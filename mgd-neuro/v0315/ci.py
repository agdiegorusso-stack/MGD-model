"""Reuse verified baseline commands and materialize plain UTF-8 inspector sources."""
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
    destination=Path('mgd-neuro-app/lib/knowledge_inspector_v0315.dart')
    source=(folder/'knowledge_inspector_v0315.dart').read_text()
    source=source.replace("['titolo','title','sourceTitle','label','topic','text','userText','hypothesis','term','id','key']", "['titolo','title','sourceTitle','label','topic','text','userText','hypothesis','term','t','id','key','valore']",1)
    source=source.replace("  return 'Elemento';", "  if(m['a']!=null && m['b']!=null)return '${m['a']} → ${m['b']}';\n  return 'Elemento';",1)
    old="""        final rows=value is List?value.map(_map315).toList():[ _map315(value) ];
        return _list(ctx,title,()=>rows);"""
    new="""        if(value is Map)return _record(ctx,{'titolo':title,..._map315(value)});
        final rows=value is List?value.map(_map315).toList():[ _map315(value) ];
        return _list(ctx,title,()=>rows);"""
    if old not in source:
        raise SystemExit('Inspector nested-map anchor missing')
    source=source.replace(old,new,1)
    destination.write_text(source)
    # SelectableText has its own Scrollable; target the outer page ListView.
    tests=(folder/'knowledge_inspector_v0315_test.dart').read_text()
    old_scroll=',200);await tester.pumpAndSettle();'
    if tests.count(old_scroll)!=2:
        raise SystemExit('Expected two widget-test scroll targets')
    tests=tests.replace(old_scroll,',200,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();')
    Path('mgd-neuro-app/test/knowledge_inspector_v0315_test.dart').write_text(tests)
    Path('mgd-neuro-app/BUILD-COMMIT.txt').write_text(subprocess.check_output(['git','rev-parse','HEAD'],text=True))
elif mode=='platform':
    original_step('Generate Android project and permissions','mgd-neuro-app')
else:
    raise SystemExit('Unknown mode: '+mode)
