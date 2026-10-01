import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'cls_core_v0340.dart';

Uint8List pack340(Object value) {
  final b = const StandardMessageCodec().encodeMessage(value)!;
  return b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
}

Cue340 unpackCue340(Object value) {
  final b = value as Uint8List;
  final m = const StandardMessageCodec().decodeMessage(ByteData.sublistView(b))
      as Map;
  return m.map((k, v) => MapEntry(k.toString(),
      (v as Map).map((a, b) => MapEntry(a.toString(), (b as num).toDouble()))));
}

Pattern340 pattern340(Map<String, Object?> row) => Pattern340(
    row['id'] as int,
    row['label'] as String,
    row['context'] as String,
    unpackCue340(row['features']!),
    text: row['text'] as String? ?? '',
    source: row['source'] as String? ?? '');

typedef RecallRequest340 = ({
  Cue340 cue,
  List<Pattern340> records,
  String context
});
Recall340 recallWorker340(RecallRequest340 r) =>
    Hopfield340.recall(r.cue, r.records, context: r.context);

class ClsStore340 {
  final Database db;
  ClsStore340._(this.db);
  static Future<ClsStore340>? _shared;
  static Future<ClsStore340> get shared =>
      _shared ??= open().catchError((Object e) {
        _shared = null;
        throw e;
      });
  bool _replaying = false;
  int revision = 0, lastRecallMicros = 0, lastCandidates = 0;
  static const _cols = [
    'id',
    'label',
    'context',
    'text',
    'source',
    'features',
    'created',
    'uid',
    'consolidated'
  ];

  static Future<ClsStore340> open(
      {String? path, DatabaseFactory? factory}) async {
    path ??=
        '${(await getApplicationDocumentsDirectory()).path}/mgd_cls_0340.db';
    final db = await (factory ?? databaseFactory).openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys=ON');
              await db.rawQuery('PRAGMA journal_mode=WAL');
            },
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE episodes(id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT UNIQUE NOT NULL, label TEXT NOT NULL, context TEXT NOT NULL, text TEXT NOT NULL, source TEXT NOT NULL, created TEXT NOT NULL, features BLOB NOT NULL, image BLOB, audio BLOB, signature TEXT NOT NULL, consolidated INTEGER NOT NULL DEFAULT 0, language_delta BLOB)');
              await db.execute(
                  'CREATE INDEX episode_context ON episodes(context,id)');
              await db.execute(
                  'CREATE INDEX episode_label ON episodes(context,label,id)');
              await db.execute(
                  'CREATE INDEX episode_signature ON episodes(context,signature)');
              await db.execute(
                  'CREATE INDEX episode_pending ON episodes(consolidated,id)');
              await db.execute(
                  'CREATE TABLE postings(episode INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE, context TEXT NOT NULL, channel TEXT NOT NULL, feature TEXT NOT NULL, value REAL NOT NULL, PRIMARY KEY(episode,channel,feature))');
              await db.execute(
                  'CREATE INDEX posting_search ON postings(context,channel,feature)');
              await db.execute(
                  'CREATE TABLE prototypes(context TEXT NOT NULL,label TEXT NOT NULL,features BLOB NOT NULL,seen INTEGER NOT NULL,PRIMARY KEY(context,label))');
              await db.execute(
                  'CREATE TABLE grams(context TEXT NOT NULL,suffix TEXT NOT NULL,token TEXT NOT NULL,n INTEGER NOT NULL,PRIMARY KEY(context,suffix,token))');
              await db.execute(
                  'CREATE TABLE legacy(uid TEXT PRIMARY KEY,episode INTEGER REFERENCES episodes(id) ON DELETE SET NULL)');
              await db.execute(
                  'CREATE TABLE audit(id INTEGER PRIMARY KEY,episode INTEGER REFERENCES episodes(id) ON DELETE CASCADE,old_label TEXT,new_label TEXT,at TEXT)');
              await db.execute(
                  'CREATE TABLE settings(k TEXT PRIMARY KEY,v TEXT NOT NULL)');
            }));
    return ClsStore340._(db);
  }

  Future<void> close() => db.close();
  static String _signature(Cue340 cue) {
    final channels = cue.keys.toList()..sort();
    final sorted = {
      for (final c in channels)
        c: {for (final k in (cue[c]!.keys.toList()..sort())) k: cue[c]![k]}
    };
    return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
  }

  Future<int> learn(Cue340 input,
      {required String label,
      String context = 'generale',
      String text = '',
      String source = 'Conferma utente',
      String? uid,
      String? created,
      Uint8List? image,
      Uint8List? audio}) async {
    if (label.trim().isEmpty ||
        label.length > 160 ||
        context.trim().isEmpty ||
        context.length > 160 ||
        source.length > 2000 ||
        text.length > 32000) {
      throw ArgumentError(
          'Nome, contesto o dimensione dell’episodio non validi.');
    }
    if ((image?.length ?? 0) > 12 * 1024 * 1024 ||
        (audio?.length ?? 0) > 4 * 1024 * 1024) {
      throw ArgumentError('Allegato troppo grande per un singolo episodio.');
    }
    final cue = Hopfield340.normalize(input),
        c = norm340(context),
        l = norm340(label);
    final signature = _signature(cue);
    final key = uid ??
        sha256
            .convert(utf8
                .encode('$c\u0000$l\u0000$text\u0000$source\u0000$signature'))
            .toString();
    final id = await db.transaction((tx) async {
      final old = await tx.query('episodes',
          columns: ['id'], where: 'uid=?', whereArgs: [key]);
      if (old.isNotEmpty) return old.first['id'] as int;
      final id = await tx.insert('episodes', {
        'uid': key,
        'label': l,
        'context': c,
        'text': text,
        'source': source,
        'created': created ?? DateTime.now().toUtc().toIso8601String(),
        'features': pack340(cue),
        'image': image,
        'audio': audio,
        'signature': signature
      });
      final batch = tx.batch();
      for (final channel in cue.entries) {
        for (final feature in channel.value.entries) {
          batch.insert('postings', {
            'episode': id,
            'context': c,
            'channel': channel.key,
            'feature': feature.key,
            'value': feature.value
          });
        }
      }
      await batch.commit(noResult: true);
      return id;
    });
    revision++;
    return id;
  }

  /// Idempotent and resumable. Tombstones in `legacy` prevent resurrection of
  /// deleted migrated records. Original v0.33 snapshots are left untouched.
  Future<int> migrateLegacy(Iterable<Map<String, dynamic>> rows) async {
    var n = 0;
    for (final e in rows) {
      final uid = 'legacy33:${e['id']}';
      if ((await db.query('legacy', where: 'uid=?', whereArgs: [uid]))
          .isNotEmpty) continue;
      final cue = (e['features'] as Map).map((k, v) => MapEntry(
          k.toString(),
          (v as Map)
              .map((a, b) => MapEntry(a.toString(), (b as num).toDouble()))));
      final id = await learn(cue,
          label: e['label'] as String,
          context: e['context'] as String,
          text: e['description'] as String? ?? '',
          source: e['source'] as String? ?? 'Archivio 0.33',
          created: e['at'] as String?,
          uid: uid);
      await db.insert('legacy', {'uid': uid, 'episode': id},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      n++;
      if (n % 16 == 0) await Future<void>.delayed(Duration.zero);
    }
    return n;
  }

  Future<List<Map<String, Object?>>> page(
      {int after = 0,
      int limit = 64,
      String query = '',
      String? context}) async {
    if (limit < 1 || limit > 512)
      throw ArgumentError('Dimensione pagina non valida.');
    final where = ['id>?'], args = <Object?>[after];
    if (context != null) {
      where.add('context=?');
      args.add(norm340(context));
    }
    if (query.trim().isNotEmpty) {
      where.add('(instr(lower(text),?)>0 OR instr(label,?)>0)');
      args.addAll([norm340(query), norm340(query)]);
    }
    return db.query('episodes',
        columns: _cols,
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'id',
        limit: limit);
  }

  Future<Map<String, Object?>?> get(int id) async {
    final rows = await db.query('episodes', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Pattern340>> candidates(Cue340 input,
      {String context = 'generale', int budget = 128}) async {
    if (budget < 8 || budget > 512) throw ArgumentError('Budget non valido.');
    final cue = Hopfield340.normalize(input), c = norm340(context);
    final terms = <List<Object>>[];
    for (final m in cue.entries) {
      final ranked = m.value.entries.toList()
        ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
      for (final f in ranked.take(48)) {
        terms.add([m.key, f.key, f.value]);
      }
    }
    final values = List.filled(terms.length, '(?,?,?)').join(',');
    final rows = await db.rawQuery(
        'WITH q(channel,feature,value) AS (VALUES $values) SELECT p.episode AS id,SUM(p.value*q.value) AS relevance FROM postings p JOIN q ON p.channel=q.channel AND p.feature=q.feature WHERE p.context=? GROUP BY p.episode ORDER BY relevance DESC,p.episode ASC LIMIT ?',
        [...terms.expand((x) => x), c, budget]);
    final ids = rows.map((r) => r['id'] as int).toSet();
    // Exact full-cue matches have an independent indexed route, including rare
    // conflicting labels that might otherwise be hidden by a top-k shortlist.
    final exact = await db.rawQuery(
        'SELECT MIN(id) AS id FROM episodes WHERE context=? AND signature=? GROUP BY label LIMIT ?',
        [c, _signature(cue), budget]);
    for (final r in exact) {
      ids.add(r['id'] as int);
    }
    if (ids.isEmpty) return [];
    final selected = await db.query('episodes',
        columns: _cols,
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids.toList());
    return selected.map(pattern340).toList();
  }

  Future<Recall340> recall(Cue340 cue,
      {String context = 'generale', int budget = 128}) async {
    final timer = Stopwatch()..start();
    final records = await candidates(cue, context: context, budget: budget);
    lastCandidates = records.length;
    final result = await compute(
        recallWorker340, (cue: cue, records: records, context: context));
    lastRecallMicros = timer.elapsedMicroseconds;
    return result;
  }

  Future<Recall340> recallSlow(Cue340 cue,
      {String context = 'generale'}) async {
    final rows = await db.query('prototypes',
        where: 'context=?',
        whereArgs: [norm340(context)],
        orderBy: 'seen DESC,label',
        limit: 128);
    return compute(recallWorker340, (
      cue: cue,
      records: List.generate(
          rows.length,
          (i) => Pattern340(-i - 1, rows[i]['label'] as String,
              norm340(context), unpackCue340(rows[i]['features']!),
              source:
                  'Prototipo lento: ${rows[i]['seen']} episodi consolidati')),
      context: context
    ));
  }

  static Cue340 _slowUpdate(Cue340 old, Cue340 incoming) {
    final out = <String, Map<String, double>>{
      for (final e in old.entries) e.key: Map.of(e.value)
    };
    for (final ch in incoming.entries) {
      final previous = out[ch.key];
      if (previous == null) {
        out[ch.key] = Map.of(ch.value);
        continue;
      }
      final next = <String, double>{};
      for (final k in {...previous.keys, ...ch.value.keys}) {
        next[k] = .9 * (previous[k] ?? 0) + .1 * (ch.value[k] ?? 0);
      }
      final ranked = next.entries.toList()
        ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
      out[ch.key] = Map.fromEntries(ranked.take(512));
    }
    return Hopfield340.normalize(out);
  }

  /// Slow memory consumes bounded batches; fast episodic evidence is never
  /// overwritten. A record is incorporated once, not once per replay tick.
  Future<int> consolidate({int budget = 8}) async {
    if (budget < 1 || budget > 64)
      throw ArgumentError('Budget di ripasso non valido.');
    if (_replaying) return 0;
    _replaying = true;
    try {
      final count = await db.transaction((tx) async {
        final rows = await tx.query('episodes',
            where: 'consolidated=0', orderBy: 'id', limit: budget);
        for (final e in rows) {
          final c = e['context'] as String, l = e['label'] as String;
          final prior = await tx.query('prototypes',
              where: 'context=? AND label=?', whereArgs: [c, l]);
          final input = unpackCue340(e['features']!);
          final next = prior.isEmpty
              ? input
              : _slowUpdate(unpackCue340(prior.first['features']!), input);
          await tx.insert(
              'prototypes',
              {
                'context': c,
                'label': l,
                'features': pack340(next),
                'seen': prior.isEmpty ? 1 : (prior.first['seen'] as int) + 1
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
          if (e['language_delta'] == null) {
            final delta = Italian340.transitions(e['text'] as String);
            final batch = tx.batch();
            for (final g in delta.entries) {
              final i = g.key.indexOf('\u0000');
              final suffix = g.key.substring(0, i),
                  token = g.key.substring(i + 1);
              batch.rawInsert(
                  'INSERT INTO grams(context,suffix,token,n) VALUES(?,?,?,?) ON CONFLICT(context,suffix,token) DO UPDATE SET n=n+excluded.n',
                  [c, suffix, token, g.value]);
            }
            batch.update('episodes', {'language_delta': pack340(delta)},
                where: 'id=?', whereArgs: [e['id']]);
            await batch.commit(noResult: true);
          }
          await tx.update('episodes', {'consolidated': 1},
              where: 'id=?', whereArgs: [e['id']]);
        }
        return rows.length;
      });
      if (count > 0) revision++;
      return count;
    } finally {
      _replaying = false;
    }
  }

  Future<void> _invalidate(
      DatabaseExecutor tx, String context, String label) async {
    await tx.delete('prototypes',
        where: 'context=? AND label=?', whereArgs: [context, label]);
    await tx.update('episodes', {'consolidated': 0},
        where: 'context=? AND label=?', whereArgs: [context, label]);
  }

  Future<void> correct(int id, String label) async {
    if (label.trim().isEmpty || label.length > 160)
      throw ArgumentError('Nome non valido.');
    await db.transaction((tx) async {
      final rows = await tx.query('episodes', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Episodio non presente.');
      final e = rows.single, c = e['context'] as String, l = norm340(label);
      await tx.insert('audit', {
        'episode': id,
        'old_label': e['label'],
        'new_label': l,
        'at': DateTime.now().toUtc().toIso8601String()
      });
      await tx.update('episodes', {'label': l, 'consolidated': 0},
          where: 'id=?', whereArgs: [id]);
      await _invalidate(tx, c, e['label'] as String);
      await _invalidate(tx, c, l);
    });
    revision++;
  }

  Future<void> delete(int id) async {
    await db.transaction((tx) async {
      final rows = await tx.query('episodes', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final e = rows.single;
      if (e['language_delta'] is Uint8List) {
        final bytes = e['language_delta'] as Uint8List;
        final delta = const StandardMessageCodec()
            .decodeMessage(ByteData.sublistView(bytes)) as Map;
        final batch = tx.batch();
        for (final g in delta.entries) {
          final key = g.key as String, i = key.indexOf('\u0000');
          batch.rawUpdate(
              'UPDATE grams SET n=n-? WHERE context=? AND suffix=? AND token=?',
              [
                g.value,
                e['context'],
                key.substring(0, i),
                key.substring(i + 1)
              ]);
        }
        batch.delete('grams', where: 'n<=0');
        await batch.commit(noResult: true);
      }
      await tx.delete('episodes', where: 'id=?', whereArgs: [id]);
      await _invalidate(tx, e['context'] as String, e['label'] as String);
    });
    revision++;
  }

  Future<List<Map<String, Object?>>> nextWords(String prefix,
      {String context = 'generale'}) async {
    var history = Italian340.tokens(prefix);
    if (history.isEmpty) history = ['<s>'];
    for (var n = min(3, history.length); n >= 0; n--) {
      final suffix = history.sublist(history.length - n).join(' ');
      final rows = await db.query('grams',
          columns: ['token', 'n'],
          where: 'context=? AND suffix=?',
          whereArgs: [norm340(context), suffix],
          orderBy: 'n DESC,token',
          limit: 12);
      if (rows.isNotEmpty) return rows;
    }
    return [];
  }

  Future<String> continueText(String prefix,
      {String context = 'generale', int words = 40}) async {
    if (words < 1 || words > 160)
      throw ArgumentError('Budget di generazione non valido.');
    final out = Italian340.tokens(prefix), visits = <String, int>{};
    for (var i = 0; i < words; i++) {
      final rows = await nextWords(out.join(' '), context: context);
      if (rows.isEmpty) break;
      String? selected;
      for (final row in rows) {
        final t = row['token'] as String;
        final state = '${out.skip(max(0, out.length - 3)).join(' ')}\u0000$t';
        if ((visits[state] ?? 0) >= 2) continue;
        selected = t;
        visits[state] = (visits[state] ?? 0) + 1;
        break;
      }
      if (selected == null || selected == '<e>') break;
      out.add(selected);
      if (i > 3 && {'.', '!', '?'}.contains(selected)) break;
    }
    return out
        .join(' ')
        .replaceAllMapped(RegExp(r'\s+([.,!?;:])'), (m) => m[1]!);
  }

  Future<int> importText(String text,
      {String source = 'Testo utente',
      String context = 'generale',
      String label = 'testo',
      bool Function()? cancelled}) async {
    var n = 0;
    for (final chunk in Italian340.chunks(text)) {
      if (cancelled?.call() ?? false) break;
      final f = Italian340.features(chunk);
      if (f.isEmpty) continue;
      await learn({'text:v1': f},
          label: label, context: context, text: chunk, source: source);
      n++;
      if (n % 16 == 0) await Future<void>.delayed(Duration.zero);
    }
    return n;
  }

  Future<int> importFile(File file,
      {String context = 'generale',
      bool Function()? cancelled,
      void Function(int)? progress}) async {
    var carry = '', n = 0;
    await for (final block in file.openRead().transform(utf8.decoder)) {
      if (cancelled?.call() ?? false) break;
      carry += block;
      while (carry.length > 6000) {
        if (cancelled?.call() ?? false) return n;
        var cut = carry.lastIndexOf(RegExp(r'\s'), 6000);
        if (cut < 1) cut = 6000;
        n += await importText(carry.substring(0, cut),
            source: 'File: ${file.uri.pathSegments.last}',
            context: context,
            cancelled: cancelled);
        carry = carry.substring(cut);
        progress?.call(n);
      }
    }
    if (!(cancelled?.call() ?? false))
      n += await importText(carry,
          source: 'File: ${file.uri.pathSegments.last}',
          context: context,
          cancelled: cancelled);
    progress?.call(n);
    return n;
  }

  Future<Map<String, int>> stats() async {
    final r = (await db.rawQuery(
            'SELECT COUNT(*) AS episodes,COALESCE(SUM(consolidated),0) AS consolidated,COALESCE(SUM(LENGTH(features)+LENGTH(text)+COALESCE(LENGTH(image),0)+COALESCE(LENGTH(audio),0)),0) AS bytes FROM episodes'))
        .single;
    final p = (await db.rawQuery('SELECT COUNT(*) AS n FROM prototypes'))
        .single['n'] as int;
    final v = (await db.rawQuery(
            "SELECT COUNT(DISTINCT token) AS n FROM grams WHERE suffix='' AND token NOT IN ('<s>','<e>')"))
        .single['n'] as int;
    return {
      'episodes': r['episodes'] as int,
      'consolidated': r['consolidated'] as int,
      'payloadBytes': r['bytes'] as int,
      'prototypes': p,
      'vocabulary': v
    };
  }

  Future<void> setting(String key, String value) => db
      .insert('settings', {'k': key, 'v': value},
          conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<String?> readSetting(String key) async {
    final rows = await db.query('settings', where: 'k=?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  /// Snapshot contains media and all tables. Serialized against SQLite writes.
  Future<Uint8List> exportDatabase() async {
    if (db.path == inMemoryDatabasePath)
      throw StateError('Archivio di test non esportabile.');
    final snapshot =
        File('${db.path}.export-${DateTime.now().microsecondsSinceEpoch}');
    try {
      await db.execute('VACUUM INTO ?', [snapshot.path]);
      return await snapshot.readAsBytes();
    } finally {
      if (await snapshot.exists()) await snapshot.delete();
    }
  }
}
