import 'rule_reasoning_v0429.dart';
import 'semantic_reasoning_v0435.dart';
import 'web_knowledge_explorer_v11.dart';

/// Read-only adapter shared by chat and assessment. Persisted source rows,
/// never test reports, supply all facts and equations after a restart.
class ReadingReasoning435 {
  static GroundedAnswer435? answer(ResearchMemory11 memory, String prompt) {
    final answer = SemanticReasoning435.answer(
      RuleReasoning429.sources(memory)
          .map((s) => ReadingSource435(s.id, s.text, s.title, s.url))
          .toList(),
      prompt,
    );
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
