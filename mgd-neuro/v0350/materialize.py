#!/usr/bin/env python3
"""Apply the verified final storage-isolation refinement to readable 0.35.0 source.
The main implementation and prior Android-route fixes were already materialized
in the source commit from run 37000939574. This step never downloads/runs remote
code, never touches application data, and refuses concurrent source changes.
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

EXPECTED = '13e24ad847ed45a2bec7bfb7355d0cbe55c48d4a2857e2d2fec91cc023fa7d8a'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    here = Path(__file__).resolve().parent
    root = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else here.parents[1]/'mgd-neuro-app'
    raw=lzma.decompress(base64.b64decode((here/'storage-fix.xz.b64').read_text().strip(),validate=True))
    if digest(raw)!=EXPECTED:
        raise ValueError('Storage refinement digest mismatch')
    payload=json.loads(raw)
    staged={}
    with tempfile.TemporaryDirectory(prefix='mgd-storage-fix-') as folder:
        tmp=Path(folder)
        for entry in payload['files']:
            rel=Path(entry['path'])
            if rel.is_absolute() or '..' in rel.parts or rel.parts[0] not in {'lib','test','integration_test'}:
                raise ValueError(f'Unsafe source path: {rel}')
            target=root/rel
            current=digest(target.read_bytes()) if target.is_file() else None
            if current==entry['after']:
                print(f'Already verified: {rel}')
                continue
            if current!=entry['before']:
                raise ValueError(f'Unexpected/concurrent source change: {rel}: {current}')
            if 'text' in entry:
                data=entry['text'].encode('utf-8')
            else:
                if not entry['patch'].startswith(f'--- {rel}\n+++ {rel}\n'):
                    raise ValueError(f'Unexpected patch header: {rel}')
                dest=tmp/rel
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(target,dest)
                subprocess.run(['patch','--batch','--fuzz=0','--silent','-p0'],input=entry['patch'],text=True,cwd=tmp,check=True)
                data=dest.read_bytes()
            if digest(data)!=entry['after']:
                raise ValueError(f'Refined source digest mismatch: {rel}')
            staged[rel]=data
        for rel,data in staged.items():
            target=root/rel
            target.parent.mkdir(parents=True,exist_ok=True)
            pending=target.with_name(target.name+'.mgd-pending')
            pending.write_bytes(data)
            pending.replace(target)
            print(f'Applied and verified: {rel}')
    print(f'Storage isolation verified; {len(staged)} files changed. Run all tests before release.')

if __name__=='__main__':
    main()
