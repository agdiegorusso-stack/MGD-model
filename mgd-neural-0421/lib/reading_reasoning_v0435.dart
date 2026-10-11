import 'rule_reasoning_v0429.dart';
import 'semantic_reasoning_v0435.dart';
import 'web_knowledge_explorer_v11.dart';

/// Read-only adapter shared by chat and assessment. Persisted source rows,
/// never test reports, supply all facts and equations after a restart.
class ReadingReasoning435 {
  static List<ReadingSource435> sources(ResearchMemory11 memory) {
    final withdrawn = <String>{}, conflicted = <String, Set<String>>{};
    for (final claim in memory.claims.values) {
      final evidence = memory.evidence.where(
        (e) => claim.evidenceIds.contains(e.id),
      );
      if ({'rifiutata', 'ritirata'}.contains(claim.status)) {
        withdrawn.addAll(evidence.map((e) => e.sourceUrl));
      } else if (claim.conflict) {
        for (final e in evidence) {
          (conflicted[e.sourceUrl] ??= {}).add(
            RuleReasoning429.norm(e.excerpt),
          );
        }
      }
    }
    final state = memory.state317['sourceMemory323'];
    final rows = state is Map ? state['rows'] : null;
    if (rows is! Map)
      return RuleReasoning429.sources(memory)
          .map((s) => ReadingSource435(s.id, s.text, s.title, s.url))
          .toList();
    final out = <ReadingSource435>[];
    for (final row in rows.values.whereType<Map>()) {
      final url = '${row['url']}', text = '${row['text']}';
      if (withdrawn.contains(url)) continue;
      // A quarantined extraction candidate does not withdraw every sentence
      // in its document. Original negatives and missing properties retain
      // their meaning. Substantive conflicts block their evidence spans.
      final blocked = conflicted[url] ?? const <String>{};
      for (final clause in text.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
        if (blocked.any((b) => b.contains(RuleReasoning429.norm(clause))))
          continue;
        out.add(
          ReadingSource435(
            '${row['id']}:${out.length}',
            clause,
            '${row['title']}',
            url,
          ),
        );
      }
    }
    return out;
  }

  static GroundedAnswer435? answer(ResearchMemory11 memory, String prompt) {
    final answer = SemanticReasoning435.answer(sources(memory), prompt);
    if (answer == null) return null;
    final references = {
      for (final s in answer.sources.where((s) => !s.url.startsWith('query:')))
        s.url: '${s.title} · ${s.url}',
    };
    return GroundedAnswer435(
      '${answer.text}${references.isEmpty ? '' : '\nFonti: ${references.values.join('\n')}'}',
      answer.operation,
      answer.sources,
      answer.steps,
      unknown: answer.unknown,
    );
  }
}
