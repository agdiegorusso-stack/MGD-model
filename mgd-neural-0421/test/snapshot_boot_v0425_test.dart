import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/mgd_state_store_v026.dart';
import 'package:mgd_neuro_mobile/memory_boot_v0425.dart';
import 'package:mgd_neuro_mobile/memory_runtime_v0319.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  final store = MgdStateStore26.instance;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mgd-boot425-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  tearDown(() async {
    await store.close319();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    await dir.delete(recursive: true);
  });

  test('large snapshots are chunked, reopened and restored without a UI decode', () async {
    final b = PlasticLanguageBrain04();
    b.importTeacherFact08(subject: 'Cellula X', relation: 'contiene', object: 'nucleo');
    b.importTeacherFact08(subject: 'Cellula X', relation: 'contiene', object: 'mitocondrio');
    final maps = memorySnapshotMaps425(b, MgdWorld06(), ResearchMemory11(), MgdLanguage20());
    maps['brain_v051']!['largeTestPayload425'] = 'x' * (12 * 1024 * 1024);
    await store.putMapsAtomic319(maps);
    final db = await openDatabase('${dir.path}/mgd_neuro_v026.db');
    final sizes = await db.rawQuery('SELECT MAX(length(payload)) AS n, COUNT(*) AS c FROM snapshot_parts425');
    expect(sizes.single['n'], lessThanOrEqualTo(262144));
    expect(sizes.single['c'], greaterThan(48));
    await store.close319();
    var ticks = 0;
    final pulse = Timer.periodic(const Duration(milliseconds: 10), (_) => ticks++);
    late LoadedMemory425 restored;
    try { restored = await MemoryBoot425.load(); } finally { pulse.cancel(); }
    expect(ticks, greaterThan(2));
    expect(restored.brain.slots.values.single.candidates.length, 2);
    expect(restored.language.sentences, greaterThan(0));
    expect(dir.listSync().whereType<Directory>().where((d) => d.path.contains('mgd-restore425-')), isEmpty);
  });

  test('an interrupted multi-memory checkpoint rolls back every changed part', () async {
    await store.putMapsAtomic319({'a': {'v': 'previous'}, 'b': {'v': 'previous'}});
    await expectLater(store.putEncodedAtomic341({
      'a': encodeSnapshot425({'v': 'replacement' * 40000}),
      'b': Uint8List(0),
    }), throwsStateError);
    expect(await store.getMap('a'), {'v': 'previous'});
    expect(await store.getMap('b'), {'v': 'previous'});
  });

  test('existing large BLOBs remain readable through bounded slices', () async {
    await store.putMap('init', {'v': 1});
    final db = await openDatabase('${dir.path}/mgd_neuro_v026.db');
    final original = {'text': 'memoria' * 500000};
    await db.insert('state_snapshots', {'k': 'old',
      'payload': encodeSnapshot425(original), 'updated_at': 1});
    final files = await store.exportForRestore425(['old']);
    try {
      expect(decodeSnapshot425(await File(files.files['old']!).readAsBytes()), original);
    } finally { await files.dispose(); }
    expect(await store.getMap('old'), original);
  });

  test('missing snapshot parts fail explicitly without replacing saved memory', () async {
    await store.putMap('brain_v051', {'padding': 'x' * 900000});
    final db = await openDatabase('${dir.path}/mgd_neuro_v026.db');
    await db.delete('snapshot_parts425', where: 'k=? AND part=?', whereArgs: ['brain_v051', 1]);
    await expectLater(MemoryBoot425.load(), throwsStateError);
    final count = await db.rawQuery('SELECT COUNT(*) AS n FROM snapshot_manifests425 WHERE k=?', ['brain_v051']);
    expect(count.single['n'], 1);
    expect(dir.listSync().whereType<Directory>().where((d) => d.path.contains('mgd-restore425-')), isEmpty);
  });

  test('unknown brain versions protect the archive instead of booting an empty model', () async {
    await store.putMap('brain_v051', {'version': 999});
    await expectLater(MemoryBoot425.load(), throwsFormatException);
    expect(await store.getMap('brain_v051'), {'version': 999});
  });
}
