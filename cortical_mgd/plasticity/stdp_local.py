# cortical_mgd/plasticity/stdp_local.py

import torch
import math

class STDPLocal:
    """
    Standard Spike-Timing Dependent Plasticity (Experimental Baseline).
    Tracks exact spike timings and issues weight updates blindly,
    with a completely constant learning rate.
    """
    def __init__(self, n_pre: int, n_post: int, eta_base: float = 0.01, 
                 tau_plus: float = 20.0, tau_minus: float = 20.0,
                 A_plus: float = 1.0, A_minus: float = 1.0):
        self.eta_base = eta_base
        self.A_plus = A_plus
        self.A_minus = A_minus
        
        dt = 1.0
        self.decay_plus = math.exp(-dt / tau_plus)
        self.decay_minus = math.exp(-dt / tau_minus)
        
        self.trace_pre = None
        self.trace_post = None

    def update_traces(self, pre_spikes: torch.Tensor, post_spikes: torch.Tensor):
        if self.trace_pre is None or self.trace_pre.shape != pre_spikes.shape:
            self.trace_pre = torch.zeros_like(pre_spikes)
            self.trace_post = torch.zeros_like(post_spikes)
            
        self.trace_pre *= self.decay_plus
        self.trace_post *= self.decay_minus
        
        self.trace_pre[pre_spikes == 1.0] += 1.0
        self.trace_post[post_spikes == 1.0] += 1.0
        
        self.last_pre_spikes = pre_spikes
        self.last_post_spikes = post_spikes

    def compute_weight_update(self, kappa: float = 0.0, D_avg: float = 1.0, D_target: float = 1.0) -> torch.Tensor:
        """
        Computes the target weight update (dW) using STDP baseline rules.
        Identical to MGD version, except eta strictly equals eta_base.
        """
        dW = (self.A_plus * self.trace_pre.T @ self.last_post_spikes) - \
             (self.A_minus * self.last_pre_spikes.T @ self.trace_post)
        
        dW_finale = self.eta_base * dW
        return dW_finale
