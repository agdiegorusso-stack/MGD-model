from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()

# Undo the over-broad semantic interception from patch_v0252.
global_block="""    // Semantic/deictic families must win before generic predicate attractors.
    // Without this call the dedicated partner/child/name parser was dead code:
    // "chi è la mia compagna?" could collapse onto USER identity.
    final semantic = _semanticInterpretation(
      surfaces,
      speaker: speaker,
      create: create,
      isQuestion: isQuestion,
    );
    if (semantic != null) return semantic;

"""
if global_block in s:
    s=s.replace(global_block,'',1)

# Keep the original attractor interpretation untouched. After an explicit
# correction, additionally write relational roles (partner/daughter/son/etc.)
# into their dedicated semantic slot and train that attractor strongly.
anchor="""    if (interpretation.isQuestion && interpretation.subjectId != null && interpretation.relationId != null) {
      _putFact(
        subjectId: interpretation.subjectId!,
        relationId: interpretation.relationId!,
        objectText: answer,
        reward: reward,
        episodeId: ep.id,
      );
      _linkParaphraseByAnswer(
        subjectId: interpretation.subjectId!,
        relationId: interpretation.relationId!,
        objectText: answer,
      );
    } else {
      final statement = interpret(answer, speaker: 'agent', create: true);
      _learnDeclarativeFrame(answer, statement, reward: reward, episodeId: ep.id);
    }
    discoverConcepts();"""
replacement="""    if (interpretation.isQuestion && interpretation.subjectId != null && interpretation.relationId != null) {
      _putFact(
        subjectId: interpretation.subjectId!,
        relationId: interpretation.relationId!,
        objectText: answer,
        reward: reward,
        episodeId: ep.id,
      );
      _linkParaphraseByAnswer(
        subjectId: interpretation.subjectId!,
        relationId: interpretation.relationId!,
        objectText: answer,
      );
    } else {
      final statement = interpret(answer, speaker: 'agent', create: true);
      _learnDeclarativeFrame(answer, statement, reward: reward, episodeId: ep.id);
    }

    // Supplemental semantic-role binding. It never replaces the established
    // generic interpretation, so existing identity/coordination behavior stays
    // unchanged; it only prevents a role correction from being swallowed by
    // USER/name when that attractor is already stronger.
    final roleSurfaces0252 = lexicalTokens(prompt);
    final roleFamily0252 = _roleFamilyIn(roleSurfaces0252);
    if(roleFamily0252 != null){
      final roleNormalized0252 = roleSurfaces0252.map(normalizeText).toList();
      final roleIsQuestion0252 =
          normalizeText(prompt).endsWith('?') || roleNormalized0252.any(_questionWords.contains);
      final semanticRole0252 = _semanticInterpretation(
        roleSurfaces0252,
        speaker:'user',
        create:true,
        isQuestion:roleIsQuestion0252,
      );
      if(semanticRole0252 != null &&
          semanticRole0252.subjectId != null &&
          semanticRole0252.relationId != null){
        _putFact(
          subjectId:semanticRole0252.subjectId!,
          relationId:semanticRole0252.relationId!,
          objectText:answer,
          reward:max(0.95,reward),
          episodeId:ep.id,
        );
        _trainRelationAttractor(
          semanticRole0252.relationId!,
          semanticRole0252.relationCues,
          max(0.95,reward),
        );
        _linkParaphraseByAnswer(
          subjectId:semanticRole0252.subjectId!,
          relationId:semanticRole0252.relationId!,
          objectText:answer,
        );
      }
    }
    discoverConcepts();"""
if anchor not in s: raise SystemExit('teach supplemental role anchor missing')
s=s.replace(anchor,replacement,1)

# Migration of old one-shot corrections only touches relational-role prompts,
# and reinforces both the fact and its role attractor.
old="""      final surfaces=lexicalTokens(ep.userText);
      if(surfaces.isEmpty)continue;
      final ns=surfaces.map(normalizeText).toList();"""
new="""      final surfaces=lexicalTokens(ep.userText);
      if(surfaces.isEmpty || _roleFamilyIn(surfaces)==null)continue;
      final ns=surfaces.map(normalizeText).toList();"""
if old in s:
    s=s.replace(old,new,1)

old="""      _putFact(
        subjectId:i.subjectId!,
        relationId:relationId,
        objectText:answer,
        reward:1.0,
        episodeId:ep.id,
      );
      repaired++;"""
new="""      _putFact(
        subjectId:i.subjectId!,
        relationId:relationId,
        objectText:answer,
        reward:1.0,
        episodeId:ep.id,
      );
      _trainRelationAttractor(relationId,i.relationCues,1.0);
      _linkParaphraseByAnswer(
        subjectId:i.subjectId!,
        relationId:relationId,
        objectText:answer,
      );
      repaired++;"""
if old in s:
    s=s.replace(old,new,1)

p.write_text(s)
