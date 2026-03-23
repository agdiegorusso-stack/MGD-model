# cortical_mgd/neurons/lif_adaptive.py

import torch
import torch.nn as nn
import math

class AdaptiveLIFGroup(nn.Module):
    """
    Leaky Integrate-and-Fire neuron group with threshold adaptation.
    Designed for brain-inspired computing requiring strict 1-5% sparsity dynamics.
    """
    def __init__(self, n_neurons: int, tau_m: float = 20.0, tau_adp: float = 100.0, 
                 v_th_base: float = 1.0, beta: float = 1.8):
        super().__init__()
        self.n_neurons = n_neurons
        self.tau_m = tau_m
        self.tau_adp = tau_adp
        self.v_th_base = v_th_base
        self.beta = beta
        
        self.dt = 1.0
        self.decay_m = math.exp(-self.dt / self.tau_m)
        self.decay_adp = math.exp(-self.dt / self.tau_adp)
        
        self.v = None
        self.a = None

    def forward(self, input_current: torch.Tensor) -> torch.Tensor:
        """
        Updates membrane potentials and adaptation variables, outputting spikes.
        
        Args:
            input_current (torch.Tensor): Input driving current [batch_size, n_neurons]
        
        Returns:
            torch.Tensor: Binary spikes {0, 1} [batch_size, n_neurons]
        """
        batch_size = input_current.size(0)
        
        if self.v is None or self.v.size(0) != batch_size:
            self.v = torch.zeros(batch_size, self.n_neurons, device=input_current.device)
            self.a = torch.zeros(batch_size, self.n_neurons, device=input_current.device)
            
        # Dinamica LIF del potenziale
        self.v = self.v * self.decay_m + input_current
        
        # Calcolo threshold adattivo
        v_th = self.v_th_base + self.beta * self.a
        
        # Spiking
        spikes = (self.v >= v_th).float()
        
        # Reset hard
        self.v = self.v * (1.0 - spikes)
        
        # Aggiornamento variabile di adattamento
        self.a = self.a * self.decay_adp + spikes
        
        return spikes
    
    def reset_state(self):
        """Resets membrane potentials and adaptation thresholds to base values."""
        self.v = None
        self.a = None
