"""Paired new-text evaluation of frozen historical and production pipelines.

Gold labels are consulted ONLY after generation. Valid reference syntax is not
entailment. Every output, including malformed output and errors, is retained.
"""
import hashlib, json, os, pathlib, time
import litert_lm

out = pathlib.Path('tool/reports'); out.mkdir(exist_ok=True)
role = os.environ['MGD_EVALUATION_ROLE']
assert role in ('baseline', 'candidate')
prompts_path = out / 'neural-holdout-prompts-440.json'
prompts = json.loads(prompts_path.read_text())
key_path = pathlib.Path('tool/fixtures/neural_holdout_440_key.json')
assert hashlib.sha256(key_path.read_bytes()).hexdigest() == '594cd89e6c1ba8e1607b2574e57764c71077b8ff4ebac1702f93423a9178a127'
gold = json.loads(key_path.read_text())
evidence_path = pathlib.Path('tool/fixtures/neural_holdout_440_evidence_key.json')
assert hashlib.sha256(evidence_path.read_bytes()).hexdigest() == '47c02c36e4b6b39b853ffeb231a670547968cf9639470fd2b004ebf4142a42b5'
evidence_gold = json.loads(evidence_path.read_text())['cases']
assert len(prompts) == 16 and set(gold) == {p['id'] for p in prompts}
production = json.loads((out/'neural-inference-config-440.json').read_text())
config = production if role == 'candidate' else dict(thinking_budget=256, max_context_tokens=3072,
    max_output_tokens=768, top_k=20, top_p=.95, temperature=.6, seed=439)
model_path = pathlib.Path('android/app/src/main/assets/reader439/model.litertlm')
model_manifest = json.loads((out/'neural-model-439.json').read_text())
with model_path.open('rb') as stream:
    assert hashlib.file_digest(stream,'sha256').hexdigest() == model_manifest['sha256']
results = []
started = time.monotonic()
with litert_lm.Engine(str(model_path), max_num_tokens=config['max_context_tokens']) as engine:
    for p in prompts:
        prompt = p['prompt'] if role == 'candidate' else p['baseline_prompt']
        row_count = p['context_rows'] if role == 'candidate' else p['baseline_context_rows']
        context = p['context'] if role == 'candidate' else p['baseline_context']
        # A small finite citation oracle additionally requires the source
        # premises authored for this fixture. It is not an unrestricted NLI
        # verifier; syntax alone cannot pass this evidence check.
        groups = evidence_gold[p['id']]
        def covers(rows):
            return all(any(all(s.casefold() in str(r['text']).casefold() for s in group)
                for r in rows) for group in groups)
        input_premises_present = covers(context)
        raw, before = None, time.monotonic()
        try:
            with engine.create_conversation(extra_context={'enable_thinking': True},
                    thinking_config=litert_lm.ThinkingConfig(enable_thinking=True, thinking_token_budget=config['thinking_budget']),
                    sampler_config=litert_lm.SamplerConfig(top_k=config['top_k'], top_p=config['top_p'],
                        temperature=config['temperature'], seed=config['seed']),
                    max_output_tokens=config['max_output_tokens'], automatic_tool_calling=False) as conv:
                raw = str(conv.send_message(prompt))
            a,b = raw.find('{'), raw.rfind('}')
            data = json.loads(raw[a:b+1]) if a >= 0 and b > a else {}
            refs, unknown = data.get('evidence'), data.get('unknown')
            refs_valid = isinstance(refs,list) and all(isinstance(x,str) and x.startswith('P')
                and x[1:].isdigit() and int(x[1:]) < row_count for x in refs)
            format_valid = refs_valid and isinstance(unknown,bool) and (unknown or bool(refs))
            choice = str(data.get('answer','')).strip().upper()
            correct = choice == gold[p['id']]['answer']
            abstention = isinstance(unknown,bool) and unknown == gold[p['id']]['unknown']
            cited_rows = [context[int(x[1:])] for x in refs] if refs_valid else []
            evidence_coverage = covers(cited_rows)
            result = dict(id=p['id'], domain=p['domain'], capability=p['capability'], raw=raw,
                expected=gold[p['id']], exact_choice_correct=correct, citation_format_valid=format_valid,
                abstention_correct=abstention, passed=correct and format_valid and abstention,
                expected_premises_present_in_context=input_premises_present,
                finite_cited_premise_coverage=evidence_coverage,
                passed_with_finite_evidence_coverage=correct and format_valid and abstention and evidence_coverage,
                examined_rows=row_count, available_rows=p['available_rows'],
                source_characters=p['source_characters'], elapsed_seconds=time.monotonic()-before,
                semantic_entailment_verified=False)
        except Exception as ex:
            result = dict(id=p['id'], raw=raw, error=str(ex), passed=False, elapsed_seconds=time.monotonic()-before)
        results.append(result)
        report = dict(version='0.42.20', role=role, model=model_manifest, config=config,
            source_commit=os.environ.get('GITHUB_SHA'), workflow_run=os.environ.get('GITHUB_RUN_ID'),
            prompts_sha256=hashlib.sha256(prompts_path.read_bytes()).hexdigest(),
            new_texts_fixed_before_configuration_choice=True,
            selected_from_development_only=True, fresh_conversation_per_case=True,
            exact_choices_correct=sum(r.get('exact_choice_correct',False) for r in results),
            passed=sum(r['passed'] for r in results), total=len(results),
            passed_with_finite_evidence_coverage=sum(r.get('passed_with_finite_evidence_coverage',False) for r in results),
            finite_evidence_criterion='Coverage of human-authored necessary premise substrings by cited original passages. This finite oracle does not prove unrestricted semantic entailment. Unknown cases use separate label and abstention checks.',
            short_texts_correct=sum(r.get('exact_choice_correct',False) for r in results if int(r['id'][1:])<=12),
            long_archive_correct=sum(r.get('exact_choice_correct',False) for r in results if int(r['id'][1:])>12),
            elapsed_seconds=time.monotonic()-started, results=results,
            weights_updated=False, universal_comprehension_proven=False,
            measurement_environment='GitHub Actions Linux CPU; no physical phone performance measurement')
        (out/f'neural-holdout-440-{role}.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
        print('CASE',role,p['id'],result['passed'],flush=True)
print('FINAL', {k:v for k,v in report.items() if k not in ('results','model')},flush=True)
