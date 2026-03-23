# cortical_mgd/architecture/cortical_brain.py

import torch
import torch.nn as nn
from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.architecture.modular_gate import ModularGate
from cortical_mgd.continual.replay_buffer import MGDReplayBuffer
from cortical_mgd.plasticity.stdp_mgd import STDPMgd


class CorticalBrain(nn.Module):
    """
    Sistema multi-area con routing automatico basato sulla densità dell'input.
    
    - Area sintetica (200 neuroni): task sparsi come XOR e Banded (density < 0.05)
    - Area visiva   (400 neuroni): task densi come MNIST       (density >= 0.05)
    
    I task vengono assegnati in modo permanente alla prima area che li riceve.
    Ogni area ha il proprio ModularGate e MGDReplayBuffer, quindi i neuroni
    di Task1 (XOR) non vengono mai disturbati dal training di Task3-4 (MNIST).
    """

    def __init__(self, input_dim: int = 784):
        super().__init__()

        # --- Area sintetica ---
        self.area_synthetic = CorticalColumn(200, input_dim, target_sparsity=0.1)
        self.area_synthetic.stdp = STDPMgd(input_dim, 200)
        self.gate_synthetic = ModularGate(n_neurons=200, n_tasks=30)
        self.replay_synthetic = MGDReplayBuffer(capacity_per_task=50)

        # --- Area visiva ---
        self.area_visual = CorticalColumn(400, input_dim, target_sparsity=0.1)
        self.area_visual.stdp = STDPMgd(input_dim, 400)
        self.gate_visual = ModularGate(n_neurons=400, n_tasks=30)
        self.replay_visual = MGDReplayBuffer(capacity_per_task=50)

        # Routing permanente per task: {task_id: 'synthetic' | 'visual'}
        self.task_routing: dict[int, str] = {}
        # Contatore locale per task già assegnati a ciascuna area
        self._area_task_count: dict[str, int] = {"synthetic": 0, "visual": 0}

    # ------------------------------------------------------------------
    # Routing
    # ------------------------------------------------------------------

    def register_task(self, task_id: int, X_sample: torch.Tensor) -> str:
        """
        Decide automaticamente quale area gestisce il task basandosi sulla
        densità media dell'input:
            density = (X_sample > 0.1).float().mean()
            density < 0.05  → area 'synthetic'
            density >= 0.05 → area 'visual'

        Registra il task nel corrispondente ModularGate (low_variance).
        Ritorna la stringa dell'area scelta.
        """
        # Calcola numero di feature con segnale (vs solo rumore)
        # Il rumore è N(0, 0.05) quindi var = 0.0025. Soglia = 0.01.
        varianze = X_sample.var(dim=0)
        active_features = (varianze > 0.01).sum().item()
        
        area = "synthetic" if active_features < 250 else "visual"
        self.task_routing[task_id] = area

        col = self.area_synthetic if area == "synthetic" else self.area_visual
        gate = self.gate_synthetic if area == "synthetic" else self.gate_visual
        gate.register_task(task_id, col, fraction=0.25, strategy="low_variance")

        self._area_task_count[area] += 1
        return area

    # ------------------------------------------------------------------
    # Forward
    # ------------------------------------------------------------------

    def forward(self, x: torch.Tensor, task_id: int) -> torch.Tensor:
        """Esegue il forward nell'area corretta per il task_id."""
        area = self.task_routing[task_id]
        if area == "synthetic":
            return self.area_synthetic(x)
        else:
            return self.area_visual(x)

    # ------------------------------------------------------------------
    # Accessori per gate / replay / area
    # ------------------------------------------------------------------

    def get_column(self, task_id: int) -> CorticalColumn:
        area = self.task_routing[task_id]
        return self.area_synthetic if area == "synthetic" else self.area_visual

    def get_gate(self, task_id: int) -> ModularGate:
        area = self.task_routing[task_id]
        return self.gate_synthetic if area == "synthetic" else self.gate_visual

    def get_replay(self, task_id: int) -> MGDReplayBuffer:
        area = self.task_routing[task_id]
        return self.replay_synthetic if area == "synthetic" else self.replay_visual

    def to(self, device):
        """Sposta entrambe le aree sul device."""
        self.area_synthetic.to(device)
        self.area_visual.to(device)
        return self
