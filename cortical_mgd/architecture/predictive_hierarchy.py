# cortical_mgd/architecture/predictive_hierarchy.py

import torch
from cortical_mgd.architecture.temporal_hierarchy import TemporalHierarchy


class PredictiveHierarchy(TemporalHierarchy):
    """
    Modello L: TemporalHierarchy + Predictive Coding.

    Aggiunge connessioni di feedback top-down che rendono ogni livello
    capace di predire il livello inferiore. Il segnale che sale e l'errore
    di predizione (sorpresa), non l'input grezzo.

    Questo e l'equivalente biologico dell'attention dei transformer:
    il contesto superiore seleziona quali segnali inferiori sono rilevanti
    eliminando tutto cio che il livello alto gia si aspettava.

    Architettura feedback:
        L3 (slow, 500) -> W_back_slow (500x300) -> predice L2 (300-dim)
        L2 (cortex, 300) -> W_back_cortex (300x2000) -> predice L1 (2000-dim)

    Forward a due passate:
        Pass 1 feedforward: x -> L1 -> L2 -> L3 (rappresentazioni iniziali)
        Calcolo errori:
            e_cortex = relu(h_cortex - sigmoid(h_slow @ W_back_slow))
            e_hip    = relu(h_hip    - sigmoid(h_cortex @ W_back_cortex))
        Pass 2 su errori:
            e_hip -> L2 -> L3 (il sistema processa solo la sorpresa)

    I pesi di feedback sono proiezioni casuali fisse (non apprese).
    Questo basta: il feedback casuale allinea gradualmente le rappresentazioni
    anche senza aggiornare W_back (random feedback alignment, Lillicrap 2016).

    Consumo energetico: inferiore a K perche e_hip e sparso su due fronti
    (sparsita WTA + sparsita predizione). In media 1-3% neuroni attivi.
    """

    def __init__(self, input_dim=784, device='cuda', n_slow=3):
        super().__init__(input_dim=input_dim, device=device, n_slow=n_slow)

        # Pesi di feedback fissi (non Parameter, non aggiornati)
        # L3 -> L2: (500, 300)
        self.W_back_slow = torch.randn(500, 300) * 0.1

        # L2 -> L1: (300, 2000)
        self.W_back_cortex = torch.randn(300, 2000) * 0.1

    def to(self, device):
        super().to(device)
        self.W_back_slow = self.W_back_slow.to(device)
        self.W_back_cortex = self.W_back_cortex.to(device)
        return self

    def forward(self, x, task_id, cortex_bias=None):
        """
        Forward con predictive coding a due passate.
        Ritorna (e_hip, h_cortex, h_slow) dove e_hip sono gli errori L1.
        """
        area = self.task_routing[task_id]
        col = getattr(self, f'cortex_{area}')

        # --- Pass 1: feedforward standard ---
        h_hip = self.hippocampus(self._to_vis(x))
        h_cortex_0 = col(h_hip.detach(), bias=cortex_bias)
        h_slow_0 = self.slow_cortex(h_cortex_0.detach())

        # --- Calcolo predizioni top-down ---
        # L3 predice L2: sigma(h_slow @ W_back_slow) in spazio (batch, 300)
        pred_cortex = torch.sigmoid(h_slow_0.detach() @ self.W_back_slow)

        # L2 predice L1: sigma(h_cortex @ W_back_cortex) in spazio (batch, 2000)
        pred_hip = torch.sigmoid(h_cortex_0.detach() @ self.W_back_cortex)

        # --- Calcolo errori di predizione ---
        # relu: solo le sorprese positive propagano (i neuroni non hanno rate negativo)
        e_cortex = torch.relu(h_cortex_0 - pred_cortex)
        e_hip = torch.relu(h_hip - pred_hip)

        # --- Pass 2: processa solo la sorpresa ---
        # L2 riceve l'errore L1 (cio che L2 non si aspettava dall'ippocampo)
        self.hippocampus.lif.reset_state()
        col.lif.reset_state()
        self.slow_cortex.lif.reset_state()

        h_cortex = col(e_hip.detach(), bias=cortex_bias)
        h_slow = self.slow_cortex(h_cortex.detach())

        return e_hip, h_cortex, h_slow
