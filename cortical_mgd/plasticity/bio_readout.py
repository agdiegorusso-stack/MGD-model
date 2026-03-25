import torch

class BioReadout:
    """
    Readout biologico che sostituisce Adam+CrossEntropy.
    
    Tre meccanismi combinati:
    1. Regola di Oja: impara le direzioni principali
       senza etichette, stabilizza i pesi automaticamente
    2. Perceptrone con dopamina: aggiorna solo quando
       sbaglia, scala per il segnale DA
    3. Metaplasticita BCM: ogni sinapsi adatta la propria
       learning rate in base alla propria storia
    """
    
    def __init__(self, n_input: int, n_classes: int,
                 eta_oja: float = 0.001,
                 eta_da: float = 0.01,
                 tau_bcm: float = 100.0,
                 use_prospective_config: bool = True,
                 beta_prosp: float = 0.1):
        self.n_input = n_input
        self.n_classes = n_classes
        self.eta_oja = eta_oja
        self.eta_da = eta_da
        self.tau_bcm = tau_bcm
        # Prospective Configuration (Song et al., Nature Neuroscience 2024)
        self.use_prospective_config = use_prospective_config
        self.beta_prosp = beta_prosp  # nudging coefficient toward target
        
        # Pesi del readout: (n_input, n_classes)
        self.W = torch.zeros(n_input, n_classes)
        torch.nn.init.xavier_uniform_(
            self.W.unsqueeze(0)).squeeze(0)
        
        # Soglia BCM per ogni sinapsi (metaplasticita)
        # theta_ij = media mobile di y_j^2
        self.theta_bcm = torch.ones(n_classes) * 0.1
        
        # Storia attivazioni per BCM
        self.y_mean_sq = torch.ones(n_classes) * 0.1
    
    def forward(self, h: torch.Tensor) -> torch.Tensor:
        """
        h: (1, n_input) spike sum dal livello precedente
        Ritorna logits (1, n_classes)
        """
        return h @ self.W
    
    def predict(self, h: torch.Tensor) -> int:
        """Predizione online: argmax dei logits."""
        logits = self.forward(h)
        return int(logits.argmax(dim=1).item())
    
    def update_oja(self, h: torch.Tensor,
                   y: torch.Tensor) -> None:
        """
        Regola di Oja: apprendimento non supervisionato.
        Impara le direzioni principali dell'input.
        dW_ij = eta * (h_i * y_j - y_j^2 * W_ij)
        
        h: (1, n_input), y: (1, n_classes) output corrente
        """
        dev = self.W.device
        h_d = h.detach().to(dev)
        y_d = y.detach().to(dev)
        
        # Outer product: (n_input, n_classes)
        dW = h_d.T @ y_d
        # Termine di decadimento Oja: stabilizza i pesi
        decay = (y_d ** 2) * self.W
        self.W += self.eta_oja * (dW - decay)
    
    def update_dopamine(self, h: torch.Tensor,
                        pred: int, true_label: int,
                        da_signal: float) -> None:
        """
        Perceptrone modulato dalla dopamina.
        Aggiorna solo se la predizione e sbagliata.
        dW[:, pred] -= eta_da * DA * h  (scoraggia pred errata)
        dW[:, true] += eta_da * DA * h  (rinforza pred corretta)
        
        da_signal: segnale dopaminergico [0, 1]
        """
        if pred == true_label:
            return  # Nessun aggiornamento se corretto
        
        dev = self.W.device
        h_d = h.detach().to(dev).squeeze(0)
        
        # Penalizza la classe predetta erroneamente
        self.W[:, pred] -= self.eta_da * da_signal * h_d
        # Rinforza la classe corretta
        self.W[:, true_label] += (self.eta_da *
                                   da_signal * h_d)
    
    def update_bcm(self, h: torch.Tensor,
                   y: torch.Tensor) -> None:
        """
        Metaplasticita BCM (Bienenstock-Cooper-Munro 1982).
        La soglia theta di ogni neurone adatta la LR locale.
        dW_ij = eta * h_i * y_j * (y_j - theta_j)
        theta_j <- theta_j + (y_j^2 - theta_j) / tau_bcm
        
        Neuroni molto attivi alzano theta -> LR decresce
        Neuroni poco attivi abbassano theta -> LR cresce
        Equivalente biologico del momento secondo di Adam.
        """
        dev = self.W.device
        h_d = h.detach().to(dev).squeeze(0)
        y_d = y.detach().to(dev).squeeze(0)
        
        # BCM rule
        bcm_factor = y_d * (y_d - self.theta_bcm)
        dW = torch.outer(h_d, bcm_factor)
        self.W += self.eta_oja * dW
        
        # Aggiorna soglia BCM (media mobile di y^2)
        self.y_mean_sq = (self.y_mean_sq +
                          (y_d ** 2 - self.y_mean_sq)
                          / self.tau_bcm)
        self.theta_bcm = self.y_mean_sq.clone()
    
    def online_step_prospective(self, h: torch.Tensor,
                                true_label: int,
                                da_signal: float = 1.0) -> int:
        """
        Prospective Configuration (Song et al., Nature Neuroscience 2024).

        Due fasi esplicite prima di applicare la plasticita:

        Fase 1 -- Inferenza (free phase):
            Forward pass: y_inf = softmax(h @ W).
            BCM equilibration: la soglia theta si aggiorna su y_inf,
            modellando il settling dell'attivita verso un equilibrio
            libero prima di qualsiasi modifica sinaptica.

        Fase 2 -- Configurazione prospettica (nudged phase):
            y_prosp = (1 - beta) * y_inf + beta * y_one_hot
            dove beta = self.beta_prosp e il coefficiente di nudging.
            y_prosp e l'attivita che il network DOVREBBE avere
            se l'output fosse corretto (target clamping leggero).

        Fase 3 -- Plasticita:
            Oja con y_prosp (rinforza la direzione prospettica).
            DA-gate proporzionale a |y_prosp - y_inf| (errore di fase):
            quando la predizione e giusta, y_prosp ~ y_inf e nessun
            aggiornamento DA avviene. Quando sbaglia, l'errore di fase
            scala il segnale correttivo.

        h: (1, n_input)
        true_label: int
        da_signal: float [0,1]
        """
        dev = self.W.device

        # --- Fase 1: Inferenza ---
        logits = self.forward(h)
        y_inf = torch.softmax(logits, dim=1)
        pred = int(logits.argmax(dim=1).item())

        # BCM equilibration nella fase libera
        self.update_bcm(h, y_inf)

        # --- Fase 2: Configurazione prospettica ---
        y_one_hot = torch.zeros(1, self.n_classes, device=dev, dtype=self.W.dtype)
        y_one_hot[0, true_label] = 1.0
        y_prosp = (1.0 - self.beta_prosp) * y_inf.detach() + self.beta_prosp * y_one_hot

        # --- Fase 3: Plasticita ---
        # Oja sulla configurazione prospettica
        self.update_oja(h, y_prosp)

        # DA-gate: scala l'errore per la distanza inferenza-prospettica
        phase_error = (y_prosp - y_inf.detach()).abs().max().item()
        effective_da = da_signal * max(phase_error / (self.beta_prosp + 1e-6), 0.0)
        effective_da = min(effective_da, 3.0)  # clamp per stabilita
        self.update_dopamine(h, pred, true_label, effective_da)

        return pred

    def online_step(self, h: torch.Tensor,
                    true_label: int,
                    da_signal: float = 1.0) -> int:
        """
        Passo completo online: forward + update.
        Nessun batch, nessun optimizer, nessuna loss.

        Se use_prospective_config=True (default), delega a
        online_step_prospective che implementa il protocollo a due fasi
        di Song et al. (Nature Neuroscience 2024).

        h: (1, n_input)
        true_label: int (etichetta corrente)
        da_signal: segnale dopamina [0,1]

        Ritorna la predizione corrente.
        """
        if self.use_prospective_config:
            return self.online_step_prospective(h, true_label, da_signal)

        # --- Percorso legacy (use_prospective_config=False) ---
        logits = self.forward(h)
        y_pred = torch.softmax(logits, dim=1)
        pred = int(logits.argmax(dim=1).item())

        y_true = torch.zeros(1, self.n_classes,
                             device=self.W.device, dtype=self.W.dtype)
        y_true[0, true_label] = 1.0
        self.update_oja(h, y_true)
        self.update_bcm(h, y_pred)
        self.update_dopamine(h, pred, true_label, da_signal)

        return pred
    
    def to(self, device):
        self.W = self.W.to(device)
        self.theta_bcm = self.theta_bcm.to(device)
        self.y_mean_sq = self.y_mean_sq.to(device)
        return self


import threading


class DopamineController:
    """
    Gestisce la variabile DA (Dopamina) virtuale.
    DA non e' piu' legata all'accuratezza del classificatore:
    viene modulata da feedback causale esterno ("Felicita'").

    Usa threading.Lock per operazioni thread-safe tra WebcamThread e InputThread.
    """
    def __init__(self, base_da: float = 0.1, happy_boost: float = 0.9,
                 decay_rate: float = 0.02):
        self.DA = base_da
        self.base_da = base_da
        self.happy_boost = happy_boost
        self.decay_rate = decay_rate
        self._lock = threading.Lock()
        self._happy_event = threading.Event()

    def trigger_happiness(self, label: str = "") -> None:
        """Chiamato dal thread audio/tastiera quando l'utente esprime felicita'."""
        with self._lock:
            self.DA = self.happy_boost
        self._happy_event.set()
        print(f"[DOPAMINA] Spike DA={self.happy_boost:.2f} per oggetto: '{label}'")

    def decay_step(self) -> None:
        """
        Chiamato ogni tick del loop principale.
        Decade esponenzialmente verso base_da.
        Modula eta_mgd abbassando la soglia di plasticita' STDP.
        """
        with self._lock:
            self.DA = self.base_da + (self.DA - self.base_da) * (1.0 - self.decay_rate)
        self._happy_event.clear()

    @property
    def eta_mgd(self) -> float:
        """
        Learning rate geometrico MGD modulato dalla dopamina.
        DA alta -> eta alta -> plasticita' massima -> memorizzazione forzata.
        """
        with self._lock:
            return float(self.DA)

    def is_plastic(self, threshold: float = 0.5) -> bool:
        """True se il sistema e' in stato ad alta plasticita' (apprendimento attivo)."""
        with self._lock:
            return self.DA >= threshold
