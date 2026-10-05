import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/canonical_memory_v0420.dart';
import 'package:mgd_neuro_mobile/cognitive_coordinator_v0420.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late CanonicalMemory420 memory;
  late CognitiveCoordinator420 coordinator;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mgd420-');
    memory = await CanonicalMemory420.open(path: '${dir.path}/memory.db', factory: databaseFactoryFfi);
    coordinator = await CognitiveCoordinator420.create(memory);
  });
  tearDown(() async { await memory.close(); await dir.delete(recursive: true); });

  test('questions and generated answers never become factual observations', () async {
    await coordinator.process('La capsula contiene quarzo.');
    final before = await memory.stats();
    final reply = await coordinator.process('Che cosa contiene la capsula?');
    expect(reply.status, anyOf('direct', 'deduction'));
    expect(reply.text.toLowerCase(), contains('quarzo'));
    expect(reply.evidence, isNotEmpty);
    final after = await memory.stats();
    expect(after['claims'], before['claims']);
    expect(after['passages'], before['passages']);
    expect(after['flux'] as double, greaterThan(before['flux'] as double));
  });
  test('new text can be questioned immediately without replay or consolidation gate', () async {
    final learned = await memory.ingestText('Il lorvante contiene cristalli.');
    expect(learned['claims'], greaterThan(0));
    expect((await coordinator.process('Che cosa contiene il lorvante?')).text, contains('cristalli'));
  });
  test('reimport of identical text does not duplicate evidence or linguistic usage', () async {
    const text = 'La glarpa produce latte.';
    await memory.ingestText(text);
    final before = await memory.export();
    final again = await memory.ingestText(text);
    final after = await memory.export();
    expect(again['new'], false);
    for (final table in ['passages', 'claims', 'usage', 'edges']) {
      expect((after[table] as List).length, (before[table] as List).length);
    }
  });
  test('explicit positive and negative evidence produce a conflict', () async {
    await memory.ingestText('La gemma contiene quarzo. La gemma non contiene quarzo.');
    final reply = await coordinator.process('La gemma contiene quarzo?');
    expect(reply.status, 'conflict');
    expect(reply.evidence.length, greaterThanOrEqualTo(2));
  });
  test('unsupported scope is retained without becoming a certain fact', () async {
    final learned = await memory.ingestText('Forse la glarpa contiene oro.');
    expect(learned['claims'], 0);
    expect((await memory.unresolved()).single['text'], contains('Forse'));
    expect((await coordinator.process('La glarpa contiene oro?')).status, 'unknown');
  });
  test('consolidated knowledge remains explicitly correctable', () async {
    await memory.ingestText('La capsula contiene quarzo.');
    final original = (await memory.graph()).single['id'] as String;
    for (var i = 0; i < 80; i++) { await memory.activate([original]); }
    await memory.correct([original], 'La capsula contiene ferro.');
    final reply = await coordinator.process('Che cosa contiene la capsula?');
    expect(reply.text.toLowerCase(), contains('ferro'));
    expect(reply.text.toLowerCase(), isNot(contains('quarzo')));
    expect((await memory.evidence([original])).single['status'], 'superseded');
    expect((await memory.evidence([original])).single['text'], contains('quarzo'));
  });
  test('invalid correction leaves both knowledge and provenance unchanged', () async {
    await memory.ingestText('La capsula contiene quarzo.');
    final original = (await memory.graph()).single['id'] as String;
    await expectLater(memory.correct([original], 'Forse.'), throwsFormatException);
    expect((await memory.evidence([original])).single['status'], 'asserted');
    expect((await memory.stats())['passages'], 1);
  });
  test('learning a second domain does not remove old evidence', () async {
    await memory.ingestText('Il lorvante contiene cristalli.');
    final first = await coordinator.process('Che cosa contiene il lorvante?');
    await memory.ingestText('La cellula contiene DNA.');
    final second = await coordinator.process('Che cosa contiene il lorvante?');
    expect(second.text, first.text);
    expect(second.claimIds.toSet(), first.claimIds.toSet());
  });
  test('restart retains the same answers and source evidence', () async {
    await memory.ingestText('Il lorvante contiene cristalli.');
    final first = await coordinator.process('Che cosa contiene il lorvante?');
    await memory.close();
    memory = await CanonicalMemory420.open(path: '${dir.path}/memory.db', factory: databaseFactoryFfi);
    coordinator = await CognitiveCoordinator420.create(memory);
    final after = await coordinator.process('Che cosa contiene il lorvante?');
    expect(after.text, first.text); expect(after.claimIds.toSet(), first.claimIds.toSet());
  });
  test('alias and sensor binding use the same concept identity', () async {
    await memory.ingestText('Il lorvante contiene cristalli.');
    await memory.alias('lrv', 'lorvante');
    await memory.bindSensor('lorvante', 'vision', {'v:red': .8, 'v:edge': .2});
    await memory.bindSensor('lorvante', 'audio', {'a:rms': .7, 'a:band': .1});
    final rows = await memory.db.query('sensory');
    expect(rows.map((e) => e['concept']).toSet().length, 1);
    expect((await coordinator.process('Che cosa contiene lrv?')).text, contains('cristalli'));
  });
  test('hypotheses can transfer a rule without modifying memory', () async {
    await memory.ingestText('Ogni neride possiede una coda.');
    final before = (await memory.stats())['claims'];
    final reply = await coordinator.process('Ipotizza: Nova è un neride. | Che cosa possiede Nova?');
    expect(reply.text.toLowerCase(), contains('coda'));
    expect((await memory.stats())['claims'], before);
    expect((await coordinator.process('Nova è un neride?')).status, 'unknown');
  });
  test('first order false belief is separate from the observed world', () async {
    await coordinator.process('Anna mette la palla nella scatola.');
    await coordinator.process('Anna esce.');
    await coordinator.process('Luca mette la palla nella credenza.');
    final belief = await coordinator.process('Dove pensa Anna che sia la palla?');
    expect(belief.status, 'belief'); expect(belief.text, contains('scatola'));
    expect(belief.text, isNot(contains('nella credenza')));
    final world = await coordinator.process('Dove si trova la palla?');
    expect(world.text, contains('credenza'));
  });
  test('stated desire does not become a world fact', () async {
    await coordinator.process('Marco vuole andare a Roma.');
    expect((await memory.stats())['claims'], 0);
    expect((await coordinator.process('Che cosa vuole Marco?')).text.toLowerCase(), contains('roma'));
  });
  test('finite narrative constructions retain original provenance', () async {
    final learned = await memory.ingestText('Dopo aver lasciato il porto, Ada consegnò a Bruno la mappa che aveva trovato. Bruno la ripose nello zaino prima di salutare Ada.');
    final reply = await coordinator.process('A chi Ada consegnò la mappa?', scope: learned['source'] as String);
    expect(reply.text.toLowerCase(), contains('bruno'));
    expect(reply.evidence.any((e) => '${e['text']}'.contains('Dopo aver')), true);
    final where = await coordinator.process('Dove si trova la mappa?', scope: learned['source'] as String);
    expect(where.text.toLowerCase(), contains('zaino'));
  });
  for (final sentence in [
    'Ada consegnò a Bruno la mappa.',
    'Ada consegnò a Bruno la mappa che aveva trovato.',
  ]) {
    test('recipient survives clause reordering: $sentence', () async {
      final learned = await memory.ingestText(sentence);
      final reply = await coordinator.process('A chi Ada consegnò la mappa?',
          scope: learned['source'] as String);
      expect(reply.status, 'direct');
      expect(reply.text, contains('Bruno'));
      expect(reply.evidence.single['text'], sentence);
    });
  }
  test('explicit arithmetic and color facts are source-backed', () async {
    await memory.ingestText('Il deposito ospitava sette casse, ma due furono trasferite al molo. Ada osservò la lanterna rossa accanto alla finestra.');
    expect((await coordinator.process('Quante casse rimasero nel deposito?')).text, '5');
    expect((await coordinator.process('Di che colore era la lanterna?')).text, 'rossa');
  });
  test('snapshot restore is atomic and deletion removes all dependent data', () async {
    final learned = await memory.ingestText('La glarpa produce latte.');
    final snapshot = await memory.export();
    final damaged = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    (damaged['claims'] as List).first['unit'] = 'missing';
    await expectLater(memory.restore(damaged), throwsA(anything));
    expect((await memory.stats())['claims'], 1);
    await memory.deleteSource(learned['source'] as String);
    expect((await memory.stats())['claims'], 0);
    await memory.restore(snapshot);
    expect((await coordinator.process('Che cosa produce la glarpa?')).text, contains('latte'));
  });
  test('retrieval exceeding budget never presents absence as a certain answer', () async {
    final lines = List.generate(210, (i) => 'La gemma contiene materiale$i.').join('\n');
    await memory.ingestText(lines);
    expect((await coordinator.process('Che cosa contiene la gemma?')).status, 'budget');
  });
  test('MGD ablation has the same admission policy', () async {
    final baseline = await CanonicalMemory420.open(path: '${dir.path}/baseline.db', factory: databaseFactoryFfi, useMgd: false);
    try {
      final other = await CognitiveCoordinator420.create(baseline);
      const text = 'Il lorvante contiene cristalli.';
      await memory.ingestText(text); await baseline.ingestText(text);
      final a = await coordinator.process('Che cosa contiene il lorvante?');
      final b = await other.process('Che cosa contiene il lorvante?');
      expect(a.text, b.text);
      expect((await baseline.stats())['flux'], 0);
    } finally { await baseline.close(); }
  });
  test('frequent unrelated predicates do not exhaust a precise query', () async {
    await memory.ingestText(List.generate(220,
      (i) => 'Il recipiente$i contiene minerale$i.').join('\n'));
    await memory.ingestText('Il lorvante contiene cristalli.');
    final reply = await coordinator.process('Che cosa contiene il lorvante?');
    expect(reply.status, 'direct');
    expect(reply.text, contains('cristalli'));
    expect(reply.candidates, lessThan(10));
  });
  test('a frequent actor does not hide an explicitly identified object', () async {
    final learned = await memory.ingestText(
      'Ada consegnò la mappa a Bruno.\n${List.generate(210,
        (i) => 'Ada consegnò il foglio$i a Carla.').join('\n')}');
    final reply = await coordinator.process('A chi Ada consegnò la mappa?',
      scope: learned['source'] as String);
    expect(reply.status, 'direct'); expect(reply.text.toLowerCase(), contains('bruno'));
    expect(reply.candidates, lessThan(10));
  });
  test('common nouns are not invented as social observers', () async {
    await coordinator.process('La capsula contiene quarzo.');
    expect(await coordinator.social.presentAgents(), isEmpty);
  });
}
