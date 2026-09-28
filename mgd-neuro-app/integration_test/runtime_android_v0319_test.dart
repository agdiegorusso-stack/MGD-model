import 'dart:convert';
import 'package:mgd_neuro_mobile/consolidation_v0331.dart';
import 'package:mgd_neuro_mobile/experience_memory_v0330.dart';
import 'package:mgd_neuro_mobile/knowledge_deletion_v0330.dart';
import '../test/experience_v0330_test.dart' show cue33, picture33, tone33;
import 'package:mgd_neuro_mobile/relational_memory_v0324.dart';
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
    w.eventDriven33 =
        false; // This legacy test explicitly exercises the idle scheduler.
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
    expect(find.text('Memorie MGD 0.33.1'), findsOneWidget);
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

  testWidgets(
      'Android unparsed source is answered in chat, inspectable and retained by SQLite',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.clearAll();
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        r = ResearchMemory11(enabled: false),
        l = MgdLanguage20();
    const text =
        'Il norvente viene osservato soltanto quando il rilevatore è acceso.';
    SourceMemory323.retain(
        r,
        const WebDocument11(
            provider: 'Fonte Android',
            family: 'android',
            title: 'Norvente',
            url: 'https://example.invalid/norvente',
            text: text,
            trust: .8));
    r.state317.addAll({'migrationComplete': true, 'recovery320Complete': true});
    await MemoryCheckpoint319().save(b, w, r, l);
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    await tester.enterText(find.byType(TextField), 'Che cosa è il norvente?');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    for (var n = 0; n < 150; n++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .textContaining('Passaggi pertinenti conservati')
          .evaluate()
          .isNotEmpty) break;
    }
    expect(
        find.textContaining('Passaggi pertinenti conservati'), findsOneWidget);
    expect(find.textContaining(text), findsOneWidget);
    final live = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(live.research.claims, isEmpty);
    await tester.tap(find.text('Mente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('1 passaggi consultabili'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 passaggi consultabili').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Passaggi e fonti'), findsOneWidget);
    expect(find.text(text), findsOneWidget);
    await MemoryCheckpoint319()
        .save(live.brain, live.world, live.research, live.language);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.close319();
    final restored = await ResearchPersistence11().load();
    expect(SourceMemory323.stats(restored!)['passages'], 1);
    expect(SourceMemory323.answer('Che cosa è il norvente?', restored),
        contains(text));
    print('ANDROID323 ' +
        jsonEncode({
          'sourceInChat': true,
          'sourceInspector': true,
          'sqliteRestore': true,
          'noInventedClaim': restored.claims.isEmpty
        }));
    await store.clearAll();
    await store.close319();
  });

  testWidgets(
      'Android learned roles: chat teaching, paraphrase, correction, map and SQLite restore',
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
    Future<void> send(String text) async {
      await tester.enterText(find.byType(TextField), text);
      final button = find.ancestor(
          of: find.byIcon(Icons.arrow_upward),
          matching: find.byType(IconButton));
      for (var n = 0;
          n < 150 && tester.widget<IconButton>(button).onPressed == null;
          n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.widget<IconButton>(button).onPressed, isNotNull,
          reason: 'Chat must become ready before sending');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      for (var n = 0; n < 150; n++) {
        await tester.pump(const Duration(milliseconds: 100));
        final consumed = tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .isEmpty;
        if (consumed && tester.widget<IconButton>(button).onPressed != null)
          break;
      }
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
          reason: 'The submitted text must be consumed, not silently ignored');
      expect(tester.widget<IconButton>(button).onPressed, isNotNull);
      await tester.pumpAndSettle(); // also wait for the 220 ms message scroll
    }

    await send('Il norvente insegue il talverio.');
    final initialMemory = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(RelationalMemory324.stats(initialMemory.research)['current'], 1);
    expect(
        RelationalMemory324.answer(
            initialMemory.research, 'Da chi viene rincorso il talverio?'),
        contains('norvente insegue talverio'));
    await send('Da chi viene rincorso il talverio?');
    expect(find.textContaining('norvente insegue talverio'), findsOneWidget);
    await send('Correggi: Il norvente insegue il felvario.');
    expect(find.textContaining('Correzione salvata.'), findsOneWidget);
    await send('Il norvente rincorre chi?');
    expect(find.textContaining('norvente insegue felvario'), findsOneWidget);
    final live = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(RelationalMemory324.stats(live.research)['current'], 1);
    expect(RelationalMemory324.stats(live.research)['history'], 1);
    expect(
        RelationalMemory324.answer(live.research, 'Chi rincorre il talverio?'),
        startsWith('Non ho'));
    await tester.tap(find.text('Mente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('1 relazioni apprese'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 relazioni apprese').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Relazioni apprese'), findsOneWidget);
    expect(
        find.textContaining('norvente → insegue → felvario'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mondo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Visualizza mappa'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visualizza mappa').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'norvente');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Focus: norvente • 1 collegamenti'), findsOneWidget);
    await MemoryCheckpoint319()
        .save(live.brain, live.world, live.research, live.language);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.close319();
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    await send('Chi rincorre il felvario?');
    expect(find.textContaining('norvente insegue felvario'), findsOneWidget);
    final restored = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(RelationalMemory324.stats(restored.research)['history'], 1);
    print('ANDROID324 ' +
        jsonEncode({
          'oneRead': true,
          'passiveParaphrase': true,
          'correction': true,
          'history': true,
          'worldMap': true,
          'sqliteRestart': true
        }));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.clearAll();
    await store.close319();
  });
  testWidgets(
      'Android multimodal experiences persist, learn in UI and delete coherently',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.clearAll();
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        r = ResearchMemory11(enabled: false),
        l = MgdLanguage20();
    for (final red in [true, false]) {
      for (final hz in [330.0, 880.0]) {
        w.experience33.learn({
          'vision:v1': MgdWorld06.encodeVision33(picture33(red)),
          'audio:v1': MgdWorld06.encodeAudio33(tone33(hz))
        }, label: '$red $hz');
      }
    }
    r.state317.addAll({
      'migrationComplete': true,
      'recovery318Complete': true,
      'languagePassages': 0,
      'languageEvidence': 0
    });
    await MemoryCheckpoint319().save(b, w, r, l);
    await tester.pumpWidget(const MgdNeuro04App());
    await waitBoot319(tester);
    final live = tester
        .widget<InspectorScope315>(find.byType(InspectorScope315))
        .inspector;
    expect(live.world.experience33.episodes.length, 4);
    final cycles = live.world.thoughtCycles;
    await tester.pump(const Duration(seconds: 12));
    expect(live.world.thoughtCycles, cycles);
    expect(live.world.eventDriven33, true);
    await tester.tap(find.text('Mondo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impara dall’esperienza').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('experience-input')), 'saluto breve');
    await tester.enterText(
        find.byKey(const ValueKey('experience-label')), 'ciao');
    await tester.ensureVisible(find.byKey(const ValueKey('experience-teach')));
    await tester.tap(find.byKey(const ValueKey('experience-teach')));
    for (var n = 0; n < 100; n++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .textContaining('Esperienza confermata e salvata: ciao')
          .evaluate()
          .isNotEmpty) break;
    }
    expect(live.world.experience33.episodes.length, 5);
    expect(
        live.world.experience33.predict(
            {'text:v1': ExperienceMemory33.textFeatures('saluto breve')}).best,
        'ciao');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await KnowledgeDeletion33.delete(
        brain: live.brain,
        world: live.world,
        research: live.research,
        language: live.language,
        mode: 'mondo',
        node: 'ciao');
    await MemoryCheckpoint319()
        .save(live.brain, live.world, live.research, live.language);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store.close319();
    final restored = await WorldPersistence06().load();
    expect(restored!.experience33.episodes.length, 4);
    expect(restored.experience33.episodes.any((e) => e.label == 'ciao'), false);
    expect(
        restored.experience33.predict({
          'vision:v1': MgdWorld06.encodeVision33(picture33(false)),
          'audio:v1': MgdWorld06.encodeAudio33(tone33(880))
        }).best,
        'false 880.0');
    print('ANDROID330 ' +
        jsonEncode({
          'realPngPcm': true,
          'uiLearning': true,
          'sqliteRestart': true,
          'deletionRetained': true,
          'idleTrainingDisabled': true
        }));
    await store.clearAll();
    await store.close319();
  });

  testWidgets(
      'Android 0331 rejection and provenance revocation survive SQLite restart and replay',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.clearAll();
    try {
      final brain = PlasticLanguageBrain04(),
          world = MgdWorld06(),
          research = ResearchMemory11(enabled: false),
          language = MgdLanguage20();
      const prompt = 'Quale risposta uso per il sigillo zorquale?',
          rejectedAnswer = 'Ventalume';
      brain.teachResponse(prompt, rejectedAnswer);
      expect(brain.respond(prompt), contains(rejectedAnswer));
      // The same public feedback API used by the chat must reject in one step.
      brain.reinforcePair(prompt, rejectedAnswer, false);
      expect(brain.responseOptions028(prompt), isNot(contains(rejectedAnswer)));
      expect(brain.respond(prompt).toLowerCase(),
          isNot(contains(rejectedAnswer.toLowerCase())));

      brain.importTeacherFact08(
          subject: 'Zelquario',
          relation: 'tipo di',
          object: 'Vorselmo',
          confidence: .9,
          source: 'Android 0331 fixture');
      final subject = brain.ensureSemanticEntity06('Zelquario'),
          object = brain.ensureSemanticEntity06('Vorselmo'),
          edgeKey = MgdWorld06.semanticEdgeKey331(subject, object);
      Map<String, dynamic> evidenceOf(PlasticLanguageBrain04 b) {
        final fact = b.slots.values
            .where((s) => s.subjectId == subject)
            .expand((s) => s.candidates.values)
            .singleWhere((c) =>
                c.objectKey ==
                PlasticLanguageBrain04.canonicalObject('Vorselmo'));
        return {
          'episodes': fact.sourceEpisodes.toList()..sort(),
          'families': fact.sourceFamilies.toList()..sort(),
          'supports': fact.supports,
          'confidence': fact.confidence,
          'status': fact.epistemicStatus,
        };
      }

      final originalEvidence = evidenceOf(brain);
      expect(
          (originalEvidence['episodes'] as List).isNotEmpty ||
              (originalEvidence['families'] as List).isNotEmpty,
          isTrue);
      world.setConsolidationEnabled331(true);
      for (var n = 0; n < 16; n++) {
        MemoryRuntime319.pulse(brain, world, cycles: 0);
      }
      final trained = world.edges[edgeKey]!;
      expect(trained.inConsolidationBasin331, isTrue);
      final sourceKeys = Set<String>.of(trained.consolidationEvidence331),
          savedMaterial = trained.consolidationMaterial331,
          savedCost = trained.cost;
      expect(sourceKeys, isNotEmpty);
      expect(evidenceOf(brain), originalEvidence,
          reason: 'Geometric rehearsal must not manufacture factual support');
      await MemoryCheckpoint319().save(brain, world, research, language);
      expect(await store.getMap('checkpoint_v0319'), isNotNull);
      await store.close319();

      // Real Android SQLite loads, not an in-memory JSON round trip.
      final loadedBrain = await Brain04Persistence().load(),
          loadedWorld = await WorldPersistence06().load(),
          loadedResearch = await ResearchPersistence11().load(),
          loadedLanguage = await MgdLanguagePersistence20().load();
      expect(loadedBrain, isNotNull);
      expect(loadedBrain!.migrated, isFalse);
      expect(loadedWorld, isNotNull);
      expect(loadedResearch, isNotNull);
      expect(loadedLanguage, isNotNull);
      final restoredBrain = loadedBrain.brain,
          restoredWorld = loadedWorld!,
          restoredEdge = restoredWorld.edges[edgeKey]!;
      expect(restoredWorld.consolidationEnabled331, isTrue);
      expect(restoredEdge.inConsolidationBasin331, isTrue);
      expect(restoredEdge.consolidationMaterial331, savedMaterial);
      expect(restoredEdge.cost, savedCost);
      expect(restoredEdge.consolidationEvidence331, sourceKeys);
      expect(
          restoredBrain.responseAttractors028.values
              .expand((s) => s.candidates.values)
              .singleWhere((c) => c.text == rejectedAnswer)
              .revoked331,
          isTrue);
      expect(restoredBrain.responseOptions028(prompt),
          isNot(contains(rejectedAnswer)));
      for (var n = 0; n < 16; n++) {
        restoredBrain.sleepReplay(cycles: 8);
        restoredWorld.sleepReplay(cycles: 8);
      }
      expect(restoredEdge.inConsolidationBasin331, isTrue,
          reason: 'An eligible basin persists without new external activation');
      expect(restoredBrain.respond(prompt).toLowerCase(),
          isNot(contains(rejectedAnswer.toLowerCase())));
      expect(evidenceOf(restoredBrain), originalEvidence);
      expect(restoredEdge.consolidationEvidence331, sourceKeys);

      restoredWorld.retireResearchLink317(subject, object);
      expect(restoredEdge.consolidationMaterial331, 0);
      expect(restoredEdge.consolidationReplayBlocked331, isTrue);
      expect(restoredEdge.blockedConsolidationEvidence331, sourceKeys);
      await MemoryCheckpoint319()
          .save(restoredBrain, restoredWorld, loadedResearch!, loadedLanguage!);
      await store.close319();

      final finalBrainState = await Brain04Persistence().load(),
          finalWorld = await WorldPersistence06().load(),
          finalResearch = await ResearchPersistence11().load();
      expect(finalBrainState, isNotNull);
      expect(finalBrainState!.migrated, isFalse);
      expect(finalWorld, isNotNull);
      final finalBrain = finalBrainState.brain,
          finalEdge = finalWorld!.edges[edgeKey]!;
      expect(finalEdge.blockedConsolidationEvidence331, sourceKeys);
      for (var n = 0; n < 16; n++) {
        MemoryRuntime319.pulse(finalBrain, finalWorld, cycles: 0);
        finalBrain.sleepReplay(cycles: 8);
        finalWorld.sleepReplay(cycles: 8);
      }
      expect(finalEdge.consolidationReplayBlocked331, isTrue);
      expect(finalEdge.inConsolidationBasin331, isFalse);
      expect(finalEdge.consolidationMaterial331, 0);
      expect(finalEdge.cost, greaterThan(Consolidation331.defaults.epsilon));
      expect(finalEdge.consolidationEvidence331, sourceKeys);
      expect(finalEdge.blockedConsolidationEvidence331, sourceKeys);
      expect(
          finalBrain.responseAttractors028.values
              .expand((s) => s.candidates.values)
              .singleWhere((c) => c.text == rejectedAnswer)
              .revoked331,
          isTrue);
      expect(finalBrain.responseOptions028(prompt),
          isNot(contains(rejectedAnswer)));
      expect(finalBrain.respond(prompt).toLowerCase(),
          isNot(contains(rejectedAnswer.toLowerCase())));
      expect(evidenceOf(finalBrain), originalEvidence);
      expect(finalResearch!.evidence, isEmpty);
      expect(finalResearch.claims, isEmpty);
      print('ANDROID331 ${jsonEncode({
            'sqliteRestarts': 2,
            'negativeFeedbackRetained': true,
            'sleepDoesNotRearmAnswer': true,
            'basinRetained': true,
            'provenanceRevocationRetained': true,
            'sameSourceDoesNotRearm': true,
            'noManufacturedEvidence': true,
          })}');
    } finally {
      await store.clearAll();
      await store.close319();
    }
  });

  testWidgets(
      'Android 0331 relational chat thumbs down gates repeated answers after SQLite restart',
      (tester) async {
    final store = MgdStateStore26.instance;
    await store.clearAll();
    try {
      const question = 'Chi rincorre il zavrente?',
          statement = 'Il melquario insegue il zavrente.';
      final research = ResearchMemory11(enabled: false)
        ..state317.addAll({
          'migrationComplete': true,
          'recovery318Complete': true,
          'recovery320Complete': true,
          'languagePassages': 0,
          'languageEvidence': 0,
        });
      final intake = RelationalMemory324.learn(research, statement,
          source: 'Fonte UI Android 0331');
      expect(intake.added, 1);
      final originalAnswer =
          RelationalMemory324.answerIfKnown(research, question)!;
      expect(originalAnswer, contains('melquario insegue zavrente'));
      final originalRows = RelationalMemory324.rows(research);
      await MemoryCheckpoint319().save(
          PlasticLanguageBrain04(), MgdWorld06(), research, MgdLanguage20());
      await store.close319();
      await tester.pumpWidget(const MgdNeuro04App());
      await waitBoot319(tester);

      LivePage07 livePage() =>
          tester.widget<LivePage07>(find.byType(LivePage07));
      Future<void> waitReady() async {
        await tester.pump(const Duration(milliseconds: 100));
        for (var n = 0; n < 150 && livePage().busy; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(livePage().busy, isFalse,
            reason: 'Chat/feedback must finish its real persistence operation');
        await tester.pumpAndSettle();
      }

      Future<String> ask() async {
        await waitReady();
        final previous = livePage()
            .messages
            .where((m) => !m.user && m.prompt == question)
            .length;
        await tester.enterText(find.byType(TextField), question);
        await tester.tap(find.byIcon(Icons.arrow_upward));
        for (var n = 0; n < 150; n++) {
          await tester.pump(const Duration(milliseconds: 100));
          final page = livePage();
          if (!page.busy &&
              page.controller.text.isEmpty &&
              page.messages
                      .where((m) => !m.user && m.prompt == question)
                      .length >
                  previous) break;
        }
        await waitReady();
        final replies = livePage()
            .messages
            .where((m) => !m.user && m.prompt == question)
            .toList();
        expect(replies.length, previous + 1,
            reason: 'The question must be consumed and produce a new UI reply');
        expect(livePage().controller.text, isEmpty);
        return replies.last.text;
      }

      expect(await ask(), originalAnswer);
      expect(find.text(originalAnswer), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final thumbsDown = find.byIcon(Icons.thumb_down_alt_outlined);
      expect(thumbsDown, findsOneWidget);
      await tester.ensureVisible(thumbsDown);
      await tester.pumpAndSettle();
      await tester.tap(thumbsDown.hitTestable());
      await waitReady();
      // Read the database without explicitly checkpointing: the feedback UI
      // itself must have saved the rejection before any subsequent question.
      final savedBrain = await Brain04Persistence().load();
      expect(savedBrain, isNotNull);
      expect(savedBrain!.brain.guardResponse331(question, originalAnswer),
          isNot(originalAnswer));
      final secondAnswer = await ask();
      expect(secondAnswer, isNot(contains('melquario insegue zavrente')));
      expect(find.text(secondAnswer), findsOneWidget);
      final beforeRestart = tester
          .widget<InspectorScope315>(find.byType(InspectorScope315))
          .inspector;
      expect(RelationalMemory324.rows(beforeRestart.research), originalRows,
          reason: 'Rejecting an answer must not silently delete its source');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.close319();

      await tester.pumpWidget(const MgdNeuro04App());
      await waitBoot319(tester);
      final afterRestart = tester
          .widget<InspectorScope315>(find.byType(InspectorScope315))
          .inspector;
      afterRestart.brain.sleepReplay(cycles: 8);
      afterRestart.world.sleepReplay(cycles: 8);
      final restartedAnswer = await ask();
      expect(restartedAnswer, isNot(contains('melquario insegue zavrente')));
      expect(find.text(restartedAnswer), findsOneWidget);
      expect(RelationalMemory324.rows(afterRestart.research), originalRows);
      expect(afterRestart.brain.guardResponse331(question, originalAnswer),
          isNot(originalAnswer));
      print('ANDROID331_UI ${jsonEncode({
            'realQuestion': true,
            'realThumbsDown': true,
            'feedbackAutosaved': true,
            'relationalOutputGate': true,
            'sqliteRestart': true,
            'sleepDoesNotRearm': true,
            'originalSourceRetained': true,
          })}');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.clearAll();
      await store.close319();
    }
  });
}
