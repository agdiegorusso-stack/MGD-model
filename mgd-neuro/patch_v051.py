from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
brain_path = root / 'lib' / 'plastic_language_brain_v04.dart'
persist_path = root / 'lib' / 'persistence.dart'
main_path = root / 'lib' / 'main.dart'
test_path = root / 'test' / 'plastic_language_brain_v04_test.dart'

s = brain_path.read_text()

# Carry forward the validated 0.5 compiler/runtime fixes that lived in the
# previous build pipeline rather than in the archived source tarball.
s = s.replace("'ha', 'ho', 'hai', 'hanno', 'aveva', 'hanno'", "'ha', 'ho', 'hai', 'hanno', 'aveva'")
s = s.replace("margin >= 0.045 || bestScore >= 0.72", "margin >= 0.010 || bestScore >= 0.68")
if "frame:deictic-bare" not in s:
    s = s.replace(
        "    if (feature == 'ctx:deictic') return 0.45;",
        "    if (feature == 'ctx:deictic') return 0.45;\n"
        "    if (feature == 'frame:deictic-bare') return 1.10;"
    )
    s = s.replace(
        "    if (hasDeictic || subjectId == userId || subjectId == selfId) {\n"
        "      candidates.add('ctx:deictic');\n"
        "    }\n\n"
        "    for (var i = 0; i + 1 < contentForBigrams.length; i++) {",
        "    if (hasDeictic || subjectId == userId || subjectId == selfId) {\n"
        "      candidates.add('ctx:deictic');\n"
        "      final hasLexicalRole = candidates.any((f) => f.startsWith('lex:'));\n"
        "      if (!hasLexicalRole) candidates.add('frame:deictic-bare');\n"
        "    }\n\n"
        "    for (var i = 0; i + 1 < contentForBigrams.length; i++) {"
    )

# 0.5.1 schema version: force one-time repair of states saved by 0.5/0.4.1.
s = s.replace('static const int version = 5;', 'static const int version = 6;')

# Contrastive lexical gating: concrete role words must not collapse merely
# because they share generic verbs/question frames (figlio/figlia/figli).
old = """    final usePrior = min(0.08, log(1 + relation.uses) * 0.012);\n    return (0.68 * coverage + 0.32 * specificity + usePrior)\n        .clamp(0.0, 1.0)\n        .toDouble();\n"""
new = """    final usePrior = min(0.08, log(1 + relation.uses) * 0.012);\n    var score = 0.68 * coverage + 0.32 * specificity + usePrior;\n\n    // Contrastive lexical gating. If both the input and the attractor carry\n    // concrete role words, an exact lexical match must matter more than\n    // generic question/verb context. This prevents nearby forms such as\n    // figlio / figlia / figli from collapsing into one attractor while still\n    // allowing genuinely paraphrastic relations (e.g. partner/moglie) whose\n    // prototype has learned both surface forms.\n    final inputLex = fs.where((f) => f.startsWith('lex:')).toSet();\n    final prototypeLex = relation.cues.keys\n        .where((f) => f.startsWith('lex:'))\n        .toSet();\n    if (inputLex.isNotEmpty && prototypeLex.isNotEmpty) {\n      final overlap = inputLex.intersection(prototypeLex);\n      if (overlap.isEmpty) {\n        score *= 0.24;\n      } else {\n        final lexicalAgreement = overlap.length / inputLex.length;\n        score += 0.12 * lexicalAgreement;\n      }\n    }\n\n    return score.clamp(0.0, 1.0).toDouble();\n"""
if old not in s:
    raise SystemExit('relation score anchor not found')
s = s.replace(old, new, 1)

# Questions no longer create/reinforce a semantic relation before a correct
# answer exists. This prevents repeated failed queries from teaching the wrong
# attractor to itself.
old = """  String respond(String prompt) {\n    final interpretation = interpret(prompt, speaker: 'user', create: true);\n    final report = learnSurface(prompt, reward: 0.28);\n    if (interpretation.relationId != null) {\n      _trainRelationAttractor(interpretation.relationId!, interpretation.relationCues, 0.12);\n    }\n    final ep = _storeEpisode(userText: prompt, report: report, interpretation: interpretation);\n    _learnDeclarativeFrame(prompt, interpretation, reward: 0.35, episodeId: ep.id);\n\n    String? answer;\n"""
new = """  String respond(String prompt) {\n    // A question is evidence about what the user wants, not evidence that a\n    // particular semantic relation is correct. Query existing attractors\n    // without creating/reinforcing one. Learning is reward-gated after a\n    // successful answer or an explicit correction.\n    final interpretation = interpret(prompt, speaker: 'user', create: false);\n    final report = learnSurface(prompt, reward: 0.20);\n    final ep = _storeEpisode(userText: prompt, report: report, interpretation: interpretation);\n\n    String? answer;\n"""
if old not in s:
    raise SystemExit('respond anchor not found')
s = s.replace(old, new, 1)

old = """    answer ??= _generateFromState(prompt);\n    if (answer.trim().isEmpty) {\n      answer = 'Non ho ancora una rappresentazione abbastanza stabile per rispondere. Insegnamelo o correggimi.';\n    }\n\n    ep.agentText = answer;\n    learnSurface(answer, reward: answer.startsWith('Non ho ancora') ? 0.02 : 0.14);\n    return answer;\n  }\n"""
new = """    answer ??= _generateFromState(prompt);\n    if (answer.trim().isEmpty) {\n      answer = 'Non ho ancora una rappresentazione abbastanza stabile per rispondere. Insegnamelo o correggimi.';\n    }\n\n    final successful = !answer.startsWith('Non ho ancora');\n    if (successful && interpretation.relationId != null) {\n      _trainRelationAttractor(\n        interpretation.relationId!,\n        interpretation.relationCues,\n        0.08,\n      );\n    }\n    ep.agentText = answer;\n    learnSurface(answer, reward: successful ? 0.14 : 0.0);\n    return answer;\n  }\n"""
if old not in s:
    raise SystemExit('respond tail anchor not found')
s = s.replace(old, new, 1)

# Reconstruct facts from episodic evidence during migration. Old builds could
# lose the singular son/daughter slot while the original sentence remained in
# episodic memory; the episode is the least lossy source of truth available.
anchor = '  void discoverConcepts() {\n'
if anchor not in s:
    raise SystemExit('discover concepts anchor not found')
method = """  void _rebuildSemanticFactsFromEpisodes() {\n    final snapshot = [...episodes];\n    for (final ep in snapshot) {\n      final text = ep.userText.trim();\n      if (text.isEmpty) continue;\n      final i = interpret(text, speaker: 'user', create: false);\n\n      var subjectId = i.subjectId ?? ep.subjectId;\n      int? relationId;\n\n      // Migration-only lexical recovery: old builds sometimes collapsed a\n      // singular family role into its plural slot. The raw episode still\n      // contains the role word, so use it to restore the intended family.\n      final roleFamily = _roleFamilyIn(lexicalTokens(text));\n      if (roleFamily != null) {\n        relationId = _relationKeyToId['latent:$roleFamily'] ??\n            _relationKeyToId['sem:$roleFamily'];\n      }\n\n      // Prefer the relation that the original episode was bound to when it\n      // can be mapped to a known semantic family. Old slot migration could\n      // lose the slot while leaving this episode-level binding intact.\n      if (relationId == null &&\n          ep.relationId != null &&\n          ep.relationId! >= 0 &&\n          ep.relationId! < relations.length) {\n        final oldId = _canonicalRelation(ep.relationId!);\n        final oldRelation = relations[oldId];\n        String? family;\n        if (oldRelation.key.startsWith('latent:')) {\n          final candidate = oldRelation.key.substring(7);\n          if (_semanticLabels.containsKey(candidate)) family = candidate;\n        } else if (oldRelation.key.startsWith('sem:')) {\n          final candidate = oldRelation.key.substring(4);\n          if (_semanticLabels.containsKey(candidate)) family = candidate;\n        }\n        family ??= _semanticFamilyOf(oldRelation.label);\n        if (family != null) {\n          relationId = _relationKeyToId['latent:$family'] ??\n              _relationKeyToId['sem:$family'] ??\n              oldId;\n        } else {\n          relationId = oldId;\n        }\n      }\n      relationId ??= i.relationId;\n      if (subjectId == null || relationId == null) continue;\n\n      String? objectText;\n      if (!i.isQuestion) {\n        objectText = i.objectText;\n        if ((objectText == null || objectText.trim().isEmpty) &&\n            ep.objectKey != null && ep.objectKey!.trim().isNotEmpty) {\n          objectText = ep.objectKey;\n        }\n      } else if (ep.agentText != null &&\n          ep.agentText!.trim().isNotEmpty &&\n          !ep.agentText!.startsWith('Non ho ancora')) {\n        objectText = ep.agentText;\n      }\n\n      if (objectText == null || objectText.trim().isEmpty) continue;\n      _putFact(\n        subjectId: subjectId,\n        relationId: relationId,\n        objectText: objectText,\n        reward: 0.72,\n        episodeId: ep.id,\n      );\n    }\n  }\n\n"""
s = s.replace(anchor, method + anchor, 1)

s = s.replace(
    "if (storedVersion != 4 && storedVersion != 5) return PlasticLanguageBrain04();",
    "if (storedVersion != 4 && storedVersion != 5 && storedVersion != 6) return PlasticLanguageBrain04();",
)
old = """    if (storedVersion == 4) {\n      b.repairSemanticMemory();\n    }\n    b._developmentalPriorsInstalled = false;\n    b._installDevelopmentalPriors();\n    b.discoverConcepts();\n    return b;\n"""
new = """    final needsMigration = storedVersion < version;\n    if (needsMigration) {\n      b.repairSemanticMemory();\n    }\n    b._developmentalPriorsInstalled = false;\n    b._installDevelopmentalPriors();\n    if (needsMigration) {\n      b._rebuildSemanticFactsFromEpisodes();\n      b.repairSemanticMemory();\n      // repairSemanticMemory can redirect latent relations to canonical\n      // semantic IDs. Re-prime the MGD feature edges on those final anchors.\n      b._developmentalPriorsInstalled = false;\n      b._installDevelopmentalPriors();\n    }\n    b.discoverConcepts();\n    return b;\n"""
if old not in s:
    raise SystemExit('fromJson migration anchor not found')
s = s.replace(old, new, 1)
brain_path.write_text(s)

# New state file preserves the v0.5 file as a migration source instead of
# overwriting it in place.
s = persist_path.read_text()
s = s.replace(
    "static const _fileName = 'mgd_neuro_brain_v05.json.gz';\n  static const _oldV04FileName",
    "static const _fileName = 'mgd_neuro_brain_v051.json.gz';\n  static const _oldV05FileName = 'mgd_neuro_brain_v05.json.gz';\n  static const _oldV04FileName",
)
anchor = """    try {\n      final old = await _file(_oldV04FileName);\n"""
insert = """    try {\n      final old = await _file(_oldV05FileName);\n      if (await old.exists()) {\n        final raw = utf8.decode(gzip.decode(await old.readAsBytes()));\n        final brain = PlasticLanguageBrain04.fromJson(jsonDecode(raw) as Map<String, dynamic>);\n        await save(brain);\n        return (brain: brain, migrated: true);\n      }\n    } catch (_) {\n      // Continue with v0.4 migration or a new brain.\n    }\n\n"""
if anchor not in s:
    raise SystemExit('persistence v04 anchor not found')
s = s.replace(anchor, insert + anchor, 1)
s = s.replace(
    "for (final name in [_fileName, _oldV04FileName, _oldV03FileName])",
    "for (final name in [_fileName, _oldV05FileName, _oldV04FileName, _oldV03FileName])",
)
persist_path.write_text(s)

# Visible version/status.
s = main_path.read_text()
s = s.replace('MGD Neuro 0.5', 'MGD Neuro 0.5.1')
s = s.replace('Nuovo cervello 0.5 • attrattori semantici MGD', 'Nuovo cervello 0.5.1 • attrattori semantici MGD')
s = s.replace('Memoria precedente migrata nel modello 0.5', 'Memoria precedente migrata e riparata nel modello 0.5.1')
s = s.replace('Cervello 0.5 ripristinato dal telefono', 'Cervello 0.5.1 ripristinato dal telefono')
s = s.replace('Azzerare MGD-Neuro 0.5?', 'Azzerare MGD-Neuro 0.5.1?')
s = s.replace("Text('MGD-Neuro 0.4.1'", "Text('MGD-Neuro 0.5.1'")
main_path.write_text(s)

# Regression tests that reproduce the phone failure rather than only the clean
# in-memory path.
s = test_path.read_text()
if "v0.5 corrupted child memory is repaired from episodic experience" not in s:
    insert = r'''

  test('v0.5 corrupted child memory is repaired from episodic experience', () {
    final old = PlasticLanguageBrain04();
    old.learnEvent('Mi chiamo Diego.');
    old.learnEvent('Mia figlia si chiama Cloe.');
    old.learnEvent('Mio figlio si chiama Dante.');
    final json = old.toJson();
    json['version'] = 5;

    final relations = (json['relations'] as List).cast<Map<String, dynamic>>();
    final son = relations.firstWhere((r) => r['label'] == 'figlio')['id'] as int;
    final slots = (json['slots'] as List).cast<Map<String, dynamic>>();
    slots.removeWhere((slot) => slot['relationId'] == son);

    final migrated = PlasticLanguageBrain04.fromJson(json);
    final sonAnswer = migrated.respond('come si chiama mio figlio?').toLowerCase();
    final daughterAnswer = migrated.respond('come si chiama mia figlia?').toLowerCase();
    final childrenAnswer = migrated.respond('come si chiamano i miei figli?').toLowerCase();

    expect(sonAnswer, contains('dante'));
    expect(sonAnswer, isNot(contains('cloe')));
    expect(daughterAnswer, contains('cloe'));
    expect(daughterAnswer, isNot(contains('dante')));
    expect(childrenAnswer, contains('cloe'));
    expect(childrenAnswer, contains('dante'));
  });

  test('repeated questions do not reinforce or merge a wrong relation', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mia figlia si chiama Cloe.');
    b.learnEvent('Mio figlio si chiama Dante.');

    for (var i = 0; i < 4; i++) {
      expect(b.respond('come si chiama mio figlio?').toLowerCase(), contains('dante'));
      expect(b.respond('come si chiama mia figlia?').toLowerCase(), contains('cloe'));
    }

    final son = b.respond('chi è mio figlio?').toLowerCase();
    final daughter = b.respond('chi è mia figlia?').toLowerCase();
    expect(son, contains('dante'));
    expect(son, isNot(contains('cloe')));
    expect(daughter, contains('cloe'));
    expect(daughter, isNot(contains('dante')));
  });
'''
    idx = s.rfind('\n}')
    s = s[:idx] + insert + s[idx:]
test_path.write_text(s)
