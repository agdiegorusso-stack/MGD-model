"""Reuse only valid outputs whose model, prompts and inference settings match.

The twelve held-out outputs from the reference run had a key mismatch and
are deliberately excluded. They must be executed again by the evaluator.
"""
import hashlib
import json
import pathlib
import subprocess

out = pathlib.Path('tool/reports')
ref = pathlib.Path('tool/reference-assessment439')
commit = 'bba2a4d6b905d15c1c86dd06ef42472f1d40b048'
run = 38139443358

def digest(data):
    return hashlib.sha256(data).hexdigest()

def original(path):
    return subprocess.check_output(['git', 'show', f'{commit}:mgd-neural-0421/{path}'])

report_bytes = (ref / 'neural-comprehension-439.json').read_bytes()
assert digest(report_bytes) == 'e765b11a142a1ebbb7cd367b826a27ddd1f7dcb6d3ec783233698ec84898f2b0'
assert (ref / 'BUILD-COMMIT.txt').read_text().strip() == commit
report = json.loads(report_bytes)
current_prompts = (out / 'neural-prompts-439.json').read_bytes()
assert current_prompts == (ref / 'neural-prompts-439.json').read_bytes(), 'Production prompts changed: cannot reuse assessment'
assert json.loads((out / 'neural-model-439.json').read_text()) == report['model']
native = pathlib.Path('android/app/src/main/kotlin/it/diegorusso/mgd_neuro_mobile/NeuralReader439.kt')
assert digest(native.read_bytes()) == 'ed7ac9cf8d93143d7e462caa74901556c2797ec3714d402e407e34534ac6b0be'
assert native.read_bytes() == original(str(native)), 'Native inference changed'
# This exact candidate changes only parsing/display of omitted uncertainty.
# Validate before dart format; the following build only reformats whitespace.
reader = pathlib.Path('lib/neural_reading_v0439.dart').read_bytes()
assert digest(reader) == '808661c8e95e5d70c4cc385b66333235d8b6cd46125a7d1b50fb10bceab59872'
old_evaluator = original('tool/evaluate_neural439.py')
assert digest(old_evaluator) == 'fdaed67b965d6b796dad9506208631eb3939dadf42a1c230afd5481d68be8f2d'
new_evaluator = pathlib.Path('tool/evaluate_neural439.py').read_bytes()

def inference_block(source, thinking):
    text = source.decode()
    start = text.index("with engine.create_conversation(extra_context={'enable_thinking': " + thinking + '},')
    end = text.index("\n            a, b = raw.find", start)
    return text[start:end]

for mode in ['True', 'False']:
    assert inference_block(old_evaluator, mode) == inference_block(new_evaluator, mode), 'Inference configuration changed'
assert 'with litert_lm.Engine(str(model), max_num_tokens=3072) as engine:' in new_evaluator.decode()
assert report['thinking_budget'] == 256 and report['max_context_tokens'] == 3072
assert report['qa_constrained_json'] is False and report['reading_constrained_json'] is True
development = [r for r in report['results'] if r['split'] == 'development']
assert len(development) == 24 and all('raw' in r and 'error' not in r for r in development)
assert len(report['reading_results']) == 9
proof = {
    'equivalent_inputs_verified': True,
    'reference_commit': commit, 'reference_workflow_run': run,
    'reference_artifact_id': 11702793836,
    'reference_report_sha256': digest(report_bytes),
    'production_prompts_sha256': digest(current_prompts),
    'reader_candidate_sha256_before_format': digest(reader),
    'native_source_sha256': digest(native.read_bytes()),
    'model_sha256': report['model']['sha256'],
    'qa_and_reading_inference_blocks_identical': True,
    'development_outputs_reused': 24, 'note_format_outputs_reused': 9,
    'heldout_outputs_reused': 0, 'heldout_cases_to_reexecute': 12,
    'reason': 'Model inputs and inference are unchanged. App change only exposes missing abstention metadata as undeclared uncertainty. Reference held-out key mismatch requires new inference and grading.'
}
(out / 'reference-neural-comprehension-439.json').write_bytes(report_bytes)
(out / 'reference-assessment-equivalence-439.json').write_text(json.dumps(proof, indent=2))
print(json.dumps(proof, indent=2))
