import torch
import torch.nn as nn
import torch.nn.functional as F

from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.architecture.modular_gate import ModularGate
from cortical_mgd.continual.replay_buffer import MGDReplayBuffer

class HierarchicalBrain(nn.Module):
    def __init__(self, input_dim: int = 784, device: str = 'cuda'):
        """
        CorticalHierarchy a 3 livelli (Fase 2).
        L1, L2 separati per tipologia di input (sintetico vs visivo).
        L3 livello esecutivo condiviso.
        """
        super().__init__()
        
        # --- L1 (Sensoriale, Veloce, Locale) ---
        self.L1_synthetic = CorticalColumn(300, input_dim, target_sparsity=0.1)
        self.L1_visual    = CorticalColumn(600, input_dim, target_sparsity=0.1)
        
        self.gate_L1_syn   = ModularGate(300, 30)
        self.gate_L1_vis   = ModularGate(600, 30)
        
        self.replay_L1_syn = MGDReplayBuffer(50)
        self.replay_L1_vis = MGDReplayBuffer(50)
        
        # --- L2 (Associativo, Medio) ---
        self.L2_synthetic = CorticalColumn(500, input_dim=300, target_sparsity=0.1)
        self.L2_visual    = CorticalColumn(1000, input_dim=600, target_sparsity=0.1)
        
        self.gate_L2_syn   = ModularGate(500, 30)
        self.gate_L2_vis   = ModularGate(1000, 30)
        
        self.replay_L2_syn = MGDReplayBuffer(50)
        self.replay_L2_vis = MGDReplayBuffer(50)
        
        # --- L3 (Esecutivo, Lento, Condiviso) ---
        # Riceve 1000 input (da L2_visual, o da L2_synthetic con 500 padding)
        self.L3 = CorticalColumn(200, input_dim=1000, target_sparsity=0.1)
        # L3 non ha gate: è aggiornato completamente ed è la convergenza finale.
        
        # Gestione task
        self.task_routing = {} # iter -> 'synthetic' | 'visual'
        
    def to(self, device):
        """Sposta tutti i moduli su device."""
        self.L1_synthetic.to(device)
        self.L1_visual.to(device)
        self.L2_synthetic.to(device)
        self.L2_visual.to(device)
        self.L3.to(device)
        return self

    def register_task(self, task_id: int, X_sample: torch.Tensor) -> str:
        """
        Registra il task calcolando le active_features per smistare
        su 'synthetic' (< 250) o 'visual' (>= 250).
        Alloca neuroni sui gate dei livelli interessati.
        """
        varianze = X_sample.var(dim=0)
        active_features = (varianze > 0.01).sum().item()
        
        area = 'synthetic' if active_features < 250 else 'visual'
        self.task_routing[task_id] = area
        
        fraction = 0.25
        if area == 'synthetic':
            self.gate_L1_syn.register_task(task_id, self.L1_synthetic, fraction, strategy="low_variance")
            self.gate_L2_syn.register_task(task_id, self.L2_synthetic, fraction, strategy="low_variance")
        else:
            self.gate_L1_vis.register_task(task_id, self.L1_visual, fraction, strategy="low_variance")
            self.gate_L2_vis.register_task(task_id, self.L2_visual, fraction, strategy="low_variance")
            
        return area
        
    def forward(self, x: torch.Tensor, task_id: int) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """
        Ritorna le spike generate ad ogni livello (h1, h2, h3).
        x dev'essere unsqueezed [1, input_dim].
        Assicurarsi che chi chiama passi x già splittato sui timestep (qui facciamo inferenza singola).
        """
        area = self.task_routing[task_id]
        
        if area == 'synthetic':
            h1 = self.L1_synthetic(x)
            
            # STDP locale: disconnessione dei gradienti tramite detach()
            h2 = self.L2_synthetic(h1.detach())
            
            # Padding da 500 a 1000 per dare input compatibile all'L3
            h2_padded = F.pad(h2.detach(), (0, 500))
            
            h3 = self.L3(h2_padded)
        else:
            h1 = self.L1_visual(x)
            
            h2 = self.L2_visual(h1.detach())
            
            # Nessun padding necessario, l'output visual ha già size 1000
            h2_padded = h2.detach()
            
            h3 = self.L3(h2_padded)
            
        return h1, h2, h3

    def get_routing_components(self, task_id: int):
        """Helper function per il training loop: ritorna le componenti corrette in base all'area."""
        area = self.task_routing[task_id]
        if area == 'synthetic':
            return (self.L1_synthetic, self.gate_L1_syn, self.replay_L1_syn,
                    self.L2_synthetic, self.gate_L2_syn, self.replay_L2_syn,
                    self.L3, area, self.L1_synthetic)
        else:
            return (self.L1_visual, self.gate_L1_vis, self.replay_L1_vis,
                    self.L2_visual, self.gate_L2_vis, self.replay_L2_vis,
                    self.L3, area, self.L3)
