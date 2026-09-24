from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'plastic_language_brain_v04.dart'
s = p.read_text()
old = "'è','e','sono','sei','era','essere','ha','ho','hai','hanno'"
new = "'è','sono','sei','era','essere','ha','ho','hai','hanno'"
if old not in s:
    raise SystemExit('0.28 duplicate stop-word anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)
print('MGD Neuro 0.28 duplicate stop-word fix applied')
