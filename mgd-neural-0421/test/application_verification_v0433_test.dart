import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/application_verification_v0433.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/transport_reasoning_v0433.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/web_knowledge_explorer_v11.dart';

// Exact 20-word original sentence, independently read in OpenStax 5.2.
const text = 'In passive transport, substances move from an area of higher concentration to an area of lower concentration.';
WebDocument11 document([String body = text]) => WebDocument11(provider: 'OpenStax fixture',
  family: 'openstax.org', title: 'Biology 2e · 5.2 Passive Transport',
  url: ApplicationVerification433.url, text: body, trust: .9);

void main() {
  sqfliteFfiInit();
  for (final q in ApplicationVerification433.cases(document(), 433)) {
    test('source transfer: ${q.id}', () async {
      final reader = await VerificationReader428.open(factory: databaseFactoryFfi,
          temporaryRoot: Directory.systemTemp.path);
      try {
        await reader.read([document()]);
        final frozen = jsonEncode(reader.memory.toJson());
        final answer = await reader.answer(q.prompt);
        expect(LearningVerification428.grade(q, answer).passed, isTrue,
            reason: '${q.prompt}\n${answer.text}');
        expect(jsonEncode(reader.memory.toJson()), frozen);
      } finally { await reader.close(); }
    });
  }
  test('real measurements are retained independently of the study and learned ordering', () {
    final original = ResearchMemory11();
    final doc = document();
    SourceMemory323.retain(original, doc);
    final m = ResearchMemory11.fromJson(jsonDecode(jsonEncode(original.toJson())));
    final q = ApplicationVerification433.cases(doc, 519).first;
    expect(TransportReasoning433.answer(m, q.prompt)!.proof!['result']['from'], 'sangue');
    expect(TransportReasoning433.answer(ResearchMemory11(), q.prompt)!.truth, 'unknown');
    // Reversing the retained statement reverses predictions. There is no
    // hidden answer table or unconditional high-to-low output in the solver.
    final reversed = ResearchMemory11();
    SourceMemory323.retain(reversed, document(text.replaceAll('higher', 'TEMP')
        .replaceAll('lower', 'higher').replaceAll('TEMP', 'lower')));
    final reversedAnswer = TransportReasoning433.answer(reversed, q.prompt)!;
    expect(reversedAnswer.proof!['result']['from'], 'bagno');
    expect(LearningVerification428.grade(q, VerificationAnswer428(reversedAnswer.text,
        'inferenza', proof: reversedAnswer.proof)).passed, isFalse);
  });
  test('conflicting, conditional and negated teaching statements do not become a usable principle', () {
    for (final body in ['If a condition is met, $text', text.replaceFirst('move', 'do not move'),
        '$text ${text.replaceAll('higher', 'TEMP').replaceAll('lower', 'higher').replaceAll('TEMP', 'lower')}']) {
      final m = ResearchMemory11();
      SourceMemory323.retain(m, document(body));
      expect(TransportReasoning433.answer(m, ApplicationVerification433.cases(document(), 7).first.prompt)!.truth,
          anyOf('unknown', 'conflict'));
    }
  });
  test('a quote or a conclusion without the source-premise bridge cannot pass', () {
    final q = ApplicationVerification433.cases(document(), 7).first;
    expect(LearningVerification428.grade(q, const VerificationAnswer428(text, 'passaggi')).passed, isFalse);
    expect(LearningVerification428.grade(q, VerificationAnswer428('Da sangue a bagno', 'inferenza',
        proof: {'kind': 'quantitative_transfer', 'result': q.expectedTransfer433})).passed, isFalse);
  });
  test('copying retained memory for a test isolates all nested maps', () async {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document());
    final frozen = jsonEncode(m.toJson());
    final reader = await VerificationReader428.open(factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path, retained: m);
    try {
      await reader.read([document('Unita contiene modulo.')]);
      expect(jsonEncode(m.toJson()), frozen);
    } finally { await reader.close(); }
  });
  test('held-out seeds, labels, decimals and units change inputs without teaching question keys', () {
    final m = ResearchMemory11();
    SourceMemory323.retain(m, document());
    for (final seed in [11, 99, 1801, 65537, 23488791]) {
      for (final q in ApplicationVerification433.cases(document(), seed)) {
        final a = TransportReasoning433.answer(m, q.prompt)!;
        expect(LearningVerification428.grade(q, VerificationAnswer428(a.text,
            a.truth == 'true' ? 'inferenza' : 'astensione', proof: a.proof)).passed, isTrue,
            reason: '${q.id} at seed $seed: ${a.text}');
      }
    }
  });
}
