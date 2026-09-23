from pathlib import Path
import sys
root=Path(sys.argv[1])

# Fix semantic-role questions/corrections: partner/daughter/etc. parser existed
# but was never called by interpret(), so "chi è la mia compagna?" could fall
# back to a generic/name attractor and retrieve USER->name ("Diego").
p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()

anchor="""    if (surfaces.isEmpty) {
      return const Interpretation04(
        isQuestion: false,
        subjectId: null,
        relationId: null,
        objectText: null,
        objectKey: null,
        relationCues: [],
        confidence: 0,
      );
    }

    final closedPredicate082 = _interpretClosedPredicateQuestion082("""
replacement="""    if (surfaces.isEmpty) {
      return const Interpretation04(
        isQuestion: false,
        subjectId: null,
        relationId: null,
        objectText: null,
        objectKey: null,
        relationCues: [],
        confidence: 0,
      );
    }

    // Semantic/deictic families must win before generic predicate attractors.
    // Without this call the dedicated partner/child/name parser was dead code:
    // "chi è la mia compagna?" could collapse onto USER identity.
    final semantic = _semanticInterpretation(
      surfaces,
      speaker: speaker,
      create: create,
      isQuestion: isQuestion,
    );
    if (semantic != null) return semantic;

    final closedPredicate082 = _interpretClosedPredicateQuestion082("""
if anchor not in s: raise SystemExit('interpret semantic insertion anchor missing')
s=s.replace(anchor,replacement,1)

insert_anchor="""  void reinforcePair(String prompt, String response, bool positive) {"""
method=r'''  int repairSemanticCorrections0252(){
    var repaired=0;
    for(final ep in episodes){
      final answer=ep.agentText?.trim()??'';
      if(answer.isEmpty || ep.reward<0.95)continue;
      final surfaces=lexicalTokens(ep.userText);
      if(surfaces.isEmpty)continue;
      final ns=surfaces.map(normalizeText).toList();
      final isQuestion=normalizeText(ep.userText).endsWith('?')||ns.any(_questionWords.contains);
      if(!isQuestion)continue;
      final i=_semanticInterpretation(
        surfaces,
        speaker:'user',
        create:true,
        isQuestion:true,
      );
      if(i==null||i.subjectId==null||i.relationId==null)continue;
      final relationId=_canonicalRelation(i.relationId!);
      if(relationId<0||relationId>=relations.length)continue;
      if(!relations[relationId].key.startsWith('sem:'))continue;

      final key=canonicalObject(answer);
      final slot=slots['${i.subjectId}::$relationId'];
      final existing=slot?.candidates[key];
      if(existing!=null && existing.confidence>=0.85)continue;

      _putFact(
        subjectId:i.subjectId!,
        relationId:relationId,
        objectText:answer,
        reward:1.0,
        episodeId:ep.id,
      );
      repaired++;
    }
    return repaired;
  }

'''
if insert_anchor not in s: raise SystemExit('repair insertion anchor missing')
s=s.replace(insert_anchor,method+insert_anchor,1)
p.write_text(s)

p=root/'lib'/'main.dart'
s=p.read_text()
anchor="""      _brain = loaded?.brain ?? PlasticLanguageBrain04();\n      _world = world ?? MgdWorld06();"""
replacement="""      _brain = loaded?.brain ?? PlasticLanguageBrain04();\n      final repairedSemanticCorrections252 = _brain.repairSemanticCorrections0252();\n      _world = world ?? MgdWorld06();"""
if anchor not in s: raise SystemExit('main brain load anchor missing')
s=s.replace(anchor,replacement,1)

anchor="""      _startMindTimer19();
      if(needsConceptMigration25){"""
replacement="""      _startMindTimer19();
      if(repairedSemanticCorrections252>0){
        unawaited(_persistence.save(_brain));
      }
      if(needsConceptMigration25){"""
if anchor not in s: raise SystemExit('main repair save anchor missing')
s=s.replace(anchor,replacement,1)
s=s.replace("MGD Neuro 0.25.1","MGD Neuro 0.25.2")
p.write_text(s)

p=root/'test'/'plastic_language_brain_v04_test.dart'
s=p.read_text()
insert="""\n  test('semantic partner correction does not collapse onto user identity', () {\n    final brain = PlasticLanguageBrain04();\n    brain.teachResponse('come mi chiamo?', 'Diego', reward: 1.0);\n    brain.teachResponse('chi è la mia compagna?', 'Alessandra', reward: 1.0);\n\n    expect(brain.respond('come mi chiamo?').toLowerCase(), contains('diego'));\n    expect(brain.respond('chi è la mia compagna?').toLowerCase(), contains('alessandra'));\n  });\n"""
pos=s.rfind('}')
if pos<0: raise SystemExit('test file closing brace missing')
s=s[:pos]+insert+s[pos:]
p.write_text(s)

p=root/'pubspec.yaml'
s=p.read_text().replace('version: 0.25.1+39','version: 0.25.2+40')
p.write_text(s)
