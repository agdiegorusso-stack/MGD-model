// BOOK_EXAM_DELETION_0342
import 'package:flutter/foundation.dart';
import 'cls_bridge_v0340.dart';
import 'book_lab_service_v0342.dart';

import 'experience_page_v0330.dart' show deleteWorker33;
import 'experience_memory_v0330.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'mgd_language_v020.dart';
import 'relational_memory_v0324.dart';

String conceptNode33(Experience33 e) => '${e.label} · ${e.context}';
String episodeNode33(Experience33 e) =>
    'Esperienza ${e.id}: ${e.features.keys.map((k) => k.split(':').first).join(' + ')}';

class KnowledgeDeletion33 {
  /// Caller holds the app's editing lock and saves one complete checkpoint.
  static Future<void> delete({
    required PlasticLanguageBrain04 brain,
    required MgdWorld06 world,
    required ResearchMemory11 research,
    required MgdLanguage20 language,
    required String mode,
    required String node,
  }) async {
    if (mode == 'esperienze') {
      final episodes = world.experience33.episodes;
      for (final e in episodes) {
        if (episodeNode33(e) == node || conceptNode33(e) == node) {
          if (episodeNode33(e) == node) {
            await ClsBridge340.deleteLegacy(e.id);
          } else {
            await ClsBridge340.forgetLabel(e.label);
          }
          world.experience33 = await compute(deleteWorker33, (
            memory: world.experience33.toJson(),
            id: episodeNode33(e) == node ? e.id : null,
            label: conceptNode33(e) == node ? e.label : null,
            context: conceptNode33(e) == node ? e.context : null,
          ));
          world.step++;
          return;
        }
      }
      return;
    }
    if (mode == 'concetti' &&
        (node.startsWith('◆ ') || node.startsWith('◇ '))) {
      research.emergentConcepts.removeWhere(
        (_, c) => c.label == node.substring(2),
      );
      return;
    }
    if (mode == 'episodi' && node.startsWith('Ep.')) {
      final id = int.tryParse(node.substring(3));
      research.narrativeEpisodes.removeWhere((e) => e.id == id);
      research.narrativeLinks.removeWhere((e) => e.episodeId == 'e24:$id');
      return;
    }
    await ClsBridge340.forgetLabel(node);
    bool matches(String s) => PlasticLanguageBrain04.containsLabel33(s, node);
    bool deep(dynamic v) => v is String
        ? matches(v)
        : v is Map
            ? v.values.any(deep)
            : v is Iterable
                ? v.any(deep)
                : false;
    // Rebuild the expensive trainable component off the UI thread BEFORE mutation.
    final next = await compute(deleteWorker33, (
      memory: world.experience33.toJson(),
      id: null,
      label: node,
      context: null,
    ));
    final ids = brain.forgetNode33(node);
    language.forgetNode33(node);
    final prototypeIds = world.prototypes
        .where(
          (p) =>
              ids.contains(p.semanticEntityId) ||
              (p.label != null && canonical33(p.label!) == canonical33(node)),
        )
        .map((p) => p.id)
        .toSet();
    for (final p in world.prototypes.where(
      (p) => prototypeIds.contains(p.id),
    )) {
      p.centroid.clear();
      p.label = null;
      p.semanticEntityId = null;
      p.observations = 0;
      p.stability = 0;
    }
    final worldNodes = {
      ...ids.map((id) => 'e:$id'),
      ...prototypeIds.map((id) => 'p:$id'),
    };
    world.edges.removeWhere(
      (_, e) => worldNodes.contains(e.a) || worldNodes.contains(e.b),
    );
    world.observations.removeWhere((e) => prototypeIds.contains(e.prototypeId));
    if (prototypeIds.contains(world.lastObservation?.prototypeId)) {
      world.lastObservation = null;
      world.lastFeatures33 = null;
    }
    world.thoughts.removeWhere((e) => deep(e.toJson()));
    if (ids.contains(world.currentUserEntityId091))
      world.currentUserEntityId091 = null;
    if (ids.contains(world.lastLanguageEntity09))
      world.lastLanguageEntity09 = null;
    world.pendingCuriosityEntities09.removeWhere(ids.contains);
    if (matches(world.pendingCuriosityQuestion09 ?? '')) {
      world.pendingCuriosityQuestion09 = null;
      world.pendingCuriosityType09 = null;
      world.pendingCuriosityPrototype09 = null;
    }
    research.claims.removeWhere((_, c) => deep(c.toJson()));
    research.evidence.removeWhere((e) => deep(e.toJson()));
    research.passages.removeWhere((p) => matches(p.text));
    research.narrativeEpisodes.removeWhere((e) => matches(e.text));
    research.narrativeLinks.removeWhere(
      (e) => matches(e.from) || matches(e.to),
    );
    research.emergentConcepts.removeWhere((_, c) => deep(c.toJson()));
    research.termMemory.removeWhere((k, _) => matches(k));
    for (final t in research.termMemory.values) {
      t.co.removeWhere((k, _) => matches(k));
    }
    // Remove original documents that would otherwise restore the removed facts.
    research.sessions.removeWhere(
      (s) => deep(s.audit315['documents']) || matches(s.topic),
    );
    final queue = research.state317['queue'];
    if (queue is List) queue.removeWhere(deep);
    RelationalMemory324.forget33(research, matches);
    SourceMemory323.forget33(research, matches);
    BookLab342.closeChat();
    final lab = research.state317['bookLab342'];
    if (lab is Map) {
      final tests = lab['cases'];
      if (tests is Map) {
        for (final value in tests.values) {
          if (value is List) value.removeWhere(deep);
        }
      }
      final reports = lab['reports'];
      if (reports is List) reports.removeWhere(deep);
    }
    research.lastGoal = null;
    research.lastStatus = 'Memoria modificata dall’utente.';
    world.experience33 = next;
    world.step++;
  }
}
