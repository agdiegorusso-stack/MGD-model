import pytest
import torch
import numpy as np

from cortical_mgd.continual.geometric_ewc import GeometricEWC
from cortical_mgd.distillation.soft_trainer import GeometricSoftTrainer
from cortical_mgd.distillation.llm_interface import OllamaInterface

def test_geometric_ewc_formula():
    """Valida l'algebra vettoriale e pesata della nuova EWC Geometrica."""
    ewc = GeometricEWC(model=None, lambda_ewc=10.0)
    
    # Tensore importanza campionato dai gradienti del D_avg
    importance = torch.tensor([[0.5, 2.0]])
    W = torch.tensor([[1.0, 2.0]])
    W_star = torch.tensor([[1.0, 0.0]])
    
    # Elaborazione matematica aspettata:
    # penalty = 10.0 * ( 0.5 * (1-1)^2 + 2.0 * (2-0)^2 )
    # penalty = 10.0 * ( 0.0 + 2.0 * 4.0 ) = 10.0 * 8.0 = 80.0
    loss = ewc.compute_ewc_loss(W, W_star, importance)
    assert abs(loss.item() - 80.0) < 1e-4, f"EWC Geometrica erra nel calcolo penalità: exp 80.0, got {loss.item()}"

def test_ollama_fallback():
    """Testa che l'interfaccia non imploda e produca distribuzioni sintetiche se Ollama locale è offline."""
    api = OllamaInterface(model_name="llama3_mock_offline", base_url="http://localhost:invalid")
    assert not api.is_available()
    
    # Deve ritornare un fallback dummy matrix valido
    att = api.get_attention_weights("test")
    assert isinstance(att, list)
    assert len(att) > 0
    assert torch.is_tensor(att[0])

def test_distillation_loss_geometric_components():
    """Verifica millimetricamente il combinatore loss MGD (CE + \lambda_D + \lambda_k + \lambda_S)."""
    trainer = GeometricSoftTrainer(lambda_D=2.0, lambda_k=3.0, lambda_S=1.0)
    
    # Creiamo target probabilistici uguali per azzerare concettualmente la CE
    snn_out = torch.tensor([[1.0]])
    soft_label = torch.tensor([[1.0]])
    
    # Penalità D_avg: lambda_D * (D_snn(3.0) - D_llm(1.0))^2 = 2.0 * 4.0 = 8.0
    # Penalità kappa: lambda_k * max(0, k_snn(-0.5) - k_llm(-1.0)) = 3.0 * max(0, 0.5) = 1.5
    # Penalità S_RT: lambda_S * |S_snn(0.8) - S_llm(0.2)| = 1.0 * 0.6 = 0.6
    # SOMMA LOSS GEOMETRICA EXPECTED = 10.1
    # 
    # Delta_Geo EXPECTED = |3.0-1.0|/1.0 + |-0.5 - (-1.0)| = 2.0 + 0.5 = 2.5
    
    loss, metrics = trainer.compute_loss(
        snn_output=snn_out, soft_labels=soft_label,
        D_avg_snn=3.0, D_avg_llm=1.0,
        kappa_snn=-0.5, kappa_llm=-1.0,
        S_RT_snn=0.8, S_RT_llm=0.2
    )
    
    # Verifichiamo la loss geometrica spuria depurata della CE basica (per semplificare il test, CE=0 o ~0)
    # Assumiamo l'implementation uses standard CE or MSE, but for identical 1.0 vectors it's 0.0
    assert abs(loss.item() - 10.1) < 1e-3, f"Loss Geometrica non allineata alla formula target, exp 10.1 got {loss.item()}"
    assert abs(metrics["delta_geo"] - 2.5) < 1e-4, f"Metrica delta_geo errata, exp 2.5 got {metrics['delta_geo']}"
