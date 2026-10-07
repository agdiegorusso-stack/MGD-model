import 'dart:async';
import 'dart:isolate';
import 'cls_bridge_v0340.dart';
import 'relational_memory_v0324.dart';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'mgd_language_v020.dart';
import 'consolidation_provenance_v0331.dart';
import 'learning_bridge_v0421.dart';

/// One external observation updates both the relational and language memories.
/// Replays remain exposure counts, never additional independent evidence.
class LearningService321 {
  static Future<int> learnText(PlasticLanguageBrain04 brain, MgdWorld06 world,
      MgdLanguage20 language, String text,
      {int passes = 1,
      String source = 'Testo insegnato',
      bool observeCls = true,
      bool Function()? shouldContinue,
      ResearchMemory11? memory,
      void Function(int done, int total)? progress}) async {
    final chunks = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    var done = 0, acquired = 0;
    final clock = Stopwatch()..start();
    acquisition:
    for (var p = 0; p < passes; p++) {
      for (final sentence in chunks) {
        if (shouldContinue != null && !shouldContinue()) break acquisition;
        brain.learnEvent(sentence, reward: .45);
        language.ingestText(sentence, reward: .45);
        world.integrateLanguageExperience09(brain, sentence, reward: .30);
        done++;
        if (p == 0) acquired++;
        progress?.call(done, chunks.length * passes);
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (acquired == 0) return done;
    // Only the acquired prefix may enter durable semantic memories. A stopped
    // replay adds exposures but does not add independent source evidence.
    final observed = acquired == chunks.length
        ? text
        : chunks.take(acquired).join('\n');
    if (memory != null) {
      await RelationalMemory324.learnAsync(memory, observed, source: source);
      final id = ResearchSemantics317.digest(ResearchSemantics317.norm(observed));
      SourceMemory323.retain(
          memory,
          WebDocument11(
              provider: 'Testo insegnato',
              family: 'locale:utente',
              title: source,
              url: 'local://corpus/' + id,
              text: observed,
              trust: .75));
    }
    if (observeCls) await ClsBridge340.observeText(observed, source: source);
    await LearningBridge421.external(observed, source);
    brain.discoverConcepts();
    world.runtime319['lastLearning321'] = {
      'kind': 'testo insegnato',
      'sentenceExposures': done,
      'elapsedMicros': clock.elapsedMicroseconds,
      'at': DateTime.now().toIso8601String(),
    };
    return done;
  }

  static Future<void> drainResearch(
      PlasticLanguageBrain04 brain, MgdWorld06 world, ResearchMemory11 memory,
      {bool Function()? shouldContinue}) async {
    while (ResearchSemantics317.getPending(memory) > 0) {
      if (shouldContinue != null && !shouldContinue()) return;
      ResearchSemantics317.processQueue(brain, world, memory, maxUnits: 24);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    // An unchanged extractor cannot learn by trying the same passage six times.
    // Preserve unresolved text and retry once when the extractor version changes.
    final explorer = WebKnowledgeExplorer11();
    while (memory.pendingPassages321.isNotEmpty) {
      if (shouldContinue != null && !shouldContinue()) return;
      explorer.reprocessDuringSleep(brain, world, memory, limit: 1);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  static Future<
      ({
        PlasticLanguageBrain04 brain,
        Map<String, dynamic> world,
        ResearchMemory11 research
      })> sleep(PlasticLanguageBrain04 brain, MgdWorld06 world,
          ResearchMemory11 research) =>
      Isolate.run(() {
        final baseStep = world.step;
        brain.sleepReplay(cycles: 72);
        ConsolidationEvidence331.sync(brain, world);
        world.sleepReplay(cycles: 72);
        world.think(brain, cycles: 32);
        return (
          brain: brain,
          world: world.toJson()..['runtimeBaseStep331'] = baseStep,
          research: research
        );
      });
}
