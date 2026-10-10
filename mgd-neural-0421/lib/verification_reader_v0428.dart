import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'cognitive_core_v0400.dart';
import 'cognitive_induction_v024.dart';
import 'learning_service_v0321.dart';
import 'learning_verification_v0428.dart';
import 'mgd_language_v020.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

/// Controlled reading uses new, disposable memories and the production web
/// intake/extractor/induction. Global bridges are never called, so fictional
/// facts, questions and answer keys cannot enter the user's real memories.
class VerificationReader428 {
  final PlasticLanguageBrain04 brain = PlasticLanguageBrain04();
  final ResearchMemory11 memory = ResearchMemory11(enabled: false);
  final MgdWorld06 world = MgdWorld06();
  final MgdLanguage20 language = MgdLanguage20();
  final CognitiveCore400 core;
  final Directory directory;
  VerificationReader428._(this.core, this.directory);

  static Future<VerificationReader428> open({DatabaseFactory? factory, String? temporaryRoot}) async {
    final root = temporaryRoot == null ? await getTemporaryDirectory() : Directory(temporaryRoot);
    final directory = await root.createTemp('mgd-verification-');
    try {
      final store = await CognitiveStore400.openAt('${directory.path}/core.db', factory: factory);
      return VerificationReader428._(CognitiveCore400(store), directory);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<VerificationAnswer428> answer(String prompt) =>
      MemoryQuery428.answer(brain, memory, prompt, core);

  Future<void> read(List<WebDocument11> documents, {bool Function()? cancelled}) async {
    for (final doc in documents) {
      if (cancelled?.call() ?? false) throw VerificationCancelled428();
      WebKnowledgeExplorer11().integrate(brain, world, memory, ResearchDraft11(
        goal: ResearchGoal11(query: doc.title, topic: doc.title,
            reason: 'Lettura controllata senza rete', value: 1),
        documents: [doc], claims: const [], passages: const [], sentencesRead: 0));
      await language.ingestWeb317(doc);
      ResearchSemantics317.markLanguage320(memory, doc);
      await CognitiveInduction24.learn(text: doc.text, sourceName: doc.title,
          brain: brain, memory: memory);
      for (final sentence in doc.text.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
        if (cancelled?.call() ?? false) throw VerificationCancelled428();
        if (sentence.trim().isNotEmpty) await core.experience(sentence, source: doc.title);
      }
      await LearningService321.drainResearch(brain, world, memory,
          shouldContinue: () => !(cancelled?.call() ?? false));
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> close() async {
    try { await core.store.close(); }
    finally { if (await directory.exists()) await directory.delete(recursive: true); }
  }
}
