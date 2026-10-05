import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v10.dart';

void main() {
  test('extractor learns Italian copular taxonomy conservatively', () {
    final explorer = WebKnowledgeExplorer10();
    const doc = WebDocument10(
      provider: 'test',
      sourceFamily: 'test-family',
      title: 'Cane',
      url: 'https://example.test/cane',
      text: '',
      trust: 0.9,
    );

    final c = explorer.extractClaimFromSentence(
      'cane',
      'Il cane è un mammifero appartenente alla famiglia dei canidi.',
      doc,
    );

    expect(c, isNotNull);
    expect(c!.subject.toLowerCase(), 'cane');
    expect(c.relation, 'tipo di');
    expect(c.object.toLowerCase(), contains('mammifero'));
  });

  test('extractor recognizes Italian possession relation', () {
    final explorer = WebKnowledgeExplorer10();
    const doc = WebDocument10(
      provider: 'test',
      sourceFamily: 'test-family',
      title: 'Uccello',
      url: 'https://example.test/uccello',
      text: '',
      trust: 0.9,
    );

    final c = explorer.extractClaimFromSentence(
      'uccello',
      "L'uccello ha piume che ricoprono il corpo.",
      doc,
    );

    expect(c, isNotNull);
    expect(c!.relation, 'ha');
    expect(c.object.toLowerCase(), 'piume');
  });

  test('research memory persists provenance and daily budget', () {
    final memory = ResearchMemory10(enabled: true, dailyBudget: 3);
    final now = DateTime.now();
    expect(memory.canResearch('cane mammifero', now: now), isTrue);
    memory.beginQuery('cane mammifero', now);
    expect(memory.requestsToday, 1);
    expect(
      memory.canResearch(
        'cane mammifero',
        now: now.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );

    memory.evidence.add(ResearchEvidence10(
      id: 'e1',
      query: 'cane mammifero',
      subject: 'cane',
      relation: 'tipo di',
      object: 'mammifero',
      provider: 'Wikipedia IT',
      sourceFamily: 'wikipedia',
      sourceTitle: 'Cane',
      sourceUrl: 'https://it.wikipedia.org/wiki/Cane',
      sourceHost: 'it.wikipedia.org',
      excerpt: 'Il cane è un mammifero.',
      sourceTrust: 0.82,
      retrievedAtIso: now.toIso8601String(),
    ));

    final roundTrip = ResearchMemory10.fromJson(memory.toJson());
    expect(roundTrip.enabled, isTrue);
    expect(roundTrip.evidence.single.sourceFamily, 'wikipedia');
    expect(roundTrip.requestsToday, 1);
  });

  test('goal selector prefers a known but underexplored entity', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final memory = ResearchMemory10();
    brain.learnEvent('Questo è un ornitorinco.', reward: 0.9);
    world.integrateLanguageExperience09(
      brain,
      'Questo è un ornitorinco.',
      reward: 0.6,
    );
    final id = brain.ensureSemanticEntity06('ornitorinco');
    brain.entities[id].mentions += 4;
    brain.entities[id].lastSeen = brain.step;
    world.curiosity = 0.8;

    final goal =
        WebKnowledgeExplorer10().selectGoal(brain, world, memory);
    expect(goal, isNotNull);
    expect(goal!.query.toLowerCase(), contains('ornitorinco'));
    expect(goal.value, greaterThan(0));
  });

  test('single-source web claim remains a weak prior', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final memory = ResearchMemory10();
    final explorer = WebKnowledgeExplorer10();
    final now = DateTime.now();
    const doc = WebDocument10(
      provider: 'Wikipedia IT',
      sourceFamily: 'wikipedia',
      title: 'Cane',
      url: 'https://it.wikipedia.org/wiki/Cane',
      text: 'Il cane è un mammifero.',
      trust: 0.82,
    );
    final claim = explorer.extractClaimFromSentence(
      'cane',
      'Il cane è un mammifero.',
      doc,
    );
    const goal = ResearchGoal10(
      query: 'cane definizione',
      focusLabel: 'cane',
      reason: 'test',
      kind: 'test',
      value: 0.8,
      seedEntityIds: [],
    );
    memory.beginQuery(goal.query, now);
    final outcome = explorer.integrate(
      brain,
      world,
      memory,
      ResearchDraft10(
        goal: goal,
        documents: const [doc],
        claims: [claim!],
      ),
    );

    expect(outcome.integratedClaims, 1);
    final stored = memory.claims.values.single;
    expect(stored.confidence, lessThanOrEqualTo(0.70));
    expect(stored.sourceFamilies, contains('wikipedia'));
    expect(
      brain.cognitiveFacts06().any(
        (f) => f.object.toLowerCase().contains('mammifero'),
      ),
      isTrue,
    );
  });
}
