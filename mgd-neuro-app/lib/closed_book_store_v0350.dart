// Independent, incremental memory store. No raw-text field or full-book snapshot.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'book_import_v0341.dart';
import 'competence_language_v0350.dart';
import 'narrative_memory_v0350.dart';

Map<String, dynamic> compileRequest350(Map<String, dynamic> request) {
  final compiler =
      NarrativeCompiler350(Map<String, dynamic>.from(request['state'] as Map));
  if (request['safe'] == false) {
    compiler.clearDiscourse();
    return CompiledUnit350(
            digest350('${request['text']}'),
            request['ordinal'] as int,
            ('${request['text']}').length,
            1,
            [],
            CompetenceLanguage350.observeFragment('${request['text']}'),
            {'overlong_fragment': 1},
            compiler.state())
        .toJson();
  }
  return compiler
      .compile('${request['text']}', unitOrdinal: request['ordinal'] as int)
      .toJson();
}

bool containsForgotten350(dynamic data, Set<String> hashes) {
  if (hashes.isEmpty) return false;
  if (data is String) {
    final t = tokens350(data);
    for (var i = 0; i < t.length; i++) {
      for (var n = 1; n <= 12 && i + n <= t.length; n++) {
        if (hashes.contains(digest350(t.skip(i).take(n).join(' '))))
          return true;
      }
    }
    return false;
  }
  if (data is Map)
    return data.entries.any((e) =>
        containsForgotten350(e.key, hashes) ||
        containsForgotten350(e.value, hashes));
  if (data is Iterable) return data.any((x) => containsForgotten350(x, hashes));
  return false;
}

Map<String, dynamic> filteredUnit350(
    Map<String, dynamic> original, Set<String> hashes) {
  final unit = Map<String, dynamic>.from(original);
  final all = (unit['events'] as List).cast<Map>();
  final removed = all
      .where((e) => containsForgotten350(e, hashes))
      .map((e) => e['id'])
      .toSet();
  unit['events'] = all
      .where((e) =>
          !removed.contains(e['id']) &&
          !removed.contains(e['subject']) &&
          !removed.contains(e['object']))
      .toList();
  final data = <String, dynamic>{};
  for (final row in (unit['language'] as Map).entries) {
    final values = <String, dynamic>{};
    for (final e in (row.value as Map).entries) {
      if (!containsForgotten350('${row.key} ${e.key}', hashes))
        values['${e.key}'] = e.value;
    }
    if (values.isNotEmpty) data['${row.key}'] = values;
  }
  unit['language'] = data;
  if (containsForgotten350(unit['discourse'], hashes))
    unit['discourse'] = {
      'nextOrdinal': (unit['discourse'] as Map)['nextOrdinal'] ?? 0
    };
  return unit;
}

class ClosedBookStore350 {
  final Database db;
  bool importing = false;
  ClosedBookStore350._(this.db);
  static Future<ClosedBookStore350>? _shared;
  static Future<ClosedBookStore350> get shared =>
      _shared ??= open().catchError((Object e) {
        _shared = null;
        throw e;
      });
  static Future<ClosedBookStore350> open(
      {String? path, DatabaseFactory? factory}) async {
    path ??=
        '${(await getApplicationDocumentsDirectory()).path}/mgd_closed_book_0350.db';
    final db = await (factory ?? databaseFactory).openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) async {
              await db.execute('PRAGMA foreign_keys=ON');
              await db.rawQuery('PRAGMA journal_mode=WAL');
            },
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE books(id TEXT PRIMARY KEY,title TEXT NOT NULL,source_bytes INTEGER NOT NULL,characters INTEGER NOT NULL DEFAULT 0,units INTEGER NOT NULL DEFAULT 0,sentences INTEGER NOT NULL DEFAULT 0,recognized INTEGER NOT NULL DEFAULT 0,unparsed INTEGER NOT NULL DEFAULT 0,events INTEGER NOT NULL DEFAULT 0,complete INTEGER NOT NULL DEFAULT 0,revision INTEGER NOT NULL DEFAULT 0,state TEXT NOT NULL DEFAULT "{}",created TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE units(book TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,ordinal INTEGER NOT NULL,hash TEXT NOT NULL,issues TEXT NOT NULL,PRIMARY KEY(book,ordinal))');
              await db.execute(
                  'CREATE TABLE events(book TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,id TEXT NOT NULL,ordinal INTEGER NOT NULL,subject TEXT NOT NULL,object TEXT NOT NULL,predicate TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(book,id))');
              await db
                  .execute('CREATE INDEX event_order ON events(book,ordinal)');
              await db.execute(
                  'CREATE INDEX event_subject ON events(book,subject,predicate)');
              await db.execute(
                  'CREATE INDEX event_object ON events(book,object,predicate)');
              await db.execute(
                  'CREATE TABLE usage(book TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,g TEXT NOT NULL,f TEXT NOT NULL,n INTEGER NOT NULL CHECK(n>0),PRIMARY KEY(book,g,f))');
              await db.execute('CREATE INDEX usage_group ON usage(g,f)');
              await db.execute(
                  'CREATE TABLE settings(k TEXT PRIMARY KEY,v TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE exams(book TEXT PRIMARY KEY REFERENCES books(id) ON DELETE CASCADE,payload TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE reports(id INTEGER PRIMARY KEY AUTOINCREMENT,book TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE,payload TEXT NOT NULL,created TEXT NOT NULL)');
            }));
    return ClosedBookStore350._(db);
  }

  Future<void> close() => db.close();
  Future<void> beginBook(String id, String title, {int sourceBytes = 0}) async {
    if (id.isEmpty || title.trim().isEmpty || title.length > 400)
      throw ArgumentError('Identità del libro non valida.');
    await db.insert(
        'books',
        {
          'id': id,
          'title': title,
          'source_bytes': sourceBytes,
          'created': DateTime.now().toIso8601String()
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, dynamic>?> book(String id) async {
    final rows = await db.query('books', where: 'id=?', whereArgs: [id]);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> books() async =>
      (await db.query('books', orderBy: 'created DESC'))
          .map(Map<String, dynamic>.from)
          .toList();
  Future<bool> commitUnit(String bookId, Map<String, dynamic> unit) async {
    final bans = await forgottenHashes();
    if (bans.isNotEmpty) unit = filteredUnit350(unit, bans);
    return db.transaction((tx) async {
      final exists = await tx.query('units',
          columns: ['hash'],
          where: 'book=? AND ordinal=?',
          whereArgs: [bookId, unit['ordinal']]);
      if (exists.isNotEmpty) {
        if (exists.first['hash'] != unit['hash'])
          throw StateError('Il testo è cambiato durante la ripresa.');
        return false;
      }
      final current = (await tx.query('books',
              columns: ['units'], where: 'id=?', whereArgs: [bookId]))
          .single;
      if (current['units'] != unit['ordinal'])
        throw StateError('Ordine del consolidamento non valido.');
      final events = (unit['events'] as List).cast<Map>();
      final issues = Map<String, int>.from(unit['issues'] as Map);
      final skipped = issues.entries
          .where((e) => e.key != 'chapter_heading')
          .fold<int>(0, (a, e) => a + e.value);
      final batch = tx.batch();
      batch.insert('units', {
        'book': bookId,
        'ordinal': unit['ordinal'],
        'hash': unit['hash'],
        'issues': jsonEncode(issues)
      });
      for (final e in events) {
        batch.insert('events', {
          'book': bookId,
          'id': e['id'],
          'ordinal': e['ordinal'],
          'subject': e['subject'],
          'object': e['object'],
          'predicate': e['predicate'],
          'payload': jsonEncode(e)
        });
      }
      for (final row in (unit['language'] as Map).entries) {
        for (final count in (row.value as Map).entries) {
          batch.rawInsert(
              'INSERT INTO usage(book,g,f,n) VALUES(?,?,?,?) ON CONFLICT(book,g,f) DO UPDATE SET n=n+excluded.n',
              [bookId, row.key, count.key, count.value]);
        }
      }
      final sentences = unit['sentences'] as int;
      batch.rawUpdate(
          'UPDATE books SET units=units+1,characters=characters+?,sentences=sentences+?,recognized=recognized+?,unparsed=unparsed+?,events=events+?,revision=revision+1,state=?,complete=0 WHERE id=?',
          [
            unit['characters'],
            sentences,
            (sentences - skipped - (issues['chapter_heading'] ?? 0))
                .clamp(0, sentences),
            skipped,
            events.length,
            jsonEncode(unit['discourse']),
            bookId
          ]);
      await batch.commit(noResult: true);
      return true;
    });
  }

  Future<void> finish(String id) async {
    await db.update('books', {'complete': 1}, where: 'id=?', whereArgs: [id]);
    await setActive(id);
  }

  Future<void> setActive(String id) async {
    if (await book(id) == null) throw StateError('Libro non disponibile.');
    await db.insert('settings', {'k': 'active', 'v': id},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> active() async {
    final r = await db.query('settings', where: 'k=?', whereArgs: ['active']);
    return r.isEmpty ? null : r.first['v'] as String;
  }

  Future<void> forgetBook(String id) async {
    if (importing) throw StateError('Interrompi prima la lettura.');
    await db.transaction((tx) async {
      await tx.delete('books', where: 'id=?', whereArgs: [id]);
      await tx
          .delete('settings', where: 'k=? AND v=?', whereArgs: ['active', id]);
    });
  }

  Future<void> correctEvent(
      String bookId, String id, Map<String, dynamic> roles) async {
    if (importing) throw StateError('Interrompi prima la lettura.');
    final rows = await db
        .query('events', where: 'book=? AND id=?', whereArgs: [bookId, id]);
    if (rows.length != 1) throw StateError('Evento non più disponibile.');
    final old =
        Event350.fromJson(jsonDecode(rows.single['payload'] as String) as Map);
    if (old.kind == 'cause')
      throw StateError(
          'Correggi gli eventi collegati, non una causa senza ruoli.');
    String role(String k, String fallback) {
      final v = '${roles[k] ?? fallback}'.trim();
      if (v.length > 160) throw const FormatException('Ruolo troppo lungo.');
      return entity350(v);
    }

    final subject = role('subject', old.subject),
        object = role('object', old.object),
        target = role('target', old.target),
        location = norm350('${roles['location'] ?? old.location}');
    if (subject.isEmpty || location.length > 160)
      throw const FormatException('Serve un agente esplicito e ruoli brevi.');
    final corrected = Event350(
        id: old.id,
        unit: old.unit,
        ordinal: old.ordinal,
        subject: subject,
        predicate: old.predicate,
        object: object,
        surface: old.surface,
        subjectSurface: '${roles['subject'] ?? old.subjectSurface}',
        target: target,
        location: location,
        kind: old.kind,
        chapter: old.chapter,
        epistemic: 'asserted',
        negative: roles['negative'] as bool? ?? old.negative,
        universal: old.universal,
        resolution: old.resolution.contains('passive_roles')
            ? 'user_corrected/passive_roles'
            : 'user_corrected');
    final bans = await forgottenHashes();
    if (containsForgotten350(corrected.toJson(), bans))
      throw StateError(
          'La correzione contiene dati precedentemente cancellati.');
    final before = CompetenceLanguage350.observe('', events: [old.toJson()]);
    final after =
        CompetenceLanguage350.observe('', events: [corrected.toJson()]);
    await db.transaction((tx) async {
      final current = await tx.query('events',
          columns: ['payload'],
          where: 'book=? AND id=?',
          whereArgs: [bookId, id]);
      if (current.isEmpty ||
          current.single['payload'] != rows.single['payload'])
        throw StateError('La memoria è cambiata: riapri l’evento.');
      for (final group in before.counts.entries) {
        for (final feature in group.value.entries) {
          final r = await tx.query('usage',
              columns: ['n'],
              where: 'book=? AND g=? AND f=?',
              whereArgs: [bookId, group.key, feature.key]);
          if (r.isEmpty)
            continue; // Features can have been targeted by earlier erasure.
          final n = (r.single['n'] as int) - feature.value;
          if (n < 0) throw StateError('Contributo grammaticale incoerente.');
          if (n == 0) {
            await tx.delete('usage',
                where: 'book=? AND g=? AND f=?',
                whereArgs: [bookId, group.key, feature.key]);
          } else {
            await tx.update('usage', {'n': n},
                where: 'book=? AND g=? AND f=?',
                whereArgs: [bookId, group.key, feature.key]);
          }
        }
      }
      for (final group in after.counts.entries) {
        for (final feature in group.value.entries) {
          await tx.rawInsert(
              'INSERT INTO usage(book,g,f,n) VALUES(?,?,?,?) ON CONFLICT(book,g,f) DO UPDATE SET n=n+excluded.n',
              [bookId, group.key, feature.key, feature.value]);
        }
      }
      await tx.update(
          'events',
          {
            'subject': corrected.subject,
            'object': corrected.object,
            'predicate': corrected.predicate,
            'payload': jsonEncode(corrected.toJson())
          },
          where: 'book=? AND id=?',
          whereArgs: [bookId, id]);
      await tx.delete('events',
          where: 'book=? AND predicate=? AND (subject=? OR object=?)',
          whereArgs: [bookId, 'causa_esplicita', id, id]);
      await tx.rawUpdate(
          'UPDATE books SET revision=revision+1,events=(SELECT COUNT(*) FROM events WHERE book=?) WHERE id=?',
          [bookId, bookId]);
    });
  }

  Future<void> clear() async {
    if (importing) throw StateError('Lettura in corso.');
    await db.transaction((tx) async {
      await tx.delete('books');
      await tx.delete('settings');
    });
  }

  Future<Map<String, dynamic>> snapshot(String id) async {
    final meta = await book(id);
    if (meta == null) throw StateError('Libro non trovato.');
    final data = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await db.query('events',
          columns: ['payload'],
          where: 'book=?',
          whereArgs: [id],
          orderBy: 'ordinal',
          offset: offset,
          limit: 256);
      for (final row in page) {
        data.add(jsonDecode(row['payload'] as String) as Map<String, dynamic>);
      }
      if (page.length < 256) break;
      offset += page.length;
      await Future<void>.delayed(Duration.zero);
    }
    meta.remove('state');
    return {'metadata': meta, 'events': data, 'rawPassagesRead': 0};
  }

  Future<List<Map<String, dynamic>>> eventPage(String id,
          {int offset = 0, int limit = 100}) async =>
      (await db.query('events',
              columns: ['payload'],
              where: 'book=?',
              whereArgs: [id],
              orderBy: 'ordinal',
              offset: offset,
              limit: limit.clamp(1, 200)))
          .map(
              (r) => jsonDecode(r['payload'] as String) as Map<String, dynamic>)
          .toList();
  Future<Map<String, int>> issues(String id) async {
    final result = <String, int>{};
    var offset = 0;
    while (true) {
      final page = await db.query('units',
          columns: ['issues'],
          where: 'book=?',
          whereArgs: [id],
          offset: offset,
          limit: 256);
      for (final r in page) {
        for (final e in (jsonDecode(r['issues'] as String) as Map).entries) {
          result['${e.key}'] =
              (result['${e.key}'] ?? 0) + (e.value as num).toInt();
        }
      }
      if (page.length < 256) break;
      offset += page.length;
    }
    return result;
  }

  Future<CompetenceLanguage350> language(
      {String? bookId, Set<String>? groups}) async {
    final data = <String, Map<String, int>>{};
    if (groups?.isEmpty == true) return CompetenceLanguage350();
    final where = [
      if (bookId != null) 'book=?',
      if (groups != null) 'g IN (${List.filled(groups.length, '?').join(',')})'
    ].join(' AND ');
    final args = [if (bookId != null) bookId, if (groups != null) ...groups];
    var offset = 0;
    while (true) {
      final rows = await db.rawQuery(
          'SELECT g,f,SUM(n) AS n FROM usage ${where.isEmpty ? '' : 'WHERE $where'} GROUP BY g,f ORDER BY g,f LIMIT 512 OFFSET ?',
          [...args, offset]);
      for (final r in rows) {
        data.putIfAbsent(r['g'] as String, () => {})[r['f'] as String] =
            (r['n'] as num).toInt();
      }
      if (rows.length < 512) break;
      offset += rows.length;
    }
    return CompetenceLanguage350(data);
  }

  Future<Map<String, dynamic>> word(String input, {String? bookId}) async {
    if (input.length > 160)
      throw const FormatException('Cerca una parola o un’espressione breve.');
    final w = norm350(input),
        model =
            await language(bookId: bookId, groups: {'context:$w', 'sense:$w'});
    final rows = await db.rawQuery(
        'SELECT g,SUM(n) AS n FROM usage WHERE g LIKE ? AND f=? ${bookId == null ? '' : 'AND book=?'} GROUP BY g ORDER BY n DESC LIMIT 12',
        ['gap:%', w, if (bookId != null) bookId]);
    final roles = await db.rawQuery(
        'SELECT g,SUM(n) AS n FROM usage WHERE g LIKE ? AND f=? ${bookId == null ? '' : 'AND book=?'} GROUP BY g',
        ['role:%', w, if (bookId != null) bookId]);
    return {
      'word': w,
      'observations': (await db.rawQuery(
              'SELECT COALESCE(SUM(n),0) n FROM usage WHERE g=? AND f=? ${bookId == null ? '' : 'AND book=?'}',
              ['lexicon', w, if (bookId != null) bookId]))
          .first['n'],
      'senses': (model.counts['sense:$w'] ?? {})
          .entries
          .map((e) => {'frame': e.key.replaceAll('|', ' · '), 'count': e.value})
          .toList(),
      'associations': model.associations(w),
      'usages': rows
          .map((r) => {
                'frame':
                    (r['g'] as String).substring(4).replaceFirst('|', ' ___ '),
                'count': r['n']
              })
          .toList(),
      'roles': roles,
      'note':
          'Usi e associazioni appresi. La vicinanza non è una definizione né un sinonimo certo.'
    };
  }

  Future<Map<String, dynamic>> compare(List<String> candidates,
      {String? bookId}) async {
    if (candidates.length > 16 ||
        candidates.any((s) => s.length > 2048 || tokens350(s).length > 256))
      throw const FormatException(
          'Confronta al massimo 16 frasi di 256 token per prova. La memoria dei libri non viene limitata.');
    final groups = {'predicates'};
    for (final s in candidates) {
      final ts = tokens350(s);
      groups.add('next:^');
      for (final t in ts) {
        groups.add('next:$t');
      }
      for (var i = 1; i <= ts.length; i++) {
        for (final f
            in CompetenceLanguage350.headFeatures(ts.take(i).join(' '))) {
          groups.add('agreement:$f');
          groups.add('endingAgreement:$f');
        }
      }
    }
    return (await language(bookId: bookId, groups: groups)).compare(candidates);
  }

  Future<Map<String, dynamic>> compose(String s, String v, String o,
          {String? bookId}) async =>
      (await language(bookId: bookId, groups: {'verbFrames:${norm350(v)}'}))
          .compose(s, v, o);
  Future<void> setCases(String id, List<Map<String, dynamic>> cases) async =>
      db.insert('exams', {'book': id, 'payload': jsonEncode(cases)},
          conflictAlgorithm: ConflictAlgorithm.replace);
  Future<String?> _readPayload(
      String table, String where, List<Object?> args) async {
    if (!{'exams', 'reports'}.contains(table))
      throw ArgumentError('Tabella non consentita.');
    final row = await db.rawQuery(
        'SELECT length(payload) n FROM $table WHERE $where', args);
    if (row.isEmpty) return null;
    final n = row.first['n'] as int, out = StringBuffer();
    for (var i = 1; i <= n; i += 65536) {
      final part = await db.rawQuery(
          'SELECT substr(payload,?,65536) p FROM $table WHERE $where',
          [i, ...args]);
      if (part.isEmpty)
        throw StateError('Il report è cambiato durante la lettura.');
      out.write(part.first['p']);
    }
    return out.toString();
  }

  Future<List<Map<String, dynamic>>> cases(String id) async {
    final payload = await _readPayload('exams', 'book=?', [id]);
    return payload == null
        ? []
        : (jsonDecode(payload) as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
  }

  Future<void> saveReport(String id, Map<String, dynamic> report) async {
    await db.insert('reports', {
      'book': id,
      'payload': jsonEncode(report),
      'created': DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String, dynamic>>> reports(String id, {int limit = 1}) async {
    final ids = await db.query('reports',
        columns: ['id'],
        where: 'book=?',
        whereArgs: [id],
        orderBy: 'id DESC',
        limit: limit.clamp(1, 20));
    final result = <Map<String, dynamic>>[];
    for (final r in ids) {
      final payload = await _readPayload('reports', 'id=?', [r['id']]);
      if (payload != null)
        result.add(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    }
    return result;
  }

  Future<Set<String>> forgottenHashes() async {
    final rows = await db
        .query('settings', where: 'k=?', whereArgs: ['forgotten_hashes']);
    return rows.isEmpty
        ? <String>{}
        : Set<String>.from(jsonDecode(rows.single['v'] as String) as List);
  }

  /// Erases events/features mentioning a concept, not every book containing it.
  /// Only digests remain to block accidental resurrection on import/resume.
  Future<void> forgetConcept(String label) async {
    if (importing)
      throw StateError('Interrompi la lettura prima della cancellazione.');
    final normalized = tokens350(label).join(' ');
    if (normalized.isEmpty) return;
    final bans = await forgottenHashes()
      ..add(digest350(normalized));
    final all = await books();
    await db.transaction((tx) async {
      await tx.insert(
          'settings', {'k': 'forgotten_hashes', 'v': jsonEncode(bans.toList())},
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final b in all) {
        final id = b['id'] as String, removed = <String>{};
        // A keyset scan remains stable while deleting rows.
        int after = -1;
        while (true) {
          final rows = await tx.query('events',
              columns: ['id', 'ordinal', 'payload'],
              where: 'book=? AND ordinal>?',
              whereArgs: [id, after],
              orderBy: 'ordinal',
              limit: 128);
          if (rows.isEmpty) break;
          final batch = tx.batch();
          for (final r in rows) {
            final e = jsonDecode(r['payload'] as String) as Map;
            if (containsForgotten350(e, bans)) {
              removed.add(r['id'] as String);
              batch.delete('events',
                  where: 'book=? AND id=?', whereArgs: [id, r['id']]);
            }
          }
          await batch.commit(noResult: true);
          after = rows.last['ordinal'] as int;
        }
        if (removed.isNotEmpty) {
          final links = await tx.query('events',
              where: 'book=? AND predicate=?',
              whereArgs: [id, 'causa_esplicita']);
          for (final r in links) {
            final e = jsonDecode(r['payload'] as String) as Map;
            if (removed.contains(e['subject']) || removed.contains(e['object']))
              await tx.delete('events',
                  where: 'book=? AND id=?', whereArgs: [id, r['id']]);
          }
        }
        String lastG = '', lastF = '';
        while (true) {
          final rows = await tx.rawQuery(
              'SELECT g,f FROM usage WHERE book=? AND (g>? OR (g=? AND f>?)) ORDER BY g,f LIMIT 512',
              [id, lastG, lastG, lastF]);
          if (rows.isEmpty) break;
          final batch = tx.batch();
          for (final r in rows) {
            if (containsForgotten350('${r['g']} ${r['f']}', bans))
              batch.delete('usage',
                  where: 'book=? AND g=? AND f=?',
                  whereArgs: [id, r['g'], r['f']]);
          }
          await batch.commit(noResult: true);
          lastG = rows.last['g'] as String;
          lastF = rows.last['f'] as String;
        }
        // Evaluation artifacts are invalid after edits and could repeat removed information.
        await tx.delete('reports', where: 'book=?', whereArgs: [id]);
        await tx.delete('exams', where: 'book=?', whereArgs: [id]);
        final oldState = jsonDecode(b['state'] as String) as Map;
        await tx.rawUpdate(
            'UPDATE books SET events=(SELECT COUNT(*) FROM events WHERE book=?), revision=revision+1,state=?,title=? WHERE id=?',
            [
              id,
              jsonEncode({'nextOrdinal': oldState['nextOrdinal'] ?? 0}),
              containsForgotten350(b['title'], bans)
                  ? 'Lettura con dati rimossi'
                  : b['title'],
              id
            ]);
      }
    });
  }

  Future<Map<String, dynamic>> storageStats(String id) async {
    final payload = (await db.rawQuery(
            'SELECT COALESCE(SUM(length(payload)),0) n FROM events WHERE book=?',
            [id]))
        .first['n'] as num;
    final features =
        (await db.rawQuery('SELECT COUNT(*) n FROM usage WHERE book=?', [id]))
            .first['n'] as num;
    return {
      'eventPayloadBytes': payload,
      'usageEntries': features,
      'rawTextBytesStored': 0,
      'note':
          'Byte dei soli eventi, non dimensione totale SQLite. Le statistiche e gli indici occupano altro spazio.'
    };
  }

  Future<Map<String, dynamic>> importFile(File file,
      {required String title,
      bool Function()? cancelled,
      void Function(Map<String, dynamic>)? progress}) async {
    if (importing) throw StateError('È già in corso una lettura.');
    importing = true;
    try {
      BookText341.validateName(title);
      final hash = (await sha256.bind(file.openRead()).first).toString();
      await beginBook(hash, title, sourceBytes: await file.length());
      final meta = (await book(hash))!,
          completed = (meta['units'] as num).toInt();
      if (meta['complete'] == 1) {
        await setActive(hash);
        return {...meta, 'skippedComplete': true};
      }
      var discourse = Map<String, dynamic>.from(
              jsonDecode(meta['state'] as String) as Map),
          ordinal = 0;
      await for (final fragment
          in BookText341.fragments(BookText341.decode(file))) {
        if (cancelled?.call() == true) break;
        if (ordinal < completed) {
          ordinal++;
          continue;
        }
        final compiled = await compute(compileRequest350, {
          'text': fragment.text,
          'safe': fragment.semanticSafe,
          'ordinal': ordinal,
          'state': discourse
        });
        if (cancelled?.call() == true) break;
        await commitUnit(hash, compiled);
        discourse = Map<String, dynamic>.from(compiled['discourse'] as Map);
        ordinal++;
        progress?.call((await book(hash))!);
      }
      if (cancelled?.call() != true) {
        await finish(hash);
      } else {
        await setActive(hash);
      }
      return {...(await book(hash))!, 'cancelled': cancelled?.call() == true};
    } finally {
      importing = false;
    }
  }

  /// Migration reads archived passages once. Recall never retains them.
  Future<Map<String, dynamic>> consolidateRows(List<Map<String, dynamic>> rows,
      {required String title,
      required String identity,
      bool Function()? cancelled,
      void Function(Map<String, dynamic>)? progress}) async {
    if (importing) throw StateError('È già in corso una lettura.');
    importing = true;
    try {
      final hash =
          digest350('legacy:$identity:${rows.map((r) => r['id']).join('|')}');
      await beginBook(hash, title);
      final meta = (await book(hash))!;
      if (meta['complete'] == 1) {
        await setActive(hash);
        return meta;
      }
      var discourse =
          Map<String, dynamic>.from(jsonDecode(meta['state'] as String) as Map);
      final done = (meta['units'] as num).toInt();
      for (var i = done; i < rows.length; i++) {
        if (cancelled?.call() == true) break;
        final compiled = await compute(compileRequest350, {
          'text': '${rows[i]['text']}',
          'safe': true,
          'ordinal': i,
          'state': discourse
        });
        if (cancelled?.call() == true) break;
        await commitUnit(hash, compiled);
        discourse = Map<String, dynamic>.from(compiled['discourse'] as Map);
        if (i % 16 == 0) progress?.call((await book(hash))!);
      }
      if (cancelled?.call() != true) await finish(hash);
      await setActive(hash);
      return (await book(hash))!;
    } finally {
      importing = false;
    }
  }
}

/// Worker receives structured events only. It cannot consult SQLite or book files.
class ClosedRecallWorker350 {
  final ReceivePort _receive = ReceivePort();
  final Map<int, Completer<dynamic>> _pending = {};
  final Completer<void> _ready = Completer<void>();
  Isolate? _isolate;
  SendPort? _send;
  bool _closed = false;
  int _id = 0;
  ClosedRecallWorker350._();
  static Future<ClosedRecallWorker350> open(
      Map<String, dynamic> snapshot) async {
    final w = ClosedRecallWorker350._();
    w._receive.listen((m) {
      if (m is Map && m['ready'] == true) {
        w._send = m['port'] as SendPort;
        if (!w._ready.isCompleted) w._ready.complete();
      } else if (m is Map && m['id'] is int) {
        final c = w._pending.remove(m['id']);
        if (c != null) {
          if (m.containsKey('error')) {
            c.completeError(StateError('${m['error']}'));
          } else {
            c.complete(m['value']);
          }
        }
      } else {
        final e = StateError('Memoria di lavoro terminata.');
        if (!w._ready.isCompleted) w._ready.completeError(e);
        w.close();
      }
    });
    try {
      w._isolate = await Isolate.spawn(
          _closedWorker350, [w._receive.sendPort, snapshot],
          onExit: w._receive.sendPort, onError: w._receive.sendPort);
      await w._ready.future.timeout(const Duration(seconds: 60));
      return w;
    } catch (_) {
      w.close();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> call(String op,
      [Map<String, dynamic> data = const {}]) async {
    if (_closed || _send == null) throw StateError('Memoria chiusa.');
    final id = ++_id, c = Completer<dynamic>();
    _pending[id] = c;
    _send!.send({'id': id, 'op': op, ...data});
    try {
      return Map<String, dynamic>.from(
          await c.future.timeout(const Duration(seconds: 60)) as Map);
    } finally {
      _pending.remove(id);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _receive.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('Memoria chiusa.'));
    }
    _pending.clear();
  }
}

void _closedWorker350(List args) async {
  final send = args[0] as SendPort,
      snapshot = Map<String, dynamic>.from(args[1] as Map);
  final engine = ClosedBookEngine350(
      (snapshot['events'] as List)
          .map((x) => Event350.fromJson(x as Map))
          .toList(),
      Map<String, dynamic>.from(snapshot['metadata'] as Map));
  final port = ReceivePort();
  send.send({'ready': true, 'port': port.sendPort});
  await for (final raw in port) {
    final m = raw as Map;
    try {
      Map<String, dynamic> value;
      switch (m['op']) {
        case 'ask':
          value = engine.answer('${m['question']}',
              assumptions: '${m['assumptions'] ?? ''}');
          break;
        case 'graph':
          value = engine.graph(offset: m['offset'] as int? ?? 0);
          break;
        case 'summary':
          value = {
            'text': engine.summary(entity: m['entity'] as String?),
            'rawPassagesRead': 0
          };
          break;
        default:
          throw ArgumentError('Operazione sconosciuta.');
      }
      send.send({'id': m['id'], 'value': value});
    } catch (e) {
      send.send({'id': m['id'], 'error': '$e'});
    }
  }
}
