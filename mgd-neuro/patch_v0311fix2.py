from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()
old="""  static bool _mentions0311(String sentence,String phrase,{double ratio=0.60}) {
    final need=_contentRoots0311(phrase);
    if(need.isEmpty)return false;
    final have=_contentRoots0311(sentence);
    var hits=0;
    for(final n in need){
      if(have.any((h)=>h==n || h.startsWith(n) || n.startsWith(h)))hits++;
    }
    return hits/max(1,need.length)>=ratio;
  }
"""
new="""  static bool _rootCompatible0311(String a,String b){
    if(a==b || a.startsWith(b) || b.startsWith(a))return true;
    if(a.length<5 || b.length<5)return false;
    var common=0;
    final lim=min(a.length,b.length);
    while(common<lim && a.codeUnitAt(common)==b.codeUnitAt(common))common++;
    return common>=5;
  }

  static bool _mentions0311(String sentence,String phrase,{double ratio=0.60}) {
    final need=_contentRoots0311(phrase);
    if(need.isEmpty)return false;
    final have=_contentRoots0311(sentence);
    var hits=0;
    for(final n in need){
      if(have.any((h)=>_rootCompatible0311(h,n)))hits++;
    }
    return hits/max(1,need.length)>=ratio;
  }
"""
if old not in s: raise SystemExit('0.31.1 mentions anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
print('MGD Neuro 0.31.1 lexical cognate matching fixed')
