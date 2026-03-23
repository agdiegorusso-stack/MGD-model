import torch
import torch.nn as nn
from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.plasticity.stdp_local import STDPLocal
from cortical_mgd.plasticity.homeostasis import apply_homeostatic_normalization

column = CorticalColumn(n_neurons=100, input_dim=784, target_sparsity=0.1)
column.stdp = STDPLocal(784, 100)

X_s = torch.tensor([[0,0], [0,1], [1,0], [1,1]]).float()
X = torch.zeros(4, 784)
X[:, :2] = X_s * 60.0

print("INITIAL W MAX:", column.W.max().item(), "MEAN:", column.W.mean().item())
print("INITIAL COL SUM:", column.W.sum(dim=0).mean().item())

# Applico 1 volta homeostasis per simulare l'inizio (come succede alla Epoch 0 nel loop reale)
column.W.data = apply_homeostatic_normalization(column.W.data, target_sum=15.0)
print("AFTER HOMEO W MAX:", column.W.max().item(), "MEAN:", column.W.mean().item())

print("\n--- TEST FORWARD ---")
for i in range(4):
    x_s = X[i].unsqueeze(0)
    print(f"\nSAMPLE {i} (X_s=[{X_s[0,0]},{X_s[0,1]}]):")
    if hasattr(column.lif, "reset_state"): column.lif.reset_state()
    else: column.lif.v = None; column.lif.a = None
    
    for t in range(3):
        current = x_s @ column.W.data
        spks = column(x_s)
        print(f" t={t}: current_max={current.max().item():.3f}, spks_sum={spks.sum().item()}")
        
print("\n--- TEST LEARNING ---")
for epoch in range(5):
    column.train()
    for i in range(4):
        x_s = X[i].unsqueeze(0)
        if hasattr(column.lif, "reset_state"): column.lif.reset_state()
        else: column.lif.v = None; column.lif.a = None
        for t in range(3):
            spks = column(x_s)
            dW = column.stdp.compute_weight_update()
            column.W.data.add_(dW)
            column.W.data = apply_homeostatic_normalization(column.W.data, target_sum=15.0)
            column.W.data.clamp_(0.0, 5.0)
            
print("\n--- TEST FORWARD AFTER ALGORITHM ---")
for i in range(4):
    x_s = X[i].unsqueeze(0)
    print(f"\nSAMPLE {i} (X_s=[{X_s[0,0]},{X_s[0,1]}]):")
    if hasattr(column.lif, "reset_state"): column.lif.reset_state()
    else: column.lif.v = None; column.lif.a = None
    sum_s = 0
    for t in range(3):
        current = x_s @ column.W.data
        spks = column(x_s)
        sum_s += spks.sum().item()
        print(f" t={t}: current_max={current.max().item():.3f}, spks_sum={spks.sum().item()}")
    print(" Total spikes for this sample:", sum_s)
