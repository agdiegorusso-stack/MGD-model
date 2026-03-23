# cortical_mgd/architecture/cortical_column.py

import torch
import torch.nn as nn
from cortical_mgd.neurons.lif_adaptive import AdaptiveLIFGroup
from cortical_mgd.plasticity.stdp_mgd import STDPMgd
from cortical_mgd.core.mgd_metrics import compute_forman_ricci_torch, compute_D_avg_torch
from cortical_mgd.plasticity.structural_plasticity import StructuralPlasticity


class CorticalColumn(nn.Module):
    """
    A unified computational unit enforcing strict biological/MGD laws.
    Contains Adaptive LIF neurons regulated by geometric STDP (MGD modulated)
    and bounds output traffic aggressively using WTA competition (e.g. 5% max active).

    Structural plasticity (Holtmaat & Svoboda 2009) embedded:
    - Co-attivazione accumulata su GPU via register_buffer (nessun round-trip CPU
      nel forward hot-path; torch.compile stabile).
    - Pruning + sinaptogenesi chiamati una volta per task in prune_and_grow().
    - Rende W sparsa nel tempo -> kappa_F inizia a variare da -1.98.
    """
    def __init__(self, n_neurons: int, input_dim: int, target_sparsity: float = 0.05):
        super().__init__()
        self.W = nn.Parameter(torch.rand(input_dim, n_neurons) * 0.1)
        self.lif = AdaptiveLIFGroup(n_neurons, tau_m=50.0)
        self.stdp = STDPMgd(input_dim, n_neurons)
        self.n_neurons = n_neurons
        self.k_wta = max(1, int(n_neurons * target_sparsity))
        self.stp = StructuralPlasticity(n_neurons, input_dim)
        # Buffer su GPU per co-attivazione: si sposta automaticamente con .to(device)
        # Uso register_buffer per compatibilita' torch.compile (niente lazy-init branch)
        self.register_buffer('_co_act', torch.zeros(input_dim, n_neurons))
        self.register_buffer('_co_act_n', torch.zeros(1, dtype=torch.int64))

    def forward(self, x: torch.Tensor,
                bias: torch.Tensor | None = None) -> torch.Tensor:
        """
        Drives input through the synaptic weights to the LIF neurons.
        Forward pass with optional structural bias for top-down guided competition.
        """
        current = x @ self.W
        self.lif(current)  # aggiorna stato LIF per adattamento soglia
        
        # Omeostasi WTA: penalizza i neuroni che vincono troppo spesso
        if not hasattr(self, 'wta_freq'):
            self.register_buffer('wta_freq', torch.zeros(self.n_neurons, device=current.device))
        
        # Biased competition: during training bias modifica la selezione WTA
        guided = current + bias if bias is not None else current
        
        # Sottrae la frequenza di vincita per scoraggiare chi vince sempre
        guided = guided - self.wta_freq * 0.5
        
        # Hard WTA sui guided current: forza esattamente k_wta vincitori
        # indipendentemente dalla soglia LIF (necessario con input sparsi da VH)
        _, top_idx = torch.topk(guided, self.k_wta, dim=1)
        spikes = torch.zeros_like(current).scatter_(1, top_idx, 1.0)
        
        # Apprendimento STDP (se abilitato)
        self.stdp.update_traces(x, spikes)
        
        # Aggiornamento parametri modulazione globale
        with torch.no_grad():
            self._co_act.add_(x.detach().T @ spikes.detach())
            self._co_act_n.add_(x.shape[0])
            self.wta_freq.mul_(0.9).add_(spikes.detach().mean(dim=0))
            
        return spikes

    def prune_and_grow(self, task_id: int, allocation_time: dict) -> None:
        """
        Pruning sinaptico + sinaptogenesi post-task (chiamato una volta per task).

        Trasferisce co-attivazione GPU->CPU qui (non nel forward).
        Dopo pruning azzera buffer per il task successivo.
        """
        with torch.no_grad():
            self.stp.co_act_matrix.copy_(self._co_act.cpu())
            self.stp.co_act_count = int(self._co_act_n.item())
            new_conn = self.stp.prune(self.W.data, task_id, allocation_time)
            self.W.data.mul_(new_conn.to(self.W.device))
            self.W.data = self.stp.grow(self.W.data)
        self._co_act.zero_()
        self._co_act_n.zero_()
        self.stp.co_act_count = 0

    def compute_mgd_metrics(self) -> tuple[float, float]:
        """
        Extracts real-time continuous geometric properties from the column's
        afferent/recurrent weight matrices.

        Returns:
            (kappa, D_avg): Forman-Ricci Curvature and Effective Dimension.
        """
        W = self.W.detach()
        kappa = compute_forman_ricci_torch(W)
        d_avg = float(compute_D_avg_torch(W).item())
        return kappa, d_avg
