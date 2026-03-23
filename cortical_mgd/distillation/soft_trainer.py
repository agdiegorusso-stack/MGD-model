# cortical_mgd/distillation/soft_trainer.py

import torch

class GeometricSoftTrainer:
    """
    Trains the Spiking Neural Network to mimic both the computational inference output 
    and the fundamental geometric structure of the large parameter Teacher LLM.
    """
    def __init__(self, lambda_D: float = 1.0, lambda_k: float = 1.0, lambda_S: float = 1.0):
        self.lambda_D = lambda_D
        self.lambda_k = lambda_k
        self.lambda_S = lambda_S

    def compute_loss(self, snn_output: torch.Tensor, soft_labels: torch.Tensor, 
                     D_avg_snn: float, D_avg_llm: float, 
                     kappa_snn: float, kappa_llm: float, 
                     S_RT_snn: float, S_RT_llm: float) -> tuple[torch.Tensor, dict]:
        """
        Total Distillation Loss = CE(snn_output, soft_labels) 
                                + lambda_D * (D_avg_snn - D_avg_llm)^2 
                                + lambda_k * max(0, kappa_snn - kappa_llm) 
                                + lambda_S * |S_RT_snn - S_RT_llm|
        """
        # CE con soft labels
        log_probs = torch.log(snn_output.clamp(min=1e-8))
        ce = -(soft_labels * log_probs).sum()
        
        pen_D = self.lambda_D * (D_avg_snn - D_avg_llm)**2
        pen_k = self.lambda_k * max(0.0, kappa_snn - kappa_llm)
        pen_S = self.lambda_S * abs(S_RT_snn - S_RT_llm)
        
        loss = ce + torch.tensor(pen_D + pen_k + pen_S)
        
        delta_geo = abs(D_avg_snn - D_avg_llm) / (D_avg_llm + 1e-10) \
                  + abs(kappa_snn - kappa_llm)
                  
        return loss, {"delta_geo": delta_geo, 
                      "pen_D": pen_D, 
                      "pen_k": pen_k, 
                      "pen_S": pen_S}
