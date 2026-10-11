"""Development-only inference-budget selection; never exposes gold to inference."""
import hashlib, json, os, pathlib, time
from huggingface_hub import hf_hub_download
import litert_lm

budget = int(os.environ['MGD_THINKING_BUDGET'])
assert budget in (768, 1024)
out = pathlib.Path('mgd-reader-budget-results'); out.mkdir(exist_ok=True)
model = hf_hub_download('litert-community/Qwen3-1.7B',
    'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
    revision='79bf0667b32ae025b972e5fe555fe72ca6e8816c')
with open(model, 'rb') as stream:
    assert hashlib.file_digest(stream, 'sha256').hexdigest() == '2a72330b504a6596d53a2c00923c57173b10f1b83e6a541213ffec08d1fc5de8'
prompts = json.loads(pathlib.Path('mgd_reader_assessment_prompts439.json').read_text())
gold = json.loads(pathlib.Path('mgd-neural-0421/tool/fixtures/neural_comprehension_439_key.json').read_text())
assert {p['id'] for p in prompts} == set(gold) and len(prompts) == 24
results = []
with litert_lm.Engine(model, max_num_tokens=4096) as engine:
    for p in prompts:
        start, raw = time.monotonic(), None
        try:
            with engine.create_conversation(extra_context={'enable_thinking': True},
                    thinking_config=litert_lm.ThinkingConfig(enable_thinking=True, thinking_token_budget=budget),
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.95, temperature=0.6, seed=439),
                    max_output_tokens=budget+512, automatic_tool_calling=False) as conv:
                raw = str(conv.send_message(p['prompt'].replace('/no_think', '')))
            a, b = raw.find('{'), raw.rfind('}')
            data = json.loads(raw[a:b+1])
            refs, unknown = data.get('evidence'), data.get('unknown')
            valid = isinstance(refs, list) and all(isinstance(x, str) and x.startswith('P') and x[1:].isdigit() and int(x[1:]) < p['context_rows'] for x in refs)
            valid = valid and isinstance(unknown, bool) and (unknown or bool(refs))
            choice = str(data.get('answer', '')).strip().upper()
            correct = choice == gold[p['id']]['answer']
            calibrated = unknown == gold[p['id']]['unknown']
            r = dict(id=p['id'], raw=raw, expected=gold[p['id']], exact_choice_correct=correct,
                citation_format_valid=valid, abstention_correct=calibrated,
                passed=correct and valid and calibrated, seconds=time.monotonic()-start)
        except Exception as ex:
            r = dict(id=p['id'], raw=raw, passed=False, error=str(ex), seconds=time.monotonic()-start)
        results.append(r)
        report = dict(thinking_budget=budget, max_context_tokens=4096, max_output_tokens=budget+512,
            total=len(results), passed=sum(x['passed'] for x in results),
            exact_choices_correct=sum(x.get('exact_choice_correct',False) for x in results),
            results=results, model_selection_used_development_suite=True,
            universal_comprehension_proven=False, source_commit=os.environ.get('GITHUB_SHA'))
        (out/f'budget-{budget}.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
        print('CASE', budget, p['id'], r['passed'], flush=True)
print('FINAL', {k:v for k,v in report.items() if k!='results'}, flush=True)
