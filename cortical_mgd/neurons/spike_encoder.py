# cortical_mgd/neurons/spike_encoder.py

import torch

def rank_order_encode(inputs: torch.Tensor, max_time: int) -> torch.Tensor:
    """
    Translates continuous inputs into spike trains using Rank-Order Coding.
    Higher values fire progressively earlier in the temporal window.
    
    Args:
        inputs (torch.Tensor): Continuous input data [batch_size, features] (normalized 0-1)
        max_time (int): Number of time steps.
        
    Returns:
        torch.Tensor: Spatiotemporal spikes [batch_size, features, max_time]
    """
    batch_size, features = inputs.shape
    
    # rank 0 per il valore più elevato (descending=True)
    ranks = torch.argsort(torch.argsort(inputs, dim=1, descending=True))
    
    spikes = torch.zeros(batch_size, features, max_time, device=inputs.device)
    
    # Assegniamo l'impulso al timestep pari al rank (saturando a max_time-1)
    t_idx = torch.clamp(ranks, 0, max_time - 1)
    spikes.scatter_(2, t_idx.unsqueeze(2), 1.0)
    
    return spikes

def rate_encode(inputs: torch.Tensor, max_time: int) -> torch.Tensor:
    """
    Translates continuous inputs into spike trains using Poisson Rate Coding.
    
    Args:
        inputs (torch.Tensor): Continuous input data [batch_size, features] (normalized 0-1)
        max_time (int): Number of time steps.
        
    Returns:
        torch.Tensor: Spatiotemporal spikes [batch_size, features, max_time]
    """
    batch_size, features = inputs.shape
    prob_matrix = inputs.unsqueeze(2).expand(batch_size, features, max_time)
    
    spikes = (torch.rand_like(prob_matrix) < prob_matrix).float()
    return spikes
