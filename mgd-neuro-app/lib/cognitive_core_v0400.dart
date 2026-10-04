// MGD Cognitive Core 0.40.0
// Predictive, incremental cognitive layer: working memory, semantic memory,
// structured world relations, selective episodic memory, learned constructions,
// content-addressable recall and curiosity driven by uncertainty.
//
// No pretrained LLM, embedding model or POS tagger is used here. The persistent
// store contains compact learned statistics/frames, never the source document.
import 'dart:convert';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

String norm400(String x) => x
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> tokens400(String x) => RegExp(r"[a-zàèéìòù]+(?:'[a-zàèéìòù]+)?|[0-9]+")
    .allMatches(norm400(x))
    .map((m) => m[0]!)
    .toList(growable: false);

const functionWords400 = <String>{
  'il','lo','la','i','gli','le','un','uno','una','di','del','della','dei','degli','delle',
  'a','al','alla','allo','ai','agli','alle','da','dal','dalla','dallo','dai','dagli','dalle',
  'in','nel','nella','nello','nei','nelle','su','sul','sulla','sullo','sui','sugli','sulle',
  'con','per','tra','fra','e','ed','o','oppure','ma','però','pero','che','cui','non','si',
  'mi','ti','ci','vi','ne','lo','la','li','le','lui','lei','esso','essa','essi','esse',
  'io','tu','noi','voi','loro','questo','questa','questi','queste','quello','quella',
  'quelli','quelle','come','quando','dove','perché','perche','se','mentre','poi','ora',
};

const auxiliary400 = <String>{
  'è','era','sono','erano','fu','furono','essere','ha','hanno','aveva','avevano','ebbe',
  'avere','viene','veniva','vengono','può','possono','deve','devono','vuole','vogliono'
};

bool isContent400(String x) =>
    x.length > 1 && !functionWords400.contains(x) && !RegExp(r'^\d+$').hasMatch(x);

String stem400(String x) {
  var w = norm400(x);
  const endings = [
    'erebbero','irebbero','erebbe','irebbe','avano','evano','ivano','assero','essero','issero',
    'ando','endo','endo','iamo','ate','ete','ite','ano','ono','ava','eva','iva','ato','uto','ito',
    'ò','ì','ai','avi','evi','ivi','are','ere','ire','isce','isco','isci','iscono'
  ];
  for (final e in endings) {
    if (w.length > e.length + 2 && w.endsWith(e)) return w.substring(0, w.length - e.length);
  }
  return w;
}

bool looksVerb400(String token) {
  if (auxiliary400.contains(token)) return true;
  if (!isContent400(token) || token.length < 3) return false;
  return RegExp(r'(o|i|a|e|iamo|ate|ete|ite|ano|ono|ava|eva|iva|ò|ì|ato|uto|ito|isce|iscono)$')
      .hasMatch(token);
}

class CognitiveFrame400 {
  final String subject, predicate, object, location;
  final bool negative;
  final List<String> concepts;
  const CognitiveFrame400({
    required this.subject,
    required this.predicate,
    required this.object,
    required this.location,
    required this.negative,
    required this.concepts,
  });
  bool get valid => subject.isNotEmpty && predicate.isNotEmpty;
  String get signature => '$subject|$predicate|$object|$location|${negative ? 1 : 0}';
  Map<String, dynamic> toJson() => {
        'subject': subject,
        'predicate': predicate,
        'object': object,
        'location': location,
        'negative': negative,
        'concepts': concepts,
      };
}

class FrameInducer400 {
  static const locationWords = {
    'in','nel','nella','nello','nei','nelle','su','sul','sulla','sotto','sopra','dentro','fuori','verso','presso'
  };

  static CognitiveFrame400 induce(String sentence) {
    final ts = tokens400(sentence);
    if (ts.isEmpty) {
      return const CognitiveFrame400(subject: '', predicate: '', object: '', location: '', negative: false, concepts: []);
    }
    final content = ts.where(isContent400).toList(growable: false);
    if (content.isEmpty) {
      return CognitiveFrame400(subject: '', predicate: '', object: '', location: '', negative: ts.contains('non'), concepts: const []);
    }

    var verbIndex = -1;
    for (var i = 1; i < ts.length; i++) {
      if (looksVerb400(ts[i]) && ts.take(i).any(isContent400)) {
        verbIndex = i;
        break;
      }
    }
    if (verbIndex < 0 && ts.length >= 3) {
      // Distribution-free bootstrap: the first lexical item between two lexical
      // regions is a candidate predicate. This is an uncertain frame, but it
      // allows learning new verbs rather than requiring a fixed verb dictionary.
      for (var i = 1; i < ts.length - 1; i++) {
        if (isContent400(ts[i]) && ts.take(i).any(isContent400) && ts.skip(i + 1).any(isContent400)) {
          verbIndex = i;
          break;
        }
      }
    }
    if (verbIndex < 0) {
      return CognitiveFrame400(subject: content.first, predicate: '', object: '', location: '', negative: ts.contains('non'), concepts: content.toSet().toList());
    }

    final before = ts.take(verbIndex).where(isContent400).toList();
    final after = ts.skip(verbIndex + 1).toList();
    final subjectTokens = before.isEmpty ? <String>[] : before.sublist(max(0, before.length - 2));
    final subject = subjectTokens.join(' ');
    final predicate = stem400(ts[verbIndex]);

    var location = '';
    var objectTokens = <String>[];
    var locAt = -1;
    for (var i = 0; i < after.length; i++) {
      if (locationWords.contains(after[i])) {
        locAt = i;
        break;
      }
    }
    if (locAt >= 0) {
      objectTokens = after.take(locAt).where(isContent400).take(3).toList();
      location = after.skip(locAt).take(5).join(' ');
    } else {
      objectTokens = after.where(isContent400).take(3).toList();
    }
    final object = objectTokens.join(' ');
    final concepts = <String>{...content, predicate}.where((x) => x.isNotEmpty).toList(growable: false);
    return CognitiveFrame400(
      subject: subject,
      predicate: predicate,
      object: object,
      location: location,
      negative: ts.contains('non'),
      concepts: concepts,
    );
  }

  static String construction(String sentence, CognitiveFrame400 frame) {
    final ts = tokens400(sentence);
    final out = <String>[];
    for (final t in ts.take(20)) {
      if (functionWords400.contains(t)) {
        out.add('F:$t');
      } else if (frame.subject.split(' ').contains(t)) {
        out.add('S');
      } else if (stem400(t) == frame.predicate && frame.predicate.isNotEmpty) {
        out.add('V');
      } else if (frame.object.split(' ').contains(t)) {
        out.add('O');
      } else if (RegExp(r'^\d+$').hasMatch(t)) {
        out.add('NUM');
      } else {
        out.add('X');
      }
    }
    return out.join(' ');
  }
}

class CognitiveAttention400 {
  final double surprise, novelty, uncertainty, causalImpact, goalRelevance, persistence, salience;
  const CognitiveAttention400({
    required this.surprise,
    required this.novelty,
    required this.uncertainty,
    required this.causalImpact,
    required this.goalRelevance,
    required this.persistence,
    required this.salience,
  });
  Map<String, dynamic> toJson() => {
        'surprise': surprise,
        'novelty': novelty,
        'uncertainty': uncertainty,
        'causalImpact': causalImpact,
        'goalRelevance': goalRelevance,
        'persistence': persistence,
        'salience': salience,
      };
}

class CognitiveTurn400 {
  final CognitiveFrame400 frame;
  final CognitiveAttention400 attention;
  final List<String> predictions;
  final List<String> curiosity;
  const CognitiveTurn400(this.frame, this.attention, this.predictions, this.curiosity);
}

class CognitiveStore400 {
  final Database db;
  CognitiveStore400._(this.db);

  static Future<CognitiveStore400> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return openAt('${dir.path}/mgd_cognitive_core_0400.db');
  }

  static Future<CognitiveStore400> openAt(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            try { await db.rawQuery('PRAGMA journal_mode=WAL'); } catch (_) {}
            await db.execute('PRAGMA synchronous=NORMAL');
            await db.execute('PRAGMA foreign_keys=ON');
          },
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE concepts(term TEXT PRIMARY KEY, exposures INTEGER NOT NULL DEFAULT 0, as_subject INTEGER NOT NULL DEFAULT 0, as_object INTEGER NOT NULL DEFAULT 0, as_predicate INTEGER NOT NULL DEFAULT 0, first_seen INTEGER NOT NULL, last_seen INTEGER NOT NULL)');
            await db.execute('CREATE TABLE contexts(src TEXT NOT NULL, dst TEXT NOT NULL, offset INTEGER NOT NULL, count INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(src,dst,offset))');
            await db.execute('CREATE INDEX contexts_src_idx ON contexts(src,count DESC)');
            await db.execute('CREATE INDEX contexts_dst_idx ON contexts(dst,count DESC)');
            await db.execute('CREATE TABLE relations(subject TEXT NOT NULL, predicate TEXT NOT NULL, object TEXT NOT NULL, location TEXT NOT NULL DEFAULT "", negative INTEGER NOT NULL DEFAULT 0, count INTEGER NOT NULL DEFAULT 0, first_seen INTEGER NOT NULL, last_seen INTEGER NOT NULL, PRIMARY KEY(subject,predicate,object,location,negative))');
            await db.execute('CREATE INDEX relations_subject_idx ON relations(subject,count DESC)');
            await db.execute('CREATE INDEX relations_object_idx ON relations(object,count DESC)');
            await db.execute('CREATE INDEX relations_predicate_idx ON relations(predicate,count DESC)');
            await db.execute('CREATE TABLE transitions(prev_predicate TEXT NOT NULL, next_predicate TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(prev_predicate,next_predicate))');
            await db.execute('CREATE INDEX transitions_prev_idx ON transitions(prev_predicate,count DESC)');
            await db.execute('CREATE TABLE constructions(pattern TEXT PRIMARY KEY, count INTEGER NOT NULL DEFAULT 0, last_seen INTEGER NOT NULL)');
            await db.execute('CREATE TABLE episodes(id INTEGER PRIMARY KEY AUTOINCREMENT, subject TEXT NOT NULL, predicate TEXT NOT NULL, object TEXT NOT NULL, location TEXT NOT NULL, negative INTEGER NOT NULL, salience REAL NOT NULL, surprise REAL NOT NULL, novelty REAL NOT NULL, at INTEGER NOT NULL)');
            await db.execute('CREATE INDEX episodes_salience_idx ON episodes(salience DESC,at DESC)');
            await db.execute('CREATE INDEX episodes_subject_idx ON episodes(subject,at DESC)');
            await db.execute('CREATE TABLE gaps(term TEXT NOT NULL, kind TEXT NOT NULL, score REAL NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY(term,kind))');
            await db.execute('CREATE INDEX gaps_score_idx ON gaps(score DESC)');
            await db.execute('CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT NOT NULL)');
          },
        ));
    return CognitiveStore400._(db);
  }

  Future<void> close() => db.close();

  Future<Map<String, int>> exposures(Iterable<String> terms) async {
    final xs = terms.where((x) => x.isNotEmpty).toSet().toList();
    if (xs.isEmpty) return {};
    final q = List.filled(xs.length, '?').join(',');
    final rows = await db.rawQuery('SELECT term,exposures FROM concepts WHERE term IN ($q)', xs);
    return {for (final r in rows) '${r['term']}': (r['exposures'] as int? ?? 0)};
  }

  Future<int> relationCount(CognitiveFrame400 f) async {
    if (!f.valid) return 0;
    final rows = await db.rawQuery(
        'SELECT count FROM relations WHERE subject=? AND predicate=? AND object=? AND location=? AND negative=?',
        [f.subject, f.predicate, f.object, f.location, f.negative ? 1 : 0]);
    return rows.isEmpty ? 0 : (rows.single['count'] as int? ?? 0);
  }

  Future<Map<String, int>> nextPredicates(String prev) async {
    if (prev.isEmpty) return {};
    final rows = await db.rawQuery('SELECT next_predicate,count FROM transitions WHERE prev_predicate=? ORDER BY count DESC LIMIT 24', [prev]);
    return {for (final r in rows) '${r['next_predicate']}': (r['count'] as int)};
  }

  Future<void> observe({
    required String sentence,
    required CognitiveFrame400 frame,
    required CognitiveAttention400 attention,
    required String previousPredicate,
  }) async {
    final ts = tokens400(sentence), stamp = DateTime.now().millisecondsSinceEpoch;
    final lexical = ts.where(isContent400).toList(growable: false);
    final unique = lexical.toSet();
    final pattern = FrameInducer400.construction(sentence, frame);
    await db.transaction((tx) async {
      for (final term in unique) {
        await tx.rawInsert('INSERT INTO concepts(term,exposures,first_seen,last_seen) VALUES(?,1,?,?) ON CONFLICT(term) DO UPDATE SET exposures=exposures+1,last_seen=excluded.last_seen', [term, stamp, stamp]);
      }
      if (frame.predicate.isNotEmpty) {
        await tx.rawInsert('INSERT INTO concepts(term,exposures,as_predicate,first_seen,last_seen) VALUES(?,1,1,?,?) ON CONFLICT(term) DO UPDATE SET exposures=exposures+1,as_predicate=as_predicate+1,last_seen=excluded.last_seen', [frame.predicate, stamp, stamp]);
      }
      for (var i = 0; i < lexical.length; i++) {
        for (var j = max(0, i - 4); j <= min(lexical.length - 1, i + 4); j++) {
          if (i == j || lexical[i] == lexical[j]) continue;
          await tx.rawInsert('INSERT INTO contexts(src,dst,offset,count) VALUES(?,?,?,1) ON CONFLICT(src,dst,offset) DO UPDATE SET count=count+1', [lexical[i], lexical[j], j - i]);
        }
      }
      if (frame.valid) {
        await tx.rawUpdate('UPDATE concepts SET as_subject=as_subject+1 WHERE term=?', [frame.subject.split(' ').last]);
        if (frame.object.isNotEmpty) {
          await tx.rawUpdate('UPDATE concepts SET as_object=as_object+1 WHERE term=?', [frame.object.split(' ').last]);
        }
        await tx.rawInsert('INSERT INTO relations(subject,predicate,object,location,negative,count,first_seen,last_seen) VALUES(?,?,?,?,?,1,?,?) ON CONFLICT(subject,predicate,object,location,negative) DO UPDATE SET count=count+1,last_seen=excluded.last_seen', [frame.subject, frame.predicate, frame.object, frame.location, frame.negative ? 1 : 0, stamp, stamp]);
        if (previousPredicate.isNotEmpty) {
          await tx.rawInsert('INSERT INTO transitions(prev_predicate,next_predicate,count) VALUES(?,?,1) ON CONFLICT(prev_predicate,next_predicate) DO UPDATE SET count=count+1', [previousPredicate, frame.predicate]);
        }
      }
      if (pattern.isNotEmpty) {
        await tx.rawInsert('INSERT INTO constructions(pattern,count,last_seen) VALUES(?,1,?) ON CONFLICT(pattern) DO UPDATE SET count=count+1,last_seen=excluded.last_seen', [pattern, stamp]);
      }
      if (frame.valid && attention.salience >= .50) {
        await tx.insert('episodes', {
          'subject': frame.subject, 'predicate': frame.predicate, 'object': frame.object,
          'location': frame.location, 'negative': frame.negative ? 1 : 0,
          'salience': attention.salience, 'surprise': attention.surprise,
          'novelty': attention.novelty, 'at': stamp,
        });
      }
      for (final term in unique) {
        final exp = await tx.rawQuery('SELECT exposures,as_subject,as_object,as_predicate FROM concepts WHERE term=?', [term]);
        if (exp.isEmpty) continue;
        final r = exp.single;
        final n = r['exposures'] as int;
        final roles = (r['as_subject'] as int) + (r['as_object'] as int) + (r['as_predicate'] as int);
        final ignorance = (1 / sqrt(max(1, n))) * (roles == 0 ? 1.0 : .65);
        await tx.rawInsert('INSERT INTO gaps(term,kind,score,updated_at) VALUES(?,?,?,?) ON CONFLICT(term,kind) DO UPDATE SET score=excluded.score,updated_at=excluded.updated_at', [term, roles == 0 ? 'meaning' : 'properties', ignorance, stamp]);
      }
      await tx.rawInsert('INSERT INTO meta(k,v) VALUES("cycles","1") ON CONFLICT(k) DO UPDATE SET v=CAST(CAST(v AS INTEGER)+1 AS TEXT)');
      await tx.rawInsert('INSERT INTO meta(k,v) VALUES("last_prediction_error",?) ON CONFLICT(k) DO UPDATE SET v=excluded.v', ['${attention.surprise}']);
      await tx.rawInsert('INSERT INTO meta(k,v) VALUES("last_salience",?) ON CONFLICT(k) DO UPDATE SET v=excluded.v', ['${attention.salience}']);
    });
  }

  Future<List<Map<String, dynamic>>> associations(String term, {int limit = 10}) async {
    final rows = await db.rawQuery('SELECT dst,SUM(count) AS n FROM contexts WHERE src=? GROUP BY dst ORDER BY n DESC LIMIT ?', [norm400(term), limit]);
    return rows.map((r) => {'term': '${r['dst']}', 'count': r['n'] as int}).toList();
  }

  Future<List<Map<String, dynamic>>> relations(String term, {int limit = 12}) async {
    final q = norm400(term);
    final rows = await db.rawQuery('SELECT subject,predicate,object,location,negative,count FROM relations WHERE subject LIKE ? OR object LIKE ? ORDER BY count DESC,last_seen DESC LIMIT ?', ['%$q%', '%$q%', limit]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>?> concept(String term) async {
    final q = norm400(term);
    final rows = await db.query('concepts', where: 'term=?', whereArgs: [q], limit: 1);
    if (rows.isEmpty) return null;
    return {...rows.single, 'associations': await associations(q), 'relations': await relations(q)};
  }

  Future<List<Map<String, dynamic>>> topGaps({int limit = 8}) async {
    final rows = await db.rawQuery('SELECT term,kind,score FROM gaps WHERE score>0.08 ORDER BY score DESC,updated_at DESC LIMIT ?', [limit]);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> recall(Iterable<String> cues, {int limit = 8}) async {
    final terms = cues.where(isContent400).map(norm400).toSet().toList();
    if (terms.isEmpty) return [];
    final scores = <String, double>{};
    for (final c in terms) {
      scores[c] = (scores[c] ?? 0) + 2;
      final rows = await db.rawQuery('SELECT dst,SUM(count) AS n FROM contexts WHERE src=? GROUP BY dst ORDER BY n DESC LIMIT 32', [c]);
      final total = rows.fold<int>(0, (a, r) => a + (r['n'] as int));
      for (final r in rows) {
        final t = '${r['dst']}';
        scores[t] = (scores[t] ?? 0) + (r['n'] as int) / max(1, total);
      }
    }
    if (scores.isEmpty) return [];
    // Modern-Hopfield-like content addressing: softmax over similarity scores.
    final mx = scores.values.reduce(max), exps = <String, double>{};
    var z = 0.0;
    for (final e in scores.entries) {
      final v = exp(4.0 * (e.value - mx)); exps[e.key] = v; z += v;
    }
    final out = exps.entries.map((e) => {'term': e.key, 'weight': e.value / max(1e-12, z)}).toList()
      ..sort((a, b) => (b['weight'] as double).compareTo(a['weight'] as double));
    return out.take(limit).toList();
  }

  Future<Map<String, dynamic>> stats() async {
    Future<int> count(String table) async => Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
    final metaRows = await db.query('meta');
    final meta = {for (final r in metaRows) '${r['k']}': '${r['v']}'};
    return {
      'concepts': await count('concepts'), 'relations': await count('relations'),
      'episodes': await count('episodes'), 'constructions': await count('constructions'),
      'contexts': await count('contexts'), 'cycles': int.tryParse(meta['cycles'] ?? '') ?? 0,
      'predictionError': double.tryParse(meta['last_prediction_error'] ?? '') ?? 0.0,
      'salience': double.tryParse(meta['last_salience'] ?? '') ?? 0.0,
    };
  }

  Future<String?> answerRelation(String question) async {
    final q = norm400(question).replaceAll(RegExp(r'[?!.]+$'), '');
    final ts = tokens400(q);
    if (ts.isEmpty) return null;
    final who = ts.first == 'chi';
    final what = ts.first == 'cosa' || (ts.length > 1 && ts[0] == 'che' && ts[1] == 'cosa');
    if (!who && !what) return null;
    final candidateVerbs = ts.where(looksVerb400).map(stem400).toList();
    if (candidateVerbs.isEmpty) return null;
    final p = candidateVerbs.first;
    final content = ts.where(isContent400).where((x) => stem400(x) != p).toList();
    if (who && content.isNotEmpty) {
      final object = content.last;
      final rows = await db.rawQuery('SELECT subject,count FROM relations WHERE predicate=? AND object LIKE ? AND negative=0 ORDER BY count DESC,last_seen DESC LIMIT 3', [p, '%$object%']);
      if (rows.isNotEmpty) return '${rows.first['subject']}';
    }
    if (what && content.isNotEmpty) {
      final subject = content.last;
      final rows = await db.rawQuery('SELECT object,location,count FROM relations WHERE predicate=? AND subject LIKE ? AND negative=0 ORDER BY count DESC,last_seen DESC LIMIT 3', [p, '%$subject%']);
      if (rows.isNotEmpty) {
        final o = '${rows.first['object']}', l='${rows.first['location']}';
        return o.isNotEmpty ? o : (l.isNotEmpty ? l : null);
      }
    }
    return null;
  }

  Future<void> clear() async {
    await db.transaction((tx) async {
      for (final table in ['concepts','contexts','relations','transitions','constructions','episodes','gaps','meta']) {
        await tx.delete(table);
      }
    });
  }
}

class CognitiveCore400 {
  final CognitiveStore400 store;
  final List<CognitiveFrame400> workingMemory = [];
  String activeGoal = '';
  CognitiveCore400(this.store);

  String get previousPredicate => workingMemory.isEmpty ? '' : workingMemory.last.predicate;

  Future<CognitiveTurn400> experience(String text, {String source = 'utente'}) async {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+|\n+')).where((x) => x.trim().isNotEmpty).toList();
    CognitiveTurn400? last;
    for (final sentence in sentences) {
      if (sentence.trim().endsWith('?')) continue; // Questions query memory; they are not facts.
      final frame = FrameInducer400.induce(sentence);
      final prev = previousPredicate;
      final predicted = await store.nextPredicates(prev);
      final total = predicted.values.fold<int>(0, (a, b) => a + b);
      final pObs = frame.predicate.isEmpty ? 0.0 : (predicted[frame.predicate] ?? 0) / max(1, total);
      final surprise = predicted.isEmpty ? .65 : (1 - pObs).clamp(0.0, 1.0);
      final sortedPred = predicted.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
      final predNames = sortedPred.take(4).map((e)=>e.key).toList();
      var entropy = 0.0;
      if (total > 0) {
        for (final n in predicted.values) {
          final p=n/total; if (p>0) entropy -= p*log(p);
        }
      }
      final uncertainty = predicted.length <= 1 ? (predicted.isEmpty ? .9 : .2) : (entropy / log(predicted.length)).clamp(0.0,1.0);
      final expMap = await store.exposures(frame.concepts);
      final novelty = frame.concepts.isEmpty ? .5 : frame.concepts.map((c)=>1/(1+(expMap[c]??0))).reduce((a,b)=>a+b)/frame.concepts.length;
      final existing = await store.relationCount(frame);
      final causal = RegExp(r'\b(perché|perche|quindi|perciò|poiché|poiche|causa|provoca|rende)\b', caseSensitive:false).hasMatch(sentence)
          ? 1.0 : (frame.valid && existing==0 ? .45 : .1);
      final activeTerms = workingMemory.expand((f)=>f.concepts).toSet();
      final persistence = frame.concepts.any(activeTerms.contains) ? .7 : .2;
      final goalTokens = tokens400(activeGoal).where(isContent400).toSet();
      final goalRel = goalTokens.isEmpty ? .0 : frame.concepts.any(goalTokens.contains) ? 1.0 : .0;
      final salience = (.28*surprise + .20*novelty + .16*uncertainty + .16*causal + .10*goalRel + .10*persistence).clamp(0.0,1.0);
      final att = CognitiveAttention400(surprise: surprise, novelty: novelty, uncertainty: uncertainty, causalImpact: causal, goalRelevance: goalRel, persistence: persistence, salience: salience);
      await store.observe(sentence: sentence, frame: frame, attention: att, previousPredicate: prev);
      if (frame.valid) {
        workingMemory.add(frame);
        if (workingMemory.length > 12) workingMemory.removeAt(0);
      }
      final gaps = await curiosity(limit: 3);
      last = CognitiveTurn400(frame, att, predNames, gaps);
    }
    return last ?? CognitiveTurn400(
      const CognitiveFrame400(subject:'',predicate:'',object:'',location:'',negative:false,concepts:[]),
      const CognitiveAttention400(surprise:0,novelty:0,uncertainty:0,causalImpact:0,goalRelevance:0,persistence:0,salience:0),
      const [], await curiosity(limit:3));
  }

  Future<String?> answer(String prompt) async {
    final q = norm400(prompt);
    if (q.isEmpty) return null;
    final direct = await store.answerRelation(q);
    if (direct != null) return direct;

    final meaning = RegExp(r"^(?:che cosa significa|cosa significa|cos'è|cos e|che cos'è|che cos e)\s+(.+?)[?!.]*$").firstMatch(q);
    if (meaning != null) return describeConcept(meaning[1]!);
    final know = RegExp(r'^(?:che cosa sai di|cosa sai di|parlami di)\s+(.+?)[?!.]*$').firstMatch(q);
    if (know != null) return describeConcept(know[1]!);
    final dont = RegExp(r'^(?:che cosa non sai di|cosa non sai di)\s+(.+?)[?!.]*$').firstMatch(q);
    if (dont != null) return ignorance( dont[1]! );
    final goal = RegExp(r'^(?:obiettivo|voglio capire|studia)\s*:?\s*(.+)$').firstMatch(q);
    if (goal != null) {
      activeGoal = goal[1]!.trim();
      return 'Obiettivo attivo: $activeGoal. Darò più salienza alle esperienze che lo riducono o lo chiariscono.';
    }
    final cues = tokens400(q).where(isContent400).toList();
    if (cues.isEmpty) return null;
    final recalled = await store.recall(cues, limit: 5);
    if (recalled.isEmpty) return null;
    final strong = recalled.where((x)=>(x['weight'] as double)>.08).map((x)=>x['term']).toList();
    if (strong.isEmpty) return null;
    return 'Le associazioni più attive nella mia memoria sono: ${strong.join(', ')}. Non ho ancora una relazione abbastanza determinata per rispondere con maggiore precisione.';
  }

  Future<String> describeConcept(String term) async {
    final q = norm400(term).replaceAll(RegExp(r'[?!.]+$'), '').trim();
    final c = await store.concept(q);
    if (c == null) return 'Non ho ancora abbastanza esperienza di “$q” per attribuirgli un significato.';
    final assoc = (c['associations'] as List).take(6).map((x)=>(x as Map)['term']).toList();
    final rel = (c['relations'] as List).take(5).map((x){
      final r=x as Map; return '${r['subject']} → ${r['predicate']} → ${r['object']}${'${r['location']}'.isEmpty?'':' (${r['location']})'}';
    }).toList();
    final parts=<String>[];
    parts.add('“$q” è stato osservato ${c['exposures']} volte');
    if (assoc.isNotEmpty) parts.add('compare soprattutto vicino a ${assoc.join(', ')}');
    if (rel.isNotEmpty) parts.add('partecipa a relazioni come ${rel.join('; ')}');
    return '${parts.join('. ')}. È una descrizione appresa dall’uso, non una definizione preinstallata.';
  }

  Future<String> ignorance(String term) async {
    final q=norm400(term).replaceAll(RegExp(r'[?!.]+$'),'').trim();
    final c=await store.concept(q);
    if(c==null) return 'Non so ancora nulla di “$q”. La domanda più utile è: che tipo di cosa è e che cosa può fare o subire?';
    final gaps=await store.topGaps(limit:20);
    final own=gaps.where((g)=>g['term']==q).toList();
    final rel=(c['relations'] as List).length;
    if(rel==0) return 'Conosco la forma “$q”, ma non ho ancora relazioni strutturate sufficienti: non so che tipo di cosa sia, che cosa faccia o quali proprietà la distinguano.';
    return 'Ho ${c['exposures']} osservazioni e $rel relazioni su “$q”, ma restano incerte proprietà, eccezioni, cause e confini del concetto${own.isEmpty?'':'. La priorità di approfondimento è ${((own.first['score'] as num)*100).round()}%'}.';
  }

  Future<List<String>> curiosity({int limit=6}) async {
    final gaps=await store.topGaps(limit:limit);
    return gaps.map((g){
      final t='${g['term']}', kind='${g['kind']}';
      return kind=='meaning' ? 'Che cos’è “$t” e quali proprietà lo distinguono?' : 'Quali proprietà di “$t” restano stabili in contesti diversi?';
    }).toList();
  }
}

class CognitiveCoreBridge400 {
  static CognitiveCore400? _core;
  static Future<CognitiveCore400> get core async => _core ??= CognitiveCore400(await CognitiveStore400.open());

  static bool isQuestion(String text) => text.trim().endsWith('?') || RegExp(r'^\s*(chi|cosa|che cosa|come|dove|quando|perché|perche|qual|quale|cos|parlami|che cosa sai|cosa sai|che cosa non sai|cosa non sai)\b', caseSensitive:false).hasMatch(text);

  static Future<String?> processChat(String text) async {
    final c=await core;
    if (isQuestion(text)) return c.answer(text);
    await c.experience(text, source:'chat');
    return null;
  }

  static Future<Map<String,dynamic>> stats() async => (await core).store.stats();
  static Future<void> reset() async { final c=await core; c.workingMemory.clear(); await c.store.clear(); }
  static Future<void> close() async { final c=_core; _core=null; if(c!=null) await c.store.close(); }
}
