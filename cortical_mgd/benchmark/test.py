# test_quick_retention.py - mettilo nella root del progetto
import torch
import torch.nn as nn
from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.plasticity.stdp_local import STDPLocal
from cortical_mgd.plasticity.stdp_mgd import STDPMgd
from cortical_mgd.plasticity.homeostasis import apply_homeostatic_normalization
from cortical_mgd.architecture.modular_gate import ModularGate
from cortical_mgd.continual.replay_buffer import MGDReplayBuffer
from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite

torch.manual_seed(42)
suite = MGDBenchmarkSuite()
X1, y1 = suite._create_xor_task(64)
X2, y2 = suite._create_banded_task(64)

def train(col, readout, opt, X, y, gate, rep, t_idx, epochs=5):
    for e in range(epochs):
        kappa, d_avg = col.compute_mgd_metrics()
        for i in range(len(X)):
            x_s = X[i].unsqueeze(0)
            col.lif.reset_state()
            sum_s = torch.zeros(1, col.n_neurons)
            dW = 0
            col.train()
            for _ in range(3):
                sum_s += col(x_s)
                dW += col.stdp.compute_weight_update(kappa, d_avg, 2.0)
            if gate:
                dW = gate.apply_mask_to_dW(dW, t_idx)
            with torch.no_grad():
                col.W.add_(dW)
                if gate:
                    mask = gate.get_plastic_mask(t_idx).bool()
                    col.W.data[:, mask] = apply_homeostatic_normalization(
                        col.W.data[:, mask], 15.0)
                else:
                    col.W.data = apply_homeostatic_normalization(col.W.data, 15.0)
                col.W.data.clamp_(0, 5)
            readout.train(); opt.zero_grad()
            nn.CrossEntropyLoss()(readout(sum_s), y[i].unsqueeze(0)).backward()
            opt.step()
        if rep and e == epochs-1:
            rep.add_task(t_idx, X, y, col)
            for _, (Xr, yr) in rep.sample_replay(10):
                for i in range(len(Xr)):
                    col.lif.reset_state()
                    sr = torch.zeros(1, col.n_neurons)
                    dWr = 0
                    for _ in range(3):
                        sr += col(Xr[i].unsqueeze(0))
                        dWr += col.stdp.compute_weight_update(kappa, d_avg, 2.0)
                    dWr = gate.apply_mask_to_dW(dWr, t_idx)
                    with torch.no_grad():
                        col.W.add_(dWr * 0.3)
                        col.W.data.clamp_(0, 5)

def acc(col, readout, X, y):
    col.eval(); readout.eval(); c = 0
    with torch.no_grad():
        for i in range(len(X)):
            col.lif.reset_state()
            s = torch.zeros(1, col.n_neurons)
            for _ in range(3): s += col(X[i].unsqueeze(0))
            if readout(s).argmax() == y[i]: c += 1
    return c / len(X)

# A baseline
colA = CorticalColumn(200, 784, 0.1); colA.stdp = STDPLocal(784, 200)
roA = nn.Linear(200, 8); optA = torch.optim.Adam(roA.parameters(), 0.01)
train(colA, roA, optA, X1, y1, None, None, 0)
a1_before = acc(colA, roA, X1, y1)
train(colA, roA, optA, X2, y2, None, None, 1)
a1_after = acc(colA, roA, X1, y1)
print(f'A: T1_before={a1_before:.3f} T1_after={a1_after:.3f} forgetting={a1_before-a1_after:.3f}')

# D full
colD = CorticalColumn(200, 784, 0.1); colD.stdp = STDPMgd(784, 200)
roD = nn.Linear(200, 8); optD = torch.optim.Adam(roD.parameters(), 0.01)
gate = ModularGate(200, 4); rep = MGDReplayBuffer(50)
gate.register_task(0, colD, 0.3, 'low_variance')
train(colD, roD, optD, X1, y1, gate, rep, 0)
d1_before = acc(colD, roD, X1, y1)
gate.register_task(1, colD, 0.3, 'low_variance')
train(colD, roD, optD, X2, y2, gate, rep, 1)
d1_after = acc(colD, roD, X1, y1)
print(f'D: T1_before={d1_before:.3f} T1_after={d1_after:.3f} forgetting={d1_before-d1_after:.3f}')