import 'dart:async';
import 'package:flutter/foundation.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'cognitive_induction_v024.dart';
import 'relational_memory_v0324.dart';
import 'learned_reader_v0324.dart';

List<ExtractedClaim11> _extract321(WebDocument11 doc) => doc.text
    .split(RegExp(r'(?<=[.!?])\s+|\n+'))
    .where((s) => !LearnedReader324.handles(s))
    .expand((s) => ResearchSemantics317.extractAny321(s, doc))
    .toList();

class CorpusSemanticOutcome22 {
  final int sentences,
      candidates,
      accepted,
      doubtful,
      conflicts,
      reinforced,
      entitiesTouched;
  CorpusSemanticOutcome22(
      {required this.sentences,
      required this.candidates,
      required this.accepted,
      required this.doubtful,
      required this.conflicts,
      required this.reinforced,
      required this.entitiesTouched});
  String cognitiveSummary = '';
  String get summary =>
      '$candidates proposizioni esaminate, $accepted nuove utilizzabili con fonte, '
      '$reinforced già note, $doubtful osservate, $conflicts conflitti';
}

/// Local reading uses exactly the same evidence checks and audit as web intake.
/// A renamed/reimported file is not an independent confirming source.
class CorpusSemanticBridge22 {
  static Future<CorpusSemanticOutcome22> learn({
    required String text,
    required String sourceName,
    required PlasticLanguageBrain04 brain,
    required MgdWorld06 world,
    required ResearchMemory11 memory,
    String? sourceFamily,
  }) async {
    final clock = Stopwatch()..start();
    final digest = ResearchSemantics317.digest(ResearchSemantics317.norm(text));
    final doc = WebDocument11(
        provider: 'Corpus locale',
        family: 'locale:utente',
        title: sourceName,
        url: 'local://corpus/$digest',
        text: text,
        trust: .75);
    final learned324=await RelationalMemory324.learnAsync(memory,text,source:sourceName);
    final claims = await compute(_extract321, doc);
    final count = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .where((s) => s.trim().isNotEmpty)
        .length;
    final beforeEntities = brain.entities.length;
    final outcome = WebKnowledgeExplorer11().integrate(
        brain,
        world,
        memory,
        ResearchDraft11(
            goal: ResearchGoal11(
                query: sourceName,
                topic: sourceName,
                reason: 'testo fornito dall’utente',
                value: 1),
            documents: [doc],
            claims: claims,
            passages: [],
            sentencesRead: count));
    final session = memory.lastSession!;
    while (ResearchSemantics317.getPending(memory) > 0) {
      ResearchSemantics317.processQueue(brain, world, memory, maxUnits: 24);
      await Future<void>.delayed(Duration.zero);
    }
    final sources =
        Set<String>.from(memory.state317['localSources321'] as List? ?? []);
    String cognitiveSummary = 'Testo già presente nella memoria narrativa';
    if (sources.add(digest)) {
      final cognitive = await CognitiveInduction24.learn(
          text: text, sourceName: sourceName, brain: brain, memory: memory);
      cognitiveSummary = cognitive.summary;
      memory.state317['localSources321'] = sources.toList();
    }
    session.audit315['learnedReader324']={'added':learned324.added,'unresolved':learned324.unresolved};
    session.completedAtIso = DateTime.now().toIso8601String();
    session.audit315['elapsedMicros321'] = clock.elapsedMicroseconds;
    world.runtime319['lastLearning321'] = {
      'kind': 'corpus locale',
      'sentences': session.sentencesRead,
      'newUsable': session.audit315['newUsable321'],
      'elapsedMicros': clock.elapsedMicroseconds,
      'at': session.completedAtIso
    };
    return CorpusSemanticOutcome22(
        sentences: session.sentencesRead,
        candidates: session.candidates,
        accepted:
            session.audit315['newUsable321'] as int? ?? outcome.integrated,
        doubtful: session.doubtful,
        conflicts: session.contradictions,
        reinforced: session.audit315['knownClaims321'] as int? ?? 0,
        entitiesTouched: brain.entities.length - beforeEntities)
      ..cognitiveSummary = cognitiveSummary;
  }
}
