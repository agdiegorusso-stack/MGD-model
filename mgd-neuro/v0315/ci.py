"""Reuse the verified 0.31.4 reconstruction and Android configuration commands.
The baseline workflow remains unchanged. New source files are plain UTF-8.
"""
from pathlib import Path
import subprocess
import sys
import shutil

workflow=Path('.github/workflows/build-mgd-neuro-apk.yml').read_text().splitlines()

def original_step(name: str, cwd: str | None = None) -> None:
    marker='      - name: '+name
    start=next(i for i,line in enumerate(workflow) if line==marker)
    stop=next((i for i in range(start+1,len(workflow)) if workflow[i].startswith('      - name:')),len(workflow))
    block=workflow[start:stop]
    run=next(i for i,line in enumerate(block) if line.startswith('        run:'))
    header=block[run].split('run:',1)[1].strip()
    if header=='|':
        script='\n'.join(line[10:] if line.startswith('          ') else line for line in block[run+1:])
    else:
        script=header
    subprocess.run(['bash','-e','-o','pipefail','-c',script],cwd=cwd,check=True)

mode=sys.argv[1]
if mode=='signing':
    original_step('Ensure stable Android signing key')
elif mode=='source':
    original_step('Restore 0.5 base and apply 0.5.1 repair')
    original_step('Apply 0.6 multimodal MGD overlay')
    folder=Path('mgd-neuro/v0315')
    subprocess.run([sys.executable,'-m','py_compile',str(folder/'apply.py')],check=True)
    subprocess.run([sys.executable,str(folder/'apply.py'),'mgd-neuro-app'],check=True)
    shutil.copyfile(folder/'knowledge_inspector_v0315.dart','mgd-neuro-app/lib/knowledge_inspector_v0315.dart')
    shutil.copyfile(folder/'knowledge_inspector_v0315_test.dart','mgd-neuro-app/test/knowledge_inspector_v0315_test.dart')
    Path('mgd-neuro-app/BUILD-COMMIT.txt').write_text(subprocess.check_output(['git','rev-parse','HEAD'],text=True))
elif mode=='platform':
    original_step('Generate Android project and permissions','mgd-neuro-app')
else:
    raise SystemExit('Unknown mode: '+mode)
