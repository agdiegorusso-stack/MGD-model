from pathlib import Path
import sys
root=Path(sys.argv[1])

# Fast teacher import + remove old synthetic teacher episodes.
p=root/'lib'/'plastic_language_brain_v04.dart'; s=p.read_text()
anchor="""  double importTeacherFact08({
    required String subject,"""
method=r'''  double importTeacherFactFast26({
    required String subject,
    required String relation,
    required String object,
    double confidence = 0.65,
    String source = 'teacher',
  }) {
    final s=subject.trim(), r=relation.trim(), o=object.trim();
    if(s.isEmpty||r.isEmpty||o.isEmpty)return 0;
    final c=confidence.clamp(0.0,1.0).toDouble();
    final subjectId=_entityForText(s);
    final relationId=_teacherRelationId082(r);
    for(final token in lexicalTokens(r)){
      final cue='lex:${normalizeText(token)}';
      relations[relationId].cues[cue]=(relations[relationId].cues[cue]??0)+0.18+0.28*c;
      _primeAttractorEdge(relationId,cue,0.18+0.32*c);
    }
    final reward=0.12+0.42*c;
    final flux=_putFact(subjectId:subjectId,relationId:relationId,objectText:o,reward:reward,episodeId:null,synchronize:false);
    relations[relationId].uses++;
    return flux;
  }

  int compactSyntheticTeacherEpisodes26(){
    final before=episodes.length;
    episodes.removeWhere((e)=>e.userText.startsWith('[teacher:'));
    return before-episodes.length;
  }

'''
if anchor not in s: raise SystemExit('teacher fast method anchor missing')
s=s.replace(anchor,method+anchor,1)
p.write_text(s)

p=root/'lib'/'teacher_bridge_v08.dart'; s=p.read_text()
s=s.replace('brain.importTeacherFact08(','brain.importTeacherFactFast26(',1)
start=s.index('TeacherImportResult08 importTeacherPack08(')
part=s[start:]
part=part.replace('brain.importTeacherFact08(','brain.importTeacherFactFast26(')
s=s[:start]+part
s=s.replace('world.think(brain, cycles: 36, seedText: pack.model);','world.think(brain, cycles: 10, seedText: pack.model, stopFlux: 0.006);',1)
p.write_text(s)

p=root/'lib'/'main.dart'; s=p.read_text()
old="""      if (mounted) setState(() => _status = 'Carico memoria linguistica…');
      final loaded = await _persistence.load();
      if (mounted) setState(() => _status = 'Carico mondo sensoriale…');
      final world = await _worldPersistence.load();
      if (mounted) setState(() => _status = 'Carico ricerca e provenienza…');
      final research = await _researchPersistence.load();
      if (mounted) setState(() => _status = 'Carico geometria linguistica MGD…');
      final language = await _languagePersistence20.load();

      _brain = loaded?.brain ?? PlasticLanguageBrain04();
      final repairedSemanticCorrections252 = _brain.repairSemanticCorrections0252();"""
new="""      if (mounted) setState(() => _status = 'Carico GraphStore MGD 0.26…');
      final loadedFuture=_persistence.load();
      final worldFuture=_worldPersistence.load();
      final researchFuture=_researchPersistence.load();
      final languageFuture=_languagePersistence20.load();
      final loaded=await loadedFuture;
      final world=await worldFuture;
      final research=await researchFuture;
      final language=await languageFuture;

      _brain = loaded?.brain ?? PlasticLanguageBrain04();
      final compactedTeacherEpisodes26=_brain.compactSyntheticTeacherEpisodes26();
      final repairedSemanticCorrections252 = loaded?.migrated == true ? _brain.repairSemanticCorrections0252() : 0;"""
if old not in s: raise SystemExit('main boot load block missing')
s=s.replace(old,new,1)
old="""      if(repairedSemanticCorrections252>0){
        unawaited(_persistence.save(_brain));
      }"""
new="""      if(repairedSemanticCorrections252>0 || compactedTeacherEpisodes26>0){
        unawaited(_persistence.save(_brain));
      }"""
if old not in s: raise SystemExit('main repair save missing')
s=s.replace(old,new,1)
old="""    await _researchPersistence.clear();
    setState(() {"""
new="""    await _researchPersistence.clear();
    await _languagePersistence20.clear();
    setState(() {"""
if old not in s: raise SystemExit('reset language anchor missing')
s=s.replace(old,new,1)
old="""      _researchMemory = ResearchMemory11();
      _messages.clear();"""
new="""      _researchMemory = ResearchMemory11();
      _language20 = MgdLanguage20();
      _messages.clear();"""
if old not in s: raise SystemExit('reset language object anchor missing')
s=s.replace(old,new,1)
s=s.replace('MGD Neuro 0.25.2','MGD Neuro 0.26')
s=s.replace('Cervello 0.20 ripristinato','GraphStore MGD 0.26 ripristinato')
s=s.replace('Nuovo cervello 0.20','Nuovo cervello 0.26')
p.write_text(s)

p=root/'pubspec.yaml'; s=p.read_text().replace('version: 0.25.2+40','version: 0.26.0+41'); p.write_text(s)
