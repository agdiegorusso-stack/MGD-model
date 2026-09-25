"""Verify saved evidence without training again or changing model selection."""
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

from benchmark import (BURN, SCENARIOS, TinyTransformer, fixed_sets, memory,
                       paired_interval, stream, transformer_predictions)


def main():
    out = Path('results')
    report = json.loads((out / 'results.json').read_text())
    saved = np.load(out / 'test_streams.npz')
    predictions = np.load(out / 'predictions.npz')
    test = fixed_sets(72000, 256)
    for scenario, data in test.items():
        for key, value in data.items():
            assert np.array_equal(value, saved[f'{scenario}_{key}'])
    digest = hashlib.sha256(b''.join(
        d[k].tobytes() for d in test.values() for k in ['keys', 'obs', 'target']
    )).hexdigest()
    assert digest == report['testSha256']

    torch.set_num_threads(2)
    torch.use_deterministic_algorithms(True)
    controls = []
    for seed in [21, 22, 23]:
        ckpt = torch.load(out / f'transformer_{seed}.pt', weights_only=True)
        model = TinyTransformer()
        model.load_state_dict(ckpt['state'])
        model.eval()
        for scenario, data in test.items():
            actual = transformer_predictions(model, data)
            assert np.array_equal(actual, predictions[f'Transformer{seed}_{scenario}'])
        clean = stream(993000 + seed, 64, 0., 0.)
        clean_pred = transformer_predictions(model, clean)
        clean_accuracy = float((clean_pred[:, BURN:] == clean['target'][:, BURN:]).mean())
        k = torch.from_numpy(clean['keys'][:2])
        v = torch.from_numpy(clean['obs'][:2])
        v2 = v.clone()
        v2[:, 64:] = (v2[:, 64:] + 1) % 4
        with torch.inference_mode():
            future_error = float((model(k, v)[:, :64] - model(k, v2)[:, :64]).abs().max())
        assert clean_accuracy >= .95 and future_error < 1e-5
        controls.append({'seed': seed, 'cleanAccuracy': clean_accuracy,
                         'futureLogitDifference': future_error})

    # Recalculate scores from saved predictions, not printed summary rows.
    per_episode = {}
    per_seed = {}
    for name, rows in report['results'].items():
        per_episode[name] = []
        for scenario, row in rows.items():
            data = test[scenario]
            target = data['target'][:, BURN:]
            if name == 'Transformer_mean':
                corrects = []
                for seed in [21, 22, 23]:
                    correct = predictions[f'Transformer{seed}_{scenario}'][:, BURN:] == target
                    corrects.append(correct)
                    per_seed.setdefault(str(seed), {})[scenario] = float(correct.mean())
                correct = np.mean(corrects, axis=0)
            elif name == 'Bayes_known_generator':
                hazard, noise = SCENARIOS[scenario]
                pred = memory(data, 'bayes', {'hazard': hazard, 'noise': noise})
                correct = pred[:, BURN:] == target
            else:
                correct = predictions[f'{name}_{scenario}'][:, BURN:] == target
            assert abs(float(correct.mean()) - row['accuracy']) < 1e-12
            per_episode[name].append(correct.mean(1))

    selected = report['selection']['mgd']['params']
    for scenario, data in test.items():
        actual = memory(data, 'mgd', selected)
        assert np.array_equal(actual, predictions[f'MGD_{scenario}'])
        # Predictions must not depend on evaluation labels.
        relabelled = {**data, 'target': (data['target'] + 1) % 4}
        assert np.array_equal(actual, memory(relabelled, 'mgd', selected))
        changed_future = {**data, 'obs': data['obs'].copy()}
        changed_future['obs'][:, 64:] = (changed_future['obs'][:, 64:] + 1) % 4
        assert np.array_equal(actual[:, :64], memory(changed_future, 'mgd', selected)[:, :64])

    for name, expected in report['pairedComparisonsMGDMinusOther'].items():
        actual = paired_interval(per_episode['MGD'], per_episode[name])
        assert abs(actual['deltaPercentagePoints'] - expected['deltaPercentagePoints']) < 1e-12
        assert np.allclose(actual['ci95Percentile'], expected['ci95Percentile'], atol=1e-12, rtol=0)

    per_scenario = {}
    for i, scenario in enumerate(SCENARIOS):
        per_scenario[scenario] = {
            name: paired_interval([per_episode['MGD'][i]], [per_episode[name][i]])
            for name in ['Transformer_mean', 'EMA', 'MGD_no_material_retuned',
                         'MGD_no_memory_same_params', 'counts']
        }
    for seed, row in per_seed.items():
        row['mean'] = float(np.mean(list(row.values())))
    summary = {
        'allChecksPassed': True,
        'testSha256': digest,
        'transformerControlsRechecked': controls,
        'savedCheckpointPredictionsReproducedExactly': True,
        'mgdPredictionsReproducedExactly': True,
        'mgdLabelAndFutureIndependencePassed': True,
        'savedAggregateAccuraciesAndBootstrapIntervalsReproduced': True,
        'means': {name: float(np.mean(episodes)) for name, episodes in per_episode.items()},
        'transformerSeedAccuracies': per_seed,
        'secondaryPerScenarioMGDMinusOther': per_scenario,
        'secondaryAnalysisWarning': 'Per-scenario intervals are descriptive, without correction for multiple comparisons; do not replace the primary criterion.'
    }
    (out / 'verification.json').write_text(json.dumps(summary, indent=2))
    manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(out.iterdir()) if p.is_file() and p.name != 'SHA256SUMS.txt'}
    (out / 'SHA256SUMS.txt').write_text(''.join(f'{digest}  {name}\n' for name, digest in manifest.items()))
    print(json.dumps({'allChecksPassed': True, 'means': summary['means'],
                      'transformerSeedAccuracies': per_seed}, indent=2))


if __name__ == '__main__':
    main()
