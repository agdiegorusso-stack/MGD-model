import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/rule_reasoning_v0429.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/transfer_verification_v0429.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/web_knowledge_explorer_v11.dart';

ResearchMemory11 memory(String text, {String url = 'local://rules/test'}) {
  final m = ResearchMemory11();
  SourceMemory323.retain(m, WebDocument11(provider: 'Test', family: 'locale:test',
      title: 'Regole lette', url: url, text: text, trust: .8));
  return m;
}
String? truth(ResearchMemory11 m, String question) => RuleReasoning429.answer(m, question)?.truth;

void main() {
  sqfliteFfiInit();
  test('conditional chains use learned premises with independently replayable proofs', () {
    final m = memory('interruttore è acceso. '
        'Se interruttore è acceso, allora rele è attivo. '
        'Se rele è attivo allora lampada è luminosa. '
        'Se lampada è luminosa allora allarme è visibile.');
    final result = RuleReasoning429.answer(m, 'allarme è visibile?')!;
    expect(result.truth, 'true');
    expect(result.text, contains('Fonte: Regole lette'));
    expect(RuleReasoning429.validate(result.proof!, RuleReasoning429.parse(RuleReasoning429.sources(m)), []), false,
        reason: 'A proof must bind to the exact parsed rule objects, not arbitrary copied identifiers');
    final program = RuleReasoning429.parse(RuleReasoning429.sources(m));
    final solved = RuleReasoning429.solve(program, RuleReasoning429.atom('allarme è visibile')!, []);
    expect(RuleReasoning429.validate(solved.proof!, program, []), true);
    final tampered = LogicProof429(RuleReasoning429.atom('altro è visibile')!,
      rule: solved.proof!.rule, binding: solved.proof!.binding, premises: solved.proof!.premises);
    expect(RuleReasoning429.validate(tampered, program, []), false);
  });
  test('one-way implication does not assert its converse or inverse', () {
    final m = memory('Se motore è acceso allora ruota è attiva.');
    expect(truth(m, 'motore è spento. ruota è attiva?'), 'unknown');
    expect(truth(m, 'ruota è attiva. motore è acceso?'), 'unknown');
    expect(truth(m, 'motore è acceso. ruota è attiva?'), 'true');
  });
  test('biconditional works in both directions with explicit negatives', () {
    final m = memory('porta è aperta se e solo se chiave è presente.');
    expect(truth(m, 'chiave è presente. porta è aperta?'), 'true');
    expect(truth(m, 'chiave è assente. porta è aperta?'), 'false');
    expect(truth(m, 'porta è aperta. chiave è presente?'), 'true');
    expect(truth(m, 'porta è chiusa. chiave è presente?'), 'false');
  });
  test('conjunction requires all premises; a false member differs from a missing member', () {
    final m = memory('sistema è attivo se e solo se alimentazione è presente e consenso è presente.');
    expect(truth(m, 'alimentazione è presente. sistema è attivo?'), 'unknown');
    expect(truth(m, 'alimentazione è presente. consenso è presente. sistema è attivo?'), 'true');
    expect(truth(m, 'alimentazione è assente. sistema è attivo?'), 'false');
    expect(truth(m, 'sistema è inattivo. consenso è presente?'), 'unknown');
  });
  test('universal guarded rules apply to new members, preserving class restrictions', () {
    final m = memory('Ogni sensore che contiene batteria diventa pronto.');
    expect(truth(m, 'nuovo è un sensore. nuovo contiene batteria. nuovo diventa pronto?'), 'true');
    expect(truth(m, 'nuovo è un veicolo. nuovo contiene batteria. nuovo diventa pronto?'), 'unknown');
    expect(truth(m, 'nuovo è un sensore. nuovo non contiene batteria. nuovo diventa pronto?'), 'unknown');
  });
  test('counterfactual conditions override base values only within a query', () {
    final m = memory('chiave è presente. porta è aperta se e solo se chiave è presente.');
    final original = jsonEncode(m.toJson());
    expect(truth(m, 'chiave è assente. porta è aperta?'), 'false');
    expect(truth(m, 'porta è aperta?'), 'true');
    expect(jsonEncode(m.toJson()), original);
  });
  test('conflicting premises or rule conclusions are never a determined prediction', () {
    final m = memory('porta è aperta se e solo se chiave è presente.');
    expect(truth(m, 'chiave è presente. chiave è assente. porta è aperta?'), 'conflict');
    final conflicting = memory('segnale è presente. '
      'Se segnale è presente allora porta è aperta. '
      'Se segnale è presente allora porta è chiusa.');
    expect(truth(conflicting, 'porta è aperta?'), 'conflict');
  });
  test('an unrelated conflict does not poison a proof', () {
    final m = memory('rumore è presente. rumore è assente. '
      'chiave è presente. porta è aperta se e solo se chiave è presente.');
    expect(truth(m, 'porta è aperta?'), 'true');
  });
  test('unqualified negative entrance requires an explicit exclusive mechanism', () {
    const rules = 'unità contiene canale. '
      'canale fa entrare liquido in ogni cellula che lo contiene se e solo se energia è presente.';
    expect(truth(memory(rules), 'energia è assente. liquido entra in unità?'), 'unknown');
    expect(truth(memory(rules), 'liquido entra in unità. energia è presente?'), 'unknown');
    expect(truth(memory('$rules Tutte le cellule di questo modello hanno soltanto questo ingresso.'),
      'energia è assente. liquido entra in unità?'), 'false');
  });
  test('modal or unsupported disjunctive rules are not turned into certainties', () {
    final m = memory('porta potrebbe diventare aperta se chiave è presente. '
      'luce è accesa se segnale è presente oppure chiave è presente.');
    expect(truth(m, 'chiave è presente. porta diventa aperta?'), 'unknown');
    expect(truth(m, 'segnale è presente. luce è accesa?'), 'unknown');
  });
  test('forgotten source rules immediately cease to justify a conclusion', () {
    final m = memory('chiave è presente. porta è aperta se e solo se chiave è presente.');
    expect(truth(m, 'porta è aperta?'), 'true');
    SourceMemory323.forget33(m, (text) => text.contains('se e solo se'));
    expect(truth(m, 'chiave è presente. porta è aperta?'), 'unknown');
  });
  test('quantitative questions distinguish a recorded value from a missing property', () {
    final m = memory('alfa contiene modulo. alfa pesa 7.');
    expect(truth(m, 'Quanto pesa alfa?'), 'fact');
    expect(RuleReasoning429.answer(m, 'Quanto pesa alfa?')!.text, contains('alfa pesa 7'));
    expect(truth(m, 'Quanto misura alfa?'), 'unknown');
    expect(truth(m, 'alfa è verde?'), 'unknown');
    expect(truth(memory('alfa pesa 7. alfa non pesa 7.'), 'Quanto pesa alfa?'), 'conflict');
  });
  test('bounded inference abstains on exhaustion and terminates on cycles', () {
    final p = RuleReasoning429.parse(RuleReasoning429.sources(memory(
      'a è vero se e solo se b è vero. b è vero se e solo se c è vero.')));
    final target = RuleReasoning429.atom('a è vero')!;
    expect(RuleReasoning429.solve(p, target, []).truth, 'unknown');
    expect(RuleReasoning429.solve(p, target, [], maxWork: 1).text, contains('limite'));
  });
  test('new identifiers and changed polarities retain the original strict evaluator', () {
    for (final seed in [19, 47, 101, 9827, 99991]) {
      final m = ResearchMemory11();
      final worlds = LearningVerification428.worlds(seed);
      for (final w in worlds) { SourceMemory323.retain(m, w.document); }
      for (final q in worlds.expand((w) => w.cases).where((q) => q.object.isEmpty)) {
        final answer = RuleReasoning429.answer(m, q.prompt)!;
        final graded = LearningVerification428.grade(q, VerificationAnswer428(answer.text,
          answer.truth == 'unknown' ? 'astensione' : 'inferenza', proof: answer.proof?.toJson()));
        expect(graded.passed, true, reason: '${q.prompt}: ${answer.text}');
      }
    }
  });
  test('production reading passes independent transfer with visible proofs and no answer leakage', () async {
    final reader = await VerificationReader428.open(factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path);
    try {
      final worlds = TransferVerification429.worlds(429);
      final report = await LearningVerification428.run(mode: 'transfer', seed: 429,
        cases: worlds.expand((w) => w.cases).toList(), query: reader.answer,
        read: () => reader.read(worlds.map((w) => w.document).toList()));
      final rows = LearningVerification428.rows(report);
      final out = Directory('tool/reports');
      await out.create(recursive: true);
      await File('${out.path}/transfer-verification-0.42.9.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      expect(report['passed'], report['total'], reason: jsonEncode(rows.where((r) => r['passed'] != true).toList()));
      expect(rows.where((r) => {'si', 'no'}.contains(r['expected']))
        .every((r) => (r['answer'] as Map)['proof'] is Map), true);
      final snapshot = jsonEncode(reader.memory.toJson());
      for (final q in worlds.first.cases) { await reader.answer(q.prompt); }
      expect(jsonEncode(reader.memory.toJson()), snapshot);
    } finally { await reader.close(); }
  });
}
