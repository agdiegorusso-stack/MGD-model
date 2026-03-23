# cortical_mgd/architecture/hierarchy.py

import torch
import torch.nn as nn
from cortical_mgd.architecture.area import CorticalArea

class CorticalHierarchy(nn.Module):
    """
    The Macroscopic Topography.
    Governs a standard three-tier progression modeled after the Human Neocortex:
      - L1: Sensory input (small, agile columns, fast integration)
      - L2: Associative core (medium columns)
      - L3: Executive orchestrator (large columns, slow adaptation)
      
    Targets a global geometric layout with strictly hyperbolic (kappa < -0.3) topography.
    """
    def __init__(self, input_dim: int):
        super().__init__()
        # Target constraint architetturale
        self.kappa_target = -0.3
        
        self.L1 = CorticalArea(n_columns=2,  neurons_per_column=20,  input_dim=input_dim)
        self.L2 = CorticalArea(n_columns=4,  neurons_per_column=40,  input_dim=20)
        self.L3 = CorticalArea(n_columns=8,  neurons_per_column=80,  input_dim=40)
        
    def forward(self, sensory_input: torch.Tensor) -> torch.Tensor:
        """
        Progressively cascades activation stimuli across L1 -> L2 -> L3.
        Connectivity dynamically evaluates internal S_RT thresholds before transferring.
        """
        x1 = self.L1(sensory_input)
        x2 = self.L2(x1)
        x3 = self.L3(x2)
        return x3
