"""
structural_plasticity.py — Fase 8: Pruning sinaptico e sinaptogenesi biologica.

Implementa plasticità strutturale (Holtmaat & Svoboda, 2009) fondata su:
  - Kappa_F locale (curvatura di Forman-Ricci) per identificare sinapsi non specializzate
  - Co-attivazione pre×post per identificare connessioni latenti da "risvegliare"
  - Contatore di inattività per tau_pruning task consecutivi

PROPRIETÀ CHIAVE:
  - Elimina il limite fisso di n_tasks liberando neuroni morti post-pruning
  - Scala biologicamente: O(input_dim × n_neurons), no overhead SVD
  - Compatibile con ModularGate: i neuroni liberati rientrano nel pool di allocazione
"""

import torch


class StructuralPlasticity:
    """
    Pruning sinaptico e sinaptogenesi fondati su kappa_F locale e co-attivazione.

    PRUNING:
        Sinapsi eliminate se: peso basso (< epsilon) AND kappa_F > 0 (curvatura
        positiva = neurone generalista, non specializzato) AND inattive per
        tau_pruning task consecutivi.

    SINAPTOGENESI:
        Connessioni dormenti (connectivity == 0) con alta co-attivazione vengono
        riattivate con peso iniziale piccolo (0.01).
    """

    def __init__(
        self,
        n_neurons: int,
        input_dim: int,
        epsilon: float = 0.05,
        tau_pruning: int = 3,
        grow_threshold: float = 0.1,
    ):
        """
        Args:
            n_neurons:       Numero di neuroni nella colonna corticale.
            input_dim:       Dimensione dell'input (es. 784 per MNIST).
            epsilon:         Soglia peso minimo sotto cui una sinapsi è "debole".
            tau_pruning:     Task consecutivi di inattività prima del pruning.
            grow_threshold:  Soglia co-attivazione normalizzata per sinaptogenesi.
        """
        self.epsilon = epsilon
        self.tau_pruning = tau_pruning
        self.grow_threshold = grow_threshold

        # Maschera connettività: 1 = sinapsi attiva, 0 = dormiente/potata
        self.connectivity = torch.ones(input_dim, n_neurons)

        # Contatore inattività per sinapsi (in unità di "task")
        self.inactivity = torch.zeros(input_dim, n_neurons)

        # Matrice co-attivazione accumulata: pre_spikes^T @ post_spikes
        self.co_act_matrix = torch.zeros(input_dim, n_neurons)
        self.co_act_count = 0

    # ------------------------------------------------------------------
    # Online statistics
    # ------------------------------------------------------------------

    def update_coactivation(
        self, pre_spikes: torch.Tensor, post_spikes: torch.Tensor
    ) -> None:
        """
        Accumula co-attivazione pre×post ad ogni forward pass.

        Args:
            pre_spikes:  (1, input_dim)  spike binari del livello pre-sinaptico.
            post_spikes: (1, n_neurons)  spike binari del livello post-sinaptico.
        """
        # pre_spikes.T: (input_dim, 1)  ×  post_spikes: (1, n_neurons) = (input_dim, n_neurons)
        delta = pre_spikes.cpu().T @ post_spikes.cpu()
        self.co_act_matrix += delta
        self.co_act_count += 1

    # ------------------------------------------------------------------
    # Pruning
    # ------------------------------------------------------------------

    def prune(
        self,
        W: torch.Tensor,
        task_id: int,
        allocation_time: dict,
        protected_neurons=None,
    ) -> torch.Tensor:
        """
        Pota le sinapsi deboli + iperbolicità bassa + vecchie.

        Criteri (tutti e tre devono essere veri):
            1. peso < epsilon           (sinapsi debole)
            2. kappa_F > 0              (curvatura positiva = non specializzata)
            3. inattiva > tau_pruning   (task consecutivi senza attivazione)

        Args:
            W:               (input_dim, n_neurons) matrice pesi corrente.
            task_id:         Id del task corrente (per logging).
            allocation_time: Dict {neuron_idx: task_id} da ModularGate.
            protected_neurons: Set di indici dei neuroni da non potare.

        Returns:
            Maschera di connettività aggiornata (input_dim, n_neurons) su device di W.
        """
        W_cpu = W.detach().cpu()

        # --- Kappa_F locale per ogni sinapsi (approssimazione sparsa) ---
        deg_pre = W_cpu.sum(dim=1, keepdim=True)   # (input_dim, 1)
        deg_post = W_cpu.sum(dim=0, keepdim=True)  # (1, n_neurons)
        n_active = (W_cpu > 1e-8).float().sum()
        d_bar = W_cpu.sum() / (n_active + 1e-8)
        # kappa_F per sinapsi (ij): (4*w_ij - deg_i - deg_j) / d_bar
        kappa = (4.0 * W_cpu - deg_pre - deg_post) / (d_bar + 1e-8)

        # --- Criteri ---
        # Invece di soglia assoluta, usa percentile 10%
        # Le 10% sinapsi piu deboli sono candidate al pruning
        epsilon_dynamic = torch.quantile(W_cpu[W_cpu > 1e-8], 0.10) if (W_cpu > 1e-8).any() else torch.tensor(self.epsilon)
        weak = W_cpu < epsilon_dynamic

        # Relativamente meno iperbolica rispetto alla media
        kappa_mean = kappa.mean()
        kappa_std = kappa.std()
        not_specialized = kappa > (kappa_mean + kappa_std)

        # Aggiorna inattività: +1 per le deboli, reset per le attive
        self.inactivity[weak] += 1
        self.inactivity[~weak] = 0

        old_enough = self.inactivity > self.tau_pruning

        # Maschera neuroni protetti (allocati a task)
        # Non potare mai le sinapsi di neuroni consolidati
        protected_mask = torch.zeros(W_cpu.shape, dtype=torch.bool)
        if protected_neurons is not None:
            for j in protected_neurons:
                protected_mask[:, j] = True
        elif allocation_time:
            for j in allocation_time.keys():
                protected_mask[:, j] = True

        to_prune = weak & not_specialized & old_enough & ~protected_mask

        # Applica pruning
        self.connectivity[to_prune] = 0
        W_cpu[to_prune] = 0.0

        n_pruned = int(to_prune.sum().item())
        if n_pruned > 0:
            print(f"[Pruning] Task{task_id}: {n_pruned} sinapsi potate")

        return self.connectivity.to(W.device)

    # ------------------------------------------------------------------
    # Synaptogenesis
    # ------------------------------------------------------------------

    def grow(self, W: torch.Tensor) -> torch.Tensor:
        """
        Attiva connessioni dormenti con alta co-attivazione (sinaptogenesi).

        Args:
            W: (input_dim, n_neurons) matrice pesi corrente.

        Returns:
            W aggiornato (su stesso device di input).
        """
        if self.co_act_count == 0:
            return W

        W_cpu = W.detach().cpu()
        co_norm = self.co_act_matrix / (self.co_act_count + 1e-8)

        dormant = self.connectivity == 0
        high_coact = co_norm > self.grow_threshold
        to_grow = dormant & high_coact

        # Attiva con peso piccolo (non rompe la distribuzione dei pesi esistenti)
        W_cpu[to_grow] = 0.01
        self.connectivity[to_grow] = 1

        n_grown = int(to_grow.sum().item())
        if n_grown > 0:
            print(f"[Sinaptogenesi] {n_grown} sinapsi attivate")

        return W_cpu.to(W.device)

    # ------------------------------------------------------------------
    # Masking
    # ------------------------------------------------------------------

    def apply_connectivity(self, W: torch.Tensor) -> torch.Tensor:
        """
        Azzera le sinapsi dormenti applicando la maschera di connettività.

        Args:
            W: (input_dim, n_neurons) matrice pesi.

        Returns:
            W con sinapsi potate azzerate.
        """
        return W * self.connectivity.to(W.device)
