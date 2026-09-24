from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()
old="'a','al','alla','in','nel','nella','con','per','da','the','a','an','of','to','in',"
new="'a','al','alla','in','nel','nella','con','per','da','the','an','of','to',"
if old not in s: raise SystemExit('0.31.1 duplicate stop-word anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
print('MGD Neuro 0.31.1 stop-word set fixed')
