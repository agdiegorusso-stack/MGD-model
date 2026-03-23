import pytest
import torch
from cortical_mgd.neurons.lif_adaptive import AdaptiveLIFGroup
from cortical_mgd.neurons.wta_lateral import apply_wta_competition, compute_dynamic_inhibition
from cortical_mgd.neurons.spike_encoder import rank_order_encode, rate_encode

def test_lif_group_adaptation():
    """Testa l'aumento del threshold per indurre sparsità dopo ripetuti spike."""
    lif = AdaptiveLIFGroup(n_neurons=5, tau_m=20.0, tau_adp=100.0, v_th_base=1.0, beta=1.8)
    
    # Stimolo costante e molto alto
    current = torch.tensor([[5.0, 5.0, 5.0, 5.0, 5.0]])
    
    spikes_total = 0
    for _ in range(5):
        spikes = lif(current)
        spikes_total += spikes.sum().item()
        
    # Senza adattamento: 5 step * 5 neuroni = 25 spikes.
    # Con theshold adattivo (beta=1.8): si fermano velocemente.
    assert spikes_total < 25.0, f"Adattamento non ha frenato gli spikes, totale: {spikes_total} (atteso < 25)"
    assert spikes_total > 0.0, "Nessuno spike sparato nonostante corrente forte (5.0)"

def test_wta_competition():
    """Testa che k-Winner-Take-All permetta gli spike limitatamente ai migliori k potenziali."""
    potentials = torch.tensor([[0.5, 0.9, 1.2, 0.3, 1.5]]) 
    spikes = torch.tensor([[1.0, 1.0, 1.0, 0.0, 1.0]]) # Tutti vorrebbero sparare (tranne index 3)
    
    # Sparsità fissata a k=2
    k = 2
    out_spikes = apply_wta_competition(spikes, potentials, k)
    
    assert out_spikes.sum().item() == 2, f"Attesi esattamente 2 neuroni attivi, ottenuti {out_spikes.sum().item()}"
    assert out_spikes[0, 4] == 1.0, "Il neurone con V max (1.5) doveva necessariamente sparare"
    assert out_spikes[0, 2] == 1.0, "Il secondo neurone max (1.2) doveva sparare"
    assert out_spikes[0, 1] == 0.0, "Il neurone con V 0.9 doveva essere inibito (fuori dai top 2)"

def test_compute_dynamic_inhibition():
    """Testa calcolo dell'inibizione sottrattiva globale per sparsità target."""
    potentials = torch.tensor([[1.5, 1.2, 0.9, 0.5, 0.1]])
    
    inh_strong = compute_dynamic_inhibition(potentials, target_sparsity=0.2) # k=1 (molto rigido)
    inh_weak = compute_dynamic_inhibition(potentials, target_sparsity=0.8) # k=4 (rilassato)
    
    assert torch.all(inh_strong >= inh_weak), "L'inibizione deve essere maggiore per una sparsità 0.2 rispetto a 0.8"

def test_spike_encoder_rank_order():
    """Testa encoding temporale Rank-Order: alto segnale genera spike precoci."""
    inputs = torch.tensor([[0.1, 0.9, 0.5]]) # batch 1, 3 features
    max_time = 3
    
    spikes = rank_order_encode(inputs, max_time)
    
    assert spikes.shape == (1, 3, 3), f"Shape scorretta: {spikes.shape}"
    
    # t=0: spara l'intensità massima (0.9, indice 1)
    assert spikes[0, 1, 0] == 1.0, "Feature alta 0.9 non ha sparato a t=0"
    
    # t=1: spara l'intensità media (0.5, indice 2)
    assert spikes[0, 2, 1] == 1.0, "Feature media 0.5 non ha sparato a t=1"
    
    # t=2: spara l'intensità debole (0.1, indice 0)
    assert spikes[0, 0, 2] == 1.0, "Feature debole 0.1 non ha sparato a t=2"
