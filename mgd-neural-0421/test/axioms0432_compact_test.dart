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
import 'package:mgd_neuro_mobile/axioms/teacher_compact0432.dart';

// Exact unmodified output supplied from the user's phone (cycle 3, 46914 ms).
const phoneFailure0432 = r'''{"diagnosis":"Il verbo 'raggiunge' è un evento di movimento (raggiunge) e un luogo (Pisa). Il contesto fornisce la chiave in posseduta da da Luca, ma è è rilevante rilevante per movimento.","task":{"id":"target","text":"Luca giunge a Pisa.","intent":"raggiunge","args":{"who":"Luca","where":"Pisa"}},"negated":false,"before":{"location":{"luca":"roma","sofia":"roma","chiave":"null"}},"holder":{"chiave":"luca"},"owner":{"chiave":"luca"}},"expected_after":{"luca":"Pisa","sofia":"roma","chiave":"null"}},"expected_status":"applied"},"lessons":[{"kind":"anchored","id":"giunge","text":"Luca giunge a Pisa.","anchor":"raggiunge","args":{"who":"Luca","where":"Pisa"}},{"where":"Pisa"}}},"probes":[{"id":"p1","text":"Luca giunge a Pisa.","intent":"raggiunge","args":{"who":"Luca","where":"Pisa"}},"negated":false,"before":{"location":{"luca":"roma","sofia":"roma","chiave":"null"}},"expected_after":{"luca":"Pisa","sofia":"roma","chiave":"null"}},"expected_status":"applied"},{"id":"p2","text":"Luca non giunge a Pisa.","intent":"giunge","args":{"who":"Luca","where":"isa"}},"negated":true,"before":{"location":{"luca":"roma","sofia":"roma","chiave":"null"}},"holder":{"ve":"luca"},"owner":{"chiave":"luca"}},"expected_after":{"location":{"luca":"roma","sofia":"roma","chiave":"null"}},"expected_status":"event_denied_no_update"}]}''';
J world0432() => {'location': {'luca': 'roma', 'sofia': 'roma', 'chiave': null},
  'holder': {'chiave': 'luca'}, 'owner': {'chiave': 'luca'}};
J pick0432(AxiomStudent s, String text, String intent) =>
    compactCandidates0432(s, text).firstWhere((c) => c['intent'] == intent);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ffi.sqfliteFfiInit(); sqlite.databaseFactory = ffi.databaseFactoryFfi;
  late Directory dir;
  final stores = <AxiomStore>[];
  Future<AxiomStore> open() async {
    final s = AxiomStore(); stores.add(s);
    await s.open(databasePath: '${dir.path}/axioms.db'); return s;
  }
  void mock(FutureOr<dynamic> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(AxiomStore.channel, (c) async {
        if (c.method == 'status') return {'loaded': 'custom', 'backend': 'GPU'};
        return handler(c);
      });
  }
  setUp(() async { dir = await Directory.systemTemp.createTemp('axioms0432-'); mock((_) => null); });
  tearDown(() async {
    for (final s in stores) { await s.closeStorage(); s.dispose(); }
    stores.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AxiomStore.channel, null);
    await dir.delete(recursive: true);
  });

  test('exact phone response is invalid and is never salvaged into knowledge', () {
    expect(phoneFailure0432.length, 1327);
    expect(() => jsonDecode(phoneFailure0432), throwsFormatException);
    final s = AxiomStudent(axiomSeed()), before = axHash(axiomSeed());
    expect(() => compactChoice0432(phoneFailure0432, compactCandidates0432(s, 'Luca giunge a Pisa.')), throwsFormatException);
    expect(s.revision, before);
  });
  test('unknown demo verb is not in the seed; hypotheses reuse minimal existing frame', () {
    final s = AxiomStudent(axiomSeed());
    expect(s.parse('Luca giunge a Pisa.')['status'], 'unrecognized');
    final c = pick0432(s, 'Luca giunge a Pisa.', 'move');
    expect(c['surface'], ['giunge']);
    expect(c['args'], {'who': 'luca', 'where': 'pisa'});
    expect(s.frames.any((f) => f['id'] == c['frame_id']), true);
  });
  test('compact decoder rejects unknown codes, added fields, prose and truncated JSON', () {
    final cs = compactCandidates0432(AxiomStudent(axiomSeed()), 'Luca giunge a Pisa.');
    for (final raw in ['{"choice":"C999"}', '{"choice":"C1","args":{}}', 'C1', '{"choice":', '[]']) {
      expect(() => compactChoice0432(raw, cs), throwsFormatException, reason: raw);
    }
    expect(compactChoice0432('{"choice":"UNKNOWN"}', cs), 'UNKNOWN');
  });
  for (final spec in [
    ['Luca giunge a Pisa.', 'move'], ['Luca approda a Pisa.', 'move'],
    ['Luca agguanta la chiave.', 'pick'], ['Luca recapita la chiave a Sofia.', 'give'],
    ['Luca regala la chiave a Sofia.', 'donate'], ['Luca colloca la chiave a terra.', 'drop']
  ]) {
    test('same compiler works without hardcoded synonym: ${spec[0]}', () {
      final original = AxiomStudent(axiomSeed());
      final candidate = pick0432(original, spec[0], spec[1]);
      final proposal = compactPackage0432(original, spec[0], world0432(), candidate, axiomRegression());
      final result = validateTeaching(original, proposal, axiomRegression());
      expect(result['accepted'], true, reason: canonical(result));
      final learned = AxiomStudent(result['model'] as Map);
      expect(learned.frames.length, original.frames.length);
      expect(learned.programs, original.programs);
      expect(learned.lexicon.length, original.lexicon.length + 1);
      expect(result['protected_tested'], 276);
      expect((proposal['probes'] as List).map((p) => canonical(p['args'])).toSet().length, greaterThanOrEqualTo(3));
      expect(original.revision, axHash(axiomSeed()));
    });
  }
  test('known negation is not absorbed into an invented lexical meaning', () {
    final original = AxiomStudent(axiomSeed());
    final cs = compactCandidates0432(original, 'Luca non giunge a Pisa.');
    expect(cs, isNotEmpty);
    expect(cs.every((c) => c['negated'] == true && !(c['surface'] as List).contains('non')), true);
    final p = compactPackage0432(original, 'Luca non giunge a Pisa.', world0432(), cs.first, axiomRegression());
    final r = validateTeaching(original, p, axiomRegression());
    expect(r['accepted'], true, reason: canonical(r));
    expect(p['task']['expected_after'], world0432());
    expect(p['task']['expected_status'], 'event_denied_no_update');
  });
  test('target state preserves all fields and actual JSON null', () {
    final s = AxiomStudent(axiomSeed());
    final p = compactPackage0432(s, 'Luca giunge a Pisa.', world0432(), pick0432(s, 'Luca giunge a Pisa.', 'move'), axiomRegression());
    final after = world0432(); after['location']['luca'] = 'pisa';
    expect(p['task']['expected_after'], after);
    expect(p['task']['args'], {'who': 'luca', 'where': 'pisa'});
    expect(p['task']['intent'], 'move');
    expect(p['task']['expected_after']['location']['chiave'], isNull);
  });
  test('probes are separate from the original request and lesson', () {
    final s = AxiomStudent(axiomSeed());
    final p = compactPackage0432(s, 'Luca giunge a Pisa.', world0432(), pick0432(s, 'Luca giunge a Pisa.', 'move'), axiomRegression());
    for (final q in p['probes'] as List) {
      expect(axTokens(q['text']), isNot(axTokens(p['task']['text'])));
      expect(axTokens(q['text']), isNot(axTokens(p['lessons'][0]['text'])));
      expect(q['reference_text'], isA<String>());
    }
    expect(p['independent_semantic_truth_proven'], false);
  });
  test('no suitable reference tests means no acceptance', () {
    final s = AxiomStudent(axiomSeed());
    expect(() => compactPackage0432(s, 'Luca giunge a Pisa.', world0432(), pick0432(s, 'Luca giunge a Pisa.', 'move'), []), throwsFormatException);
  });
  test('one compact reply teaches and persists, then works without teacher', () async {
    var calls = 0;
    mock((c) {
      if (c.method != 'generate') return null;
      calls++;
      expect(c.arguments['max_output_tokens'], 64);
      expect(c.arguments['json_schema'], isA<String>());
      expect((c.arguments['prompt'] as String).length, lessThan(4000));
      final code = pick0432(AxiomStudent(axiomSeed()), 'Luca giunge a Pisa.', 'move')['id'];
      return jsonEncode({'choice': code});
    });
    final s = await open();
    await s.teach('Luca giunge a Pisa.', world0432(), 3);
    expect(calls, 1); expect(s.result!['accepted'], true, reason: canonical(s.result));
    expect(s.result!['status'], 'applied'); expect(s.result!['request_retested'], true);
    expect(s.result!['world']['location']['luca'], 'pisa');
    expect(s.result!['world']['owner'], {'chiave': 'luca'});
    expect(s.student.parse('È a Torino che Vittorio giunge.')['status'], 'ok');
    await s.closeStorage(); final restored = await open();
    mock((c) { if (c.method == 'generate') throw StateError('teacher is off'); return null; });
    await restored.inspect('Sofia giunge a Milano.', world0432());
    expect(restored.result!['world']['location']['sofia'], 'milano');
    await restored.teach('Luca giunge a Pisa.', world0432(), 3);
    expect(restored.result!['already_known'], true);
    expect(restored.state['events'].last['protocol'], '0432');
    expect(restored.state['events'].last['outcome'], 'accepted');
    await restored.testAll(); expect(restored.result!['passed'], restored.result!['total']);
  });
  test('UNKNOWN leaves knowledge unchanged, does not repeat expensive calls', () async {
    var count = 0;
    mock((c) { if (c.method != 'generate') return null; count++; return '{"choice":"UNKNOWN"}'; });
    final s = await open(), revision = axHash(axiomSeed());
    await s.teach('Luca pensa a Pisa.', world0432(), 3);
    expect(count, 1); expect(s.student.revision, revision);
    expect(s.state['events'].last['outcome'], 'no_semantic_equivalence');
  });
  test('malformed output cannot reset context or modify the seed', () async {
    mock((c) => c.method == 'generate' ? phoneFailure0432 : null);
    final s = await open(), revision = axHash(axiomSeed());
    await s.teach('Luca giunge a Pisa.', world0432(), 1);
    expect(s.student.revision, revision);
    expect(s.state['events'].last['outcome'], 'invalid_compact_response');
    expect(s.state['probes'], isEmpty);
  });
  test('cancelled response cannot become a late accepted lesson', () async {
    final started = Completer<void>(), raw = Completer<String>();
    mock((c) { if (c.method != 'generate') return null; started.complete(); return raw.future; });
    final s = await open(), revision = axHash(axiomSeed());
    final work = s.teach('Luca giunge a Pisa.', world0432(), 3);
    await started.future; await s.stop(); raw.complete('{"choice":"C1"}'); await work;
    expect(s.student.revision, revision);
    expect(s.state['events'].last['outcome'], 'cancelled');
  });
  test('produce exact app prompts for real Kotlin Gemma inference (labels excluded from prompt)', () {
    final s = AxiomStudent(axiomSeed());
    final out = <J>[];
    for (final spec in [
      ['Luca giunge a Pisa.', 'move'], ['Sofia approda a Milano.', 'move'],
      ['Luca agguanta la chiave.', 'pick'], ['Luca regala la chiave a Sofia.', 'donate'],
      ['Luca pensa a Pisa.', 'UNKNOWN'], ['Luca non giunge a Pisa.', 'move']
    ]) {
      final cs = compactCandidates0432(s, spec[0]);
      final expected = spec[1] == 'UNKNOWN' ? 'UNKNOWN' : cs.firstWhere((c) => c['intent'] == spec[1])['id'];
      out.add({'request': spec[0], 'system': compactTeacherSystem0432,
        'prompt': compactPrompt0432(spec[0], cs), 'schema': jsonEncode(compactSchema0432(cs)),
        'expected_choice': expected, 'candidates': cs});
    }
    final f = File('tool/reports/compact-prompts0432.json'); f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(out));
  });
  test('replay real Gemma responses through the app and persist resulting knowledge', () async {
    final path = Platform.environment['MGD_LIVE_0432'];
    if (path == null) return;
    final rows = jsonDecode(File(path).readAsStringSync()) as List;
    expect(rows.length, 6);
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i] as Map;
      expect(row['backend'], 'CPU');
      expect(row['model_sha256'], '181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c');
      final request = row['request'] as String;
      final cs = compactCandidates0432(AxiomStudent(axiomSeed()), request);
      expect(compactChoice0432(row['raw_response'] as String, cs), row['expected_choice']);
      if (row['expected_choice'] == 'UNKNOWN') continue;
      final c = cs.singleWhere((c) => c['id'] == row['expected_choice']);
      final p = compactPackage0432(AxiomStudent(axiomSeed()), request, world0432(), c, axiomRegression());
      final r = validateTeaching(AxiomStudent(axiomSeed()), p, axiomRegression());
      expect(r['accepted'], true, reason: canonical(r));
    }
    final first = rows.first as Map;
    mock((c) => c.method == 'generate' ? first['raw_response'] : null);
    final s = await open(); await s.teach(first['request'] as String, world0432(), 1);
    expect(s.result!['accepted'], true);
    await s.closeStorage(); final reloaded = await open();
    expect(reloaded.student.parse('Elena giunge a Genova.')['status'], 'ok');
  }, skip: Platform.environment['MGD_LIVE_0432'] == null ? 'Requires real model artifact; separate mandatory CI replay' : false);
}
