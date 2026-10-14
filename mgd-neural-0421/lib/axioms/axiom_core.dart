import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';

typedef J = Map<String, dynamic>;
J copyJ(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
Object? ordered(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((e) => e.toString()).toList()..sort();
    return {for (final k in keys) k: ordered(v[k])};
  }
  if (v is List) return v.map(ordered).toList();
  return v;
}

String canonical(Object? v) => jsonEncode(ordered(v));
String axHash(Object? v) =>
    sha256.convert(utf8.encode(canonical(v))).toString();
bool equalJ(Object? a, Object? b) => canonical(a) == canonical(b);
List<String> axTokens(String s) {
  final out = RegExp(r'@[a-z]+|[\p{L}]+(?:-[\p{L}]+)*|[^\w\s]', unicode: true)
      .allMatches(s.toLowerCase())
      .map((m) => m.group(0)!)
      .toList();
  if (out.isNotEmpty && out.last == '.') out.removeLast();
  return out;
}

bool entity(String s) =>
    RegExp(r'^[\p{L}]+(?:-[\p{L}]+)*$', unicode: true).hasMatch(s);

/// Full-consumption unification, with a work budget independent of the LLM.
List<Map<String, List<String>>> matchAx(List pattern, List<String> seq) {
  final results = <Map<String, List<String>>>[];
  var work = 0;
  void walk(int i, int j, Map<String, List<String>> env) {
    if (++work > 20000) throw const FormatException('search_limit');
    if (i == pattern.length) {
      if (j == seq.length) results.add(env);
      return;
    }
    final p = pattern[i];
    if (p is String) {
      if (j < seq.length && seq[j] == p) walk(i + 1, j + 1, env);
      return;
    }
    final name = p['name'] as String;
    final old = env[name];
    if (old != null) {
      if (j + old.length <= seq.length &&
          equalJ(old, seq.sublist(j, j + old.length))) {
        walk(i + 1, j + old.length, env);
      }
      return;
    }
    final remaining = pattern.skip(i + 1).fold<int>(
        0, (n, e) => n + (e is String ? 1 : (e['minimum'] as int? ?? 1)));
    final upper = (p['maximum'] as int? ?? 24)
        .clamp(0, (seq.length - j - remaining).clamp(0, 48));
    for (var n = p['minimum'] as int? ?? 1; n <= upper; n++) {
      final value = seq.sublist(j, j + n);
      if (p['entity'] == true && (n != 1 || !entity(value.first))) continue;
      if (value.any(
          (x) => const ['.', '?', '!', ';'].contains(x) || x.startsWith('@')))
        continue;
      walk(i + 1, j + n, {...env, name: value});
    }
  }

  walk(0, 0, {});
  return results;
}

class AxiomStudent {
  final J model;
  AxiomStudent(Map value, {bool validate = true}) : model = copyJ(value) {
    if (validate) validateModel();
  }
  List get frames => model['frames'] as List;
  List get lexicon => model['lexicon'] as List;
  List get rules => model['rules'] as List;
  J get programs => Map<String, dynamic>.from(model['programs'] as Map);
  String get revision => axHash(model);
  String lexId(Map x) => 'lex:${axHash([
            x['surface'],
            x['intent'],
            x['frame_id']
          ]).substring(0, 16)}';

  void validateModel() {
    if (utf8.encode(jsonEncode(model)).length > 4000000)
      throw const FormatException('Mappa troppo grande per questo motore.');
    for (final k in ['frames', 'lexicon', 'rules']) {
      if (model[k] is! List || (model[k] as List).length > 4096)
        throw FormatException('Campo $k non valido.');
    }
    if (model['programs'] is! Map || programs.length > 128)
      throw const FormatException('Programmi non validi.');
    final ids = <String>{};
    for (final f in frames) {
      if (f is! Map || f['id'] is! String || !ids.add(f['id'] as String))
        throw const FormatException('Identificatore frame duplicato.');
      validatePattern(f['parts'] as List);
      final names =
          (f['parts'] as List).whereType<Map>().map((e) => e['name']).toList();
      if (!names.contains('predicate') ||
          f['roles'] is! List ||
          !(f['roles'] as List).every(names.contains)) {
        throw const FormatException('Ruoli o predicato mancanti.');
      }
    }
    for (final l in lexicon) {
      if (l is! Map ||
          l['surface'] is! List ||
          (l['surface'] as List).isEmpty ||
          (l['surface'] as List).length > 6 ||
          !(l['surface'] as List).every((x) => x is String && entity(x)) ||
          !ids.contains(l['frame_id']) ||
          l['intent'] is! String) {
        throw const FormatException('Collegamento lessicale non valido.');
      }
    }
    final ruleIds = <String>{};
    for (final r in rules) {
      if (r is! Map || r['id'] is! String || !ruleIds.add(r['id'] as String))
        throw const FormatException('Regola duplicata.');
      validatePattern(r['source'] as List);
      final vars = (r['source'] as List)
          .whereType<Map>()
          .map((e) => e['name'])
          .toSet()
          .toList()
        ..sort((a, b) => '$a'.compareTo('$b'));
      if (r['target'] is! List ||
          (r['target'] as List).length > 32 ||
          !(r['target'] as List).every((e) => e is String))
        throw const FormatException('Riscrittura non valida.');
      final refs = (r['target'] as List)
          .cast<String>()
          .where((s) => s.startsWith(r'$'))
          .map((s) => s.substring(1))
          .toList()
        ..sort();
      if (!equalJ(vars, refs))
        throw const FormatException('La regola perde o duplica una variabile.');
      if ((r['target'] as List)
          .any((s) => (s as String).startsWith('@') && s != '@not'))
        throw const FormatException('Marcatore interno sconosciuto.');
    }
    for (final p in programs.values) validateProgram(p as Map);
  }

  static void validatePattern(List p) {
    if (p.isEmpty || p.length > 32)
      throw const FormatException('Pattern fuori limite.');
    for (final x in p) {
      if (x is String) {
        if (x.isEmpty || x.length > 80 || x.startsWith('@'))
          throw const FormatException('Letterale non valido.');
      } else if (x is Map) {
        final lo = x['minimum'] ?? 1, hi = x['maximum'] ?? 24;
        if (x['name'] is! String ||
            lo is! int ||
            hi is! int ||
            lo < 1 ||
            hi < lo ||
            hi > 24) throw const FormatException('Variabile fuori limite.');
      } else {
        throw const FormatException('Pattern non valido.');
      }
    }
  }

  static void validateProgram(Map p) {
    void expr(dynamic x) {
      if (x is! Map || !const ['arg', 'read', 'none'].contains(x['kind']))
        throw const FormatException(
            'Primitiva sconosciuta: richiesta di estensione, non un assioma accettato.');
      if (x['kind'] != 'none' &&
          (x['arg'] is! String || !entity(x['arg'] as String)))
        throw const FormatException('Argomento non valido.');
      if (x['kind'] == 'read' &&
          !const ['location', 'holder', 'owner'].contains(x['relation']))
        throw const FormatException(
            'Relazione non eseguibile nel dominio corrente.');
    }

    if (p['guards'] is! List ||
        p['writes'] is! List ||
        (p['guards'] as List).length > 12 ||
        (p['writes'] as List).length > 12 ||
        (p['writes'] as List).isEmpty)
      throw const FormatException('Programma fuori limite.');
    for (final g in p['guards'] as List) {
      if (!const ['eq', 'neq', 'known'].contains(g['kind']))
        throw const FormatException('Condizione sconosciuta.');
      expr(g['left']);
      if (g['kind'] != 'known') expr(g['right']);
    }
    final targets = <String>{};
    for (final w in p['writes'] as List) {
      if (!const ['location', 'holder', 'owner'].contains(w['relation']) ||
          w['target_arg'] is! String ||
          !targets.add('${w['relation']}:${w['target_arg']}'))
        throw const FormatException('Scrittura duplicata o non valida.');
      expr(w['value']);
    }
  }

  J parse(String text) {
    if (text.length > 4096 || text.contains('@'))
      return {'status': 'search_limit', 'proof': []};
    final start = axTokens(text);
    if (start.length > 48) return {'status': 'search_limit', 'proof': []};
    final queue = Queue<J>()
      ..add({'tokens': start, 'neg': false, 'proof': <String>[], 'depth': 0});
    final seen = <String>{}, readings = <String, J>{};
    var exhausted = false;
    try {
      while (queue.isNotEmpty) {
        final item = queue.removeFirst();
        final current = List<String>.from(item['tokens'] as List);
        var neg = item['neg'] as bool;
        while (current.isNotEmpty && current.first == '@not') {
          neg = !neg;
          current.removeAt(0);
        }
        final key = canonical([current, neg]);
        if (seen.contains(key)) continue;
        if (seen.length >= 512) {
          exhausted = true;
          break;
        }
        seen.add(key);
        final proof = List<String>.from(item['proof'] as List);
        for (final f in frames) {
          final entries = lexicon.where((l) => l['frame_id'] == f['id']);
          for (final env in matchAx(f['parts'] as List, current)) {
            for (final l in entries) {
              if (!equalJ(env['predicate'], l['surface'])) continue;
              final args = {
                for (final role in f['roles'] as List)
                  role as String: env[role]!.first
              };
              final r = <String, dynamic>{
                'status': 'ok',
                'intent': l['intent'],
                'args': args,
                'negated': neg,
                'proof': [...proof, f['id'], lexId(l as Map)],
                'normal': current.join(' ')
              };
              final signature = canonical([l['intent'], args, neg]);
              if (!readings.containsKey(signature) ||
                  (r['proof'] as List).length <
                      (readings[signature]!['proof'] as List).length)
                readings[signature] = r;
            }
          }
        }
        for (final r in rules) {
          for (final env in matchAx(r['source'] as List, current)) {
            final output = <String>[];
            for (final p in (r['target'] as List).cast<String>()) {
              output.addAll(p.startsWith(r'$') ? env[p.substring(1)]! : [p]);
            }
            if (equalJ(output, current)) continue;
            if ((item['depth'] as int) >= 10) {
              if (!seen.contains(canonical([output, neg]))) exhausted = true;
            } else {
              if (queue.length > 4096) {
                exhausted = true;
                break;
              }
              queue.add({
                'tokens': output,
                'neg': neg,
                'proof': [...proof, r['id']],
                'depth': (item['depth'] as int) + 1
              });
            }
          }
        }
      }
    } on FormatException {
      exhausted = true;
    }
    if (exhausted)
      return {'status': 'search_limit', 'explored': seen.length, 'proof': []};
    if (readings.isEmpty)
      return {'status': 'unrecognized', 'explored': seen.length, 'proof': []};
    if (readings.length > 1)
      return {
        'status': 'ambiguous',
        'alternatives': readings.values.toList(),
        'proof': []
      };
    return {...readings.values.first, 'explored': seen.length};
  }

  J execute(String text, Map before) {
    final reading = parse(text), world = copyJ(before);
    final out = <String, dynamic>{'reading': reading, 'world': world};
    if (reading['status'] != 'ok') return {...out, 'status': reading['status']};
    final p = programs[reading['intent']];
    if (p == null) return {...out, 'status': 'missing_semantic_composition'};
    if (reading['negated'] == true)
      return {...out, 'status': 'event_denied_no_update', 'writes': []};
    final args = reading['args'] as Map;
    final reads = <String>{}, missing = <String>{};
    (bool, dynamic) value(Map e) {
      if (e['kind'] == 'none') return (true, null);
      final name = args[e['arg']];
      if (name == null)
        throw const FormatException('Ruolo necessario assente nel programma.');
      if (e['kind'] == 'arg') return (true, name);
      final rel = e['relation'] as String, table = before[rel] as Map? ?? {};
      reads.add('$rel:$name');
      var known = table.containsKey(name) &&
          !(const ['location', 'owner'].contains(rel) && table[name] == null);
      if (rel == 'location' && table.containsKey(name) && table[name] == null) {
        reads.add('holder:$name');
        if ((before['holder'] as Map? ?? {})[name] != null) known = true;
      }
      if (!known) missing.add('$rel:$name');
      return (known, table[name]);
    }

    try {
      var rejected = false;
      for (final g in p['guards'] as List) {
        final a = value(g['left'] as Map);
        if (g['kind'] == 'known') {
          if (a.$1 && a.$2 == null) rejected = true;
        } else {
          final b = value(g['right'] as Map);
          if (a.$1 && b.$1 && (g['kind'] == 'eq' ? a.$2 != b.$2 : a.$2 == b.$2))
            rejected = true;
        }
      }
      if (rejected)
        return {
          ...out,
          'status': 'preconditions_false',
          'reads': reads.toList(),
          'writes': []
        };
      final writes = <J>[];
      for (final w in p['writes'] as List) {
        final v = value(w['value'] as Map), target = args[w['target_arg']];
        if (target == null)
          throw const FormatException('Destinatario della scrittura assente.');
        writes
            .add({'relation': w['relation'], 'entity': target, 'value': v.$2});
      }
      if (missing.isNotEmpty)
        return {
          ...out,
          'status': 'needs_context',
          'missing_facts': missing.toList()..sort(),
          'teach_axiom_instead': false
        };
      for (final w in writes) {
        (world[w['relation']] ??= <String, dynamic>{})[w['entity']] =
            w['value'];
      }
      return {
        ...out,
        'status': 'applied',
        'reads': reads.toList(),
        'writes': writes,
        'program': 'program:${reading['intent']}'
      };
    } on FormatException catch (e) {
      return {...out, 'status': 'invalid_composition', 'error': e.message};
    }
  }

  J probe(Map q) {
    final r = parse(q['text'] as String);
    final expected = q['parse_status'] ?? 'ok';
    var pass = r['status'] == expected;
    if (expected == 'ok')
      pass = pass &&
          r['intent'] == q['intent'] &&
          equalJ(r['args'], q['args']) &&
          r['negated'] == (q['negated'] ?? false);
    J? run;
    if (q.containsKey('before')) {
      run = execute(q['text'] as String, q['before'] as Map);
      pass = pass &&
          run['status'] == q['expected_status'] &&
          equalJ(run['world'], q['expected_after']);
    }
    return {
      'id': q['id'],
      'text': q['text'],
      'passed': pass,
      'reading': r,
      if (run != null) 'execution': run
    };
  }

  /// Learns a lexical coupling and reusable role frame from one annotated example.
  void anchored(Map lesson) {
    final seq = axTokens(lesson['text'] as String),
        anchor = axTokens(lesson['anchor'] as String);
    if (anchor.isEmpty || anchor.length > 6)
      throw const FormatException('Predicato mancante.');
    final positions = <int>[];
    for (var i = 0; i + anchor.length <= seq.length; i++) {
      if (equalJ(seq.sublist(i, i + anchor.length), anchor)) positions.add(i);
    }
    if (positions.length != 1)
      throw const FormatException(
          'Il predicato deve identificare un unico segmento.');
    final args = Map<String, dynamic>.from(lesson['args'] as Map);
    if (args.values.toSet().length != args.length ||
        !args.values.every((v) => v is String && entity(v)))
      throw const FormatException('Usare entità distinte.');
    final parts = <dynamic>[], found = <String>[];
    for (var i = 0; i < seq.length;) {
      if (i == positions.single) {
        parts.add(
            {'name': 'predicate', 'minimum': 1, 'maximum': 6, 'entity': false});
        i += anchor.length;
        continue;
      }
      final roles = args.keys
          .where((r) => args[r].toString().toLowerCase() == seq[i])
          .toList();
      if (roles.isNotEmpty) {
        found.add(roles.single);
        parts.add(
            {'name': roles.single, 'minimum': 1, 'maximum': 1, 'entity': true});
      } else {
        parts.add(seq[i]);
      }
      i++;
    }
    final roles = args.keys.toList()..sort();
    found.sort();
    if (!equalJ(found, roles))
      throw const FormatException('Ogni ruolo deve apparire una volta.');
    final existing = frames
        .where((f) => equalJ(f['parts'], parts) && equalJ(f['roles'], roles));
    final id = existing.isNotEmpty
        ? existing.first['id']
        : 'frame:${axHash([parts, roles]).substring(0, 16)}';
    if (existing.isEmpty)
      frames.add({'id': id, 'parts': parts, 'roles': roles});
    final entry = {
      'surface': anchor,
      'intent': lesson['intent'],
      'frame_id': id,
      'lesson_id': lesson['id']
    };
    if (!lexicon.any((x) => lexId(x as Map) == lexId(entry)))
      lexicon.add(entry);
  }

  void applyLesson(Map lesson) {
    switch (lesson['kind']) {
      case 'anchored':
        anchored(lesson);
        break;
      case 'rewrite':
        final r = copyJ(lesson['rule'] as Map),
            examples = lesson['equivalences'] as List? ?? [];
        if (examples.length < 2 ||
            examples.map((e) => e['source']).toSet().length < 2)
          throw const FormatException(
              'Servono almeno due equivalenze diverse.');
        final bindings = <String, Set<String>>{};
        for (final e in examples) {
          var valid = false;
          for (final env in matchAx(
              r['source'] as List, axTokens(e['source'] as String))) {
            final transformed = <String>[];
            for (final s in (r['target'] as List).cast<String>()) {
              transformed.addAll(
                  s.startsWith(r'$') ? (env[s.substring(1)] ?? []) : [s]);
            }
            if (equalJ(transformed, axTokens(e['target'] as String))) {
              valid = true;
              for (final k in env.keys) {
                (bindings[k] ??= <String>{}).add(canonical(env[k]));
              }
            }
          }
          if (!valid)
            throw const FormatException('La regola non spiega le equivalenze.');
        }
        if (bindings.isEmpty || bindings.values.any((v) => v.length < 2))
          throw const FormatException('Variare ogni ruolo fra gli esempi.');
        if (rules.any((x) => x['id'] == r['id']))
          throw const FormatException(
              'Nuovo ID richiesto; vietata sovrascrittura silenziosa.');
        r['lesson_ids'] = [lesson['id']];
        rules.add(r);
        break;
      case 'program':
        validateProgram(lesson['program'] as Map);
        final p = copyJ(lesson['program'] as Map);
        p['lesson_id'] = lesson['id'];
        (model['programs'] as Map)[lesson['intent']] = p;
        break;
      default:
        throw const FormatException(
            'Primitiva non eseguibile: serve una nuova estensione verificata del linguaggio.');
    }
    (model['lesson_ids'] ??= <String>[]).add(lesson['id']);
    validateModel();
  }

  /// All nodes are linked to the executable model, not an LLM-drawn illustration.
  List<J> graph() {
    final nodes = <String, J>{};
    void add(
        String id, String label, String type, List<String> deps, Object? data) {
      nodes[id] = {
        'id': id,
        'label': label,
        'type': type,
        'depends': deps,
        'data': data,
        'minimality': type == 'primitive'
            ? 'Base dichiarata del DSL; minimalità assoluta non certificata.'
            : 'Componente scomponibile / da sottoporre a test.'
      };
    }

    for (final p in [
      'bind',
      'read',
      'null',
      'eq',
      'neq',
      'known',
      'write',
      'sequence',
      'rewrite',
      'negation'
    ]) {
      add('primitive:$p', p, 'primitive', [], {
        'scope':
            'Linguaggio operativo finito, non atomo universale del significato.'
      });
    }
    add('primitive:boolean_not', 'Negazione booleana', 'primitive', [],
        {'scope': 'Operatore del DSL dichiarato.'});
    add('primitive:presence', 'Presenza del dato', 'primitive', [], {
      'scope': 'Distinguere un campo assente da un valore nullo esplicito.'
    });
    add(
        'primitive:neq',
        'Diversità',
        'expression',
        ['primitive:eq', 'primitive:boolean_not'],
        {'definition': 'not(eq(a,b))'});
    add('primitive:known', 'Valore noto', 'expression', [
      'primitive:read',
      'primitive:presence',
      'primitive:null',
      'primitive:eq',
      'primitive:boolean_not'
    ], {
      'definition':
          'Presenza epistemica del dato e valore diverso da null; il simulatore distingue assenza strutturale e dato ignoto.'
    });
    String expression(Map e) {
      final id = 'expr:${axHash(e).substring(0, 16)}';
      final op = e['kind'] == 'arg'
          ? 'bind'
          : e['kind'] == 'none'
              ? 'null'
              : 'read';
      add(
          id,
          e['kind'] == 'read'
              ? 'Leggi ${e['relation']} di ${e['arg']}'
              : e['kind'] == 'arg'
                  ? 'Ruolo ${e['arg']}'
                  : 'Assenza esplicita',
          'expression',
          ['primitive:$op'],
          e);
      return id;
    }

    for (final entry in programs.entries) {
      final p = entry.value as Map, parts = <String>[];
      for (var i = 0; i < (p['guards'] as List).length; i++) {
        final g = p['guards'][i] as Map, id = 'guard:${entry.key}:$i';
        add(
            id,
            'Condizione ${entry.key} ${i + 1}',
            'guard',
            [
              'primitive:${g['kind']}',
              expression(g['left'] as Map),
              if (g['right'] != null) expression(g['right'] as Map)
            ],
            g);
        parts.add(id);
      }
      for (var i = 0; i < (p['writes'] as List).length; i++) {
        final w = p['writes'][i] as Map, id = 'write:${entry.key}:$i';
        add(id, 'Imposta ${w['relation']}(${w['target_arg']})', 'write',
            ['primitive:write', expression(w['value'] as Map)], w);
        parts.add(id);
      }
      add('program:${entry.key}', entry.key, 'program',
          ['primitive:sequence', ...parts], p);
    }
    for (final f in frames) {
      add(
          f['id'] as String,
          (f['parts'] as List)
              .map((p) => p is String ? p : '\$${p['name']}')
              .join(' '),
          'frame',
          ['primitive:bind'],
          f);
    }
    for (final l in lexicon) {
      add(lexId(l as Map), (l['surface'] as List).join(' '), 'lexeme',
          [l['frame_id'] as String, 'program:${l['intent']}'], l);
    }
    for (final r in rules) {
      add(
          r['id'] as String,
          (r['id'] as String).replaceFirst('rule:', ''),
          'rule',
          [
            'primitive:rewrite',
            if ((r['target'] as List).contains('@not')) 'primitive:negation'
          ],
          r);
    }
    return nodes.values.toList();
  }

  AxiomStudent without(String id) {
    final result = AxiomStudent(model), m = result.model;
    if (id.startsWith('lex:')) {
      result.lexicon.removeWhere((x) => result.lexId(x as Map) == id);
    } else if (id.startsWith('frame:')) {
      result.frames.removeWhere((x) => x['id'] == id);
      result.lexicon.removeWhere((x) => x['frame_id'] == id);
    } else if (id.startsWith('rule:')) {
      result.rules.removeWhere((x) => x['id'] == id);
    } else if (id.startsWith('program:')) {
      (m['programs'] as Map).remove(id.substring(8));
    } else if (id.startsWith('guard:') || id.startsWith('write:')) {
      final pieces = id.split(':'),
          key = pieces.first == 'guard' ? 'guards' : 'writes';
      (m['programs'][pieces[1]][key] as List).removeAt(int.parse(pieces[2]));
    } else {
      throw const FormatException(
          'Primitiva fissa: ablazione non implementata; nessuna certificazione.');
    }
    return result;
  }
}

/// Pure worker function: safe to run in a Flutter isolate.
J axiomJob(J request) {
  final student = AxiomStudent(request['model'] as Map);
  final probes = (request['probes'] as List? ?? []).cast<Map>();
  switch (request['job']) {
    case 'parse':
      return student.execute(
          request['text'] as String, request['world'] as Map? ?? {});
    case 'tests':
      final results = probes.map(student.probe).toList();
      return {
        'passed': results.where((r) => r['passed'] == true).length,
        'total': results.length,
        'results': results,
        'revision': student.revision
      };
    case 'ablate':
      final passing =
          probes.where((q) => student.probe(q)['passed'] == true).toList();
      final candidate = student.without(request['node'] as String);
      final failures = passing
          .map(candidate.probe)
          .where((r) => r['passed'] != true)
          .toList();
      final coverage = passing
          .where((q) => (student.parse(q['text'] as String)['proof'] as List)
              .contains(request['node']))
          .length;
      return {
        'node': request['node'],
        'revision': student.revision,
        'tested': passing.length,
        'covered_parse_paths': coverage,
        'status': passing.isEmpty
            ? 'inconclusive'
            : failures.isEmpty
                ? 'no_regression_observed'
                : 'necessary_on_tested_cases',
        'witnesses': failures.take(8).toList(),
        'regressions': failures.length,
        'absolute_minimality': false
      };
    case 'teach':
      return validateTeaching(student, request['proposal'] as Map, probes);
    default:
      throw const FormatException('Operazione sconosciuta.');
  }
}

/// LLM assertions are proposals, not proof of correctness or independent labels.
J validateTeaching(AxiomStudent original, Map proposal, List<Map> regression) {
  final lessons = proposal['lessons'] as List? ?? [],
      tasks = proposal['probes'] as List? ?? [];
  if (lessons.isEmpty)
    return {
      'accepted': false,
      'reason':
          proposal['diagnosis'] ?? 'Servono nuove lezioni o dati contestuali.'
    };
  if (lessons.length > 4 || tasks.length < 3 || tasks.length > 24)
    return {
      'accepted': false,
      'reason': 'Fornire 1–4 lezioni e 3–24 prove formative distinte.'
    };
  if (tasks.any((q) =>
      q is! Map ||
      q['text'] is! String ||
      q['args'] is! Map ||
      q['intent'] is! String))
    return {'accepted': false, 'reason': 'Test malformati.'};
  final texts =
      tasks.map((q) => canonical(axTokens(q['text'] as String))).toSet();
  final trainingTexts = lessons
      .expand((l) => [
            if (l['text'] != null) canonical(axTokens(l['text'] as String)),
            for (final e in l['equivalences'] as List? ?? [])
              canonical(axTokens(e['source'] as String))
          ])
      .toSet();
  if (texts.length != tasks.length ||
      texts.intersection(trainingTexts).isNotEmpty ||
      tasks.map((q) => canonical(q['args'])).toSet().length < 3)
    return {
      'accepted': false,
      'reason': 'I test devono differire dalle lezioni e variare i ruoli.'
    };
  if (lessons.any((l) => l['kind'] == 'program') &&
      (tasks
                  .where(
                      (q) => q['before'] is Map && q['expected_after'] is Map)
                  .length <
              3 ||
          !tasks.any((q) =>
              q['expected_status'] == 'preconditions_false' ||
              q['expected_status'] == 'needs_context')))
    return {
      'accepted': false,
      'reason':
          'Una composizione richiede transizioni e almeno un controesempio contestuale.'
    };
  final targetTask = proposal['task'];
  if (targetTask is! Map ||
      targetTask['text'] is! String ||
      targetTask['intent'] is! String ||
      targetTask['args'] is! Map)
    return {
      'accepted': false,
      'reason': 'Il task originale deve essere annotato esplicitamente.'
    };
  if (tasks.any((q) =>
      q['before'] is! Map ||
      q['expected_after'] is! Map ||
      q['expected_status'] is! String))
    return {
      'accepted': false,
      'reason':
          'Ogni prova deve verificare anche un effetto operativo, non soltanto riconoscere una frase.'
    };
  if (!tasks.any((q) => const [
        'preconditions_false',
        'needs_context',
        'event_denied_no_update'
      ].contains(q['expected_status'])))
    return {
      'accepted': false,
      'reason':
          'Manca un contrasto operativo: negazione, precondizione falsa o contesto insufficiente.'
    };
  final evaluationTasks = [targetTask, ...tasks];
  final protected =
      regression.where((q) => original.probe(q)['passed'] == true).toList();
  final attempts = <J>[];
  // Find the smallest successful subset among the provided alternatives only.
  final masks = List.generate((1 << lessons.length) - 1, (i) => i + 1)
    ..sort((a, b) => a
        .toRadixString(2)
        .replaceAll('0', '')
        .length
        .compareTo(b.toRadixString(2).replaceAll('0', '').length));
  final already =
      evaluationTasks.every((q) => original.probe(q as Map)['passed'] == true);
  if (already)
    return {
      'accepted': false,
      'reason': 'Le prove sono già superate: nessun nuovo assioma giustificato.'
    };
  for (final mask in masks) {
    final candidate = AxiomStudent(original.model);
    try {
      for (var i = 0; i < lessons.length; i++) {
        if ((mask & (1 << i)) != 0) candidate.applyLesson(lessons[i] as Map);
      }
      final transfer =
          evaluationTasks.map((q) => candidate.probe(q as Map)).toList();
      final loss = protected
          .map(candidate.probe)
          .where((r) => r['passed'] != true)
          .toList();
      final good = transfer.every((r) => r['passed'] == true) && loss.isEmpty;
      attempts.add({
        'mask': mask,
        'transfer_passed': transfer.where((r) => r['passed'] == true).length,
        'regressions': loss.length,
        'failures': transfer.where((r) => r['passed'] != true).take(3).toList()
      });
      if (good)
        return {
          'accepted': true,
          'model': candidate.model,
          'new_probes': tasks,
          'revision_before': original.revision,
          'revision_after': candidate.revision,
          'protected_tested': protected.length,
          'transfer_tested': evaluationTasks.length,
          'attempts': attempts,
          'scope':
              'Verifica formativa sul frammento e regressioni note. Non prova indipendente né minimalità assoluta.',
          'mask': mask
        };
    } catch (e) {
      attempts.add({'mask': mask, 'error': '$e'});
    }
  }
  return {
    'accepted': false,
    'reason':
        'Le proposte non bastano oppure danneggiano conoscenze precedenti. Serve altra istruzione.',
    'attempts': attempts
  };
}
