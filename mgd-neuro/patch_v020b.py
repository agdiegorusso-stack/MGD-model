from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()
s = s.replace("if((used[e.b]??0)>==>c.c!punct(e.b)) { if(out.length>5)break; }",
              "if ((used[e.b] ?? 0) >= 3 && !punct(e.b)) { if (out.length > 5) break; }")
s = s.replace("if((used[e.b]??0)>=3 && !punct(e.b)) { if(out.length>5)break; }",
              "if ((used[e.b] ?? 0) >= 3 && !punct(e.b)) { if (out.length > 5) break; }")
s = s.replace("wanted.contains(e.b)?.22:0.0", "wanted.contains(e.b) ? 0.22 : 0.0")
s = s.replace("punct(e.b)?.02:0", "punct(e.b) ? 0.02 : 0.0")
p.write_text(s)
