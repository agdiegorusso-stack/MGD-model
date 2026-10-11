import '../lib/neural_reading_v0439.dart';
import '../lib/reading_memory_v0438.dart';
import '../lib/web_knowledge_explorer_v11.dart';

// Frozen 0.42.19 retrieval, solely for paired evaluation, never an app route.
class LegacyReadingContext439 {
  static List<Map<String, dynamic>> context(ResearchMemory11 m, String query) {
    final rows = NeuralReading439.fragments(m), terms = ReadingMemory438.terms(query);
    if (terms.isEmpty || rows.isEmpty) return [];
    final scored = <({int index, double score})>[];
    for (var i = 0; i < rows.length; i++) {
      final body = ReadingMemory438.terms('${rows[i]['text']}');
      final title = ReadingMemory438.terms('${rows[i]['title']} ${(rows[i]['topics438'] as List? ?? []).join(' ')}');
      var score = terms.intersection(body).length.toDouble() +
          1.5 * terms.intersection(title).length;
      if (score > 0) scored.add((index: i, score: score));
    }
    // Proposed notes can suggest where to look. They never become evidence:
    // the answer prompt receives the original passages exclusively.
    final positions = {for (var i = 0; i < rows.length; i++) rows[i]['rid439']: i};
    for (final record in NeuralReading439.notes(m)) {
      for (final note in (record['notes'] as List? ?? []).whereType<Map>()) {
        final hits = terms.intersection(ReadingMemory438.terms('${note['text']}')).length;
        if (hits == 0) continue;
        for (final ref in (note['evidence'] as List? ?? []).whereType<Map>()) {
          final index = positions[ref['id']];
          if (index != null) scored.add((index: index, score: hits * 0.8));
        }
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    // For a small source collection, inspect all context even with no matching
    // surface words. This is bounded fallback, not a semantic retrieval claim.
    final seeds = scored.isEmpty && rows.length <= 16
      ? List.generate(rows.length, (i) => i) : scored.take(5).map((s) => s.index).toList();
    final indices = <int>{};
    for (final i in seeds) {
      indices.add(i);
      for (final j in [i - 2, i - 1, i + 1, i + 2]) {
        if (j >= 0 && j < rows.length && rows[j]['url'] == rows[i]['url']) indices.add(j);
      }
    }
    var budget = 0;
    final selected = <Map<String, dynamic>>[];
    for (final i in (indices.toList()..sort())) {
      final n = '${rows[i]['text']}'.length;
      if (budget + n > 4400 || selected.length >= 16) continue;
      selected.add(rows[i]); budget += n;
    }
    return selected;
  }

}
