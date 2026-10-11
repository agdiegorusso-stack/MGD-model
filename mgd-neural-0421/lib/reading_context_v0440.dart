import 'dart:math';
import 'reading_memory_v0438.dart';

/// A retrieval index over ORIGINAL text. Scores and proposed-note hints never
/// certify entailment. A finite context is reported as a finite context.
class ReadingContext440 {
  static List<Map<String, dynamic>> select(List<Map<String, dynamic>> rows,
      String query, {Iterable<Map<String, dynamic>> noteRecords = const [],
      int maxCharacters = 4400, int maxPassages = 16}) {
    if (rows.isEmpty || maxCharacters <= 0 || maxPassages <= 0) return [];
    final terms = ReadingMemory438.terms(query);
    if (terms.isEmpty) return [];
    final total = rows.fold<int>(0, (n, r) => n + '${r['text']}'.length);
    // Small collections fit in full, including facts with no lexical overlap.
    if (rows.length <= maxPassages && total <= maxCharacters) return rows;
    final bodies = rows.map((r) => ReadingMemory438.terms('${r['text']}')).toList();
    final titles = rows.map((r) => ReadingMemory438.terms(
        '${r['title']} ${(r['topics438'] as List? ?? []).join(' ')}')).toList();
    final postings = <String, Set<int>>{};
    for (var i = 0; i < rows.length; i++) {
      for (final t in bodies[i].union(titles[i])) {
        (postings[t] ??= <int>{}).add(i);
      }
    }
    double idf(String t) => log(1 + rows.length / ((postings[t]?.length ?? 0) + 1));
    final scores = <int, double>{};
    for (final t in terms) {
      for (final i in postings[t] ?? <int>{}) {
        scores[i] = (scores[i] ?? 0) + idf(t) *
            ((bodies[i].contains(t) ? 1.0 : 0.0) + (titles[i].contains(t) ? .6 : 0.0));
      }
    }
    final positions = {for (var i = 0; i < rows.length; i++) rows[i]['rid439']: i};
    for (final record in noteRecords) {
      for (final note in (record['notes'] as List? ?? []).whereType<Map>()) {
        final hits = terms.intersection(ReadingMemory438.terms('${note['text']}'));
        if (hits.isEmpty) continue;
        final hint = hits.fold<double>(0, (n, t) => n + .5 * idf(t));
        for (final ref in (note['evidence'] as List? ?? []).whereType<Map>()) {
          final index = positions[ref['id']];
          if (index != null) scores[index] = max(scores[index] ?? 0, hint);
        }
      }
    }
    List<int> rank(Map<int, double> values) => values.keys.toList()..sort((a, b) {
      final c = values[b]!.compareTo(values[a]!);
      return c == 0 ? a.compareTo(b) : c;
    });
    final seeds = rank(scores).take(5).toList();
    if (seeds.isEmpty) return [];
    final selected = <int>{};
    var characters = 0;
    bool add(int i) {
      if (selected.contains(i)) return true;
      final n = '${rows[i]['text']}'.length;
      if (selected.length >= maxPassages || characters + n > maxCharacters) return false;
      selected.add(i); characters += n; return true;
    }
    // Reserve the best actual hits FIRST. Sorting by archive position before
    // budgeting used to discard the best hit if earlier neighbours filled it.
    for (final i in seeds) { add(i); }
    // Two bounded association hops use uncommon terms from original passages,
    // never generated notes as evidence. This is lexical association, not a
    // claim of an embedding model or a complete semantic graph.
    var frontier = List<int>.from(selected);
    for (var hop = 0; hop < 2 && frontier.isNotEmpty; hop++) {
      final bridgeScores = <int, double>{};
      for (final seed in frontier) {
        final anchors = bodies[seed].where((t) => t.length >= 4 &&
            !terms.contains(t) && (postings[t]?.length ?? 0) >= 2 &&
            (postings[t]?.length ?? 0) <= max(2, rows.length ~/ 4)).toList()
          ..sort((a, b) => idf(b).compareTo(idf(a)));
        for (final t in anchors.take(8)) {
          for (final i in postings[t] ?? <int>{}) {
            if (selected.contains(i) || !bodies[i].contains(t)) continue;
            bridgeScores[i] = (bridgeScores[i] ?? 0) + idf(t);
          }
        }
      }
      final next = <int>[];
      for (final i in rank(bridgeScores).take(3)) {
        if (add(i)) next.add(i);
      }
      frontier = next;
    }
    // Round-robin proximity follows seed relevance rather than archive order.
    for (final distance in [1, 2]) {
      for (final i in seeds) {
        for (final j in [i - distance, i + distance]) {
          if (j >= 0 && j < rows.length && rows[j]['url'] == rows[i]['url']) add(j);
        }
      }
    }
    for (final i in rank(scores)) { add(i); }
    // Restore reading order only AFTER selecting within the fixed budget.
    return [for (final i in selected.toList()..sort()) rows[i]];
  }
}
