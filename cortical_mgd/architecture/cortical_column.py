# cortical_mgd/architecture/cortical_column.py

import torch
import torch.nn as nn
from cortical_mgd.neurons.lif_adaptive import AdaptiveLIFGroup
from cortical_mgd.plasticity.stdp_mgd import STDPMgd
from cortical_mgd.core.mgd_metrics import compute_forman_ricci_torch, compute_D_avg_torch, compute_D_avg_local
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
        
        # Sottrae la frequenza di vincita (ora in range [0, 1])
        # Moltiplicatore 100.0: Salita drastica per spaccare l'overlap del 40% del SentenceTransformer!
        # Max current è 75.0. Se un neurone domina, wta_freq -> 1.0, penalità -> 100.0.
        # Identico topic (perfetto 15 pesi max): 75.0 - (es. 0.6 * 100) = 15.0 (Vince ancora sul rumore 1.5)
        # Overlap topic scorrelato (es. 6 pesi): 30.0 - (0.6 * 100) = -30.0 (Perde rovinosamente)
        guided = guided - self.wta_freq * 100.0
        
        # Aggiunta di rumore biologico per spezzare i pareggi (tie-breaking)
        # Rumore stocastico solo in training: in eval i cluster ID devono essere
        # deterministici e riproducibili (stessa frase -> stesso cluster ogni volta).
        if self.training:
            guided = guided + torch.randn_like(guided) * 1e-3

        # Hard WTA sui guided current: forza esattamente k_wta vincitori
        # indipendentemente dalla soglia LIF (necessario con input sparsi da VH)
        _, top_idx = torch.topk(guided, self.k_wta, dim=1)
        spikes = torch.zeros_like(current).scatter_(1, top_idx, 1.0)

        # Apprendimento STDP (se abilitato)
        self.stdp.update_traces(x, spikes)

        # Aggiornamento homeostasis e co-attivazione: SOLO in training.
        # In eval (inference/retrieval) wta_freq e' frozen: garantisce che la stessa
        # frase produca sempre lo stesso cluster ID indipendentemente da quante
        # altre frasi sono state processate.
        if self.training:
            with torch.no_grad():
                self._co_act.add_(x.detach().T @ spikes.detach())
                self._co_act_n.add_(x.shape[0])
                self.wta_freq.mul_(0.95).add_(spikes.detach().mean(dim=0) * 0.02)

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

    def compute_mgd_metrics(self, local_davg: bool = False) -> tuple[float, float]:
        """
        Extracts real-time continuous geometric properties from the column's
        afferent/recurrent weight matrices.

        Args:
            local_davg: if True uses the O(n) column-norm proxy instead of SVD O(n^3).

        Returns:
            (kappa, D_avg): Forman-Ricci Curvature and Effective Dimension.
        """
        W = self.W.detach()
        kappa = compute_forman_ricci_torch(W)
        if local_davg:
            d_avg = float(compute_D_avg_local(W).item())
        else:
            d_avg = float(compute_D_avg_torch(W).item())
        return kappa, d_avg
