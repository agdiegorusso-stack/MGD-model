import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/learning_bridge_v0421.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  sqfliteFfiInit();
  final yes = LearningVerification428.worlds(17).first.cases
      .firstWhere((c) => c.capability == 'application');
  test('quotes and associations cannot pass an application by containing answer words', () {
    for (final route in ['passaggi', 'associazioni']) {
      expect(LearningVerification428.grade(yes,
          VerificationAnswer428('Sì, questo è il testo. No, altro caso.', route)).passed, false);
    }
    expect(LearningVerification428.grade(yes,
        const VerificationAnswer428('Sì. No.', 'cognitivo')).passed, false);
    expect(LearningVerification428.grade(yes,
        const VerificationAnswer428('Non so. La risposta potrebbe essere sì.', 'cognitivo')).passed, false);
    expect(LearningVerification428.grade(yes,
        const VerificationAnswer428('Sì, la condizione del modello è soddisfatta.', 'cognitivo')).passed, true);
  });
  test('fact grading rejects wrong subject, negation and conflict', () {
    final q = LearningVerification428.worlds(17).first.cases.first;
    expect(LearningVerification428.grade(q, VerificationAnswer428(
        '• ${q.subject} — con fonte: ${q.relation} → ${q.object}.', 'relazioni')).passed, true);
    expect(LearningVerification428.grade(q, VerificationAnswer428(
        '• ${q.subject} — ha parte → ${q.object}.', 'fonti')).passed, true);
    for (final text in [
      '• altro — ${q.relation} → ${q.object}.',
      '• ${q.subject} — non ${q.relation} → ${q.object}.',
      '• ${q.subject} — ${q.relation} → ${q.object}. [IN CONFLITTO]',
    ]) {
      expect(LearningVerification428.grade(q, VerificationAnswer428(text, 'relazioni')).passed, false);
    }
  });
  test('unknown information requires explicit abstention', () {
    final q = LearningVerification428.worlds(17).first.cases.last;
    expect(LearningVerification428.grade(q,
        const VerificationAnswer428('Non determinabile.', 'astensione')).passed, true);
    expect(LearningVerification428.grade(q,
        const VerificationAnswer428('Le associazioni più attive sono: peso, cellula.', 'associazioni')).passed, false);
  });
  test('new seeds change identifiers and polarity with both counterfactual answers', () {
    final all = LearningVerification428.worlds(17);
    expect(all.expand((w) => w.cases).length, 28);
    expect(all.expand((w) => w.cases).map((c) => c.id).toSet().length, 28);
    expect(all.first.document.text, isNot(LearningVerification428.worlds(18).first.document.text));
    for (final world in all) {
      final cases = world.cases.where((c) => c.capability == 'conditions').toList();
      expect(cases.map((c) => c.expected).toSet(), {'si', 'no'});
      final expectsPresent = world.document.text.contains('è presente.');
      expect(cases.first.expected, expectsPresent ? 'si' : 'no');
    }
  });
  test('query-only interface receives prompts; keys and feedback are never taught', () async {
    final cases = LearningVerification428.worlds(7).first.cases;
    final trace = <String>[];
    final r = await LearningVerification428.run(mode: 'controlled', seed: 7,
      cases: cases, query: (prompt) async {
        trace.add('query:$prompt');
        return const VerificationAnswer428('Non determinabile.', 'astensione');
      }, read: () async { trace.add('read'); });
    expect(trace.where((e) => e.startsWith('query:')).length, cases.length * 2);
    expect(trace.indexOf('read'), cases.length);
    expect(r['beforePassed'], 1);
    expect(r['passed'], 1);
    expect(LearningVerification428.rows(r).every((r) => r['before'] is Map), true);
  });
  test('cancellation produces no partial report', () async {
    var stop = false;
    expect(() => LearningVerification428.run(mode: 'controlled', seed: 1,
      cases: LearningVerification428.worlds(1).first.cases,
      query: (_) async { stop = true; return const VerificationAnswer428('', 'astensione'); },
      read: () async { fail('Cancelled run must not teach'); }, cancelled: () => stop),
      throwsA(isA<VerificationCancelled428>()));
  });
  test('reports survive research serialization and detach caller mutations', () {
    final m = ResearchMemory11();
    final report = {'mode': 'sources', 'passed': 0, 'total': 1,
      'results': [{'passed': false, 'subject': 'Cellula', 'claimKey': 'x'}]};
    LearningVerification428.store(m, report);
    (report['results'] as List).clear();
    final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(LearningVerification428.failedSubjects(LearningVerification428.reports(restored).first), ['Cellula']);
    for (var i = 0; i < 10; i++) { LearningVerification428.store(restored, {'results': []}); }
    expect(LearningVerification428.reports(restored).length, 6);
  });
  test('actual failed subjects become due without losing readings or pause', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la cellula');
    final g = StudyGoal426.state(m)!;
    final all = StudyGoal426.items(g);
    all.first['documents'] = 2;
    all.first['attempts'] = 9;
    all.first['nextAt'] = DateTime.now().add(const Duration(hours: 8)).toIso8601String();
    g['items'] = all;
    m.state317[StudyGoal426.key] = g;
    StudyGoal426.review(m, ['Cellula']);
    expect(StudyGoal426.next(m)!.topic, 'Cellula');
    expect(StudyGoal426.items(StudyGoal426.state(m)!).first['documents'], 2);
    StudyGoal426.pause(m, true);
    StudyGoal426.review(m, ['Cellula']);
    expect(StudyGoal426.next(m), isNull);
  });
  test('source sampling excludes conflicting, qualified, unrelated and missing evidence', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la cellula');
    for (final name in ['Cellula', 'Organulo', 'Pianeta', 'Membrana cellulare']) {
      m.claims[name] = ResearchClaim11(key: name, subject: name,
        relation: 'contiene', object: 'oggetto', confidence: .8,
        conflict: name == 'Organulo', status: 'documentata', lastSeenIso: '',
        evidenceIds: {name}, meta317: {'usable': true,
          if (name == 'Membrana cellulare') 'qualifiers': {'condizione': 'x'}});
      m.evidence.add(ResearchEvidence11(id: name, subject: name, relation: 'contiene',
        object: 'oggetto', provider: 'Fonte', sourceFamily: 'test', sourceTitle: name,
        sourceUrl: 'local://$name', excerpt: '$name contiene oggetto.',
        trust: .8, retrievedAtIso: ''));
    }
    final cases = LearningVerification428.sourceCases(m, 12);
    expect(cases.length, 2);
    expect(cases.every((c) => c.subject == 'Cellula'), true);
  });
  test('production reader and responder run in isolated stores without answer leakage', () async {
    final reader = await VerificationReader428.open(factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path);
    final worlds = LearningVerification428.worlds(428);
    LearningBridge421.observe = (_, __) async { fail('Global memory bridge must not be used'); };
    try {
      final before = await reader.core.store.stats();
      await reader.answer(worlds.first.cases.first.prompt);
      expect(await reader.core.store.stats(), before);
      final report = await LearningVerification428.run(mode: 'controlled', seed: 428,
        cases: worlds.expand((w) => w.cases).toList(), query: reader.answer,
        read: () => reader.read(worlds.map((w) => w.document).toList()));
      expect(report['total'], 28);
      expect(SourceMemory323.stats(reader.memory)['passages'], greaterThan(0));
      expect(reader.memory.narrativeEpisodes, isNotEmpty);
      final memory = jsonEncode(reader.memory.toJson());
      final coreStats = await reader.core.store.stats();
      for (final q in worlds.first.cases) { await reader.answer(q.prompt); }
      expect(jsonEncode(reader.memory.toJson()), memory);
      expect(await reader.core.store.stats(), coreStats);
      // Persist an honest, inspectable engine result; no success threshold is
      // hard-coded because evaluator correctness is distinct from competence.
      final output = Directory('tool/reports');
      await output.create(recursive: true);
      await File('${output.path}/learning-verification-0.42.8.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    } finally {
      LearningBridge421.observe = null;
      final path = reader.directory.path;
      await reader.close();
      expect(Directory(path).existsSync(), false);
    }
  });
}
