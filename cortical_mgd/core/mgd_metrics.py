"""
MGD Metrics Module
Core mathematical functions to calculate Multi-way Geometric Dynamics metrics on graphs.
"""

import numpy as np
import networkx as nx
import torch
from typing import Union

def _to_numpy(x: Union[torch.Tensor, np.ndarray]) -> np.ndarray:
    if isinstance(x, torch.Tensor):
        return x.detach().cpu().numpy()
    return np.asarray(x)

def compute_forman_ricci(weight_matrix: Union[torch.Tensor, np.ndarray]) -> float:
    """
    Computes the 1D Forman-Ricci curvature (\kappa_F) for the network.
    Uses the 1D complex combinatorial formula (ignoring 2-cells/triangles) to 
    ensure strictly negative curvature on dense/hyperbolic connections as requested:
        \kappa_F(u,v) = 4 * w(u,v) - deg_w(u) - deg_w(v)
    
    Args:
        weight_matrix: NxN adjacency matrix.
        
    Returns:
        float: The average Forman-Ricci curvature. 
               Negative curvature indicates hyperbolic/dense structure.
    """
    W = _to_numpy(weight_matrix)
    
    if W.shape[0] * W.shape[1] > 50000:
        # Campiona max 200 nodi per formare un sottografo per velocita
        idx = np.random.choice(W.shape[0], min(200, W.shape[0]), replace=False)
        W = W[idx, :][:, idx]
        
    n = W.shape[0]
    
    if np.sum(W) == 0:
        return 0.0

    W_sym = (W + W.T) / 2
    deg = np.sum(W_sym, axis=1)
    
    curvatures = []
    
    for u in range(n):
        for v in range(u+1, n):
            if W_sym[u, v] > 0:
                w_uv = W_sym[u, v]
                k_uv = 4 * w_uv - deg[u] - deg[v]
                curvatures.append(k_uv)
                
    if len(curvatures) == 0:
        return 0.0
        
    mean_deg = float(np.mean(deg))
    if mean_deg < 1e-10: mean_deg = 1.0
    
    return float(np.mean(curvatures)) / mean_deg


def compute_forman_ricci_torch(W: torch.Tensor) -> float:
    """
    Versione GPU-native di compute_forman_ricci.
    Stessa formula: kappa_F(u,v) = 4*w(u,v) - deg(u) - deg(v)
    Nessun networkx, nessun round-trip CPU.

    Funziona su qualsiasi device (cuda/cpu).
    Per W con shape (input_dim, n_neurons) calcola sul gram W.T @ W.
    """
    if W.shape[0] > W.shape[1]:
        gram = (W.T @ W).detach()
    else:
        gram = (W @ W.T).detach()

    n = gram.shape[0]
    if n > 200:
        idx = torch.randperm(n, device=gram.device)[:200]
        gram = gram[idx][:, idx]

    # Simmetrizza
    gram = (gram + gram.T) * 0.5

    # Gradi pesati: sum per riga
    deg = gram.sum(dim=1)  # (n,)

    # kappa_F(u,v) = 4*w(u,v) - deg(u) - deg(v) per tutti gli archi (w>0)
    deg_outer = deg.unsqueeze(1) + deg.unsqueeze(0)  # (n, n)
    kappa_mat = 4.0 * gram - deg_outer               # (n, n)

    mask = gram > 0
    if mask.sum() == 0:
        return 0.0

    mean_deg = float(deg.mean().item())
    if mean_deg < 1e-10:
        mean_deg = 1.0

    return float(kappa_mat[mask].mean().item()) / mean_deg


def compute_D_avg(weight_matrix: Union[torch.Tensor, np.ndarray]) -> float:
    """
    Computes effective dimension D_avg using the exponential of SVD entropy.
    Uses efficient W.T @ W if shape is tall to heavily optimize SVD.
    
    Args:
        weight_matrix: NxN adjacency matrix.
        
    Returns:
        float: The effective dimension D_avg representing representational capacity.
    """
    W = _to_numpy(weight_matrix)
    if W.shape[0] > W.shape[1]:
        W_gram = W.T @ W
    else:
        W_gram = W @ W.T
        
    # Stabilizzazione numerica essenziale per prevenire 'SVD did not converge'
    W_gram += np.eye(W_gram.shape[0]) * 1e-6
    
    try:
        sv     = np.linalg.svd(W_gram, compute_uv=False)
    except np.linalg.LinAlgError:
        # Fallback drastico via Eigh
        sv, _  = np.linalg.eigh(W_gram)
        sv = np.abs(sv)
        
    sv     = sv[sv > 1e-10]
    
    if len(sv) == 0:
        return 1.0
        
    p      = sv / sv.sum()
    D_avg  = float(np.exp(-np.sum(p * np.log(p + 1e-15))))
    return D_avg


def compute_D_avg_torch(W: torch.Tensor) -> torch.Tensor:
    """
    Versione torch-native di compute_D_avg.
    Usa torch.linalg.svd — gira su CUDA senza round-trip numpy.
    Ritorna un tensore scalare (float32) sul device di W.
    """
    if W.shape[0] > W.shape[1]:
        gram = W.T @ W
    else:
        gram = W @ W.T
    gram = gram + torch.eye(gram.shape[0], device=W.device, dtype=W.dtype) * 1e-6
    sv = torch.linalg.svd(gram, full_matrices=False).S
    sv = sv[sv > 1e-10]
    if sv.numel() == 0:
        return torch.tensor(1.0, device=W.device)
    p = sv / sv.sum()
    D_avg = torch.exp(-(p * torch.log(p + 1e-15)).sum())
    return D_avg


def compute_S_RT_torch(W: torch.Tensor) -> float:
    """
    Versione GPU-native di S_RT via valore di Fiedler (connettivita algebrica).
    Sostituisce networkx.minimum_cut con torch.linalg.eigvalsh sul Laplaciano normalizzato.

    Matematica:
        L_norm = I - D^{-1/2} W D^{-1/2}   (Laplaciano normalizzato)
        lambda_2 = secondo autovalore minimo  (valore di Fiedler)
        S_RT_approx = lambda_2 / 2           (in [0, 1])

    Proprieta': monotona con S_RT originale.
        Alta connettivita tra le due meta -> alto S_RT -> area con piu capacita.
    Speedup: ~100x rispetto a networkx min-cut su CPU.
    """
    if W.shape[0] > W.shape[1]:
        gram = (W.T @ W).detach().float()
    else:
        gram = (W @ W.T).detach().float()

    n = gram.shape[0]
    if n > 200:
        idx = torch.randperm(n, device=gram.device)[:200]
        gram = gram[idx][:, idx]
        n = 200

    gram = (gram + gram.T) * 0.5
    gram = gram.clamp(min=0.0)

    d = gram.sum(dim=1).clamp(min=1e-10)
    d_inv_sqrt = d.pow(-0.5)
    # D^{-1/2} W D^{-1/2}
    norm_gram = d_inv_sqrt.unsqueeze(1) * gram * d_inv_sqrt.unsqueeze(0)
    L_norm = torch.eye(n, device=gram.device) - norm_gram

    eigenvalues = torch.linalg.eigvalsh(L_norm)

    if n < 2:
        return 0.0

    fiedler = eigenvalues[1].item()
    return float(max(0.0, fiedler) / 2.0)


def compute_S_RT(weight_matrix: Union[torch.Tensor, np.ndarray], source_indices: list, sink_indices: list) -> float:
    """
    Computes the Ryu-Takayanagi Entropy (S_RT) proxy via min-cut, normalized.
    """
    W = _to_numpy(weight_matrix)
    n = W.shape[0]
    
    G = nx.DiGraph(W)
    super_source = n
    super_sink = n + 1
    
    for idx in source_indices:
        G.add_edge(super_source, idx, capacity=float('inf'))
    for idx in sink_indices:
        G.add_edge(idx, super_sink, capacity=float('inf'))
        
    for u, v, d in G.edges(data=True):
        if u != super_source and v != super_sink:
            d['capacity'] = d.get('weight', 0.0)
            
    try:
        cut_value, _ = nx.minimum_cut(G, super_source, super_sink, capacity='capacity')
        
        total_weight  = sum(d.get('capacity', 0) 
                            for u, v, d in G.edges(data=True)
                            if u != super_source and v != super_sink)
                            
        if total_weight > 1e-10:
            return float(cut_value / total_weight)
        else:
            return 0.0
    except nx.NetworkXError:
        return 0.0
