from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()
old="""    if(sid==null)return null;
    final relationNeedle=normalizeText(relation);
"""
new="""    final relationNeedle=normalizeText(relation);
"""
if old not in s: raise SystemExit('0.31 nullable subject early-return anchor missing')
s=s.replace(old,new,1)
old="""    if(rid!=null && best>=0.45){
      final composed=composeFact031(subjectId:sid,relationId:rid,objectText:object);
      if(composed!=null)return composed;
    }

    final subjectSurface=sid>=0 && sid<entities.length
        ? (_bestSurface031(entitySurfaceForms031,sid)??entities[sid].label)
        : subject.trim();
"""
new="""    if(sid!=null && rid!=null && best>=0.45){
      final composed=composeFact031(subjectId:sid,relationId:rid,objectText:object);
      if(composed!=null)return composed;
    }

    final subjectSurface=sid!=null && sid>=0 && sid<entities.length
        ? (_bestSurface031(entitySurfaceForms031,sid)??entities[sid].label)
        : subject.trim();
"""
if old not in s: raise SystemExit('0.31 nullable subject compose anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
print('MGD Neuro 0.31 nullable subject composition fallback fixed')
