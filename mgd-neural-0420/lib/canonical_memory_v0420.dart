import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'book_text_v0420.dart' show BookText420;
import 'book_understanding_v0342.dart';
import 'canonical_compiler_v0420.dart';
import 'competence_language_v0350.dart';
import 'native_mgd_engine_v09.dart';
import 'narrative_memory_v0350.dart';
import 'social_memory_v0420.dart' show SocialStore410;

String id420(String value) => sha256.convert(utf8.encode(value)).toString();
String canonical420(String value) => bookEntity342(value);

class CandidateBatch420 {
  final List<Map<String, dynamic>> rows;
  final bool truncated;
  const CandidateBatch420(this.rows, {this.truncated = false});
}

/// One database for original evidence, episodes, semantic assertions, geometry,
/// learned linguistic usage and sensor bindings. Geometry never changes truth.
class CanonicalMemory420 {
  final Database db;
  final bool useMgd;
  Future<void> _tail = Future<void>.value();
  CanonicalMemory420._(this.db, this.useMgd);

  static const schema = <String>[
    'CREATE TABLE sources(id TEXT PRIMARY KEY,title TEXT NOT NULL,kind TEXT NOT NULL,family TEXT NOT NULL,complete INTEGER NOT NULL DEFAULT 0,state TEXT NOT NULL DEFAULT "{}",units INTEGER NOT NULL DEFAULT 0,revision INTEGER NOT NULL DEFAULT 0,created INTEGER NOT NULL)',
    'CREATE TABLE passages(id TEXT PRIMARY KEY,source TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,ordinal INTEGER NOT NULL,hash TEXT NOT NULL,text TEXT NOT NULL,safe INTEGER NOT NULL,issues TEXT NOT NULL,unresolved INTEGER NOT NULL DEFAULT 0,created INTEGER NOT NULL,UNIQUE(source,ordinal))',
    'CREATE INDEX passage_source ON passages(source,ordinal)',
    'CREATE TABLE concepts(id TEXT PRIMARY KEY,label TEXT NOT NULL UNIQUE,kind TEXT NOT NULL DEFAULT "entity")',
    'CREATE TABLE aliases(alias TEXT NOT NULL,concept TEXT NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,PRIMARY KEY(alias,concept))',
    'CREATE INDEX alias_lookup ON aliases(alias)',
    'CREATE TABLE claims(id TEXT PRIMARY KEY,unit TEXT NOT NULL REFERENCES passages(id) ON DELETE CASCADE,source TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,subject TEXT NOT NULL,predicate TEXT NOT NULL,object TEXT NOT NULL,location TEXT NOT NULL,target TEXT NOT NULL,negative INTEGER NOT NULL,universal INTEGER NOT NULL,kind TEXT NOT NULL,epistemic TEXT NOT NULL,status TEXT NOT NULL DEFAULT "asserted",payload TEXT NOT NULL)',
    'CREATE INDEX claim_subject ON claims(subject,predicate,status)',
    'CREATE INDEX claim_object ON claims(object,predicate,status)',
    'CREATE INDEX claim_source ON claims(source,status)',
    'CREATE TABLE claim_terms(term TEXT NOT NULL,claim TEXT NOT NULL REFERENCES claims(id) ON DELETE CASCADE,PRIMARY KEY(term,claim))',
    'CREATE INDEX term_lookup ON claim_terms(term)',
    'CREATE TABLE edges(claim TEXT PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,w REAL NOT NULL,m REAL NOT NULL,material REAL NOT NULL,chi REAL NOT NULL,flux REAL NOT NULL DEFAULT 0,updates INTEGER NOT NULL DEFAULT 0)',
    'CREATE TABLE usage(unit TEXT NOT NULL REFERENCES passages(id) ON DELETE CASCADE,g TEXT NOT NULL,f TEXT NOT NULL,n INTEGER NOT NULL CHECK(n>0),PRIMARY KEY(unit,g,f))',
    'CREATE INDEX usage_group420 ON usage(g,f)',
    'CREATE TABLE sensory(id TEXT PRIMARY KEY,concept TEXT NOT NULL REFERENCES concepts(id),modality TEXT NOT NULL,features TEXT NOT NULL,source TEXT NOT NULL,created INTEGER NOT NULL)',
    'CREATE INDEX sensory_concept ON sensory(concept,modality)',
    'CREATE TABLE corrections(id INTEGER PRIMARY KEY AUTOINCREMENT,claim TEXT NOT NULL,unit TEXT NOT NULL,action TEXT NOT NULL,created INTEGER NOT NULL)',
    'CREATE TABLE meta420(k TEXT PRIMARY KEY,v TEXT NOT NULL)',
  ];

  static Future<CanonicalMemory420> open({String? path,
      DatabaseFactory? factory, bool useMgd = true}) async {
    path ??= '${(await getApplicationDocumentsDirectory()).path}/mgd_canonical_0420.db';
    final db = await (factory ?? databaseFactory).openDatabase(path,
      options: OpenDatabaseOptions(version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys=ON');
          await db.rawQuery('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA synchronous=NORMAL');
        },
        onCreate: (db, _) async {
          for (final sql in schema) { await db.execute(sql); }
        }));
    await SocialStore410.usingDatabase(db);
    return CanonicalMemory420._(db, useMgd);
  }

  Future<T> serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<String?> meta(String key) async {
    final rows = await db.query('meta420', where: 'k=?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['v'] as String;
  }
  Future<void> setMeta(String key, String value) => serial(() async {
    await db.insert('meta420', {'k': key, 'v': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  });

  Future<void> _source(String id, String title, String kind, String family) async {
    await db.rawInsert('INSERT OR IGNORE INTO sources(id,title,kind,family,created) VALUES(?,?,?,?,?)',
        [id, title, kind, family, DateTime.now().millisecondsSinceEpoch]);
  }

  Future<String> _concept(DatabaseExecutor tx, String label) async {
    final norm = canonical420(label), id = id420('concept:$norm');
    await tx.insert('concepts', {'id': id, 'label': norm},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await tx.insert('aliases', {'alias': norm, 'concept': id},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return id;
  }

  Future<void> _claim(DatabaseExecutor tx, Event350 e, String unit,
      String source, {String status = 'asserted'}) async {
    await tx.insert('claims', {'id': e.id, 'unit': unit, 'source': source,
      'subject': e.subject, 'predicate': e.predicate, 'object': e.object,
      'location': e.location, 'target': e.target, 'negative': e.negative ? 1 : 0,
      'universal': e.universal ? 1 : 0, 'kind': e.kind,
      'epistemic': e.epistemic, 'status': status, 'payload': jsonEncode(e.toJson())},
      conflictAlgorithm: ConflictAlgorithm.ignore);
    for (final value in [e.subject, e.object, e.target]) {
      if (value.isNotEmpty && e.kind != 'cause') await _concept(tx, value);
    }
    final terms = <String>{...BookEngine342.terms(
      '${e.subject} ${e.object} ${e.target} ${e.location} ${e.predicate}'),
      e.subject, e.object, e.predicate}..remove('');
    for (final term in terms) {
      await tx.insert('claim_terms', {'term': term, 'claim': e.id},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    // New evidence is accessible immediately; consolidation is not an admission gate.
    final step = MgdMath09.evolve(weight: .95, memory: 0, material: 0,
        coherenceAverage: 0, activation: 1);
    await tx.insert('edges', {'claim': e.id,
      'w': useMgd ? step.weight : .95, 'm': useMgd ? step.memory : 0,
      'material': useMgd ? step.material : 0, 'chi': step.coherenceAverage,
      'flux': useMgd ? step.informationalFlux : 0, 'updates': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, dynamic>> _unit(String source, String text,
      {required int ordinal, bool safe = true,
      List<String> replace = const []}) async {
    final digest = id420(text), unit = id420('$source:$ordinal:$digest');
    final old = await db.query('passages', where: 'source=? AND ordinal=?',
        whereArgs: [source, ordinal]);
    if (old.isNotEmpty) {
      if (old.single['hash'] != digest) throw StateError('Blocco di origine cambiato.');
      return {'unit': old.single['id'], 'new': false, 'claims': 0};
    }
    final meta = (await db.query('sources', where: 'id=?', whereArgs: [source])).single;
    final compiled = await compute(compileCanonical420, {
      'text': text, 'unit': unit, 'ordinal': ordinal, 'safe': safe,
      'state': jsonDecode(meta['state'] as String)});
    final events = (compiled['events'] as List).map((e) => Event350.fromJson(e as Map)).toList();
    if (replace.isNotEmpty && events.isEmpty) {
      throw const FormatException('La correzione non contiene un fatto interpretabile. Scrivi una frase completa; la memoria precedente resta disponibile.');
    }
    await db.transaction((tx) async {
      await tx.insert('passages', {'id': unit, 'source': source, 'ordinal': ordinal,
        'hash': digest, 'text': text, 'safe': safe ? 1 : 0,
        'issues': jsonEncode(compiled['issues']),
        'unresolved': (compiled['issues'] as Map).entries
          .where((e) => e.key != 'chapter_heading').fold<int>(0, (n, e) => n + (e.value as num).toInt()),
        'created': DateTime.now().millisecondsSinceEpoch});
      for (final e in events) { await _claim(tx, e, unit, source); }
      for (final id in replace) {
        await tx.update('claims', {'status': 'superseded'}, where: 'id=?', whereArgs: [id]);
        await tx.insert('corrections', {'claim': id, 'unit': unit,
          'action': 'explicit_user_correction', 'created': DateTime.now().millisecondsSinceEpoch});
      }
      for (final group in (compiled['language'] as Map).entries) {
        for (final feature in (group.value as Map).entries) {
          await tx.insert('usage', {'unit': unit, 'g': '${group.key}',
            'f': '${feature.key}', 'n': (feature.value as num).toInt()});
        }
      }
      await tx.rawUpdate('UPDATE sources SET state=?,units=units+1,revision=revision+1 WHERE id=?',
          [jsonEncode(compiled['discourse']), source]);
    });
    return {'unit': unit, 'new': true, 'claims': events.length,
      'issues': compiled['issues'], 'events': events.map((e) => e.toJson()).toList()};
  }

  Future<Map<String, dynamic>> ingestText(String text,
      {String title = 'Testo insegnato', String? sourceId,
      String kind = 'text', String family = 'locale:utente',
      bool continueSource = false, bool semanticSafe = true}) => serial(() async {
    if (text.trim().isEmpty) return {'claims': 0, 'units': 0, 'new': false};
    final source = sourceId ?? id420('$kind:$text');
    await _source(source, title, kind, family);
    final current = (await db.query('sources', where: 'id=?', whereArgs: [source])).single;
    if (!continueSource && current['complete'] == 1) {
      return {'source': source, 'claims': 0, 'units': 0, 'new': false};
    }
    var ordinal = continueSource ? current['units'] as int : 0;
    var claims = 0, units = 0;
    final all = <Map<String, dynamic>>[];
    await for (final block in BookText420.fragments(Stream<String>.value(text))) {
      final r = await _unit(source, block.text, ordinal: ordinal++,
          safe: block.semanticSafe && semanticSafe);
      claims += r['claims'] as int; if (r['new'] == true) units++;
      all.addAll((r['events'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)));
    }
    if (!continueSource) await db.update('sources', {'complete': 1},
        where: 'id=?', whereArgs: [source]);
    return {'source': source, 'claims': claims, 'units': units,
      'new': units > 0, 'events': all};
  });

  Future<Map<String, dynamic>> importFile(File file, {required String title,
      bool Function()? cancelled, void Function(int, int)? progress}) => serial(() async {
    BookText420.validateName(title);
    final source = (await sha256.bind(file.openRead()).first).toString();
    await _source(source, title, 'book', 'document:$source');
    final meta = (await db.query('sources', where: 'id=?', whereArgs: [source])).single;
    if (meta['complete'] == 1) return {'source': source, 'new': false, 'claims': 0};
    var ordinal = 0, chars = 0, claims = 0;
    await for (final fragment in BookText420.fragments(BookText420.decode(file))) {
      if (cancelled?.call() == true) break;
      final r = await _unit(source, fragment.text,
          ordinal: ordinal++, safe: fragment.semanticSafe);
      chars += fragment.text.length; claims += r['claims'] as int;
      progress?.call(ordinal, chars);
    }
    final stopped = cancelled?.call() == true;
    if (!stopped) await db.update('sources', {'complete': 1},
        where: 'id=?', whereArgs: [source]);
    return {'source': source, 'units': ordinal, 'characters': chars,
      'claims': claims, 'cancelled': stopped, 'new': true};
  });

  Future<void> restore(Map<String, dynamic> snapshot) => serial(() async {
    if (snapshot['schema'] != 'mgd.canonical.420') throw const FormatException('Formato snapshot non riconosciuto.');
    const tables = ['sources', 'passages', 'concepts', 'aliases', 'claims',
      'claim_terms', 'edges', 'usage', 'sensory', 'corrections', 'meta420',
      'agents', 'beliefs', 'goals', 'observations', 'social_meta'];
    for (final table in tables) {
      if (snapshot[table] is! List) throw FormatException('Tabella assente: $table');
    }
    await db.transaction((tx) async {
      await tx.delete('sensory'); await tx.delete('sources'); await tx.delete('concepts');
      for (final table in ['corrections', 'meta420', 'agents', 'beliefs', 'goals', 'observations', 'social_meta']) {
        await tx.delete(table);
      }
      for (final table in tables) {
        final columns = (await tx.rawQuery('PRAGMA table_info($table)')).map((c) => '${c['name']}').toSet();
        for (final raw in snapshot[table] as List) {
          if (raw is! Map || raw.keys.any((k) => !columns.contains(k))) throw FormatException('Riga non valida: $table');
          await tx.insert(table, Map<String, Object?>.from(raw));
        }
      }
      final check = await tx.rawQuery('PRAGMA foreign_key_check');
      if (check.isNotEmpty) throw const FormatException('Relazioni snapshot non valide.');
    });
  });

  Future<List<Map<String, dynamic>>> sources() async =>
      db.query('sources', orderBy: 'created DESC');

  Future<Map<String, dynamic>> stats() async {
    Future<int> count(String table, [String where = '1']) async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE $where')) ?? 0;
    final flux = (await db.rawQuery('SELECT COALESCE(SUM(flux),0) n FROM edges')).single['n'];
    final issues = await db.rawQuery('SELECT p.id FROM passages p WHERE p.unresolved>0 OR NOT EXISTS(SELECT 1 FROM claims c WHERE c.unit=p.id)');
    return {'sources': await count('sources'), 'passages': await count('passages'),
      'concepts': await count('concepts'), 'claims': await count('claims', 'status="asserted"'),
      'revoked': await count('claims', 'status="superseded"'),
      'activeEdges': Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM edges e JOIN claims c ON c.id=e.claim WHERE c.status="asserted" AND e.w<=1.0')) ?? 0,
      'consolidated': Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM edges e JOIN claims c ON c.id=e.claim WHERE c.status="asserted" AND e.material>=0.7')) ?? 0,
      'unparsed': issues.length, 'sensory': await count('sensory'),
      'flux': (flux as num).toDouble(), 'useMgd': useMgd};
  }

  Future<String?> resolve(String value) async {
    final rows = await db.rawQuery('SELECT c.label FROM aliases a JOIN concepts c ON c.id=a.concept WHERE a.alias=?',
        [canonical420(value)]);
    return rows.length == 1 ? rows.single['label'] as String : null;
  }

  Future<void> alias(String alias, String label) => serial(() async {
    if (canonical420(alias).isEmpty || canonical420(label).isEmpty) throw ArgumentError('Alias vuoto.');
    final rows = await db.query('concepts', where: 'label=?', whereArgs: [canonical420(label)]);
    if (rows.isEmpty) throw StateError('Il concetto deve essere già presente.');
    await db.insert('aliases', {'alias': canonical420(alias), 'concept': rows.single['id']},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  });

  Future<CandidateBatch420> candidates(String question,
      {String? scope, String assumptions = '', int budget = 192}) async {
    final allTerms = BookEngine342.terms(question).toSet()
      ..removeWhere((t) => NarrativeCompiler350.verbMap.containsKey(t) ||
          NarrativeCompiler350.verbMap.values.contains(t));
    var truncated = allTerms.length > 24;
    final terms = allTerms.take(24).toList();
    // Resolve only aliases actually mentioned. Ambiguous aliases remain unresolved.
    for (final term in List<String>.of(terms)) {
      final resolved = await resolve(term);
      if (resolved != null) terms.addAll(BookEngine342.terms(resolved));
    }
    final q = bookNorm342(question).replaceAll(RegExp(r'[?!.]+$'), '');
    final parsed = BookEngine342.parseQuestion(question);
    final rootClasses = <String>{};
    for (final sentence in assumptions.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
      final premise = BookEngine342.atomic(sentence, 'temporary');
      if (premise != null && premise.relation == 'tipo' && !premise.negative) {
        rootClasses.add(premise.object);
      }
    }
    final args = <Object?>[];
    String? condition;
    if (parsed != null && parsed.subject.isNotEmpty) {
      if (parsed.relation == 'luogo') {
        condition = '(c.subject=? OR c.object=?)';
        args.addAll([parsed.subject, parsed.subject]);
      } else {
        condition = '(c.subject=? AND (c.predicate=? OR c.predicate="tipo"))';
        args.addAll([parsed.subject, parsed.relation]);
      }
    } else if (parsed != null && parsed.object.isNotEmpty) {
      condition = '(c.object=? AND c.predicate=?)';
      args.addAll([parsed.object, parsed.relation]);
    }
    // Narrative recipients have explicit actor/object slots. Avoid retrieving
    // every event of a frequent character merely because its name matches.
    final verbPattern = (NarrativeCompiler350.verbMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|');
    final recipient = RegExp('^a chi (.+?) (?:ha )?($verbPattern) (.+)\$').firstMatch(q);
    if (recipient != null) {
      condition = '(c.subject=? AND c.predicate=? AND c.object=?)';
      args.clear();
      args.addAll([canonical420(recipient[1]!),
        NarrativeCompiler350.lemma(recipient[2]!), canonical420(recipient[3]!)]);
    }
    final color = RegExp(r'^di che colore (?:è|era)\s+(.+)$').firstMatch(q);
    final quantity = RegExp(r'^quante?\s+.+?\s+(?:rimasero|rimangono|restano)\s+(?:nel|nella|in)\s+(.+)$').firstMatch(q);
    if (color != null || quantity != null) {
      condition = '(c.subject=? AND c.predicate IN ("colore","stato","quantità_residua"))';
      args.clear(); args.add(canonical420(color?[1] ?? quantity![1]!));
    }
    if (condition == null && terms.isNotEmpty) {
      condition = 'c.id IN (SELECT claim FROM claim_terms WHERE term IN (${List.filled(terms.length, '?').join(',')}))';
      args.addAll(terms);
    }
    if (rootClasses.isNotEmpty) {
      condition = '(${condition ?? '0'} OR (c.universal=1 AND c.subject IN (${List.filled(rootClasses.length, '?').join(',')})))';
      args.addAll(rootClasses);
    }
    if (condition == null) return const CandidateBatch420([]);
    final rows = await db.rawQuery(
      'SELECT c.*,e.w,e.m,e.material,e.chi,e.flux FROM claims c JOIN edges e ON e.claim=c.id '
      'WHERE c.status="asserted" AND ($condition) ${scope == null ? '' : 'AND c.source=? '} '
      'ORDER BY c.negative DESC,e.w,c.id LIMIT ?',
      [...args, if (scope != null) scope, budget + 1]);
    final selected = <String, Map<String, dynamic>>{for (final r in rows.take(budget)) '${r['id']}': Map.of(r)};
    truncated = truncated || rows.length > budget;
    // Only explicit class-membership links require expansion for this proof
    // engine. Generic object adjacency would pull in unrelated book chapters.
    var frontier = rows.take(budget).where((r) => r['predicate'] == 'tipo' && r['negative'] == 0).toList();
    final expanded = <String>{};
    for (var depth = 0; depth < 4 && selected.length < budget; depth++) {
      final next = <Map<String, dynamic>>[];
      final allEntities = frontier.map((r) => '${r['object']}')
          .where((x) => x.isNotEmpty && !expanded.contains(x)).toSet();
      truncated = truncated || allEntities.length > 24;
      final entities = allEntities.take(24);
      for (final entity in entities) {
        expanded.add(entity);
        final neighbors = await db.rawQuery(
          'SELECT c.*,e.w,e.m,e.material,e.chi,e.flux FROM claims c JOIN edges e ON e.claim=c.id '
          'WHERE c.status="asserted" AND c.universal=1 AND c.subject=? '
          '${scope == null ? '' : 'AND c.source=? '} ORDER BY c.negative DESC,e.w LIMIT 33',
          [entity, if (scope != null) scope]);
        truncated = truncated || neighbors.length > 32;
        for (final r in neighbors.take(32)) {
          if (selected.length >= budget) break;
          if (!selected.containsKey(r['id'])) {
            selected['${r['id']}'] = Map.of(r);
            if (r['predicate'] == 'tipo' && r['negative'] == 0) next.add(r);
          }
        }
      }
      frontier = next;
    }
    truncated = truncated || frontier.any((r) => !expanded.contains(r['object'])) || selected.length >= budget;
    // Opposite evidence for selected atoms must not be hidden by relevance order.
    for (final r in List<Map<String, dynamic>>.of(selected.values)) {
      final opposite = await db.rawQuery(
        'SELECT c.*,e.w,e.m,e.material,e.chi,e.flux FROM claims c JOIN edges e ON e.claim=c.id '
        'WHERE c.subject=? AND c.predicate=? AND c.object=? AND c.status="asserted" '
        '${scope == null ? '' : 'AND c.source=? '} ORDER BY c.negative DESC LIMIT 17',
        [r['subject'], r['predicate'], r['object'], if (scope != null) scope]);
      truncated = truncated || opposite.length > 16;
      for (final n in opposite.take(16)) {
        if (selected.length >= budget && !selected.containsKey(n['id'])) break;
        selected['${n['id']}'] = Map.of(n);
      }
    }
    final ids = selected.keys.toList();
    if (ids.isNotEmpty && selected.length < budget) {
      final causes = await db.rawQuery(
        'SELECT c.*,e.w,e.m,e.material,e.chi,e.flux FROM claims c JOIN edges e ON e.claim=c.id '
        'WHERE c.kind="cause" AND c.status="asserted" AND c.subject IN (${List.filled(ids.length, '?').join(',')}) '
        '${scope == null ? '' : 'AND c.source=? '} LIMIT ?',
        [...ids, if (scope != null) scope, budget - selected.length + 1]);
      final remaining = budget - selected.length;
      truncated = truncated || causes.length > remaining;
      for (final cause in causes.take(remaining)) {
        selected['${cause['id']}'] = Map.of(cause);
        if (selected.length >= budget) break;
        final endpoint = await db.rawQuery(
          'SELECT c.*,e.w,e.m,e.material,e.chi,e.flux FROM claims c JOIN edges e ON e.claim=c.id '
          'WHERE c.id=? AND c.status="asserted"', [cause['object']]);
        if (endpoint.isNotEmpty) selected['${endpoint.single['id']}'] = Map.of(endpoint.single);
      }
    }
    return CandidateBatch420(selected.values.toList(),
        truncated: truncated || selected.length >= budget);
  }

  Future<List<Map<String, dynamic>>> evidence(Iterable<String> claimIds) async {
    final ids = claimIds.toSet().take(192).toList();
    if (ids.isEmpty) return [];
    return db.rawQuery('SELECT c.id,c.status,c.kind,c.subject,c.predicate,c.object,c.location,c.target,c.negative,p.text,p.ordinal,p.issues,s.title,s.id source,s.kind sourceKind '
      'FROM claims c JOIN passages p ON p.id=c.unit JOIN sources s ON s.id=c.source '
      'WHERE c.id IN (${List.filled(ids.length, '?').join(',')})', ids);
  }

  Future<void> activate(Iterable<String> ids, {double reward = 0}) => serial(() async {
    if (!useMgd) return;
    await db.transaction((tx) async {
      for (final id in ids.toSet().take(192)) {
        final rows = await tx.rawQuery('SELECT e.* FROM edges e JOIN claims c ON c.id=e.claim '
          'WHERE e.claim=? AND c.status="asserted"', [id]);
        if (rows.isEmpty) continue;
        final e = rows.single;
        // Material-dependent plasticity is an AI design choice, not a theorem
        // transferred from the original stochastic lattice model.
        final plasticity = 1 / (1 + 4 * (e['material'] as num));
        final next = MgdMath09.evolve(weight: (e['w'] as num).toDouble(),
          memory: (e['m'] as num).toDouble(), material: (e['material'] as num).toDouble(),
          coherenceAverage: (e['chi'] as num).toDouble(), activation: plasticity,
          reward: reward);
        await tx.rawUpdate('UPDATE edges SET w=?,m=?,material=?,chi=?,flux=flux+?,updates=updates+1 WHERE claim=?',
          [next.weight, next.memory, next.material, next.coherenceAverage,
           next.informationalFlux, id]);
      }
    });
  });

  Future<void> consolidate({int budget = 32}) async {
    final rows = await db.rawQuery('SELECT e.claim FROM edges e JOIN claims c ON c.id=e.claim '
      'WHERE c.status="asserted" AND e.material<0.7 ORDER BY e.updates DESC LIMIT ?', [budget]);
    await activate(rows.map((r) => '${r['claim']}'));
  }

  /// Correction and revocation commit together, including the original scope.
  /// Consolidation never prevents an explicit correction.
  Future<Map<String, dynamic>> correct(List<String> ids, String sentence) => serial(() async {
    if (ids.isEmpty) throw ArgumentError('Scegli una relazione da correggere.');
    final rows = await db.query('claims', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
    if (rows.length != ids.toSet().length) throw StateError('Relazione non trovata.');
    final scopes = rows.map((r) => '${r['source']}').toSet();
    if (scopes.length != 1) throw StateError('Correggi una fonte alla volta.');
    final source = scopes.single;
    final meta = (await db.query('sources', where: 'id=?', whereArgs: [source])).single;
    return _unit(source, sentence, ordinal: meta['units'] as int, replace: ids);
  });

  Future<void> bindSensor(String label, String modality, Map<String, double> features,
      {String source = 'Sensore con etichetta utente'}) => serial(() async {
    if (!{'vision', 'visual', 'auditory', 'image', 'audio'}.contains(modality)) throw ArgumentError('Modalità non valida.');
    if (canonical420(label).isEmpty) throw ArgumentError('Etichetta vuota.');
    if (features.isEmpty || features.values.any((x) => !x.isFinite)) throw ArgumentError('Descrittori non validi.');
    final concept = await _concept(db, label);
    final id = id420('$concept:$modality:${jsonEncode(features)}');
    await db.insert('sensory', {'id': id, 'concept': concept, 'modality': modality,
      'features': jsonEncode(features), 'source': source,
      'created': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.ignore);
  });

  Future<List<Map<String, dynamic>>> recognize(String modality, Map<String, double> features,
      {int budget = 128}) async {
    final rows = await db.rawQuery('SELECT s.*,c.label FROM sensory s JOIN concepts c ON c.id=s.concept '
      'WHERE s.modality=? ORDER BY s.created DESC LIMIT ?', [modality, budget]);
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final other = Map<String, num>.from(jsonDecode(row['features'] as String) as Map);
      var dot = 0.0, aa = 0.0, bb = 0.0;
      for (final k in {...features.keys, ...other.keys}) {
        final a = features[k] ?? 0, b = other[k]?.toDouble() ?? 0;
        dot += a * b; aa += a * a; bb += b * b;
      }
      final score = aa == 0 || bb == 0 ? 0.0 : dot / sqrt(aa * bb);
      out.add({...row, 'similarity': score});
    }
    out.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));
    return out.take(5).toList();
  }

  Future<List<Map<String, dynamic>>> graph({int limit = 100, int offset = 0}) async =>
      db.rawQuery('SELECT c.id,c.subject,c.predicate,c.object,c.location,c.target,c.negative,e.w,e.material FROM claims c '
        'JOIN edges e ON e.claim=c.id WHERE c.status="asserted" ORDER BY c.subject,c.id LIMIT ? OFFSET ?',
        [limit, offset]);

  Future<List<Map<String, dynamic>>> unresolved({int limit = 64}) async =>
    db.rawQuery('SELECT p.*,s.title FROM passages p JOIN sources s ON s.id=p.source '
      'WHERE p.unresolved>0 OR NOT EXISTS(SELECT 1 FROM claims c WHERE c.unit=p.id) ORDER BY p.created DESC LIMIT ?', [limit]);

  Future<List<Map<String, dynamic>>> sourcePassages(String source, {int offset = 0, int limit = 32}) async =>
      db.query('passages', where: 'source=?', whereArgs: [source], orderBy: 'ordinal', offset: offset, limit: limit);

  Future<CompetenceLanguage350> language() async {
    final rows = await db.rawQuery('SELECT g,f,SUM(n) n FROM usage GROUP BY g,f');
    final counts = <String, Map<String, int>>{};
    for (final r in rows) { counts.putIfAbsent('${r['g']}', () => {})['${r['f']}'] = (r['n'] as num).toInt(); }
    return CompetenceLanguage350(counts);
  }

  Future<void> deleteSource(String id) => serial(() async {
    await db.delete('sources', where: 'id=?', whereArgs: [id]);
    await _pruneConcepts();
  });

  Future<void> _pruneConcepts() async {
    await db.rawDelete('DELETE FROM concepts WHERE label NOT IN '
      '(SELECT subject FROM claims UNION SELECT object FROM claims UNION SELECT target FROM claims) '
      'AND id NOT IN (SELECT concept FROM sensory)');
  }

  Future<Map<String, dynamic>> export() async {
    await _tail;
    return db.transaction((tx) async {
      final result = <String, dynamic>{'schema': 'mgd.canonical.420',
        'version': '0.42.0', 'useMgd': useMgd};
      for (final table in ['sources', 'passages', 'concepts', 'aliases', 'claims',
        'claim_terms', 'edges', 'usage', 'sensory', 'corrections', 'meta420',
        'agents', 'beliefs', 'goals', 'observations', 'social_meta']) {
        final exists = await tx.rawQuery('SELECT name FROM sqlite_master WHERE type="table" AND name=?', [table]);
        if (exists.isNotEmpty) result[table] = await tx.query(table);
      }
      return result;
    });
  }

  Future<void> clear() => serial(() async {
    await db.transaction((tx) async {
      for (final table in ['sources', 'sensory', 'concepts', 'corrections', 'meta420']) {
        await tx.delete(table);
      }
      for (final table in ['agents', 'beliefs', 'goals', 'observations', 'social_meta']) {
        final exists = await tx.rawQuery('SELECT name FROM sqlite_master WHERE type="table" AND name=?', [table]);
        if (exists.isNotEmpty) await tx.delete(table);
      }
    });
  });

  Future<void> close() async { await _tail; await db.close(); }
}
