# cortical_mgd/neurons/spike_encoder.py

import torch

def rank_order_encode(inputs: torch.Tensor, max_time: int) -> torch.Tensor:
    """
    Translates continuous inputs into spike trains using Rank-Order Coding.
    Higher values fire progressively earlier in the temporal window.
    
    Args:
        inputs (torch.Tensor): Continuous input data [batch_size, features] (normalized 0-1)
        max_time (int): Number of time steps.
        
    Returns:
        torch.Tensor: Spatiotemporal spikes [batch_size, features, max_time]
    """
    batch_size, features = inputs.shape
    
    # rank 0 per il valore più elevato (descending=True)
    ranks = torch.argsort(torch.argsort(inputs, dim=1, descending=True))
    
    spikes = torch.zeros(batch_size, features, max_time, device=inputs.device)
    
    # Assegniamo l'impulso al timestep pari al rank (saturando a max_time-1)
    t_idx = torch.clamp(ranks, 0, max_time - 1)
    spikes.scatter_(2, t_idx.unsqueeze(2), 1.0)
    
    return spikes

def rate_encode(inputs: torch.Tensor, max_time: int) -> torch.Tensor:
    """
    Translates continuous inputs into spike trains using Poisson Rate Coding.
    
    Args:
        inputs (torch.Tensor): Continuous input data [batch_size, features] (normalized 0-1)
        max_time (int): Number of time steps.
        
    Returns:
        torch.Tensor: Spatiotemporal spikes [batch_size, features, max_time]
    """
    batch_size, features = inputs.shape
    prob_matrix = inputs.unsqueeze(2).expand(batch_size, features, max_time)
    
    spikes = (torch.rand_like(prob_matrix) < prob_matrix).float()
    return spikes


import cv2
import numpy as np


class WebcamSpikeAdapter:
    """
    Adattatore OpenCV -> Spike Train per BioMGDBrain.
    Usa MOG2 background subtraction per estrarre solo pixel modificati
    (simula event-camera N-MNIST), poi rate-codes l'intensita in spike.
    """
    def __init__(self, target_size=(28, 28), threshold=30):
        self.target_size = target_size
        self.threshold = threshold
        self.bg_subtractor = cv2.createBackgroundSubtractorMOG2(
            history=100, varThreshold=threshold, detectShadows=False
        )

    def process_frame(self, frame_bgr: np.ndarray):
        """
        Ritorna (spike_train_numpy, motion_density).
        spike_train e' None se il frame non e' sufficientemente diverso dal precedente
        (keyframe gate, evita bottleneck von Neumann).
        """
        fg_mask = self.bg_subtractor.apply(frame_bgr)
        motion_density = float(np.mean(fg_mask > 0))

        if motion_density < 0.02:
            return None, motion_density

        masked = cv2.bitwise_and(frame_bgr, frame_bgr, mask=fg_mask)
        gray = cv2.cvtColor(masked, cv2.COLOR_BGR2GRAY)
        resized = cv2.resize(gray, self.target_size)
        normalized = resized.astype(np.float32) / 255.0
        flat = normalized.flatten()  # (784,) for 28x28

        # Poisson rate coding
        spike_train = (np.random.rand(*flat.shape) < flat).astype(np.float32)
        return spike_train, motion_density
