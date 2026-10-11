import 'web_knowledge_explorer_v11.dart';
import 'study_goal_v0426.dart';

class ReadingAnswer430 {
  final String text;
  final List<Map<String, String>> claims;
  const ReadingAnswer430(this.text, this.claims);
  Map<String, dynamic> get proof => {'kind': 'retrieval', 'claims': claims};
}

/// An open request for a topic retrieves its documented assertions, rather
/// than requiring the user to specify an internal graph edge label. This is
/// source recall, not a mechanism explanation or an inference.
class ReadingQuery430 {
  /// Context retained by the active study, including old saved sessions. A
  /// lexical match alone cannot make two Wikidata entities the same subject.
  static List<Map> resolvedSources432(ResearchMemory11 memory) {
    final g = StudyGoal426.state(memory);
    if (g == null) return [];
    final created = DateTime.tryParse('${g['createdAt']}');
    final queries = StudyGoal426.items(g).map((i) => StudyGoal426.query(g, i)).toSet();
    return memory.sessions.where((s) => queries.contains(s.query) && created != null &&
        DateTime.tryParse(s.startedAtIso)?.isBefore(created) == false)
        .expand((s) => (s.audit315['documents'] as List? ?? []).whereType<Map>())
        .where((d) => d['provider'] == 'Wikipedia IT' && d['meta318'] is Map &&
            d['meta318']['resolvedTopic'] == true &&
            RegExp(r'^Q[1-9][0-9]*$').hasMatch('${d['meta318']['wikidataId'] ?? ''}')).toList();
  }

  static bool contextualSense432(ResearchClaim11 c, List<Map> documents) {
    final relevant = documents.where((d) => key('${d['title']}') == key(c.subject) ||
        key('${d['meta318']['requestedTopic']}') == key(c.subject)).toList();
    if (relevant.isEmpty) return true;
    if (c.subjectSenseKey == null) return relevant.any((d) => key('${d['title']}') == key(c.subject));
    if (!c.subjectSenseKey!.startsWith('wikidata:')) return true;
    return relevant.any((d) => c.subjectSenseKey == 'wikidata:${d['meta318']['wikidataId']}');
  }

  static String key(String text) => ResearchSemantics317.norm(text)
      .replaceAll(RegExp(r'[?!.]+$'), '')
      .replaceFirst(RegExp(r'^(il|lo|la|un|uno|una)\s+'), '').trim();

  static String? topic(String prompt) {
    final clean = key(prompt);
    final match = RegExp(r'^(?:che cosa sai (?:di|su)|cosa sai (?:di|su)|'
        r'parlami (?:di|del|della)|dimmi qualcosa (?:di|su)|'
        r'spiegami|descrivi|definisci|che cos [eè]|cos [eè]|che cosa [eè])\s+(.+)$')
        .firstMatch(clean);
    return match == null ? null : key(match[1]!);
  }

  static bool usable(ResearchClaim11 c) => !c.conflict &&
      {'documentata', 'accettata'}.contains(c.status) &&
      c.evidenceIds.isNotEmpty && c.meta317['usable'] == true &&
      c.meta317['negative'] != true &&
      (c.meta317['qualifiers'] is! Map || (c.meta317['qualifiers'] as Map).isEmpty);

  static String sentence(String subject, String relation, String object) {
    final r = ResearchSemantics317.norm(relation);
    final verb = switch (r) {
      'sottoclasse di' || 'subclass of' => 'è un tipo di',
      'istanza di' || 'instance of' => 'è un esempio di',
      'ha parte' || 'contiene' => 'contiene',
      'parte di' => 'fa parte di',
      'ha funzione' => 'ha la funzione di',
      'tipo di' || 'è' || 'e' => 'è',
      _ => null,
    };
    return verb == null ? 'Per $subject la fonte riporta «$relation: $object».'
        : '$subject $verb $object.';
  }

  static ReadingAnswer430? answer(ResearchMemory11 memory, String prompt) {
    final asked = topic(prompt);
    if (asked == null) return null;
    final sources = resolvedSources432(memory);
    final resolved = sources.where((d) => key('${d['title']}') == asked ||
        key('${d['meta318']['requestedTopic']}') == asked).toList();
    final candidates = memory.claims.values.where((c) => usable(c) &&
        (resolved.isEmpty ? key(c.subject) == asked : resolved.any((d) =>
          c.subjectSenseKey == 'wikidata:${d['meta318']['wikidataId']}' ||
          (c.subjectSenseKey == null && key(c.subject) == key('${d['title']}'))))).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    if (candidates.isEmpty) return null;
    final rows = <Map<String, String>>[], lines = <String>[], seen = <String>{};
    for (final c in candidates) {
      if (!seen.add('${key(c.subject)}|${key(c.relation)}|${key(c.object)}')) continue;
      final evidence = memory.evidence.where((e) => c.evidenceIds.contains(e.id));
      if (evidence.isEmpty) continue;
      final e = evidence.first;
      if (e.sourceUrl.isEmpty) continue;
      rows.add({'subject': c.subject, 'relation': c.relation, 'object': c.object,
        'claimKey': c.key, 'title': e.sourceTitle, 'url': e.sourceUrl,
        'excerpt': e.excerpt});
      lines.add('${sentence(c.subject, c.relation, c.object)}\n'
          'Fonte: ${e.sourceTitle} · ${e.sourceUrl}');
      if (rows.length == 12) break;
    }
    if (rows.isEmpty) return null;
    return ReadingAnswer430('Fatti documentati su ${candidates.first.subject}:\n'
        '${lines.join('\n\n')}', rows);
  }
}
