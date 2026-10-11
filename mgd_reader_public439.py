import hashlib, io, json, pathlib, urllib.request, zipfile, re
from huggingface_hub import hf_hub_download
import litert_lm

out = pathlib.Path('mgd-reader-probe-results'); out.mkdir(exist_ok=True)
url = 'https://dl.fbaipublicfiles.com/glue/superglue/data/v2/CB.zip'
data = urllib.request.urlopen(url, timeout=60).read()
with zipfile.ZipFile(io.BytesIO(data)) as z:
    name = next(n for n in z.namelist() if n.endswith('/val.jsonl'))
    items = [json.loads(l) for l in z.read(name).decode().splitlines() if l.strip()]
model = hf_hub_download('litert-community/Qwen3-0.6B',
    'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm', revision='a3c5d805ae362dff7f580bc25f2dfb9a5a7eaa76')
results = []
labels = {'A': 'entailment', 'B': 'contradiction', 'C': 'neutral'}
with litert_lm.Engine(model, max_num_tokens=2048) as engine:
    for item in items:
        # SuperGLUE CB is a different, public English task, not the Italian
        # app QA suite and not a full SuperGLUE score. Gold stays with examiner.
        prompt = ('Read the premise and decide if the hypothesis is entailed (A), '
            'contradicted (B), or neither (C). Consider the speaker\'s commitment, '
            'negations and reported beliefs. Return only one letter A, B, or C. /no_think\n' +
            json.dumps({'premise': item['premise'], 'hypothesis': item['hypothesis']}))
        try:
            with engine.create_conversation(extra_context={'enable_thinking': False},
                    sampler_config=litert_lm.SamplerConfig(top_k=20, top_p=0.8, temperature=0.0, seed=439),
                    max_output_tokens=64, automatic_tool_calling=False) as conv:
                raw = str(conv.send_message(prompt)).strip().upper()
            # Extract a single option token from a concise first line; do not
            # infer a label from a long explanation or from the premise.
            first = raw.splitlines()[0] if raw else ''
            token = re.fullmatch(r'\s*[(*]?([ABC])[).*:]?\s*', first)
            prediction = labels.get(token[1]) if token else None
            if prediction is None and first.lower() in labels.values():
                prediction = first.lower()
            if item['idx'] < 3: print('PUBLIC RAW', item['idx'], repr(raw), flush=True)
            results.append({'id': item['idx'], 'prediction': prediction,
                'gold': item['label'], 'correct': prediction == item['label'], 'output_format_valid': prediction is not None})
        except Exception as ex:
            results.append({'id': item['idx'], 'gold': item['label'], 'correct': False, 'error': str(ex)})
        print('PUBLIC CASE', item['idx'], results[-1]['correct'], flush=True)
scores = []
for label in labels.values():
    tp = sum(r.get('prediction') == label and r['gold'] == label for r in results)
    fp = sum(r.get('prediction') == label and r['gold'] != label for r in results)
    fn = sum(r.get('prediction') != label and r['gold'] == label for r in results)
    scores.append(2*tp/(2*tp+fp+fn) if 2*tp+fp+fn else 0)
report = {'task': 'SuperGLUE CommitmentBank validation', 'dataset_url': url,
    'dataset_zip_sha256': hashlib.sha256(data).hexdigest(),
    'total': len(results), 'correct': sum(r['correct'] for r in results),
    'accuracy': sum(r['correct'] for r in results)/len(results), 'macro_f1': sum(scores)/3,
    'output_format_valid': sum(r.get('output_format_valid', False) for r in results),
    'environment': 'Linux CPU, LiteRT-LM 0.18.0, Qwen3 0.6B INT4',
    'weights_updated': False, 'prompt_tuned_on_validation': False,
    'pretraining_contamination_excluded': False,
    'full_superglue_or_android_app_score': False,
    'universal_comprehension_proven': False, 'results': results}
(out/'public-comprehension-439.json').write_text(json.dumps(report, indent=2))
print(json.dumps({k:v for k,v in report.items() if k != 'results'}), flush=True)
assert len(results) == 56
