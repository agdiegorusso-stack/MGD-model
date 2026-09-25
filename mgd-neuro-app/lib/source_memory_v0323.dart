part of 'web_knowledge_explorer_v11.dart';

/// Exact source memory. Retrieval is not semantic validation and never adds a
/// claim, changes confidence or turns repeated exposure into another source.
class SourceMemory323 {
  static final _cache = Expando<_SourceIndex323>();
  static Map<String, dynamic> _state(ResearchMemory11 m) {
    final old = m.state317['sourceMemory323'];
    if (old is Map<String, dynamic>) return old;
    final value = Map<String, dynamic>.from(old as Map? ?? {});
    m.state317['sourceMemory323'] = value;
    return value;
  }

  static Map<String, dynamic> _rows(ResearchMemory11 m) {
    final s = _state(m);
    final old = s['rows'];
    if (old is Map<String, dynamic>) return old;
    final value = Map<String, dynamic>.from(old as Map? ?? {});
    s['rows'] = value;
    return value;
  }

  static int retain(ResearchMemory11 m, WebDocument11 d) {
    if (d.text.trim().isEmpty) return 0;
    final rows = _rows(m), state = _state(m);
    var added = 0, skipped = 0;
    // Keep whole sentences: slicing a condition away changes its meaning.
    for (final sentence in d.text.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
      final text = sentence.trim();
      if (text.length < 8) continue;
      if (text.length > 4000) { skipped++; continue; }
      final id = ResearchSemantics317.digest([
        ResearchSemantics317.canonicalUrl(d.url), text
      ]);
      if (rows.containsKey(id)) continue;
      rows[id] = {
        'id': id, 'text': text, 'title': d.title, 'url': d.url,
        'provider': d.provider, 'family': ResearchSemantics317.family(d),
        'observedAt': DateTime.now().toIso8601String(),
      };
      added++;
    }
    if (added > 0) {
      state['revision'] = (state['revision'] as num? ?? 0).toInt() + 1;
      state['sourceCount'] = rows.values.whereType<Map>().map((r) => r['url']).toSet().length;
      _cache[m] = null;
    }
    // Source text remains in its original document even if a sentence is too
    // long for the interactive index. This number is per intake, not a total.
    state['lastIntakeSkippedLongSentences'] = skipped;
    state['lastIntakeNewPassages'] = added;
    return added;
  }

  static void recover(ResearchMemory11 m) {
    if (_state(m)['recovered'] == true) return;
    for (final d in ResearchSemantics317.uniqueDocuments320(m)) {
      retain(m, ResearchSemantics317.docFrom(d));
    }
    for (final p in m.passages) {
      retain(m, WebDocument11(provider: p.provider, family: p.sourceFamily,
        title: p.sourceTitle, url: p.sourceUrl, text: p.text, trust: p.trust));
    }
    for (final e in m.evidence) {
      retain(m, WebDocument11(provider: e.provider, family: e.sourceFamily,
        title: e.sourceTitle, url: e.sourceUrl, text: e.excerpt, trust: e.trust));
    }
    _state(m)['recovered'] = true;
  }

  static List<Map<String, dynamic>> rows(ResearchMemory11 m) {
    recover(m);
    return _rows(m).values.whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static const _stop = {
    'il','lo','la','i','gli','le','un','uno','una','l','di','del','della','dei',
    'degli','delle','dello','dell','a','al','alla','allo','ai','agli','alle',
    'da','dal','dalla','dai','in','nel','nella','nei','nelle','su','sul','sulla',
    'sulle','con','per','tra','fra','e','o','è','sono','era','essere',
    'che','cosa','cos','come','quale','quali','chi','dove','quando','perché',
    'mi','puoi','dire','dimmi','parlami','spiega','spiegami','definizione',
    'the','an','of','to','is','are','was','what','which','who','where','when',
    'how','why','does','do','me','tell','about','define','explain','and','or',
  };
  static List<String> terms(String text) =>
      ResearchSemantics317.tokens(text)
          .where((t) => !_stop.contains(t))
          .map(ResearchSemantics317.word).toList();

  static List<SourceHit323> search(String question, ResearchMemory11 m,
      {int limit = 3}) {
    recover(m);
    final clock = Stopwatch()..start();
    final query = terms(question).toSet();
    final state = _state(m);
    final index = _cache[m] ??= _SourceIndex323(rows(m));
    final matches = index.search(query, limit);
    state['lastQuery'] = question;
    state['lastQueryMicros'] = clock.elapsedMicroseconds;
    state['lastMatches'] = matches.length;
    state['queries'] = (state['queries'] as num? ?? 0).toInt() + 1;
    return matches;
  }

  static Map<String, dynamic> stats(ResearchMemory11 m) {
    recover(m);
    final rs = _rows(m);
    return {
      'passages': rs.length,
      'sources': _state(m)['sourceCount'] ?? 0,
      'lastQueryMicros': _state(m)['lastQueryMicros'],
      'lastMatches': _state(m)['lastMatches'],
      'lastIntakeSkippedLongSentences':
          _state(m)['lastIntakeSkippedLongSentences'] ?? 0,
    };
  }

  static String? answer(String question, ResearchMemory11 m) {
    if (!question.trim().endsWith('?') &&
        !RegExp(r'^(?:cosa|cos[’\x27]|che|parlami|dimmi|come|quali|quale|spiega|what|define|explain)',
            caseSensitive: false).hasMatch(question.trim())) return null;
    final hits = search(question, m);
    if (hits.isEmpty) return null;
    return 'Passaggi pertinenti conservati nella memoria. Il testo della fonte '
        'mantiene condizioni e negazioni; non equivale a una relazione verificata.\n\n' +
        hits.map((h) => '«' + h.text + '»\nFonte: ' + h.title +
          ' (' + h.provider + ').\n' + h.url).join('\n\n');
  }
}

class SourceHit323 {
  final String id, text, title, url, provider;
  final double score;
  SourceHit323(Map<String, dynamic> row, this.score)
      : id = row['id'].toString(), text = row['text'].toString(),
        title = row['title'].toString(), url = row['url'].toString(),
        provider = row['provider'].toString();
}

class _SourceIndex323 {
  final List<Map<String, dynamic>> rows;
  final Map<String, Map<int, int>> postings = {};
  final List<int> lengths = [];
  late final double averageLength;
  _SourceIndex323(this.rows) {
    for (var i = 0; i < rows.length; i++) {
      final ts = SourceMemory323.terms(rows[i]['text'].toString());
      lengths.add(ts.length);
      for (final t in ts) {
        final p = postings.putIfAbsent(t, () => {});
        p[i] = (p[i] ?? 0) + 1;
      }
    }
    averageLength = lengths.isEmpty ? 1 :
        max(1, lengths.fold<int>(0, (a,b) => a+b) / lengths.length).toDouble();
  }

  List<SourceHit323> search(Set<String> query, int limit) {
    if (query.isEmpty || rows.isEmpty || limit <= 0) return [];
    // Every content term must occur in the same sentence. A document title
    // cannot rescue an unrelated sentence. This is lexical recall, not an
    // entailment or paraphrase model; unsupported queries abstain.
    Set<int>? candidates;
    for (final term in query) {
      final p = postings[term];
      if (p == null) return [];
      candidates = candidates == null ? p.keys.toSet() :
          candidates.intersection(p.keys.toSet());
      if (candidates.isEmpty) return [];
    }
    final hits = <SourceHit323>[];
    for (final i in candidates!) {
      var score = 0.0;
      for (final t in query) {
        final p = postings[t]!, tf = p[i]!;
        final idf = log(1 + (rows.length - p.length + .5) / (p.length + .5));
        score += idf * tf * 2.2 /
            (tf + 1.2 * (.25 + .75 * lengths[i] / averageLength));
      }
      hits.add(SourceHit323(rows[i], score));
    }
    hits.sort((a,b) {
      final cmp = b.score.compareTo(a.score);
      return cmp == 0 ? a.id.compareTo(b.id) : cmp;
    });
    return hits.take(limit).toList();
  }
}

/// An explicit nominal definition followed by a comma and descriptive context.
/// The tail remains a qualifier and never becomes an unconditional premise.
class ScopedDefinition323 {
  static List<ExtractedClaim11> extract(String subject, String sentence,
      WebDocument11 doc) {
    final clean = sentence.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.endsWith('?') || clean.length > 1400) return [];
    final match = RegExp(
      r'^(?:il |la |lo |un |una )?(.{2,80}?)\s+(è|sono)\s+(.{3,180}?),\s*(.+)$',
      caseSensitive: false).firstMatch(clean);
    if (match == null ||
        !ResearchSemantics317.sameSubject(match[1]!, subject)) return [];
    final head = match[3]!, tail = match[4]!;
    if (!RegExp(r'^(?:un |uno |una |un[’\x27])', caseSensitive: false)
        .hasMatch(head)) return [];
    if (!RegExp(r'^(?:caratterizzat[oaie]|individuat[oaie]|classificat[oaie]|costituit[oaie]|format[oaie]|compost[oaie])\b',
        caseSensitive: false).hasMatch(tail)) return [];
    if (RegExp(r'\b(?:non|forse|potrebbe|potrebbero|se|qualora|may|might|if)\b',
        caseSensitive: false).hasMatch(match[1]! + ' ' + head)) return [];
    final object = head.replaceFirst(RegExp(
      r'^(?:un |uno |una |un[’\x27])', caseSensitive: false), '').trim();
    return [ExtractedClaim11(subject: subject, relation: 'tipo di',
      object: object, sentence: clean, source: doc, quality: .85,
      meta317: {
        'extractor': 'rules317', 'polarity': 1, 'classRelation321': false,
        'scopedDefinition323': true,
        'qualifiers': {'descriptiveContext323': tail},
      })];
  }
}
