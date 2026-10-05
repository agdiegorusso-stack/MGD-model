import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';

void main() {
  test('identity attractor generalizes across natural paraphrases', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mi chiamo Diego.');
    b.learnEvent('Tu ti chiami Jarvis.');

    expect(b.respond('come mi chiamo?').toLowerCase(), contains('diego'));
    expect(b.respond('qual è il mio nome?').toLowerCase(), contains('diego'));
    expect(b.respond('io chi sono?').toLowerCase(), contains('diego'));
    expect(b.respond('come ti chiami?').toLowerCase(), contains('jarvis'));
    expect(b.respond('tu chi sei?').toLowerCase(), contains('jarvis'));
  });

  test('daughter son and plural children stay distinct across word order', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mia figlia si chiama Cloe.');
    b.learnEvent('Mio figlio si chiama Dante.');

    final daughter1 = b.respond('come si chiama mia figlia?').toLowerCase();
    final daughter2 = b.respond('mia figlia come si chiama?').toLowerCase();
    final daughter3 = b.respond('chi è mia figlia?').toLowerCase();
    final son1 = b.respond('come si chiama mio figlio?').toLowerCase();
    final son2 = b.respond('mio figlio come si chiama?').toLowerCase();
    final son3 = b.respond('chi è mio figlio?').toLowerCase();
    final children1 = b.respond('come si chiamano i miei figli?').toLowerCase();
    final children2 = b.respond('i miei figli come si chiamano?').toLowerCase();
    final children3 = b.respond('chi sono i miei figli?').toLowerCase();

    for (final d in [daughter1, daughter2, daughter3]) {
      expect(d, contains('cloe'));
      expect(d, isNot(contains('dante')));
    }
    for (final d in [son1, son2, son3]) {
      expect(d, contains('dante'));
      expect(d, isNot(contains('cloe')));
    }
    for (final d in [children1, children2, children3]) {
      expect(d, contains('cloe'));
      expect(d, contains('dante'));
    }
  });

  test('partner attractor generalizes without a runtime phrase switch', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('La mia compagna si chiama Alessandra.');
    expect(b.respond('come si chiama la mia compagna?').toLowerCase(), contains('alessandra'));
    expect(b.respond('chi è mia moglie?').toLowerCase(), contains('alessandra'));
    expect(b.respond('chi è la mia partner?').toLowerCase(), contains('alessandra'));
  });

  test('novel verb relation is learned online by attractor matching', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Il cane mangia carne.');
    expect(b.respond('cosa mangia il cane?').toLowerCase(), contains('carne'));

    b.learnEvent('Il gatto mangia pesce.');
    expect(b.respond('cosa mangia il gatto?').toLowerCase(), contains('pesce'));
  });

  test('generic copular relation works for unseen entities', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Il cane è animale.');
    expect(b.respond('cosa è il cane?').toLowerCase(), contains('animale'));
  });

  test('sleep preserves attractor retrieval and does not swap roles', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mi chiamo Diego.');
    b.learnEvent('Tu ti chiami Jarvis.');
    b.learnEvent('Mia figlia si chiama Cloe.');
    b.learnEvent('Mio figlio si chiama Dante.');
    b.sleepReplay(cycles: 32);

    expect(b.respond('io chi sono?').toLowerCase(), contains('diego'));
    expect(b.respond('tu chi sei?').toLowerCase(), contains('jarvis'));
    expect(b.respond('chi è mia figlia?').toLowerCase(), contains('cloe'));
    expect(b.respond('chi è mio figlio?').toLowerCase(), contains('dante'));
  });

  test('one conversational turn creates one episode', () {
    final b = PlasticLanguageBrain04();
    b.respond('come ti chiami?');
    expect(b.stats().episodes, 1);
    b.teachResponse('come ti chiami?', 'Jarvis');
    expect(b.stats().episodes, 1);
  });

  test('entropic age is normalized and repetition changes less', () {
    final b = PlasticLanguageBrain04();
    final r1 = b.learnEvent('Il cane mangia carne.');
    final r2 = b.learnEvent('Il cane mangia carne.');
    expect(r1.flux, inInclusiveRange(0.0, 1.0));
    expect(r2.flux, inInclusiveRange(0.0, 1.0));
    expect(b.stats().entropicAge, lessThan(10.0));
  });

  test('state survives serialization and sleep', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mi chiamo Diego.');
    b.learnEvent('Mia figlia si chiama Cloe.');
    b.learnEvent('Mio figlio si chiama Dante.');
    final copy = PlasticLanguageBrain04.fromJson(b.toJson());
    copy.sleepReplay(cycles: 16);
    expect(copy.respond('io chi sono?').toLowerCase(), contains('diego'));
    expect(copy.respond('mia figlia come si chiama?').toLowerCase(), contains('cloe'));
    expect(copy.respond('mio figlio come si chiama?').toLowerCase(), contains('dante'));
  });

  test('v0.4 state can be loaded and enriched with developmental attractors', () {
    final old = PlasticLanguageBrain04();
    old.learnEvent('Mi chiamo Diego.');
    old.learnEvent('Mia figlia si chiama Cloe.');
    final json = old.toJson();
    json['version'] = 4;
    final migrated = PlasticLanguageBrain04.fromJson(json);
    expect(migrated.respond('io chi sono?').toLowerCase(), contains('diego'));
    expect(migrated.respond('chi è mia figlia?').toLowerCase(), contains('cloe'));
  });

  test('v0.5 corrupted child memory is repaired from episodic experience', () {
    final old = PlasticLanguageBrain04();
    old.learnEvent('Mi chiamo Diego.');
    old.learnEvent('Mia figlia si chiama Cloe.');
    old.learnEvent('Mio figlio si chiama Dante.');
    final json = old.toJson();
    json['version'] = 5;

    final relations = (json['relations'] as List).cast<Map<String, dynamic>>();
    final son = relations.firstWhere((r) => r['label'] == 'figlio')['id'] as int;
    final slots = (json['slots'] as List).cast<Map<String, dynamic>>();
    slots.removeWhere((slot) => slot['relationId'] == son);

    final migrated = PlasticLanguageBrain04.fromJson(json);
    final sonAnswer = migrated.respond('come si chiama mio figlio?').toLowerCase();
    final daughterAnswer = migrated.respond('come si chiama mia figlia?').toLowerCase();
    final childrenAnswer = migrated.respond('come si chiamano i miei figli?').toLowerCase();

    expect(sonAnswer, contains('dante'));
    expect(sonAnswer, isNot(contains('cloe')));
    expect(daughterAnswer, contains('cloe'));
    expect(daughterAnswer, isNot(contains('dante')));
    expect(childrenAnswer, contains('cloe'));
    expect(childrenAnswer, contains('dante'));
  });

  test('repeated questions do not reinforce or merge a wrong relation', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mia figlia si chiama Cloe.');
    b.learnEvent('Mio figlio si chiama Dante.');

    for (var i = 0; i < 4; i++) {
      expect(b.respond('come si chiama mio figlio?').toLowerCase(), contains('dante'));
      expect(b.respond('come si chiama mia figlia?').toLowerCase(), contains('cloe'));
    }

    final son = b.respond('chi è mio figlio?').toLowerCase();
    final daughter = b.respond('chi è mia figlia?').toLowerCase();
    expect(son, contains('dante'));
    expect(son, isNot(contains('cloe')));
    expect(daughter, contains('cloe'));
    expect(daughter, isNot(contains('dante')));
  });


  test('coordinated clauses become separate semantic events', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Mi chiamo Diego.');
    b.learnEvent('Tu ti chiami Jarvis.');
    b.learnEvent('io sono un essere umano e tu una macchina');

    expect(b.respond('io come mi chiamo?').toLowerCase(), contains('diego'));
    expect(b.respond('tu chi sei?').toLowerCase(), contains('jarvis'));

    final generic = b.relations.indexWhere((r) => r.key == 'latent:generic-is');
    expect(generic, greaterThanOrEqualTo(0));

    final userKey = b.userId.toString() + '::' + generic.toString();
    final selfKey = b.selfId.toString() + '::' + generic.toString();
    final userSlot = b.slots[userKey];
    final selfSlot = b.slots[selfKey];
    expect(userSlot?.winner?.display.toLowerCase(), contains('essere umano'));
    expect(selfSlot?.winner?.display.toLowerCase(), contains('macchina'));

    final allObjects = b.slots.values
        .expand((slot) => slot.candidates.values)
        .map((c) => c.display.toLowerCase())
        .toList();
    expect(allObjects.any((x) => x.contains('e tu una macchina')), isFalse);
  });

  test('coordination handles two explicit subjects', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Cloe è mia figlia e Dante è mio figlio.');

    final daughter = b.respond('chi è mia figlia?').toLowerCase();
    final son = b.respond('chi è mio figlio?').toLowerCase();
    expect(daughter, contains('cloe'));
    expect(daughter, isNot(contains('dante')));
    expect(son, contains('dante'));
    expect(son, isNot(contains('cloe')));
  });

  test('coordination does not split a simple multi-valued object', () {
    final b = PlasticLanguageBrain04();
    final before = b.stats().episodes;
    b.learnEvent('i miei figli sono Cloe e Dante');
    final after = b.stats().episodes;
    expect(after - before, 1);
  });


  test('semantic partner correction does not collapse onto user identity', () {
    final brain = PlasticLanguageBrain04();
    brain.teachResponse('come mi chiamo?', 'Diego', reward: 1.0);
    brain.teachResponse('chi è la mia compagna?', 'Alessandra', reward: 1.0);

    expect(brain.respond('come mi chiamo?').toLowerCase(), contains('diego'));
    expect(brain.respond('chi è la mia compagna?').toLowerCase(), contains('alessandra'));
  });

  test('partner role wins even after identity attractor is repeatedly reinforced', () {
    final brain = PlasticLanguageBrain04();
    for (var i = 0; i < 12; i++) {
      brain.teachResponse('come mi chiamo?', 'Diego', reward: 1.0);
    }
    brain.teachResponse('chi è la mia compagna?', 'Alessandra', reward: 1.0);
    for (var i = 0; i < 12; i++) {
      brain.teachResponse('io chi sono?', 'Diego', reward: 1.0);
    }
    expect(brain.respond('chi è la mia compagna?').toLowerCase(), contains('alessandra'));
  });

  test('stateful dialogue keeps multiple response attractors without contradiction', () {
    final b = PlasticLanguageBrain04();
    b.teachResponse('come stai?', 'Sto bene', reward: 1.0);
    b.teachResponse('come stai?', 'Sto male', reward: 1.0);
    b.teachResponse('come stai?', 'Così così', reward: 0.9);

    final options = b.responseOptions028('come stai?').map((x) => x.toLowerCase()).toSet();
    expect(options, contains('sto bene'));
    expect(options, contains('sto male'));
    expect(options, contains('così così'));

    final answers = <String>{};
    for (var i = 0; i < 6; i++) {
      answers.add(b.respond('come stai?').toLowerCase());
    }
    expect(answers.length, greaterThanOrEqualTo(2));
  });

  test('lexeme may own multiple senses and context disambiguates them', () {
    final b = PlasticLanguageBrain04();
    final astro = b.registerLexicalSense028(
      surface: 'stella',
      senseKey: 'astro',
      label: 'stella',
      gloss: 'corpo celeste che emette luce nello spazio',
      confidence: 0.8,
    );
    final symbol = b.registerLexicalSense028(
      surface: 'stella',
      senseKey: 'symbol',
      label: 'stella',
      gloss: 'simbolo grafico a cinque punte usato nel disegno',
      confidence: 0.8,
    );
    expect(astro, isNot(symbol));
    expect(b.entityIdForLabel06('stella'), isNull);
    expect(b.resolveSenseEntity028('stella nello spazio', context: 'corpo celeste luce'), astro);
    expect(b.resolveSenseEntity028('stella a cinque punte', context: 'simbolo grafico disegno'), symbol);
    final graph = b.semanticGraph(limit: 100);
    expect(graph.where((e) => e.relation == 'può significare').length, 2);
  });

  test('research hypothesis is assimilated weakly then can consolidate', () {
    final b = PlasticLanguageBrain04();
    final sid = b.ensureSemanticEntity06('organismo');
    b.importResearchHypothesis028(
      subjectId: sid,
      relation: 'tipo di',
      object: 'entità biologica',
      confidence: 0.45,
      sourceFamilies: const ['wikimedia'],
    );
    final slot = b.slots.values.firstWhere((s) => s.subjectId == sid);
    final candidate = slot.candidates.values.single;
    expect(candidate.epistemicStatus, 'hypothesis');
    expect(candidate.confidence, lessThan(0.52));

    b.importResearchFact028(
      subjectId: sid,
      relation: 'tipo di',
      object: 'entità biologica',
      confidence: 0.70,
      sourceFamilies: const ['wikimedia', 'britannica'],
    );
    expect(candidate.epistemicStatus, 'consolidated');
    expect(candidate.sourceFamilies.length, 2);
  });


  test('0.31 native composition builds a sentence never observed as a whole', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Il gatto dorme sul divano.');
    b.learnEvent('Il cane corre nel giardino.');

    final generated = b.composeSemantic031(
      subject: 'gatto',
      relation: 'corre',
      object: 'nel giardino',
    );
    expect(generated, isNotNull);
    final n = generated!.toLowerCase();
    expect(n, contains('gatto'));
    expect(n, contains('corre'));
    expect(n, contains('giardino'));
    expect(n, isNot(equals('il cane corre nel giardino.')));
  });

  test('0.31 learned surface frames survive serialization', () {
    final b = PlasticLanguageBrain04();
    b.learnEvent('Il gatto dorme sul divano.');
    b.learnEvent('Il cane mangia carne.');
    final copy=PlasticLanguageBrain04.fromJson(b.toJson());
    final generated=copy.composeSemantic031(subject:'gatto',relation:'mangia',object:'pesce');
    expect(generated,isNotNull);
    expect(generated!.toLowerCase(),contains('gatto mangia pesce'));
  });

}
