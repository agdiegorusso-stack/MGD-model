import 'dart:convert';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';

typedef ExternalFact331 = ({
  int subject,
  int object,
  String label,
  Set<String> evidence
});

/// Reads existing provenance. Rehearsal never changes sources or confidence.
class ConsolidationEvidence331 {
  static List<ExternalFact331> collect(PlasticLanguageBrain04 brain) {
    final facts = <ExternalFact331>[];
    final episodes = {for (final ep in brain.episodes) ep.id: ep};
    for (final slot in brain.slots.values) {
      if (slot.subjectId < 0 ||
          slot.subjectId >= brain.entities.length ||
          brain.entities[slot.subjectId].kind == 'deleted') continue;
      for (final c in slot.candidates.values) {
        final retainedEpisodes = c.sourceEpisodes.where((id) {
          final ep = episodes[id];
          if (ep == null) return false;
          // A rejected answer is no longer a confirmation. An independent
          // declaration in the user text is not automatically retracted.
          return !ep.responseRevoked331 ||
              (!ep.wasQuestion &&
                  PlasticLanguageBrain04.canonicalObject(ep.agentText ?? '') !=
                      c.objectKey);
        }).toSet();
        final experienced =
            c.epistemicStatus == 'experienced' && retainedEpisodes.isNotEmpty;
        final sourced =
            c.epistemicStatus == 'consolidated' && c.sourceFamilies.isNotEmpty;
        if (!(experienced || sourced) ||
            c.confidence < .50 ||
            c.contradictions > 0) continue;
        final object = brain.entityIdForLabel06(c.display);
        if (object == null ||
            object == slot.subjectId ||
            brain.entities[object].kind == 'deleted') continue;
        String key(String kind, Object source) => jsonEncode(
            [slot.subjectId, slot.relationId, c.objectKey, kind, source]);
        facts.add((
          subject: slot.subjectId,
          object: object,
          label: brain.entities[slot.subjectId].label,
          evidence: {
            if (experienced)
              for (final id in retainedEpisodes) key('episode', id),
            if (sourced)
              for (final family in c.sourceFamilies) key('family', family),
          }
        ));
      }
    }
    return facts;
  }

  static Map<String, Set<String>> byEdge(List<ExternalFact331> facts) {
    final result = <String, Set<String>>{};
    for (final f in facts) {
      result
          .putIfAbsent(MgdWorld06.semanticEdgeKey331(f.subject, f.object),
              () => <String>{})
          .addAll(f.evidence);
    }
    return result;
  }

  static void sync(PlasticLanguageBrain04 brain, MgdWorld06 world) =>
      world.syncConsolidationEvidence331(byEdge(collect(brain)));
}
