from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
main = root / 'lib' / 'main.dart'
pubspec = root / 'pubspec.yaml'

m = main.read_text()
m = m.replace('MGD Neuro 0.12', 'MGD Neuro 0.12.1')
m = m.replace('MGD-Neuro 0.12', 'MGD-Neuro 0.12.1')
m = m.replace('Nuovo cervello 0.12', 'Nuovo cervello 0.12.1')
m = m.replace('Cervello 0.12 ripristinato', 'Cervello 0.12.1 ripristinato')
main.write_text(m)

p = pubspec.read_text()
p = p.replace('version: 0.12.0+18', 'version: 0.12.1+19')
pubspec.write_text(p)
