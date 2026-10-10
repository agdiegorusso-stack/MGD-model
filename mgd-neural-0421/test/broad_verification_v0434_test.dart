import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/broad_verification_v0434.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/verification_reader_v0428.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('frozen cross-domain criteria accept independently written reference answers', () async {
    final suite = await BroadVerification434.load();
    final domains = (suite['domains'] as List).cast<Map>();
    expect(domains.length, 8);
    var count = 0;
    for (final d in domains) {
      for (final q in (d['questions'] as List).cast<Map>()) {
        count++;
        final answer = VerificationAnswer428('${q['reference']}',
            q['determinate'] == true ? 'inferenza' : 'astensione');
        expect(BroadVerification434.grade(q, answer).passed, true,
            reason: '${d['id']}-${q['id']}: ${q['reference']}');
        expect(BroadVerification434.grade(q,
            VerificationAnswer428('${d['text']}', 'passaggi')).passed, false);
        expect(BroadVerification434.grade(q, const VerificationAnswer428(
            'Non determinabile dalle informazioni disponibili.', 'astensione')).passed, false,
            reason: 'Blanket abstention must not score even on missing-data questions.');
      }
    }
    expect(count, 32);
  });
  test('grading checks the first conclusion and requires the calculation or justification', () async {
    final suite = await BroadVerification434.load();
    final d = (suite['domains'] as List).cast<Map>().firstWhere((d) => d['id'] == 'conto');
    final q = (d['questions'] as List).cast<Map>().firstWhere((q) => q['id'] == 'saldo');
    expect(BroadVerification434.grade(q, const VerificationAnswer428(
        '34 euro.', 'inferenza')).passed, false);
    expect(BroadVerification434.grade(q, VerificationAnswer428(
        '99 euro. ${q['reference']}', 'inferenza')).passed, false);
    expect(BroadVerification434.grade(q, VerificationAnswer428(
        '${q['reference']}', 'associazioni')).passed, false);
  });
  test('production reader is measured in eight isolated domains without a required engine score', () async {
    // This validates the measurement pipeline. Passing this software test says
    // nothing about whether MGD passes the comprehension benchmark.
    final report = await BroadVerification434.run(openReader: () =>
        VerificationReader428.open(factory: databaseFactoryFfi,
            temporaryRoot: Directory.systemTemp.path));
    expect(report['total'], 32);
    expect(report['memoryUnchanged434'], true);
    expect(report['generalComprehension434'], 'not_demonstrated');
    expect(report['sha256434'], BroadVerification434.frozenSha);
    expect((report['determinate434'] as Map)['total'], 24);
    expect((report['applied434'] as Map)['total'], 16);
    expect((report['unknown434'] as Map)['total'], 8);
    expect(LearningVerification428.rows(report), everyElement(contains('before')));
    final output = File('tool/reports/comprehension-0.42.14.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    print('BROAD434 ${jsonEncode({for (final k in ['passed', 'total', 'beforePassed',
      'determinate434', 'applied434', 'unknown434', 'domains434', 'sha256434']) k: report[k]})}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
