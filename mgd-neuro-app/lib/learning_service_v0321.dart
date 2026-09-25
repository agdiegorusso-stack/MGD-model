import 'dart:async';
import 'dart:isolate';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'mgd_language_v020.dart';

/// One external observation updates both the relational and language memories.
/// Replays remain exposure counts, never additional independent evidence.
class LearningService321 {
  static Future<int> learnText(PlasticLanguageBrain04 brain, MgdWorld06 world,
      MgdLanguage20 language, String text,
      {int passes = 1, ResearchMemory11? memory, void Function(int done, int total)? progress}) async {
    final chunks = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    var done = 0;
    final clock = Stopwatch()..start();
    for (var p = 0; p < passes; p++) {
      for (final sentence in chunks) {
        brain.learnEvent(sentence, reward: .45);
        language.ingestText(sentence, reward: .45);
        world.integrateLanguageExperience09(brain, sentence, reward: .30);
        done++;
        progress?.call(done, chunks.length * passes);
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (memory != null) {
      final id = ResearchSemantics317.digest(ResearchSemantics317.norm(text));
      SourceMemory323.retain(memory, WebDocument11(provider: 'Testo insegnato',
        family: 'locale:utente', title: 'Testo insegnato',
        url: 'local://corpus/' + id, text: text, trust: .75));
    }
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
        brain.sleepReplay(cycles: 72);
        world.sleepReplay(cycles: 72);
        world.think(brain, cycles: 32);
        return (brain: brain, world: world.toJson(), research: research);
      });
}
