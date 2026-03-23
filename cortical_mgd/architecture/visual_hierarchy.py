# cortical_mgd/architecture/visual_hierarchy.py
#
# Gerarchia visiva biologica V1 -> V2 -> V4 -> IT
# Hubel & Wiesel 1962, Felleman & Van Essen 1991, Tanaka 1996
#
# Input:  (B, 3, 32, 32) immagini normalizzate in [0,1]
# Output: (B, 512)       rappresentazione oggetti sparsa, invariante posizione
#
# Ogni livello:
#   Conv2d (pesi >= 0, init uniforme piccolo)
#   LIF adattativi -> spike binari {0,1}
#   WTA tra canali per ogni posizione spaziale
#   STDP Hebbiana locale: correlazione patch-pre con post-spike

import torch
import torch.nn as nn
import torch.nn.functional as F
from cortical_mgd.neurons.lif_adaptive import AdaptiveLIFGroup
from cortical_mgd.plasticity.homeostasis import apply_homeostatic_normalization

class LIFConv(nn.Module):
    def __init__(self, tau_m=20.0, tau_a=200.0, beta=0.1, v_th=1.0):
        super().__init__()
        self.decay = 1.0 - 1.0 / tau_m
        self.decay_a = 1.0 - 1.0 / tau_a
        self.beta = beta
        self.v_th = v_th
        self.v = None
        self.a = None

    def reset_state(self):
        self.v = None
        self.a = None

    def forward(self, current):
        if self.v is None or self.v.shape != current.shape:
            self.v = torch.zeros_like(current)
            self.a = torch.zeros_like(current)
        self.v = self.v * self.decay + current
        th = self.v_th + self.beta * self.a
        spikes = (self.v >= th).float()
        self.v = self.v * (1.0 - spikes)
        self.a = self.a * self.decay_a + spikes
        return spikes

def wta_spatial(current, k_frac, freq_penalty=None):
    B, C, H, W = current.shape
    k = max(1, int(C * k_frac))
    c = current.reshape(B, C, H * W).clone()
    if freq_penalty is not None:
        c = c * torch.exp(-freq_penalty.view(1, C, 1) * 2.0)
    _, top_idx = torch.topk(c, k, dim=1)
    mask = torch.zeros_like(c).scatter_(1, top_idx, 1.0)
    return mask.reshape(B, C, H, W)

class ConvSNNLayer(nn.Module):
    def __init__(self, in_ch, out_ch, kernel=3, stride=1, padding=1, sparsity=0.1, tau_m=20.0):
        super().__init__()
        self.conv = nn.Conv2d(in_ch, out_ch, kernel, stride, padding, bias=False)
        nn.init.uniform_(self.conv.weight, -0.05, 0.05)
        w_flat = self.conv.weight.data.view(out_ch, -1)
        self.conv.weight.data = apply_homeostatic_normalization(w_flat, target_sum=0.5 * w_flat.shape[1]).view(out_ch, in_ch, kernel, kernel)
        self.lif = LIFConv(tau_m=tau_m)
        self.sparsity = sparsity
        self.stride = stride
        self.kernel = kernel
        self.padding = padding
        self.register_buffer('freq_penalty', torch.zeros(out_ch))

    def forward(self, x):
        current = self.conv(x)
        current = F.relu(current)
        spikes = wta_spatial(current, self.sparsity, self.freq_penalty)
        self.lif(current)
        
        if self.training:
            with torch.no_grad():
                s_mean = spikes.mean(dim=(0, 2, 3))
                self.freq_penalty.mul_(0.9).add_(s_mean)
        return spikes

    def reset_state(self):
        self.lif.reset_state()

    @torch.no_grad()
    def stdp_update(self, x_pre, spikes_post, eta):
        B, C_in = x_pre.shape[0], x_pre.shape[1]
        C_out, H_out, W_out = (spikes_post.shape[1], spikes_post.shape[2], spikes_post.shape[3])
        x_unfold = F.unfold(x_pre, kernel_size=self.kernel, stride=self.stride, padding=self.padding)
        s_flat = spikes_post.reshape(B, C_out, H_out * W_out)
        dW = torch.bmm(s_flat, x_unfold.transpose(1, 2)).mean(0)
        dW = dW.view(C_out, C_in, self.kernel, self.kernel)
        
        # Oja's decay term to enforce competition and stop batch average identicality
        s_mean = s_flat.mean(dim=(0, 2)).view(C_out, 1, 1, 1)
        decay = s_mean * self.conv.weight.data
        
        self.conv.weight.add_((dW - decay) * eta)
        self.conv.weight.clamp_(-2.0, 5.0)
        w_flat = self.conv.weight.data.view(C_out, -1)
        self.conv.weight.data = apply_homeostatic_normalization(w_flat, target_sum=0.5 * w_flat.shape[1]).view(C_out, C_in, self.kernel, self.kernel)

class DenseSNNLayer(nn.Module):
    def __init__(self, in_dim, out_dim, sparsity=0.05):
        super().__init__()
        self.linear = nn.Linear(in_dim, out_dim, bias=False)
        nn.init.uniform_(self.linear.weight, -0.05, 0.05)
        self.linear.weight.data = apply_homeostatic_normalization(self.linear.weight.data, target_sum=15.0)
        self.lif = AdaptiveLIFGroup(out_dim, tau_m=20.0)
        self.k = max(1, int(out_dim * sparsity))
        self.register_buffer('freq_penalty', torch.zeros(out_dim))

    def forward(self, x, bias=None):
        current = self.linear(x)
        self.lif(current)
        guided = current * torch.exp(-self.freq_penalty.unsqueeze(0) * 2.0)
        if bias is not None:
            guided = guided + bias * 5.0
        _, top_idx = torch.topk(guided, self.k, dim=1)
        spikes = torch.zeros_like(current).scatter_(1, top_idx, 1.0)
        
        if self.training:
            with torch.no_grad():
                self.freq_penalty.mul_(0.9).add_(spikes.mean(dim=0))
        return spikes

    def reset_state(self):
        self.lif.reset_state()
        
    @torch.no_grad()
    def stdp_update(self, x_pre, spikes_post, eta):
        dW = spikes_post.T @ x_pre
        # Oja's decay term
        out_active = spikes_post.sum(dim=0).unsqueeze(1)
        decay = out_active * self.linear.weight.data
        
        self.linear.weight.add_((dW - decay) * eta)
        self.linear.weight.clamp_(-2.0, 5.0)
        self.linear.weight.data = apply_homeostatic_normalization(self.linear.weight.data, target_sum=15.0)

class OccipitalCortex(nn.Module):
    def __init__(self):
        super().__init__()
        self.v1 = ConvSNNLayer(3, 32, stride=1, sparsity=0.1)
        self.v2 = ConvSNNLayer(32, 64, stride=2, sparsity=0.1)
        self.v3 = ConvSNNLayer(64, 128, stride=2, sparsity=0.1)
        
    def forward(self, x):
        h1 = self.v1(x)
        h2 = self.v2(h1)
        h3 = self.v3(h2)
        return h1, h2, h3
        
    def reset_state(self):
        self.v1.reset_state()
        self.v2.reset_state()
        self.v3.reset_state()
        
    @torch.no_grad()
    def stdp_update(self, x, h1, h2, h3, eta_v1, eta_v2, eta_v3):
        self.v1.stdp_update(x, h1, eta_v1)
        self.v2.stdp_update(h1, h2, eta_v2)
        self.v3.stdp_update(h2, h3, eta_v3)

class VentralStream(nn.Module):
    def __init__(self):
        super().__init__()
        self.v4 = ConvSNNLayer(128, 256, stride=2, sparsity=0.1)
        self.it = DenseSNNLayer(256, 512, sparsity=0.08)
        
    def forward(self, h3, bias=None):
        h4 = self.v4(h3)
        pooled = h4.mean(dim=[2, 3])
        return self.it(pooled, bias=bias), h4, pooled
        
    def reset_state(self):
        self.v4.reset_state()
        self.it.reset_state()
        
    @torch.no_grad()
    def stdp_update(self, h3, h4, pooled, it_spikes, eta_v4, eta_it):
        self.v4.stdp_update(h3, h4, eta_v4)
        self.it.stdp_update(pooled, it_spikes, eta_it)

class DorsalStream(nn.Module):
    def __init__(self):
        super().__init__()
        self.v5 = ConvSNNLayer(128, 256, stride=2, sparsity=0.1)
        self.parietal = DenseSNNLayer(256, 512, sparsity=0.08)
        
    def forward(self, h3, bias=None):
        h5 = self.v5(h3)
        # Pooling differenziato per Dorsal per catturare gradienti/posizioni spaziali (max o mix)
        pooled = h5.amax(dim=[2, 3])
        return self.parietal(pooled, bias=bias), h5, pooled
        
    def reset_state(self):
        self.v5.reset_state()
        self.parietal.reset_state()
        
    @torch.no_grad()
    def stdp_update(self, h3, h5, pooled, par_spikes, eta_v5, eta_par):
        self.v5.stdp_update(h3, h5, eta_v5)
        self.parietal.stdp_update(pooled, par_spikes, eta_par)

class VisualHierarchy(nn.Module):
    """
    Advanced Neuromorphic Visual Cortex incorporating Occipital, Ventral (What), 
    and Dorsal (Where) streams, converging into a Prefrontal Cortex representation.
    Designed according to Generative Mathematics of Dimensions (MGD).
    Total Output Dimension: 1024
    """
    VH_OUT_DIM = 1024

    def __init__(self):
        super().__init__()
        self.occipital = OccipitalCortex()
        self.ventral = VentralStream()
        self.dorsal = DorsalStream()
        
    def forward(self, x):
        h1, h2, h3 = self.occipital(x)
        it_spikes, _, _ = self.ventral(h3)
        par_spikes, _, _ = self.dorsal(h3)
        # Prefrontal Cortex integration: Concatenation of dimensional fields M_parallel and M_perp
        pfc_spikes = torch.cat([it_spikes, par_spikes], dim=1)
        return pfc_spikes

    def reset_state(self):
        self.occipital.reset_state()
        self.ventral.reset_state()
        self.dorsal.reset_state()

    @torch.no_grad()
    def stdp_update_all(self, x_raw, vh_bias=None, eta_v1=0.005, eta_v2=0.002,
                        eta_v3=0.001, eta_v45=0.005, eta_dense=0.005):
        self.train()
        h1, h2, h3 = self.occipital(x_raw)
        self.occipital.stdp_update(x_raw, h1, h2, h3, eta_v1, eta_v2, eta_v3)
        
        bias_it = vh_bias[:, :512] if vh_bias is not None else None
        bias_par = vh_bias[:, 512:] if vh_bias is not None else None
        
        it_spikes, h4, pool_v = self.ventral(h3, bias=bias_it)
        self.ventral.stdp_update(h3, h4, pool_v, it_spikes, eta_v45, eta_dense)
        
        par_spikes, h5, pool_d = self.dorsal(h3, bias=bias_par)
        self.dorsal.stdp_update(h3, h5, pool_d, par_spikes, eta_v45, eta_dense)
        
        return torch.cat([it_spikes, par_spikes], dim=1)
