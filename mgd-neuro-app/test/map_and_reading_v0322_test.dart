import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/navigable_graph_v013.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';

WebDocument11 document(String text) => WebDocument11(
    provider: 'Wikipedia IT',
    family: 'wikimedia',
    title: 'Nucleotide',
    url: 'https://it.wikipedia.org/wiki/Nucleotide',
    text: text,
    trust: .84);

void main() {
  testWidgets(
      'chat word persists and global map search finds the isolated linguistic node',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final b = PlasticLanguageBrain04(), l = MgdLanguage20();
    b.respond('ciao');
    l.ingestText('ciao');
    expect(b.entityIdForLabel06('ciao'), isNull);
    final restored = MgdLanguage20.fromJson(jsonDecode(jsonEncode(l.toJson())));
    await tester.pumpWidget(MaterialApp(
        home: SemanticMapPage14(
            brain: b, research: ResearchMemory11(), language: restored)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'CIAO');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Focus: ciao • 0 collegamenti'), findsOneWidget);
    expect(find.textContaining('1 occorrenze'), findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Lingua'))
            .selected,
        true);
    expect(find.byKey(const ValueKey('knowledge-map-nodes')), findsOneWidget);
    expect(
        tester.getRect(find.byType(InteractiveViewer)).contains(tester
            .getCenter(find.byKey(const ValueKey('knowledge-map-nodes')))),
        true,
        reason:
            'The isolated node must be inside the visible viewport, not merely in the painter data.');
    expect(tester.takeException(), isNull);
    // No fictitious knowledge or edge was added to make the word visible.
    expect(b.entityIdForLabel06('ciao'), isNull);
    expect(restored.edges.values.where((e) => e.a == 'ciao' && e.b == 'ciao'),
        isEmpty);
  });

  testWidgets(
      'entity without any semantic edges renders on a small phone and after resize',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final b = PlasticLanguageBrain04()..ensureSemanticEntity06('Isolato');
    await tester.pumpWidget(MaterialApp(
        home: SemanticMapPage14(
            brain: b,
            research: ResearchMemory11(),
            language: MgdLanguage20())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('knowledge-map-nodes')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'isolato');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('Focus: Isolato'), findsOneWidget);
    expect(find.text('Nodo presente, senza collegamenti in questa memoria.'),
        findsOneWidget);
    tester.view.physicalSize = const Size(640, 360);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search refreshes current memory and return restores its previous layer',
      (tester) async {
    final b = PlasticLanguageBrain04(), l = MgdLanguage20();
    b.ensureSemanticEntity06('Faro');
    await tester.pumpWidget(MaterialApp(
        home: SemanticMapPage14(
            brain: b, research: ResearchMemory11(), language: l)));
    await tester.pumpAndSettle();
    l.ingestText('ciao mondo');
    await tester.enterText(find.byType(TextField), 'ciao');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Focus: ciao • 1 collegamenti'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Indietro nella mappa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Indietro nella mappa'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mondo'))
            .selected,
        true);
    expect(tester.takeException(), isNull);
  });

  test(
      'screenshot enumerations are preserved as text without an inverted is-a relation',
      () {
    for (final text in [
      "Uno zucchero pentoso è il ribosio nell'RNA e il desossiribosio nel DNA.",
      "Due dei nucleotidi più importanti dal punto di vista metabolico sono l'adenosina trifosfato (ATP) e la guanosina monofosfato ciclico (cGMP)."
    ])
      expect(ResearchSemantics317.extractAny321(text, document(text)), isEmpty,
          reason: text);
  });

  test('discipline introduction is context and not part of the entity name',
      () {
    const text =
        'In chimica, i nucleotidi sono molecole presenti in tutti gli organismi viventi.';
    final x = ResearchSemantics317.extractAny321(text, document(text)).single;
    expect(x.subject, 'nucleotidi');
    expect(x.sentence, text);
    expect(x.meta317['qualifiers']['domainContext'], 'In chimica,');
    expect(ResearchSemantics317.evaluate(x)['verdict'], 'support');
    const conditional =
        'Nel fegato, i nucleotidi sono molecole indispensabili.';
    expect(
        ResearchSemantics317.extractAny321(conditional, document(conditional)),
        isEmpty);
  });

  test(
      'legacy malformed evidence is quarantined without deleting source or user corrections',
      () {
    final m = ResearchMemory11(),
        b = PlasticLanguageBrain04(),
        w = MgdWorld06();
    final c = ResearchClaim11(
        key: 'old',
        subject: 'zucchero pentoso',
        relation: 'tipo di',
        object: "il ribosio nell'RNA e il desossiribosio nel DNA",
        confidence: .6,
        status: 'documentata',
        conflict: false,
        lastSeenIso: 'old');
    c.meta317.addAll({'extractor': 'rules317', 'engine': 317});
    final e = ResearchEvidence11(
        id: 'old-e',
        subject: c.subject,
        relation: c.relation,
        object: c.object,
        provider: 'Wikipedia IT',
        sourceFamily: 'wikimedia',
        sourceTitle: 'Nucleotide',
        sourceUrl: 'https://it.wikipedia.org/wiki/Nucleotide',
        excerpt:
            "Uno zucchero pentoso è il ribosio nell'RNA e il desossiribosio nel DNA.",
        trust: .84,
        retrievedAtIso: 'old',
        meta317: {'verdict': 'support'});
    m.evidence.add(e);
    c.evidenceIds.add(e.id);
    m.claims[c.key] = c;
    expect(ResearchSemantics317.reviewExtractions322(b, w, m), 1);
    expect(c.status, 'quarantena');
    expect(c.meta317['usable'], false);
    expect(m.evidence.single.excerpt, e.excerpt);
    expect(m.claims.length, 1);
    expect(ResearchSemantics317.reviewExtractions322(b, w, m), 0);
    expect(
        ResearchSemantics317.answer('Cosa è uno zucchero pentoso?', m), isNull);
    c.status = 'corretta_utente';
    ResearchSemantics317.reevaluate(b, w, m, c);
    expect(c.status, 'corretta_utente');
  });

  test(
      'compound research label falls back to a partial topic without claiming equivalence',
      () async {
    final calls = <Uri>[];
    final ex = WebKnowledgeExplorer11(jsonLoader318: (u) async {
      calls.add(u);
      if (u.host != 'it.wikipedia.org') return {};
      final q = u.queryParameters;
      if ((q['titles']?.split('|').contains('Bioma') ?? false) ||
          q['generator'] == 'search')
        return {
          'query': {
            'pages': [
              {
                'pageid': 1,
                'title': 'Bioma',
                'extract': 'Il bioma è una regione ecologica estesa.',
                'fullurl': 'https://it.wikipedia.org/wiki/Bioma'
              }
            ]
          }
        };
      return {};
    });
    final d = await ex.research(const ResearchGoal11(
        query: 'Bioma o grande sistema ecologico Tundra Taiga',
        topic: 'Bioma o grande sistema ecologico',
        reason: 'screenshot',
        value: 1));
    expect(d.documents.length, 1);
    expect(d.documents.single.meta318['partialTopic322'], 'Bioma');
    expect(d.documents.single.meta318['resolvedTopic'], false);
    expect(
        d.diagnostics318.any((x) => x['status'] == 'argomento parziale'), true);
    expect(d.claims.single.subject, 'Bioma');
    expect(d.claims.single.meta317['queryAliases318'] ?? [],
        isNot(contains('Bioma o grande sistema ecologico')));
    expect(
        calls.where((u) =>
            (u.queryParameters['titles']?.split('|').contains('Bioma') ??
                false)),
        isNotEmpty);
  });
  testWidgets(
      'documented relation is in Mondo and moves to review after quarantine',
      (tester) async {
    final m = ResearchMemory11();
    final c = ResearchClaim11(
        key: 'source',
        subject: 'Talverio',
        relation: 'tipo di',
        object: 'Molecola',
        confidence: .6,
        status: 'documentata',
        conflict: false,
        lastSeenIso: 'now');
    m.claims[c.key] = c;
    await tester.pumpWidget(MaterialApp(
        home: SemanticMapPage14(
            brain: PlasticLanguageBrain04(),
            research: m,
            language: MgdLanguage20())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Talverio');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mondo'))
            .selected,
        true);
    expect(find.text('con fonte: tipo di → Molecola'), findsOneWidget);
    c.status = 'quarantena';
    c.confidence = .25;
    await tester.tap(find.byTooltip('Cerca'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Da verificare'))
            .selected,
        true);
    expect(find.text('con fonte: tipo di → Molecola'), findsNothing);
    expect(m.claims.length, 1);
    expect(tester.takeException(), isNull);
  });
}
