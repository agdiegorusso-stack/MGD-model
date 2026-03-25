import os
import numpy as np
import torch
from cortical_mgd.architecture.bio_mgd_brain import BioMGDBrain

# Cartella dove salvare i pesi MGD persistenti
_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'data')
os.makedirs(_DATA_DIR, exist_ok=True)
_WEIGHTS_PATH = os.path.join(_DATA_DIR, 'mgd_weights.pt')

class MGDTextBrain:
    """
    Wrapper per BioMGDBrain ottimizzato per encoding testuale.
    - encode_and_forward(): testo → mgd_id stringa stabile
    - apply_dopamine(): rinforza la zona topologica attiva (Three-Factor R-STDP)
    - save_weights() / load_weights(): persistenza dei pesi tra sessioni
    """

    def __init__(self, n_input_mgd: int = 512, device: str = 'cpu'):
        self.n_input = n_input_mgd
        self.device = device
        self.brain = BioMGDBrain(input_dim=n_input_mgd, device=device)
        self.brain.to(device)

        self.text_task_id = "text_memory"
        self.brain.task_routing[self.text_task_id] = 'A'

        # Cache dell'ultimo stato per il feedback dopaminergico
        self._last_x: torch.Tensor | None = None
        self._last_h_hip: torch.Tensor | None = None
        self._last_h1: torch.Tensor | None = None
        self._last_h2: torch.Tensor | None = None
        self._last_h3: torch.Tensor | None = None

        # Carica pesi persistenti se esistono
        self.load_weights()

    def save_weights(self, path: str = _WEIGHTS_PATH):
        """Salva i pesi plastici di tutti i layer su disco."""
        torch.save({
            'cortex_A_W': self.brain.cortex_A.W.data,
            'cortex_L2_W': self.brain.cortex_L2.W.data,
            'L3_W': self.brain.L3.W.data,
        }, path)

    def load_weights(self, path: str = _WEIGHTS_PATH):
        """Carica i pesi plastici da disco se il file esiste."""
        if os.path.exists(path):
            checkpoint = torch.load(path, map_location=self.device)
            for key, col in [
                ('cortex_A_W',  self.brain.cortex_A),
                ('cortex_L2_W', self.brain.cortex_L2),
                ('L3_W',        self.brain.L3),
            ]:
                if key in checkpoint:
                    w = checkpoint[key]
                    if w.shape == col.W.shape:
                        col.W.data.copy_(w)


    def encode_text_sequence(self, text: str, text_encoder, T: int = 10,
                              train_mode: bool = True) -> str:
        """
        Processa il testo nativo convertendolo nella sua Sparse Distributed Representation (SDR).
        Solo i K=15 neuroni piu' semanticamente rilevanti sparano, ordinati per importanza.

        train_mode=True  (default): aggiorna wta_freq e homeostasis -> usa durante R-STDP training.
        train_mode=False (inference): wta_freq frozen, no rumore -> cluster ID deterministico e
                         riproducibile. Usa per retrieval e storage nel DB (garantisce che la stessa
                         frase produca sempre lo stesso cluster ID indipendentemente da quante
                         altre frasi siano state processate nel frattempo).
        """
        if train_mode:
            self.brain.train()
        else:
            self.brain.eval()

        spike_train_np = text_encoder.text_to_sdr_spikes(text, n_neurons=self.n_input, top_k=15, max_T=T)
        spike_train = torch.tensor(spike_train_np, dtype=torch.float32, device=self.device)

        # Reset stati SNN e STDP traces prima di ogni nuova sequenza (frase).
        # CRITICO: senza il reset delle traces, encode di "nome" eredita il 60% delle
        # traces di "fisica" (decay=0.951^10≈0.60), inquinando il segnale contrastivo.
        self.brain.hippocampus.lif.reset_state()
        self.brain.cortex_A.lif.reset_state()
        self.brain.cortex_L2.lif.reset_state()
        self.brain.L3.lif.reset_state()
        for col in [self.brain.cortex_A, self.brain.cortex_L2, self.brain.L3]:
            col.stdp.trace_pre = None
            col.stdp.trace_post = None

        accumulated_spikes = None
        h_hip_acc = None
        h1_acc = None
        h2_acc = None

        with torch.no_grad():
            for t in range(T):
                # spike_train[t] è [1, n_neurons]
                x_t = spike_train[t]
                h_hip, h1, h2, h3 = self.brain.forward(x_t, task_id=self.text_task_id)
                if accumulated_spikes is None:
                    accumulated_spikes = h3.clone()
                    h_hip_acc = h_hip.clone()
                    h1_acc = h1.clone()
                    h2_acc = h2.clone()
                else:
                    accumulated_spikes += h3
                    h_hip_acc += h_hip
                    h1_acc += h1
                    h2_acc += h2

        # Salva per apply_dopamine (usiamo l'accumulato diviso T come proxy dell'attività media presinaptica)
        self._last_x = None  # Non più un vettore fisso, abbiamo un treno spaziotemporale
        self._last_h_hip = h_hip_acc / T
        self._last_h1 = h1_acc / T 
        self._last_h2 = h2_acc / T
        self._last_h3 = accumulated_spikes / T

        # MGD ID = neurone con max attivazione accumulata nel livello esecutivo L3
        spikes = accumulated_spikes.squeeze(0)
        winning_neuron = torch.argmax(spikes).item()
        return f"L3_cluster_{winning_neuron}"

    def apply_dopamine(self, delta_da: float):
        """
        Applica aggiornamento R-STDP ai pesi in base al reward dopaminergico.
        Propaga il segnale a TUTTI i layer in cascata (Cortex A, Cortex L2, L3).
        Senza questo, l'identificativo estratto su L3 restava puro rumore casuale non addestrato!
        """
        if self._last_h_hip is None:
            return

        updates = []

        # 1. Layer Sensoriale (Cortex_A)
        col_A = self.brain.cortex_A
        kappa_A, d_avg_A = col_A.compute_mgd_metrics()
        
        # Selective Reward: solo i neuroni che hanno sparato in A imparano
        mask_A = (self._last_h1 > 0).float() if self._last_h1 is not None else torch.ones(1, col_A.n_neurons, device=self.device)
        delta_A = mask_A * delta_da
        
        dW_A = col_A.stdp.compute_weight_update(kappa_A, d_avg_A, d_avg_A, col_A.W, delta_A, 1.0)
        if dW_A.dim() == 3: dW_A = dW_A.squeeze(0)
        updates.append((col_A, dW_A))

        # 2. Layer Associativo (Cortex_L2)
        if self._last_h2 is not None and hasattr(self.brain, 'cortex_L2'):
            col_L2 = self.brain.cortex_L2
            kappa_L2, d_avg_L2 = col_L2.compute_mgd_metrics() if hasattr(col_L2, 'compute_mgd_metrics') else (kappa_A, d_avg_A)
            
            # Selective Reward: solo chi ha sparato in L2 impara
            mask_L2 = (self._last_h2 > 0).float()
            delta_L2 = mask_L2 * delta_da
            
            dW_L2 = col_L2.stdp.compute_weight_update(kappa_L2, d_avg_L2, d_avg_L2, col_L2.W, delta_L2, 1.0)
            if dW_L2.dim() == 3: dW_L2 = dW_L2.squeeze(0)
            updates.append((col_L2, dW_L2))

        # 3. Layer Esecutivo (L3)
        if hasattr(self, '_last_h3') and self._last_h3 is not None and hasattr(self.brain, 'L3'):
            col_L3 = self.brain.L3
            kappa_L3, d_avg_L3 = col_L3.compute_mgd_metrics() if hasattr(col_L3, 'compute_mgd_metrics') else (kappa_A, d_avg_A)

            # Selective Reward: SOLO il neurone vincitore (argmax = cluster ID) impara.
            # mask > 0 dava ~128/200 neuroni (tutti che sparano almeno 1 volta in T=10).
            # Con 128 neuroni aggiornati per topic, il segnale contrastivo si diluisce.
            winning_idx = int(torch.argmax(self._last_h3.squeeze(0)).item())
            mask_L3 = torch.zeros(1, col_L3.n_neurons, device=self.device)
            mask_L3[0, winning_idx] = 1.0
            delta_L3 = mask_L3 * delta_da
            
            dW_L3 = col_L3.stdp.compute_weight_update(kappa_L3, d_avg_L3, d_avg_L3, col_L3.W, delta_L3, 1.0)
            if dW_L3.dim() == 3: dW_L3 = dW_L3.squeeze(0)
            updates.append((col_L3, dW_L3))

        # Applica l'aggiornamento ai pesi di tutti i layer.
        # Three-factor R-STDP: dW = eligibility * dopamine.
        # DA positivo -> LTP (aggiungi), DA negativo -> LTD (sottrai).
        # Senza il segno negativo, modulation=0.833 non basta: i pesi crescono
        # comunque e saturano al clamp, annullando qualsiasi struttura topic-specifica.
        with torch.no_grad():
            for col, dW in updates:
                col.W.add_(dW if delta_da >= 0 else -dW)
                # Oja normalization: mantiene i pesi su ipersfera unitaria (||W[:,j]||=1).
                # Sostituisce il clamp [0,5]: con tutti W=5.0 ogni input produce la stessa
                # attivazione -> stesso neurone vince per ogni topic (modal collapse).
                # Con norma unitaria, topic diversi sviluppano "direzioni" diverse nello
                # spazio dei pesi -> neuroni specializzati per topic distinti.
                col.W.data.clamp_(min=0.0)
                norms = col.W.data.norm(dim=0, keepdim=True).clamp(min=1e-8)
                col.W.data.div_(norms)

        # Clear memory per il prossimo turn
        self._last_x = None
        self._last_h_hip = None
        self._last_h1 = None
        self._last_h2 = None
        self._last_h3 = None
