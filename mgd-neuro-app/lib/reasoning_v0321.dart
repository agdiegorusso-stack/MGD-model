import 'web_knowledge_explorer_v11.dart';

class Deduction321 {
  final String subject, relation, object;
  final List<ResearchClaim11> premises;
  const Deduction321(this.subject, this.relation, this.object, this.premises);
}

/// Bounded, explicit class transitivity over sourced propositions.
/// This is a logical rule, not an additional web source or a learned truth.
/// Proofs are recomputed so a quarantined/withdrawn premise invalidates them.
class Reasoning321 {
  static bool _eligible(ResearchClaim11 c) =>
      c.meta317['usable'] == true &&
      !c.conflict &&
      {'documentata', 'accettata'}.contains(c.status) &&
      (c.meta317['qualifiers'] is! Map ||
          (c.meta317['qualifiers'] as Map).isEmpty) &&
      (c.meta317['classRelation321'] == true ||
          {'P31', 'P279'}.contains(c.meta317['property']));

  static bool _joins(
      ResearchClaim11 a, ResearchClaim11 b, List<ResearchClaim11> all) {
    final oid = a.meta317['objectSenseKey'];
    if (oid != null || b.subjectSenseKey != null) {
      return oid != null && oid == b.subjectSenseKey;
    }
    if (all.any((c) =>
        c.subjectSenseKey != null &&
        ResearchSemantics317.sameSubject(c.subject, a.object))) return false;
    return ResearchSemantics317.sameSubject(a.object, b.subject);
  }

  static List<Deduction321> infer(ResearchMemory11 memory, String subject,
      {int maxDepth = 4, int maxExpansions = 256}) {
    final all = memory.claims.values.toList();
    final eligible = all.where(_eligible).toList();
    final starts = eligible
        .where((c) => ResearchSemantics317.sameSubject(c.subject, subject))
        .toList();
    if (starts.map((c) => c.subjectSenseKey ?? '').toSet().length > 1)
      return [];
    final queue = starts.map((c) => <ResearchClaim11>[c]).toList();
    final out = <Deduction321>[];
    final conclusions = <String>{};
    var expanded = 0;
    for (var i = 0; i < queue.length && expanded < maxExpansions; i++) {
      final path = queue[i];
      if (path.length >= maxDepth) continue;
      for (final next in eligible) {
        if (expanded >= maxExpansions) break;
        if (!{'sottoclasse di', 'tipo di'}.contains(next.relation) ||
            path.any((c) => c.key == next.key) ||
            !_joins(path.last, next, all)) continue;
        expanded++;
        if (ResearchSemantics317.sameSubject(path.first.subject, next.object))
          continue;
        final proof = [...path, next];
        final relation = path.first.relation == 'istanza di'
            ? 'istanza di'
            : 'sottoclasse di';
        final key =
            '$relation|${next.meta317['objectSenseKey'] ?? ResearchSemantics317.concept(next.object)}';
        if (!conclusions.add(key)) continue;
        queue.add(proof);
        final direct = starts
            .any((c) => ResearchSemantics317.sameObject(c.object, next.object));
        if (!direct)
          out.add(
              Deduction321(path.first.subject, relation, next.object, proof));
      }
    }
    return out;
  }

  static String? answer(String question, ResearchMemory11 memory) {
    if (!RegExp(r'\b(?:deduci|dedurre|deduzioni|concludere|conclusioni)\b',
            caseSensitive: false)
        .hasMatch(question)) return null;
    final q = ' ${ResearchSemantics317.concept(question)} ';
    final subjects = memory.claims.values
        .where(
            (c) => q.contains(' ${ResearchSemantics317.concept(c.subject)} '))
        .map((c) => c.subject)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (subjects.isEmpty)
      return 'Non ho premesse utilizzabili per questa deduzione.';
    final deductions = infer(memory, subjects.first);
    if (deductions.isEmpty)
      return 'Non ho una catena di premesse compatibili da cui ricavare una nuova deduzione.';
    return deductions.take(4).map((d) {
      final proof = d.premises
          .map((p) => '${p.subject} — ${p.relation} → ${p.object}')
          .join('; ');
      final urls = d.premises
          .expand((p) => memory.evidence.where((e) =>
              p.evidenceIds.contains(e.id) &&
              e.meta317['verdict'] == 'support'))
          .map((e) => e.sourceUrl)
          .toSet()
          .join('\n');
      return 'Deduzione condizionata alle premesse: ${d.subject} — ${d.relation} → ${d.object}.\n'
          'Regola: transitività delle classi. Premesse: $proof.\n$urls';
    }).join('\n\n');
  }
}
