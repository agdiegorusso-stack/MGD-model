from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
brain_path = root / 'lib' / 'plastic_language_brain_v04.dart'
world_path = root / 'lib' / 'sensory_world_v06.dart'
main_path = root / 'lib' / 'main.dart'
pubspec_path = root / 'pubspec.yaml'
test_path = root / 'test' / 'teacher_bridge_v08_test.dart'
teacher_src = Path('mgd-neuro/teacher_bridge_v08.dart')
teacher_dst = root / 'lib' / 'teacher_bridge_v08.dart'

teacher_dst.write_text(teacher_src.read_text())

b = brain_path.read_text()
anchor = """  int ensureSemanticEntity06(String label) => _entityForText(label);

"""
if anchor not in b:
    raise SystemExit('brain API anchor missing')
methods = r'''  int ensureSemanticEntity06(String label) => _entityForText(label);

  double importTeacherFact08({
    required String subject,
    required String relation,
    required String object,
    double confidence = 0.65,
    String source = 'teacher',
  }) {
    final s = subject.trim();
    final r = relation.trim();
    final o = object.trim();
    if (s.isEmpty || r.isEmpty || o.isEmpty) return 0;

    final c = confidence.clamp(0.0, 1.0).toDouble();
    final subjectId = _entityForText(s);
    final family = normalizeText(r)
        .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');

    final relationId = _ensureDevelopmentalRelation(
      'teacher-' + family,
      r,
      const [],
    );

    for (final token in lexicalTokens(r)) {
      final cue = 'lex:' + normalizeText(token);
      relations[relationId].cues[cue] =
          (relations[relationId].cues[cue] ?? 0) + 0.25 + 0.35 * c;
      _primeAttractorEdge(relationId, cue, 0.25 + 0.40 * c);
    }

    final statement = s + ' ' + r + ' ' + o;
    final reward = 0.12 + 0.42 * c;
    final report = learnSurface(statement, reward: reward * 0.45);
    final interpretation = Interpretation04(
      isQuestion: false,
      subjectId: subjectId,
      relationId: relationId,
      objectText: o,
      objectKey: canonicalObject(o),
      relationCues: lexicalTokens(r)
          .map((x) => 'lex:' + normalizeText(x))
          .toList(),
      confidence: 0.40 + 0.45 * c,
    );

    final ep = _storeEpisode(
      userText: '[teacher:' + source + '] ' + statement,
      report: report,
      interpretation: interpretation,
      reward: reward,
    );
    ep.salience = (0.18 + 0.42 * c).clamp(0.0, 0.72).toDouble();

    final flux = _putFact(
      subjectId: subjectId,
      relationId: relationId,
      objectText: o,
      reward: reward,
      episodeId: ep.id,
      synchronize: false,
    );
    relations[relationId].uses++;
    return flux;
  }

'''
b = b.replace(anchor, methods, 1)
brain_path.write_text(b)

w = world_path.read_text()
anchor = """  void bindLast({required String label, required int entityId}) {
"""
if anchor not in w:
    raise SystemExit('world API anchor missing')
methods = r'''  void importTeacherSemanticLink08(
    int entityA,
    int entityB,
    double similarity, {
    double confidence = 0.65,
  }) {
    if (entityA == entityB) return;
    final sim = similarity.clamp(0.0, 1.0).toDouble();
    final conf = confidence.clamp(0.0, 1.0).toDouble();
    if (sim < 0.05 || conf <= 0) return;

    final e = _edge(_eNode(entityA), _eNode(entityB));
    final prior = sim * (0.25 + 0.55 * conf);

    e.fast = max(
      e.fast,
      (0.10 + 0.48 * prior).clamp(0.0, 0.70).toDouble(),
    );
    e.slow = max(
      e.slow,
      (0.03 + 0.20 * prior).clamp(0.0, 0.36).toDouble(),
    );
    e.meta = max(
      e.meta,
      (0.02 + 0.12 * prior).clamp(0.0, 0.24).toDouble(),
    );
    e.elig = max(e.elig, 0.12 + 0.28 * prior);
    e.cost = min(
      e.cost,
      (1.45 - 0.78 * prior).clamp(0.28, 1.45).toDouble(),
    );
    e.uses += 1;
    e.lastUsed = step;
  }

'''
w = w.replace(anchor, methods + anchor, 1)
world_path.write_text(w)

m = main_path.read_text()
m = m.replace(
    "import 'package:image_picker/image_picker.dart';\n",
    "import 'package:image_picker/image_picker.dart';\n"
    "import 'package:file_picker/file_picker.dart';\n",
)
m = m.replace(
    "import 'sensory_world_v06.dart';\n",
    "import 'sensory_world_v06.dart';\n"
    "import 'teacher_bridge_v08.dart';\n",
)

method_anchor = """  Future<void> _think06() async {
"""
if method_anchor not in m:
    raise SystemExit('main method anchor missing')
method = r'''  Future<void> _importTeacherPack08() async {
    if (_busy || !_ready) return;
    setState(() {
      _busy = true;
      _status = 'Seleziona un knowledge pack distillato da un LLM…';
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'mgdpack'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        throw StateError('Il selettore non ha restituito i byte del file.');
      }

      final pack = TeacherPack08.fromBytes(bytes);
      final result = importTeacherPack08(_brain, _world, pack);
      await _save(
        'Teacher ' +
            result.model +
            ': ' +
            result.facts.toString() +
            ' fatti + ' +
            result.links.toString() +
            ' legami latenti importati',
      );

      if (!mounted) return;
      setState(() {
        _status = 'Distillazione da ' +
            result.model +
            ' • ' +
            result.facts.toString() +
            ' fatti • ' +
            result.links.toString() +
            ' legami • +' +
            result.entities.toString() +
            ' entità. I prior restano plastici.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Errore teacher pack: ' + e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
m = m.replace(method_anchor, method + method_anchor, 1)

old = """      _WorldPage07(brain: _brain, world: _world, last: _lastSense),
"""
new = """      _WorldPage07(
        brain: _brain,
        world: _world,
        last: _lastSense,
        busy: _busy,
        onImportTeacher: _importTeacherPack08,
      ),
"""
if old not in m:
    raise SystemExit('world page constructor anchor missing')
m = m.replace(old, new, 1)

old = """class _WorldPage07 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final SensoryResult06? last;

  const _WorldPage07({required this.brain, required this.world, required this.last});
"""
new = """class _WorldPage07 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final SensoryResult06? last;
  final bool busy;
  final Future<void> Function() onImportTeacher;

  const _WorldPage07({
    required this.brain,
    required this.world,
    required this.last,
    required this.busy,
    required this.onImportTeacher,
  });
"""
if old not in m:
    raise SystemExit('world page class anchor missing')
m = m.replace(old, new, 1)

anchor = """        const SizedBox(height: 12),
        AspectRatio(
"""
if anchor not in m:
    raise SystemExit('world page UI anchor missing')
ui = """        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Distillazione LLM → MGD',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Importa fatti e geometria semantica estratti da un '
                  'modello open-weight. Non congela il cervello: i prior '
                  'restano connessioni MGD deboli e modificabili '
                  'dall’esperienza successiva.',
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onImportTeacher,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importa knowledge pack'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AspectRatio(
"""
m = m.replace(anchor, ui, 1)

m = m.replace('MGD Neuro 0.7.1', 'MGD Neuro 0.8')
m = m.replace('MGD-Neuro 0.7.1', 'MGD-Neuro 0.8')
m = m.replace('Nuovo cervello 0.7', 'Nuovo cervello 0.8')
m = m.replace('Cervello 0.7 ripristinato', 'Cervello 0.8 ripristinato')
m = m.replace('Nuovo cervello 0.7 creato', 'Nuovo cervello 0.8 creato')
main_path.write_text(m)

p = pubspec_path.read_text()
if 'file_picker:' not in p:
    p = p.replace(
        '  record: ^7.1.1\n',
        '  record: ^7.1.1\n  file_picker: ^10.3.3\n',
    )
p = p.replace('version: 0.6.0+8', 'version: 0.8.0+12')
pubspec_path.write_text(p)

test_path.write_text(r'''import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/teacher_bridge_v08.dart';

void main() {
  test('teacher pack imports explicit facts as weak plastic priors', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'mgd-teacher-pack-v1',
          'teacher': {'model': 'test-llm', 'source': 'unit'},
          'facts': [
            {'s': 'cane', 'r': 'is_a', 'o': 'animale', 'confidence': 0.8},
            {'s': 'gatto', 'r': 'is_a', 'o': 'animale', 'confidence': 0.8},
          ],
          'links': [
            {
              'a': 'cane',
              'b': 'gatto',
              'similarity': 0.82,
              'confidence': 0.7
            },
          ],
        }),
      ),
    );

    final beforeEdges = world.stats().worldEdges;
    final result = importTeacherPack08(
      brain,
      world,
      TeacherPack08.fromBytes(bytes),
    );

    expect(result.model, 'test-llm');
    expect(result.facts, 2);
    expect(result.links, 1);
    expect(brain.entityIdForLabel06('cane'), isNotNull);
    expect(brain.entityIdForLabel06('gatto'), isNotNull);
    expect(brain.entityIdForLabel06('animale'), isNotNull);
    expect(
      brain.cognitiveFacts06().any(
        (f) => f.relation == 'is_a' && f.object.toLowerCase() == 'animale',
      ),
      isTrue,
    );
    expect(world.stats().worldEdges, greaterThan(beforeEdges));
  });

  test('teacher semantic link remains an ordinary plastic MGD edge', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final a = brain.ensureSemanticEntity06('cane');
    final b = brain.ensureSemanticEntity06('lupo');

    world.importTeacherSemanticLink08(a, b, 0.9, confidence: 0.6);
    final afterOne = world.stats().meanSlow;
    world.importTeacherSemanticLink08(a, b, 0.9, confidence: 0.6);
    final afterTwo = world.stats().meanSlow;

    expect(afterOne, greaterThan(0));
    expect(afterTwo, greaterThanOrEqualTo(afterOne));
  });

  test('alternate teacher pack field names are accepted', () {
    final pack = TeacherPack08.fromJson({
      'format': 'mgd-teacher-pack-v1',
      'model': 'teacher-x',
      'facts': [
        {
          'subject': 'Roma',
          'predicate': 'is_a',
          'object': 'città',
          'score': 0.9,
        },
      ],
      'links': [
        {'left': 'Roma', 'right': 'Milano', 'score': 0.7},
      ],
    });

    expect(pack.model, 'teacher-x');
    expect(pack.facts.single.subject, 'Roma');
    expect(pack.links.single.b, 'Milano');
  });
}
''')
