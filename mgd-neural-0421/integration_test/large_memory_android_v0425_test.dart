import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mgd_neuro_mobile/main.dart';
import 'package:mgd_neuro_mobile/knowledge_inspector_v0315.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/mgd_state_store_v026.dart';
import 'package:mgd_neuro_mobile/memory_runtime_v0319.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'restored_app_android_v0421_test.dart' show sendTopic423, reply423, keyboardClosed421;

const stressCount425 = 50000;

/// Generate a coherent synthetic saved state by extending a real taught fact.
/// This exercises cold restoration, not training/biology accuracy. All IDs,
/// candidates, episode references and lexical edges are valid and unique.
Map<String, Uint8List> stressCheckpoint425() {
  final b = PlasticLanguageBrain04(), w = MgdWorld06();
  b.importTeacherFact08(subject: 'Campione 0', relation: 'contiene',
      object: 'Organello comune', confidence: .95, source: 'stress425');
  final slot = b.slots.values.single;
  final sid = slot.subjectId;
  final oid = b.ensureSemanticEntity06('Organello comune');
  w.importTeacherSemanticLink08(sid, oid, .55, confidence: .95);
  final raw = b.toJson(), world = w.toJson();
  final entities = raw['entities'] as List, assemblies = raw['assemblies'] as List;
  final slots = raw['slots'] as List, episodes = raw['episodes'] as List;
  final temporal = raw['temporal'] as List, associative = raw['associative'] as List;
  final edges = world['edges'] as List;
  final entityTemplate = Map<String, dynamic>.from(entities[sid]);
  final slotTemplate = Map<String, dynamic>.from(slots.single);
  final candidate = Map<String, dynamic>.from((slotTemplate['candidates'] as List).single);
  final epTemplate = Map<String, dynamic>.from(episodes.single);
  final worldTemplate = Map<String, dynamic>.from(edges.single);
  final zero = assemblies.indexWhere((a) => a['token'] == '0');
  final zeroTemplate = Map<String, dynamic>.from(assemblies[zero]);
  final edgeTemplate = Map<String, dynamic>.from(temporal.first);
  final tokenIds = List<int>.from(epTemplate['tokenIds']);
  final otherToken = tokenIds.firstWhere((id) => id != zero);
  for (var n = 1; n < stressCount425; n++) {
    final eid = entities.length, tid = assemblies.length;
    entities.add({...entityTemplate, 'id': eid, 'key': 'campione $n',
      'label': 'Campione $n', 'aliases': <String>[]});
    assemblies.add({...zeroTemplate, 'id': tid, 'token': '$n', 'surface': '$n'});
    slots.add({...slotTemplate, 'subjectId': eid,
      'candidates': [{...candidate, 'sourceEpisodes': [n + 1]}]});
    episodes.add({...epTemplate, 'id': n + 1, 'subjectId': eid,
      'userText': '[teacher:stress425] Campione $n contiene Organello comune',
      'tokenIds': tokenIds.map((id) => id == zero ? tid : id).toList()});
    temporal.add({...edgeTemplate, 'from': otherToken, 'to': tid});
    temporal.add({...edgeTemplate, 'from': tid, 'to': otherToken});
    associative.add({...edgeTemplate, 'from': tid, 'to': otherToken});
    associative.add({...edgeTemplate, 'from': otherToken, 'to': tid});
    edges.add({...worldTemplate, 'a': 'e:$eid', 'b': 'e:$oid'});
  }
  raw['nextEpisodeId'] = stressCount425 + 1;
  final r = ResearchMemory11(enabled: false);
  r.state317['migrationComplete'] = true;
  return {'brain_v051': encodeSnapshot425(raw), 'world_v06': encodeSnapshot425(world),
    'research_v11': encodeSnapshot425(r.toJson()),
    'language_v20': encodeSnapshot425(MgdLanguage20().toJson())};
}

Future<void> boot425(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 120));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(InspectorScope315).evaluate().isNotEmpty) return;
    if (find.text('Memoria protetta: caricamento non riuscito').evaluate().isNotEmpty) {
      fail('Cold boot failed: ${find.byType(SelectableText).evaluate().map((e) => (e.widget as SelectableText).data)}');
    }
  }
  fail('50000-fact cold boot did not finish within 120 seconds.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('50000 saved facts: legacy and chunked cold restore stay responsive and usable',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.close319();
    final documents = await getApplicationDocumentsDirectory();
    final path = '${documents.path}/mgd_neuro_v026.db';
    await deleteDatabase(path);
    final encoded = await Isolate.run(stressCheckpoint425);
    final size = encoded.values.fold<int>(0, (n, b) => n + b.length);
    // Start with the exact large single-BLOB format of 0.42.4, schema v1.
    final old = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE state_snapshots(k TEXT PRIMARY KEY,payload BLOB NOT NULL,updated_at INTEGER NOT NULL)');
      await db.execute('CREATE TABLE graph_nodes(space TEXT,node TEXT,weight REAL,PRIMARY KEY(space,node))');
      await db.execute('CREATE TABLE graph_edges(space TEXT,src TEXT,rel TEXT,dst TEXT,weight REAL,PRIMARY KEY(space,src,rel,dst))');
    });
    for (final e in encoded.entries) {
      await old.insert('state_snapshots', {'k': e.key, 'payload': e.value, 'updated_at': 1});
    }
    await old.close();
    final records = <Map<String, dynamic>>[];
    for (final format in ['legacy_blob', 'chunked_checkpoint']) {
      var pulses = 0, maxGap = 0;
      var previous = DateTime.now();
      final clock = Stopwatch()..start();
      final pulse = Timer.periodic(const Duration(milliseconds: 20), (_) {
        final now = DateTime.now(), gap = now.difference(previous).inMilliseconds;
        if (gap > maxGap) maxGap = gap;
        previous = now; pulses++;
      });
      await tester.pumpWidget(const MgdNeuro04App());
      try { await boot425(tester); } finally { pulse.cancel(); }
      final tail = DateTime.now().difference(previous).inMilliseconds;
      if (tail > maxGap) maxGap = tail;
      final inspector = tester.widget<InspectorScope315>(find.byType(InspectorScope315)).inspector;
      expect(inspector.brain.slots.length, stressCount425);
      expect(inspector.world.edges.length, stressCount425);
      expect(inspector.brain.episodes.length, stressCount425);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text('MGD Neuro 0.42.5'), findsOneWidget);
      expect(pulses, greaterThan(10));
      expect(maxGap, lessThan(1500), reason: 'UI event loop must stay responsive during real persisted restoration.');
      records.add({'format': format, 'bytes': size, 'facts': stressCount425,
        'elapsed_ms': clock.elapsedMilliseconds, 'max_ui_gap_ms': maxGap, 'pulses': pulses});
      await sendTopic423(tester, 'Campione 49999');
      final reply = await reply423(tester, 'Campione 49999');
      expect(reply.text, contains('Organello comune'));
      expect(reply.text, isNot(contains('IN CONFLITTO')));
      await tester.tap(find.text('Mappa'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'Campione 49999');
      await tester.tap(find.byTooltip('Cerca'));
      await keyboardClosed421(tester);
      expect(find.textContaining(RegExp(r'Focus:\s*Campione 49999\b', caseSensitive: false)), findsWidgets);
      expect(find.byKey(const ValueKey('knowledge-map-nodes')), findsOneWidget);
      await MemoryCheckpoint319().save(inspector.brain, inspector.world, inspector.research, inspector.language);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      await store.close319();
    }
    final temp = await getTemporaryDirectory();
    await File('${temp.path}/large-memory425.json').writeAsString(jsonEncode(records));
    print('LARGE_MEMORY425 ${jsonEncode(records)}');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
