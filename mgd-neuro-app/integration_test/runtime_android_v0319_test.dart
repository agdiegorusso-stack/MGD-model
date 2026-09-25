import 'dart:convert';
import '../test/research_v0318_test.dart' show Sources318;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mgd_neuro_mobile/main.dart';
import 'package:mgd_neuro_mobile/memory_runtime_v0319.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/mgd_state_store_v026.dart';
import 'package:mgd_neuro_mobile/knowledge_inspector_v0315.dart';
import 'package:mgd_neuro_mobile/world_persistence_v06.dart';
import 'package:mgd_neuro_mobile/persistence.dart';
import 'package:mgd_neuro_mobile/research_persistence_v11.dart';
import 'package:mgd_neuro_mobile/reasoning_v0321.dart';

Future<void> waitBoot319(WidgetTester tester) async {
  for (var n = 0; n < 150; n++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.byType(InspectorScope315).evaluate().isNotEmpty) return;
  }
  fail('Application did not expose its loaded memory within 30s');
}

Future<void> searchCiao322(WidgetTester tester) async {
  await tester.tap(find.text('Mondo'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Visualizza mappa'), 300,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Visualizza mappa').hitTestable());
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'ciao');
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
  expect(find.text('Focus: ciao • 0 collegamenti'), findsOneWidget);
  expect(find.byKey(const ValueKey('knowledge-map-nodes')), findsOneWidget);
  expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Lingua'))
          .selected,
      true);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android SQLite restart retains learned answers and UI, then blocks corrupt world',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.clearAll();
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        r = ResearchMemory11(enabled: false),
        l = MgdLanguage20();
    for (var n = 0; n < 96; n++) {
      final s = 'Entità numero $n', o = 'Categoria ${n % 4}';
      b.importTeacherFact08(
          subject: s,
          relation: 'tipo di',
          object: o,
          confidence: .85,
          source: 'Android fixture');
      w.importTeacherSemanticLink08(
          b.ensureSemanticEntity06(s), b.ensureSemanticEntity06(o), .55,
          confidence: .6);
    }
    const doc = WebDocument11(
        provider: 'Fonte test',
        family: 'test',
        title: 'Nucleotide',
        url: 'https://example.invalid/nucleotide',
        text: 'Il nucleotide è una molecola.',
        trust: .9);
    WebKnowledgeExplorer11().integrate(
        b,
        w,
        r,
        const ResearchDraft11(
            goal: ResearchGoal11(
                query: 'Nucleotide',
                topic: 'Nucleotide',
                reason: 'fixture',
                value: 1),
            documents: [doc],
            claims: [
              ExtractedClaim11(
                  subject: 'Nucleotide',
                  relation: 'tipo di',
                  object: 'molecola',
                  sentence: 'Il nucleotide è una molecola.',
                  source: doc,
                  quality: .9)
            ],
            passages: [],
            sentencesRead: 1));
    while (ResearchSemantics317.getPending(r) > 0)
      ResearchSemantics317.processQueue(b, w, r);
    final online = WebKnowledgeExplorer11(jsonLoader318: Sources318().call);
    final draft = await online.research(const ResearchGoal11(
        query: 'Organismi Tassonomia Animali Piante',
        topic: 'Organismi',
        contextTerms: ['Tassonomia', 'Animali', 'Piante'],
        reason: 'Android context regression',
        value: 1));
    online.integrate(b, w, r, draft);
    while (ResearchSemantics317.getPending(r) > 0)
      ResearchSemantics317.processQueue(b, w, r);
    expect(
        ResearchSemantics317.answer('Cosa sono gli organismi?', r), isNotNull);
    for (final d in draft.documents) await l.ingestWeb317(d);
    r.state317.addAll({
      'migrationComplete': true,
      'recovery318Complete': true,
      'languagePassages': r.passages.length,
      'languageEvidence': r.evidence.length
    });
    l.ingestText(
        'Il nucleotide è una molecola. La cellula contiene informazioni.');
    r.narrativeLinks.add(NarrativeLink24(
        episodeId: 'e24:fixture',
        from: 'nucleotide',
        relation: 'co-presente',
        to: 'molecola',
        confidence: .5,
        source: 'Android fixture'));
    for (var n = 0; n < 6; n++) MemoryRuntime319.pulse(b, w);
    final initialCycles = w.thoughtCycles,
        initialEdges = w.edges.length,
        initialAge = w.entropicAge,
        initialFacts = b.cognitiveFacts06().length;
    final answer = ResearchSemantics317.answer('Che cosa è un nucleotide?', r);
    expect(answer, contains('Documentata da una fonte'));
    await MemoryCheckpoint319().save(b, w, r, l);
    await store.close319();
    final rb = await Brain04Persistence().load(),
        rw = await WorldPersistence06().load(),
        rr = await ResearchPersistence11().load(),
        rl = await MgdLanguagePersistence20().load();
    expect(rb!.brain.cognitiveFacts06().length, initialFacts);
    expect(rw!.thoughtCycles, initialCycles);
    expect(rw.edges.length, initialEdges);
    expect(rw.entropicAge, initialAge);
    expect(rr!.evidence.length, r.evidence.length);
    expect(
        ResearchSemantics317.answer('Che cosa è un nucleotide?', rr), answer);
    expect(rl!.sentences, l.sentences);
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    await tester.tap(find.text('Mente'));
    await tester.pumpAndSettle();
    expect(find.text('Memorie MGD 0.32.3'), findsOneWidget);
    final live = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(live.world.thoughtCycles, greaterThanOrEqualTo(initialCycles));
    expect(live.brain.cognitiveFacts06().length, initialFacts);
    // Exercise actual scheduler while a read-only inspector is open.
    await tester.tap(find.text('Esplora tutta la memoria'));
    await tester.pumpAndSettle();
    final cyclesBefore = live.world.thoughtCycles;
    await tester.pump(const Duration(seconds: 12));
    for (var n = 0; n < 100 && live.world.thoughtCycles <= cyclesBefore; n++)
      await tester.pump(const Duration(milliseconds: 200));
    expect(live.world.thoughtCycles, greaterThan(cyclesBefore));
    expect(live.research.evidence.length, r.evidence.length);
    await tester.pageBack();
    await tester.pumpAndSettle();
    // A fresh widget instance loads the same persisted world, not a new empty one.
    await MemoryCheckpoint319()
        .save(live.brain, live.world, live.research, live.language);
    final savedCycles = live.world.thoughtCycles,
        savedAge = live.world.entropicAge;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.close319();
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    final second = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(second.world.thoughtCycles, greaterThanOrEqualTo(savedCycles));
    expect(second.world.entropicAge, greaterThanOrEqualTo(savedAge));
    expect(
        ResearchSemantics317.answer(
            'Che cosa è un nucleotide?', second.research),
        answer);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final malformed = {'edges': 'INVALID_TEST_PAYLOAD', 'thoughtCycles': 999};
    await store.putMap('world_v06', malformed);
    await tester.pumpWidget(const MgdNeuro04App());
    for (var n = 0;
        n < 150 &&
            find
                .text('Memoria protetta: caricamento non riuscito')
                .evaluate()
                .isEmpty;
        n++) await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Memoria protetta: caricamento non riuscito'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    expect(await store.getMap('world_v06'), malformed);
    expect((await store.getMap('brain_v051'))!['episodes'], isNotEmpty);
    print('ANDROID319 ${jsonEncode({
          'facts': initialFacts,
          'worldEdges': initialEdges,
          'cyclesRestored': savedCycles,
          'ageRestored': savedAge,
          'evidence': r.evidence.length,
          'restart': true,
          'corruptionProtected': true,
          'sourcedAnswer': answer
        })}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.clearAll();
    await store.close319();
  });
  testWidgets(
      'Android real learning button, deduction in chat and cold restore',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.clearAll();
    await MemoryCheckpoint319().save(
        PlasticLanguageBrain04(),
        MgdWorld06(),
        ResearchMemory11(enabled: false)
          ..state317
              .addAll({'migrationComplete': true, 'recovery320Complete': true}),
        MgdLanguage20());
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    await tester.tap(find.text('Mente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Impara / esplora lingua'), 300,
        scrollable: find.byType(Scrollable).first);
    // ensureVisible can jump the scroll position; the live Android binding
    // must lay out the following frame before a tap uses the new coordinates.
    await tester.pumpAndSettle();
    expect(find.text('Impara / esplora lingua').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Impara / esplora lingua').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField),
        'Il talverio è una sottoclasse di lorvante. Il lorvante è una sottoclasse di zermante.');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Impara testo incollato'));
    await tester.pumpAndSettle();
    expect(find.text('Impara testo incollato').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Impara testo incollato').hitTestable());
    for (var n = 0; n < 150; n++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find
          .textContaining('nuove utilizzabili con fonte')
          .evaluate()
          .isNotEmpty) break;
    }
    expect(
        find.textContaining('2 nuove utilizzabili con fonte'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vivi'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Cosa puoi dedurre sul talverio?');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    for (var n = 0; n < 150; n++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('Deduzione condizionata').evaluate().isNotEmpty)
        break;
    }
    expect(find.textContaining('Premesse:'), findsOneWidget);
    final before = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    final answer =
        Reasoning321.answer('Cosa puoi dedurre sul talverio?', before.research);
    await MemoryCheckpoint319()
        .save(before.brain, before.world, before.research, before.language);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.close319();
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    final after = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(
        Reasoning321.answer('Cosa puoi dedurre sul talverio?', after.research),
        answer);
    expect(after.research.lastSession!.sentencesRead, 2);
    expect(after.metricRows('Documentate').length, 2);
    print('ANDROID321 ${jsonEncode({
          'learnedFromButton': true,
          'chatDeduction': true,
          'restart': true,
          'sentences': after.research.lastSession!.sentencesRead,
          'documented': after.metricRows('Documentate').length
        })}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.clearAll();
    await store.close319();
  });

  testWidgets(
      'Android chat word appears in map before and after SQLite restore',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.clearAll();
    await MemoryCheckpoint319().save(
        PlasticLanguageBrain04(),
        MgdWorld06(),
        ResearchMemory11(enabled: false)
          ..state317
              .addAll({'migrationComplete': true, 'recovery320Complete': true}),
        MgdLanguage20());
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    await tester.enterText(find.byType(TextField), 'ciao');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    for (var n = 0; n < 150; n++) {
      await tester.pump(const Duration(milliseconds: 100));
      final send = find.ancestor(
          of: find.byIcon(Icons.arrow_upward),
          matching: find.byType(IconButton));
      if (send.evaluate().isNotEmpty &&
          tester.widget<IconButton>(send).onPressed != null) break;
    }
    final before = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(before.language.tokenCount['ciao'], 1);
    await searchCiao322(tester);
    await MemoryCheckpoint319()
        .save(before.brain, before.world, before.research, before.language);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.close319();
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    await searchCiao322(tester);
    print('ANDROID322 ${jsonEncode({
          'chatWord': 'ciao',
          'foundInLanguageMap': true,
          'isolatedNodeVisible': true,
          'restart': true
        })}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.clearAll();
    await store.close319();
  });

  testWidgets('Android unparsed source is answered in chat, inspectable and retained by SQLite', (tester) async {
    final store=MgdStateStore26.instance;
    await store.clearAll();
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),
      r=ResearchMemory11(enabled:false),l=MgdLanguage20();
    const text='Il norvente viene osservato soltanto quando il rilevatore è acceso.';
    SourceMemory323.retain(r,const WebDocument11(provider:'Fonte Android',
      family:'android',title:'Norvente',url:'https://example.invalid/norvente',
      text:text,trust:.8));
    r.state317.addAll({'migrationComplete':true,'recovery320Complete':true});
    await MemoryCheckpoint319().save(b,w,r,l);
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    await tester.enterText(find.byType(TextField),'Che cosa è il norvente?');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    for(var n=0;n<150;n++) {
      await tester.pump(const Duration(milliseconds:100));
      if(find.textContaining('Passaggi pertinenti conservati').evaluate().isNotEmpty) break;
    }
    expect(find.textContaining('Passaggi pertinenti conservati'),findsOneWidget);
    expect(find.textContaining(text),findsOneWidget);
    final live=tester.widget<InspectorScope315>(find.byType(InspectorScope315)).inspector;
    expect(live.research.claims,isEmpty);
    await tester.tap(find.text('Mente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('1 passaggi consultabili'),250,
      scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 passaggi consultabili').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Passaggi e fonti'),findsOneWidget);
    expect(find.text(text),findsOneWidget);
    await MemoryCheckpoint319().save(live.brain,live.world,live.research,live.language);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle(); await store.close319();
    final restored=await ResearchPersistence11().load();
    expect(SourceMemory323.stats(restored!)['passages'],1);
    expect(SourceMemory323.answer('Che cosa è il norvente?',restored),contains(text));
    print('ANDROID323 '+jsonEncode({'sourceInChat':true,'sourceInspector':true,
      'sqliteRestore':true,'noInventedClaim':restored.claims.isEmpty}));
    await store.clearAll(); await store.close319();
  });
}
