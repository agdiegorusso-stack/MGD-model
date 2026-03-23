# cortical_mgd/architecture/dendritic_hierarchy.py

import torch
from cortical_mgd.architecture.predictive_hierarchy import PredictiveHierarchy


class DendriticHierarchy(PredictiveHierarchy):
    """
    Modello M: PredictiveHierarchy + neuroni a due compartimenti (dendritici).

    In biologia ogni neurone corticale ha due zone di integrazione:
    - Compartimento basale: integra input feedforward (segnale di errore da L1)
    - Compartimento apicale: integra input top-down da L3 (contesto)

    L'effetto e che L3 decide QUALI neuroni L2 possono rispondere all'input.
    Se il contesto superiore si aspetta un certo pattern e il pattern arriva,
    quei neuroni sono gia pronti a sparare (soglia effettiva abbassata).
    Questo e l'equivalente biologico dell'attention: il contesto seleziona.

    Implementazione:
        current_ff = e_hip @ W_ff              (compartimento basale)
        current_apical = h_slow @ W_apical     (compartimento apicale)
        current_total = current_ff + alpha * current_apical
        spikes = LIF(current_total) + WTA

    I pesi apicali W_apical sono proiezioni casuali fisse (non apprese).
    La combinazione di predictive coding (errori) + dendritic gating (contesto)
    replica il ciclo completo di elaborazione corticale.

    Architettura feedback:
        L3 (slow_cortex, 500 neuroni) -> W_apical (500x300) -> modula L2 (300-dim)
        alpha_apical = 0.5: meta del current viene dal contesto
    """

    def __init__(self, input_dim=784, device='cuda', n_slow=3):
        super().__init__(input_dim=input_dim, device=device, n_slow=n_slow)

        # Pesi apicali fissi: L3 (500) -> ogni area L2 (300)
        self.W_apical_A = torch.randn(500, 300) * 0.01
        self.W_apical_B = torch.randn(500, 300) * 0.01
        self.W_apical_C = torch.randn(500, 300) * 0.01
        self.W_apical_D = torch.randn(500, 300) * 0.01

        # Intensita del segnale apicale rispetto al feedforward
        self.alpha_apical = 0.5

    def to(self, device):
        super().to(device)
        self.W_apical_A = self.W_apical_A.to(device)
        self.W_apical_B = self.W_apical_B.to(device)
        self.W_apical_C = self.W_apical_C.to(device)
        self.W_apical_D = self.W_apical_D.to(device)
        return self

    def forward(self, x, task_id, cortex_bias=None):
        """
        Forward con predictive coding + gating dendritico apicale.
        Ritorna (e_hip, h_cortex, h_slow).
        """
        area = self.task_routing[task_id]
        col = getattr(self, f'cortex_{area}')
        W_apical = getattr(self, f'W_apical_{area}')

        # --- Pass 1: feedforward completo per ottenere il contesto L3 ---
        h_hip = self.hippocampus(self._to_vis(x))
        h_cortex_0 = col(h_hip.detach(), bias=cortex_bias)
        h_slow_0 = self.slow_cortex(h_cortex_0.detach())

        # --- Errori di predizione (predictive coding da PredictiveHierarchy) ---
        pred_hip = torch.sigmoid(h_cortex_0.detach() @ self.W_back_cortex)
        e_hip = torch.relu(h_hip - pred_hip)

        # --- Gating apicale: L3 modula quali neuroni L2 rispondono ---
        # current apicale: h_slow proiettato nello spazio L2 (batch, 300)
        current_apical = h_slow_0.detach() @ W_apical

        # --- Reset e passata finale con due compartimenti ---
        self.hippocampus.lif.reset_state()
        col.lif.reset_state()
        self.slow_cortex.lif.reset_state()

        # Compartimento basale: errore di predizione attraverso i pesi L2
        current_ff = e_hip.detach() @ col.W  # (batch, 300)

        # Corrente totale: feedforward + modulazione apicale
        current_total = current_ff + self.alpha_apical * current_apical

        # Hard WTA sui current totali (feedforward + apicale):
        # Biased competition: during training bias modifica la selezione WTA
        guided = current_total + cortex_bias if cortex_bias is not None else current_total
        # identico a CorticalColumn.forward(), garantisce k_wta vincitori
        # indipendentemente dalla soglia LIF (necessario con input sparsi/piccoli)
        col.lif(current_total)  # aggiorna stato LIF per adattamento soglia
        _, top_idx = torch.topk(guided, col.k_wta, dim=1)
        spikes = torch.zeros_like(current_total).scatter_(1, top_idx, 1.0)

        # Aggiorna tracce STDP con l'input effettivo (errore di predizione)
        col.stdp.update_traces(e_hip.detach(), spikes)

        # L3 aggiornato con l'output dendritico
        h_slow = self.slow_cortex(spikes.detach())

        return e_hip, spikes, h_slow

