import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/corpus_semantic_bridge_v022.dart';
import '../lib/knowledge_inspector_v0315.dart';
import '../lib/learning_service_v0321.dart';
import '../lib/memory_runtime_v0319.dart';
import '../lib/reasoning_v0321.dart';
import 'research_v0318_test.dart' show Sources318;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'legacy unstructured text learns an explicit subject different from the old query',
      () async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    m.passages.add(ResearchPassage11(
        id: 'old',
        topic: 'Biologia',
        provider: 'Fonte',
        sourceFamily: 'example',
        sourceTitle: 'Manuale',
        sourceUrl: 'https://example.org/biologia',
        text: 'Il nucleotide è una molecola.',
        trust: .9,
        attempts: 6));
    await LearningService321.drainResearch(b, w, m);
    expect(m.passages.single.structured, true);
    expect(m.pendingPassages321, isEmpty);
    expect(ResearchSemantics317.answer('Cosa è il nucleotide?', m),
        contains('molecola'));
  });
  test(
      'structured Wikidata sources are present in the session document inventory',
      () async {
    final explorer = WebKnowledgeExplorer11(jsonLoader318: Sources318().call);
    final draft = await explorer.research(const ResearchGoal11(
        query: 'Organismi',
        topic: 'Organismi',
        reason: 'source inventory',
        value: 1));
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    explorer.integrate(b, w, m, draft);
    final inspector = MemoryInspector315(
        brain: b, world: w, research: m, language: MgdLanguage20());
    final documents = inspector.sessionRows(m.lastSession!, 'Documenti');
    for (final claim in draft.claims) {
      expect(documents.any((d) => d['sourceUrl'] == claim.source.url), true,
          reason: claim.source.url);
    }
    expect(documents.length, m.lastSession!.documents);
    expect(inspector.sessionRows(m.lastSession!, 'Provider').length,
        m.lastSession!.providers);
  });
  test(
      'one local reading answers unseen questions; reimport is not new evidence',
      () async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    const text = 'Il zorvello produce lumina. Il zorvello contiene cristalli. '
        'Il talverio vive nella grotta.';
    final a = await CorpusSemanticBridge22.learn(
        text: text, sourceName: 'Primo.txt', brain: b, world: w, memory: m);
    expect(a.accepted, 3);
    expect(ResearchSemantics317.answer('Cosa produce il zorvello?', m),
        contains('lumina'));
    expect(ResearchSemantics317.answer('Cosa produce il zorvello?', m),
        isNot(contains('cristalli')));
    expect(ResearchSemantics317.answer('Dove vive il talverio?', m),
        contains('grotta'));
    expect(m.lastSession!.sentencesRead, 3);
    final evidence = m.evidence.length;
    final repeated = await CorpusSemanticBridge22.learn(
        text: text,
        sourceName: 'Rinominato.txt',
        brain: b,
        world: w,
        memory: m);
    expect(repeated.accepted, 0);
    expect(repeated.reinforced, 3);
    expect(m.evidence.length, evidence);
    expect(m.lastSession!.learnedFacts, isEmpty);
    expect(m.lastSession!.audit315['newClaims321'], 0);
    expect(m.lastSession!.audit315['newEvidence321'], 0);
    expect(m.lastSession!.sentencesRead, 3);
    final restored =
        ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(ResearchSemantics317.answer('Cosa produce il zorvello?', restored),
        contains('lumina'));
  });

  test('unsupported prose is retained but not retried forever', () async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    m.state317.addAll({'migrationComplete': true, 'recovery320Complete': true});
    m.passages.add(ResearchPassage11(
        id: 'p',
        topic: 'dubbio',
        provider: 'Locale',
        sourceFamily: 'locale',
        sourceTitle: 'Testo',
        sourceUrl: 'local://testo',
        text: 'Forse alcune osservazioni richiederanno ulteriori studi.'));
    await LearningService321.drainResearch(b, w, m);
    expect(m.pendingPassages321, isEmpty);
    expect(m.uninterpretedPassages321.length, 1);
    expect(m.passages.single.attempts, 1);
    await LearningService321.drainResearch(b, w, m);
    expect(m.passages.single.attempts, 1);
    expect(m.claims, isEmpty);
    expect(m.sessions, isEmpty);
  });

  test(
      'class deductions have new conclusions, premises, and invalidate on conflict',
      () async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    await CorpusSemanticBridge22.learn(
        text: 'Il zorvello è una sottoclasse di talverio. '
            'Il talverio è una sottoclasse di norvante.',
        sourceName: 'Classi',
        brain: b,
        world: w,
        memory: m);
    final proof = Reasoning321.infer(m, 'zorvello').single;
    expect(proof.object, 'norvante');
    expect(proof.premises.length, 2);
    expect(m.claims.length,
        2); // A deduction never fabricates another observation.
    expect(Reasoning321.answer('Cosa puoi dedurre sul zorvello?', m),
        contains('Premesse:'));
    await CorpusSemanticBridge22.learn(
        text: 'Il talverio non è una sottoclasse di norvante.',
        sourceName: 'Smentita',
        brain: b,
        world: w,
        memory: m);
    expect(Reasoning321.infer(m, 'zorvello'), isEmpty);
  });

  test(
      'attributes, conditional statements, and cycles do not become class proofs',
      () async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    await CorpusSemanticBridge22.learn(
        text: 'Il cielo è blu. Il blu è una sottoclasse di colore. '
            'Se il cane è una sottoclasse di mammifero. Il mammifero è una sottoclasse di cane.',
        sourceName: 'Limiti',
        brain: b,
        world: w,
        memory: m);
    expect(Reasoning321.infer(m, 'cielo'), isEmpty);
    expect(Reasoning321.infer(m, 'cane'), isEmpty);
  });

  test(
      'metric values and drills share the same collections after learning and restart',
      () async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11(),
        l = MgdLanguage20();
    for (var n = 0; n < 4; n++) l.ingestText('Il cane è un mammifero.');
    l.ingestText('La sequenza rara resta separata.');
    await CorpusSemanticBridge22.learn(
        text: 'Il cane è un mammifero. Il cane mangia carne.',
        sourceName: 'Prova',
        brain: b,
        world: w,
        memory: m);
    for (final research in [
      m,
      ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())))
    ]) {
      final inspector = MemoryInspector315(
          brain: b, world: w, research: research, language: l);
      for (final label in MemoryInspector315.counted321) {
        expect(inspector.metricValue321(label),
            '${inspector.metricRows(label).length}',
            reason: label);
        expect(
            inspector
                .metricRows(label)
                .any((r) => '${r['nota']}'.contains('Dettaglio aggregato')),
            false,
            reason: label);
      }
      for (final label in [
        'Documenti',
        'Provider',
        'Famiglie',
        'Frasi lette',
        'Candidati',
        'Documentate',
        'Corroborate',
        'Proposizioni nuove',
        'Già note',
        'Nuove evidenze',
        'Osservate',
        'Quarantena',
        'Conflitti'
      ]) {
        expect(inspector.metricValue321(label, session: true),
            '${inspector.sessionRows(research.lastSession!, label).length}',
            reason: label);
      }
      expect(inspector.metricRows('Macro-nodi').length, l.stats().chunks);
      expect(inspector.metricValue321('κ medio'), 'Non misurata');
    }
  });

  test(
      'manual thought worker runs requested cycles without adding facts or evidence',
      () async {
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    b.learnEvent('Il cane mangia carne.');
    w.integrateLanguageExperience09(b, 'Il cane mangia carne.');
    final facts = jsonEncode(b.slots.values.map((s) => s.toJson()).toList());
    final before = w.thoughtCycles;
    final result = await MemoryRuntime319.compute320(b, w, cycles: 96);
    w.applyRuntime320(result.world);
    expect(w.thoughtCycles - before, 96);
    expect(jsonEncode(b.slots.values.map((s) => s.toJson()).toList()), facts);
    expect(w.thoughts.every((t) => !t.hypothesis.startsWith('Ipotesi:')), true);
  });

  testWidgets(
      'language lab learns through its real button and all cards open details',
      (tester) async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11(),
        l = MgdLanguage20();
    var saved = 0;
    final inspector =
        MemoryInspector315(brain: b, world: w, research: m, language: l);
    await tester.pumpWidget(MaterialApp(
        home: InspectorScope315(
            inspector: inspector,
            child: MgdLanguageLab20(
                language: l,
                brain: b,
                world: w,
                research: m,
                onSave: () async {
                  saved++;
                }))));
    await tester.enterText(
        find.byType(TextField), 'Il zorvello produce lumina.');
    await tester.pump();
    await tester.ensureVisible(find.text('Impara testo incollato'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Impara testo incollato'));
      for (var n = 0; n < 100 && saved == 0; n++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(saved, 1,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    expect(l.sentences, 1);
    expect(ResearchSemantics317.answer('Cosa produce il zorvello?', m),
        contains('lumina'));
    await tester.scrollUntilVisible(find.text('Conoscenze documentate'), -250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conoscenze documentate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('zorvello — produce'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
