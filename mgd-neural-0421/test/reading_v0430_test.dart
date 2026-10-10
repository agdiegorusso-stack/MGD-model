import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/reading_query_v0430.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/rule_reasoning_v0429.dart';
import '../lib/prose_verification_v0430.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/web_knowledge_explorer_v11.dart';

ResearchMemory11 retained(String text) {
  final m = ResearchMemory11();
  SourceMemory323.retain(m, WebDocument11(provider: 'Test', family: 'locale:test',
      title: 'Paragrafo nuovo', url: 'local://reading/test', text: text, trust: .8));
  return m;
}

void fact(ResearchMemory11 m, String subject, String relation, String object,
    {bool conflict = false, Map<String, dynamic> extra = const {}}) {
  final id = '$subject-$relation-$object';
  m.claims[id] = ResearchClaim11(key: id, subject: subject, relation: relation,
      object: object, confidence: .8, conflict: conflict, status: 'documentata',
      lastSeenIso: '', evidenceIds: {id}, meta317: {'usable': true, ...extra});
  m.evidence.add(ResearchEvidence11(id: id, subject: subject, relation: relation,
      object: object, provider: 'Fonte originale', sourceFamily: 'test',
      sourceTitle: 'Documento $subject', sourceUrl: 'https://example.org/$id',
      excerpt: '$subject: $relation $object.', trust: .8, retrievedAtIso: ''));
}

void main() {
  sqfliteFfiInit();
  test('open descriptions retrieve documented claims across all four screenshot topics', () {
    final m = ResearchMemory11();
    final subjects = ['Metabolismo cellulare', 'Differenziazione cellulare',
      'Segnalazione cellulare', 'Membrana cellulare'];
    for (final s in subjects) { fact(m, s, 'sottoclasse di', 'Processo biologico'); }
    final before = jsonEncode(m.toJson());
    for (final s in subjects) {
      for (final q in ['Che cosa sai di $s?', 'Cosa sai su $s?', 'Spiegami $s', 'Descrivi $s']) {
        final answer = ReadingQuery430.answer(m, q)!;
        expect(answer.text, contains('$s è un tipo di Processo biologico.'));
        expect(answer.text, contains('https://example.org/'));
        expect(answer.claims.single['subject'], s);
      }
    }
    expect(ReadingQuery430.answer(m, 'Perché Membrana cellulare è attiva?'), isNull);
    expect(ReadingQuery430.answer(m, 'Che cosa sai di Sconosciuto?'), isNull);
    expect(jsonEncode(m.toJson()), before);
  });
  test('retrieval excludes conflicting, negated and qualified assertions', () {
    final m = ResearchMemory11();
    fact(m, 'Cellula', 'contiene', 'Nucleo', conflict: true);
    fact(m, 'Cellula', 'contiene', 'Parete', extra: {'negative': true});
    fact(m, 'Cellula', 'contiene', 'Cloroplasto', extra: {'qualifiers': {'tipo': 'vegetale'}});
    expect(ReadingQuery430.answer(m, 'Che cosa sai di Cellula?'), isNull);
    fact(m, 'Cellula', 'contiene', 'Membrana');
    expect(ReadingQuery430.answer(m, 'Che cosa sai di Cellula?')!.claims.length, 1);
  });
  test('open recall accepts supported alternative facts and rejects unrelated assertions', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la cellula');
    fact(m, 'Cellula', 'contiene', 'Membrana');
    fact(m, 'Cellula', 'sottoclasse di', 'Sistema biologico');
    final q = LearningVerification428.sourceCases(m, 1).firstWhere((q) => q.capability == 'recall');
    final answer = ReadingQuery430.answer(m, q.prompt)!;
    expect(LearningVerification428.grade(q, VerificationAnswer428(answer.text,
        'letture', proof: answer.proof)).passed, true);
    expect(LearningVerification428.grade(q, const VerificationAnswer428('Un nome', 'letture',
        proof: {'kind': 'retrieval', 'claims': [{'subject': 'Pianeta', 'relation': 'contiene',
          'object': 'Membrana', 'url': 'https://example.org/'}]})).passed, false);
    expect(LearningVerification428.grade(q, const VerificationAnswer428('Un nome', 'letture',
        proof: {'kind': 'retrieval', 'claims': []})).passed, false);
  });
  test('fronted conditionals, hypothetical questions and why share a sourced proof', () {
    final m = retained('Quando il contatto è chiuso, il rele è attivo. '
        'Quando il rele è attivo, la lampada è accesa.');
    for (final q in ['Se il contatto è chiuso, la lampada è accesa?',
      'Il contatto è chiuso. Perché la lampada è accesa?',
      'Che cosa succede alla lampada quando il contatto è chiuso?']) {
      final answer = RuleReasoning429.answer(m, q)!;
      expect(answer.truth, 'true', reason: q);
      expect(answer.proof!.conclusion.signedKey, '+stato(lampada|acceso)');
      expect(answer.text, contains('Quando il rele è attivo'));
      expect(answer.text, contains('ipotesi della domanda'));
    }
    expect(RuleReasoning429.answer(m, 'La lampada è accesa?')!.truth, 'unknown');
  });
  test('necessity, sufficiency and unsupported qualifiers remain distinct', () {
    final m = retained('Il sensore è attivo solo se la batteria è presente. '
        'Quando il consenso è presente, la porta è aperta e il segnale è acceso.');
    expect(RuleReasoning429.answer(m, 'La batteria è presente. Il sensore è attivo?')!.truth, 'unknown');
    expect(RuleReasoning429.answer(m, 'La batteria è assente. Il sensore è attivo?')!.truth, 'false');
    expect(RuleReasoning429.answer(m, 'Il sensore è attivo. La batteria è presente?')!.truth, 'true');
    expect(RuleReasoning429.answer(m, 'Il consenso è presente. Il segnale è acceso?')!.truth, 'true');
    final weak = retained('Quando la batteria è presente, il sensore potrebbe essere attivo.');
    expect(RuleReasoning429.answer(weak, 'La batteria è presente. Il sensore è attivo?')!.truth, 'unknown');
  });
  test('a reported fact does not acquire an invented causal explanation', () {
    final m = retained('La lampada è accesa.');
    expect(RuleReasoning429.answer(m, 'Perché la lampada è accesa?')!.truth, 'unknown');
  });
  test('unseen reflexive predicates transfer across distinct paragraphs and counterconditions', () {
    for (final scenario in [
      ('telo', 'vento', 'tende', 'Quando il vento è presente, il telo si tende.'),
      ('fiore', 'luce', 'apre', 'Quando la luce è presente, il fiore si apre.'),
    ]) {
      final m = retained(scenario.$4);
      final before = jsonEncode(m.toJson());
      final yes = RuleReasoning429.answer(m, 'Se ${scenario.$2} è presente, ${scenario.$1} si ${scenario.$3}?')!;
      expect(yes.truth, 'true');
      expect(yes.proof!.conclusion.predicate, scenario.$3);
      expect(RuleReasoning429.answer(m,
          '${scenario.$2} è assente. ${scenario.$1} si ${scenario.$3}?')!.truth, 'unknown');
      expect(jsonEncode(m.toJson()), before);
    }
  });
  test('production reader proves or abstains on an inspectable teaching paragraph', () async {
    final reader = await VerificationReader428.open(factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path);
    try {
      final world = ProseVerification430.world();
      final report = await LearningVerification428.run(mode: 'prose', seed: 430,
          cases: world.cases, query: reader.answer, read: () => reader.read([world.document]));
      final output = Directory('tool/reports');
      await output.create(recursive: true);
      await File('${output.path}/prose-verification-0.42.10.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      expect(report['passed'], 12, reason: jsonEncode(LearningVerification428.rows(report)
          .where((r) => r['passed'] != true).toList()));
      final before = jsonEncode(reader.memory.toJson());
      for (final q in world.cases) { await reader.answer(q.prompt); }
      expect(jsonEncode(reader.memory.toJson()), before);
    } finally { await reader.close(); }
  });
}
