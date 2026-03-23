import pytest
import torch
import torch.nn as nn
from cortical_mgd.architecture.bio_mgd_brain import BioMGDBrain
from cortical_mgd.data.nmnist_loader import load_nmnist
import numpy as np

def test_nmnist_loader():
    try:
        dataset = load_nmnist(n_samples=10, split='train')
        events, target = dataset[0]
        print(f"\nNMNIST First Sample Shape (n_time_bins, polarity, w, h): {events.shape}")
        assert events.shape == (10, 2, 34, 34), f"Shape is {events.shape}"
        assert isinstance(target, int) or isinstance(target, np.integer)
    except Exception as e:
        pytest.fail(f"NMNIST loading failed: {e}")

def test_nmnist_biomgd_task5():
    # Integra G_BioMGDBrain con N-MNIST come Task 5
    # Senza toccare codice esistente, simuliamo il loop su NMNIST qui
    dataset = load_nmnist(n_samples=50, split='train')
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    
    # Prepara subset per test rapido
    indices = torch.randperm(len(dataset))[:50]
    subset = torch.utils.data.Subset(dataset, indices)
    loader = torch.utils.data.DataLoader(subset, batch_size=1, shuffle=False)
    
    # Inizializza G_BioMGDBrain (input 784, NMNIST raw è 10x2x34x34)
    g_brain = BioMGDBrain(input_dim=784).to(device)
    
    # Readout per Task 5 (index 4)
    t_idx = 4
    # Scegliamo col_s basato sul novelty factor che farà routing su A o B.
    # Ma calcoliamo novelty per il primo sample per stabilire l'area
    first_events, _ = next(iter(loader))
    
    # Conversion function per adattare [1, 10, 2, 34, 34] a [1, 10, 784]
    def nmnist_to_flat_28x28(x_b_t_c_h_w):
        # x shape: [batch, time, polarity, 34, 34]
        # Sum polarities
        x_sum = x_b_t_c_h_w.sum(dim=2) # [batch, time, 34, 34]
        # Center crop 28x28 (drop 3 pixels from each side)
        x_crop = x_sum[:, :, 3:31, 3:31] # [batch, time, 28, 28]
        # Flatten
        return x_crop.reshape(x_b_t_c_h_w.size(0), x_b_t_c_h_w.size(1), 784).float()
    
    x_flat = nmnist_to_flat_28x28(first_events).to(device)
    
    # Estraiamo x per novelty (sum of spikes or just 1 frame representation, let's take mean over time)
    x_rep = x_flat.mean(dim=1)
    
    # Route
    h_hip, novelty, eta_factor = g_brain.compute_novelty(x_rep)
    area = g_brain.route_by_srt(t_idx, None)
    
    hip, col, gate, replay, L2, gate_L2, L3, area = g_brain.get_routing_components(t_idx)
    
    readout = nn.Linear(col.n_neurons, 10).to(device)
    opt_r = torch.optim.Adam(readout.parameters(), lr=0.01)
    
    # Dummy training per dimostrare che il loop accetta i dati Task5
    hip.train(); col.train(); L2.train(); L3.train(); readout.train()
    
    kap_c, d_c = col.compute_mgd_metrics()
    
    # Process 5 samples as proof of life
    for i, (events, target) in enumerate(loader):
        if i >= 5: break
        
        x_flat = nmnist_to_flat_28x28(events).to(device)
        y = target.to(device)
        
        # Reset lifer states
        if hasattr(hip.lif, "reset_state"):
            hip.lif.reset_state(); col.lif.reset_state(); L2.lif.reset_state(); L3.lif.reset_state()
        else:
            hip.lif.v = None; hip.lif.a = None; col.lif.v = None; col.lif.a = None
            L2.lif.v = None; L2.lif.a = None; L3.lif.v = None; L3.lif.a = None
            
        sum_h1 = torch.zeros(1, col.n_neurons, device=device)
        
        # Process over time bins
        for t in range(x_flat.size(1)):
            x_t = x_flat[:, t, :] # [1, 784]
            h_hip, h1, h2, h3 = g_brain(x_t, t_idx)
            sum_h1 += h1
            
        # STDP (approximate per entire sequence for this test)
        dW_col = col.stdp.compute_weight_update(kap_c, d_c, 2.0)
        dW_col = gate.apply_mask_to_dW(dW_col, t_idx)
        
        with torch.no_grad():
            col.W.add_(dW_col)
            # Homeostasis on W
            pl_mask = gate.get_plastic_mask(t_idx).bool()
            # Simplistic homeostasis for test
            norm = torch.norm(col.W.data[:, pl_mask], p=2, dim=0, keepdim=True)
            scale = (15.0 / (norm + 1e-8)).clamp_(max=1.0)
            col.W.data[:, pl_mask] *= scale
            torch.clamp_(col.W.data, 0.0, 5.0)
            
        opt_r.zero_grad()
        loss = nn.CrossEntropyLoss()(readout(sum_h1), y)
        loss.backward()
        opt_r.step()
        
    print(f"\nTask5 (N-MNIST) integrated successfully on area {area}. Novelty: {novelty:.3f}, Eta: {eta_factor:.2f}")
    assert True
