// BOOK_IMPORT_REPAIR_0341
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Uint8List _encodeBinary26(Map<String, dynamic> map) {
  final data = const StandardMessageCodec().encodeMessage(map);
  if (data == null) return Uint8List(0);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

dynamic _normalizeDecoded26(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries)
        e.key.toString(): _normalizeDecoded26(e.value)
    };
  }
  if (value is List) return value.map(_normalizeDecoded26).toList();
  return value;
}

Map<String, dynamic> _decodeBinary26(Uint8List bytes) {
  final bd = ByteData.sublistView(bytes);
  final raw = const StandardMessageCodec().decodeMessage(bd);
  return Map<String, dynamic>.from(_normalizeDecoded26(raw) as Map);
}

// Invoked in the restoration/checkpoint isolate, never on the UI.
Map<String, dynamic> decodeSnapshot425(Uint8List bytes) => _decodeBinary26(bytes);
Uint8List encodeSnapshot425(Map<String, dynamic> map) => _encodeBinary26(map);

class SnapshotFiles425 {
  final String directory;
  final Map<String, String> files;
  final Map<String, int> sizes;
  SnapshotFiles425(this.directory, this.files, this.sizes);
  Future<void> dispose() async {
    final dir = Directory(directory);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

class MgdStateStore26 {
  MgdStateStore26._();
  static final MgdStateStore26 instance = MgdStateStore26._();
  Database? _db;
  Future<Database>? _opening;

  Future<Database> _open() {
    final ready = _db;
    if (ready != null && ready.isOpen) return Future.value(ready);
    _db = null;
    return _opening ??= _openInner().whenComplete(() => _opening = null);
  }

  Future<Database> _openInner() async {
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      '${dir.path}/mgd_neuro_v026.db',
      version: 2,
      onConfigure: (db) async {
        // IMPORTANT on Android: journal_mode is a row-returning PRAGMA.
        // execute()/execSQL() throws:
        // "Queries can be performed using SQLiteDatabase query or rawQuery methods only."
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=NORMAL');
        await db.execute('PRAGMA temp_store=MEMORY');
        await db.execute('PRAGMA foreign_keys=ON');
      },
      onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE state_snapshots (k TEXT PRIMARY KEY, payload BLOB NOT NULL, updated_at INTEGER NOT NULL)');
        await db.execute(
            'CREATE TABLE graph_nodes (space TEXT NOT NULL, node TEXT NOT NULL, weight REAL NOT NULL DEFAULT 0, PRIMARY KEY(space,node))');
        await db.execute(
            'CREATE TABLE graph_edges (space TEXT NOT NULL, src TEXT NOT NULL, rel TEXT NOT NULL, dst TEXT NOT NULL, weight REAL NOT NULL, PRIMARY KEY(space,src,rel,dst))');
        await db.execute(
            'CREATE INDEX graph_edges_src_idx ON graph_edges(space,src)');
        await db.execute(
            'CREATE INDEX graph_edges_dst_idx ON graph_edges(space,dst)');
        await _createParts425(db);
      },
      onUpgrade: (db, old, _) async {
        if (old < 2) await _createParts425(db);
      },
    );
    _db = db;
    return db;
  }

  static const snapshotPartBytes425 = 262144;
  static Future<void> _createParts425(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS snapshot_manifests425 '
        '(k TEXT PRIMARY KEY, bytes INTEGER NOT NULL, parts INTEGER NOT NULL, updated_at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS snapshot_parts425 '
        '(k TEXT NOT NULL, part INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(k,part))');
  }

  Future<Map<String, int>> _sizes425(DatabaseExecutor db, String key) async {
    final chunked = await db.query('snapshot_manifests425',
        columns: ['bytes', 'parts'], where: 'k=?', whereArgs: [key]);
    if (chunked.isNotEmpty) {
      return {'bytes': chunked.single['bytes'] as int,
        'parts': chunked.single['parts'] as int};
    }
    final old = await db.rawQuery(
        'SELECT length(payload) AS n FROM state_snapshots WHERE k=?', [key]);
    return old.isEmpty ? {} : {'bytes': old.single['n'] as int};
  }

  Future<void> _readParts425(DatabaseExecutor db, String key,
      Map<String, int> info, Future<void> Function(Uint8List) consume) async {
    final n = info['bytes']!;
    if (n <= 0) throw StateError('Archivio $key presente ma vuoto.');
    final parts = info['parts'];
    if (parts != null && parts != (n + snapshotPartBytes425 - 1) ~/ snapshotPartBytes425) {
      throw StateError('Manifesto archivio $key incoerente.');
    }
    var read = 0;
    for (var offset = 0; offset < n; offset += snapshotPartBytes425) {
      final rows = parts != null
          ? await db.query('snapshot_parts425', columns: ['payload'],
              where: 'k=? AND part=?', whereArgs: [key, offset ~/ snapshotPartBytes425])
          : await db.rawQuery(
              'SELECT substr(payload,?,?) AS payload FROM state_snapshots WHERE k=?',
              [offset + 1, snapshotPartBytes425, key]);
      final expected = n - offset < snapshotPartBytes425 ? n - offset : snapshotPartBytes425;
      final part = rows.length == 1 ? rows.single['payload'] : null;
      if (part is! Uint8List || part.length != expected) {
        throw StateError('Archivio $key incompleto al blocco ${offset ~/ snapshotPartBytes425}.');
      }
      await consume(part);
      read += part.length;
    }
    if (read != n) throw StateError('Dimensione archivio $key incoerente.');
  }

  /// Read one consistent checkpoint with bounded channel messages and IO.
  /// Only temporary file paths are passed to the restoration isolate.
  Future<SnapshotFiles425> exportForRestore425(List<String> keys,
      {void Function(String key, int read, int total)? onProgress}) async {
    final temp = await getTemporaryDirectory();
    await temp.create(recursive: true);
    final dir = await temp.createTemp('mgd-restore425-');
    final files = <String, String>{}, sizes = <String, int>{};
    try {
      final db = await _open();
      await db.transaction((tx) async {
        for (var i = 0; i < keys.length; i++) {
          final key = keys[i], info = await _sizes425(tx, keys[i]);
          if (info.isEmpty) continue;
          final file = File('${dir.path}/$i.bin');
          final handle = await file.open(mode: FileMode.write);
          var done = 0;
          try {
            await _readParts425(tx, key, info, (part) async {
              await handle.writeFrom(part);
              done += part.length;
              onProgress?.call(key, done, info['bytes']!);
            });
          } finally {
            await handle.close();
          }
          files[key] = file.path;
          sizes[key] = info['bytes']!;
        }
      });
      return SnapshotFiles425(dir.path, files, sizes);
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getMap(String key) async {
    final db = await _open();
    final payload = await db.transaction<Uint8List?>((tx) async {
      final info = await _sizes425(tx, key);
      if (info.isEmpty) return null;
      final out = BytesBuilder(copy: false);
      await _readParts425(tx, key, info, (part) async { out.add(part); });
      return out.takeBytes();
    });
    return payload == null ? null : compute(_decodeBinary26, payload);
  }

  /// Presence checks do not decode an entire historical checkpoint.
  Future<bool> hasSnapshot425(String key) async {
    final info = await _sizes425(await _open(), key);
    return info.isNotEmpty && info['bytes']! > 0;
  }

  /// All memories commit together; each batch has at most eight 256 KiB parts.
  Future<void> putEncodedAtomic341(Map<String, Uint8List> encoded) async {
    final db = await _open();
    await db.transaction((tx) async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (final entry in encoded.entries) {
        if (entry.value.isEmpty) throw StateError('Snapshot ${entry.key} vuoto.');
        await tx.delete('snapshot_parts425', where: 'k=?', whereArgs: [entry.key]);
        var batch = tx.batch(), inBatch = 0, parts = 0;
        for (var offset = 0; offset < entry.value.length; offset += snapshotPartBytes425) {
          final end = offset + snapshotPartBytes425 < entry.value.length
              ? offset + snapshotPartBytes425 : entry.value.length;
          batch.insert('snapshot_parts425', {'k': entry.key, 'part': parts++,
            'payload': Uint8List.sublistView(entry.value, offset, end)});
          if (++inBatch == 8) {
            await batch.commit(noResult: true);
            batch = tx.batch(); inBatch = 0;
          }
        }
        if (inBatch > 0) await batch.commit(noResult: true);
        await tx.insert('snapshot_manifests425', {'k': entry.key,
          'bytes': entry.value.length, 'parts': parts, 'updated_at': stamp},
          conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.delete('state_snapshots', where: 'k=?', whereArgs: [entry.key]);
      }
    });
  }

  Future<void> putMap(String key, Map<String, dynamic> map) async {
    final payload = await compute(_encodeBinary26, map);
    await putEncodedAtomic341({key: payload});
  }

  Future<void> putMapsAtomic319(Map<String, Map<String, dynamic>> maps) async {
    final encoded = <String, Uint8List>{};
    for (final entry in maps.entries) {
      encoded[entry.key] = await compute(_encodeBinary26, entry.value);
    }
    await putEncodedAtomic341(encoded);
  }

  Future<void> close319() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }

  Future<void> deleteKey(String key) async {
    final db = await _open();
    await db.transaction((tx) async {
      await tx.delete('snapshot_parts425', where: 'k=?', whereArgs: [key]);
      await tx.delete('snapshot_manifests425', where: 'k=?', whereArgs: [key]);
      await tx.delete('state_snapshots', where: 'k=?', whereArgs: [key]);
    });
  }

  Future<void> replaceGraph(
      {required String space,
      required Iterable<String> nodes,
      required Iterable<({String src, String rel, String dst, double weight})>
          edges}) async {
    final db = await _open();
    await db.transaction((tx) async {
      await tx.delete('graph_edges', where: 'space=?', whereArgs: [space]);
      await tx.delete('graph_nodes', where: 'space=?', whereArgs: [space]);
      final batch = tx.batch();
      for (final n in nodes) {
        batch.insert('graph_nodes', {'space': space, 'node': n, 'weight': 0.0},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final e in edges) {
        batch.insert(
            'graph_edges',
            {
              'space': space,
              'src': e.src,
              'rel': e.rel,
              'dst': e.dst,
              'weight': e.weight
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertGraphDelta271({
    required String space,
    required Iterable<String> nodes,
    required Iterable<({String src, String rel, String dst, double weight})>
        edges,
    int batchSize = 256,
    void Function(int completed, int total)? onProgress,
  }) async {
    final db = await _open();
    final nodeList =
        nodes.where((x) => x.trim().isNotEmpty).toSet().toList(growable: false);
    final edgeList = edges.toList(growable: false);
    final total = nodeList.length + edgeList.length;
    if (total == 0) {
      onProgress?.call(0, 0);
      return;
    }
    var done = 0;

    for (var i = 0; i < nodeList.length; i += batchSize) {
      final end =
          (i + batchSize < nodeList.length) ? i + batchSize : nodeList.length;
      await db.transaction((tx) async {
        final batch = tx.batch();
        for (var j = i; j < end; j++) {
          batch.insert('graph_nodes',
              {'space': space, 'node': nodeList[j], 'weight': 0.0},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult: true);
      });
      done += end - i;
      onProgress?.call(done, total);
      await Future<void>.delayed(Duration.zero);
    }

    for (var i = 0; i < edgeList.length; i += batchSize) {
      final end =
          (i + batchSize < edgeList.length) ? i + batchSize : edgeList.length;
      await db.transaction((tx) async {
        final batch = tx.batch();
        for (var j = i; j < end; j++) {
          final e = edgeList[j];
          batch.insert(
              'graph_edges',
              {
                'space': space,
                'src': e.src,
                'rel': e.rel,
                'dst': e.dst,
                'weight': e.weight
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
      done += end - i;
      onProgress?.call(done, total);
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> clearAll() async {
    final db = await _open();
    await db.transaction((tx) async {
      await tx.delete('state_snapshots');
      await tx.delete('snapshot_parts425');
      await tx.delete('snapshot_manifests425');
      await tx.delete('graph_edges');
      await tx.delete('graph_nodes');
    });
  }
}
