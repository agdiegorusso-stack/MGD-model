# cortical_mgd/plasticity/homeostasis.py

import torch

def apply_homeostatic_normalization(weight_matrix: torch.Tensor, target_sum: float = 1.0, dim: int = 1) -> torch.Tensor:
    """
    Restricts explosive weight growth by scaling the Fan-In for each post-synaptic neuron.
    Uses L1 norm to safely handle both excitatory and inhibitory weights.
    For nn.Linear (out, in), dim=1 normalizza Fan-In.
    For CorticalColumn (in, out), dim=0 normalizza Fan-In.
    """
    row_sums = weight_matrix.abs().sum(dim=dim, keepdim=True)
    return weight_matrix * (target_sum / (row_sums + 1e-10))
