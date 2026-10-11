import hashlib, json, os, pathlib, time
import litert_lm

out = pathlib.Path('tool/reports')
prompts = json.loads((out / 'neural-prompts-439.json').read_text())
gold = {**json.loads(pathlib.Path('tool/fixtures/neural_comprehension_439_key.json').read_text()), **json.loads(pathlib.Path('tool/fixtures/neural_holdout2_439_key.json').read_text())}
assert len(prompts) == 36 and len({p['id'] for p in prompts}) == 36
assert set(gold) == {p['id'] for p in prompts}, 'Fixture/key mismatch; abort before inference'
model = pathlib.Path('android/app/src/main/assets/reader439/model.litertlm')
baseline_path = pathlib.Path('../mgd_reader_assessment_prompts439.json')
if baseline_path.exists():
    baseline = {p['id']: p['prompt'].replace('/no_think','') for p in json.loads(baseline_path.read_text())}
    for p in prompts:
        if p['split']=='development':
            assert p['prompt']==baseline[p['id']], 'Restored QA prompt differs from measured baseline: '+p['id']
    print('All 24 development prompts match the measured reasoning baseline byte-for-byte.', flush=True)

results, readings, provenance = [], [], {}
to_run = prompts
reference = out / 'reference-neural-comprehension-439.json'
if reference.exists():
    provenance = json.loads((out / 'reference-assessment-equivalence-439.json').read_text())
    assert provenance['equivalent_inputs_verified'] is True
    assert hashlib.sha256((out / 'neural-prompts-439.json').read_bytes()).hexdigest() == provenance['production_prompts_sha256']
    prior = json.loads(reference.read_text())
    results = [dict(r, assessment_source_commit=provenance['reference_commit'], assessment_workflow_run=provenance['reference_workflow_run'])
        for r in prior['results'] if r['split'] == 'development']
    assert len(results) == 24 and all('raw' in r and 'error' not in r for r in results)
    assert all(r['expected'] == gold[r['id']] for r in results)
    readings = prior['reading_results']
    assert len(readings) == 9 and [r['id'] for r in readings] == [p['id'] for p in prompts[::4]]
    to_run = [p for p in prompts if p['split'] == 'heldout']
    print('Reusing 24 development answers and 9 note-format probes with verified identical inputs. Re-executing all 12 held-out cases with the corrected key.', flush=True)
start = time.monotonic()
with litert_lm.Engine(str(model), max_num_tokens=3072) as engine:
    for p in to_run:
        t = time.monotonic()
        raw = None
        try:
            # Each case has a fresh conversation: no test target, previous answer,
            # or gold label is ever provided to the reader.
            with engine.create_conversation(extra_context={'enable_thinking': True},
                    thinking_config=litert_lm.ThinkingConfig(enable_thinking=True, thinking_token_budget=256),
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.95, temperature=0.6, seed=439),
                    max_output_tokens=768, automatic_tool_calling=False) as conv:
                raw = str(conv.send_message(p['prompt']))
            a, b = raw.find('{'), raw.rfind('}')
            data = json.loads(raw[a:b+1]) if a >= 0 and b > a else {}
            refs = data.get('evidence', [])
            unknown = data.get('unknown')
            valid_refs = isinstance(refs, list) and all(isinstance(x, str) and x.startswith('P') and x[1:].isdigit()
                and int(x[1:]) < p['context_rows'] for x in refs)
            valid = valid_refs and isinstance(unknown, bool) and (unknown or bool(refs))
            choice = str(data.get('answer', '')).strip().upper()
            correct = choice == gold[p['id']]['answer']
            calibrated = unknown == gold[p['id']]['unknown']
            r = dict(id=p['id'], domain=p['domain'], capability=p['capability'], split=p['split'], raw=raw,
                expected=gold[p['id']], exact_choice_correct=correct, citation_format_valid=valid,
                abstention_correct=calibrated, passed=correct and valid and calibrated,
                elapsed_seconds=time.monotonic()-t, semantic_entailment_verified=False)
        except Exception as ex:
            r = dict(id=p['id'], split=p['split'], raw=raw, passed=False, error=str(ex), elapsed_seconds=time.monotonic()-t)
        r['assessment_source_commit'] = os.environ.get('GITHUB_SHA', 'local')
        r['assessment_workflow_run'] = os.environ.get('GITHUB_RUN_ID', 'local')
        results.append(r)
        print('CASE', p['id'], r['passed'], flush=True)
    # Separately exercise the actual all-passage interpretation prompt on diverse
    # inputs. Count parse/reference validity, not semantic correctness of notes.
    for p in ([] if readings else prompts[::4]):
        try:
            with engine.create_conversation(extra_context={'enable_thinking': False},
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.8, temperature=0.7, seed=439),
                    max_output_tokens=512, automatic_tool_calling=False,
                    constrained_decoding_config=litert_lm.ConstrainedDecodingConfig(enable=True, provider=litert_lm.LiteRtLmConstraintProviderType.LL_GUIDANCE)) as conv:
                raw = str(conv.send_message(p['reading_prompt'], response_format=litert_lm.ResponseFormat.json(p['reading_schema'])))
            a, b = raw.find('{'), raw.rfind('}')
            data = json.loads(raw[a:b+1])
            notes = data.get('notes', [])
            valid = isinstance(notes, list) and bool(notes) and all(isinstance(n, dict)
                and isinstance(n.get('text'), str) and len(n['text'].strip()) >= 8
                and n['text'].strip().lower() not in ['nota','contenuto concreto','risposta']
                and isinstance(n.get('evidence'), list) and n['evidence']
                and all(x.startswith('P') and x[1:].isdigit() and int(x[1:]) < p['context_rows'] for x in n['evidence']) for n in notes)
            readings.append(dict(id=p['id'], raw=raw, note_references_valid=valid, semantic_correctness_verified=False))
        except Exception as ex:
            readings.append(dict(id=p['id'], error=str(ex), note_references_valid=False))
report = {'version': '0.42.19', 'model': json.loads((out / 'neural-model-439.json').read_text()),
    'environment': 'Linux CPU LiteRT-LM 0.18.0; not measured on an Android phone',
    'assessment': '24 development texts used for model selection plus 12 fresh held-out Italian texts fixed after rejecting guided QA; previous holdout is now diagnostic; fresh conversations, exact labels, abstention and citation checks',
    'passed': sum(r['passed'] for r in results), 'total': len(results),
    'development_passed': sum(r['passed'] for r in results if r['split']=='development'), 'development_total': 24,
    'heldout_passed': sum(r['passed'] for r in results if r['split']=='heldout'), 'heldout_total': 12,
    'exact_choices_correct': sum(r.get('exact_choice_correct', False) for r in results),
    'development_exact_choices_correct': sum(r.get('exact_choice_correct', False) for r in results if r['split']=='development'),
    'heldout_exact_choices_correct': sum(r.get('exact_choice_correct', False) for r in results if r['split']=='heldout'),
    'valid_note_reference_batches': sum(r['note_references_valid'] for r in readings),
    'note_batches_tested': len(readings), 'elapsed_seconds': time.monotonic()-start,
    'universal_comprehension_proven': False, 'public_benchmark_run': False, 'thinking_budget': 256, 'max_context_tokens': 3072, 'qa_constrained_json': False, 'reading_constrained_json': True,
    'results': results, 'reading_results': readings,
    'assessment_provenance': provenance,
    'heldout_key_mismatch_in_previous_run': 'Previous run 38139443358 used H keys for J inputs: its 12 held-out results are invalid, excluded and re-executed here. Development outputs and note-format probes were unaffected.',
    'uncertainty_reporting': 'Missing unknown is accepted by the app as explicitly undeclared uncertainty, never imputed. This assessment retains the strict full-protocol grading: missing unknown still fails.'}
(out / 'neural-comprehension-439.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps({k: v for k, v in report.items() if k not in ['results','reading_results','model']}), flush=True)
assert len(results) == 36
