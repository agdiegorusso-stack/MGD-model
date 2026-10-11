import hashlib, json, pathlib, shutil
from huggingface_hub import hf_hub_download

manifest = {'repo': 'litert-community/Qwen3-0.6B',
    'revision': 'a3c5d805ae362dff7f580bc25f2dfb9a5a7eaa76',
    'filename': 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    'sha256': '03e7da1eb1108b50dffaa9bb52cc7bcbad2eb0c66ca990267f480c1e545d2856',
    'bytes': 344671744, 'runtime': 'LiteRT-LM 0.18.0', 'license': 'Apache-2.0',
    'weights_updated_by_MGD': False, 'universal_comprehension': False}
source = hf_hub_download(manifest['repo'], manifest['filename'], revision=manifest['revision'])
assert pathlib.Path(source).stat().st_size == manifest['bytes']
with open(source, 'rb') as stream:
    assert hashlib.file_digest(stream, 'sha256').hexdigest() == manifest['sha256']
out = pathlib.Path('android/app/src/main/assets/reader439')
out.mkdir(parents=True, exist_ok=True)
shutil.copyfile(source, out / 'model.litertlm')
(out / 'model.json').write_text(json.dumps(manifest, indent=2))
license_path = hf_hub_download('Qwen/Qwen3-0.6B', 'LICENSE')
shutil.copyfile(license_path, out / 'LICENSE-Qwen.txt')
(out / 'NOTICE.txt').write_text('MGD Studio 0.42.19 uses Qwen3-0.6B by the Qwen team, converted by LiteRT Community.\n'
    'Runtime: LiteRT-LM by Google, Apache-2.0. The MGD reading memory and source records are separate from the pretrained model.\n'
    'Model source: https://huggingface.co/litert-community/Qwen3-0.6B\n'
    'Original model: https://huggingface.co/Qwen/Qwen3-0.6B\n'
    'Runtime: https://github.com/google-ai-edge/LiteRT-LM/tree/v0.18.0\n')
reports = pathlib.Path('tool/reports'); reports.mkdir(exist_ok=True)
(reports / 'neural-model-439.json').write_text(json.dumps(manifest, indent=2))
print('Pinned local model verified and bundled:', manifest['bytes'], 'bytes')
