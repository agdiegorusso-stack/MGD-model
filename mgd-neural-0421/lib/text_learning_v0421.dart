import 'dart:io';
import 'book_text_v0420.dart';
import 'learning_service_v0321.dart';
import 'mgd_language_v020.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

class TextImport421 {
  final int fragments, exposures, retainedOnly;
  final bool cancelled;
  const TextImport421(this.fragments, this.exposures, this.retainedOnly,
      this.cancelled);
}

/// Streamed acquisition into the same memories used by chat and the map.
class TextLearning421 {
  static Future<TextImport421> importFile(File file,
      {required String name,
      required PlasticLanguageBrain04 brain,
      required MgdWorld06 world,
      required ResearchMemory11 research,
      required MgdLanguage20 language,
      bool Function()? cancelled,
      void Function(int, int)? progress}) async {
    BookText420.validateName(name);
    var fragments = 0, exposures = 0, retained = 0;
    await for (final part in BookText420.fragments(BookText420.decode(file))) {
      if (cancelled?.call() ?? false) break;
      if (part.semanticSafe) {
        exposures += await LearningService321.learnText(
            brain, world, language, part.text,
            memory: research, source: name);
      } else {
        // A sentence cut by the resource budget is evidence, not a new fact.
        language.ingestText(part.text, reward: .42, learnFrames341: false);
        SourceMemory323.retain(research, WebDocument11(
            provider: 'TXT locale', family: 'locale:utente', title: name,
            url: 'local://fragment/${ResearchSemantics317.digest(part.text)}',
            text: part.text, trust: .75));
        retained++;
      }
      fragments++;
      progress?.call(fragments, exposures);
      await Future<void>.delayed(Duration.zero);
    }
    return TextImport421(fragments, exposures, retained,
        cancelled?.call() ?? false);
  }
}
