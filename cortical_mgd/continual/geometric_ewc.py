# cortical_mgd/continual/geometric_ewc.py

import torch
import torch.nn as nn
from cortical_mgd.core.mgd_metrics import compute_D_avg_torch

class GeometricEWC:
    """
    Elastic Weight Consolidation where the standard Fisher Information Matrix 
    is REPLACED by structural importance derived from the gradient of D_avg.
    Versione GPU-native: usa torch.linalg.svd via compute_D_avg_torch.
    """
    def __init__(self, model: nn.Module, lambda_ewc: float = 100.0):
        self.model = model
        self.lambda_ewc = lambda_ewc

    def compute_importance(self, W: torch.Tensor) -> torch.Tensor:
        """
        Calcola l'importanza topologica tramite differenze finite per colonna:
            importance[:, j] = |∂D_avg / ∂W[:, j]|
        Loop su n_neurons colonne (es. 100 o 200), non su n_neurons * input_dim elementi.
        SVD su GPU via torch.linalg — nessun round-trip numpy.
        """
        device = W.device
        eps = 1e-4
        base = compute_D_avg_torch(W.detach())  # scalare torch su device
        imp = torch.zeros_like(W)

        for j in range(W.shape[1]):
            W_plus = W.detach().clone()
            W_plus[:, j] = W_plus[:, j] + eps
            d_plus = compute_D_avg_torch(W_plus)
            imp[:, j] = ((d_plus - base) / eps).abs()

        return imp

    def compute_ewc_loss(self, W: torch.Tensor, W_star: torch.Tensor, importance: torch.Tensor) -> torch.Tensor:
        """
        loss_ewc = lambda * sum(importance * (W - W_star)^2)
        """
        return self.lambda_ewc * (importance * (W - W_star)**2).sum()

