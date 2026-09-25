import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';

Uint8List imageBytes(int r, int g, int b) {
  final image = img.Image(width: 32, height: 32);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('visual episodic query resolves through identity to sensory memory', () {
    final brain = PlasticLanguageBrain04();
    brain.learnEvent('Mi chiamo Diego.');
    final diego = brain.entityIdForLabel06('Diego');
    expect(diego, isNotNull);

    final world = MgdWorld06();
    world.observeVisionBytes(imageBytes(180, 90, 70));
    world.bindLast(label: 'Diego', entityId: diego!);

    final answer = world.groundedAnswer07(brain, 'mi hai già visto?');
    expect(answer, isNotNull);
    expect(answer!.toLowerCase(), contains('sì'));
    expect(answer.toLowerCase(), contains('diego'));
  });

  test('inverse identity query walks object to subject', () {
    final brain = PlasticLanguageBrain04();
    brain.learnEvent('Mi chiamo Diego.');
    final world = MgdWorld06();
    final answer = world.groundedAnswer07(brain, 'sai chi è Diego?');
    expect(answer?.toLowerCase(), contains('sei tu'));
  });

  test('thought recurrence produces exploratory non-empty hypotheses', () {
    final brain = PlasticLanguageBrain04();
    brain.learnEvent('Mi chiamo Diego.');
    brain.learnEvent('Cloe è mia figlia.');
    brain.learnEvent('Dante è mio figlio.');
    final world = MgdWorld06();
    final trace = world.think(brain, cycles: 24, seedText: 'Diego');
    expect(trace, isNotEmpty);
    expect(trace.any((t) => t.hypothesis.startsWith('Ipotesi:') || t.hypothesis.startsWith('Esploro:')), isTrue);
  });

  test('natural self label grounds photo to user identity', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(imageBytes(180, 120, 90));
    final canonical = world.bindLastNatural071(brain, 'sono io Diego');

    expect(canonical.toLowerCase(), 'diego');
    expect(
      world.lastPerceptionSummary().toLowerCase(),
      contains('diego'),
    );
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
    expect(
      world.groundedAnswer07(brain, 'mi hai già visto?')?.toLowerCase(),
      contains('sì'),
    );
  });

  test('old sentence-shaped sensory label is repaired on load', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    final result = world.observeVisionBytes(imageBytes(170, 110, 85));
    final wrong = brain.ensureSemanticEntity06('sono io Diego');
    world.bindLast(label: 'sono io Diego', entityId: wrong);

    expect(
      result.prototype.label?.toLowerCase(),
      contains('sono io diego'),
    );

    final repaired = world.repairNaturalBindings071(brain);
    expect(repaired, 1);
    expect(result.prototype.label?.toLowerCase(), 'diego');
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
  });

  test('natural object sentence binds perception to object entity', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(imageBytes(220, 30, 30));
    final canonical = world.bindLastNatural071(brain, 'questo è un cane');
    expect(canonical.toLowerCase(), 'cane');
    expect(world.lastPerceptionSummary().toLowerCase(), contains('cane'));
  });


  test('0.8 Persona Diego alias is merged into canonical user identity', () {
    final brain = PlasticLanguageBrain04();
    brain.learnEvent('Mi chiamo Diego.');
    final diego = brain.entityIdForLabel06('Diego');
    expect(diego, isNotNull);

    final world = MgdWorld06();
    final result = world.observeVisionBytes(imageBytes(160, 110, 80));
    final duplicate = brain.ensureSemanticEntity06('Persona diego');
    world.bindLast(label: 'Persona diego', entityId: duplicate);

    expect(result.prototype.semanticEntityId, duplicate);
    expect(
      world.groundedAnswer07(brain, 'mi hai mai visto?')?.toLowerCase(),
      contains('sì'),
    );
    expect(result.prototype.semanticEntityId, diego);
    expect(result.prototype.label?.toLowerCase(), 'diego');
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
  });

  test('Persona Diego natural binding reuses canonical identity', () {
    final brain = PlasticLanguageBrain04();
    brain.learnEvent('Mi chiamo Diego.');
    final diego = brain.entityIdForLabel06('Diego');
    expect(diego, isNotNull);

    final world = MgdWorld06();
    world.observeVisionBytes(imageBytes(140, 100, 90));
    final canonical = world.bindLastNatural071(brain, 'Persona Diego');

    expect(canonical.toLowerCase(), 'diego');
    expect(world.prototypes.single.semanticEntityId, diego);
    expect(
      world.groundedAnswer07(brain, 'mi hai visto?')?.toLowerCase(),
      contains('sì'),
    );
  });


  test('native MGD edge evolves memory material and active geometry', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    brain.learnEvent('Cane è animale.');
    brain.learnEvent('Gatto è animale.');

    for (var i = 0; i < 8; i++) {
      world.integrateLanguageExperience09(brain, 'Cane e gatto.', reward: 0.8);
    }

    final cane = brain.entityIdForLabel06('Cane');
    final gatto = brain.entityIdForLabel06('Gatto');
    expect(cane, isNotNull);
    expect(gatto, isNotNull);
    final key = ['e:$cane', 'e:$gatto']..sort();
    final e = world.edges['${key[0]}|${key[1]}'];
    expect(e, isNotNull);
    expect(e!.fast, greaterThan(0));
    expect(e.cost, lessThanOrEqualTo(1.0));
    expect(world.stats().activeEdges, greaterThan(0));
  });

  test('stable unnamed perception makes MGD ask its own question', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final bytes = imageBytes(170, 110, 80);
    for (var i = 0; i < 5; i++) {
      world.observeVisionBytes(bytes);
    }
    final question = world.nextCuriosityQuestion09(brain);
    expect(question, isNotNull);
    expect(question!.toLowerCase(), contains('come chiam'));

    final acknowledgement = world.consumeCuriosityAnswer09(brain, 'mela');
    expect(acknowledgement, isNotNull);
    expect(world.prototypes.first.label?.toLowerCase(), 'mela');
  });

  test('known common category does not request a new cluster name', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    brain.learnEvent('Cane è animale.');
    brain.learnEvent('Gatto è animale.');
    for (var i = 0; i < 8; i++) {
      world.integrateLanguageExperience09(brain, 'Cane e gatto.', reward: 0.9);
    }
    expect(world.nextCuriosityQuestion09(brain), isNull);
    expect(world.pendingCuriosityType09, isNull);
  });

  test('chat deictic self assertion binds last photo', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(imageBytes(180, 120, 90));
    final canonical =
        world.bindLastFromUtterance091(brain, 'questo sono io Diego');

    expect(canonical?.toLowerCase(), 'diego');
    expect(world.currentUserEntityId091, isNotNull);
    expect(
      world.groundedAnswer07(brain, 'mi hai già visto?')?.toLowerCase(),
      contains('sì'),
    );
    expect(
      world.groundedAnswer07(brain, 'chi sono io?')?.toLowerCase(),
      'diego.',
    );
  });

  test('0.9 history migration repairs photo plus chat self assertion', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    final result = world.observeVisionBytes(imageBytes(170, 110, 80));
    final diego = brain.ensureSemanticEntity06('Diego');
    world.bindLast(label: 'Diego', entityId: diego);

    // Simulate the exact old 0.9 failure: language episode says who the
    // person is, but the sensor and CURRENT_USER role were never unified.
    brain.respond('questo sono io Diego');
    expect(world.currentUserEntityId091, isNull);

    final repaired = world.repairCurrentUserFromHistory091(brain);
    expect(repaired, greaterThan(0));
    expect(world.currentUserEntityId091, diego);
    expect(result.prototype.semanticEntityId, diego);
    expect(
      world.groundedAnswer07(brain, 'mi hai già visto?')?.toLowerCase(),
      contains('sì'),
    );
  });

  test('deictic object chat assertion grounds last photo too', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(imageBytes(220, 30, 30));
    final canonical =
        world.bindLastFromUtterance091(brain, 'questo è un cane');

    expect(canonical?.toLowerCase(), 'cane');
    expect(world.prototypes.single.label?.toLowerCase(), 'cane');
  });


  test('response state can own visual and audio sensory prototypes', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    brain.teachResponse('Come stai?', 'Sto bene', reward: 0.9);
    final entity = brain.ensureSemanticEntity06('Sto bene');

    final visual = world.observeVisionBytes(imageBytes(180, 90, 70));
    world.bindLast(label: 'Sto bene', entityId: entity);
    final audio = world.observeAudioPcm(Uint8List.fromList(List<int>.filled(1600, 8)), sampleRate: 16000);
    world.bindLast(label: 'Sto bene', entityId: entity);

    expect(visual.prototype.semanticEntityId, entity);
    expect(audio.prototype.semanticEntityId, entity);
    final linked = world.sensoryForEntity07(brain, entity);
    expect(linked.map((p) => p.modality).toSet(), containsAll(<String>{'vision', 'audio'}));
  });

}
