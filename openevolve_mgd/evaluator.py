import sys
import os
import importlib.util
import subprocess
import json

def evaluate(program_path: str) -> dict:
    """
    OpenEvolve Evaluator:
    1. Legge param evoluti
    2. Li salva in evolution_params.json
    3. Lancia run_benchmark_cifar100.py (subprocess)
    4. Legge l'ACC da results.json
    """
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    program_path = os.path.abspath(program_path)

    import hashlib
    mod_name = "evolved_" + hashlib.md5(program_path.encode()).hexdigest()[:8]
    if mod_name in sys.modules:
        del sys.modules[mod_name]

    spec = importlib.util.spec_from_file_location(mod_name, program_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    params = mod.get_params()

    # Bounds
    params['eta_v1'] = float(max(1e-5, min(0.1, params['eta_v1'])))
    params['eta_v2'] = float(max(1e-5, min(0.1, params['eta_v2'])))
    params['eta_v3'] = float(max(1e-5, min(0.1, params['eta_v3'])))
    params['eta_v45'] = float(max(1e-5, min(0.1, params['eta_v45'])))
    params['eta_dense'] = float(max(1e-5, min(0.1, params['eta_dense'])))
    params['eta_oja'] = float(max(1e-5, min(0.5, params['eta_oja'])))
    params['eta_da'] = float(max(1e-4, min(1.0, params['eta_da'])))
    params['beta'] = float(max(0.1, min(20.0, params['beta'])))
    params['target_sum'] = float(max(1.0, min(50.0, params['target_sum'])))
    params['target_sparsity'] = float(max(0.01, min(0.5, params['target_sparsity'])))

    # Write params to bridge file
    params_file = os.path.join(project_root, 'evolution_params.json')
    with open(params_file, 'w') as f:
        json.dump(params, f)

    try:
        # Run benchmark
        # To avoid extremely slow evaluations, we evaluate on 1 task, 3 epochs, 30 samples/class
        cmd = [
            "python3", "run_benchmark_cifar100.py",
            "--n_tasks", "1",
            "--samples_per_class", "30",
            "--epochs_per_task", "3",
            "--pretrain_epochs", "1"
        ]
        res = subprocess.run(cmd, cwd=project_root, capture_output=True, text=True)
        
        # Parse result
        res_file = os.path.join(project_root, 'results_cifar100', 'results.json')
        with open(res_file, 'r') as f:
            results = json.load(f)
            acc = float(results[0].get('ACC', 0.0))
            
        print(f"[OpenEvolve] Esecuzione: ACC={acc:.3f} | eta_da={params['eta_da']:.3f} beta={params['beta']:.2f}")

        return {
            "score": acc,
            "combined_score": acc,
            "accuracy": acc
        }
    except Exception as e:
        print(f"Evaluator error: {e}")
        return {"score": 0.0, "error": str(e)}
