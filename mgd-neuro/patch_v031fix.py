from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()
old="var out='$subject $bridge $ob:'.replaceAll(RegExp(r'\\\\s+'),' ').trim();"
new="var out='$subject $bridge $obj'.replaceAll(RegExp(r'\\\\s+'),' ').trim();"
if old not in s: raise SystemExit('0.31 composition typo anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
print('MGD Neuro 0.31 composition typo fixed')
