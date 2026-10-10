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
      'version': '0.42.15',
      'total': rows.length,
      'passed': rows.where((r) => r['passed'] == true).length,
      'results': rows,
    };
    File('tool/reports/semantic-transfer-0.42.15.json')
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
      expect(answer.route, 'inferenza');
      expect(answer.text, startsWith('21'));
      expect(answer.proof?['kind'], 'semantic435');
      expect(answer.text, contains('local://transfer435/production'));
      expect(jsonEncode(reader.memory.toJson()), snapshot);
      restored = await VerificationReader428.open(
        factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path,
        retained: reader.memory,
      );
      expect((await restored.answer(prompt)).text, answer.text);
      expect(
        (await restored.answer('La quota vale 13. Quanto vale la spesa?')).text,
        startsWith('Non determinabile: manca tassa'),
      );
      expect(jsonEncode(restored.memory.toJson()), snapshot);
      expect(
        jsonEncode(reader.memory.toJson()),
        isNot(contains('Mostra il calcolo')),
      );
    } finally {
      await restored?.close();
      await reader.close();
    }
  });
}
