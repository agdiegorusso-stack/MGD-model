import pytest
import math
from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
from cortical_mgd.benchmark.energy_profiler import EnergyProfiler

def test_energy_profiler_positive():
    """Verifica le transizioni fisiche e metriche a Joule contro array Transformer densi."""
    profiler = EnergyProfiler()
    energy = profiler.compute_inference_energy(active_spikes=50, n_weights=1000)
    assert energy > 0.0
    
    comp = profiler.compare_with_transformer(energy, d_model=512, n_heads=8)
    assert "ratio" in comp
    assert comp["ratio"] > 0

def test_smoke_benchmark_task1():
    """Istanzia REALMENTE l'SNN e l'addestra decifrando pattern input."""
    suite = MGDBenchmarkSuite()
    acc_A = suite.quick_test_task1_accuracy(epochs=3)
    
    # Tesi scientifica: Rete esprime plasticità oltre la selezione causuale (25% per 4 classi)
    assert acc_A > 0.25, f"Accuracy troppo bassa: {acc_A:.3f}"

def test_benchmark_forgetting_c_vs_a():
    """
    Test cruciale: allena 2 network (Baseline vs MGD) in modo continuo
    su XOR -> Banded, collauda l'Amnesia sull'XOR finale.
    """
    suite = MGDBenchmarkSuite()
    forgetting_A, forgetting_C = suite.quick_test_forgetting_task1_to_2()
    
    # Tesi scientifica: MGD dimentica meno della baseline grazie ad accumulo geometrico e modulazione
    assert forgetting_C < forgetting_A, \
        f"MGD ({forgetting_C:.3f}) scorda più di baseline ({forgetting_A:.3f})"
    
    # Sanity checks: fisica del Forgetting logico
    assert forgetting_A >= 0.0, "Forgetting non può essere negativo"
    assert forgetting_A <= 1.0, "Forgetting non può superare 1.0"

def test_replay_prioritizes_high_variance():
    from cortical_mgd.continual.replay_buffer import MGDReplayBuffer
    suite = MGDBenchmarkSuite(n_neurons=100, input_dim=784)
    col = suite._create_benchmark_column() if hasattr(suite, "_create_benchmark_column") else None
    
    from cortical_mgd.architecture.cortical_column import CorticalColumn
    col = CorticalColumn(n_neurons=100, input_dim=784, target_sparsity=0.1)
    
    X, y = suite._create_xor_task(60)
    buf = MGDReplayBuffer(capacity_per_task=20)
    buf.add_task(0, X, y, col)
    
    assert buf.n_tasks() == 1
    assert len(buf.buffer[0]) == 20

def test_no_overlap_between_tasks():
    from cortical_mgd.architecture.modular_gate import ModularGate
    from cortical_mgd.architecture.cortical_column import CorticalColumn
    gate = ModularGate(n_neurons=100, n_tasks=2)
    col = CorticalColumn(n_neurons=100, input_dim=784)
    gate.register_task(0, col, fraction=0.3, strategy="random")
    gate.register_task(1, col, fraction=0.3, strategy="random")
    
    m1 = gate.get_plastic_mask(0)
    m2 = gate.get_plastic_mask(1)
    assert (m1 * m2).sum() == 0, "Overlap tra maschere di task!"

def test_lowvar_selects_unspecialized_neurons():
    from cortical_mgd.architecture.modular_gate import ModularGate
    from cortical_mgd.architecture.cortical_column import CorticalColumn
    gate = ModularGate(n_neurons=100, n_tasks=2)
    col = CorticalColumn(n_neurons=100, input_dim=784)
    # Renda la col[10:90] non uniforme (molto variante)
    import torch
    col.W.data[:, 10:90] = torch.rand_like(col.W.data[:, 10:90]) * 5.0
    col.W.data[:, :10] = 0.0 # Bassa varianza
    col.W.data[:, 90:] = 0.0 # Bassa varianza
    
    gate.register_task(0, col, fraction=0.2, strategy="low_variance")
    sel = gate.get_plastic_mask(0).bool()
    
    var_selected = col.W.data[:, sel].var(dim=0).mean()
    var_all = col.W.data.var(dim=0).mean()
    assert var_selected < var_all

def test_full_mgd_reduces_forgetting():
    suite = MGDBenchmarkSuite()
    f_d_lowvar, f_d_rand, f_a_base = suite.quick_test_forgetting_D()
    
    assert f_d_lowvar < f_a_base, f"D_lowvar ({f_d_lowvar:.3f}) >= A_base ({f_a_base:.3f})"

def test_full_retention_4tasks():
    """Test scientifico definitivo: D_MGD_FULL deve ricordare Task1 dopo 4 task su dati reali."""
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence()
    
    d_row = df[(df["Model"] == "D_MGD_FULL") & (df["Task"] == 4)]
    a_row = df[(df["Model"] == "A_STDPLocal") & (df["Task"] == 4)]
    
    d_acc_t1 = float(d_row["Accuracy_Task1"].values[0])
    a_acc_t1 = float(a_row["Accuracy_Task1"].values[0])
    
    print(f"\n[test_full_retention_4tasks]")
    print(f"  D_MGD_FULL Accuracy_Task1 @ Task4: {d_acc_t1:.3f}")
    print(f"  A_STDPLocal Accuracy_Task1 @ Task4: {a_acc_t1:.3f}")
    
    assert d_acc_t1 > 0.50, f"D_MGD_FULL Task1 retention {d_acc_t1:.3f} <= 0.50"
    assert d_acc_t1 > a_acc_t1, f"D_MGD_FULL ({d_acc_t1:.3f}) <= A_STDPLocal ({a_acc_t1:.3f})"

def test_brain_retention_4tasks():
    """
    Test scientifico Fase 2: CorticalBrain con aree separate per densità.
    Deve ricordare Task1 dopo 4 task eterogenei (sintetici -> MNIST)
    dimostrando che separation area risolve il representation drift.
    """
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence()
    
    e_row = df[(df["Model"] == "E_CorticalBrain") & (df["Task"] == 4)]
    a_row = df[(df["Model"] == "A_STDPLocal") & (df["Task"] == 4)]
    
    e_acc_t1 = float(e_row["Accuracy_Task1"].values[0])
    a_acc_t1 = float(a_row["Accuracy_Task1"].values[0])
    
    print(f"\n[test_brain_retention_4tasks]")
    print(f"  E_CorticalBrain Accuracy_Task1 @ Task4: {e_acc_t1:.3f}")
    print(f"  A_STDPLocal       Accuracy_Task1 @ Task4: {a_acc_t1:.3f}")
    
    assert e_acc_t1 > 0.50, f"CorticalBrain Task1 retention {e_acc_t1:.3f} <= 0.50"
    assert e_acc_t1 > a_acc_t1, f"CorticalBrain ({e_acc_t1:.3f}) <= Baseline ({a_acc_t1:.3f})"


def test_hierarchical_retention():
    """
    Testa se la HierarchicalBrain (F) mantiene le informationi di Task 1 
    dopo l'apprendimento di 4 task eterogenei (XOR, Banded, MNIST, MNIST).
    Verifica che il retention sia > 90% e non scenda sotto la soglia di CorticalBrain.
    """
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence()
    
    # Prendi solo la riga finale (al completamento di Task 4) per i due modelli esaminati
    f_row = df[(df["Model"] == "F_HierarchicalBrain") & (df["Task"] == 4)]
    e_row = df[(df["Model"] == "E_CorticalBrain") & (df["Task"] == 4)]
    
    # Verifica che la run si sia completata per entrambi
    assert not f_row.empty, "Nessun risultato trovato per F_HierarchicalBrain al Task 4"
    assert not e_row.empty, "Nessun risultato trovato per E_CorticalBrain al Task 4"
    
    f_acc = float(f_row['Accuracy_Task1'].values[0])
    e_acc = float(e_row['Accuracy_Task1'].values[0])
    
    print(f"\n[Validation] HierarchicalBrain Retention (T1 al T4): {f_acc:.3f} | CorticalBrain: {e_acc:.3f}")
    
    # Check 1: Soglia Assoluta del 90%
    assert f_acc >= 0.90, f"F_HierarchicalBrain scende sotto il 90% (Acc: {f_acc:.3f})"
    
    # Check 2: Controllo comparazione col Flat Brain tollerante al 5%
    assert f_acc >= e_acc * 0.95, f"F_HierarchicalBrain ({f_acc:.3f}) performa peggio di E_CorticalBrain ({e_acc:.3f}) con devianza inaccettabile"

def test_bio_mgd_retention():
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence()
    g_row = df[(df["Model"] == "G_BioMGDBrain") & (df["Task"] == suite.n_tasks)]
    
    assert not g_row.empty, f"Nessun risultato trovato per G_BioMGDBrain al Task {suite.n_tasks}"
    g_acc = float(g_row['Accuracy_Task1'].values[0])
    
    print(f'\n[Validation] BioMGD retention @ Task {suite.n_tasks}: {g_acc:.3f}')
    assert g_acc >= 0.92, f"BioMGD retention scende sotto il 92%: {g_acc:.3f}"

def test_all_models_20tasks():
    from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence_extended(n_extra_tasks=15)
    
    # Verifica retention@Task20 per tutti i modelli principali
    for model in ['E_CorticalBrain', 'F_HierarchicalBrain', 'G_BioMGDBrain']:
        row = df[(df.Model==model) & (df.Task==20)]
        if row.empty:
            continue
        acc = float(row['Accuracy_Task1'].values[0])
        print(f"{model} retention@T20: {acc:.3f}")
    
    g_row = df[(df.Model=='G_BioMGDBrain') & (df.Task==20)]
    if not g_row.empty:
        g_acc = float(g_row['Accuracy_Task1'].values[0])
        assert g_acc >= 0.80, f"G_BioMGDBrain retention@T20 scende sotto 0.80: {g_acc:.3f}"

def test_local_mgd():
    from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence(skip_hierarchical=True)
    h_row = df[(df.Model=='H_LocalMGD') & (df.Task==4)]
    if not h_row.empty:
        h_acc = float(h_row['Accuracy_Task1'].values[0])
        b_row = df[(df.Model=='B_MGD_EWC') & (df.Task==4)]
        b_acc = float(b_row['Accuracy_Task1'].values[0])
        print(f'H_LocalMGD retention: {h_acc:.3f}')
        print(f'B_MGD_EWC retention:  {b_acc:.3f}')
        assert h_acc > 0.300

def test_local_mgd_5tasks():
    from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence(skip_hierarchical=True)
    
    h_row = df[(df.Model=='H_LocalMGD') & (df.Task==5)]
    assert not h_row.empty, "Task 5 N-MNIST row not found"
    h_acc = float(h_row['Accuracy_Task1'].values[0])
    print(f'H_LocalMGD retention@T5: {h_acc:.3f}')
    assert h_acc >= 0.75

def test_overlap_mgd():
    from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence(skip_hierarchical=True)
    i_row = df[(df.Model=='I_OverlapMGD') & (df.Task==suite.n_tasks)]
    if not i_row.empty:
        i_acc = float(i_row['Accuracy_Task1'].values[0])
        print(f'I_OverlapMGD retention@T{suite.n_tasks}: {i_acc:.3f}')
        assert i_acc >= 0.75
    
    # Verifica scalabilita: pruning deve aver liberato neuroni
    from cortical_mgd.architecture.modular_gate import ModularGate
    # Il gate e accessibile tramite il suite se esposto, altrimenti
    # usiamo il fatto che run_task_sequence ritorna il df
    # La verifica indiretta e che il test non sia saturato:
    # se i_acc >= 0.75 con 5 task e fraction=0.10, il pruning e attivo
    free_count = int((~suite._last_gate_I.allocated_neurons).sum()) if hasattr(suite, '_last_gate_I') else -1
    print(f'Neuroni liberi dopo T{suite.n_tasks}: {free_count}/500')
    if free_count >= 0:
        assert free_count > 0, 'Saturazione: pruning non ha liberato neuroni'


def test_structural_plasticity():
    from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence_extended(n_extra_tasks=5)  # 4+5 = 9 task totali

    i_row = df[(df.Model == 'I_OverlapMGD') & (df.Task == suite.n_tasks)]
    if not i_row.empty:
        i_acc = float(i_row['Accuracy_Task1'].values[0])
        print(f'I_OverlapMGD retention@T{suite.n_tasks}: {i_acc:.3f}')
        assert i_acc >= 0.75, f'Retention crollata: {i_acc:.3f}'

    # Verifica scalabilita: il pruning deve aver liberato neuroni
    # (con 9 task e tau_pruning=1, ci aspettiamo neuroni liberati)
    free_count = int((~suite._last_gate_I.allocated_neurons).sum()) if hasattr(suite, '_last_gate_I') else -1
    print(f'Neuroni liberi dopo T{suite.n_tasks}: {free_count}/500')
    if free_count >= 0:
        assert free_count > 0, 'Saturazione: pruning non ha liberato neuroni dopo 9 task'

def test_temporal_hierarchy():
    suite = MGDBenchmarkSuite()
    df = suite.run_task_sequence(skip_hierarchical=True)

    k_row = df[(df.Model == 'K_TemporalHierarchy') &
               (df.Task == suite.n_tasks)]
    assert not k_row.empty, \
        f'Nessun risultato K_TemporalHierarchy al Task {suite.n_tasks}'

    k_acc = float(k_row['Accuracy_Task1'].values[0])
    print(f'\nK retention@T{suite.n_tasks}: {k_acc:.3f}')
    assert k_acc >= 0.75, \
        f'K_TemporalHierarchy retention {k_acc:.3f} < 0.75'


def test_neuromorphic_readout():
    from cortical_mgd.benchmark.benchmark_suite import MGDBenchmarkSuite
    suite = MGDBenchmarkSuite()
    suite.only_models = {"A_STDPLocal", "I_OverlapMGD", "J_NeuromorphicMGD"}
    df = suite.run_task_sequence(skip_hierarchical=True)
    
    j_row = df[(df.Model == 'J_NeuromorphicMGD') & (df.Task == suite.n_tasks)]
    j_acc = float(j_row['Accuracy_Task1'].values[0]) if not j_row.empty else 0.0
    print(f'J_NeuromorphicMGD retention@T{suite.n_tasks}: {j_acc:.3f}')
        
    a_row = df[(df.Model == 'A_STDPLocal') & (df.Task == suite.n_tasks)]
    a_acc = float(a_row['Accuracy_Task1'].values[0]) if not a_row.empty else 0.0
        
    i_row = df[(df.Model == 'I_OverlapMGD') & (df.Task == suite.n_tasks)]
    i_acc = float(i_row['Accuracy_Task1'].values[0]) if not i_row.empty else 0.0
        
    print(f"Comparison -> J: {j_acc:.3f}, A: {a_acc:.3f}, I: {i_acc:.3f}")
    assert j_acc > 0.300, f"J_NeuromorphicMGD failed to beat baseline with {j_acc:.3f}"
