from pathlib import Path
import sys
root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()
s = s.replace("if(edges.length<20)return null;", "if(edges.length<8)return null;")
p.write_text(s)
