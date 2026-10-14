import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:mgd_neuro_mobile/axioms/axiom_core.dart';
import 'package:mgd_neuro_mobile/axioms/axiom_seed.dart';
import 'package:mgd_neuro_mobile/axioms/axiom_store.dart';
import 'package:mgd_neuro_mobile/axioms/teacher_protocol0431.dart';
import 'axioms0430_test.dart' show lessonPackage;

J screenshotWorld() => {
  'location': {'luca': 'roma', 'sofia': 'roma', 'chiave': null},
  'holder': {'chiave': 'luca'}, 'owner': {'chiave': 'luca'}
};
J screenshotPackage() {
  final p = lessonPackage();
  p['task']['before'] = screenshotWorld();
  final after = screenshotWorld();
  after['location']['luca'] = 'pisa';
  p['task']['expected_after'] = after;
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ffi.sqfliteFfiInit();
  sqlite.databaseFactory = ffi.databaseFactoryFfi;
  late Directory dir;
  final stores = <AxiomStore>[];
  Future<AxiomStore> open() async {
    final s = AxiomStore(); stores.add(s);
    await s.open(databasePath: '${dir.path}/axioms.db');
    return s;
  }
  void mock(FutureOr<dynamic> Function(MethodCall) fn) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AxiomStore.channel, (call) async => fn(call));
  }
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mgd-0431-teacher-');
    mock((_) => null);
  });
  tearDown(() async {
    for (final s in stores) { await s.closeStorage(); s.dispose(); }
    stores.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AxiomStore.channel, null);
    await dir.delete(recursive: true);
  });

  test('complete format example actually passes the unchanged teaching gate', () {
    final p = teacherFormatExample0431();
    expect(teacherProblems0431(p, p['task']['text'] as String,
        copyJ(p['task']['before'] as Map)), isEmpty);
    final student = AxiomStudent(axiomSeed());
    expect(student.parse('Luca giunge a Pisa.')['status'], 'unrecognized');
    final report = validateTeaching(student, p, axiomRegression());
    expect(report['accepted'], true, reason: canonical(report));
    expect(report['protected_tested'], 276);
    // The format example is only text in the teacher prompt, never boot knowledge.
    expect(student.parse('Irene viaggia verso Roma.')['status'], 'unrecognized');
    expect(axiomTeacherContract0431, contains(jsonEncode(p)));
  });
  test('decoder accepts a complete fenced object but rejects truncated output', () {
    final p = screenshotPackage();
    expect(decodeTeacher0431('```json\n${jsonEncode(p)}\n```'), p);
    expect(() => decodeTeacher0431('{"task":'), throwsFormatException);
    expect(() => decodeTeacher0431('[]'), throwsFormatException);
    expect(() => decodeTeacher0431('${jsonEncode(p)} ${jsonEncode(p)}'),
        throwsFormatException);
  });
  test('missing task is diagnosed without inventing an expected answer', () {
    final p = screenshotPackage()..remove('task');
    expect(teacherProblems0431(p, 'Luca giunge a Pisa.', screenshotWorld()),
        contains(contains('task: manca')));
    expect(p.containsKey('task'), false);
  });
  test('partial expected world explicitly diagnoses lost Sofia holder and owner', () {
    final p = screenshotPackage();
    p['task']['expected_after'] = {'location': {'luca': 'pisa'}};
    final problems = teacherProblems0431(p, 'Luca giunge a Pisa.', screenshotWorld());
    expect(problems.join('\n'), contains('location.sofia'));
    expect(problems.join('\n'), contains('holder'));
    expect(problems.join('\n'), contains('owner'));
    expect(p['task']['expected_after'], {'location': {'luca': 'pisa'}});
  });
  test('a probe cannot reuse the target or omit explicit negation labels', () {
    final p = screenshotPackage();
    p['probes'][0]['text'] = p['task']['text'];
    (p['probes'][1] as Map).remove('negated');
    final problems = teacherProblems0431(p, 'Luca giunge a Pisa.', screenshotWorld());
    expect(problems.join('\n'), contains('diverso anche dal task'));
    expect(problems.join('\n'), contains('negated'));
  });
  test('accepted teacher lesson is re-executed on the full screenshot world and reopens', () async {
    mock((call) => call.method == 'generate' ? jsonEncode(screenshotPackage()) : null);
    final s = await open();
    await s.inspect('Luca giunge a Pisa.', screenshotWorld());
    expect(s.result!['status'], 'unrecognized');
    await s.teach('Luca giunge a Pisa.', screenshotWorld(), 3);
    expect(s.result!['accepted'], true);
    expect(s.result!['request_retested'], true);
    expect(s.result!['status'], 'applied');
    expect(s.result!['world'], screenshotPackage()['task']['expected_after']);
    expect(s.student.parse('È a Torino che Elena giunge.')['status'], 'ok');
    await s.closeStorage();
    final restored = await open();
    expect(restored.student.parse('Elena giunge a Genova.')['status'], 'ok');
    expect(restored.state['events'].last['outcome'], 'accepted');
    await restored.testAll();
    expect(restored.result!['passed'], restored.result!['total']);
  });
  test('invalid JSON and missing task are logged and precise feedback reaches next cycle', () async {
    var calls = 0;
    final prompts = <J>[];
    mock((call) {
      if (call.method != 'generate') return null;
      prompts.add(copyJ(jsonDecode(call.arguments['prompt'] as String) as Map));
      calls++;
      if (calls == 1) return '{"task":';
      if (calls == 2) return jsonEncode(screenshotPackage()..remove('task'));
      return jsonEncode(screenshotPackage());
    });
    final s = await open();
    await s.teach('Luca giunge a Pisa.', screenshotWorld(), 3);
    expect(calls, 3);
    expect(prompts[1]['feedback']['protocol_errors'].join(), contains('JSON'));
    expect(prompts[2]['feedback']['protocol_errors'].join(), contains('task'));
    expect(s.result!['accepted'], true);
    expect((s.state['events'] as List).map((e) => e['outcome']).toList(),
        ['invalid_json', 'invalid_schema', 'accepted']);
    expect(s.state['events'][0]['raw_response'], '{"task":');
  });
  test('all malformed cycles preserve knowledge and expose the concrete final reason', () async {
    mock((call) => call.method == 'generate' ? jsonEncode({'diagnosis':'x',
        'lessons': [{}], 'probes': []}) : null);
    final s = await open();
    final revision = s.student.revision;
    await s.teach('Luca giunge a Pisa.', screenshotWorld(), 3);
    expect(s.student.revision, revision);
    expect(s.result!['accepted'], false);
    expect(s.result!['reason'], contains('task'));
    expect(s.state['events'], hasLength(3));
    await s.closeStorage();
    expect((await open()).state['events'], hasLength(3));
  });
  test('valid JSON with false operational labels still fails the unchanged gate', () async {
    final wrong = screenshotPackage();
    wrong['task']['expected_after']['location']['luca'] = 'bari';
    mock((call) => call.method == 'generate' ? jsonEncode(wrong) : null);
    final s = await open();
    final revision = s.student.revision;
    await s.teach('Luca giunge a Pisa.', screenshotWorld(), 1);
    expect(s.student.revision, revision);
    expect(s.result!['accepted'], false);
    expect(s.state['events'].last['outcome'], 'rejected');
    expect(s.result!['reason'], contains('Dettaglio'));
  });
  test('old unrecognized result is cleared during generation and cancellation rejects late lesson', () async {
    final started = Completer<void>(), response = Completer<String>();
    mock((call) {
      if (call.method == 'generate') { started.complete(); return response.future; }
      return null;
    });
    final s = await open();
    await s.inspect('Luca giunge a Pisa.', screenshotWorld());
    final revision = s.student.revision;
    final work = s.teach('Luca giunge a Pisa.', screenshotWorld(), 3);
    await started.future;
    expect(s.result, isNull);
    expect(s.status, contains('genera la proposta'));
    await s.stop();
    response.complete(jsonEncode(screenshotPackage()));
    await work;
    expect(s.student.revision, revision);
    expect(s.state['events'].last['outcome'], 'cancelled');
  });
  test('a runtime exception is logged without declaring a missing axiom', () async {
    mock((call) {
      if (call.method == 'generate') throw PlatformException(code: 'TIMEOUT', message: 'timeout');
      return null;
    });
    final s = await open();
    await s.teach('Luca giunge a Pisa.', screenshotWorld(), 3);
    expect(s.state['events'].last['outcome'], 'runtime_error');
    expect(s.result!['reason'], contains('runtime'));
    expect(s.student.parse('Luca giunge a Pisa.')['status'], 'unrecognized');
  });
  test('an unloaded teacher is detected before generation', () async {
    var calls = 0;
    mock((call) {
      if (call.method == 'status') return {'loaded': '', 'backend': ''};
      if (call.method == 'generate') calls++;
      return null;
    });
    final s = await open();
    await s.teach('Luca giunge a Pisa.', screenshotWorld(), 3);
    expect(calls, 0);
    expect(s.result!['reason'], contains('Nessun insegnante caricato'));
  });
}
