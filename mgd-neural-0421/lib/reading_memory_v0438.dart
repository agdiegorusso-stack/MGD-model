import 'dart:math';
import 'web_knowledge_explorer_v11.dart';

class ReadingRecall438 {
  final String text;
  final List<Map<String, dynamic>> passages;
  final int available;
  final bool missing;
  const ReadingRecall438(this.text, this.passages, this.available,
      {this.missing = false});
  Map<String, dynamic> get proof => {
    'kind': 'source_passages', 'passages': passages,
    'available': available, 'semanticValidation': false,
  };
}

/// Source-grounded, extractive reading memory. It learns its vocabulary,
/// document contexts and postings from actual intake, including unseen names.
/// A query never trains the model or certifies a source assertion. Morphology
/// and lexical families rank excerpts; they cannot become logical premises.
class ReadingMemory438 {
  static final _cache = Expando<_ReadingIndex438>();
  static final _stamps = Expando<String>();
  static const _extraStop = {
    'sai', 'sapere', 'hai', 'letto', 'imparato', 'riguardo', 'tutto', 'qual',
    'qualcosa', 'sul', 'sullo', 'dell', 'da', 'dal', 'dalla', 'dagli', 'allo',
    'sull', 'l', 'cosa', 'cos', 'che', 'e', 'quanto', 'quanti', 'quante',
    'qual è', 'ci', 'si', 'del', 'su', 'puoi', 'spiegare', 'raccontami',
  };
  static const _families = [
    ['rimuove', 'rimuovono', 'rimuovere', 'elimina', 'eliminano', 'eliminare'],
    ['utilizza', 'utilizzano', 'utilizzare', 'usa', 'usano', 'usare'],
    ['contiene', 'contengono', 'contenere', 'comprende', 'comprendono'],
    ['funzione', 'funzioni', 'scopo', 'serve', 'servono', 'utilità'],
    ['causa', 'cause', 'provoca', 'provocano', 'causare'],
    ['richiede', 'richiedono', 'richiedere', 'necessita', 'necessario'],
    ['misura', 'misurano', 'misurare', 'misurazione'],
  ];
  static String stem(String word) {
    var w = word.toLowerCase().replaceAll('à', 'a').replaceAll('è', 'e')
        .replaceAll('é', 'e').replaceAll('ì', 'i').replaceAll('ò', 'o')
        .replaceAll('ù', 'u');
    for (final suffix in ['mente', 'ando', 'endo', 'ano', 'ono', 'are', 'ere', 'ire']) {
      if (w.length > suffix.length + 3 && w.endsWith(suffix)) {
        return w.substring(0, w.length - suffix.length);
      }
    }
    if (w.length > 5 && RegExp(r'[aeio]$').hasMatch(w)) {
      w = w.substring(0, w.length - 1);
    }
    return w;
  }
  static String _canonical(String word) {
    for (var i = 0; i < _families.length; i++) {
      if (_families[i].contains(word)) return '@lex$i';
    }
    return stem(word);
  }
  static Set<String> terms(String text) => SourceMemory323.terms(text)
      .where((w) => !_extraStop.contains(w)).map(_canonical).toSet();

  static _ReadingIndex438 _index(ResearchMemory11 memory) {
    final state = memory.state317['sourceMemory323'];
    final stamp = '${state is Map ? state['revision'] : 0}:'
        '${state is Map ? state['completeRecovery438'] : false}:'
        '${memory.sessions.length}:${memory.passages.length}:${memory.evidence.length}';
    if (_cache[memory] == null || _stamps[memory] != stamp) {
      _cache[memory] = _ReadingIndex438(SourceMemory323.readRows438(memory));
      _stamps[memory] = stamp;
    }
    return _cache[memory]!;
  }

  static Set<String> _withdrawn(ResearchMemory11 memory) {
    final withdrawn = <String>{};
    for (final c in memory.claims.values.where((c) =>
        {'rifiutata', 'ritirata'}.contains(c.status))) {
      withdrawn.addAll(memory.evidence.where((e) => c.evidenceIds.contains(e.id))
          .map((e) => e.sourceUrl));
    }
    return withdrawn;
  }
  static List<Map<String, dynamic>> rows(ResearchMemory11 memory) {
    final withdrawn = _withdrawn(memory);
    return _index(memory).rows.where((r) => !withdrawn.contains(r['url']))
        .map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Map<String, int> stats(ResearchMemory11 memory, {String? topic}) {
    final q = topic == null ? <String>{} : terms(topic);
    final index = _index(memory), withdrawn = _withdrawn(memory);
    final rs = <Map<String, dynamic>>[];
    for (var i = 0; i < index.rows.length; i++) {
      final row = index.rows[i];
      if (!withdrawn.contains(row['url']) && q.every((t) =>
          index.body[i].contains(t) || index.contexts[i].contains(t))) {
        rs.add(row);
      }
    }
    return {'passages': rs.length,
      'sources': rs.map((r) => r['url']).toSet().length,
      'characters': rs.fold(0, (n, r) => n + '${r['text']}'.length)};
  }

  static ReadingRecall438? answer(ResearchMemory11 memory, String prompt,
      {int limit = 8, bool explicitSearch = false}) {
    final clean = ResearchSemantics317.norm(prompt);
    final overview = RegExp(r'^(?:che cosa sai|cosa sai|che cosa hai imparato|'
      r'cosa hai imparato|parlami|descrivi|spiegami|raccontami|definisci|'
      r'che cos e|cos e|che cosa e)\b').hasMatch(clean);
    if (!explicitSearch && !overview && !prompt.trim().endsWith('?') &&
        !RegExp(r'^(?:chi|come|dove|quando|perche|quale|quali|qual|quanto)\b').hasMatch(clean)) {
      return null;
    }
    final query = terms(prompt);
    if (query.isEmpty || limit <= 0) return null;
    final index = _index(memory);
    final hits = index.find(query, _withdrawn(memory), overview: overview);
    if (hits.isEmpty) {
      final contextKnown = index.contexts.any((s) => s.any(query.contains));
      if (!contextKnown) return null;
      return const ReadingRecall438(
        'Non ho trovato nelle letture conservate un passaggio che risponda a questa domanda.',
        [], 0, missing: true);
    }
    final picked = <Map<String, dynamic>>[];
    final seenText = <String>{};
    // Diversity chooses different statements, not repeated copies of one fact.
    // No source is designated true by rank. Whole sentences preserve modality,
    // negation, numerical ranges and clinical or temporal conditions.
    final remaining = List<(int, double)>.from(hits);
    while (remaining.isNotEmpty && picked.length < limit) {
      var best = 0, bestScore = -double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final ts = index.body[remaining[i].$1];
        var similarity = 0.0;
        for (final old in picked) {
          final other = terms('${old['text']}');
          final union = ts.union(other).length;
          if (union > 0) similarity = max(similarity, ts.intersection(other).length / union);
        }
        final score = remaining[i].$2 * (1 - .65 * similarity);
        if (score > bestScore) { best = i; bestScore = score; }
      }
      final row = index.rows[remaining.removeAt(best).$1];
      if (seenText.add(ResearchSemantics317.norm('${row['text']}'))) {
        picked.add(Map<String, dynamic>.from(row));
      }
    }
    if (picked.isEmpty) return null;
    final lines = <String>[];
    for (var i = 0; i < picked.length; i++) {
      final row = picked[i];
      lines.add('[${i + 1}] ${row['text']}\nFonte: ${row['title']} · ${row['url']}');
    }
    return ReadingRecall438('Dalle letture conservate:\n\n${lines.join('\n\n')}'
      '\n\n${picked.length} passaggi mostrati su ${hits.length} pertinenti. '
      'Apri Letture per consultare gli altri. Le frasi riportano ciò che dicono le fonti.',
      picked, hits.length);
  }
}

class _ReadingIndex438 {
  final List<Map<String, dynamic>> rows;
  final List<Set<String>> body = [], contexts = [];
  final Map<String, Set<int>> postings = {};
  _ReadingIndex438(this.rows) {
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final b = ReadingMemory438.terms('${r['text']}');
      final c = ReadingMemory438.terms('${r['title']} '
          '${(r['topics438'] as List? ?? []).join(' ')}');
      body.add(b); contexts.add(c);
      for (final t in b.union(c)) { (postings[t] ??= {}).add(i); }
    }
  }
  List<(int, double)> find(Set<String> query, Set<String> withdrawnUrls,
      {required bool overview}) {
    Set<int>? candidates;
    // Query-only operators are removed before here. Remaining specific terms
    // must occur in the passage or its real document context. Unknown named
    // entities cannot be dropped to make an unrelated answer look successful.
    for (final t in query) {
      final p = postings[t];
      if (p == null) return [];
      candidates = candidates == null ? Set<int>.from(p) : candidates.intersection(p);
      if (candidates.isEmpty) return [];
    }
    final out = <(int, double)>[];
    for (final i in candidates ?? <int>{}) {
      if (withdrawnUrls.contains(rows[i]['url'])) continue;
      if (!overview && !body[i].any(query.contains)) continue;
      var score = 0.0;
      for (final t in query) {
        final idf = log(1 + rows.length / (postings[t]!.length + 1));
        score += idf * (body[i].contains(t) ? 1.0 : .65);
      }
      out.add((i, score + .01));
    }
    out.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return out;
  }
}
