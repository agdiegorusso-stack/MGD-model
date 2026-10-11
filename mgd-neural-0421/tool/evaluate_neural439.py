import json, pathlib, time
import litert_lm

out = pathlib.Path('tool/reports')
prompts = json.loads((out / 'neural-prompts-439.json').read_text())
gold = json.loads(pathlib.Path('tool/fixtures/neural_comprehension_439_key.json').read_text())
model = pathlib.Path('android/app/src/main/assets/reader439/model.litertlm')
results, readings = [], []
start = time.monotonic()
with litert_lm.Engine(str(model), max_num_tokens=2048) as engine:
    for p in prompts:
        t = time.monotonic()
        try:
            # Each case has a fresh conversation: no test target, previous answer,
            # or gold label is ever provided to the reader.
            with engine.create_conversation(extra_context={'enable_thinking': False},
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.8, temperature=0.0, seed=439),
                    max_output_tokens=384, automatic_tool_calling=False) as conv:
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
            r = dict(id=p['id'], domain=p['domain'], capability=p['capability'], raw=raw,
                expected=gold[p['id']], exact_choice_correct=correct, citation_format_valid=valid,
                abstention_correct=calibrated, passed=correct and valid and calibrated,
                elapsed_seconds=time.monotonic()-t, semantic_entailment_verified=False)
        except Exception as ex:
            r = dict(id=p['id'], passed=False, error=str(ex), elapsed_seconds=time.monotonic()-t)
        results.append(r)
        print('CASE', p['id'], r['passed'], flush=True)
    # Separately exercise the actual all-passage interpretation prompt on diverse
    # inputs. Count parse/reference validity, not semantic correctness of notes.
    for p in prompts[::4]:
        try:
            with engine.create_conversation(extra_context={'enable_thinking': False},
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.8, temperature=0.0, seed=439),
                    max_output_tokens=384, automatic_tool_calling=False) as conv:
                raw = str(conv.send_message(p['reading_prompt']))
            a, b = raw.find('{'), raw.rfind('}')
            data = json.loads(raw[a:b+1])
            notes = data.get('notes', [])
            valid = isinstance(notes, list) and bool(notes) and all(isinstance(n, dict)
                and isinstance(n.get('text'), str) and n['text'].strip()
                and isinstance(n.get('evidence'), list) and n['evidence']
                and all(x.startswith('P') and x[1:].isdigit() and int(x[1:]) < p['context_rows'] for x in n['evidence']) for n in notes)
            readings.append(dict(id=p['id'], raw=raw, note_references_valid=valid, semantic_correctness_verified=False))
        except Exception as ex:
            readings.append(dict(id=p['id'], error=str(ex), note_references_valid=False))
report = {'version': '0.42.19', 'model': json.loads((out / 'neural-model-439.json').read_text()),
    'environment': 'Linux CPU LiteRT-LM 0.18.0; not measured on an Android phone',
    'assessment': '24 custom short Italian texts, fresh conversations, exact multiple-choice labels plus abstention and citation checks',
    'passed': sum(r['passed'] for r in results), 'total': len(results),
    'exact_choices_correct': sum(r.get('exact_choice_correct', False) for r in results),
    'valid_note_reference_batches': sum(r['note_references_valid'] for r in readings),
    'note_batches_tested': len(readings), 'elapsed_seconds': time.monotonic()-start,
    'universal_comprehension_proven': False, 'public_benchmark_run': False,
    'results': results, 'reading_results': readings}
(out / 'neural-comprehension-439.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps({k: v for k, v in report.items() if k not in ['results','reading_results','model']}), flush=True)
assert len(results) == 24
