import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/reading_reasoning_v0435.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../tool/semantic_transfer_v0435.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('new transfer cases change names, numbers, domains, sources and missing premises', () {
    final rows = semanticTransfer435();
    final report = {
      'scope': 'Casi sviluppati dopo il motore; grammatiche limitate, non valutazione cieca.',
      'version': '0.42.16',
      'total': rows.length,
      'passed': rows.where((r) => r['passed'] == true).length,
      'results': rows,
    };
    File('tool/reports/semantic-transfer-0.42.16.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    print(
      'TRANSFER435 ${jsonEncode({'passed': report['passed'], 'total': report['total']})}',
    );
    for (final row in rows) {
      expect(row['passed'], true, reason: '${row['id']}: ${row['answer']}');
    }
  });
  test('same production memory query calculates, survives restore and never learns the questions', () async {
    const prompt =
        'La quota vale 13 e la tassa vale 8. Quanto vale la spesa? Mostra il calcolo.';
    final reader = await VerificationReader428.open(
      factory: databaseFactoryFfi,
      temporaryRoot: Directory.systemTemp.path,
    );
    VerificationReader428? restored;
    try {
      expect(ReadingReasoning435.answer(reader.memory, prompt), isNull);
      await reader.read([
        WebDocument11(
          provider: 'Test',
          family: 'locale:transfer435',
          title: 'Regola di somma',
          url: 'local://transfer435/production',
          trust: .8,
          text: 'La spesa è la quota piu la tassa: S = q + t. Il colore della fattura non è indicato.',
        ),
      ]);
      final snapshot = jsonEncode(reader.memory.toJson());
      final answer = await reader.answer(prompt);
      expect(
        answer.route,
        'inferenza',
        reason: jsonEncode({
          'answer': answer.toJson(),
          'sources': ReadingReasoning435.sources(reader.memory)
              .map((s) => s.toJson())
              .toList(),
          'claims': reader.memory.claims.values.map((c) => c.toJson()).toList(),
        }),
      );
      expect(answer.text, startsWith('21'));
      expect(answer.proof?['kind'], 'semantic435');
      expect(answer.text, contains('local://transfer435/production'));
      expect(jsonEncode(reader.memory.toJson()), snapshot);
      restored = await VerificationReader428.open(
        factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path,
        retained: reader.memory,
      );
      // Restoration applies the existing budget/provenance migration. Query
      // invariance starts after that migration; the answer must stay the same.
      final restoredSnapshot = jsonEncode(restored.memory.toJson());
      expect((await restored.answer(prompt)).text, answer.text);
      expect(
        (await restored.answer('La quota vale 13. Quanto vale la spesa?')).text,
        startsWith('Non determinabile: manca tassa'),
      );
      expect(jsonEncode(restored.memory.toJson()), restoredSnapshot);
      expect(
        jsonEncode(reader.memory.toJson()),
        isNot(contains('Mostra il calcolo')),
      );
    } finally {
      await restored?.close();
      await reader.close();
    }
  });
  test('a doubtful extraction does not erase other sentences; withdrawal and conflict remain effective', () {
    final memory = ResearchMemory11();
    const url = 'local://transfer435/filter';
    const equation = 'La spesa è la quota piu la tassa: S = q + t.';
    const property = 'La temperatura del serbatoio non è nota.';
    SourceMemory323.retain(
      memory,
      WebDocument11(
        provider: 'Test',
        family: 'locale:test',
        title: 'Regola e proprietà',
        url: url,
        text: '$equation $property',
        trust: .8,
      ),
    );
    final evidence = ResearchEvidence11.fromJson({
      'id': 'e',
      'sourceUrl': url,
      'excerpt': property,
    });
    final claim = ResearchClaim11.fromJson({
      'key': 'c',
      'status': 'quarantena',
      'evidenceIds': ['e'],
    });
    memory.evidence.add(evidence);
    memory.claims[claim.key] = claim;
    const prompt = 'La quota vale 9 e la tassa vale 5. Quanto vale la spesa?';
    final snapshot = jsonEncode(memory.toJson());
    expect(ReadingReasoning435.answer(memory, prompt)?.text, startsWith('14'));
    expect(jsonEncode(memory.toJson()), snapshot);
    claim.conflict = true;
    expect(ReadingReasoning435.answer(memory, prompt)?.text, startsWith('14'));
    expect(
      ReadingReasoning435.sources(memory).any((s) => s.text == property),
      false,
    );
    claim.status = 'ritirata';
    expect(ReadingReasoning435.answer(memory, prompt), isNull);
  });
}
