// Online construction/distribution learner. No pretrained weights or hidden corpus.
// Counts describe observed usage, not truth. Roles are supplied by a fallible parser.
import 'dart:convert';
import 'dart:math';
import 'cls_core_v0340.dart';

String norm350(String x) =>
    x.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r'\s+'), ' ').trim();
List<String> tokens350(String x) => RegExp(
  r"[a-zàèéìòù]+(?:'[a-zàèéìòù]+)?|[0-9]+",
).allMatches(norm350(x)).map((m) => m[0]!).toList();

class UsageDelta350 {
  final Map<String, Map<String, int>> counts = {};
  void add(String group, String feature, [int n = 1]) {
    if (feature.length > 400 || group.length > 240) return;
    final row = counts.putIfAbsent(group, () => {});
    row[feature] = (row[feature] ?? 0) + n;
  }

  Map<String, dynamic> toJson() => counts;
  static UsageDelta350 fromJson(Map data) {
    final out = UsageDelta350();
    for (final e in data.entries) {
      if (e.value is Map) {
        out.counts['${e.key}'] = (e.value as Map).map(
          (k, v) => MapEntry('$k', (v as num).toInt()),
        );
      }
    }
    return out;
  }
}

/// Reversible sufficient statistics: deleting a document subtracts its contribution.
/// No complete sentences are stored; local windows contain at most two neighbours.
class CompetenceLanguage350 {
  final Map<String, Map<String, int>> counts;
  CompetenceLanguage350([Map<String, Map<String, int>>? data])
    : counts = data ?? {};
  static const functionWords = {
    'il',
    'lo',
    'la',
    'i',
    'gli',
    'le',
    'un',
    'uno',
    'una',
    "l'",
    'di',
    'del',
    'della',
    'dei',
    'degli',
    'delle',
    'a',
    'al',
    'alla',
    'da',
    'dal',
    'dalla',
    'in',
    'nel',
    'nella',
    'nei',
    'nelle',
    'su',
    'sul',
    'sulla',
    'con',
    'per',
    'tra',
    'fra',
    'e',
    'o',
    'non',
    'che',
    'si',
    'mi',
    'ti',
    'ci',
    'vi',
    'è',
    'era',
    'sono',
    'erano',
  };
  static String head(String phrase) {
    final words = tokens350(phrase);
    return words.firstWhere(
      (w) => !functionWords.contains(w),
      orElse: () => '',
    );
  }

  static List<String> headFeatures(String phrase) {
    final ts = tokens350(phrase), h = head(phrase);
    if (h.isEmpty) return [];
    return [
      'word:$h',
      if (ts.isNotEmpty && functionWords.contains(ts.first)) 'det:${ts.first}',
      if (h.length > 2) 'suffix:${h.substring(h.length - 1)}',
    ];
  }

  static UsageDelta350 observe(
    String sentence, {
    List<Map<String, dynamic>> events = const [],
  }) {
    final d = UsageDelta350(), ts = tokens350(sentence);
    if (ts.length > 256)
      return d; // A working-unit budget, explicitly counted upstream.
    for (var i = 0; i < ts.length; i++) {
      final w = ts[i];
      d.add('lexicon', w);
      d.add('next:${i == 0 ? '^' : ts[i - 1]}', w);
      d.add('previous:${i + 1 == ts.length ? r'$' : ts[i + 1]}', w);
      if (i > 0 && i + 1 < ts.length) d.add('gap:${ts[i - 1]}|${ts[i + 1]}', w);
      if (!functionWords.contains(w)) {
        for (var j = max(0, i - 3); j <= min(ts.length - 1, i + 3); j++) {
          if (j != i && !functionWords.contains(ts[j])) {
            // Signed offset retains order; the word-pair alone is NOT a proposition.
            d.add('context:$w', '${j - i}:${ts[j]}');
          }
        }
      }
    }
    if (ts.isNotEmpty) d.add('next:${ts.last}', r'$');
    for (final e in events) {
      if (e['epistemic'] != 'asserted' ||
          e['kind'] == 'cause' ||
          '${e['resolution']}'.contains('passive_roles'))
        continue;
      final verb = '${e['surface'] ?? e['predicate'] ?? ''}';
      final subject = '${e['subjectSurface'] ?? e['subject'] ?? ''}';
      if (verb.isEmpty || subject.isEmpty) continue;
      d.add('predicates', verb);
      final structure =
          '${e['negative'] == true ? 'S-N-V' : 'S-V'}'
          '${'${e['object'] ?? ''}'.isEmpty ? '' : '-O'}'
          '${'${e['target'] ?? ''}'.isEmpty ? '' : '-T'}'
          '${'${e['location'] ?? ''}'.isEmpty ? '' : '-L'}';
      d.add('constructions', structure);
      d.add('verbFrames:$verb', structure);
      d.add('role:subject', head(subject));
      if ('${e['object'] ?? ''}'.isNotEmpty)
        d.add('role:object', head('${e['object']}'));
      if ('${e['location'] ?? ''}'.isNotEmpty)
        d.add('role:location', head('${e['location']}'));
      for (final f in headFeatures(subject)) {
        d.add('agreement:$f', verb);
        final last = tokens350(verb).last;
        d.add(
          'endingAgreement:$f',
          last.length < 2 ? last : last.substring(last.length - 2),
        );
      }
      d.add('predicateObjects:$verb', head('${e['object'] ?? ''}'));
      final sh = head(subject), oh = head('${e['object'] ?? ''}');
      if (sh.isNotEmpty) d.add('sense:$sh', 'subject|${e['predicate']}|$oh');
      if (oh.isNotEmpty) d.add('sense:$oh', 'object|${e['predicate']}|$sh');
    }
    return d;
  }

  /// Overlong working fragments still teach local usage, never fake sentence boundaries.
  static UsageDelta350 observeFragment(String fragment) {
    final ts = tokens350(fragment), d = UsageDelta350();
    for (var i = 0; i < ts.length; i++) {
      final w = ts[i];
      d.add('lexicon', w);
      if (i > 0) d.add('next:${ts[i - 1]}', w);
      if (i + 1 < ts.length) d.add('previous:${ts[i + 1]}', w);
      if (i > 0 && i + 1 < ts.length) d.add('gap:${ts[i - 1]}|${ts[i + 1]}', w);
      if (!functionWords.contains(w))
        for (var j = max(0, i - 3); j <= min(ts.length - 1, i + 3); j++) {
          if (j != i && !functionWords.contains(ts[j]))
            d.add('context:$w', '${j - i}:${ts[j]}');
        }
    }
    return d;
  }

  void apply(UsageDelta350 delta, {int sign = 1}) {
    if (sign != 1 && sign != -1) throw ArgumentError('sign');
    // Validate subtraction before mutation: no partially corrupted unlearning.
    if (sign < 0) {
      for (final r in delta.counts.entries) {
        for (final e in r.value.entries) {
          if ((counts[r.key]?[e.key] ?? 0) < e.value)
            throw StateError('Contributo non presente.');
        }
      }
    }
    for (final r in delta.counts.entries) {
      final row = counts.putIfAbsent(r.key, () => {});
      for (final e in r.value.entries) {
        final n = (row[e.key] ?? 0) + sign * e.value;
        if (n == 0) {
          row.remove(e.key);
        } else {
          row[e.key] = n;
        }
      }
      if (row.isEmpty) counts.remove(r.key);
    }
  }

  List<Map<String, dynamic>> associations(String word, {int limit = 12}) {
    final row = counts['context:${norm350(word)}'] ?? {},
        combined = <String, int>{};
    for (final e in row.entries) {
      final key = e.key.substring(e.key.indexOf(':') + 1);
      combined[key] = (combined[key] ?? 0) + e.value;
    }
    final out = combined.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return out
        .take(limit)
        .map((e) => {'word': e.key, 'observations': e.value})
        .toList();
  }

  List<Map<String, dynamic>> usages(String word, {int limit = 12}) {
    final normalized = norm350(word), result = <Map<String, dynamic>>[];
    for (final r in counts.entries) {
      if (r.key.startsWith('gap:') && r.value.containsKey(normalized)) {
        result.add({
          'frame': r.key.substring(4).replaceFirst('|', ' ___ '),
          'count': r.value[normalized],
        });
      }
    }
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result.take(limit).toList();
  }

  /// Candidates are supplied by the evaluator/user, never added to training.
  /// Larger score means more supported observed usage, not a grammatical proof.
  Map<String, dynamic> compare(List<String> candidates) {
    final results = <Map<String, dynamic>>[];
    for (final sentence in candidates) {
      final ts = tokens350(sentence);
      double score = 0;
      int observations = 0;
      final reasons = <String>[];
      for (var i = 0; i < ts.length; i++) {
        final row = counts['next:${i == 0 ? '^' : ts[i - 1]}'] ?? {};
        if (row.isEmpty) continue;
        final n = row[ts[i]] ?? 0,
            total = row.values.fold<int>(0, (a, b) => a + b);
        score += log((n + .1) / (total + .1 * (row.length + 1)));
        observations += n;
      }
      // Long-distance head agreement is learned from parsed subject phrases.
      final pred = counts['predicates'] ?? {};
      final at = ts.indexWhere(pred.containsKey);
      if (at > 0) {
        final subject = ts.take(at).join(' '), verb = ts[at];
        for (final f in headFeatures(subject)) {
          final row = counts['agreement:$f'] ?? {};
          if (row.isEmpty) continue;
          final total = row.values.fold<int>(0, (a, b) => a + b),
              n = row[verb] ?? 0;
          final weight = f.startsWith('word:')
              ? 2.0
              : f.startsWith('det:')
              ? 1.5
              : .5;
          score += weight * log((n + .2) / (total + .2 * (row.length + 1)));
          if (n > 0) reasons.add('$f → $verb: $n osservazioni');
          final ending = verb.length < 2
              ? verb
              : verb.substring(verb.length - 2);
          final endings = counts['endingAgreement:$f'] ?? {};
          if (endings.isNotEmpty) {
            final observed = endings[ending] ?? 0,
                totalEnd = endings.values.fold<int>(0, (a, b) => a + b);
            score +=
                weight *
                log((observed + .2) / (totalEnd + .2 * (endings.length + 1)));
            if (observed > 0)
              reasons.add(
                '$f → finale -$ending: $observed osservazioni trasversali',
              );
          }
        }
      }
      results.add({
        'sentence': sentence,
        'score': score / max(1, ts.length),
        'support': observations,
        'reasons': reasons,
      });
    }
    results.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    final has = results.any(
      (r) => (r['support'] as int) > 0 || (r['reasons'] as List).isNotEmpty,
    );
    final clear =
        has &&
        results.isNotEmpty &&
        (results.length == 1 ||
            ((results[0]['score'] as double) - (results[1]['score'] as double))
                    .abs() >
                1e-9);
    return {
      'status': clear ? 'preference' : 'undetermined',
      'best': clear ? results.first['sentence'] : null,
      'ranking': results,
      'note':
          'Preferenza statistica appresa; non certifica tutta la grammatica.',
    };
  }

  Map<String, dynamic> compose(String subject, String verb, String object) {
    final v = norm350(verb), available = counts['verbFrames:$v'] ?? {};
    // Prototype retrieval is Hopfield over symbolic construction features.
    final candidates = <Pattern340>[];
    for (final e in available.entries) {
      if (e.key != 'S-V-O') continue;
      candidates.add(
        Pattern340(candidates.length + 1, e.key, 'grammar', {
          'text:v1': {'S': 1, 'V': 1, 'O': 1},
        }, source: '${e.value} osservazioni'),
      );
    }
    final recalled = Hopfield340.recall(
      {
        'text:v1': {'S': 1, 'V': 1, 'O': 1},
      },
      candidates,
      context: 'grammar',
    );
    if (candidates.isEmpty || recalled.best == null) {
      return {
        'status': 'unknown',
        'sentence':
            'Non ho acquisito una costruzione transitiva per questa forma verbale.',
      };
    }
    final s = norm350(subject), o = norm350(object);
    if (s.isEmpty ||
        o.isEmpty ||
        tokens350(s).length > 12 ||
        tokens350(o).length > 12) {
      return {
        'status': 'unknown',
        'sentence': 'Servono soggetto e oggetto espliciti e brevi.',
      };
    }
    // A new combination is a linguistic exercise, NEVER a fact about the book.
    return {
      'status': 'construction',
      'sentence': '${s[0].toUpperCase()}${s.substring(1)} $v $o.',
      'frame': recalled.best,
      'observations': available['S-V-O'],
      'note':
          'Combinazione di ruoli in una costruzione osservata. Non è un fatto appreso e non ne certifica la plausibilità.',
    };
  }

  String complete(String prefix, {int maxTokens = 12}) {
    final ts = tokens350(prefix), out = <String>[];
    var previous = ts.isEmpty ? '^' : ts.last;
    final visited = <String, int>{};
    for (var i = 0; i < maxTokens; i++) {
      final entries = (counts['next:$previous'] ?? {}).entries.toList()
        ..sort((a, b) {
          final n = b.value.compareTo(a.value);
          return n != 0 ? n : a.key.compareTo(b.key);
        });
      final options = entries.where((e) => (visited[e.key] ?? 0) < 2).toList();
      if (options.isEmpty || options.first.key == r'$') break;
      previous = options.first.key;
      out.add(previous);
      visited[previous] = (visited[previous] ?? 0) + 1;
    }
    return out.join(' ');
  }

  Map<String, dynamic> stats() => {
    'vocabulary': counts['lexicon']?.length ?? 0,
    'observations':
        counts['lexicon']?.values.fold<int>(0, (a, b) => a + b) ?? 0,
    'constructions': counts['constructions'] ?? {},
    'features': counts.values.fold<int>(0, (a, b) => a + b.length),
    'bytes': utf8.encode(jsonEncode(counts)).length,
  };
}
