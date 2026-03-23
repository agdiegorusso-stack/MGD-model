import torch
import torch.nn as nn
import torch.nn.functional as F

from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.architecture.modular_gate import ModularGate
from cortical_mgd.continual.replay_buffer import MGDReplayBuffer
from cortical_mgd.core.mgd_metrics import compute_S_RT_torch

class BioMGDBrain(nn.Module):
    def __init__(self, input_dim=784, device='cuda'):
        super().__init__()
        
        # LIVELLO 0: Ippocampo (Pattern Separation)
        self.hippocampus = CorticalColumn(n_neurons=2000, input_dim=784, target_sparsity=0.02)
        
        # LIVELLO 1: Corteccia sensoriale (quattro aree)
        self.cortex_A = CorticalColumn(300, 2000, 0.1)
        self.cortex_B = CorticalColumn(300, 2000, 0.1)
        self.cortex_C = CorticalColumn(300, 2000, 0.1)
        self.cortex_D = CorticalColumn(300, 2000, 0.1)
        self.gate_A = ModularGate(300, 30)
        self.gate_B = ModularGate(300, 30)
        self.gate_C = ModularGate(300, 30)
        self.gate_D = ModularGate(300, 30)
        self.replay_A = MGDReplayBuffer(100)
        self.replay_B = MGDReplayBuffer(100)
        self.replay_C = MGDReplayBuffer(100)
        self.replay_D = MGDReplayBuffer(100)
        
        # LIVELLO 2: Corteccia associativa
        self.cortex_L2 = CorticalColumn(500, 300, 0.1)
        self.gate_L2 = ModularGate(500, 30)
        
        # LIVELLO 3: Esecutivo
        self.L3 = CorticalColumn(200, 500, 0.1)
        
        self.task_routing = {}
        self.task_novelty = {}
        
        self.hip_spike_mean = 0.0
        
    def to(self, device):
        self.hippocampus.to(device)
        self.cortex_A.to(device)
        self.cortex_B.to(device)
        self.cortex_C.to(device)
        self.cortex_D.to(device)
        self.cortex_L2.to(device)
        self.L3.to(device)
        return self

    def compute_novelty(self, x):
        h_hip = self.hippocampus(x)
        spike_var = h_hip.var().item()
        novelty = max(0.0, spike_var - self.hip_spike_mean)
        self.hip_spike_mean = (0.9 * self.hip_spike_mean + 0.1 * spike_var)
        eta_factor = 1.0 + 4.0 * float(torch.sigmoid(torch.tensor(novelty * 20.0)))
        return h_hip, novelty, float(eta_factor)

    def route_by_srt(self, task_id, h_hip=None):
        # Routing via S_RT: vai nell'area con piu capacita
        areas = ['A', 'B', 'C', 'D']
        cols = [self.cortex_A, self.cortex_B, self.cortex_C, self.cortex_D]
        gates = [self.gate_A, self.gate_B, self.gate_C, self.gate_D]
        
        best_area = 'A'
        best_srt = -float('inf')
        
        for name, col in zip(areas, cols):
            s_rt = compute_S_RT_torch(col.W)
            if s_rt > best_srt:
                best_srt = s_rt
                best_area = name
                
        self.task_routing[task_id] = best_area
        
        best_col = cols[areas.index(best_area)]
        best_gate = gates[areas.index(best_area)]
        best_gate.register_task(task_id, best_col, 0.25, 'low_variance')
        self.gate_L2.register_task(task_id, self.cortex_L2, 0.25, 'low_variance')
        
        return best_area
        
    def forward(self, x, task_id):
        area = self.task_routing[task_id]
        if area == 'A': col = self.cortex_A
        elif area == 'B': col = self.cortex_B
        elif area == 'C': col = self.cortex_C
        else: col = self.cortex_D
        
        h_hip = self.hippocampus(x)
        h1 = col(h_hip.detach())
        h2 = self.cortex_L2(h1.detach())
        h3 = self.L3(h2.detach())
        return h_hip, h1, h2, h3

    def get_routing_components(self, task_id: int):
        area = self.task_routing[task_id]
        if area == 'A':
            return self.hippocampus, self.cortex_A, self.gate_A, self.replay_A, self.cortex_L2, self.gate_L2, self.L3, area
        elif area == 'B':
            return self.hippocampus, self.cortex_B, self.gate_B, self.replay_B, self.cortex_L2, self.gate_L2, self.L3, area
        elif area == 'C':
            return self.hippocampus, self.cortex_C, self.gate_C, self.replay_C, self.cortex_L2, self.gate_L2, self.L3, area
        else:
            return self.hippocampus, self.cortex_D, self.gate_D, self.replay_D, self.cortex_L2, self.gate_L2, self.L3, area

    def _get_tasks_by_srt(self):
        all_tasks = []
        for buf in [self.replay_A, self.replay_B, self.replay_C, self.replay_D]:
            for t_id, samples in buf.buffer.items():
                area = self.task_routing.get(t_id)
                if area == 'A': col = self.cortex_A
                elif area == 'B': col = self.cortex_B
                elif area == 'C': col = self.cortex_C
                else: col = self.cortex_D
                s_rt = compute_S_RT_torch(col.W)
                all_tasks.append((s_rt, t_id, buf))
        all_tasks.sort(key=lambda x: x[0], reverse=True)
        return all_tasks

    def sleep_consolidation(self, device, n_steps=200):
        """
        Consolidazione post-task con neuromodulazione biologica.

        ACh (acetilcolina): kappa come gate della plasticita durante il sonno.
            sleep_eta = 0.1 / (1 + |kappa|)
            Alta curvatura = rete strutturata = meno plasticita necessaria.

        NA (noradrenalina): lambda_ewc aumenta dopo ogni consolidamento,
            proporzionale a S_RT dell'area. Cristallizza le memorie consolidate.

        Replay ordinato per S_RT decrescente: le aree piu importanti
        (maggiore capacita residua) vengono consolidate per prime.
        """
        sorted_tasks = self._get_tasks_by_srt()
        if not sorted_tasks:
            return []

        if not hasattr(self, 'ewc_lambda'):
            self.ewc_lambda = {}
        if not hasattr(self, 'ewc_W_star'):
            self.ewc_W_star = {}

        steps_per_task = max(1, n_steps // len(sorted_tasks))

        for srt_val, task_id, buf in sorted_tasks:
            area = self.task_routing.get(task_id)
            if area is None:
                continue
            col = getattr(self, f'cortex_{area}')
            gate = getattr(self, f'gate_{area}')

            # ACh gate: kappa modula la plasticita durante il sonno
            kappa, d_avg = col.compute_mgd_metrics()
            sleep_eta = 0.1 / (1.0 + abs(kappa))

            task_samples = buf.buffer.get(task_id, [])
            if not task_samples:
                continue

            for _ in range(steps_per_task):
                indices = torch.randperm(len(task_samples))[:5]
                X_r = torch.stack([task_samples[i][0] for i in indices])

                for i in range(len(X_r)):
                    x_r = X_r[i].unsqueeze(0).to(device)
                    self.hippocampus.lif.reset_state()
                    col.lif.reset_state()

                    for _ in range(3):
                        h_hip = self.hippocampus(x_r)
                        col(h_hip.detach())

                    dW = col.stdp.compute_weight_update(kappa, d_avg, 2.0)
                    mask = gate.get_plastic_mask(task_id)
                    dW = dW * mask.unsqueeze(0).to(device)

                    # EWC penalty se il task e gia stato consolidato (NA)
                    if task_id in self.ewc_W_star:
                        lam = self.ewc_lambda.get(task_id, 50.0)
                        ewc_grad = lam * (col.W - self.ewc_W_star[task_id].to(device))
                        dW = dW - ewc_grad

                    with torch.no_grad():
                        col.W.add_(dW * sleep_eta)
                        col.W.data.clamp_(0.0, 5.0)

            # NA: aumenta lambda_ewc proporzionale a S_RT dopo la consolidazione
            base_lambda = self.ewc_lambda.get(task_id, 50.0)
            self.ewc_lambda[task_id] = base_lambda + srt_val * 10.0
            self.ewc_W_star[task_id] = col.W.data.clone()

        return [t_id for _, t_id, _ in sorted_tasks]
