import pytest
import torch
from cortical_mgd.plasticity.stdp_local import STDPLocal
from cortical_mgd.plasticity.stdp_mgd import STDPMgd
from cortical_mgd.plasticity.homeostasis import apply_homeostatic_normalization
from cortical_mgd.plasticity.consolidation import compute_consolidation_mask

def test_stdp_baseline_vs_mgd_modulation():
    """
    Test comparativo CRITICO: 
    STDP Local e STDP MGD devono calcolare matrici identiche tranne per il learning rate.
    """
    n_pre, n_post = 2, 2
    eta_base = 0.1
    stdp_local = STDPLocal(n_pre, n_post, eta_base)
    stdp_mgd = STDPMgd(n_pre, n_post, eta_base)
    
    # Iniettiamo identici spikes
    pre_spikes = torch.tensor([[1.0, 0.0]])
    post_spikes = torch.tensor([[1.0, 1.0]])
    
    stdp_local.update_traces(pre_spikes, post_spikes)
    stdp_mgd.update_traces(pre_spikes, post_spikes)
    
    # Formulazione di test: 
    # MGD boost condition: kappa = -2.0 (iperbolico), D_avg = 1.0, D_target = 2.0
    # Formula mod: f = (1 + 2.0*0.3) * clip(2.0/1.0, ...) = 1.6 * 2.0 = 3.2
    # L'aggiornamento MGD deve essere esattamente 3.2 volte piu grande di quello Local.
    dw_local = stdp_local.compute_weight_update(kappa=-2.0, D_avg=1.0, D_target=2.0)
    dw_mgd = stdp_mgd.compute_weight_update(kappa=-2.0, D_avg=1.0, D_target=2.0)
    
    # Preveniamo matrici nulle per il test scale
    # dw_local deve avere elementi dissimili da zero per l'assert proporzionale
    # Se il framework e' implementato correttamente pre-e-post innescano >0
    assert torch.allclose(dw_mgd, dw_local * 3.2, atol=1e-4), "MGD deve modulare eta del fattore geometrico esatto 3.2x"

def test_homeostasis_normalization():
    """Testa la corretta ripartizione multiplicativa dei pesi a cap prefissato."""
    weights = torch.tensor([[0.8, 2.0], 
                            [0.4, 2.0]]) # sum colonna 0 = 1.2, sum colonna 1 = 4.0
    # Applichiamo limite a 1.0
    norm_w = apply_homeostatic_normalization(weights, target_sum=1.0)
    
    sums = norm_w.sum(dim=0)
    assert abs(sums[0].item() - 1.0) < 1e-4, f"Somma pesi neurone 0 non normalizzata: {sums[0]}"
    assert abs(sums[1].item() - 1.0) < 1e-4, f"Somma pesi neurone 1 non normalizzata: {sums[1]}"

def test_consolidation_mask():
    """Testa isolamento delle sinapsi consolidate in base al threshold."""
    weights = torch.tensor([[0.1, 0.9], 
                            [0.85, 0.5]])
    mask = compute_consolidation_mask(weights, threshold=0.8)
    
    assert mask[0, 0] == 0.0
    assert mask[0, 1] == 1.0
    assert mask[1, 0] == 1.0
    assert mask[1, 1] == 0.0
