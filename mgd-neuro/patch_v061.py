from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
brain_path = root / 'lib' / 'plastic_language_brain_v04.dart'
main_path = root / 'lib' / 'main.dart'
test_path = root / 'test' / 'plastic_language_brain_v04_test.dart'

s = brain_path.read_text()

s = s.replace('static const int version = 6;', 'static const int version = 7;')
s = s.replace(
    "if (storedVersion != 4 && storedVersion != 5 && storedVersion != 6) return PlasticLanguageBrain04();",
    "if (storedVersion != 4 && storedVersion != 5 && storedVersion != 6 && storedVersion != 7) return PlasticLanguageBrain04();",
)

anchor = '  Interpretation04 interpret(String raw, {String speaker = \'user\', bool create = true}) {\n'
if anchor not in s:
    raise SystemExit('interpret anchor not found')

helpers = r'''  bool _hasPredicate061(List<String> tokens) {
    if (tokens.isEmpty) return false;
    if (_findVerbIndex(tokens, isQuestion: false) >= 0) return true;
    return tokens.any((t) => _semanticFamilyOf(t) == 'name');
  }

  bool _rightStartsIndependentClause061(List<String> tokens) {
    if (tokens.isEmpty) return false;
    final vi = _findVerbIndex(tokens, isQuestion: false);
    if (vi > 0) return true;

    final deictic = _resolveDeicticSubject(tokens, speaker: 'user');
    if (deictic != null) {
      if (vi >= 0) return true;
      final content = tokens.where((t) {
        final n = normalizeText(t);
        return !_grammarStops.contains(n) &&
            !_questionWords.contains(n) &&
            !{'e', 'ma', 'però', 'pero'}.contains(n);
      }).length;
      return content >= 2;
    }
    return false;
  }

  String _completeEllipticalClause061(
    List<String> previous,
    List<String> current,
  ) {
    if (current.isEmpty) return '';
    final currentNs = current.map(normalizeText).toList();
    const explicitCopulas = {'è', 'e', 'sono', 'sei', 'siamo', 'siete', 'era', 'sarà', 'sara'};
    final hasExplicitPredicate =
        currentNs.any(explicitCopulas.contains) ||
        current.any((t) => _semanticFamilyOf(t) == 'name');
    if (hasExplicitPredicate) return current.join(' ');

    final currentSubject =
        _resolveDeicticSubject(current, speaker: 'user');
    if (currentSubject == null) return current.join(' ');

    final pvi = _findVerbIndex(previous, isQuestion: false);
    if (pvi < 0 || pvi >= previous.length) return current.join(' ');
    final predicate = normalizeText(previous[pvi]);

    const copulas = {'è', 'e', 'sono', 'sei', 'era', 'sarà', 'sara'};
    if (!copulas.contains(predicate)) return current.join(' ');

    final first = normalizeText(current.first);
    final copula = switch (first) {
      'io' => 'sono',
      'tu' => 'sei',
      'lui' || 'lei' => 'è',
      'noi' => 'siamo',
      'voi' => 'siete',
      'loro' => 'sono',
      _ => 'è',
    };
    return [current.first, copula, ...current.sublist(1)].join(' ');
  }

  List<String> _splitCoordinatedEvents061(String text) {
    final tokens = lexicalTokens(text);
    if (tokens.length < 4) {
      final t = text.trim();
      return t.isEmpty ? const <String>[] : <String>[t];
    }

    final out = <String>[];
    var start = 0;
    List<String>? previousClauseTokens;

    for (var i = 1; i < tokens.length - 1; i++) {
      final n = normalizeText(tokens[i]);
      if (!{'e', 'ma', 'però', 'pero'}.contains(n)) continue;

      final left = tokens.sublist(start, i);
      final right = tokens.sublist(i + 1);
      if (!_hasPredicate061(left) ||
          !_rightStartsIndependentClause061(right)) {
        continue;
      }

      final leftText = previousClauseTokens == null
          ? left.join(' ')
          : _completeEllipticalClause061(previousClauseTokens, left);
      if (leftText.trim().isNotEmpty) out.add(leftText.trim());
      previousClauseTokens = left;
      start = i + 1;
    }

    final tail = tokens.sublist(start);
    if (tail.isNotEmpty) {
      final tailText = previousClauseTokens == null
          ? tail.join(' ')
          : _completeEllipticalClause061(previousClauseTokens, tail);
      if (tailText.trim().isNotEmpty) out.add(tailText.trim());
    }

    if (out.length <= 1) {
      final t = text.trim();
      return t.isEmpty ? const <String>[] : <String>[t];
    }
    return out;
  }

  Interpretation04? _interpretInverseRoleCopula061(
    String raw, {
    required String speaker,
    required bool create,
  }) {
    final surfaces = lexicalTokens(raw);
    if (surfaces.isEmpty) return null;
    final ns = surfaces.map(normalizeText).toList();
    final isQuestion =
        normalizeText(raw).endsWith('?') || ns.any(_questionWords.contains);
    if (isQuestion) return null;

    final roleFamily = _roleFamilyIn(surfaces);
    if (roleFamily == null) return null;

    var copulaIndex = -1;
    for (var i = 0; i < ns.length; i++) {
      if ({'è', 'e', 'sono', 'sei', 'siamo', 'siete', 'era', 'sarà', 'sara'}
          .contains(ns[i])) {
        copulaIndex = i;
        break;
      }
    }
    if (copulaIndex <= 0) return null;

    final roleIndex =
        surfaces.indexWhere((t) => _semanticFamilyOf(t) == roleFamily);
    if (roleIndex <= copulaIndex) return null;

    final owner =
        _resolveDeicticSubject(surfaces.sublist(copulaIndex + 1), speaker: speaker);
    if (owner == null) return null;

    final before = surfaces
        .sublist(0, copulaIndex)
        .where((t) => !_grammarStops.contains(normalizeText(t)))
        .toList();
    if (before.isEmpty) return null;
    final objectText = _joinObject(before).trim();
    if (objectText.isEmpty) return null;

    var relationRaw = _relationKeyToId['latent:' + roleFamily] ?? -1;
    if (relationRaw < 0) {
      relationRaw = create
          ? _ensureSemanticRelation(roleFamily, extraCues: surfaces)
          : (_relationKeyToId['sem:' + roleFamily] ?? -1);
    }
    if (relationRaw < 0) return null;

    return Interpretation04(
      isQuestion: false,
      subjectId: owner,
      relationId: _canonicalRelation(relationRaw),
      objectText: objectText,
      objectKey: canonicalObject(objectText),
      relationCues: ['sem:' + roleFamily],
      confidence: 0.97,
    );
  }

  Interpretation04? _interpretCopularType061(
    String raw, {
    required String speaker,
    required bool create,
  }) {
    final surfaces = lexicalTokens(raw);
    if (surfaces.isEmpty) return null;
    final ns = surfaces.map(normalizeText).toList();
    final isQuestion =
        normalizeText(raw).endsWith('?') || ns.any(_questionWords.contains);
    if (isQuestion) return null;

    if (_roleFamilyIn(surfaces) != null) return null;
    if (surfaces.any((t) => _semanticFamilyOf(t) == 'name')) return null;

    var copulaIndex = -1;
    for (var i = 0; i < ns.length; i++) {
      if ({'è', 'e', 'sono', 'sei', 'siamo', 'siete', 'era', 'sarà', 'sara'}
          .contains(ns[i])) {
        copulaIndex = i;
        break;
      }
    }
    if (copulaIndex < 0 || copulaIndex + 1 >= surfaces.length) return null;

    var subject = _resolveDeicticSubject(surfaces, speaker: speaker);
    if (subject == null && copulaIndex > 0) {
      final before = surfaces
          .sublist(0, copulaIndex)
          .where((t) => !_grammarStops.contains(normalizeText(t)))
          .toList();
      if (before.isNotEmpty) {
        final explicitSubject = before.join(' ');
        subject =
            create ? _entityForText(explicitSubject) : _findEntity(explicitSubject);
      }
    }
    if (subject == null) return null;

    var tail = surfaces.sublist(copulaIndex + 1);
    while (tail.isNotEmpty &&
        {'il', 'lo', 'la', 'i', 'gli', 'le'}
            .contains(normalizeText(tail.first))) {
      tail = tail.sublist(1);
    }
    if (tail.isEmpty) return null;

    final objectText = _joinObject(tail).trim();
    if (objectText.isEmpty) return null;
    final first = normalizeText(tail.first);

    final known = _findEntity(objectText);
    final properLike = tail.every((t) {
      if (t.isEmpty) return false;
      final c = t.codeUnitAt(0);
      return c >= 65 && c <= 90;
    });
    final classLike = {'un', 'uno', 'una'}.contains(first) ||
        (!properLike && known == null && tail.length >= 1);
    if (!classLike) return null;

    final relationRaw = create
        ? _ensureDevelopmentalRelation(
            'generic-is',
            'è',
            [raw],
          )
        : (_relationKeyToId['latent:generic-is'] ?? -1);
    if (relationRaw < 0) return null;
    final relationId = _canonicalRelation(relationRaw);

    return Interpretation04(
      isQuestion: false,
      subjectId: subject,
      relationId: relationId,
      objectText: objectText,
      objectKey: canonicalObject(objectText),
      relationCues: const ['frame:copular-type'],
      confidence: 0.96,
    );
  }

'''
s = s.replace(anchor, helpers + anchor, 1)

old = """    if (surfaces.isEmpty) {
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

    var subject = _resolveDeicticSubject(surfaces, speaker: speaker);
"""
new = """    if (surfaces.isEmpty) {
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

    final inverseRole = _interpretInverseRoleCopula061(
      raw,
      speaker: speaker,
      create: create,
    );
    if (inverseRole != null) return inverseRole;

    final copularType = _interpretCopularType061(
      raw,
      speaker: speaker,
      create: create,
    );
    if (copularType != null) return copularType;

    var subject = _resolveDeicticSubject(surfaces, speaker: speaker);
"""
if old not in s:
    raise SystemExit('interpret insertion block not found')
s = s.replace(old, new, 1)

old = """  LearningReport04 learnEvent(String text, {double reward = 0.45}) {
    final interpretation = interpret(text, speaker: 'user', create: true);
    final report = learnSurface(text, reward: reward);
    if (interpretation.relationId != null) {
      _trainRelationAttractor(interpretation.relationId!, interpretation.relationCues, reward);
    }
    final ep = _storeEpisode(userText: text, report: report, interpretation: interpretation, reward: reward);
    _learnDeclarativeFrame(text, interpretation, reward: reward, episodeId: ep.id);
    return report;
  }
"""
new = """  LearningReport04 _learnSingleEvent061(
    String text, {
    double reward = 0.45,
  }) {
    final interpretation = interpret(text, speaker: 'user', create: true);
    final report = learnSurface(text, reward: reward);
    if (interpretation.relationId != null) {
      _trainRelationAttractor(
        interpretation.relationId!,
        interpretation.relationCues,
        reward,
      );
    }
    final ep = _storeEpisode(
      userText: text,
      report: report,
      interpretation: interpretation,
      reward: reward,
    );
    _learnDeclarativeFrame(
      text,
      interpretation,
      reward: reward,
      episodeId: ep.id,
    );
    return report;
  }

  LearningReport04 learnEvent(String text, {double reward = 0.45}) {
    final events = _splitCoordinatedEvents061(text);
    if (events.length <= 1) {
      return _learnSingleEvent061(text, reward: reward);
    }

    var tokens = 0;
    var newTokens = 0;
    var novelty = 0.0;
    var error = 0.0;
    var flux = 0.0;
    var weight = 0;

    for (final event in events) {
      final r = _learnSingleEvent061(event, reward: reward);
      final w = max(1, r.tokens);
      tokens += r.tokens;
      newTokens += r.newTokens;
      novelty += r.novelty * w;
      error += r.predictionError * w;
      flux += r.flux * w;
      weight += w;
    }
    discoverConcepts();

    return LearningReport04(
      tokens: tokens,
      newTokens: newTokens,
      novelty: weight == 0 ? 0 : novelty / weight,
      predictionError: weight == 0 ? 0 : error / weight,
      flux: weight == 0 ? 0 : flux / weight,
    );
  }
"""
if old not in s:
    raise SystemExit('learnEvent block not found')
s = s.replace(old, new, 1)

respond_anchor = """  String respond(String prompt) {
    // A question is evidence about what the user wants, not evidence that a
"""
if respond_anchor not in s:
    raise SystemExit('respond anchor not found')
respond_new = """  String respond(String prompt) {
    final compoundEvents = _splitCoordinatedEvents061(prompt);
    final promptTokens = lexicalTokens(prompt).map(normalizeText).toList();
    final promptIsQuestion = normalizeText(prompt).endsWith('?') ||
        promptTokens.any(_questionWords.contains);
    if (!promptIsQuestion && compoundEvents.length > 1) {
      learnEvent(prompt, reward: 0.45);
      return 'Ho integrato ' +
          compoundEvents.length.toString() +
          ' eventi distinti.';
    }

    // A question is evidence about what the user wants, not evidence that a
"""
s = s.replace(respond_anchor, respond_new, 1)

discover_anchor = '  void discoverConcepts() {\n'
if discover_anchor not in s:
    raise SystemExit('discoverConcepts anchor not found')

repair = r'''  void _repairCoordinatedMemory061() {
    final affected = <int, List<String>>{};
    for (final ep in episodes) {
      if (ep.wasQuestion) continue;
      final parts = _splitCoordinatedEvents061(ep.userText);
      if (parts.length > 1) affected[ep.id] = parts;
    }
    if (affected.isEmpty) return;

    final ids = affected.keys.toSet();
    for (final slot in slots.values) {
      slot.candidates.removeWhere((_, candidate) {
        return candidate.sourceEpisodes.any(ids.contains);
      });
    }
    slots.removeWhere((_, slot) => slot.candidates.isEmpty);

    for (final ep in episodes.where((e) => affected.containsKey(e.id))) {
      final reward = max(0.45, ep.reward);
      for (final event in affected[ep.id]!) {
        final i = interpret(event, speaker: 'user', create: true);
        final report = learnSurface(event, reward: reward);
        if (i.relationId != null) {
          _trainRelationAttractor(i.relationId!, i.relationCues, reward);
        }
        _learnDeclarativeFrame(
          event,
          i,
          reward: reward,
          episodeId: ep.id,
        );
        ep.novelty = max(ep.novelty, report.novelty);
        ep.predictionError = min(ep.predictionError, report.predictionError);
      }
    }
  }

'''
s = s.replace(discover_anchor, repair + discover_anchor, 1)

old = """      b._developmentalPriorsInstalled = false;
      b._installDevelopmentalPriors();
    }
    b.discoverConcepts();
"""
new = """      b._developmentalPriorsInstalled = false;
      b._installDevelopmentalPriors();
      b._repairCoordinatedMemory061();
    }
    b.discoverConcepts();
"""
if old not in s:
    raise SystemExit('migration repair anchor not found')
s = s.replace(old, new, 1)

brain_path.write_text(s)

m = main_path.read_text()
m = m.replace('MGD Neuro 0.6', 'MGD Neuro 0.6.1')
m = m.replace('MGD-Neuro 0.6', 'MGD-Neuro 0.6.1')
main_path.write_text(m)

t = test_path.read_text()
if "coordinated clauses become separate semantic events" not in t:
    tests = r'''

  test('coordinated clauses become separate semantic events', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mi chiamo Diego.');
    b.learnEvent('Tu ti chiami Jarvis.');
    b.learnEvent('io sono un essere umano e tu una macchina');

    expect(b.respond('io come mi chiamo?').toLowerCase(), contains('diego'));
    expect(b.respond('tu chi sei?').toLowerCase(), contains('jarvis'));

    final generic = b.relations.indexWhere((r) => r.key == 'latent:generic-is');
    expect(generic, greaterThanOrEqualTo(0));

    final userKey = b.userId.toString() + '::' + generic.toString();
    final selfKey = b.selfId.toString() + '::' + generic.toString();
    final userSlot = b.slots[userKey];
    final selfSlot = b.slots[selfKey];
    expect(userSlot?.winner?.display.toLowerCase(), contains('essere umano'));
    expect(selfSlot?.winner?.display.toLowerCase(), contains('macchina'));

    final allObjects = b.slots.values
        .expand((slot) => slot.candidates.values)
        .map((c) => c.display.toLowerCase())
        .toList();
    expect(allObjects.any((x) => x.contains('e tu una macchina')), isFalse);
  });

  test('coordination handles two explicit subjects', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Cloe è mia figlia e Dante è mio figlio.');

    final daughter = b.respond('chi è mia figlia?').toLowerCase();
    final son = b.respond('chi è mio figlio?').toLowerCase();
    expect(daughter, contains('cloe'));
    expect(daughter, isNot(contains('dante')));
    expect(son, contains('dante'));
    expect(son, isNot(contains('cloe')));
  });

  test('coordination does not split a simple multi-valued object', () {
    final b = PlasticLanguageBrain04();
    final before = b.stats().episodes;
    b.learnEvent('i miei figli sono Cloe e Dante');
    final after = b.stats().episodes;
    expect(after - before, 1);
  });
'''
    idx = t.rfind('\n}')
    t = t[:idx] + tests + t[idx:]
test_path.write_text(t)
