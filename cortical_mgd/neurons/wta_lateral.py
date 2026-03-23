# cortical_mgd/neurons/wta_lateral.py

import torch

def apply_wta_competition(spikes: torch.Tensor, potentials: torch.Tensor, k: int) -> torch.Tensor:
    """
    Applies strict k-Winner-Take-All lateral inhibition to a layer of spikes.
    If multiple neurons spike, only the top k (based on membrane potential) survive.
    
    Args:
        spikes (torch.Tensor): Binary spike tensor [batch_size, n_neurons].
        potentials (torch.Tensor): Membrane potentials [batch_size, n_neurons].
        k (int): Exact number of neurons allowed to fire.
        
    Returns:
        torch.Tensor: Filtered binary spikes [batch_size, n_neurons].
    """
    if k <= 0:
        return torch.zeros_like(spikes)
    if k >= spikes.shape[1]:
        return spikes
        
    _, top_k_idx = torch.topk(potentials, k, dim=1)
    mask = torch.zeros_like(spikes)
    mask.scatter_(1, top_k_idx, 1.0)
    
    return spikes * mask

def compute_dynamic_inhibition(membrane_potentials: torch.Tensor, target_sparsity: float = 0.05) -> torch.Tensor:
    """
    Computes a global symmetric inhibitory signal to maintain population sparsity constraint computationally.
    
    Args:
        membrane_potentials (torch.Tensor): Population potentials [batch_size, n_neurons]
        target_sparsity (float): Desired maximum fraction of active neurons.
        
    Returns:
        torch.Tensor: Global subtractive inhibitory term.
    """
    mean_pot = membrane_potentials.mean(dim=1, keepdim=True)
    # Scaliamo proporzionalmente in modo inverso all'obiettivo di sparsità
    # Maggiore la sparsità target (es. 0.05), maggiore l'inibizione.
    inhibition = mean_pot * ((1.0 - target_sparsity) / (target_sparsity + 1e-4)) * 0.1
    return torch.relu(inhibition)
