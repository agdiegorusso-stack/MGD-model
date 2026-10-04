import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/generative_language_v0420.dart';
import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';
import 'package:mgd_neuro_mobile/social_cognition_v0410.dart';
import 'package:mgd_neuro_mobile/dialogue_engine_v0410.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('0.42 generative decoder and recursive ToM work on Android',(tester) async {
    final dir=await getTemporaryDirectory();
    final cp='${dir.path}/cognitive-0420-android.db';
    final sp='${dir.path}/social-0420-android.db';
    for(final p in [cp,sp]) { try { await File(p).delete(); } catch(_) {} }

    final cstore=await CognitiveStore400.openAt(cp);
    final sstore=await SocialStore410.openAt(sp);
    final core=CognitiveCore400(cstore);
    final dialogue=DialogueEngine410(core,TheoryOfMind410(sstore),sstore);

    await dialogue.process('Anna pensa che Luca crede che la palla è nella scatola.');
    final nested=await dialogue.process('Dove pensa Anna che Luca creda che sia la palla?');
    expect(nested?.text.toLowerCase(),contains('scatola'));

    final lang=MgdLanguage20();
    for(var i=0;i<12;i++) {
      lang.ingestText('Marta apre la porta con attenzione. '
          'Luca apre la finestra con attenzione.');
    }
    final generated=GenerativeLanguage420(lang).realize(
      'Chi apre la finestra?',
      'Marta apre la finestra con attenzione.',
      maxWords:16,
    );
    expect(generated?.toLowerCase(),contains('marta'));
    expect(generated?.toLowerCase(),contains('finestra'));

    await sstore.close();
    await cstore.close();
  });
}
