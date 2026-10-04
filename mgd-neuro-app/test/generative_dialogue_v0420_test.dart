import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';
import 'package:mgd_neuro_mobile/social_cognition_v0410.dart';
import 'package:mgd_neuro_mobile/dialogue_engine_v0410.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('MGD Generative Dialogue 0.42', () {
    test('variable-order decoder recombines learned syntax while preserving semantic anchors', () {
      final l=MgdLanguage20();
      for(var i=0;i<18;i++) {
        l.ingestText('Marta apre la porta con attenzione. '
            'Luca apre la finestra con attenzione. '
            'Marta osserva la finestra con attenzione.');
      }
      final out=l.generateOpen420(
        'Chi apre la finestra?',
        semanticHint:'Marta apre la finestra con attenzione.',
        maxWords:16,
      );
      expect(out,isNotNull);
      expect(out!.toLowerCase(),contains('marta'));
      expect(out.toLowerCase(),contains('finestra'));
      expect(out.split(' ').length,greaterThanOrEqualTo(4));
    });

    late Directory dir;
    late CognitiveStore400 cognitive;
    late SocialStore410 social;
    late CognitiveCore400 core;
    late DialogueEngine410 dialogue;

    setUp(() async {
      dir=await Directory.systemTemp.createTemp('mgd420-');
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

    test('distributional semantic space discovers related unseen labels from shared contexts', () async {
      for(var i=0;i<6;i++) {
        await core.experience('La glarpa beve acqua.');
        await core.experience('La glarpa corre nel prato.');
        await core.experience('La ferlia beve acqua.');
        await core.experience('La ferlia corre nel prato.');
      }
      await core.experience('Il sasso cade sulla terra.');
      final near=await cognitive.semanticNeighbors420('glarpa',limit:8);
      expect(near.map((x)=>x['term']),contains('ferlia'));
      final ferlia=near.firstWhere((x)=>x['term']=='ferlia');
      expect((ferlia['score'] as num).toDouble(),greaterThan(.12));
    });

    test('second-order theory of mind keeps a belief about another belief', () async {
      await dialogue.process('Anna pensa che Luca crede che la palla è nella scatola.');
      final r=await dialogue.process('Dove pensa Anna che Luca creda che sia la palla?');
      expect(r,isNotNull);
      expect(r!.intent,'theory-of-mind');
      expect(r.text.toLowerCase(),contains('luca'));
      expect(r.text.toLowerCase(),contains('scatola'));
      expect(r.text.toLowerCase(),contains('credenza su una credenza'));
    });

    test('open dialogue uses semantic expansion instead of exact lexical identity only', () async {
      for(var i=0;i<5;i++) {
        await dialogue.process('La glarpa beve acqua.');
        await dialogue.process('La ferlia beve acqua.');
        await dialogue.process('La glarpa corre nel prato.');
        await dialogue.process('La ferlia corre nel prato.');
      }
      final r=await dialogue.process('Come sono collegate glarpa e ferlia?');
      expect(r,isNotNull);
      expect(r!.text.isNotEmpty,isTrue);
      expect(r.text.toLowerCase(),
        anyOf(contains('colleg'),contains('semant'),contains('memoria'),contains('relazioni')));
    });
  });
}
