import torch
from torch import Tensor
from cortical_mgd.architecture.cortical_column import CorticalColumn

class MGDReplayBuffer:
    def __init__(self, capacity_per_task: int = 50):
        self.capacity = capacity_per_task
        self.buffer = {}  # {task_id: [(X, y), ...]}
        
    def add_task(self, task_id: int, X: Tensor, y: Tensor, column: CorticalColumn, preprocess_fn=None):
        """
        Salva i K esempi più informativi di un task.
        Priorità MGD: campioni che producono spike_sum con varianza più alta (più discriminativi).
        Se preprocess_fn è fornito, trasforma x_sample prima di passarlo alla colonna.
        """
        column.eval()
        spike_sums = []
        
        with torch.no_grad():
            for i in range(len(X)):
                x_sample = X[i].unsqueeze(0)
                if hasattr(column.lif, "reset_state"):
                    column.lif.reset_state()
                else:
                    column.lif.v = None; column.lif.a = None
                
                if preprocess_fn and hasattr(preprocess_fn, "reset_state"):
                    preprocess_fn.reset_state()
                    
                sum_s = torch.zeros(1, column.n_neurons, device=column.W.device)
                for _ in range(3):
                    x_in = preprocess_fn(x_sample) if preprocess_fn else x_sample
                    sum_s += column(x_in)
                spike_sums.append(sum_s)
                
        # [N, n_neurons]
        spike_tns = torch.cat(spike_sums, dim=0)
        
        # We want samples that are highly discriminative. 
        # For a single sample, spike_var across neurons shows how specialized its representation is.
        spike_var = spike_tns.var(dim=1)  # [N]
        
        # Sort descending
        top_indices = torch.argsort(spike_var, descending=True)[:self.capacity]
        
        saved_samples = []
        for idx in top_indices:
            saved_samples.append((X[idx], y[idx]))
            
        self.buffer[task_id] = saved_samples

    def add_task_compressed(self, task_id: int, X: Tensor, y: Tensor, column: CorticalColumn):
        """
        Salva centroide per classe invece di campioni individuali.
        Memoria: O(n_classes * n_neurons) invece di O(n_samples * n_neurons)
        """
        column.eval()
        class_spikes = {}  # {class: [spike_sums]}
        
        with torch.no_grad():
            for i in range(len(X)):
                x_s = X[i].unsqueeze(0)
                if hasattr(column.lif, 'reset_state'):
                    column.lif.reset_state()
                else:
                    column.lif.v = None; column.lif.a = None
                sum_s = torch.zeros(1, column.n_neurons, 
                                    device=column.W.device)
                for _ in range(3):
                    sum_s += column(x_s)
                label = int(y[i].item() % 10)
                if label not in class_spikes:
                    class_spikes[label] = []
                class_spikes[label].append(sum_s.squeeze(0))
        
        # Centroide per classe
        centroids = []
        for label, spikes in class_spikes.items():
            centroid = torch.stack(spikes).mean(dim=0)
            # Ricostruisci un X sintetico dal centroide
            # (per compatibilita con sample_replay)
            # Per ora il placeholder punta a un X esistente
            centroids.append((X[0], y[0]))  
        
        self.buffer[task_id] = centroids[:self.capacity]
        
    def sample_replay(self, n_per_task: int = 10) -> list:
        """
        Ritorna lista di (X_batch, y_batch) per ogni task precedente, 
        n_per_task esempi ciascuno in ordine casuale.
        """
        replay_batches = []
        for t_id, samples in self.buffer.items():
            if len(samples) == 0:
                continue
            
            # Campionamento casuale dal buffer del task
            indices = torch.randperm(len(samples))[:n_per_task]
            
            X_batch = torch.stack([samples[i][0] for i in indices])
            y_batch = torch.stack([samples[i][1] for i in indices])
            
            replay_batches.append((t_id, (X_batch, y_batch)))
            
        return replay_batches
        
    def n_tasks(self) -> int:
        return len(self.buffer)
