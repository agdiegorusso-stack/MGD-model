import torch
import torch.nn as nn
from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite

def test_xor_learning():
    torch.manual_seed(42)
    col = CorticalColumn(n_neurons=100, input_dim=784, target_sparsity=0.1)
    col.stdp.A_minus = -0.1
    readout = nn.Linear(100, 4)
    opt = torch.optim.Adam(readout.parameters(), lr=0.01)
    
    suite = MGDBenchmarkSuite(n_neurons=100, input_dim=784)
    X, y = suite._create_xor_task(100)
    
    print("Starting XOR Test Loop...")
    for epoch in range(15):
        # We define a custom mini-train loop since suite._train_column_with_readout is not split out
        col.train()
        readout.train()
        for i in range(len(X)):
            x_s = X[i].unsqueeze(0)
            if hasattr(col.lif, "reset_state"): col.lif.reset_state()
            else: col.lif.v = None; col.lif.a = None
            
            sum_s = torch.zeros(1, col.n_neurons)
            dW_accum = 0
            for t in range(3):
                spks = col(x_s)
                sum_s += spks
                dW_accum += col.stdp.compute_weight_update()
            
            if epoch == 0 and i < 4:
                print(f"Sample {i} (label {y[i].item()}): spk_sum={sum_s.sum().item():.1f}, spk_max={sum_s.max().item():.1f}")
            
            with torch.no_grad():
                col.W.add_(dW_accum)
                # apply_homeostatic_normalization is in plasticity.homeostasis
                from cortical_mgd.plasticity.homeostasis import apply_homeostatic_normalization
                col.W.data = apply_homeostatic_normalization(col.W.data, target_sum=15.0)
                col.W.data.clamp_(0.0, 5.0)
                
            opt.zero_grad()
            logits = readout(sum_s)
            loss = nn.CrossEntropyLoss()(logits, y[i].unsqueeze(0))
            loss.backward()
            opt.step()
            
        correct = 0
        spike_sums = []
        with torch.no_grad():
            for i in range(len(X)):
                x_sample = X[i].unsqueeze(0)
                spike_sum = torch.zeros(1, col.n_neurons)
                if hasattr(col.lif, "reset_state"): col.lif.reset_state()
                else: col.lif.v = None; col.lif.a = None
                
                for t in range(3): spike_sum += col(x_sample)
                spike_sums.append(spike_sum)
                logits = readout(spike_sum)
                pred = logits.argmax(dim=1)
                if pred == y[i]: correct += 1
                
        spike_tns = torch.cat(spike_sums, dim=0)
        cov = spike_tns.std(dim=0).mean().item()
        acc = correct / len(X)
        
        # Test diretto corrente su primo campione
        x_0 = X[0].unsqueeze(0)
        curr_0 = x_0 @ col.W.data
        
        print(f'Epoch {epoch}: acc={acc:.3f}, cov={cov:.4f}, max_W={col.W.max().item():.3f}, curr_0_max={curr_0.max().item():.3f}, W_col_sum_avg={col.W.sum(0).mean().item():.3f}')

if __name__ == "__main__":
    test_xor_learning()
