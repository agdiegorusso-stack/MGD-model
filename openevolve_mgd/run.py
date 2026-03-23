import sys
import os
import multiprocessing

# Guard obbligatorio su Windows: senza questo il worker
# process reimporta run.py dall'inizio creando una seconda
# istanza OpenEvolve invece di eseguire solo il task assegnato
if __name__ == '__main__':
    multiprocessing.freeze_support()

    project_root = os.path.abspath(
        os.path.join(os.path.dirname(__file__), '..'))
    if project_root not in sys.path:
        sys.path.insert(0, project_root)

    api_key = os.environ.get('OPENAI_API_KEY', '')
    if not api_key:
        print('Errore: OPENAI_API_KEY non impostata.')
        print('Esegui: $env:OPENAI_API_KEY = "sk-proj-..."')
        sys.exit(1)

    from openevolve import run_evolution
    from openevolve.config import Config, LLMModelConfig

    config = Config()
    config.max_iterations = 100
    config.random_seed = 42
    config.output_dir = 'openevolve_mgd/results'

    config.llm.models = [
        LLMModelConfig(
            name='gpt-4.1-mini',
            api_base='https://api.openai.com/v1',
            api_key=api_key,
            temperature=0.7,
            max_tokens=2048,
        )
    ]

    config.database.population_size = 20
    config.database.num_islands = 1
    config.database.migration_interval = 10

    config.evaluator.timeout = 900
    
    # Inietta il prompt per l'ottimizzazione mirata alla Separabilità Lineare (ACC 1.0)
    config.prompt.system_message = """
You are optimizing hyperparameters to solve dimensional collapse
and reach 1.0 ACC (100% Accuracy) on CIFAR-100 Task 1 using the
DendriticHierarchy MGD architecture.

The function get_params() returns the hyperparameters.
Your goal is to maximize `score` which is the CIFAR-100 task accuracy (0.0 to 1.0).
You MUST break the 0.200 random guessing barrier!

RULES:
- Return ONLY the modified get_params() function.
- Keep all keys exactly as they are.

PARAMS SPACE:
- eta_v1, eta_v2, eta_v3: [0.0001, 0.05]
- eta_v45, eta_dense: [0.0001, 0.05]
- eta_oja: [0.001, 0.1]
- eta_da: [0.01, 0.5]
- beta: [0.5, 10.0] (Feedback alignment Top-Down error multiplier)
- target_sum: [1.0, 30.0] (Homeostatic constraint sum)
- target_sparsity: [0.01, 0.2] (% of active WTA neurons)
"""

    result = run_evolution(
        initial_program='openevolve_mgd/initial_program.py',
        evaluator='openevolve_mgd/evaluator.py',
        config=config,
        iterations=100,
        output_dir='openevolve_mgd/results',
        cleanup=False,
    )

    print(f'\n=== EVOLUZIONE COMPLETATA ===')
    print(f'Best score: {result.best_score}')
    print(f'\nParametri migliori trovati:')
    print(result.best_program)
