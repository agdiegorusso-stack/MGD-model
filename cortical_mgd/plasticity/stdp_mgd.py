# cortical_mgd/plasticity/stdp_mgd.py

import torch
import math

from cortical_mgd.plasticity.synaptic_cache import SynapticCache


class STDPMgd:
    """
    MGD-modulated Spike-Timing Dependent Plasticity con regola BCM.

    STDP classica (Bi & Poo 1998):
        dW = A+ * trace_pre.T @ post_spikes  (LTP: pre prima di post)
           - A- * pre_spikes.T @ trace_post  (LTD: post prima di pre)

    Modulazione BCM (Bienenstock-Cooper-Munro 1982):
        La soglia theta per ogni neurone post-sinaptico si adatta alla sua
        storia di attivazione: theta_j <- theta_j + (y_j^2 - theta_j) / tau_bcm.
        Il termine LTP viene scalato da (post - theta): se il neurone spara
        piu' del suo set-point, il potenziale LTP diventa LTD (stabilizzazione).
        Matematica: dW_bcm = pre_trace.T @ (post * (post - theta))

        Effetto: previene la saturazione W senza bisogno del hard clamp,
        crea un punto fisso stabile per ogni neurone (Oja 1982).

    Modulazione MGD:
        eta = eta_base * (1 + max(0, -kappa) * 0.3) * clip(D_target/D_avg, 0.1, 2.0)
        Curvatura negativa (struttura iperbolica) -> tasso di apprendimento piu' alto.
    """

    def __init__(
        self,
        n_pre: int,
        n_post: int,
        eta_base: float = 0.01,
        tau_plus: float = 20.0,
        tau_minus: float = 20.0,
        A_plus: float = 1.0,
        A_minus: float = 1.0,
        tau_bcm: float = 500.0,
        use_caching: bool = False,
        tau_c: float = 10.0,
        theta_c_base: float = 0.02,
    ):
        # n_pre / n_post kept for interface compatibility (lazy-init of traces)
        del n_pre, n_post

        self.eta_base = eta_base
        self.A_plus = A_plus
        self.A_minus = A_minus

        dt = 1.0
        self.decay_plus = math.exp(-dt / tau_plus)
        self.decay_minus = math.exp(-dt / tau_minus)
        self.alpha_bcm = 1.0 / tau_bcm  # tasso aggiornamento soglia BCM

        self.trace_pre = None
        self.trace_post = None
        # Soglia BCM per ogni neurone post-sinaptico: shape (n_post,) quando init

        # Synaptic caching (van Rossum & Li 2009)
        self.use_caching = use_caching
        self.cache = SynapticCache(tau_c=tau_c, theta_c_base=theta_c_base) if use_caching else None
        self.theta_bcm: torch.Tensor | None = None

    def update_traces(self, pre_spikes: torch.Tensor, post_spikes: torch.Tensor):
        # Tracce sempre in FP32 per evitare oscillazioni dtype in AMP
        # e recompilazioni di torch.compile
        pre_f = pre_spikes.detach().float()
        post_f = post_spikes.detach().float()

        if self.trace_pre is None or self.trace_pre.shape != pre_f.shape:
            self.trace_pre = torch.zeros_like(pre_f)
            self.trace_post = torch.zeros_like(post_f)

        self.trace_pre = self.trace_pre * self.decay_plus
        self.trace_post = self.trace_post * self.decay_minus

        self.trace_pre[pre_f == 1.0] += 1.0
        self.trace_post[post_f == 1.0] += 1.0

        self.last_pre_spikes = pre_f
        self.last_post_spikes = post_f

        # Aggiorna soglia BCM: theta <- theta + (y^2 - theta) / tau_bcm
        # Mediata sul batch (dim=0) per ottenere una stima per-neurone stabile
        y_sq = (post_f ** 2).mean(dim=0)  # (n_post,)
        if self.theta_bcm is None:
            self.theta_bcm = y_sq.clone()
        else:
            if self.theta_bcm.device != y_sq.device:
                self.theta_bcm = self.theta_bcm.to(y_sq.device)
            self.theta_bcm = self.theta_bcm + self.alpha_bcm * (y_sq - self.theta_bcm)

    def compute_weight_update(
        self, kappa: float = 0.0, D_avg: float = 1.0, D_target: float = 1.0,
        W: torch.Tensor | None = None,
        delta_cortex: torch.Tensor | None = None,
        feedback_weight: float = 1.0,
    ) -> torch.Tensor:
        """
        Calcola dW combinando STDP classica e regola BCM, modulato da MGD.

        STDP: dW_std = A+ * trace_pre.T @ post - A- * pre.T @ trace_post
        BCM:  dW_bcm = trace_pre.T @ (post * (post - theta))
              Quando post > theta: contributo LTD (evita saturazione)
              Quando post < theta: contributo LTP (rinforza neuroni silenziosi)

        Curvatura-flusso locale (MGD Theorem OP8, risoluzione_kappa0 Theorem 5.3):
              kappa_local_ij = kappa_0 - gamma_0 * (M_pre_i - M_post_j) / (W_ij + eps)
              kappa_0 = 1/3  (curvatura universale catena 1D omogenea attiva)
              gamma_0 = 1.0  (con xi=0, tracce STDP come campo materiale puro)
              dW_ij *= 1 + relu(-kappa_local_ij) * 0.3
              Rinforza le sinapsi in zone iperboliche: se pre molto attivo e
              post silenzioso, la sinapsi e in curvatura negativa -> boost LTP.

        dW_finale = eta_mgd * (dW_std + dW_bcm) * boost_locale

        Args:
            kappa:    Curvatura di Forman-Ricci globale (modula eta).
            D_avg:    Dimensione effettiva corrente.
            D_target: Dimensione effettiva target.
            W:        (n_pre, n_post) pesi correnti per curvatura-flusso locale.

        Returns:
            dW: (n_pre, n_post) aggiornamento pesi.
        """
        # STDP classica
        dW_std = (
            self.A_plus * self.trace_pre.T @ self.last_post_spikes
            - self.A_minus * self.last_pre_spikes.T @ self.trace_post
        )

        # BCM: modula LTP/LTD in base alla storia del neurone
        # Tracce e theta sono sempre FP32 dopo il refactor di update_traces
        if self.theta_bcm is not None:
            theta = self.theta_bcm
            if theta.device != self.last_post_spikes.device:
                theta = theta.to(self.last_post_spikes.device)
            # (post - theta): positivo -> LTD, negativo -> LTP
            bcm_signal = self.last_post_spikes * (self.last_post_spikes - theta.unsqueeze(0))
            dW_bcm = self.trace_pre.T @ bcm_signal  # (n_pre, n_post)
        else:
            dW_bcm = torch.zeros_like(dW_std)

        dW = dW_std + dW_bcm

        # Modulazione MGD globale (Forman-Ricci + D_avg)
        factor_kappa = max(0.0, float(-kappa))
        factor_dim = max(0.1, min(2.0, float(D_target) / float(D_avg + 1e-10)))
        eta_mgd = self.eta_base * (1.0 + factor_kappa * 0.3) * factor_dim

        dW = eta_mgd * dW

        # Curvatura-flusso locale MGD (Theorem OP8 / risoluzione_kappa0 Thm 5.3):
        # kappa_local_ij = kappa_0 - gamma_0 * (M_t(i) - M_t(j)) / w_t(i,j)
        # kappa_0 = 1/3, gamma_0 = 1 (xi=0 per tracce STDP pure)
        #
        # Normalizzazione adimensionale (MGD paper: M e w in [0,1]):
        # Le tracce STDP sono O(1/(1-decay)) >> W sinaptico -> normalizzare entrambi.
        # M_norm_i = M_i / max(M)  in [0,1]
        # W_norm_ij = W_ij / max(W) in [0,1]
        # Cosi il rapporto M_diff_norm / W_norm e O(1) come nel modello MGD.
        if W is not None and self.trace_pre is not None and self.trace_post is not None:
            W_d = W.detach().float()
            M_pre = self.trace_pre.mean(dim=0).float()
            M_post = self.trace_post.mean(dim=0).float()
            if M_pre.device != W_d.device:
                M_pre = M_pre.to(W_d.device)
                M_post = M_post.to(W_d.device)
            # Normalizza M a [0,1]
            M_scale = max(M_pre.abs().max().item(), M_post.abs().max().item(), 1e-4)
            M_pre_n = M_pre / M_scale
            M_post_n = M_post / M_scale
            M_diff_n = M_pre_n.unsqueeze(1) - M_post_n.unsqueeze(0)  # in [-1, 1]
            # Normalizza W a [0,1]
            W_scale = W_d.abs().max().clamp(min=1e-4).item()
            W_norm = W_d.abs() / W_scale  # in [0, 1]
            # kappa_local: con M e W in [0,1], il rapporto e O(1)
            kappa_local = (1.0 / 3.0) - M_diff_n / (W_norm + 0.1)
            kappa_local = kappa_local.clamp(-5.0, 5.0)
            # Boost LTP nelle zone iperboliche (kappa < 0): max 2x
            boost = 1.0 + torch.relu(-kappa_local) * 0.2
            dW = dW * boost.to(dW.dtype)

        # Three-Factor STDP (R-STDP, Fremaux & Gerstner 2016):
        # Terzo fattore = segnale dopaminergico dall'errore del readout.
        # M_j = delta_cortex_j = feedback errore per neurone post j.
        # M_j > 0: neurone contribuisce alla classe giusta -> amplifica STDP (max 4x)
        # M_j < 0: neurone contribuisce alla classe sbagliata -> attenua (min 0.5x)
        # Normalizzazione RMS: robusta agli outlier (vs max-norm).
        # Ordine: DOPO MGD eta e kappa-locale, PRIMA di eta_batch globale.
        if delta_cortex is not None:
            delta_f = delta_cortex.detach().float()
            if delta_f.device != dW.device:
                delta_f = delta_f.to(dW.device)
            rms = delta_f.pow(2).mean().sqrt().clamp(min=1e-6)
            delta_n = (delta_f / rms).clamp(-3.0, 3.0) / 3.0  # in [-1, 1]
            # Asimmetrica: premia forte chi corregge, penalizza leggero chi sbaglia
            modulation = torch.where(
                delta_n > 0,
                1.0 + 3.0 * delta_n,   # range [1.0, 4.0]
                1.0 + 0.5 * delta_n    # range [0.5, 1.0]
            )
            # Warm-up lineare: nelle prime iterazioni modulation -> 1
            modulation = modulation * feedback_weight + (1.0 - feedback_weight)
            dW = dW * modulation.unsqueeze(0).to(dW.dtype)

        # Synaptic caching: filtra dW attraverso W_trans/W_pers
        # Richiede W corrente; se non fornito, salta.
        if self.use_caching and self.cache is not None and W is not None:
            dW = self.cache.apply(W.detach().float(), dW)

        return dW
