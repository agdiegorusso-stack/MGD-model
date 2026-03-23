# cortical_mgd/continual/mgd_consolidation.py

import torch
from cortical_mgd.plasticity.consolidation import compute_consolidation_mask

class MGDConsolidation:
    """Consolidates weights dynamically based on geometric stability thresholds."""
    def __init__(self, consolidation_threshold: float = 0.8):
        self.threshold = consolidation_threshold
        
    def get_consolidation_mask(self, W: torch.Tensor) -> torch.Tensor:
        """
        Returns binary mask defining which synapses exceeded the structural stability threshold.
        """
        return compute_consolidation_mask(W, self.threshold)
