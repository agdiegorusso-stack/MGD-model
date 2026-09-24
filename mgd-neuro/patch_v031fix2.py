from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()
old="""  String? composeSemantic031({required String subject,required String relation,required String object}){
    final sid=_findEntity(subject);
    if(sid==null)return null;
    final relationNeedle=normalizeText(relation);
    int? rid;
    double best=0;
"""
new="""  String? composeSemantic031({required String subject,required String relation,required String object}){
    var sid=_findEntity(subject);
    if(sid==null){
      final wanted=normalizeText(subject);
      for(final e in entitySurfaceForms031.entries){
        final hit=e.value.keys.any((surface){
          final tokens=normalizeText(surface).split(' ').where((x)=>x.isNotEmpty).toSet();
          return normalizeText(surface)==wanted || tokens.contains(wanted);
        });
        if(hit){sid=e.key;break;}
      }
    }
    if(sid==null)return null;
    final relationNeedle=normalizeText(relation);
    int? rid;
    double best=0;
    final wantedStem=_stem(relationNeedle);
    for(final e in relationSurfaceFrames031.entries){
      for(final surface in e.value.keys){
        final n=normalizeText(surface);
        final first=n.split(' ').where((x)=>x.isNotEmpty).firstOrNull;
        if(n==relationNeedle ||
            n.split(' ').contains(relationNeedle) ||
            (first!=null && _stem(first)==wantedStem)){
          rid=_canonicalRelation(e.key);
          best=0.96;
          break;
        }
      }
      if(best>=0.96)break;
    }
"""
if old not in s:
    raise SystemExit('0.31 composeSemantic anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
print('MGD Neuro 0.31 composition resolver fallback fixed')
