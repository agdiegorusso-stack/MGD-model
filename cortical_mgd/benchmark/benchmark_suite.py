# cortical_mgd/benchmark/benchmark_suite.py

import pandas as pd
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision
import torchvision.transforms as transforms
import os

from cortical_mgd.architecture.cortical_column import CorticalColumn
from cortical_mgd.architecture.cortical_brain import CorticalBrain
from cortical_mgd.architecture.hierarchical_brain import HierarchicalBrain
from cortical_mgd.architecture.bio_mgd_brain import BioMGDBrain
from cortical_mgd.plasticity.stdp_local import STDPLocal
from cortical_mgd.plasticity.stdp_mgd import STDPMgd
from cortical_mgd.plasticity.stdp_local_mgd import STDPLocalMGD
from cortical_mgd.plasticity.homeostasis import apply_homeostatic_normalization
from cortical_mgd.continual.geometric_ewc import GeometricEWC
from cortical_mgd.benchmark.energy_profiler import EnergyProfiler
from cortical_mgd.core.mgd_metrics import compute_S_RT
from cortical_mgd.continual.replay_buffer import MGDReplayBuffer
from cortical_mgd.architecture.modular_gate import ModularGate
from cortical_mgd.plasticity.structural_plasticity import StructuralPlasticity
from cortical_mgd.plasticity.bio_readout import BioReadout
from cortical_mgd.architecture.temporal_hierarchy import TemporalHierarchy
from cortical_mgd.architecture.predictive_hierarchy import PredictiveHierarchy
from cortical_mgd.architecture.dendritic_hierarchy import DendriticHierarchy



class MGDBenchmarkSuite:
    """Evaluates Cortical MGD architectures across continuous sequences."""
    def __init__(self, n_neurons: int = 100, input_dim: int = 784):
        self.n_neurons = n_neurons
        self.input_dim = input_dim
        self.profiler = EnergyProfiler()
        self.results_df = None

    def _get_mnist_subsets(self, n_samples=100):
        transform = transforms.ToTensor()
        train_ds = torchvision.datasets.MNIST(root='./data', train=True, download=True, transform=transform)
        
        idx_04 = (train_ds.targets < 5)
        X_04 = train_ds.data[idx_04].float().view(-1, 784)[:n_samples] / 255.0
        y_04 = train_ds.targets[idx_04][:n_samples]
        
        idx_59 = (train_ds.targets >= 5)
        X_59 = train_ds.data[idx_59].float().view(-1, 784)[:n_samples] / 255.0
        y_59 = train_ds.targets[idx_59][:n_samples]
        
        return (X_04, y_04), (X_59, y_59)

    def _create_xor_task(self, n_samples=100) -> tuple[torch.Tensor, torch.Tensor]:
        """Retro-compat: ritorna solo train. Usa _create_xor_task_split per train/test."""
        X, y, _, _ = self._create_xor_task_split(n_train=n_samples, n_test=0)
        return X, y

    def _create_xor_task_split(self, n_train=64, n_test=200):
        """Ritorna (X_train, y_train, X_test, y_test) con seed diverso per i dati test."""
        # --- Train ---
        torch.manual_seed(10)
        X_s_tr = torch.randint(0, 2, (n_train, 2)).float()
        y_tr = (X_s_tr[:, 0] * 2 + X_s_tr[:, 1]).long()
        X_tr = torch.zeros(n_train, self.input_dim)
        for d in range(75):
            X_tr[:, d] = X_s_tr[:, 0]
            X_tr[:, 75+d] = X_s_tr[:, 1]
        X_tr += torch.randn_like(X_tr) * 0.05
        if n_test == 0:
            return X_tr, y_tr, torch.empty(0), torch.empty(0)
        # --- Test (seed separato, mai visto) ---
        torch.manual_seed(99)
        X_s_te = torch.randint(0, 2, (n_test, 2)).float()
        y_te = (X_s_te[:, 0] * 2 + X_s_te[:, 1]).long()
        X_te = torch.zeros(n_test, self.input_dim)
        for d in range(75):
            X_te[:, d] = X_s_te[:, 0]
            X_te[:, 75+d] = X_s_te[:, 1]
        X_te += torch.randn_like(X_te) * 0.05
        return X_tr, y_tr, X_te, y_te

    def _create_banded_task(self, n_samples=100) -> tuple[torch.Tensor, torch.Tensor]:
        """Retro-compat: ritorna solo train."""
        X, y, _, _ = self._create_banded_task_split(n_train=n_samples, n_test=0)
        return X, y

    def _create_banded_task_split(self, n_train=64, n_test=200):
        # --- Train ---
        torch.manual_seed(20)
        X_s_tr = torch.rand(n_train, 2)
        y_tr = (X_s_tr[:, 0] > 0.5).long() * 2 + (X_s_tr[:, 1] > 0.5).long()
        y_tr += 4
        X_tr = torch.zeros(n_train, self.input_dim)
        for d in range(75):
            X_tr[:, 150+d] = X_s_tr[:, 0]
            X_tr[:, 225+d] = X_s_tr[:, 1]
        X_tr += torch.randn_like(X_tr) * 0.05
        if n_test == 0:
            return X_tr, y_tr, torch.empty(0), torch.empty(0)
        # --- Test ---
        torch.manual_seed(88)
        X_s_te = torch.rand(n_test, 2)
        y_te = (X_s_te[:, 0] > 0.5).long() * 2 + (X_s_te[:, 1] > 0.5).long()
        y_te += 4
        X_te = torch.zeros(n_test, self.input_dim)
        for d in range(75):
            X_te[:, 150+d] = X_s_te[:, 0]
            X_te[:, 225+d] = X_s_te[:, 1]
        X_te += torch.randn_like(X_te) * 0.05
        return X_tr, y_tr, X_te, y_te

    def _train_column_with_readout(self, column, readout, opt, X, y, epochs=1):
        for epoch in range(epochs):
            for i in range(len(X)):
                x_sample = X[i].unsqueeze(0)
                spike_sum = torch.zeros(1, column.n_neurons, device=column.W.device)
                if hasattr(column.lif, "reset_state"):
                    column.lif.reset_state()
                else: 
                    column.lif.v = None; column.lif.a = None
                    
                column.train()
                for t in range(3):
                    spikes = column(x_sample)
                    spike_sum += spikes
                
                if column.training:
                    kappa, d_avg = column.compute_mgd_metrics()
                    dW = column.stdp.compute_weight_update(kappa, d_avg, D_target=2.0)
                    with torch.no_grad():
                        column.W.add_(dW)

                readout.train()
                opt.zero_grad()
                logits = readout(spike_sum)
                loss = nn.CrossEntropyLoss()(logits, y[i].unsqueeze(0))
                loss.backward()
                opt.step()

    def _evaluate(self, column, readout, X, y) -> tuple[float, float, float]:
        column.eval()
        if hasattr(readout, "eval"): readout.eval()
        correct = 0
        spike_sums = []
        with torch.no_grad():
            for i in range(len(X)):
                x_sample = X[i].unsqueeze(0)
                spike_sum = torch.zeros(1, column.n_neurons, device=column.W.device)
                if hasattr(column.lif, "reset_state"): column.lif.reset_state()
                else: column.lif.v = None; column.lif.a = None
                
                for t in range(3): spike_sum += column(x_sample)
                spike_sums.append(spike_sum)
                if hasattr(readout, "predict"):
                    pred = readout.predict(spike_sum)
                else:
                    logits = readout(spike_sum)
                    pred = logits.argmax(dim=1)
                if pred == y[i]: correct += 1
                
        spike_tns = torch.cat(spike_sums, dim=0)
        spike_var = spike_tns.std(dim=0).mean().item()
        b_norm = readout.bias.norm().item() if hasattr(readout, "bias") and readout.bias is not None else 0.0
        acc = correct / len(X)
        return acc, spike_var, b_norm

    def _evaluate_hierarchical(self, brain, readout, X, y, task_id) -> tuple[float, float, float]:
        brain.L3.eval()
        if hasattr(readout, "eval"): readout.eval()
        correct = 0
        with torch.no_grad():
            for i in range(len(X)):
                x_s = X[i].unsqueeze(0).to(brain.L3.W.device) # X è già su device idealmente
                L1, _, _, L2, _, _, L3, area, _ = brain.get_routing_components(task_id)
                # Reset
                if hasattr(L1.lif, "reset_state"):
                    L1.lif.reset_state(); L2.lif.reset_state(); L3.lif.reset_state()
                else:
                    L1.lif.v=None; L1.lif.a=None; L2.lif.v=None; L2.lif.a=None; L3.lif.v=None; L3.lif.a=None
                
                sum_h3 = torch.zeros(1, L3.n_neurons, device=x_s.device)
                sum_h1 = torch.zeros(1, L1.n_neurons, device=x_s.device)
                for t in range(3):
                    h1, h2, h3 = brain(x_s, task_id)
                    sum_h1 += h1
                    sum_h3 += h3
                sum_h_readout = sum_h1 if area == 'synthetic' else sum_h3
                pred = readout(sum_h_readout).argmax(dim=1)
                if pred == y[i]: correct += 1
        acc = correct / len(X)
        return acc, 0.0, 0.0

    def _evaluate_biomgd(self, brain, readout, X, y, task_id) -> tuple[float, float, float]:
        hip, col, gate, replay, L2, gate_L2, L3, area = brain.get_routing_components(task_id)
        hip.eval()
        col.eval()
        L2.eval()
        L3.eval()
        readout.eval()
        correct = 0
        with torch.no_grad():
            for i in range(len(X)):
                x_s = X[i].unsqueeze(0).to(X.device)
                
                if hasattr(hip.lif, "reset_state"):
                    hip.lif.reset_state(); col.lif.reset_state()
                    L2.lif.reset_state(); L3.lif.reset_state()
                else:
                    hip.lif.v=None; hip.lif.a=None; col.lif.v=None; col.lif.a=None
                    L2.lif.v=None; L2.lif.a=None; L3.lif.v=None; L3.lif.a=None
                
                sum_h1 = torch.zeros(1, col.n_neurons, device=X.device)
                for t in range(3):
                    _, h1, _, _ = brain(x_s, task_id)
                    sum_h1 += h1
                    
                out = readout(sum_h1)
                pred = out.argmax(dim=1)
                y_safe = y[i] % 10
                if pred.item() == y_safe.item():
                    correct += 1
        acc = correct / len(X)
        return acc, 0.0, 0.0
        
    def quick_test_task1_accuracy(self, epochs: int = 3) -> float:
        torch.manual_seed(1)
        col = CorticalColumn(n_neurons=100, input_dim=784, target_sparsity=0.1)
        col.stdp = STDPLocal(784, 100)
        col.stdp.A_minus = -0.1
        readout = nn.Linear(100, 4)
        opt = torch.optim.Adam(readout.parameters(), lr=0.01)
        
        X, y = self._create_xor_task(64)
        
        self._train_column_with_readout(col, readout, opt, X, y, epochs=epochs)
        acc, _, _ = self._evaluate(col, readout, X, y)
        return float(acc)

    def quick_test_forgetting_task1_to_2(self) -> tuple[float, float]:
        torch.manual_seed(1)
        col_A = CorticalColumn(n_neurons=100, input_dim=784, target_sparsity=0.1)
        col_A.stdp = STDPLocal(784, 100)
        col_A.stdp.A_minus = -0.1
        readout_A = nn.Linear(100, 8)
        opt_A = torch.optim.Adam(readout_A.parameters(), lr=0.01)
        
        col_C = CorticalColumn(n_neurons=100, input_dim=784, target_sparsity=0.1)
        col_C.stdp = STDPMgd(784, 100)
        col_C.stdp.A_minus = -0.1
        readout_C = nn.Linear(100, 8)
        opt_C = torch.optim.Adam(readout_C.parameters(), lr=0.01)
        
        X1, y1 = self._create_xor_task(64)
        X2, y2 = self._create_banded_task(64)
        
        self._train_column_with_readout(col_A, readout_A, opt_A, X1, y1, epochs=8)
        self._train_column_with_readout(col_C, readout_C, opt_C, X1, y1, epochs=8)
        
        acc_A_T1_bz, _, _ = self._evaluate(col_A, readout_A, X1, y1)
        acc_C_T1_bz, _, _ = self._evaluate(col_C, readout_C, X1, y1)
        
        self._train_column_with_readout(col_A, readout_A, opt_A, X2, y2, epochs=8)
        self._train_column_with_readout(col_C, readout_C, opt_C, X2, y2, epochs=8)
        
        acc_A_T1_after, _, _ = self._evaluate(col_A, readout_A, X1, y1)
        acc_C_T1_after, _, _ = self._evaluate(col_C, readout_C, X1, y1)
        
        return float(acc_A_T1_bz - acc_A_T1_after), float(acc_C_T1_bz - acc_C_T1_after)

    def quick_test_forgetting_D(self) -> tuple[float, float]:
        torch.manual_seed(1)
        
        # Inizializziamo i due modelli D
        col_lowvar = CorticalColumn(n_neurons=200, input_dim=784, target_sparsity=0.1)
        col_lowvar.stdp = STDPMgd(784, 200)
        col_lowvar.stdp.A_minus = -0.1
        readout_lowvar = nn.Linear(200, 8)
        opt_lowvar = torch.optim.Adam(readout_lowvar.parameters(), lr=0.01)
        gate_lowvar = ModularGate(200, 4)
        rep_lowvar = MGDReplayBuffer(50)
        
        col_rand = CorticalColumn(n_neurons=200, input_dim=784, target_sparsity=0.1)
        col_rand.stdp = STDPMgd(784, 200)
        col_rand.stdp.A_minus = -0.1
        readout_rand = nn.Linear(200, 8)
        opt_rand = torch.optim.Adam(readout_rand.parameters(), lr=0.01)
        gate_rand = ModularGate(200, 4)
        rep_rand = MGDReplayBuffer(50)
        
        # A_baseline equivalente (200 neuroni, 784 input) senza gate/replay e con STDPLocal
        col_A_base = CorticalColumn(n_neurons=200, input_dim=784, target_sparsity=0.1)
        col_A_base.stdp = STDPLocal(784, 200)
        readout_A_base = nn.Linear(200, 8)
        opt_A_base = torch.optim.Adam(readout_A_base.parameters(), lr=0.01)
        
        X1_tr, y1_tr, X1_te, y1_te = self._create_xor_task_split(n_train=64, n_test=200)
        X2_tr, y2_tr, _,    _        = self._create_banded_task_split(n_train=64, n_test=0)
        # Alias per il loop di training (allena su train)
        X1, y1 = X1_tr, y1_tr
        X2, y2 = X2_tr, y2_tr
        
        # --- Task 1 ---
        for name, col, ro, opt, gate, rep, strat in [
            ("lowvar", col_lowvar, readout_lowvar, opt_lowvar, gate_lowvar, rep_lowvar, "low_variance"),
            ("rand", col_rand, readout_rand, opt_rand, gate_rand, rep_rand, "random"),
            ("A_base", col_A_base, readout_A_base, opt_A_base, None, None, None)
        ]:
            if gate is not None:
                gate.register_task(0, col, 0.3, strat)
                
            for e in range(8):
                # Calcola metriche per MGD (solo se è STDPMgd)
                cached_k, cached_d = None, None
                if isinstance(col.stdp, STDPMgd):
                    cached_k, cached_d = col.compute_mgd_metrics()
                    
                for i in range(len(X1)):
                    x_s = X1[i].unsqueeze(0)
                    sum_s = torch.zeros(1, 200)
                    if hasattr(col.lif, "reset_state"): col.lif.reset_state()
                    else: col.lif.v = None; col.lif.a = None
                    col.train()
                    dW_accum = 0
                    for _ in range(3):
                        sum_s += col(x_s)
                        if isinstance(col.stdp, STDPMgd):
                            dW_accum += col.stdp.compute_weight_update(cached_k, cached_d, D_target=2.0)
                        else:
                            dW_accum += col.stdp.compute_weight_update()
                            
                    dW_total = dW_accum
                    if gate is not None:
                        dW_total = gate.apply_mask_to_dW(dW_accum, 0)
                        
                    with torch.no_grad():
                        col.W.add_(dW_total)
                        col.W.data = apply_homeostatic_normalization(col.W.data, target_sum=15.0)
                        col.W.data.clamp_(0.0, 5.0)
                    ro.train()
                    opt.zero_grad()
                    loss = nn.CrossEntropyLoss()(ro(sum_s), y1[i].unsqueeze(0))
                    loss.backward()
                    opt.step()
            if rep is not None:
                rep.add_task(0, X1, y1, col)
            
        # Valuta su TEST SET (mai visto durante il training)
        acc_lowvar_T1_bz, _, _ = self._evaluate(col_lowvar, readout_lowvar, X1_te, y1_te)
        acc_rand_T1_bz, _, _ = self._evaluate(col_rand, readout_rand, X1_te, y1_te)
        acc_A_base_T1_bz, _, _ = self._evaluate(col_A_base, readout_A_base, X1_te, y1_te)
        
        # --- Task 2 ---
        for name, col, ro, opt, gate, rep, strat in [
            ("lowvar", col_lowvar, readout_lowvar, opt_lowvar, gate_lowvar, rep_lowvar, "low_variance"),
            ("rand", col_rand, readout_rand, opt_rand, gate_rand, rep_rand, "random"),
            ("A_base", col_A_base, readout_A_base, opt_A_base, None, None, None)
        ]:
            if gate is not None:
                gate.register_task(1, col, 0.3, strat)
                
            for e in range(8):
                cached_k, cached_d = None, None
                if isinstance(col.stdp, STDPMgd):
                    cached_k, cached_d = col.compute_mgd_metrics()
                    
                for i in range(len(X2)):
                    x_s = X2[i].unsqueeze(0)
                    sum_s = torch.zeros(1, 200)
                    if hasattr(col.lif, "reset_state"): col.lif.reset_state()
                    else: col.lif.v = None; col.lif.a = None
                    col.train() 
                    dW_accum = 0
                    for _ in range(3):
                        sum_s += col(x_s)
                        if isinstance(col.stdp, STDPMgd):
                            dW_accum += col.stdp.compute_weight_update(cached_k, cached_d, D_target=2.0)
                        else:
                            dW_accum += col.stdp.compute_weight_update()
                            
                    dW_total = dW_accum
                    if gate is not None:
                        dW_total = gate.apply_mask_to_dW(dW_accum, 1)
                        
                    with torch.no_grad():
                        col.W.add_(dW_total)
                        col.W.data = apply_homeostatic_normalization(col.W.data, target_sum=15.0)
                        col.W.data.clamp_(0.0, 5.0)
                    
                    # Interleaved Replay (solo se c'è replay)
                    if rep is not None and torch.rand(1).item() < 0.3:
                        for r_t_idx, (X_rep, y_rep) in rep.sample_replay(10):
                            for r_i in range(len(X_rep)):
                                xr_s = X_rep[r_i].unsqueeze(0)
                                if hasattr(col.lif, "reset_state"): col.lif.reset_state()
                                else: col.lif.v = None; col.lif.a = None
                                dW_rep = 0
                                for _ in range(3):
                                    col(xr_s)
                                    if isinstance(col.stdp, STDPMgd):
                                        dW_rep += col.stdp.compute_weight_update(cached_k, cached_d, D_target=2.0)
                                    else:
                                        dW_rep += col.stdp.compute_weight_update()
                                dW_rep = gate.apply_mask_to_dW(dW_rep, r_t_idx)
                                with torch.no_grad():
                                    col.W.add_(dW_rep * 0.3)
                                    col.W.data.clamp_(0.0, 5.0)
                                    
                    ro.train()
                    opt.zero_grad()
                    loss = nn.CrossEntropyLoss()(ro(sum_s), y2[i].unsqueeze(0))
                    loss.backward()
                    opt.step()
            
        acc_lowvar_T1_after, _, _ = self._evaluate(col_lowvar, readout_lowvar, X1_te, y1_te)
        acc_rand_T1_after, _, _ = self._evaluate(col_rand, readout_rand, X1_te, y1_te)
        acc_A_base_T1_after, _, _ = self._evaluate(col_A_base, readout_A_base, X1_te, y1_te)
        
        print(f"=== TEST SET (n=200, mai visto) ===")
        print(f"acc_lowvar_T1_bz:    {acc_lowvar_T1_bz:.3f}")
        print(f"acc_lowvar_T1_after: {acc_lowvar_T1_after:.3f}")
        print(f"acc_A_base_T1_bz:    {acc_A_base_T1_bz:.3f}")
        print(f"acc_A_base_T1_after: {acc_A_base_T1_after:.3f}")
        print(f"---")
        print(f"Forgetting D_lowvar: {float(acc_lowvar_T1_bz - acc_lowvar_T1_after):.3f}")
        print(f"Forgetting D_rand:   {float(acc_rand_T1_bz - acc_rand_T1_after):.3f}")
        print(f"Forgetting A_base:   {float(acc_A_base_T1_bz - acc_A_base_T1_after):.3f}")
        
        return (float(acc_lowvar_T1_bz - acc_lowvar_T1_after), 
                float(acc_rand_T1_bz - acc_rand_T1_after),
                float(acc_A_base_T1_bz - acc_A_base_T1_after))

    def run_task_sequence_extended(self, n_extra_tasks=5, skip_hierarchical=True):
        """Estende la sequenza standard con n_extra_tasks task extra
        (rotazione ciclica dei task esistenti).
        Usato per testare il pruning strutturale che richiede piu task per agire.
        """
        print("Pre-loading MNIST & Geometric Tasks (extended)...")
        t1 = self._create_xor_task(60)
        t2 = self._create_banded_task(60)
        t3, t4 = self._get_mnist_subsets(60)
        tasks_data = [t1, t2, t3, t4]
        try:
            import tonic
            t5 = self._get_nmnist_subset(60)
            tasks_data.append(t5)
        except ImportError:
            pass
        
        # Aggiunge task extra riciclando i task base in ordine ciclico
        base_len = len(tasks_data)
        for i in range(n_extra_tasks):
            tasks_data.append(tasks_data[i % base_len])
        
        print(f"Extended sequence: {len(tasks_data)} task totali ({base_len} base + {n_extra_tasks} extra)")
        return self.run_task_sequence(tasks_data=tasks_data, skip_hierarchical=skip_hierarchical)

    def run_task_sequence(self, tasks_data=None, skip_hierarchical=False):
        if tasks_data is None:
            print("Pre-loading MNIST & Geometric Tasks...")
            t1 = self._create_xor_task(60)
            t2 = self._create_banded_task(60)
            t3, t4 = self._get_mnist_subsets(60)
            tasks_data = [t1, t2, t3, t4]
            
            # Task 5 opzionale: N-MNIST
            try:
                from cortical_mgd.data.nmnist_loader import load_nmnist_flat
                print("Caricamento N-MNIST (Task 5)...")
                X5, y5 = load_nmnist_flat(n_samples=200, split='train')
                if X5 is not None:
                    tasks_data.append((X5, y5))
                    self.n_tasks = len(tasks_data)
                    print("[Benchmark] Task 5: N-MNIST caricato con successo.")
            except ImportError:
                print("[Benchmark] Tonic non installato. Skipping N-MNIST (Task 5).")
                self.n_tasks = len(tasks_data)
        else:
            self.n_tasks = len(tasks_data)
        
        models = {
            "A_STDPLocal": CorticalColumn(self.n_neurons, self.input_dim, target_sparsity=0.1),
            "B_MGD_EWC": CorticalColumn(self.n_neurons, self.input_dim, target_sparsity=0.1),
            "C_STDP_MGD": CorticalColumn(self.n_neurons, self.input_dim, target_sparsity=0.1),
            "D_MGD_random": CorticalColumn(200, self.input_dim, target_sparsity=0.1),
            "D_MGD_lowvar": CorticalColumn(200, self.input_dim, target_sparsity=0.1),
            "D_MGD_FULL": CorticalColumn(400, self.input_dim, target_sparsity=0.1),
            "H_LocalMGD": CorticalColumn(self.n_neurons, self.input_dim, target_sparsity=0.1),
            "I_OverlapMGD": CorticalColumn(500, self.input_dim, target_sparsity=0.1),
            "J_NeuromorphicMGD": CorticalColumn(500, self.input_dim, target_sparsity=0.1)
        }
        models["A_STDPLocal"].stdp = STDPLocal(self.input_dim, self.n_neurons)
        models["B_MGD_EWC"].stdp = STDPMgd(self.input_dim, self.n_neurons)
        models["C_STDP_MGD"].stdp = STDPMgd(self.input_dim, self.n_neurons)
        models["D_MGD_random"].stdp = STDPMgd(self.input_dim, 200)
        models["D_MGD_lowvar"].stdp = STDPMgd(self.input_dim, 200)
        models["D_MGD_FULL"].stdp = STDPMgd(self.input_dim, 400)
        models["H_LocalMGD"].stdp = STDPLocalMGD(self.input_dim, self.n_neurons)
        models["I_OverlapMGD"].stdp = STDPLocalMGD(self.input_dim, 500)
        models["J_NeuromorphicMGD"].stdp = STDPLocalMGD(self.input_dim, 500)
        
        replays = {
            "D_MGD_random": MGDReplayBuffer(capacity_per_task=50),
            "D_MGD_lowvar": MGDReplayBuffer(capacity_per_task=50),
            "D_MGD_FULL": MGDReplayBuffer(capacity_per_task=100),
            "I_OverlapMGD": MGDReplayBuffer(capacity_per_task=50),
            "J_NeuromorphicMGD": MGDReplayBuffer(capacity_per_task=50)
        }
        
        if hasattr(self, "only_models"):
            models = {k: v for k, v in models.items() if k in self.only_models}
        gates = {
            "D_MGD_random": ModularGate(n_neurons=200, n_tasks=30),
            "D_MGD_lowvar": ModularGate(n_neurons=200, n_tasks=30),
            "D_MGD_FULL": ModularGate(n_neurons=400, n_tasks=30),
            "I_OverlapMGD": ModularGate(n_neurons=500, n_tasks=30),
            "J_NeuromorphicMGD": ModularGate(n_neurons=500, n_tasks=30)
        }
        
        # Modifica utente: riequilibrio rate LTD per inputs statici 1000Hz
        for m in models.values():
            m.stdp.A_minus = -0.1
        
        # Device placement: CUDA se disponibile
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        print(f"Using device: {device}")
        for col in models.values():
            col.to(device)
        tasks_data = [(X.to(device), y.to(device)) for X, y in tasks_data]
        
        # Multi-Head Setup: Isoliamo la dimenticanza lineare dal Representation Drift
        readouts = {k: [] for k in models.keys()}
        
        # FIX 15: Inizializzazione interneuroni per I_OverlapMGD e J_NeuromorphicMGD
        for m_ident in ["I_OverlapMGD", "J_NeuromorphicMGD"]:
            if m_ident in models:
                col_I = models[m_ident]
                n_intern = int(col_I.n_neurons * 0.10)
                intern_idx = torch.randperm(col_I.n_neurons)[:n_intern]
                col_I.W.data[:, intern_idx] *= 0.3
                gates[m_ident].interneuron_idx = set(intern_idx.tolist())
        
        # Inizializzazione StructuralPlasticity per I_OverlapMGD
        sp_I = None
        if "I_OverlapMGD" in models:
            col_I = models["I_OverlapMGD"]
            sp_I = StructuralPlasticity(
                n_neurons=col_I.n_neurons,
                input_dim=col_I.W.shape[0],
                epsilon=0.05,
                tau_pruning=1,  # Fase 8: pruning già da Task2
                grow_threshold=0.1,
            )
        
        ewc_module = None
        if "B_MGD_EWC" in models:
            ewc_module = GeometricEWC(model=models["B_MGD_EWC"], lambda_ewc=30.0)
        ewc_cache = {"Ws": None, "imp": None}
        
        ewc_full = None
        if "D_MGD_FULL" in models:
            ewc_full = GeometricEWC(model=models["D_MGD_FULL"], lambda_ewc=30.0)
        ewc_full_cache = {"Ws": None, "imp": None}
        ewc_overlap = None
        if "I_OverlapMGD" in models:
            ewc_overlap = GeometricEWC(model=models["I_OverlapMGD"], lambda_ewc=15.0)
        ewc_overlap_cache = {"Ws": None, "imp": None}
        # FIX extra: DA neuromodulation history
        i_acc_history = []
        results = []
        
        for t_idx, current_task_data in enumerate(tasks_data):
            X_curr, y_curr = current_task_data
            y_curr = y_curr % 10 # bounds safety
            
            # Inizializziamo Head fresco per il Task Corrente
            for m_name in models.keys():
                n_out = models[m_name].n_neurons  # 100 per A/B/C, 200 per D_*
                if m_name == "J_NeuromorphicMGD":
                    r = BioReadout(n_out, 10).to(device)
                    o = None
                else:
                    r = nn.Linear(n_out, 10).to(device)
                    o = torch.optim.Adam(r.parameters(), lr=0.01)
                readouts[m_name].append((r, o))
            
            if t_idx == 1:
                print(f"Task 2 y distribution: {y_curr.unique()}")
                print(f"Task 2 after %10: {(y_curr % 10).unique()}")
                
            print(f"--- Processing Architectural Run: Task {t_idx+1}/4 ---")
            for m_name, column in models.items():
                if m_name == "D_MGD_random":
                    gates[m_name].register_task(t_idx, column, fraction=0.3, strategy="random")
                elif m_name in ("D_MGD_lowvar", "D_MGD_FULL"):
                    gates[m_name].register_task(t_idx, column, fraction=0.25, strategy="low_variance")
                elif m_name in ("I_OverlapMGD", "J_NeuromorphicMGD"):
                    gates[m_name].register_task_overlapping(t_idx, column, fraction=0.10)  # FIX 3
                    
                if m_name in ("I_OverlapMGD", "J_NeuromorphicMGD") and t_idx >= 4:
                    column.target_sparsity = 0.05
                    
                n_curr = column.n_neurons
                readout, opt = readouts[m_name][t_idx]
                active_spks = 0
                
                # FIX 10: Reset tracce STDP al cambio task per I_OverlapMGD
                if m_name == 'I_OverlapMGD':
                    column.stdp.trace_pre = None
                    column.stdp.trace_post = None
                    if hasattr(column.stdp, 'last_pre_spikes'): column.stdp.last_pre_spikes = None
                    if hasattr(column.stdp, 'last_post_spikes'): column.stdp.last_post_spikes = None
                
                epochs_run = 5 if t_idx == 1 else 2
                
                if column.training:
                    cached_kappa, cached_d_avg = column.compute_mgd_metrics()
                else:
                    cached_kappa, cached_d_avg = 1.0, 1.0
                    
                for epoch in range(epochs_run):
                    for i in range(len(X_curr)):
                        x_s = X_curr[i].unsqueeze(0)
                        sum_s = torch.zeros(1, n_curr, device=column.W.device)
                        if hasattr(column.lif, "reset_state"): column.lif.reset_state()
                        else: column.lif.v = None; column.lif.a = None
                        
                        column.train()
                        dW_accum = 0
                        for t in range(3):
                            spks = column(x_s)
                            
                            # FIX 9: WTA per-task solo sui neuroni plastici di I_OverlapMGD
                            if m_name == "I_OverlapMGD" and m_name in gates:
                                plastic = gates[m_name].get_plastic_mask(t_idx).bool().to(spks.device)
                                spks_masked = spks.clone()
                                spks_masked[:, ~plastic] = 0.0
                                k_wta = max(1, int(plastic.sum().item() * 0.1))
                                if spks_masked.sum() > k_wta:
                                    topk = torch.topk(spks_masked, k_wta, dim=1).indices
                                    wta_out = torch.zeros_like(spks_masked)
                                    wta_out.scatter_(1, topk, 1.0)
                                    spks = wta_out
                                    
                                # FIX 14: Hub neurons sparano meno (sparsita ridotta)
                                if t_idx >= 2:
                                    hub_mask = gates[m_name].get_shared_neurons()
                                    if hub_mask is not None:
                                        hub_idx = hub_mask.bool().to(spks.device)
                                        spks[:, hub_idx] *= 0.5
                            
                            sum_s += spks
                            active_spks += int(spks.sum().item())
                            if column.training:
                                if m_name in ("H_LocalMGD", "I_OverlapMGD", "J_NeuromorphicMGD"):
                                    column.stdp.update_traces(x_s, spks)
                                    column.stdp._W_ref = column.W
                                    if m_name in ("I_OverlapMGD", "J_NeuromorphicMGD") and m_name in gates:
                                        gates[m_name].update_coactivation(x_s, spks, task_id=t_idx)  # FIX 4
                                        if sp_I is not None:  # Fase 8: co-attivazione strutturale
                                            sp_I.update_coactivation(x_s, spks)
                                    dW_accum += column.stdp.compute_weight_update()
                                else:
                                    dW_accum += column.stdp.compute_weight_update(cached_kappa, cached_d_avg, D_target=2.0)
                        
                        # FIX 7: Normalizza sum_s per I_OverlapMGD
                        if m_name == "I_OverlapMGD":
                            n_active = (sum_s > 0).float().sum(dim=1, keepdim=True).clamp(min=1)
                            sum_s = sum_s / n_active * 10.0
                        
                        if column.training:
                            dW_total = dW_accum
                            # EWC per B_MGD_EWC
                            if m_name == "B_MGD_EWC" and ewc_module is not None and ewc_cache["imp"] is not None:
                                grad = 2 * ewc_module.lambda_ewc * ewc_cache["imp"] * (column.W.detach() - ewc_cache["Ws"])
                                dW_total -= grad
                            # EWC mascherato per D_MGD_FULL: applica solo sui neuroni attivi del task corrente
                            if m_name == "D_MGD_FULL" and ewc_full is not None and ewc_full_cache["imp"] is not None:
                                mask = gates[m_name].get_plastic_mask(t_idx).to(column.W.device)
                                grad_full = 2 * ewc_full.lambda_ewc * ewc_full_cache["imp"] * (column.W.detach() - ewc_full_cache["Ws"])
                                # Applica EWC FUORI dalla maschera (protegge i neuroni frozen)
                                frozen_mask = (1.0 - mask).unsqueeze(0)
                                dW_total -= grad_full * frozen_mask
                            # EWC selettivo per I_OverlapMGD: solo neuroni condivisi (FIX 13)
                            if m_name == "I_OverlapMGD" and t_idx > 0 and ewc_overlap is not None and ewc_overlap_cache["imp"] is not None:
                                shared = gates[m_name].get_shared_neurons()
                                if shared is not None:
                                    shared_dev = shared.to(column.W.device)
                                    grad_ov = 2 * ewc_overlap.lambda_ewc * ewc_overlap_cache["imp"] * (column.W.detach() - ewc_overlap_cache["Ws"])
                                    dW_total -= grad_ov * shared_dev.unsqueeze(0)
                                else:
                                    # Prima di avere neuroni condivisi usa EWC globale
                                    grad_ov = 2 * ewc_overlap.lambda_ewc * ewc_overlap_cache["imp"] * (column.W.detach() - ewc_overlap_cache["Ws"])
                                    dW_total -= grad_ov
                                
                            if m_name in gates:
                                dW_total = gates[m_name].apply_mask_to_dW(dW_total, t_idx)
                            
                            # FIX extra: Dopamina - scala dW se accuracy migliora
                            eta_factor_I = 1.0
                            if m_name in ("I_OverlapMGD", "J_NeuromorphicMGD") and t_idx > 0 and len(i_acc_history) > 0:
                                import numpy as np
                                current_acc_est = float((sum_s.argmax(dim=1) == y_curr[i].unsqueeze(0)).float().mean())
                                DA = max(0.0, current_acc_est - float(np.mean(i_acc_history[-3:] if len(i_acc_history) >= 3 else i_acc_history)))
                                eta_factor_I = min(1.0 + DA * 2.0, 3.0)
                                dW_total = dW_total * eta_factor_I

                            with torch.no_grad(): 
                                W_pre = column.W.data.clone()
                                column.W.add_(dW_total)
                                # Homeostasis mascherata: tocca SOLO i neuroni plastici del task corrente
                                if m_name in gates:
                                    plastic_mask = gates[m_name].get_plastic_mask(t_idx).bool()
                                    W_plastic = column.W.data[:, plastic_mask]
                                    column.W.data[:, plastic_mask] = apply_homeostatic_normalization(
                                        W_plastic, target_sum=15.0)
                                    # neuroni frozen: column.W.data[:, ~plastic_mask] rimane intatto
                                else:
                                    column.W.data = apply_homeostatic_normalization(column.W.data, target_sum=15.0)
                                torch.clamp_(column.W.data, 0.0, 5.0)
                                W_post = column.W.data
                                
                                eff_dw = (W_post - W_pre).norm().item()
                                raw_dw = dW_total.norm().item() + 1e-9
                                if epoch == 0 and i == 0:
                                    print(f"[{m_name}] Epoch 0, Step 0. eff_dW/raw_dW: {eff_dw/raw_dw:.4f}")
                                    
                        # Interleaved Replay Check
                        if column.training and m_name in replays and replays[m_name].n_tasks() > 0:
                            if torch.rand(1).item() < 0.4:
                                for r_t_idx, (X_rep, y_rep) in replays[m_name].sample_replay(10):
                                    for r_i in range(len(X_rep)):
                                        xr_s = X_rep[r_i].unsqueeze(0).to(column.W.device)
                                        if hasattr(column.lif, "reset_state"): column.lif.reset_state()
                                        else: column.lif.v = None; column.lif.a = None
                                        
                                        dW_rep = 0
                                        for _ in range(3):
                                            spks_rep = column(xr_s)
                                            if m_name in ("I_OverlapMGD", "J_NeuromorphicMGD"):
                                                column.stdp.update_traces(xr_s, spks_rep)
                                                column.stdp._W_ref = column.W
                                                # FIX 2: NO update_coactivation in replay
                                                dW_rep += column.stdp.compute_weight_update()
                                            else:
                                                dW_rep += column.stdp.compute_weight_update(cached_kappa, cached_d_avg, D_target=2.0)
                                            
                                        dW_rep = gates[m_name].apply_mask_to_dW(dW_rep, r_t_idx)
                                        with torch.no_grad():
                                            column.W.add_(dW_rep * 0.3)
                                            torch.clamp_(column.W.data, 0.0, 5.0)
                                            # Fase 8: applica connettività anche post-replay
                                            if m_name == "I_OverlapMGD" and sp_I is not None:
                                                column.W.data = sp_I.apply_connectivity(column.W)
                                            
                                # FIX 5: Reset tracce STDP dopo replay session
                                if m_name in ("I_OverlapMGD", "J_NeuromorphicMGD"):
                                    column.stdp.trace_pre = None
                                    column.stdp.trace_post = None
                                    column.stdp.last_pre_spikes = None
                                    column.stdp.last_post_spikes = None
                        
                        if m_name == "J_NeuromorphicMGD":
                            pred = readout.online_step(
                                sum_s, 
                                int(y_curr[i].item() % 10),
                                da_signal=eta_factor_I
                            )
                        else:
                            readout.train()
                            opt.zero_grad()
                            loss = nn.CrossEntropyLoss()(readout(sum_s), y_curr[i].unsqueeze(0))
                            loss.backward()
                            opt.step()
                
                # Consolidate EWC & Replay
                if m_name == "B_MGD_EWC":
                    ewc_cache["imp"] = ewc_module.compute_importance(column.W.detach())
                    ewc_cache["Ws"] = column.W.detach().clone()
                if m_name == "D_MGD_FULL":
                    ewc_full_cache["imp"] = ewc_full.compute_importance(column.W.detach())
                    ewc_full_cache["Ws"] = column.W.detach().clone()
                if m_name == "I_OverlapMGD" and t_idx == 0 and ewc_overlap is not None:
                    ewc_overlap_cache["imp"] = ewc_overlap.compute_importance(column.W.detach())
                    ewc_overlap_cache["Ws"] = column.W.detach().clone()
                # Fase 8: Pruning + Sinaptogenesi + liberazione neuroni morti
                if m_name == "I_OverlapMGD" and sp_I is not None:
                    with torch.no_grad():
                        # Pruning sinaptico
                        allocated = set(gates[m_name].allocation_time.keys())
                        sp_I.prune(column.W, t_idx, gates[m_name].allocation_time, protected_neurons=allocated)
                        # Sinaptogenesi
                        column.W.data = sp_I.grow(column.W)
                        # Applica maschera connettività
                        column.W.data = sp_I.apply_connectivity(column.W)
                    # Libera neuroni morti (tutte le sinapsi potate)
                    neuron_conn = sp_I.connectivity.sum(dim=0)  # [n_neurons]
                    dead = neuron_conn < 1.0
                    dead_indices = dead.nonzero(as_tuple=False)
                    if dead_indices.numel() > 0:
                        for j in dead_indices.squeeze(-1).tolist():
                            gates[m_name].allocated_neurons[j] = False
                            gates[m_name].allocation_time.pop(j, None)
                            gates[m_name].all_allocated.discard(j)
                            print(f'[Pruning] Neurone {j} liberato')
                    # Print diagnostico: sinapsi attive dopo ogni task
                    n_active_conn = sp_I.connectivity.sum().item()
                    n_total_conn = sp_I.connectivity.numel()
                    print(f'[SP] Task{t_idx+1}: {n_active_conn:.0f}/{n_total_conn} sinapsi attive '
                          f'({100*n_active_conn/n_total_conn:.1f}%)')
                if m_name in replays:
                    replays[m_name].add_task(t_idx, X_curr, y_curr, column)
                    
                # FIX 6: Sleep readout-only dopo ogni task per I_OverlapMGD
                if m_name == "I_OverlapMGD" and t_idx > 0:
                    import random
                    W_before_sleep = column.W.data.clone()  # FIX 12: salva W prima del sleep
                    for prev_t in range(t_idx):
                        ro_prev, opt_prev = readouts[m_name][prev_t]
                        # Prendi campioni, shuffla, fai batch da 8
                        samples = list(replays[m_name].buffer.get(prev_t, [])) if hasattr(replays[m_name].buffer, 'get') else list(replays[m_name].buffer[prev_t])
                        if not samples: continue
                        random.shuffle(samples)
                        
                        # Usa lr molto piccolo
                        for pg in opt_prev.param_groups:
                            pg['lr'] = 0.0005
                            
                        # Max 30 step (was 20)
                        step = 0
                        for i in range(0, len(samples), 8):
                            if step >= 30: break
                            batch = samples[i:i+8]
                            X_b = torch.stack([s[0] for s in batch]).to(column.W.device)
                            y_b = torch.stack([s[1] for s in batch]).to(column.W.device)
                            
                            column.eval()
                            if hasattr(column.lif, "reset_state"): column.lif.reset_state()
                            else: column.lif.v = None; column.lif.a = None
                            
                            with torch.no_grad():
                                sum_h = torch.zeros(len(batch), column.n_neurons, device=column.W.device)
                                for _ in range(3):
                                    for j, x_s in enumerate(X_b):
                                        sum_h[j] += column(x_s.unsqueeze(0)).squeeze(0)
                                        
                            ro_prev.train()
                            opt_prev.zero_grad()
                            loss = nn.CrossEntropyLoss()(ro_prev(sum_h), y_b % 10)
                            loss.backward()
                            opt_prev.step()
                            step += 1
                    # FIX 12: verifica che W non sia stato modificato durante sleep
                    assert torch.allclose(W_before_sleep, column.W.data, atol=1e-6), \
                        'W modificato durante sleep!'
            # Check Metrics against all Tasks up to now!
            for m_name, column in models.items():
                accs = []
                vars = []
                bnorms = []
                for pt in range(t_idx + 1):
                    X_e, y_e = tasks_data[pt]
                    readout_pt, _ = readouts[m_name][pt] # Head Addestrato su quel Task
                    a, sv, bn = self._evaluate(column, readout_pt, X_e, y_e % 10)
                    accs.append(a)
                    vars.append(sv)
                    bnorms.append(bn)
                    
                    if pt == 0 and t_idx > 0:
                        prev_acc = results[len(models)*(t_idx-1) + list(models.keys()).index(m_name)]["Accuracy_Task1"]
                        print(f"[{m_name}] Task1 Accuracy Forgetting check: Before={prev_acc:.3f}, Now={a:.3f}")
                
                kappa, d_avg = column.compute_mgd_metrics()
                W_np = column.W.detach().cpu().numpy()
                
                # Ottimizzazione graph cut per S_RT: operiamo sulla topologia delle sinapsi in ricezione
                if W_np.shape[0] > W_np.shape[1]:
                    W_gram = W_np.T @ W_np
                else: 
                    W_gram = W_np @ W_np.T
                    
                half = W_gram.shape[0] // 2
                s_rt = compute_S_RT(W_gram, list(range(half)), list(range(half, W_gram.shape[0])))
                flops = self.profiler.compute_inference_energy(active_spks, column.W.numel())
                
                results.append({
                    "Task": t_idx + 1, "Model": m_name,
                    "Accuracy_Current": accs[-1], "Accuracy_Task1": accs[0],
                    "Cov_Spike_T1": vars[0], "Bias_Norm_T1": bnorms[0],
                    "D_avg": d_avg, "kappa": kappa, "S_RT": s_rt, "Energy_Joules": flops
                })
        
        self.results_df = pd.DataFrame(results)
        
        # Fase 8: esponi gate I per verifica scalabilita nel test
        if "I_OverlapMGD" in gates:
            self._last_gate_I = gates["I_OverlapMGD"]

        _extra = {'K_TemporalHierarchy', 'L_PredictiveHierarchy', 'M_DendriticHierarchy',
                  'E_CorticalBrain', 'F_HierarchicalBrain', 'G_BioMGDBrain'}
        if hasattr(self, 'only_models') and not _extra.intersection(self.only_models):
            self.results_df = pd.DataFrame(results)
            return self.results_df

        # ----------------------------------------------------------------
        # K_TemporalHierarchy — L1/L2/L3 con deep sleep biologico
        # ----------------------------------------------------------------
        k_brain = TemporalHierarchy(
            input_dim=self.input_dim, device=device, n_slow=3).to(device)
        k_accs_history = []

        for t_idx, (X_curr, y_curr) in enumerate(tasks_data):
            y_curr_safe = y_curr % 10

            area, novelty, eta_k = k_brain.register_task(t_idx, X_curr)
            col  = getattr(k_brain, f'cortex_{area}')
            gate = getattr(k_brain, f'gate_{area}')

            kappa_k, d_avg_k = col.compute_mgd_metrics()

            for ep in range(8):
                for i in range(len(X_curr)):
                    x_s    = X_curr[i].unsqueeze(0).to(device)
                    y_safe = int(y_curr[i].item() % 10)

                    k_brain.hippocampus.lif.reset_state()
                    col.lif.reset_state()
                    k_brain.slow_cortex.lif.reset_state()

                    sum_h = torch.zeros(1, col.n_neurons, device=device)
                    col.train()
                    k_brain.hippocampus.train()

                    for _ in range(3):
                        _, h_cortex, _ = k_brain.forward(x_s, t_idx)
                        sum_h += h_cortex

                    ro   = k_brain.readouts[t_idx]
                    ro.online_step(sum_h, y_safe, da_signal=eta_k)

                    dW   = col.stdp.compute_weight_update(kappa_k, d_avg_k, 2.0)
                    mask = gate.get_plastic_mask(t_idx).to(device)
                    dW   = dW * mask.unsqueeze(0) * eta_k
                    with torch.no_grad():
                        col.W.add_(dW)
                        col.W.data.clamp_(0.0, 5.0)

            replay_k = getattr(k_brain, f'replay_{area}')

            class _HipPre:
                def __init__(self, hip):
                    self.hip = hip
                def reset_state(self):
                    if hasattr(self.hip.lif, 'reset_state'):
                        self.hip.lif.reset_state()
                    else:
                        self.hip.lif.v = None
                        self.hip.lif.a = None
                def __call__(self, x):
                    return self.hip(x).detach()

            replay_k.add_task(
                t_idx, X_curr, y_curr_safe, col,
                preprocess_fn=_HipPre(k_brain.hippocampus))
            k_brain.consolidate(t_idx, device)

            accs_k = []
            for pt in range(t_idx + 1):
                X_e, y_e = tasks_data[pt]
                area_pt  = k_brain.task_routing[pt]
                col_pt   = getattr(k_brain, f'cortex_{area_pt}')
                ro_pt    = k_brain.readouts[pt]
                correct  = 0
                with torch.no_grad():
                    for i in range(len(X_e)):
                        x_s = X_e[i].unsqueeze(0).to(device)
                        k_brain.hippocampus.lif.reset_state()
                        col_pt.lif.reset_state()
                        sum_h = torch.zeros(
                            1, col_pt.n_neurons, device=device)
                        for _ in range(3):
                            _, h_c, _ = k_brain.forward(x_s, pt)
                            sum_h += h_c
                        if ro_pt.predict(sum_h) == int(y_e[i].item() % 10):
                            correct += 1
                accs_k.append(correct / len(X_e))

            acc_t1 = accs_k[0]
            k_accs_history.append(acc_t1)
            if t_idx > 0:
                prev = k_accs_history[t_idx - 1]
                print(f'[K_TemporalHierarchy] Task1 retention: '
                      f'Before={prev:.3f}, Now={acc_t1:.3f}')

            kappa_k2, d_avg_k2 = col.compute_mgd_metrics()
            results.append({
                "Task": t_idx + 1, "Model": "K_TemporalHierarchy",
                "Accuracy_Current": accs_k[-1], "Accuracy_Task1": acc_t1,
                "Cov_Spike_T1": 0.0, "Bias_Norm_T1": 0.0,
                "D_avg": d_avg_k2, "kappa": kappa_k2, "S_RT": 0.0,
                "Energy_Joules": 0.0
            })

        # ----------------------------------------------------------------
        # L_PredictiveHierarchy — K + predictive coding top-down
        # ----------------------------------------------------------------
        l_brain = PredictiveHierarchy(
            input_dim=self.input_dim, device=device, n_slow=3).to(device)
        l_accs_history = []

        for t_idx, (X_curr, y_curr) in enumerate(tasks_data):
            y_curr_safe = y_curr % 10

            area, novelty, eta_l = l_brain.register_task(t_idx, X_curr)
            col  = getattr(l_brain, f'cortex_{area}')
            gate = getattr(l_brain, f'gate_{area}')

            kappa_l, d_avg_l = col.compute_mgd_metrics()

            for ep in range(8):
                for i in range(len(X_curr)):
                    x_s    = X_curr[i].unsqueeze(0).to(device)
                    y_safe = int(y_curr[i].item() % 10)

                    l_brain.hippocampus.lif.reset_state()
                    col.lif.reset_state()
                    l_brain.slow_cortex.lif.reset_state()

                    sum_h = torch.zeros(1, col.n_neurons, device=device)
                    col.train()
                    l_brain.hippocampus.train()

                    for _ in range(3):
                        # forward ritorna (e_hip, h_cortex, h_slow)
                        _, h_cortex, _ = l_brain.forward(x_s, t_idx)
                        sum_h += h_cortex

                    ro = l_brain.readouts[t_idx]
                    ro.online_step(sum_h, y_safe, da_signal=eta_l)

                    dW   = col.stdp.compute_weight_update(kappa_l, d_avg_l, 2.0)
                    mask = gate.get_plastic_mask(t_idx).to(device)
                    dW   = dW * mask.unsqueeze(0) * eta_l
                    with torch.no_grad():
                        col.W.add_(dW)
                        col.W.data.clamp_(0.0, 5.0)

            replay_l = getattr(l_brain, f'replay_{area}')

            class _HipPreL:
                def __init__(self, hip):
                    self.hip = hip
                def reset_state(self):
                    if hasattr(self.hip.lif, 'reset_state'):
                        self.hip.lif.reset_state()
                    else:
                        self.hip.lif.v = None
                        self.hip.lif.a = None
                def __call__(self, x):
                    return self.hip(x).detach()

            replay_l.add_task(
                t_idx, X_curr, y_curr_safe, col,
                preprocess_fn=_HipPreL(l_brain.hippocampus))
            l_brain.consolidate(t_idx, device)

            accs_l = []
            for pt in range(t_idx + 1):
                X_e, y_e = tasks_data[pt]
                area_pt  = l_brain.task_routing[pt]
                col_pt   = getattr(l_brain, f'cortex_{area_pt}')
                ro_pt    = l_brain.readouts[pt]
                correct  = 0
                with torch.no_grad():
                    for i in range(len(X_e)):
                        x_s = X_e[i].unsqueeze(0).to(device)
                        l_brain.hippocampus.lif.reset_state()
                        col_pt.lif.reset_state()
                        sum_h = torch.zeros(
                            1, col_pt.n_neurons, device=device)
                        for _ in range(3):
                            _, h_c, _ = l_brain.forward(x_s, pt)
                            sum_h += h_c
                        if ro_pt.predict(sum_h) == int(y_e[i].item() % 10):
                            correct += 1
                accs_l.append(correct / len(X_e))

            acc_t1 = accs_l[0]
            l_accs_history.append(acc_t1)
            if t_idx > 0:
                prev = l_accs_history[t_idx - 1]
                print(f'[L_PredictiveHierarchy] Task1 retention: '
                      f'Before={prev:.3f}, Now={acc_t1:.3f}')

            kappa_l2, d_avg_l2 = col.compute_mgd_metrics()
            results.append({
                "Task": t_idx + 1, "Model": "L_PredictiveHierarchy",
                "Accuracy_Current": accs_l[-1], "Accuracy_Task1": acc_t1,
                "Cov_Spike_T1": 0.0, "Bias_Norm_T1": 0.0,
                "D_avg": d_avg_l2, "kappa": kappa_l2, "S_RT": 0.0,
                "Energy_Joules": 0.0
            })

        # ----------------------------------------------------------------
        # M_DendriticHierarchy — L + neuroni a due compartimenti (apicale)
        # ----------------------------------------------------------------
        m_brain = DendriticHierarchy(
            input_dim=self.input_dim, device=device, n_slow=3).to(device)
        m_accs_history = []

        for t_idx, (X_curr, y_curr) in enumerate(tasks_data):
            y_curr_safe = y_curr % 10

            area, novelty, eta_m = m_brain.register_task(t_idx, X_curr)
            col  = getattr(m_brain, f'cortex_{area}')
            gate = getattr(m_brain, f'gate_{area}')

            kappa_m, d_avg_m = col.compute_mgd_metrics()

            for ep in range(8):
                for i in range(len(X_curr)):
                    x_s    = X_curr[i].unsqueeze(0).to(device)
                    y_safe = int(y_curr[i].item() % 10)

                    m_brain.hippocampus.lif.reset_state()
                    col.lif.reset_state()
                    m_brain.slow_cortex.lif.reset_state()

                    sum_h = torch.zeros(1, col.n_neurons, device=device)
                    col.train()
                    m_brain.hippocampus.train()

                    for _ in range(3):
                        _, h_cortex, _ = m_brain.forward(x_s, t_idx)
                        sum_h += h_cortex

                    ro = m_brain.readouts[t_idx]
                    ro.online_step(sum_h, y_safe, da_signal=eta_m)

                    dW   = col.stdp.compute_weight_update(kappa_m, d_avg_m, 2.0)
                    mask = gate.get_plastic_mask(t_idx).to(device)
                    dW   = dW * mask.unsqueeze(0) * eta_m
                    with torch.no_grad():
                        col.W.add_(dW)
                        col.W.data.clamp_(0.0, 5.0)

            replay_m = getattr(m_brain, f'replay_{area}')

            class _HipPreM:
                def __init__(self, hip):
                    self.hip = hip
                def reset_state(self):
                    if hasattr(self.hip.lif, 'reset_state'):
                        self.hip.lif.reset_state()
                    else:
                        self.hip.lif.v = None
                        self.hip.lif.a = None
                def __call__(self, x):
                    return self.hip(x).detach()

            replay_m.add_task(
                t_idx, X_curr, y_curr_safe, col,
                preprocess_fn=_HipPreM(m_brain.hippocampus))
            m_brain.consolidate(t_idx, device)

            accs_m = []
            for pt in range(t_idx + 1):
                X_e, y_e = tasks_data[pt]
                area_pt  = m_brain.task_routing[pt]
                col_pt   = getattr(m_brain, f'cortex_{area_pt}')
                ro_pt    = m_brain.readouts[pt]
                correct  = 0
                with torch.no_grad():
                    for i in range(len(X_e)):
                        x_s = X_e[i].unsqueeze(0).to(device)
                        m_brain.hippocampus.lif.reset_state()
                        col_pt.lif.reset_state()
                        sum_h = torch.zeros(
                            1, col_pt.n_neurons, device=device)
                        for _ in range(3):
                            _, h_c, _ = m_brain.forward(x_s, pt)
                            sum_h += h_c
                        if ro_pt.predict(sum_h) == int(y_e[i].item() % 10):
                            correct += 1
                accs_m.append(correct / len(X_e))

            acc_t1 = accs_m[0]
            m_accs_history.append(acc_t1)
            if t_idx > 0:
                prev = m_accs_history[t_idx - 1]
                print(f'[M_DendriticHierarchy] Task1 retention: '
                      f'Before={prev:.3f}, Now={acc_t1:.3f}')

            kappa_m2, d_avg_m2 = col.compute_mgd_metrics()
            results.append({
                "Task": t_idx + 1, "Model": "M_DendriticHierarchy",
                "Accuracy_Current": accs_m[-1], "Accuracy_Task1": acc_t1,
                "Cov_Spike_T1": 0.0, "Bias_Norm_T1": 0.0,
                "D_avg": d_avg_m2, "kappa": kappa_m2, "S_RT": 0.0,
                "Energy_Joules": 0.0
            })

        self.results_df = pd.DataFrame(results)

        if skip_hierarchical:
            return self.results_df

        # ----------------------------------------------------------------
        # E_CorticalBrain — loop separato (multi-area, routing automatico)
        # ----------------------------------------------------------------
        brain = CorticalBrain(input_dim=self.input_dim)
        brain.to(device)
        brain_readouts = []      # [(readout, opt)] per ogni task
        brain_accs_history = []  # acc_Task1 dopo ogni task

        # tasks_data è già su device
        for t_idx, (X_curr, y_curr) in enumerate(tasks_data):
            y_curr_safe = y_curr % 10

            # Routing: registra il task nell'area corretta
            area = brain.register_task(t_idx, X_curr)
            print(f"[E_CorticalBrain] Task{t_idx+1}: routed -> {area}")

            column = brain.get_column(t_idx)
            gate   = brain.get_gate(t_idx)
            replay = brain.get_replay(t_idx)
            n_curr = column.n_neurons

            # Head fresco per questo task
            readout = nn.Linear(n_curr, 10).to(device)
            opt_r   = torch.optim.Adam(readout.parameters(), lr=0.01)
            brain_readouts.append((readout, opt_r))

            epochs_run = 5 if t_idx == 1 else 2
            active_spks_brain = 0

            if column.training:
                cached_kappa, cached_d_avg = column.compute_mgd_metrics()
            else:
                cached_kappa, cached_d_avg = 1.0, 1.0

            for epoch in range(epochs_run):
                for i in range(len(X_curr)):
                    x_s = X_curr[i].unsqueeze(0)
                    sum_s = torch.zeros(1, n_curr, device=device)
                    if hasattr(column.lif, "reset_state"): column.lif.reset_state()
                    else: column.lif.v = None; column.lif.a = None

                    column.train()
                    dW_accum = 0
                    for t in range(3):
                        spks = column(x_s)
                        sum_s += spks
                        active_spks_brain += int(spks.sum().item())
                        dW_accum += column.stdp.compute_weight_update(cached_kappa, cached_d_avg, D_target=2.0)

                    dW_total = gate.apply_mask_to_dW(dW_accum, t_idx)
                    with torch.no_grad():
                        column.W.add_(dW_total)
                        plastic_mask = gate.get_plastic_mask(t_idx).bool()
                        W_pl = column.W.data[:, plastic_mask]
                        column.W.data[:, plastic_mask] = apply_homeostatic_normalization(W_pl, target_sum=15.0)
                        torch.clamp_(column.W.data, 0.0, 5.0)

                    # Replay (prob 0.3)
                    if replay.n_tasks() > 0 and torch.rand(1).item() < 0.3:
                        for r_t_idx, (X_rep, y_rep) in replay.sample_replay(10):
                            for r_i in range(len(X_rep)):
                                xr_s = X_rep[r_i].unsqueeze(0).to(device)
                                if hasattr(column.lif, "reset_state"): column.lif.reset_state()
                                else: column.lif.v = None; column.lif.a = None
                                dW_rep = 0
                                for _ in range(3):
                                    column(xr_s)
                                    dW_rep += column.stdp.compute_weight_update(cached_kappa, cached_d_avg, D_target=2.0)
                                dW_rep = gate.apply_mask_to_dW(dW_rep, r_t_idx)
                                with torch.no_grad():
                                    column.W.add_(dW_rep * 0.3)
                                    torch.clamp_(column.W.data, 0.0, 5.0)

                    readout.train()
                    opt_r.zero_grad()
                    loss = nn.CrossEntropyLoss()(readout(sum_s), y_curr_safe[i].unsqueeze(0))
                    loss.backward()
                    opt_r.step()

            replay.add_task(t_idx, X_curr, y_curr_safe, column)

            # Valuta su TUTTI i task visti finora
            accs_brain = []
            for pt in range(t_idx + 1):
                X_e, y_e = tasks_data[pt]
                col_pt    = brain.get_column(pt)
                ro_pt, _  = brain_readouts[pt]
                a_pt, _, _ = self._evaluate(col_pt, ro_pt, X_e, y_e % 10)
                accs_brain.append(a_pt)

            acc_t1 = accs_brain[0]
            brain_accs_history.append(acc_t1)
            if t_idx > 0:
                prev = brain_accs_history[t_idx - 1]
                print(f"[E_CorticalBrain] Task1 retention: Before={prev:.3f}, Now={acc_t1:.3f}")

            kappa_b, d_avg_b = brain.area_synthetic.compute_mgd_metrics()
            results.append({
                "Task": t_idx + 1, "Model": "E_CorticalBrain",
                "Accuracy_Current": accs_brain[-1], "Accuracy_Task1": acc_t1,
                "Cov_Spike_T1": 0.0, "Bias_Norm_T1": 0.0,
                "D_avg": d_avg_b, "kappa": kappa_b, "S_RT": 0.0,
                "Energy_Joules": 0.0
            })

        # ----------------------------------------------------------------
        # F_HierarchicalBrain — loop separato 
        # ----------------------------------------------------------------
        f_brain = HierarchicalBrain(input_dim=self.input_dim)
        f_brain.to(device)
        f_readouts = []      # [(readout, opt)] per ogni task
        f_accs_history = []  # acc_Task1 dopo ogni task

        for t_idx, (X_curr, y_curr) in enumerate(tasks_data):
            y_curr_safe = y_curr % 10

            area = f_brain.register_task(t_idx, X_curr)
            print(f"[F_HierarchicalBrain] Task{t_idx+1}: routed -> {area}")

            L1, gate_L1, replay_L1, L2, gate_L2, replay_L2, L3, c_area, c_readout = f_brain.get_routing_components(t_idx)

            readout = nn.Linear(c_readout.n_neurons, 10).to(device)
            opt_r   = torch.optim.Adam(readout.parameters(), lr=0.01)
            f_readouts.append((readout, opt_r))

            run_epochs_F = 8
            criterion = nn.CrossEntropyLoss()

            if L1.training: kap_L1, d_L1 = L1.compute_mgd_metrics()
            else: kap_L1, d_L1 = 1.0, 1.0
            if L2.training: kap_L2, d_L2 = L2.compute_mgd_metrics()
            else: kap_L2, d_L2 = 1.0, 1.0
            if L3.training: kap_L3, d_L3 = L3.compute_mgd_metrics()
            else: kap_L3, d_L3 = 1.0, 1.0

            for epoch in range(run_epochs_F):
                for i in range(len(X_curr)):
                    x_s = X_curr[i].unsqueeze(0)
                    if hasattr(L1.lif, "reset_state"):
                        L1.lif.reset_state(); L2.lif.reset_state(); L3.lif.reset_state()
                    else:
                        L1.lif.v=None; L1.lif.a=None; L2.lif.v=None; L2.lif.a=None; L3.lif.v=None; L3.lif.a=None
                    
                    sum_h3 = torch.zeros(1, L3.n_neurons, device=device)
                    sum_h1 = torch.zeros(1, L1.n_neurons, device=device) # For synthetic area readout
                    dW_acc_L1, dW_acc_L2, dW_acc_L3 = 0, 0, 0

                    L1.train(); L2.train(); L3.train()
                    
                    for t in range(3):
                        h1 = L1(x_s)
                        sum_h1 += h1
                        dW_acc_L1 += L1.stdp.compute_weight_update(kap_L1, d_L1, D_target=2.0)
                        
                        h2 = L2(h1.detach())
                        dW_acc_L2 += L2.stdp.compute_weight_update(kap_L2, d_L2, D_target=2.0)
                        
                        h2_in = F.pad(h2.detach(), (0, 500)) if area == 'synthetic' else h2.detach()
                        h3 = L3(h2_in)
                        sum_h3 += h3
                        dW_acc_L3 += L3.stdp.compute_weight_update(kap_L3, d_L3, D_target=2.0)

                    dW_L1 = gate_L1.apply_mask_to_dW(dW_acc_L1, t_idx)
                    with torch.no_grad():
                        L1.W.add_(dW_L1)
                        pl_mask_L1 = gate_L1.get_plastic_mask(t_idx).bool()
                        L1.W.data[:, pl_mask_L1] = apply_homeostatic_normalization(L1.W.data[:, pl_mask_L1], 15.0)
                        torch.clamp_(L1.W.data, 0.0, 5.0)
                        
                    dW_L2 = gate_L2.apply_mask_to_dW(dW_acc_L2, t_idx)
                    with torch.no_grad():
                        L2.W.add_(dW_L2)
                        pl_mask_L2 = gate_L2.get_plastic_mask(t_idx).bool()
                        L2.W.data[:, pl_mask_L2] = apply_homeostatic_normalization(L2.W.data[:, pl_mask_L2], 15.0)
                        torch.clamp_(L2.W.data, 0.0, 5.0)
                        
                    with torch.no_grad():
                        L3.W.add_(dW_acc_L3)
                        L3.W.data = apply_homeostatic_normalization(L3.W.data, 15.0)
                        torch.clamp_(L3.W.data, 0.0, 5.0)

                    if torch.rand(1).item() < 0.3:
                        for current_replay in [f_brain.replay_L1_syn, f_brain.replay_L1_vis]:
                            if current_replay.n_tasks() > 0:
                                for r_t_idx, (X_rep, y_rep) in current_replay.sample_replay(10):
                                    c_L1, c_gL1, _, c_L2, c_gL2, _, c_L3, r_area, _ = f_brain.get_routing_components(r_t_idx)
                                    for r_i in range(len(X_rep)):
                                        xr_s = X_rep[r_i].unsqueeze(0).to(device)
                                        if hasattr(c_L1.lif, "reset_state"):
                                            c_L1.lif.reset_state(); c_L2.lif.reset_state(); c_L3.lif.reset_state()
                                        else:
                                            c_L1.lif.v=None; c_L1.lif.a=None; c_L2.lif.v=None; c_L2.lif.a=None; c_L3.lif.v=None; c_L3.lif.a=None
                                        
                                        drW_L1, drW_L2, drW_L3 = 0, 0, 0
                                        for _ in range(3):
                                            h1_r = c_L1(xr_s)
                                            drW_L1 += c_L1.stdp.compute_weight_update(kap_L1, d_L1, D_target=2.0)
                                            h2_r = c_L2(h1_r.detach())
                                            drW_L2 += c_L2.stdp.compute_weight_update(kap_L2, d_L2, D_target=2.0)
                                            h2_in_r = F.pad(h2_r.detach(), (0, 500)) if r_area == 'synthetic' else h2_r.detach()
                                            h3_r = c_L3(h2_in_r)
                                            drW_L3 += c_L3.stdp.compute_weight_update(kap_L3, d_L3, D_target=2.0)
                                            
                                        with torch.no_grad():
                                            c_L1.W.add_(c_gL1.apply_mask_to_dW(drW_L1, r_t_idx) * 0.3)
                                            c_L2.W.add_(c_gL2.apply_mask_to_dW(drW_L2, r_t_idx) * 0.3)
                                            c_L3.W.add_(drW_L3 * 0.3)
                                            torch.clamp_(c_L1.W.data, 0.0, 5.0)
                                            torch.clamp_(c_L2.W.data, 0.0, 5.0)
                                            torch.clamp_(c_L3.W.data, 0.0, 5.0)

                    readout.train()
                    opt_r.zero_grad()
                    sum_h_readout = sum_h1 if c_area == 'synthetic' else sum_h3
                    loss = criterion(readout(sum_h_readout), y_curr_safe[i].unsqueeze(0))
                    loss.backward()
                    opt_r.step()

            replay_L1.add_task(t_idx, X_curr, y_curr_safe, L1)

            # --- Valuta su TUTTI i task visti finora ---
            accs_f = []
            for pt in range(t_idx + 1):
                X_e, y_e = tasks_data[pt]
                ro_pt, _ = f_readouts[pt]
                a_pt, _, _ = self._evaluate_hierarchical(f_brain, ro_pt, X_e, y_e % 10, pt)
                accs_f.append(a_pt)

            acc_t1 = accs_f[0]
            f_accs_history.append(acc_t1)
            if t_idx > 0:
                prev = f_accs_history[t_idx - 1]
                print(f"[F_HierarchicalBrain] Task1 retention: Before={prev:.3f}, Now={acc_t1:.3f}")

            kappa_f, d_avg_f = kap_L1, d_L1 # log properties del L1
            results.append({
                "Task": t_idx + 1, "Model": "F_HierarchicalBrain",
                "Accuracy_Current": accs_f[-1], "Accuracy_Task1": acc_t1,
                "Cov_Spike_T1": 0.0, "Bias_Norm_T1": 0.0,
                "D_avg": d_avg_f, "kappa": kappa_f, "S_RT": 0.0,
                "Energy_Joules": 0.0
            })

        # ----------------------------------------------------------------
        # G_BioMGDBrain — loop separato
        # ----------------------------------------------------------------
        g_brain = BioMGDBrain(input_dim=self.input_dim).to(device)
        g_readouts = []
        g_accs_history = []

        for t_idx, (X_curr, y_curr) in enumerate(tasks_data):
            y_curr_safe = y_curr % 10

            x_sample = X_curr[0].unsqueeze(0).to(device)
            if hasattr(g_brain.hippocampus.lif, "reset_state"):
                g_brain.hippocampus.lif.reset_state()
            else:
                g_brain.hippocampus.lif.v = None; g_brain.hippocampus.lif.a = None
            _, novelty, eta_factor = g_brain.compute_novelty(x_sample)
            print(f"[G_BioMGDBrain] Task{t_idx+1} novelty={novelty:.4f} eta={eta_factor:.2f}")

            area = g_brain.route_by_srt(t_idx, None)
            print(f"[G_BioMGDBrain] Task{t_idx+1}: routed -> {area}")

            hip, col, gate, replay, L2, gate_L2, L3, c_area = g_brain.get_routing_components(t_idx)

            readout = nn.Linear(col.n_neurons, 10).to(device)
            opt_r = torch.optim.Adam(readout.parameters(), lr=0.01)
            g_readouts.append((readout, opt_r))

            kap_hip, d_hip = hip.compute_mgd_metrics()
            kap_col, d_col = col.compute_mgd_metrics()
            kap_L2,  d_L2  = L2.compute_mgd_metrics()
            kap_L3,  d_L3  = L3.compute_mgd_metrics()

            for ep in range(8):
                for i in range(len(X_curr)):
                    x_s = X_curr[i].unsqueeze(0).to(device)
                    y_safe = y_curr[i] % 10

                    if hasattr(hip.lif, "reset_state"):
                        hip.lif.reset_state(); col.lif.reset_state()
                        L2.lif.reset_state(); L3.lif.reset_state()
                    else:
                        hip.lif.v = None; hip.lif.a = None; col.lif.v = None; col.lif.a = None
                        L2.lif.v = None; L2.lif.a = None; L3.lif.v = None; L3.lif.a = None
                        
                    sum_h1 = torch.zeros(1, col.n_neurons, device=device)
                    dW_hip, dW_col, dW_L2, dW_L3 = 0, 0, 0, 0
                    
                    hip.train(); col.train(); L2.train(); L3.train()
                    
                    for _ in range(3):
                        h_hip, h1, h2, h3 = g_brain(x_s, t_idx)
                        sum_h1 += h1
                        
                        dW_hip += hip.stdp.compute_weight_update(kap_hip, d_hip, 2.0)
                        dW_col += col.stdp.compute_weight_update(kap_col, d_col, 2.0)
                        dW_L2  += L2.stdp.compute_weight_update(kap_L2,  d_L2,  2.0)
                        dW_L3  += L3.stdp.compute_weight_update(kap_L3,  d_L3,  2.0)
                        
                    dW_hip *= eta_factor
                    dW_col *= eta_factor
                    
                    dW_col = gate.apply_mask_to_dW(dW_col, t_idx)
                    dW_L2  = gate_L2.apply_mask_to_dW(dW_L2, t_idx)
                    
                    with torch.no_grad():
                        hip.W.add_(dW_hip)
                        hip.W.data = apply_homeostatic_normalization(hip.W.data, 15.0)
                        
                        col.W.add_(dW_col)
                        pl_mask_col = gate.get_plastic_mask(t_idx).bool()
                        col.W.data[:, pl_mask_col] = apply_homeostatic_normalization(col.W.data[:, pl_mask_col], 15.0)
                        
                        L2.W.add_(dW_L2)
                        pl_mask_L2 = gate_L2.get_plastic_mask(t_idx).bool()
                        L2.W.data[:, pl_mask_L2] = apply_homeostatic_normalization(L2.W.data[:, pl_mask_L2], 15.0)
                        
                        L3.W.add_(dW_L3)
                        L3.W.data = apply_homeostatic_normalization(L3.W.data, 15.0)
                        
                        torch.clamp_(hip.W.data, 0.0, 5.0)
                        torch.clamp_(col.W.data, 0.0, 5.0)
                        torch.clamp_(L2.W.data,  0.0, 5.0)
                        torch.clamp_(L3.W.data,  0.0, 5.0)
                        
                    readout.train()
                    opt_r.zero_grad()
                    loss = nn.CrossEntropyLoss()(readout(sum_h1), y_safe.unsqueeze(0))
                    loss.backward()
                    opt_r.step()

            class HipPreprocess:
                def __init__(self, hip):
                    self.hip = hip
                def reset_state(self):
                    if hasattr(self.hip.lif, "reset_state"):
                        self.hip.lif.reset_state()
                    else:
                        self.hip.lif.v = None; self.hip.lif.a = None
                def __call__(self, x):
                    return self.hip(x).detach()

            replay.add_task(t_idx, X_curr, y_curr_safe, col, preprocess_fn=HipPreprocess(hip))
            # --- Sleep Consolidation ---
            sorted_tasks = g_brain.sleep_consolidation(device, n_steps=100)
            if sorted_tasks:
                steps_per_task = max(1, 100 // max(1, len(sorted_tasks)))
                for s_rt, pt_id, buf in sorted_tasks:
                    ro_pt, opt_pt = g_readouts[pt_id]
                    hip_s, col_s, gate_s, _, L2_s, gate_L2_s, L3_s, _ = g_brain.get_routing_components(pt_id)
                    
                    kap_col_s, d_col_s = col_s.compute_mgd_metrics()
                    kap_L2_s, d_L2_s = L2_s.compute_mgd_metrics()
                    kap_L3_s, d_L3_s = L3_s.compute_mgd_metrics()
                    sleep_eta = 0.1 / (1.0 + abs(kap_col_s))
                    
                    for step in range(steps_per_task):
                        for _, (X_rep, y_rep) in buf.sample_replay(5):
                            for i in range(len(X_rep)):
                                x_r = X_rep[i].unsqueeze(0).to(device)
                                y_r_safe = y_rep[i] % 10
                                
                                if hasattr(hip_s.lif, "reset_state"):
                                    hip_s.lif.reset_state(); col_s.lif.reset_state()
                                    L2_s.lif.reset_state(); L3_s.lif.reset_state()
                                else:
                                    hip_s.lif.v = None; hip_s.lif.a = None; col_s.lif.v = None; col_s.lif.a = None
                                    L2_s.lif.v = None; L2_s.lif.a = None; L3_s.lif.v = None; L3_s.lif.a = None
                                    
                                sum_h1_s = torch.zeros(1, col_s.n_neurons, device=device)
                                dW_col_s = 0; dW_L2_s = 0; dW_L3_s = 0
                                
                                hip_s.eval()
                                col_s.train(); L2_s.train(); L3_s.train()
                                
                                for _ in range(3):
                                    h_hip_s, h1_s, h2_s, h3_s = g_brain(x_r, pt_id)
                                    sum_h1_s += h1_s
                                    
                                    dW_col_s += col_s.stdp.compute_weight_update(kap_col_s, d_col_s, 2.0)
                                    dW_L2_s  += L2_s.stdp.compute_weight_update(kap_L2_s, d_L2_s, 2.0)
                                    dW_L3_s  += L3_s.stdp.compute_weight_update(kap_L3_s, d_L3_s, 2.0)
                                    
                                dW_col_s = gate_s.apply_mask_to_dW(dW_col_s, pt_id)
                                dW_L2_s = gate_L2_s.apply_mask_to_dW(dW_L2_s, pt_id)
                                
                                with torch.no_grad():
                                    col_s.W.add_(dW_col_s * sleep_eta)
                                    pl_mask_c = gate_s.get_plastic_mask(pt_id).bool()
                                    col_s.W.data[:, pl_mask_c] = apply_homeostatic_normalization(col_s.W.data[:, pl_mask_c], 15.0)
                                    
                                    L2_s.W.add_(dW_L2_s * sleep_eta)
                                    pl_mask_l2 = gate_L2_s.get_plastic_mask(pt_id).bool()
                                    L2_s.W.data[:, pl_mask_l2] = apply_homeostatic_normalization(L2_s.W.data[:, pl_mask_l2], 15.0)
                                    
                                    L3_s.W.add_(dW_L3_s * sleep_eta)
                                    L3_s.W.data = apply_homeostatic_normalization(L3_s.W.data, 15.0)
                                    
                                    torch.clamp_(col_s.W.data, 0.0, 5.0)
                                    torch.clamp_(L2_s.W.data, 0.0, 5.0)
                                    torch.clamp_(L3_s.W.data, 0.0, 5.0)
                                    
                                ro_pt.train()
                                opt_pt.zero_grad()
                                loss_s = nn.CrossEntropyLoss()(ro_pt(sum_h1_s.detach()), y_r_safe.unsqueeze(0))
                                loss_s.backward()
                                for param_group in opt_pt.param_groups:
                                    param_group['lr'] = 0.002
                                opt_pt.step()

            accs_g = []
            for pt in range(t_idx + 1):
                X_e, y_e = tasks_data[pt]
                ro_pt, _ = g_readouts[pt]
                a_pt, _, _ = self._evaluate_biomgd(g_brain, ro_pt, X_e, y_e % 10, pt)
                accs_g.append(a_pt)

            acc_t1 = accs_g[0]
            g_accs_history.append(acc_t1)
            if t_idx > 0:
                prev = g_accs_history[t_idx - 1]
                print(f"[G_BioMGDBrain] Task1 retention: Before={prev:.3f}, Now={acc_t1:.3f}")

            kappa_g, d_avg_g = kap_col, d_col
            results.append({
                "Task": t_idx + 1, "Model": "G_BioMGDBrain",
                "Accuracy_Current": accs_g[-1], "Accuracy_Task1": acc_t1,
                "Cov_Spike_T1": 0.0, "Bias_Norm_T1": 0.0,
                "D_avg": d_avg_g, "kappa": kappa_g, "S_RT": 0.0,
                "Energy_Joules": 0.0
            })

        self.results_df = pd.DataFrame(results)
        return self.results_df

    def run_task_sequence_extended(self, n_extra_tasks=15):
        """
        Estende run_task_sequence con task sintetici aggiuntivi.
        Task 1-5: esistenti (XOR, Banded, MNIST04, MNIST59, N-MNIST)
        Task 6-20: varianti sintetiche con seed diversi
        """
        print("Pre-loading MNIST & Geometric Tasks...")
        t1 = self._create_xor_task(60)
        t2 = self._create_banded_task(60)
        t3, t4 = self._get_mnist_subsets(60)
        tasks_data = [t1, t2, t3, t4]
        
        # Task 5 opzionale: N-MNIST
        try:
            from cortical_mgd.data.nmnist_loader import load_nmnist_flat
            print("Caricamento N-MNIST (Task 5)...")
            X5, y5 = load_nmnist_flat(n_samples=200, split='train')
            if X5 is not None:
                tasks_data.append((X5, y5))
                print("[Benchmark] Task 5: N-MNIST caricato con successo.")
        except ImportError:
            print("[Benchmark] Tonic non installato. Skipping N-MNIST (Task 5).")

        print(f"Generating {n_extra_tasks} supplementary synthetic tasks...")
        for i in range(n_extra_tasks):
            seed_val = 6 + i
            torch.manual_seed(seed_val)
            import numpy as np
            np.random.seed(seed_val)
            if i % 2 == 0:
                t_extra = self._create_xor_task(n_samples=60)
            else:
                t_extra = self._create_banded_task(n_samples=60)
            tasks_data.append(t_extra)
            
        return self.run_task_sequence(tasks_data=tasks_data)

    def _preload_tasks(self):
        """Carica la sequenza standard di task senza device placement."""
        tasks = []
        tasks.append(self._create_xor_task(60))
        tasks.append(self._create_banded_task(60))
        (X3, y3), (X4, y4) = self._get_mnist_subsets(60)
        tasks.append((X3, y3))
        tasks.append((X4, y4))
        try:
            from cortical_mgd.data.nmnist_loader import load_nmnist_flat
            X5, y5 = load_nmnist_flat(n_samples=60, split='train')
            if X5 is not None:
                tasks.append((X5, y5))
        except (ImportError, Exception):
            pass
        return tasks

    def generate_report(self) -> pd.DataFrame:
        return self.results_df

    def plot_metrics(self, dest_path: str = "benchmark_results.png"):
        df = self.results_df
        fig, axes = plt.subplots(2, 3, figsize=(16, 10))
        axes = axes.flatten()
        
        for m in df["Model"].unique():
            sub = df[df["Model"] == m]
            axes[0].plot(sub["Task"], sub["Accuracy_Current"], label=m, marker='o')
            axes[1].plot(sub["Task"], sub["Accuracy_Task1"], label=m, marker='x', linestyle='--')
            axes[2].plot(sub["Task"], sub["D_avg"], label=m, marker='s')
            axes[3].plot(sub["Task"], sub["kappa"], label=m, marker='^')
            axes[4].plot(sub["Task"], sub["S_RT"], label=m, marker='d')
            axes[5].plot(sub["Task"], sub["Energy_Joules"], label=m, marker='*')
            
        titles = ["Current Task Accuracy", "Task 1 Retained Acc (Forgetting)", 
                  "D_avg Evolution", "Kappa ORC Evolution", "S_RT Evolution", "Energy (Joules)"]
        for i, ax in enumerate(axes):
            ax.set_title(titles[i]); ax.set_xlabel("Task Sequence")
            ax.legend(); ax.grid(True)
            
        plt.tight_layout()
        plt.savefig(dest_path)
        plt.close()
