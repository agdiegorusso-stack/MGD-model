# cortical_mgd/architecture/routing.py

import torch
from typing import Any
from cortical_mgd.core.mgd_metrics import compute_S_RT

def route_via_S_RT(candidate_areas: list, input_tensor: torch.Tensor, 
                   capacities: torch.Tensor, source: int, target: int, threshold: float = 0.1) -> Any:
    """
    Ryu-Takayanagi Entropy Routing Mechanism.
    Decides whether an informational payload can propagate dynamically between two distinct areas,
    measuring whether S_RT (graph min-cut information bottleneck) exceeds the minimum capacity threshold.
    
    Args:
        candidate_areas: Possible jump destinations.
        input_tensor: Information spikes payloads.
        capacities: Adjacency/Capacity graph matrix governing the global architecture [N_areas, N_areas].
        source: Source node index in the capacity matrix.
        target: Target destination index.
        threshold: Strict capacity minimum cutoff (default 0.1).
        
    Returns:
        The routed output tensor, or None if routing gets blocked (S_RT < threshold).
    """
    s_rt = compute_S_RT(capacities.detach().cpu().numpy(),
                        source_indices=[source],
                        sink_indices=[target])
    
    if s_rt < threshold:
        return None
        
    return input_tensor
