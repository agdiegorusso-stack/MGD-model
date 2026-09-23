from pathlib import Path
import sys
root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()
s = s.replace(
    "for(final e in edges.values){if(e.a == from && e.cost <= 2.35)out.add(e);}",
    "for(final e in edges.values){if(e.a == from)out.add(e);}",
)
p.write_text(s)
