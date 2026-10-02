#!/usr/bin/env python3
"""Materialize the reviewed overlay; fail on corruption or concurrent edits.
CI commits the resulting human-readable sources before testing/building.
This file does not fetch remote code and never runs inside the Android app.
"""
import base64
import hashlib
import json
import lzma
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

EXPECTED = '9bb632b38099c915facdd157a858e21bea23950b24ad4d64432a742243c80c1a'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    here = Path(__file__).resolve().parent
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else here.parents[1] / 'mgd-neuro-app'
    parts = sorted(here.glob('overlay.xz.b64.*'))
    if len(parts) != 5:
        raise ValueError('Expected exactly five checked overlay parts')
    raw = lzma.decompress(base64.b64decode(''.join(p.read_text().strip() for p in parts), validate=True))
    if digest(raw) != EXPECTED:
        raise ValueError('Overlay SHA256 mismatch')
    payload = json.loads(raw)
    staged = {}
    with tempfile.TemporaryDirectory(prefix='mgd-materialize-') as folder:
        tmp = Path(folder)
        for entry in payload['files']:
            rel = Path(entry['path'])
            if rel.is_absolute() or '..' in rel.parts or rel.parts[0] not in {'lib', 'test', 'tool', 'integration_test', 'pubspec.yaml', 'pubspec.lock'}:
                raise ValueError(f'Unsafe source path: {rel}')
            target = root / rel
            current = digest(target.read_bytes()) if target.is_file() else None
            if current == entry['sha256']:
                print(f'Already materialized: {rel}')
                continue
            if current not in entry['allowed_old']:
                raise ValueError(f'Concurrent/unexpected contents at {rel}: {current}')
            if 'text' in entry:
                data = entry['text'].encode('utf-8')
            else:
                if not entry['patch'].startswith(f'--- {rel}\n+++ {rel}\n'):
                    raise ValueError(f'Unexpected patch header: {rel}')
                dest = tmp / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(target, dest)
                subprocess.run(['patch', '--batch', '--fuzz=0', '--silent', '-p0'], input=entry['patch'], text=True, cwd=tmp, check=True)
                data = dest.read_bytes()
            if digest(data) != entry['sha256']:
                raise ValueError(f'Materialized SHA256 mismatch: {rel}')
            staged[rel] = data
        for rel, data in staged.items():
            target = root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            pending = target.with_name(target.name + '.mgd-pending')
            pending.write_bytes(data)
            pending.replace(target)
            print(f'Materialized and verified: {rel}')
    print(f'0.35.0 overlay verified; {len(staged)} files changed')
    subprocess.run([sys.executable, str(here / 'fix_android_regressions.py'), str(root)], check=True)
    subprocess.run(['dart', 'format', str(root / 'lib/book_lab_page_v0342.dart'), str(root / 'integration_test/book_understanding_android_v0342_test.dart'), str(root / 'integration_test/runtime_android_v0319_test.dart'), str(root / 'test/legacy_book_scroll_v0350_test.dart')], check=True)

if __name__ == '__main__':
    main()
