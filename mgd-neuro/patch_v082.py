from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
brain_path = root / 'lib' / 'plastic_language_brain_v04.dart'
main_path = root / 'lib' / 'main.dart'
pubspec_path = root / 'pubspec.yaml'
test_path = root / 'test' / 'teacher_bridge_v08_test.dart'

b = brain_path.read_text()

# ---------------------------------------------------------------------------
# 0.8.2 — make imported teacher facts actually queryable in natural language.
# The 0.8 importer stored "is_a" under a separate teacher relation, while
# ordinary Italian questions use the learned copula relation ("è").  The fact
# was present in memory but the query could never reach it.
# ---------------------------------------------------------------------------
import_anchor = """  double importTeacherFact08({
"""
if import_anchor not in b:
    raise SystemExit('teacher import anchor missing')

helpers = r'''  String _teacherRelationKey082(String raw) {
    return normalizeText(raw)
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  int _teacherRelationId082(String raw) {
    final n = _teacherRelationKey082(raw);
    final compact = n.replaceAll(' ', '');

    if (compact == 'isa' ||
        n == 'is a' ||
        n == 'tipo di' ||
        n == 'classe di' ||
        n == 'è' ||
        n == 'e') {
      final id = _ensureDevelopmentalRelation(
        'generic-is',
        'è',
        const [
          'il cane è animale',
          'che cosa è il cane?',
          'cosa è il cane?',
          'il cane è un animale?',
        ],
        multiValued: true,
      );
      relations[id].multiValued = true;
      return id;
    }

    if (n == 'ha' ||
        compact == 'has' ||
        n == 'possiede' ||
        n == 'contiene parte') {
      final id = _ensureDevelopmentalRelation(
        'generic-has',
        'ha',
        const [
          'il cane ha zampe',
          'cosa ha il cane?',
          'il cane ha quattro zampe?',
        ],
        multiValued: true,
      );
      relations[id].multiValued = true;
      return id;
    }

    final family = normalizeText(raw)
        .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final readable = n.isEmpty ? raw.trim() : n;
    return _ensureDevelopmentalRelation(
      'teacher-' + family,
      readable,
      [
        'qualcosa ' + readable + ' qualcosa',
        'cosa ' + readable + ' qualcosa?',
      ],
    );
  }

  int repairTeacherFacts082() {
    var repaired = 0;
    final snapshot = relations
        .where((r) => _canonicalRelation(r.id) == r.id)
        .toList();

    for (final relation in snapshot) {
      final key = normalizeText(relation.key);
      final label = _teacherRelationKey082(relation.label);
      int? target;

      if (key.contains('teacher-is-a') ||
          label == 'is a' ||
          label == 'isa' ||
          label == 'is_a') {
        target = _teacherRelationId082('is_a');
      } else if (key.contains('teacher-ha') || label == 'ha') {
        target = _teacherRelationId082('ha');
      }

      if (target == null || target == relation.id) continue;
      _mergeRelations(target, relation.id);
      repaired++;
    }
    return repaired;
  }

  String _stripElidedArticle082(String raw) {
    final n = normalizeText(raw);
    for (final prefix in const ["l'", "un'"]) {
      if (n.startsWith(prefix) && raw.length > prefix.length) {
        return raw.substring(prefix.length);
      }
    }
    return raw;
  }

  Interpretation04? _interpretClosedPredicateQuestion082(
    String raw, {
    required String speaker,
    required bool create,
  }) {
    final surfaces = lexicalTokens(raw);
    if (surfaces.isEmpty || !normalizeText(raw).endsWith('?')) return null;

    final ns = surfaces.map(normalizeText).toList();
    var predicateIndex = -1;
    String? family;

    for (var i = 0; i < ns.length; i++) {
      final n = ns[i];
      if ({'è', 'e', 'sono', 'sei', 'era', 'sarà', 'sara'}.contains(n)) {
        predicateIndex = i;
        family = 'generic-is';
        break;
      }
      if ({'ha', 'ho', 'hai', 'hanno', 'aveva'}.contains(n)) {
        predicateIndex = i;
        family = 'generic-has';
        break;
      }
    }
    if (predicateIndex <= 0 || family == null) return null;

    final before = <String>[];
    for (final token in surfaces.sublist(0, predicateIndex)) {
      final n = normalizeText(token);
      if (_grammarStops.contains(n) ||
          _questionWords.contains(n) ||
          {'?', '.', ',', '!', ';', ':'}.contains(n)) {
        continue;
      }
      before.add(_stripElidedArticle082(token));
    }
    if (before.isEmpty) return null;

    final subjectText = before.join(' ').trim();
    final subject = create ? _entityForText(subjectText) : _findEntity(subjectText);
    if (subject == null) return null;

    final tail = <String>[];
    for (final token in surfaces.sublist(predicateIndex + 1)) {
      final n = normalizeText(token);
      if (_grammarStops.contains(n) ||
          _questionWords.contains(n) ||
          {'?', '.', ',', '!', ';', ':'}.contains(n)) {
        continue;
      }
      tail.add(_stripElidedArticle082(token));
    }
    if (tail.isEmpty) return null;

    final objectText = _joinObject(tail).trim();
    if (objectText.isEmpty) return null;

    final relationRaw = _relationKeyToId['latent:' + family] ??
        _relationKeyToId['sem:' + family];
    if (relationRaw == null) return null;

    return Interpretation04(
      isQuestion: true,
      subjectId: subject,
      relationId: _canonicalRelation(relationRaw),
      objectText: objectText,
      objectKey: canonicalObject(objectText),
      relationCues: <String>[
        family == 'generic-is' ? 'verb:ess' : 'verb:av',
        'mode:q',
      ],
      confidence: 0.99,
    );
  }

'''
b = b.replace(import_anchor, helpers + import_anchor, 1)

# Import teacher facts into the same canonical relation used by language.
old = """    final family = normalizeText(r)
        .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');

    final relationId = _ensureDevelopmentalRelation(
      'teacher-' + family,
      r,
      const [],
    );
"""
new = """    final relationId = _teacherRelationId082(r);
"""
if old not in b:
    raise SystemExit('teacher relation creation block missing')
b = b.replace(old, new, 1)

# Let yes/no copular and possession questions preserve the queried object.
interpret_anchor = """    final inverseRole = _interpretInverseRoleCopula061(
      raw,
      speaker: speaker,
      create: create,
    );
"""
interpret_new = """    final closedPredicate082 = _interpretClosedPredicateQuestion082(
      raw,
      speaker: speaker,
      create: create,
    );
    if (closedPredicate082 != null) return closedPredicate082;

    final inverseRole = _interpretInverseRoleCopula061(
      raw,
      speaker: speaker,
      create: create,
    );
"""
if interpret_anchor not in b:
    raise SystemExit('interpret insertion anchor missing')
b = b.replace(interpret_anchor, interpret_new, 1)

# If a question contains an object ("il cane è un mammifero?"), verify that
# exact candidate instead of replying with the object or falling through.
answer_anchor = """    final relationId = _canonicalRelation(slot.relationId);

    if (_relationIsMulti(relationId)) {
"""
answer_new = """    final relationId = _canonicalRelation(slot.relationId);

    if (i.objectKey != null && i.objectKey!.trim().isNotEmpty) {
      final wanted = canonicalObject(i.objectKey!);
      final exact = slot.candidates[wanted];
      if (exact != null && exact.confidence >= 0.35) {
        return 'Sì.';
      }
      // Absence from a small knowledge graph is not evidence of falsity.
      // Do not hallucinate "No": fall through to the uncertainty path.
      return null;
    }

    if (_relationIsMulti(relationId)) {
"""
if answer_anchor not in b:
    raise SystemExit('answer query anchor missing')
b = b.replace(answer_anchor, answer_new, 1)

brain_path.write_text(b)

# Boot-time migration repairs packs already imported by 0.8 / 0.8.1.
m = main_path.read_text()
boot_old = """    final repairedGroundings = _world.repairNaturalBindings071(_brain);
    final repairedIdentities = _world.repairIdentityAliases081(_brain);
    if (repairedGroundings > 0 || repairedIdentities > 0) {
"""
boot_new = """    final repairedGroundings = _world.repairNaturalBindings071(_brain);
    final repairedIdentities = _world.repairIdentityAliases081(_brain);
    final repairedTeacherFacts = _brain.repairTeacherFacts082();
    if (repairedGroundings > 0 ||
        repairedIdentities > 0 ||
        repairedTeacherFacts > 0) {
"""
if boot_old not in m:
    raise SystemExit('boot repair block missing')
m = m.replace(boot_old, boot_new, 1)
m = m.replace('MGD Neuro 0.8.1', 'MGD Neuro 0.8.2')
m = m.replace('MGD-Neuro 0.8.1', 'MGD-Neuro 0.8.2')
m = m.replace('Nuovo cervello 0.8.1', 'Nuovo cervello 0.8.2')
m = m.replace('Cervello 0.8.1 ripristinato', 'Cervello 0.8.2 ripristinato')
main_path.write_text(m)

p = pubspec_path.read_text()
p = p.replace('version: 0.8.1+13', 'version: 0.8.2+14')
pubspec_path.write_text(p)

t = test_path.read_text()
t = t.replace(
    "(f) => f.relation == 'is_a' && f.object.toLowerCase() == 'animale',",
    "(f) => f.relation == 'è' && f.object.toLowerCase() == 'animale',",
)
if "teacher is_a answers natural Italian yes-no query" not in t:
    tests = r'''

  test('teacher is_a answers natural Italian yes-no query', () {
    final brain = PlasticLanguageBrain04();
    brain.importTeacherFact08(
      subject: 'cane',
      relation: 'is_a',
      object: 'mammifero',
      confidence: 0.92,
    );

    expect(brain.respond('il cane è un mammifero?').toLowerCase(), 'sì.');
  });

  test('teacher is_a remains multi-valued taxonomy', () {
    final brain = PlasticLanguageBrain04();
    brain.importTeacherFact08(
      subject: 'cane',
      relation: 'is_a',
      object: 'animale',
      confidence: 0.92,
    );
    brain.importTeacherFact08(
      subject: 'cane',
      relation: 'is_a',
      object: 'mammifero',
      confidence: 0.92,
    );

    expect(brain.respond('il cane è un animale?').toLowerCase(), 'sì.');
    expect(brain.respond('il cane è un mammifero?').toLowerCase(), 'sì.');
    final open = brain.respond('che cosa è il cane?').toLowerCase();
    expect(open, contains('animale'));
    expect(open, contains('mammifero'));
  });

  test('teacher ha answers natural Italian yes-no query', () {
    final brain = PlasticLanguageBrain04();
    brain.importTeacherFact08(
      subject: 'uccello',
      relation: 'ha',
      object: 'piume',
      confidence: 0.92,
    );

    expect(brain.respond("l'uccello ha piume?").toLowerCase(), 'sì.');
  });
'''
    idx = t.rfind('\n}')
    if idx < 0:
        raise SystemExit('teacher test closing brace missing')
    t = t[:idx] + tests + t[idx:]
test_path.write_text(t)
