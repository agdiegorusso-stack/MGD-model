import hashlib, json, pathlib, time, traceback, urllib.request
from huggingface_hub import HfApi, hf_hub_download

out = pathlib.Path('mgd-reader-probe-results')
out.mkdir(exist_ok=True)
repo = 'litert-community/Qwen3-0.6B'
name = 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm'
report = {'repo': repo, 'filename': name, 'runtime': 'LiteRT-LM 0.18.0', 'success': False}
try:
    info = HfApi().model_info(repo, files_metadata=True)
    entry = next(x for x in info.siblings if x.rfilename == name)
    report.update(revision=info.sha, bytes=entry.size, expected_sha256=entry.lfs.sha256)
    path = hf_hub_download(repo, name, revision=info.sha)
    report['sha256'] = hashlib.file_digest(open(path, 'rb'), 'sha256').hexdigest()
    assert report['sha256'] == report['expected_sha256']
    import litert_lm
    print('MODEL VERIFIED', report['revision'], report['bytes'], flush=True)
    start = time.monotonic()
    with litert_lm.Engine(path, max_num_tokens=2048) as engine:
        report['load_seconds'] = time.monotonic() - start
        print('ENGINE LOADED', flush=True)
        with engine.create_conversation(extra_context={'enable_thinking': False}) as conv:
            result = str(conv.send_message('Testo: Giulia mise la chiave nel cassetto. Poi spostò il libro sul tavolo. Dove si trova la chiave? Rispondi in italiano in una sola frase. /no_think'))
            report['coreference_answer'] = result
            report['success'] = 'cassetto' in result.lower()
            print('ANSWER', result, flush=True)
    report['elapsed_seconds'] = time.monotonic() - start
    for kind in ['android', 'jvm']:
        url = f'https://dl.google.com/dl/android/maven2/com/google/ai/edge/litertlm/litertlm-{kind}/maven-metadata.xml'
        try:
            text = urllib.request.urlopen(url).read().decode()
            (out / f'maven-{kind}.xml').write_text(text)
        except Exception as ex:
            report[f'maven_{kind}_error'] = str(ex)
except Exception as ex:
    report['error'] = str(ex)
    report['traceback'] = traceback.format_exc()
finally:
    (out / 'feasibility.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(json.dumps(report, ensure_ascii=False), flush=True)
if not report['success']:
    raise SystemExit('Feasibility check failed; no general-comprehension claim.')
