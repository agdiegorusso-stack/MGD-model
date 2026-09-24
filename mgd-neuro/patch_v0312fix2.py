from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()
old="'il','lo','la','i','gli','le','un','uno','una','di','del','della','dei','delle',"
new="'il','lo','la','i','gli','le','un','uno','una','di','del','dello','della','dei','degli','delle','dell',"
if old not in s: raise SystemExit('0.31.2 Italian article stop-word anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
print('MGD Neuro 0.31.2 Italian article normalization fixed')
