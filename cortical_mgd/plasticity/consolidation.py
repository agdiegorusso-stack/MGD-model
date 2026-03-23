# cortical_mgd/plasticity/consolidation.py

import torch

def compute_consolidation_mask(weight_matrix: torch.Tensor, threshold: float = 0.8) -> torch.Tensor:
    """
    Identifies high-value "mature" synaptic weights that should be protected 
    from aggressive forgetting (Continuous Learning stability).
    
    Args:
        weight_matrix (torch.Tensor): Structural weights [n_pre, n_post]
        threshold (float): Cutoff metric above which a weight is deemed 'consolidated'.
        
    Returns:
        torch.Tensor: Boolean/Binary mask denoting consolidated synapses.
    """
    return (weight_matrix >= threshold).float()
