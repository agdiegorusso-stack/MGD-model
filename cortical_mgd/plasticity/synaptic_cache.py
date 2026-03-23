# cortical_mgd/plasticity/synaptic_cache.py

import math
import torch


class SynapticCache:
    """
    Synaptic Caching Decomposition (van Rossum & Li, 2009).

    The effective synaptic weight decomposes as:
        W(t) = W_pers(t) + W_trans(t)

    W_pers -- persistent (consolidated) component.
              Metabolically expensive to change; stable over many tasks.
    W_trans -- transient (cached) component.
               Accumulates STDP updates cheaply; decays exponentially.

    Dynamics:
        dW_trans/dt = -W_trans / tau_c  +  dW_STDP

    Consolidation fires per-synapse when |W_trans_ij| > theta_c_ij:
        W_pers  <-  W_pers  +  W_trans   (commit)
        W_trans <-  0                    (reset cache)

    Biological analogy:
        W_trans  ~  early-phase LTP  (fast, protein-modification-free)
        W_pers   ~  late-phase LTP   (slow, transcription-dependent)

    MGD grounding:
        The consolidation threshold is kF-dependent.
        Hyperbolic synapses (kF << 0) sit in locally hierarchical sub-networks
        and receive a lower theta_c, consolidating faster when their sub-network
        is geometrically active.
        Flat synapses (kF ~ 0) retain a high theta_c, deferring consolidation
        until evidence accumulates -- recovering the variance-reduction effect
        of gradient batching without centralised memory.

    Parameters
    ----------
    tau_c : float
        Decay time-constant (time-steps) for W_trans.  Default 10.
    theta_c_base : float
        Base consolidation threshold.  Default 0.02.
    alpha_theta : float
        Sensitivity of theta_c to kF.  Default 0.5.
        theta_c_ij = theta_c_base / (1 + max(0, -kF_ij) * alpha_theta)
    """

    def __init__(self,
                 tau_c: float = 10.0,
                 theta_c_base: float = 0.02,
                 alpha_theta: float = 0.5):
        self.tau_c = tau_c
        self.theta_c_base = theta_c_base
        self.alpha_theta = alpha_theta
        self._decay = math.exp(-1.0 / max(tau_c, 1e-6))

        self.W_trans: torch.Tensor | None = None
        self.W_pers: torch.Tensor | None = None

        self._n_consolidations = 0
        self._n_decays = 0

    # ------------------------------------------------------------------
    def _init(self, W: torch.Tensor) -> None:
        self.W_trans = torch.zeros_like(W)
        self.W_pers = W.clone()

    # ------------------------------------------------------------------
    def apply(self,
              W: torch.Tensor,
              dW: torch.Tensor,
              kappa_local: torch.Tensor | None = None) -> torch.Tensor:
        """
        Accumulate dW through the two-component caching mechanism.

        Parameters
        ----------
        W : (n_pre, n_post)  Current effective weight matrix.
        dW : (n_pre, n_post) Raw STDP update.
        kappa_local : optional (n_pre, n_post)
            Per-synapse Forman-Ricci curvature.  When provided, lowers the
            consolidation threshold in the hyperbolic (kF << 0) regime.

        Returns
        -------
        dW_eff : (n_pre, n_post)
            Net effective update to add to W.  Apply as W += dW_eff.
        """
        if self.W_trans is None or self.W_trans.shape != W.shape:
            self._init(W)

        # Re-sync W_pers whenever external code (homeostasis, pruning) touches W.
        # W_pers = W - W_trans  (by definition of the decomposition).
        self.W_pers = W - self.W_trans

        # --- Decay transient ---
        self.W_trans = self.W_trans * self._decay

        # --- Accumulate new STDP signal ---
        self.W_trans = self.W_trans + dW

        # --- Per-synapse consolidation threshold ---
        if kappa_local is not None:
            kl = kappa_local.to(W.device)
            theta_c = self.theta_c_base / (
                1.0 + torch.clamp(-kl, min=0.0) * self.alpha_theta
            )
        else:
            theta_c = self.theta_c_base

        # --- Consolidation mask ---
        consolidate = self.W_trans.abs() > theta_c
        self._n_consolidations += int(consolidate.sum().item())
        self._n_decays += int((~consolidate).sum().item())

        # Commit consolidated portion to persistent memory
        self.W_pers = self.W_pers + consolidate.float() * self.W_trans
        # Reset consolidated entries in transient cache
        self.W_trans = self.W_trans * (~consolidate).float()

        # Effective weight delta
        W_effective = self.W_pers + self.W_trans
        return W_effective - W

    # ------------------------------------------------------------------
    @property
    def consolidation_rate(self) -> float:
        total = self._n_consolidations + self._n_decays
        return self._n_consolidations / max(total, 1)

    def reset_stats(self) -> None:
        self._n_consolidations = 0
        self._n_decays = 0

    def reset_state(self) -> None:
        """Full reset (call at task boundary if needed)."""
        self.W_trans = None
        self.W_pers = None
        self.reset_stats()
