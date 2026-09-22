from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
main = root / 'lib' / 'main.dart'
pubspec = root / 'pubspec.yaml'

m = main.read_text()
m = m.replace('MGD Neuro 0.14', 'MGD Neuro 0.15')
m = m.replace('MGD-Neuro 0.14', 'MGD-Neuro 0.15')
m = m.replace('Nuovo cervello 0.14', 'Nuovo cervello 0.15')
m = m.replace('Cervello 0.14 ripristinato', 'Cervello 0.15 ripristinato')
main.write_text(m)

p = pubspec.read_text()
lines = p.splitlines()
for i, line in enumerate(lines):
    if line.startswith('version:'):
        lines[i] = 'version: 0.15.0+22'
        break
else:
    raise SystemExit('pubspec version missing')
pubspec.write_text('\n'.join(lines) + '\n')
