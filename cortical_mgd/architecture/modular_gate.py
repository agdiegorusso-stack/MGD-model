import torch
import warnings
from torch import Tensor
from cortical_mgd.architecture.cortical_column import CorticalColumn

class ModularGate:
    def __init__(self, n_neurons: int, n_tasks: int):
        self.masks = {}  # {task_id: binary mask [n_neurons]}
        self.n_neurons = n_neurons
        self.allocated_neurons = torch.zeros(n_neurons, dtype=torch.bool)
        self.all_allocated = set()
        self.allocation_time = {}
        self.co_act = torch.zeros(n_neurons)
        self.fire_count = torch.zeros(n_neurons)

    def update_coactivation(self, pre_spikes, post_spikes, task_id=0):
        """
        Chiamato dopo ogni forward pass.
        pre_spikes: (1, input_dim) o (1, n_neurons) del livello precedente
        post_spikes: (1, n_neurons) del livello corrente
        task_id: id del task corrente (per statistiche per-task)
        """
        key_co = f'co_act_{task_id}'
        key_fc = f'fire_count_{task_id}'
        if not hasattr(self, key_co):
            setattr(self, key_co, torch.zeros(self.n_neurons))
            setattr(self, key_fc, torch.zeros(self.n_neurons))
        fc = getattr(self, key_fc)
        ca = getattr(self, key_co)
        fc += post_spikes.squeeze(0).cpu()
        ca += post_spikes.squeeze(0).cpu() * \
             (pre_spikes.sum() > 0).float().cpu()
        setattr(self, key_fc, fc)
        setattr(self, key_co, ca)
        # Aggiorna anche i contatori globali per backward compatibility
        self.fire_count += post_spikes.squeeze(0).cpu()
        self.co_act += post_spikes.squeeze(0).cpu() * \
                       (pre_spikes.sum() > 0).float().cpu()
        
    def register_task(self, task_id: int, column: CorticalColumn, fraction: float = 0.3, strategy: str = 'low_variance'):
        """
        Assegna un sottoinsieme di neuroni al task corrente.
        - strategy="low_variance": seleziona i neuroni con varianza pesi minore
        - strategy="random": seleziona causalmente
        """
        req_neurons = int(self.n_neurons * fraction)
        free_indices = torch.where(~self.allocated_neurons)[0]
        
        if len(free_indices) < req_neurons:
            warnings.warn(f"ModularGate: solo {len(free_indices)} neuroni liberi per {req_neurons} richiesti. Assegnando tutti i liberi.")
            req_neurons = len(free_indices)
            
        if req_neurons == 0:
            warnings.warn("ModularGate: saturazione totale, nessun neurone plastico disponibile!")
            mask = torch.zeros(self.n_neurons, dtype=torch.float32)
            self.masks[task_id] = mask.cpu()
            return
            
        W_data = column.W.detach()  # [input_dim, n_neurons]
        
        if strategy == 'low_variance':
            # Varianza per colonna (neurone)
            var_per_neuron = W_data.var(dim=0)  # [n_neurons]
            
            # Penalizza enormemente i neuroni già allocati per non sceglierli
            var_per_neuron[self.allocated_neurons] = float('inf')
            
            _, top_k_idx = torch.topk(var_per_neuron, req_neurons, largest=False)
            
        elif strategy == 'random':
            # Permutazione casuale dei soli indici liberi
            perm = torch.randperm(len(free_indices))
            top_k_idx = free_indices[perm[:req_neurons]]
            
        else:
            raise ValueError(f"Strategy ignota: {strategy}")
            
        mask = torch.zeros(self.n_neurons, dtype=torch.float32)
        mask[top_k_idx] = 1.0
        
        self.allocated_neurons[top_k_idx] = True
        self.masks[task_id] = mask.cpu()
        selected_indices = top_k_idx.tolist()
        self.all_allocated.update(selected_indices)
        for j in selected_indices:
            self.allocation_time[j] = task_id
        free_after = (~self.allocated_neurons).sum().item()
        print(f"[Gate] Task{task_id}: {req_neurons} neuroni assegnati, "
              f"{free_after} liberi rimanenti")
        
    def register_task_overlapping(self, task_id: int, column: CorticalColumn,
                                  fraction: float = 0.05, 
                                  overlap_threshold: float = -0.5) -> Tensor:
        """
        Seleziona neuroni per il task con overlap controllato.
        - Neuroni liberi (non allocati): sempre eligibili
        - Neuroni condivisi: eligibili solo se kappa_F locale
          e < overlap_threshold (struttura iperbolica -> bassa
          interferenza)
        - fraction ridotta a 0.05 (era 0.25)
        """
        W = column.W.detach()
        
        # Neuroni liberi (mai allocati)
        # all_allocated = set() # This is now a class member
        # for t, mask in self.masks.items():
        #     nz = mask.nonzero(as_tuple=False)
        #     if nz.numel() > 0:
        #         all_allocated.update(nz.squeeze(-1).tolist())
        
        # The above block is replaced by using self.all_allocated directly
        
        free = [j for j in range(self.n_neurons) 
                if j not in self.all_allocated]
        
        if self.fire_count.sum() > 0:
            # FIX 4: usa statistiche del task precedente se disponibili
            prev_key_co = f'co_act_{task_id-1}'
            prev_key_fc = f'fire_count_{task_id-1}'
            if task_id > 0 and hasattr(self, prev_key_co):
                fire_count = getattr(self, prev_key_fc)
                co_act     = getattr(self, prev_key_co)
            else:
                fire_count = self.fire_count
                co_act     = self.co_act
            # Kappa biologica: ratio co-attivazione / firing rate
            firing_rate = fire_count / (fire_count.sum() + 1e-8)
            co_rate = co_act / (co_act.sum() + 1e-8)
            kappa_bio = co_rate / (firing_rate + 1e-8)
            # Neurone e shareable se generalista (alto kappa_bio)
            threshold = kappa_bio.mean() + 2.0 * kappa_bio.std()
            shareable_mask = kappa_bio > threshold
            
            # Filter out neurons that were allocated too recently
            for j in range(self.n_neurons):
                if shareable_mask[j] and (task_id - self.allocation_time.get(j, -99) < 2):
                    shareable_mask[j] = False
            
            shareable = torch.where(shareable_mask)[0].tolist()
        else:
            shareable = []  # Prima di avere statistiche, nessun overlap
        
        # Seleziona: prima i liberi, poi i condivisibili
        # FIX 15: interneuroni sono sempre shareable (no refractory period)
        intern = getattr(self, 'interneuron_idx', set())
        shareable_intern = list(self.all_allocated & intern)
        candidates = list(set(free + shareable + shareable_intern))
        k = max(1, int(self.n_neurons * fraction))
        
        if len(candidates) < k:
            warnings.warn(f"ModularGate Overlap: solo {len(candidates)} candidati per {k} posti. Riempio con i liberi.")
            # Se scendono sotto la quota riempiono i vuoti forzatamente
            fallback = [j for j in range(self.n_neurons) if j not in candidates]
            candidates.extend(fallback[:k - len(candidates)])
            
        # Tra i candidati, seleziona quelli con varianza minima
        vars_candidates = W[:, candidates].var(dim=0)
        top_k = torch.argsort(vars_candidates)[:k]
        selected = [candidates[i] for i in top_k.tolist()]
        
        mask = torch.zeros(self.n_neurons, dtype=torch.float32)
        mask[selected] = 1.0
        self.masks[task_id] = mask.cpu()
        
        # Tracciamo allocazione globale se serve per altri calcoli incrociati
        self.allocated_neurons[selected] = True
        self.all_allocated.update(selected)
        for j in selected:
            self.allocation_time[j] = task_id
        return mask

    def get_plastic_mask(self, task_id: int) -> Tensor:
        """
        Ritorna maschera binaria [n_neurons].
        """
        return self.masks.get(task_id, torch.zeros(self.n_neurons, dtype=torch.float32))
        
    def apply_mask_to_dW(self, dW: Tensor, task_id: int) -> Tensor:
        """
        Azzera dW per i neuroni frozen.
        """
        mask = self.get_plastic_mask(task_id).to(dW.device)
        return dW * mask.unsqueeze(0)

    def get_shared_neurons(self):
        """Ritorna una maschera float [n_neurons] per i neuroni assegnati a >= 2 task."""
        if len(self.masks) < 2:
            return None
        all_m = torch.stack(list(self.masks.values()))
        return (all_m.sum(dim=0) > 1).float()
