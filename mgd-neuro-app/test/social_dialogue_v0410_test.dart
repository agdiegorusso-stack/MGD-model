import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';
import 'package:mgd_neuro_mobile/social_cognition_v0410.dart';
import 'package:mgd_neuro_mobile/dialogue_engine_v0410.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('MGD social cognition and open dialogue 0.41', () {
    late Directory dir;
    late CognitiveStore400 cognitive;
    late SocialStore410 social;
    late CognitiveCore400 core;
    late DialogueEngine410 dialogue;

    setUp(() async {
      dir=await Directory.systemTemp.createTemp('mgd410-');
      cognitive=await CognitiveStore400.openAt('${dir.path}/cognitive.db',factory:databaseFactoryFfi);
      social=await SocialStore410.openAt('${dir.path}/social.db',factory:databaseFactoryFfi);
      core=CognitiveCore400(cognitive);
      dialogue=DialogueEngine410(core,TheoryOfMind410(social),social);
    });

    tearDown(() async {
      await social.close();
      await cognitive.close();
      await dir.delete(recursive:true);
    });

    test('false belief stays separate from changed world state', () async {
      await dialogue.process('Anna mette la palla nella scatola.');
      await dialogue.process('Anna esce.');
      await dialogue.process('Luca mette la palla nella credenza.');
      final r=await dialogue.process('Dove pensa Anna che sia la palla?');
      expect(r,isNotNull);
      expect(r!.intent,'theory-of-mind');
      expect(r.text.toLowerCase(),contains('scatola'));
      expect(r.text.toLowerCase(),isNot(contains('credenza')));
    });

    test('goals are represented separately from factual world relations', () async {
      await dialogue.process('Marco vuole andare a Roma.');
      final r=await dialogue.process('Che cosa vuole Marco?');
      expect(r,isNotNull);
      expect(r!.text.toLowerCase(),contains('andare a roma'));
    });

    test('multi-turn dialogue keeps a semantic focus rather than raw text', () async {
      await dialogue.process('La glarpa beve acqua.');
      await dialogue.process('La glarpa corre nel prato.');
      final first=await dialogue.process('Cosa pensi di glarpa?');
      expect(first,isNotNull);
      expect(first!.text.toLowerCase(),contains('glarpa'));
      final follow=await dialogue.process('Spiegami meglio');
      expect(follow,isNotNull);
      expect(follow!.text.toLowerCase(),contains('glarpa'));
      final stored=await social.getMeta('dialogue_state');
      expect(stored,isNotNull);
      expect(stored,contains('glarpa'));
      expect(stored,isNot(contains('La glarpa beve acqua')));
    });

    test('direct relational question is rendered as an answer', () async {
      await dialogue.process('Marta apre la porta.');
      final r=await dialogue.process('Chi apre la porta?');
      expect(r,isNotNull);
      expect(r!.text.toLowerCase(),contains('marta'));
    });

    test('open question returns grounded evidence or explicit uncertainty', () async {
      await dialogue.process('Il norvente aiuta il talverio.');
      await dialogue.process('Il talverio entra nella casa.');
      final r=await dialogue.process('Come sono collegati norvente e casa?');
      expect(r,isNotNull);
      expect(r!.text,isNotEmpty);
      expect(r.text.toLowerCase(),
        anyOf(contains('colleg'),contains('memoria'),contains('rappresentazione')));
    });

    test('dialogue focus survives store reopen', () async {
      await dialogue.process('La ferlia osserva il cielo.');
      await social.close();
      social=await SocialStore410.openAt('${dir.path}/social.db',factory:databaseFactoryFfi);
      dialogue=DialogueEngine410(core,TheoryOfMind410(social),social);
      final r=await dialogue.process('Spiegami meglio');
      expect(r,isNotNull);
      expect(r!.text.toLowerCase(),contains('ferlia'));
    });

    test('metacognition exposes uncertainty rather than fabricating knowledge', () async {
      final r=await dialogue.process('Che cosa non capisci?');
      expect(r,isNotNull);
      expect(r!.intent,'ignorance');
      expect(r.text,isNotEmpty);
    });
  });
}
