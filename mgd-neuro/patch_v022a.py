from pathlib import Path
import sys

root=Path(sys.argv[1])
p=root/'lib'/'corpus_semantic_bridge_v022.dart'
s=p.read_text()
old="RegExp(r'^[\\'’]+')"
new='RegExp(r"^[\'’]+")'
if old not in s:
    raise SystemExit('apostrophe regex anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
