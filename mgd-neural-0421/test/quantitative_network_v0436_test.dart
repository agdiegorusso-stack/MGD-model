import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/reading_reasoning_v0435.dart';
import '../lib/semantic_reasoning_v0435.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../tool/quantitative_transfer_v0436.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('generic constraints transfer without domain-specific handlers', () {
    final rows = quantitativeTransfer436();
    final report = {
      'version': '0.42.16',
      'scope': 'Controlli di sviluppo sul calcolo con relazioni esplicite; non prova di comprensione generale.',
      'passed': rows.where((r) => r['passed'] == true).length,
      'total': rows.length,
      'results': rows,
    };
    File('tool/reports/quantitative-transfer-0.42.16.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    for (final r in rows) expect(r['passed'], true, reason: jsonEncode(r));
  });
  test('production reader composes retained formulas and survives restore without learning queries', () async {
    const url = 'local://network436/retained';
    const text =
        'La spesa è la quota piu la tassa: S = q + t. Il totale è la spesa per il numero: T = s * n.';
    const prompt =
        'La quota vale 7 e la tassa vale 4 e il numero vale 3. Quanto vale il totale?';
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
          family: 'locale:436',
          title: 'Relazioni',
          url: url,
          trust: .8,
          text: text,
        ),
      ]);
      final snapshot = jsonEncode(reader.memory.toJson());
      final answer = await reader.answer(prompt);
      expect(answer.route, 'inferenza');
      expect(answer.text, startsWith('33.'));
      expect(answer.proof?['operation'], 'equation-network');
      expect(answer.text, contains(url));
      expect(jsonEncode(reader.memory.toJson()), snapshot);
      restored = await VerificationReader428.open(
        factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path,
        retained: reader.memory,
      );
      final restoredSnapshot = jsonEncode(restored.memory.toJson());
      expect((await restored.answer(prompt)).text, answer.text);
      final unknown = await restored.answer(
        'La quota vale 7 e la tassa vale 4. Quanto vale il totale?',
      );
      expect(unknown.route, 'astensione');
      expect(unknown.text, contains('numero'));
      expect(jsonEncode(restored.memory.toJson()), restoredSnapshot);
    } finally {
      await restored?.close();
      await reader.close();
    }
  });
  test('sources are necessary, contexts isolated and units never silently dropped', () {
    const first = ReadingSource435(
      'a',
      'La spesa è la quota piu la tassa: S = q + t.',
      'Primo',
      'local://context/a',
    );
    const second = ReadingSource435(
      'b',
      'Il totale è la spesa per il numero: T = s * n.',
      'Secondo',
      'local://context/b',
    );
    const prompt =
        'La quota vale 7 e la tassa vale 4 e il numero vale 3. Quanto vale il totale?';
    final separated = SemanticReasoning435.answer([first, second], prompt);
    expect(separated?.unknown, true);
    expect(separated?.text, isNot(startsWith('33')));
    expect(SemanticReasoning435.answer([], prompt), isNull);
    final unified = ReadingSource435(
      second.id,
      second.text,
      second.title,
      first.url,
    );
    expect(
      SemanticReasoning435.answer([unified, first], prompt)?.text,
      startsWith('33.'),
    );
    final units = SemanticReasoning435.answer(
      [first, unified],
      'La quota vale 7 kg e la tassa vale 4 e il numero vale 3. Quanto vale il totale?',
    );
    expect(units?.unknown, true);
    expect(units?.text, contains('unità'));
  });
}
