from pathlib import Path
import sys
root=Path(sys.argv[1])

# 1) Cache neighbourhoods during crystallization: the 0.25 implementation
# recomputed/sorted the same neighbourhood inside the O(N^2) pair loop.
p=root/'lib'/'cognitive_induction_v024.dart'
s=p.read_text()
old="""    final terms=candidates.take(420).map((x)=>x.term).toList();
    final used=<String>{};
    final found=<String,EmergentConcept24>{};"""
new="""    final terms=candidates.take(420).map((x)=>x.term).toList();
    // Build each local neighbourhood exactly once. With ~1,800 active terms
    // the previous implementation could sort neighbour lists hundreds of
    // thousands of times during startup.
    final neighborCache=<String,Set<String>>{
      for(final t in terms) t:_topNeighbors(t,memory),
    };
    final used=<String>{};
    final found=<String,EmergentConcept24>{};"""
if old not in s: raise SystemExit('terms cache anchor missing')
s=s.replace(old,new,1)
s=s.replace("final na=_topNeighbors(a,memory);","final na=neighborCache[a]??<String>{};",1)
s=s.replace("final nb=_topNeighbors(b,memory);","final nb=neighborCache[b]??<String>{};",1)
s=s.replace("var common=_topNeighbors(group.first,memory);","var common=Set<String>.of(neighborCache[group.first]??<String>{});",1)
s=s.replace("for(final g in group.skip(1))common=common.intersection(_topNeighbors(g,memory));","for(final g in group.skip(1))common=common.intersection(neighborCache[g]??<String>{});",1)
p.write_text(s)

# 2) Recrystallization is a migration, not something to repeat on every boot.
p=root/'lib'/'main.dart'
s=p.read_text()
old="""      _researchMemory = research ?? ResearchMemory11();
      if(_researchMemory.termMemory.isNotEmpty)CognitiveInduction24.recrystallize(_researchMemory);
      _language20 = language ?? MgdLanguage20();"""
new="""      _researchMemory = research ?? ResearchMemory11();
      final needsConceptMigration25 =
          _researchMemory.termMemory.isNotEmpty &&
          (_researchMemory.emergentConcepts.isEmpty ||
           _researchMemory.emergentConcepts.values.any((c)=>c.quality<=0));
      if(needsConceptMigration25){
        if(mounted)setState(()=>_status='Migro concetti MGD 0.25…');
        CognitiveInduction24.recrystallize(_researchMemory);
      }
      _language20 = language ?? MgdLanguage20();"""
if old not in s: raise SystemExit('boot recrystallization anchor missing')
s=s.replace(old,new,1)

old="""      _startMindTimer19();
      if (loaded?.migrated == true) {
        unawaited(_legacyMaintenance19());
      }"""
new="""      _startMindTimer19();
      if(needsConceptMigration25){
        // Persist the migrated quality/crystallization metadata so the next
        // launch can use it directly without rebuilding the concept graph.
        unawaited(_researchPersistence.save(_researchMemory));
      }
      if (loaded?.migrated == true) {
        unawaited(_legacyMaintenance19());
      }"""
if old not in s: raise SystemExit('boot persistence anchor missing')
s=s.replace(old,new,1)
s=s.replace("MGD Neuro 0.25","MGD Neuro 0.25.1")
p.write_text(s)

p=root/'pubspec.yaml'
s=p.read_text().replace('version: 0.25.0+38','version: 0.25.1+39')
p.write_text(s)
