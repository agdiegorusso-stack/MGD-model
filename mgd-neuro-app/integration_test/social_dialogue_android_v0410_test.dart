import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';
import 'package:mgd_neuro_mobile/social_cognition_v0410.dart';
import 'package:mgd_neuro_mobile/dialogue_engine_v0410.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('0.41 persists false beliefs and multi-turn semantic focus after reopen',(tester) async {
    final dir=await getTemporaryDirectory();
    final cp='${dir.path}/cognitive-0410-android.db';
    final sp='${dir.path}/social-0410-android.db';
    for(final p in [cp,sp]) { try { await File(p).delete(); } catch(_) {} }

    var cstore=await CognitiveStore400.openAt(cp);
    var sstore=await SocialStore410.openAt(sp);
    var core=CognitiveCore400(cstore);
    var dialogue=DialogueEngine410(core,TheoryOfMind410(sstore),sstore);

    await dialogue.process('Anna mette la palla nella scatola.');
    await dialogue.process('Anna esce.');
    await dialogue.process('Luca mette la palla nella credenza.');
    await dialogue.process('La glarpa beve acqua.');
    final falseBelief=await dialogue.process('Dove pensa Anna che sia la palla?');
    expect(falseBelief?.text.toLowerCase(),contains('scatola'));
    expect(falseBelief?.text.toLowerCase(),isNot(contains('credenza')));

    await sstore.close();
    await cstore.close();

    cstore=await CognitiveStore400.openAt(cp);
    sstore=await SocialStore410.openAt(sp);
    core=CognitiveCore400(cstore);
    dialogue=DialogueEngine410(core,TheoryOfMind410(sstore),sstore);

    final reopened=await dialogue.process('Dove pensa Anna che sia la palla?');
    expect(reopened?.text.toLowerCase(),contains('scatola'));
    final stats=await sstore.stats();
    expect(stats['beliefs'],greaterThan(0));

    await sstore.close();
    await cstore.close();
  });
}
