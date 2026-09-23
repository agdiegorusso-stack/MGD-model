from pathlib import Path
import sys
root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()
needle = "class MgdLanguage20 {\n  static const double"
if needle not in s:
    raise SystemExit('MgdLanguage20 class anchor missing')
s = s.replace(needle, "class MgdLanguage20 {\n  MgdLanguage20();\n\n  static const double", 1)
p.write_text(s)
