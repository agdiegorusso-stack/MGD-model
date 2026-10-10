import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/application_verification_v0433.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  sqfliteFfiInit();
  test('real online reading supports new concentration cases after save and reopen', () async {
    HttpOverrides.global = null;
    final doc = await ApplicationVerification433.fetchDocument();
    final seed = 8173619;
    final questions = ApplicationVerification433.cases(doc, seed);
    final reader = await VerificationReader428.open(factory: databaseFactoryFfi,
        temporaryRoot: Directory.systemTemp.path);
    VerificationReader428? reopened;
    try {
      final report = await LearningVerification428.run(mode: 'application', seed: seed,
        cases: questions, query: reader.answer,
        read: () async {
          await reader.read([doc]);
          final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(reader.memory.toJson())));
          reopened = await VerificationReader428.open(factory: databaseFactoryFfi,
              temporaryRoot: Directory.systemTemp.path, retained: restored);
        });
      final frozen = jsonEncode(reopened!.memory.toJson());
      final afterRestore = await LearningVerification428.run(mode: 'application', seed: seed,
        cases: questions, query: reopened!.answer);
      expect(jsonEncode(reopened!.memory.toJson()), frozen,
          reason: 'No question, answer key, query diagnostic or scoring feedback may enter learning.');
      report['afterRestore433'] = afterRestore;
      report['acquisition433'] = doc.meta318;
      report['scope433'] = 'Verso del flusso di un soluto neutro in un sistema ideale a sola diffusione.';
      final output = File('tool/reports/application-verification-0.42.13.json');
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      final results = LearningVerification428.rows(report);
      print('APPLICATION433 ${jsonEncode({'passed': report['passed'], 'total': report['total'],
        'predictionsPassed': results.where((r) => r['expectedTransfer433'] != null && r['passed'] == true).length,
        'predictionsTotal': results.where((r) => r['expectedTransfer433'] != null).length,
        'beforePredictionsPassed': results.where((r) => r['expectedTransfer433'] != null && r['beforePassed'] == true).length,
        'afterRestorePassed': afterRestore['passed'], 'source': doc.url, 'acquisition': doc.meta318})}');
      expect(report['passed'], report['total'], reason: jsonEncode(report));
      expect(afterRestore['passed'], afterRestore['total']);
      expect(results.where((r) => r['expectedTransfer433'] != null && r['beforePassed'] == true), isEmpty);
    } finally { await reader.close(); await reopened?.close(); }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
