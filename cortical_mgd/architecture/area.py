# cortical_mgd/architecture/area.py

import torch
import torch.nn as nn
from typing import List
from cortical_mgd.architecture.cortical_column import CorticalColumn

class CorticalArea(nn.Module):
    """
    Cortical Area: an ensemble of N CorticalColumns interacting via sparse lateral connectivity.
    """
    def __init__(self, n_columns: int, neurons_per_column: int, input_dim: int, sparsity: float = 0.2):
        super().__init__()
        self.n_columns = n_columns
        self.neurons_per_column = neurons_per_column
        
        self.columns = nn.ModuleList([
            CorticalColumn(neurons_per_column, input_dim)
            for _ in range(n_columns)
        ])
        # Maschera connettività sparsa tra colonne
        self.lateral_mask = (torch.rand(n_columns, n_columns) < sparsity).float()
        
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Propagates stimulus horizontally across embedded columns, mediated 
        by lateral graph connectivity and internally governed by S_RT boundaries.
        """
        # Processa input su ogni colonna in parallelo
        outputs = torch.stack([col(x) for col in self.columns], dim=1)
        # Mean pooling come output dell'area
        return outputs.mean(dim=1)
