# cortical_mgd/distillation/attention_extractor.py

import torch
import numpy as np
from cortical_mgd.core.mgd_metrics import (
    compute_forman_ricci, compute_D_avg, compute_S_RT)

def extract_geometric_targets(attention_matrices: list[torch.Tensor]) -> dict:
    """
    Parses LLM attention probability graphs to extract universal D_avg_llm, 
    kappa_llm, and S_RT_llm. These become the topological targets for the SNN.
    """
    D_list, k_list, S_list = [], [], []
    for A in attention_matrices:
        W = A.detach().cpu().numpy()
        # Assicurando safe bounds per la bipartizione S_RT
        half = A.shape[0] // 2 
        
        D_list.append(compute_D_avg(W))
        k_list.append(compute_forman_ricci(W))
        S_list.append(compute_S_RT(W, 
            list(range(half)), 
            list(range(half, A.shape[0]))))
            
    return {
        "D_avg_llm": float(np.mean(D_list)),
        "kappa_llm": float(np.mean(k_list)),
        "S_RT_llm":  float(np.mean(S_list))
    }
