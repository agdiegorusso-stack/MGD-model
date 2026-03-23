import pytest
import torch
import numpy as np
from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.architecture.area import CorticalArea
from cortical_mgd.architecture.hierarchy import CorticalHierarchy
from cortical_mgd.architecture.routing import route_via_S_RT

def test_cortical_column_sparsity_and_metrics():
    """Validazione della rigidità computazionale WTA nella CorticalColumn."""
    # Impostiamo il rigido vincolo di sparsity del 5% per il checkout
    col = CorticalColumn(n_neurons=100, input_dim=50, target_sparsity=0.05)
    
    inputs = torch.randn(1, 50) # Batch di 1 sample
    spikes_out = col(inputs)
    
    # Su 100 neuroni, uno sparsity del 5% significa MASSIMO 5 neuroni accesi
    attivati = spikes_out.sum().item()
    assert attivati <= 5.0, f"Sparsità post-WTA fallita: ammessi max 5.0, fuoco effettivo {attivati}"
    
    # Verifica calcolo dinamico interne
    kappa, d_avg = col.compute_mgd_metrics()
    assert isinstance(kappa, float)
    assert d_avg > 0.0

def test_route_via_S_RT_blocking():
    """Valida il blocco del routing qualora l'entropia della capacità crolli sotto la soglia."""
    areas = ["MockArea_0", "MockArea_1"]
    
    # Essendo compute_S_RT() NORMALIZZATO (divide per total weight):
    # adj_weak: 4 nodi con un bottleneck strettissimo tra 0 e 1, ma pesi forti altrove.
    # min_cut=0.001, total_weight=~20. S_RT normalizzata ~= 0.00005 < 0.1
    adj_weak = torch.tensor([
        [0.0, 0.001, 0.0, 0.0],
        [0.001, 0.0, 5.0, 5.0],
        [0.0, 5.0, 0.0, 5.0],
        [0.0, 5.0, 5.0, 0.0]
    ])
    
    # adj_strong: 2 nodi forti. S_RT = 5/10 = 0.5 > 0.1
    adj_strong = torch.tensor([[0.0, 5.0], [5.0, 0.0]])
    
    payload = torch.tensor([[1.0, 2.0]])
    
    # La rotta su grafo debole bloccherà istantaneamente il tracciato 0 -> 1
    routed_block = route_via_S_RT(areas, payload, capacities=adj_weak, source=0, target=1, threshold=0.1)
    assert routed_block is None, "Il Router doveva estinguere il segnale: Capacità RT normalizzata insufficiente."
    
    # La rotta su strong consentirà il passaggio del tensore originario
    routed_pass = route_via_S_RT(areas, payload, capacities=adj_strong, source=0, target=1, threshold=0.1)
    assert routed_pass is not None
    assert torch.allclose(routed_pass, payload), "Il Router doveva propagare inalterato il payload col verde S_RT."

def test_hierarchy_level_constraints_and_kappa():
    """Autentica che i tre Livelli L1-L3 onorino il crescendo di scale e il limite MGD <-0.3."""
    net = CorticalHierarchy(input_dim=10)
    
    # Controllo architettonico dimensionale
    assert hasattr(net, 'L1') and hasattr(net, 'L3')
    
    # L1 deve essere strutturalmente più "leggera/veloce" di L3
    # Meno neuroni o meno colonne per L1
    l1_complexity = net.L1.n_columns * net.L1.neurons_per_column
    l3_complexity = net.L3.n_columns * net.L3.neurons_per_column
    assert l1_complexity < l3_complexity, f"Violazione della scala cerebrale: L1 ({l1_complexity}) non è più piccolo di L3 ({l3_complexity})"
    
    # Assicuriamo che la gerarchia tracci l'iperbolico richiesto in target
    assert net.kappa_target <= -0.3, "La macro-struttura deve forzare tassativamente asintoti MGD <= -0.3"
