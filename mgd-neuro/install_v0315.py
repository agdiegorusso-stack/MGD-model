from pathlib import Path
import base64
import hashlib
import io
import shutil
import subprocess
import sys
import tarfile
import tempfile

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app').resolve()
source = Path(__file__).resolve().parent / 'v315'
encoded = ''.join((source / f'overlay.{i:02d}').read_text().strip() for i in range(4))
payload = base64.b64decode(encoded, validate=True)
expected = 'e4fc6413b2cebf23967bed7e2533993d7791504270e03e575f5e5e9b0713ea48'
if hashlib.sha256(payload).hexdigest() != expected:
    raise SystemExit('Memory inspector overlay SHA256 mismatch')
with tempfile.TemporaryDirectory(prefix='mgd-inspector-') as temp:
    work = Path(temp)
    with tarfile.open(fileobj=io.BytesIO(payload), mode='r:gz') as archive:
        for member in archive.getmembers():
            target = (work / member.name).resolve()
            if not target.is_relative_to(work.resolve()) or not member.isfile():
                raise SystemExit(f'Unsafe overlay entry: {member.name}')
            target.parent.mkdir(parents=True, exist_ok=True)
            reader = archive.extractfile(member)
            if reader is None:
                raise SystemExit(f'Unreadable overlay entry: {member.name}')
            with reader, target.open('wb') as output:
                shutil.copyfileobj(reader, output)
    subprocess.run([sys.executable, '-m', 'py_compile', str(work / 'patch_v0315.py')], check=True)
    subprocess.run([sys.executable, str(work / 'patch_v0315.py'), str(root)], check=True)
    for relative in ['lib/inspector_widgets315.dart', 'lib/knowledge_inspector315.dart', 'test/inspector315_test.dart']:
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(work / relative, target)
print('MGD Neuro 0.31.5 inspector overlay installed and integrity verified')
