import pytest
import torch
import numpy as np
from cortical_mgd.core.mgd_metrics import compute_forman_ricci, compute_D_avg, compute_S_RT

def test_compute_forman_ricci_hyperbolic():
    # Star graph K_{1,5}: nodo centrale connesso a 5 foglie
    W = torch.zeros(6, 6)
    for i in range(1, 6):
        W[0, i] = W[i, 0] = 1.0
    kappa = compute_forman_ricci(W)
    assert kappa < -1.0, f"Star graph deve avere \kappa_F < -1.0, ottenuto {kappa}"

def test_compute_forman_ricci_euclidean():
    # Clique K_5: tutti connessi a tutti -> Forman 1D fortemente negativo
    W = torch.ones(5, 5) - torch.eye(5)
    kappa = compute_forman_ricci(W)
    assert kappa < -3.0, f"Clique deve avere \kappa_F < -3.0 con Forman, ottenuto {kappa}"

def test_compute_D_avg_capacity():
    W_disconn = torch.eye(10)       # D_avg = 10 (uniforme)
    torch.manual_seed(42)
    W_dense = torch.abs(torch.randn(10, 10))
    W_dense = (W_dense + W_dense.T) / 2
    
    d_disc  = compute_D_avg(W_disconn)
    d_dense = compute_D_avg(W_dense)
    
    assert d_disc > 8.0, f"Identità deve avere D_avg ≈ 10, ottenuto {d_disc:.3f}"
    assert d_dense < d_disc, f"Matrice densa ha D_avg minore dell'identità: {d_dense:.3f} vs {d_disc:.3f}"

def test_compute_S_RT_min_cut():
    W = torch.zeros(10, 10)
    for i in range(5):
        for j in range(5):
            if i != j:
                W[i, j] = 1.0
    for i in range(5, 10):
        for j in range(5, 10):
            if i != j:
                W[i, j] = 1.0
    W[4, 5] = W[5, 4] = 0.5
    
    s_rt = compute_S_RT(W, source_indices=list(range(5)), sink_indices=list(range(5, 10)))
    assert s_rt < 0.05, f"Barbell normalizzato deve essere piccolo, ottenuto {s_rt:.4f}"
    assert s_rt > 0.001, f"S_RT deve essere > 0, ottenuto {s_rt:.4f}"
