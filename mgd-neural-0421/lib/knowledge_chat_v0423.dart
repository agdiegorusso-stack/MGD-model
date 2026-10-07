import 'cognitive_core_v0400.dart';
import 'native_mgd_engine_v09.dart';
import 'plastic_language_brain_v04.dart';
import 'relational_memory_v0324.dart';
import 'web_knowledge_explorer_v11.dart';

typedef KnowledgeLink423 = ({
  String from,
  String relation,
  String to,
  double confidence,
  String source,
  bool conflict,
});

/// The world map and chat read the same snapshot, including incoming edges.
/// Geometric strength ranks retrieval; it never certifies a proposition.
class KnowledgeChat423 {
  static String key(String text) => tokens400(text)
      .skipWhile((t) =>
          {'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'una', 'uno'}.contains(t))
      .join(' ');

  static List<KnowledgeLink423> links(
      PlasticLanguageBrain04 brain, ResearchMemory11? research,
      {double minConfidence = .35}) {
    final conflicts = <String>{};
    for (final f in brain.strongestFacts(limit: brain.slots.length)) {
      if (f.conflict) conflicts.add('${key(f.subject)}|${key(f.relation)}');
    }
    final out = brain
        .semanticGraph(limit: 10000000)
        .where((e) => e.confidence >= minConfidence)
        .map((e) => (
              from: e.from,
              relation: e.relation,
              to: e.to,
              confidence: e.confidence,
              source: 'memoria relazionale locale',
              conflict: conflicts.contains('${key(e.from)}|${key(e.relation)}')
            ))
        .toList();
    if (research == null) return _markPolarityConflicts424(out);
    final rows = RelationalMemory324.rows(research, includeHistory: false);
    for (final r in rows) {
      final from = '${r['agent']}', to = '${r['patient']}';
      final relation = '${r['relation']}';
      // A current taught assertion supersedes a duplicate legacy rendering,
      // including a corrected negative assertion about the same triple.
      out.removeWhere((e) =>
          key(e.from) == key(from) &&
          key(e.to) == key(to) &&
          ResearchSemantics317.relation(e.relation) ==
              ResearchSemantics317.relation(relation));
      final conflict = rows.any((other) =>
          other['agent'] == r['agent'] &&
          other['relation'] == r['relation'] &&
          other['patient'] == r['patient'] &&
          (other['negative'] == true) != (r['negative'] == true));
      out.add((
        from: from,
        to: to,
        relation: 'insegnata: ${r['negative'] == true ? 'non ' : ''}$relation',
        confidence: MgdMath09.strength(
            weight: (r['weight'] as num).toDouble(),
            memory: (r['memory'] as num).toDouble(),
            material: (r['material'] as num).toDouble()),
        source: '${r['source']}',
        conflict: conflict
      ));
    }
    for (final c in research.claims.values.where((c) =>
        {'documentata', 'accettata'}.contains(c.status) && !c.conflict)) {
      out.removeWhere((e) =>
          ResearchSemantics317.sameSubject(e.from, c.subject) &&
          ResearchSemantics317.sameObject(e.to, c.object) &&
          ResearchSemantics317.relation(e.relation) ==
              ResearchSemantics317.relation(c.relation));
      out.add((
        from: c.subject,
        to: c.object,
        relation:
            '${c.status == 'documentata' ? 'con fonte' : 'corroborata'}: ${c.relation}',
        confidence: c.confidence,
        source: 'memoria documentata (${c.status})',
        conflict: false
      ));
    }
    return _markPolarityConflicts424(out);
  }

  static List<KnowledgeLink423> _markPolarityConflicts424(
      List<KnowledgeLink423> out) {
    // Preserve actual positive/negative contradictions on the same triple.
    // Several positive objects of a set-valued relation are compatible.
    final polarity = <String, Set<bool>>{};
    ({String signature, bool negative}) assertion(KnowledgeLink423 e) {
      var relation = e.relation.replaceFirst(
          RegExp(r'^(insegnata|con fonte|corroborata):\s*'), '');
      final negative = relation.startsWith('non ');
      if (negative) relation = relation.substring(4);
      return (signature: '${key(e.from)}|${key(relation)}|${key(e.to)}',
          negative: negative);
    }
    for (final e in out) {
      final a = assertion(e);
      polarity.putIfAbsent(a.signature, () => <bool>{}).add(a.negative);
    }
    return out.map((e) => (
      from: e.from, relation: e.relation, to: e.to,
      confidence: e.confidence, source: e.source,
      conflict: e.conflict || polarity[assertion(e).signature]!.length > 1,
    )).toList();
  }

  static final _description = RegExp(
      r"^(?:(?:che\s+cosa|cosa|cos[' ]?è|cos[' ]?e|che\s+cos[' ]?è|chi)\s*(?:è|e|sono|sai\s+(?:di|su))?|parlami\s+(?:di|del|della)|dimmi\s+(?:di|del|della|qualcosa\s+su)|spiegami|spiega|descrivi|definisci|approfondisci)\s+",
      caseSensitive: false);
  static bool question(String text) =>
      text.trim().endsWith('?') ||
      RegExp(r"^\s*(chi|cosa|che\s+cosa|cos['’]|come|dove|quando|perch[eé]|qual\w*|quanto|parlami|dimmi|spiega\w*|descrivi|definisci|approfondisci)\b",
              caseSensitive: false)
          .hasMatch(text);

  /// Exact known names take precedence over the bootstrap frame inducer,
  /// which can otherwise mistake the second word of a noun phrase for a verb.
  static bool queryOnly(
      String text, PlasticLanguageBrain04 brain, ResearchMemory11 research) {
    if (question(text)) return true;
    final k = key(text);
    if (brain.entities.any((e) =>
        e.kind != 'deleted' &&
        (key(e.label) == k || e.aliases.any((a) => key(a) == k)))) return true;
    if (links(brain, research).any((e) => key(e.from) == k || key(e.to) == k))
      return true;
    return !FrameInducer400.induce(text).valid;
  }

  static String? answer(
      PlasticLanguageBrain04 brain, ResearchMemory11 research, String prompt) {
    if (RegExp(r'^\s*(correggi|continua|alias|ipotizza)\s*:',
            caseSensitive: false)
        .hasMatch(prompt)) return null;
    final edges = links(brain, research);
    final nodes = <String>{
      for (final e in edges) e.from,
      for (final e in edges) e.to,
      ...brain.entities.where((e) => e.kind != 'deleted').map((e) => e.label)
    };
    final clean = norm400(prompt).replaceAll(RegExp(r'[?!.]+$'), '');
    final described = clean.replaceFirst(_description, '');
    final topic = key(described);
    final exact = nodes.where((n) => key(n) == topic).toSet();
    for (final e in brain.entities.where((e) => e.kind != 'deleted')) {
      if (e.aliases.any((a) => key(a) == topic)) exact.add(e.label);
    }
    final broad = exact.isNotEmpty;
    if (!broad && !question(prompt)) return null;
    final selected = broad
        ? exact
        : nodes
            .where((n) =>
                key(n).isNotEmpty && ' ${key(clean)} '.contains(' ${key(n)} '))
            .toSet();
    // Prefer complete multiword names over their shorter substrings.
    final selectedNames = selected.toList();
    selected.removeWhere((n) => selectedNames.any((other) =>
        other != n &&
        key(other) != key(n) &&
        ' ${key(other)} '.contains(' ${key(n)} ')));
    if (selected.isEmpty) return null;
    final anchorKeys = selected.map(key).toSet();
    var relevant = edges
        .where((e) =>
            anchorKeys.contains(key(e.from)) || anchorKeys.contains(key(e.to)))
        .toList();
    if (!broad) {
      // A specific question must match its relation; unrelated neighbours
      // must not be presented as an answer to a why/where/ownership question.
      final remainder = tokens400(clean)
          .where((t) =>
              isContent400(t) && !selected.any((n) => tokens400(n).contains(t)))
          .map(stem400)
          .toSet();
      relevant = relevant
          .where(
              (e) => tokens400(e.relation).map(stem400).any(remainder.contains))
          .toList();
      if (relevant.isEmpty) return null;
    }
    if (relevant.isEmpty)
      return 'Riconosco “${selected.join(' / ')}”, ma nella mappa non ho ancora relazioni che lo descrivano. Puoi insegnarmele in Impara.';
    relevant.sort((a, b) => b.confidence.compareTo(a.confidence));
    final seen = <String>{};
    final lines = <String>[];
    for (final e in relevant) {
      final signature = '${key(e.from)}|${key(e.relation)}|${key(e.to)}';
      if (!seen.add(signature)) continue;
      final relation = e.relation
          .replaceFirst(RegExp(r'^(insegnata|con fonte|corroborata):\s*'), '');
      final warning =
          e.conflict ? ' [IN CONFLITTO: non posso confermarlo]' : '';
      lines.add(
          '• ${e.from} — $relation → ${e.to}.$warning\n  Fonte: ${e.source}.');
      if (lines.length == 12) break;
    }
    return 'Nella memoria di “${selected.join(' / ')}”:\n${lines.join('\n')}';
  }
}
