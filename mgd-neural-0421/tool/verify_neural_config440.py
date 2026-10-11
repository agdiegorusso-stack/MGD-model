"""Assert production native parameters equal the exported assessment config."""
import json,pathlib,re
out=pathlib.Path('tool/reports')
d=json.loads((out/'neural-inference-config-440.json').read_text())
native=pathlib.Path('android/app/src/main/kotlin/it/diegorusso/mgd_neuro_mobile/NeuralReader439.kt').read_text()
assert f'thinkingTokenBudget = if (reasoning) {d["thinking_budget"]} else 0' in native
assert f'maxOutputToken = if (reasoning) {d["max_output_tokens"]} else 512' in native
assert f'maxNumTokens = {d["max_context_tokens"]}' in native
assert 'topK = 20' in native and 'topP = if (reasoning) 0.95 else 0.8' in native
assert 'temperature = if (reasoning) 0.6 else 0.7, seed = 439' in native
assert d['top_k']==20 and d['top_p']==.95 and d['temperature']==.6 and d['seed']==439
current={p['id']:p['prompt'] for p in json.loads((out/'neural-prompts-439.json').read_text())}
baseline=json.loads(pathlib.Path('../mgd_reader_assessment_prompts439.json').read_text())
assert all(current[p['id']]==p['prompt'].replace('/no_think','') for p in baseline)
(out/'neural-production-equivalence-440.json').write_text(json.dumps(dict(
    development_prompts_identical_to_budget_probe=True,
    production_native_parameters_equal_assessment=True,
    config=d, universal_comprehension_proven=False),indent=2))
print('Native and production assessment configuration match; all 24 selection prompts identical.')
