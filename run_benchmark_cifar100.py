# run_benchmark_cifar100.py
#
# Benchmark Split CIFAR-100 per confronto con transformer (DualPrompt, L2P).
# 20 task, 5 classi ciascuno, 500 campioni per classe.
#
# Ottimizzazioni rispetto al benchmark MNIST:
#   - Mini-batch training (batch_size=32) invece di campione per campione
#   - Evaluation completamente batched
#   - MGD metrics calcolate una volta per task, non per campione
#   - torch.compile sui moduli critici
#
# Metriche prodotte (standard continual learning):
#   - ACC: accuracy media su tutti i task visti
#   - BWT: backward transfer (quanto dimentica i task precedenti)
#   - FWT: forward transfer (quanto aiuta i task futuri)
#
# Modelli testati: K (baseline), L (+ predictive coding), M (+ dendritic)
#
# Uso:
#   python run_benchmark_cifar100.py
#   python run_benchmark_cifar100.py --n_tasks 10 --samples_per_class 200
#   python run_benchmark_cifar100.py --device cpu

import argparse
import time
import torch
import numpy as np
from torchvision import datasets, transforms

from cortical_mgd.architecture.temporal_hierarchy import TemporalHierarchy
from cortical_mgd.architecture.predictive_hierarchy import PredictiveHierarchy
from cortical_mgd.architecture.dendritic_hierarchy import DendriticHierarchy
from cortical_mgd.plasticity.homeostasis import apply_homeostatic_normalization

# -----------------------------------------------------------------------
# Argomenti
# -----------------------------------------------------------------------

parser = argparse.ArgumentParser()
parser.add_argument('--n_tasks',            type=int, default=20)
parser.add_argument('--n_classes_per_task', type=int, default=5)
parser.add_argument('--samples_per_class',  type=int, default=500)
parser.add_argument('--epochs_per_task',    type=int, default=8)
parser.add_argument('--batch_size',         type=int, default=128)
parser.add_argument('--device',             type=str, default='cuda' if torch.cuda.is_available() else 'cpu')
parser.add_argument('--seed',               type=int, default=42)
import platform
_default_workers = 0 if platform.system() == 'Windows' else 8
parser.add_argument('--num_workers',        type=int, default=_default_workers)
parser.add_argument('--pretrain_epochs',    type=int, default=10,
                    help='Epoche STDP non supervisionato su tutte le immagini (0=disabilitato)')
args = parser.parse_args()

torch.manual_seed(args.seed)
np.random.seed(args.seed)
device = torch.device(args.device)

# -----------------------------------------------------------------------
# Ottimizzazioni hardware: i9 + RTX 2060
# -----------------------------------------------------------------------

import json
if os.path.exists('evolution_params.json'):
    with open('evolution_params.json', 'r') as f:
        EVO_PARAMS = json.load(f)
    print(f"Caricati parametri OpenEvolve: {EVO_PARAMS}")
else:
    EVO_PARAMS = {}

if torch.cuda.is_available():
    # cuDNN auto-tuning: trova il kernel piu veloce per ogni shape
    torch.backends.cudnn.benchmark = True
    torch.backends.cudnn.enabled = True

    # FP16 AMP: tensor core su RTX 2060 (Turing), ~2x speedup sui matmul
    USE_AMP = True
    amp_dtype = torch.float16
    print(f'AMP FP16 abilitato (RTX 2060 Turing tensor cores)')
else:
    USE_AMP = False
    amp_dtype = torch.float32

# torch.compile disponibile da PyTorch 2.0+
USE_COMPILE = int(torch.__version__.split('.')[0]) >= 2

print(f'Device: {device}  |  AMP: {USE_AMP}  |  compile: {USE_COMPILE}')
print(f'Tasks: {args.n_tasks}, classi/task: {args.n_classes_per_task}, '
      f'campioni/classe: {args.samples_per_class}, epoche/task: {args.epochs_per_task}')
print(f'batch_size: {args.batch_size}  |  num_workers: {args.num_workers}')

INPUT_DIM = 3072  # mantenuto per compatibilita', VH gestisce internamente
N_SLOW = 3

# -----------------------------------------------------------------------
# Dataset Split CIFAR-100
# -----------------------------------------------------------------------

print('Carico CIFAR-100...')
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5071, 0.4867, 0.4408),
                         (0.2675, 0.2565, 0.2761)),
])

train_ds = datasets.CIFAR100(root='./data', train=True,
                              download=True, transform=transform)
test_ds  = datasets.CIFAR100(root='./data', train=False,
                              download=True, transform=transform)

# Crea split: n_tasks task, n_classes_per_task classi ciascuno
total_classes = args.n_tasks * args.n_classes_per_task
assert total_classes <= 100, \
    f'Troppi task: {args.n_tasks} x {args.n_classes_per_task} = {total_classes} > 100'

# Shuffle deterministico delle classi
rng = np.random.default_rng(args.seed)
class_order = rng.permutation(100).tolist()

def get_task_data(dataset, task_idx):
    """
    Ritorna (X, y) per il task task_idx con campioni bilanciati per classe.
    Usa DataLoader con num_workers=8 (i9 8-core) e pin_memory per
    trasferimento RAM->GPU veloce.
    """
    from torch.utils.data import DataLoader, Subset

    classes = class_order[task_idx * args.n_classes_per_task:
                          (task_idx + 1) * args.n_classes_per_task]
    indices = []
    local_labels = []
    targets = dataset.targets  # lista Python in RAM, nessun transform
    for local_label, global_class in enumerate(classes):
        class_indices = [i for i, c in enumerate(targets) if c == global_class]
        class_indices = class_indices[:args.samples_per_class]
        indices.extend(class_indices)
        local_labels.extend([local_label] * len(class_indices))

    subset = Subset(dataset, indices)
    loader = DataLoader(
        subset,
        batch_size=len(indices),
        shuffle=False,
        num_workers=args.num_workers,
        pin_memory=(torch.cuda.is_available() and args.num_workers > 0),
        persistent_workers=(args.num_workers > 0),
    )
    X_raw, _ = next(iter(loader))
    # Mantieni (N, 3, 32, 32): la gerarchia visiva V1->IT gestisce il processing
    y = torch.tensor(local_labels, dtype=torch.long)
    perm = torch.randperm(len(X_raw))
    X = X_raw[perm].to(device, non_blocking=True)
    y = y[perm].to(device, non_blocking=True)
    return X, y

print('Preparo i task...')
t0 = time.time()
train_tasks = [get_task_data(train_ds, t) for t in range(args.n_tasks)]
test_tasks  = [get_task_data(test_ds,  t) for t in range(args.n_tasks)]
print(f'  pronto in {time.time()-t0:.1f}s')

# DataLoader su tutte le immagini CIFAR-100 per pretraining non supervisionato
if args.pretrain_epochs > 0:
    from torch.utils.data import DataLoader as _DL
    _pretrain_loader = _DL(
        train_ds,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        pin_memory=(torch.cuda.is_available() and args.num_workers > 0),
        persistent_workers=(args.num_workers > 0),
    )

# -----------------------------------------------------------------------
# Pretraining non supervisionato (Olshausen & Field 1996)
# -----------------------------------------------------------------------

@torch.no_grad()
def pretrain_unsupervised(brain, loader, n_epochs, device):
    """
    Fase di sviluppo visivo non supervisionato.

    Pipeline:
      immagine (B,3,32,32) -> VH STDP (V1->V2->V4->IT, Hebbiano) -> (B,512) spike IT
      (B,512) spike IT      -> Ippocampo STDP                      -> (B,2000) spike hip
      (B,2000) spike hip    -> Cortex STDP (4 aree)

    Olshausen & Field 1996: sparse coding su immagini naturali -> filtri Gabor in V1.
    VH output e' gia' binario (LIF+WTA), nessun Poisson encoding necessario.
    """
    if n_epochs == 0:
        return
    eta_hip = 0.005
    eta_ctx = 0.001
    METRICS_EVERY = 50
    print(f'\n[Pretrain] Sviluppo non supervisionato: {n_epochs} epoche su '
          f'{len(loader.dataset)} immagini (V1->V2->V4->IT->Ippocampo->Cortex)...')
    t0 = time.time()

    for ep in range(n_epochs):
        spike_sum = 0.0
        n_batches = 0
        kappa, d_avg = 0.0, 1.0

        for X_raw, _ in loader:
            X_b = X_raw.to(device)  # (B, 3, 32, 32) normalizzate [-2,2]
            # Porta in [0,1] per input VH (LIF usa correnti >= 0)
            X_min = X_b.flatten(1).min(dim=1).values.view(-1, 1, 1, 1)
            X_max = X_b.flatten(1).max(dim=1).values.view(-1, 1, 1, 1)
            X_01 = (X_b - X_min) / (X_max - X_min + 1e-8)

            if n_batches % METRICS_EVERY == 0:
                kappa, d_avg = brain.hippocampus.compute_mgd_metrics()

            # --- VH: Hebbiano a ogni livello V1->IT ---
            h_vis = brain.visual_hierarchy.stdp_update_all(X_01)  # (B, 512)

            # --- Ippocampo: input gia' spike binari da VH ---
            brain.hippocampus.lif.reset_state()
            h_hip = brain.hippocampus(h_vis)
            dW = brain.hippocampus.stdp.compute_weight_update(kappa, 1.0, 1.0)
            brain.hippocampus.W.add_(dW * eta_hip)
            brain.hippocampus.W.data.clamp_(0.0, 5.0)
            target_sum = EVO_PARAMS.get('target_sum', 15.0)
            brain.hippocampus.W.data = apply_homeostatic_normalization(brain.hippocampus.W.data, target_sum=target_sum, dim=0)
            spike_sum += h_hip.mean().item()

            # --- Cortex: input = spike ippocampo ---
            for area in ['A', 'B', 'C', 'D']:
                col = getattr(brain, f'cortex_{area}')
                col.lif.reset_state()
                for _ in range(3):
                    col(h_hip.detach())
                # Metriche MGD per area corticale (calcolate ogni METRICS_EVERY batch)
                if n_batches % METRICS_EVERY == 0:
                    kappa_c, d_avg_c = col.compute_mgd_metrics()
                else:
                    kappa_c, d_avg_c = getattr(col, '_last_kappa', 0.0), getattr(col, '_last_davg', 1.0)
                col._last_kappa = kappa_c
                col._last_davg = d_avg_c
                dWc = col.stdp.compute_weight_update(kappa_c, d_avg_c, 2.0, W=col.W.data)
                col.W.add_(dWc * eta_ctx)
                col.W.data.clamp_(0.0, 5.0)
                col.W.data = apply_homeostatic_normalization(col.W.data, target_sum=EVO_PARAMS.get('target_sum', 15.0), dim=0)

            n_batches += 1

        avg_spike = spike_sum / max(1, n_batches)
        elapsed = time.time() - t0
        print(f'  [Pretrain] Epoch {ep+1}/{n_epochs} | '
              f'kF_hip={kappa:.4f} | spike_rate_hip={avg_spike:.4f} | {elapsed:.0f}s')

    print(f'[Pretrain] Completato in {time.time()-t0:.0f}s')

# -----------------------------------------------------------------------
# Funzioni di training e valutazione ottimizzate
# -----------------------------------------------------------------------

def train_task_batched(brain, col, gate, ro, task_id,
                       X_train, y_train, kappa, d_avg,
                       eta, batch_size, device):
    """
    Training in mini-batch.
    STDP: il weight update e sommato su tutto il batch (mini-batch STDP).
    BioReadout: aggiornato campione per campione (e' gia' veloce).
    """
    col.train()
    brain.hippocampus.train()
    n = len(X_train)
    n_batches = 0  # contatore globale per task (warm-up Three-Factor)

    for ep in range(args.epochs_per_task):
        perm = torch.randperm(n)
        X_shuf = X_train[perm]
        y_shuf = y_train[perm]

        for start in range(0, n, batch_size):
            end = min(start + batch_size, n)
            X_b = X_shuf[start:end]  # (B, 3072)
            y_b = y_shuf[start:end]  # (B,)
            n_batches += 1

            amp_ctx = (torch.autocast(device_type='cuda', dtype=amp_dtype)
                       if USE_AMP and device.type == 'cuda'
                       else torch.autocast(device_type='cpu', enabled=False))

            # Pass 0: forward senza bias per calcolare errore corrente
            brain.hippocampus.lif.reset_state()
            col.lif.reset_state()
            brain.slow_cortex.lif.reset_state()

            with amp_ctx:
                _, h0, _ = brain.forward(X_b, task_id)   # no bias
                h0_f = h0.float()

            # Errore corrente → bias per i pass successivi
            with torch.no_grad():
                logits0 = (h0_f @ ro.W).float()
                y_onehot = torch.zeros(len(X_b), ro.n_classes, device=device)
                y_onehot.scatter_(1, y_b.unsqueeze(1).long(), 1.0)
                error0 = y_onehot - torch.softmax(logits0, dim=1)   # (B, n_classes)
                cortex_bias = (error0 @ ro.W.T.float())              # (B, n_neurons)
                # Normalizza per-sample in [-alpha, +alpha]
                scale = cortex_bias.abs().max(dim=1, keepdim=True)[0].clamp(min=1e-6)
                # Rampa dinamica di alpha: cresce durante le epoche
                alpha = min(0.4, 0.2 + (n_batches / 50.0) * 0.2)
                cortex_bias = cortex_bias / scale * alpha              # alpha range [0.2, 0.4]

                # --- TOP-DOWN FEEDBACK ALIGNMENT per VisualHierarchy ---
                # col.W è (1024, 300) [Ippocampo -> Cortex]
                # Wait, col is CorticalColumn(300, 2000). So input_dim=2000. col.W is (2000, 300).
                # cortex_bias è (B, 300). 
                hip_bias = cortex_bias @ col.W.data.T  # (B, 2000)
                
                # hippocampus è CorticalColumn(2000, 1024). W è (1024, 2000).
                vh_bias = hip_bias @ brain.hippocampus.W.data.T # (B, 1024)
                vh_scale = vh_bias.abs().max(dim=1, keepdim=True)[0].clamp(min=1e-6)
                beta = EVO_PARAMS.get('beta', 3.0)
                vh_bias = vh_bias / vh_scale * beta # beta multiplier!
                # ---------------------------------------------------------

            # Accumula h con bias (2 pass guidati + 1 non guidato)
            sum_h = h0_f.clone()  # già contato il pass 0
            brain.hippocampus.lif.reset_state()
            col.lif.reset_state()
            brain.slow_cortex.lif.reset_state()

            with amp_ctx:
                for _ in range(2):   # 2 pass con bias (totale 3)
                    _, h_c, _ = brain.forward(X_b, task_id, cortex_bias=cortex_bias)
                    sum_h += h_c.float()

            # Three-Factor: errore del readout come feedback per la corteccia.
            # Calcolo PRIMA dell'update BioReadout (su pesi correnti).
            # delta_cortex_j = quale neurone j doveva essere piu'/meno attivo?
            # Tutti FP32 espliciti: evita recompilazioni torch.compile FP16/FP32.
            with torch.no_grad():
                logits_b = (sum_h @ ro.W).float()
                y_onehot = torch.zeros(len(X_b), ro.n_classes, device=device)
                y_onehot.scatter_(1, y_b.unsqueeze(1).long(), 1.0)
                error_b = y_onehot - torch.softmax(logits_b, dim=1)
                delta_cortex = (error_b @ ro.W.T.float()).mean(0)  # (n_neurons,)
            # Warm-up lineare: prime 30 iterazioni modulation ~ 1
            # (readout non ancora maturo -> feedback inizialmente rumore)
            feedback_w = float(min(1.0, n_batches / 30.0))

            # Neuromodulazione DA (dopamina) per-batch (Schultz 1997):
            # delta_DA = var(h_cortex) - ema: sorpresa positiva -> eta piu' alta.
            h_var = sum_h.float().var(dim=1).mean().item()
            brain._da_ema = getattr(brain, '_da_ema', h_var)
            delta_da = max(0.0, h_var - brain._da_ema)
            brain._da_ema = 0.95 * brain._da_ema + 0.05 * h_var
            eta_batch = eta * float(torch.sigmoid(torch.tensor(delta_da * 20.0)).item() + 0.5)

            # BioReadout: aggiorna campione per campione
            for i in range(len(X_b)):
                ro.online_step(sum_h[i].unsqueeze(0),
                               int(y_b[i].item()),
                               da_signal=float(eta_batch))

            # STDP three-factor: MGD eta + kappa-locale + modulazione errore readout
            # eta_batch (globale DA) applicato DOPO three-factor (ordine critico)
            dW = col.stdp.compute_weight_update(kappa, d_avg, 2.0,
                                                W=col.W.data,
                                                delta_cortex=delta_cortex,
                                                feedback_weight=feedback_w)
            mask = gate.get_plastic_mask(task_id).to(device)
            dW   = dW * mask.unsqueeze(0) * eta_batch
            with torch.no_grad():
                col.W.add_(dW)
                col.W.data.clamp_(0.0, 5.0)
                # Omeostatica solo sui neuroni plastici del task corrente
                plastic_idx = mask.bool()
                if plastic_idx.any():
                    col.W.data[:, plastic_idx] = apply_homeostatic_normalization(
                        col.W.data[:, plastic_idx], target_sum=15.0, dim=0)
            
            # STDP three-factor per VISUAL HIERARCHY con TOP-DOWN BIAS
            X_01 = (X_b - X_b.flatten(1).min(dim=1).values.view(-1, 1, 1, 1)) / (
                   X_b.flatten(1).max(dim=1).values.view(-1, 1, 1, 1) - X_b.flatten(1).min(dim=1).values.view(-1, 1, 1, 1) + 1e-8)
            with amp_ctx:
                brain.visual_hierarchy.stdp_update_all(
                    X_01, vh_bias=vh_bias,
                    eta_v1=EVO_PARAMS.get('eta_v1', 0.005),
                    eta_v2=EVO_PARAMS.get('eta_v2', 0.002),
                    eta_v3=EVO_PARAMS.get('eta_v3', 0.001),
                    eta_v45=EVO_PARAMS.get('eta_v45', 0.005),
                    eta_dense=EVO_PARAMS.get('eta_dense', 0.005)
                )


@torch.no_grad()
def eval_all_tasks_batched(brain, task_ids, test_data, batch_size, device):
    """
    Valutazione batched su tutti i task precedenti.
    Ritorna lista di accuracy per task.
    """
    accs = []
    for pt in task_ids:
        X_e, y_e = test_data[pt]
        area_pt  = brain.task_routing[pt]
        col_pt   = getattr(brain, f'cortex_{area_pt}')
        ro_pt    = brain.readouts[pt]

        correct = 0
        total   = len(X_e)
        active_counts = torch.zeros(col_pt.n_neurons, device=device)
        active_vis = torch.zeros(1024, device=device)
        active_hip = torch.zeros(2000, device=device)

        for start in range(0, total, batch_size):
            end = min(start + batch_size, total)
            X_b = X_e[start:end]

            brain.hippocampus.lif.reset_state()
            col_pt.lif.reset_state()
            brain.slow_cortex.lif.reset_state()

            sum_h = torch.zeros(len(X_b), col_pt.n_neurons, device=device)
            amp_ctx = (torch.autocast(device_type='cuda', dtype=amp_dtype)
                       if USE_AMP and device.type == 'cuda'
                       else torch.autocast(device_type='cpu', enabled=False))
            with amp_ctx:
                for _ in range(3):
                    h_v = brain._to_vis(X_b)
                    h_h = brain.hippocampus(h_v)
                    _, h_c, _ = brain.forward(X_b, pt)
                    sum_h += h_c.float()
            
            # Conta le attivazioni (neuroni che hanno sparato almeno una volta nel batch)
            active_counts += (sum_h > 0).float().sum(dim=0)
            active_vis += (h_v > 0).float().sum(dim=0)
            active_hip += (h_h > 0).float().sum(dim=0)

            for i in range(len(X_b)):
                pred = ro_pt.predict(sum_h[i].unsqueeze(0))
                if pred == int(y_e[start + i].item()):
                    correct += 1

        dead_neurons = (active_counts == 0).sum().item()
        dead_vis = (active_vis == 0).sum().item()
        dead_hip = (active_hip == 0).sum().item()
        acc_val = correct / total
        accs.append(acc_val)
        
        # Stampa monitoraggio sparsità solo per il task testato piu recente (per non inondare lo stdout)
        if pt == task_ids[-1]:
            print(f"    [Sparsity Task {pt+1}] VH: {1024-dead_vis}/1024 | Hip: {2000-dead_hip}/2000 | Area {area_pt}: {col_pt.n_neurons-dead_neurons}/{col_pt.n_neurons}")

    return accs


def compute_continual_metrics(acc_matrix):
    """
    acc_matrix[i][j] = accuracy sul task j dopo aver addestrato il task i.
    ACC  = media finale su tutti i task
    BWT  = trasferimento backward (dimenticanza)
    FWT  = trasferimento forward (generalizzazione)
    """
    T = len(acc_matrix)
    # ACC: accuracy media all'ultimo task
    acc = np.mean(acc_matrix[-1])
    # BWT: quanto e' peggiorata l'accuracy sui task precedenti
    bwt = np.mean([acc_matrix[T-1][j] - acc_matrix[j][j]
                   for j in range(T-1)])
    # FWT: quanto il training sui task precedenti aiuta i successivi
    # (approssimato: accuracy sul task j prima di averlo visto)
    fwt = 0.0  # richiede un modello random baseline, per ora 0

    return float(acc), float(bwt), float(fwt)

# -----------------------------------------------------------------------
# Helper per aggiungere replay e consolidare
# -----------------------------------------------------------------------

def add_replay_and_consolidate(brain, area, task_id, X_train, y_train_safe):
    class _VisHipPre:
        """Preprocessore replay: VH -> Ippocampo. Input: (1,3,H,W), output: (1,2000)."""
        def __init__(self, vh, hip):
            self.vh = vh
            self.hip = hip
        def reset_state(self):
            self.vh.reset_state()
            if hasattr(self.hip.lif, 'reset_state'):
                self.hip.lif.reset_state()
        def __call__(self, x):
            dev = next(iter(self.hip.parameters())).device
            x = x.to(dev)
            if x.dim() == 3:
                x = x.unsqueeze(0)  # (1, 3, H, W)
            x_vis = self.vh(x)
            return self.hip(x_vis).detach()

    col    = getattr(brain, f'cortex_{area}')
    replay = getattr(brain, f'replay_{area}')
    replay.add_task(task_id, X_train.cpu(), y_train_safe.cpu(), col,
                    preprocess_fn=_VisHipPre(brain.visual_hierarchy,
                                             brain.hippocampus))
    brain.consolidate(task_id, device)

# -----------------------------------------------------------------------
# Loop principale per un modello
# -----------------------------------------------------------------------

def run_model(brain, model_name, n_tasks, train_tasks, test_tasks,
              batch_size, device):
    print(f'\n{"="*60}')
    print(f'Modello: {model_name}')
    print(f'{"="*60}')

    acc_matrix   = []  # acc_matrix[task_after][task_target]
    time_per_task = []

    for t_idx in range(n_tasks):
        t_start = time.time()
        X_train, y_train = train_tasks[t_idx]
        y_safe           = y_train % args.n_classes_per_task

        # Registra task (novelty + routing)
        area, novelty, eta = brain.register_task(t_idx, X_train,
                                                  n_classes=args.n_classes_per_task)
        col  = getattr(brain, f'cortex_{area}')
        gate = getattr(brain, f'gate_{area}')
        ro   = brain.readouts[t_idx]

        kappa, d_avg = col.compute_mgd_metrics()

        # Training
        train_task_batched(brain, col, gate, ro, t_idx,
                           X_train, y_safe, kappa, d_avg,
                           eta, batch_size, device)

        # Replay e consolidazione
        add_replay_and_consolidate(brain, area, t_idx, X_train, y_safe)

        # Valutazione su tutti i task visti
        accs = eval_all_tasks_batched(
            brain, list(range(t_idx + 1)), test_tasks, batch_size, device)
        acc_matrix.append(accs)

        elapsed = time.time() - t_start
        time_per_task.append(elapsed)

        print(f'  Task {t_idx+1:2d}/{n_tasks} | '
              f'ACC_curr={accs[-1]:.3f} | '
              f'ACC_T1={accs[0]:.3f} | '
              f'area={area} | {elapsed:.1f}s')

    # Padding acc_matrix a dimensione T x T
    T = n_tasks
    full_matrix = np.zeros((T, T))
    for i, row in enumerate(acc_matrix):
        for j, v in enumerate(row):
            full_matrix[i][j] = v

    acc, bwt, fwt = compute_continual_metrics(full_matrix)
    total_time = sum(time_per_task)

    print(f'\n  ACC={acc:.3f}  BWT={bwt:+.3f}  FWT={fwt:.3f}')
    print(f'  Tempo totale: {total_time:.0f}s ({total_time/60:.1f} min)')

    return {
        'model': model_name,
        'ACC':   acc,
        'BWT':   bwt,
        'FWT':   fwt,
        'acc_matrix': full_matrix,
        'time_s': total_time
    }

# -----------------------------------------------------------------------
# Numeri di riferimento dai transformer (da letteratura)
# -----------------------------------------------------------------------

TRANSFORMER_BASELINES = {
    'DualPrompt (ViT-B/16)':  {'ACC': 0.862, 'BWT': -0.005},
    'L2P (ViT-B/16)':         {'ACC': 0.836, 'BWT': -0.012},
    'EWC (ResNet)':            {'ACC': 0.476, 'BWT': -0.142},
    'FineTune (no CL)':        {'ACC': 0.347, 'BWT': -0.403},
}

# -----------------------------------------------------------------------
# Esecuzione
# -----------------------------------------------------------------------

results = []

for ModelClass, name in [
    # (TemporalHierarchy,   'K_TemporalHierarchy'),
    # (PredictiveHierarchy, 'L_PredictiveHierarchy'),
    (DendriticHierarchy,  'M_DendriticHierarchy'),
]:
    brain = ModelClass(device=args.device, n_slow=N_SLOW)
    brain.to(device)

    # Pretraining non supervisionato (prima di compile per accedere a .W)
    if args.pretrain_epochs > 0:
        pretrain_unsupervised(brain, _pretrain_loader, args.pretrain_epochs, device)

    # torch.compile: testa subito con un forward sintetico per evitare
    # crash lazily (TritonMissing si manifesta al primo forward, non al compile)
    _compiled = False
    if USE_COMPILE:
        try:
            _hip_c = torch.compile(brain.hippocampus, mode='default')
            _slw_c = torch.compile(brain.slow_cortex,  mode='default')
            # Warm-up: se Triton manca, crasha qui (gestito)
            _dummy = torch.zeros(1, 1024, device=device)
            _ = _hip_c(_dummy)
            brain.hippocampus = _hip_c
            brain.slow_cortex = _slw_c
            _compiled = True
            print(f'[{name}] torch.compile attivo')
        except Exception as _e:
            print(f'[{name}] torch.compile non disponibile ({type(_e).__name__}), continuo senza')

    res = run_model(brain, name, args.n_tasks,
                    train_tasks, test_tasks,
                    args.batch_size, device)
    results.append(res)

# -----------------------------------------------------------------------
# Tabella finale
# -----------------------------------------------------------------------

print('\n' + '='*70)
print(f'{"Modello":<35} {"ACC":>7} {"BWT":>8} {"Tempo":>10}')
print('-'*70)

for r in results:
    print(f'{r["model"]:<35} {r["ACC"]:>7.3f} {r["BWT"]:>+8.3f} '
          f'{r["time_s"]/60:>8.1f}min')

print('-'*70)
print('--- Riferimento transformer (letteratura, Split CIFAR-100) ---')
for name, m in TRANSFORMER_BASELINES.items():
    print(f'{name:<35} {m["ACC"]:>7.3f} {m["BWT"]:>+8.3f}')

print('='*70)

# Salva risultati
import json, os
os.makedirs('results_cifar100', exist_ok=True)
out = []
for r in results:
    out.append({k: (v.tolist() if hasattr(v, 'tolist') else v)
                for k, v in r.items()})
with open('results_cifar100/results.json', 'w') as f:
    json.dump(out, f, indent=2)
print('\nRisultati salvati in results_cifar100/results.json')
