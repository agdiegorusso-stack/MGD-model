# cortical_mgd/plasticity/stdp_local_mgd.py

import torch
import math

from cortical_mgd.plasticity.synaptic_cache import SynapticCache


class STDPLocalMGD:
    """
    Versione locale di STDPMgd.
    Invece di SVD globale, ogni sinapsi (i,j) calcola
    la propria curvatura di Forman locale:

      deg_i = W[i, :].sum()   # grado pesato del neurone i
      deg_j = W[:, j].sum()   # grado pesato del neurone j
      d_bar = W.sum() / (W > 0).sum()  # grado medio
      kappa_ij = (4 * W[i,j] - deg_i - deg_j) / (d_bar + 1e-8)

    Poi modula l'aggiornamento STDP per ogni sinapsi:
      eta_ij = eta_base * (1 + max(0, -kappa_ij) * alpha)

    Biologicamente plausibile: ogni sinapsi guarda solo
    i neuroni pre e post-sinaptici e i loro vicini diretti.

    Synaptic Caching (van Rossum & Li, 2009):
      Se use_caching=True, ogni dW viene filtrato attraverso
      SynapticCache prima di essere applicato a W.
      La soglia di consolidamento e kF-dipendente:
      sinapsi iperboliche (kF<<0) consolidano piu velocemente.
    """

    def __init__(self, input_dim: int, n_neurons: int,
                 eta_base: float = 0.1, alpha: float = 0.3,
                 tau_plus: float = 20.0, tau_minus: float = 20.0,
                 A_plus: float = 1.0, A_minus: float = 1.0,
                 use_caching: bool = True,
                 tau_c: float = 10.0,
                 theta_c_base: float = 0.02):
        self.input_dim = input_dim
        self.n_neurons = n_neurons
        self.eta_base = eta_base
        self.alpha = alpha

        self.A_plus = A_plus
        self.A_minus = A_minus

        dt = 1.0
        self.decay_plus = math.exp(-dt / tau_plus)
        self.decay_minus = math.exp(-dt / tau_minus)

        self.trace_pre = None
        self.trace_post = None
        self.last_pre_spikes = None
        self.last_post_spikes = None

        # Synaptic caching
        self.use_caching = use_caching
        self.cache = SynapticCache(tau_c=tau_c, theta_c_base=theta_c_base) if use_caching else None

        # Riferimento opzionale a W per compute_weight_update
        self._W_ref = None

    def update_traces(self, pre_spikes: torch.Tensor, post_spikes: torch.Tensor):
        if self.trace_pre is None or self.trace_pre.shape != pre_spikes.shape:
            self.trace_pre = torch.zeros_like(pre_spikes)
            self.trace_post = torch.zeros_like(post_spikes)

        self.trace_pre *= self.decay_plus
        self.trace_post *= self.decay_minus

        self.trace_pre[pre_spikes == 1.0] += 1.0
        self.trace_post[post_spikes == 1.0] += 1.0

        self.last_pre_spikes = pre_spikes
        self.last_post_spikes = post_spikes

    def _compute_kappa_local(self, W: torch.Tensor) -> torch.Tensor:
        """Curvatura di Forman per sinapsi su W (n_pre, n_post)."""
        deg_pre = W.sum(dim=1, keepdim=True)
        deg_post = W.sum(dim=0, keepdim=True)
        n_active = (W > 1e-8).float().sum()
        d_bar = W.sum() / (n_active + 1e-8)
        return (4 * W - deg_pre - deg_post) / (d_bar + 1e-8)

    def compute_weight_update_local(self, W: torch.Tensor) -> torch.Tensor:
        """
        W: (input_dim, n_neurons)
        Ritorna dW (input_dim, n_neurons) con eta locale per sinapsi.

        Se use_caching=True, il dW raw viene filtrato dalla SynapticCache:
        le sinapsi iperboliche (kF<<0) hanno soglia di consolidamento piu
        bassa e consolidano piu velocemente in W_pers.
        """
        kappa_local = self._compute_kappa_local(W)

        # Modulazione locale: eta alta dove curvatura negativa
        eta_local = self.eta_base * (
            1.0 + torch.clamp(-kappa_local, min=0.0) * self.alpha
        )

        # STDP base
        dW_base = (self.A_plus * self.trace_pre.T @ self.last_post_spikes) - \
                  (self.A_minus * self.last_pre_spikes.T @ self.trace_post)

        # Modulazione con eta locale topologica
        dW = eta_local * dW_base

        # Synaptic caching: filtra dW attraverso il meccanismo W_trans/W_pers
        if self.use_caching and self.cache is not None:
            dW = self.cache.apply(W, dW, kappa_local=kappa_local)

        return dW

    def compute_weight_update(self, kappa=None, d_avg=None, D_target=None) -> torch.Tensor:  # noqa: ARG002
        """
        Wrapper compatibile con l'interfaccia STDPMgd.
        Ignora kappa e d_avg globali (calcolati localmente da W).
        Richiede che update_traces e _W_ref siano stati impostati.
        """
        if self.last_pre_spikes is None or self.last_post_spikes is None:
            if hasattr(self, '_W_ref') and self._W_ref is not None:
                return torch.zeros_like(self._W_ref)
            return None
        return self.compute_weight_update_local(self._W_ref)

    @property
    def consolidation_rate(self) -> float:
        """Frazione di aggiornamenti che hanno triggerato consolidamento."""
        if self.cache is not None:
            return self.cache.consolidation_rate
        return 0.0
