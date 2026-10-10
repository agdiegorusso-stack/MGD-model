import 'web_knowledge_explorer_v11.dart';

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
    final candidates = memory.claims.values.where((c) => usable(c) &&
        key(c.subject) == asked).toList()
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
