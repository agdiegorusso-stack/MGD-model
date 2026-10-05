import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/native_mgd_engine_v09.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/memory_runtime_v0319.dart';
import 'research_v0318_test.dart' show Sources318;
import 'runtime_v0319_test.dart' show fixture319;

WebDocument11 source320(String text,
        {String family = 'external',
        String url = 'https://independent.example/source',
        String title = 'Organismo vivente',
        double trust = .86,
        Map<String, dynamic> meta = const {}}) =>
    WebDocument11(
        provider: 'Source',
        family: family,
        title: title,
        url: url,
        text: text,
        trust: trust,
        meta318: meta);
void drain320(PlasticLanguageBrain04 b, MgdWorld06 w, ResearchMemory11 m) {
  for (var i = 0; i < 1000 && ResearchSemantics317.getPending(m) > 0; i++) {
    ResearchSemantics317.processQueue(b, w, m);
  }
  expect(ResearchSemantics317.getPending(m), 0);
}

void main() {
  test('equilibrium solves the actual logistic recursion across its domain',
      () {
    for (final rho in [.8, .92, .965])
      for (final xi in [0.0, .01, .03, .06])
        for (var i = 0; i <= 100; i++) {
          final q = i / 100, p = MgdParameters09(rho: rho, xi: xi);
          final m = MgdMath09.equilibriumMaterial(q, p: p);
          expect(rho * m + (1 - rho) * q + xi * m * (1 - m), closeTo(m, 1e-12));
          expect(m, inInclusiveRange(0, 1));
        }
    expect(MgdMath09.equilibriumMaterial(.5), closeTo(2 / 3, 1e-12));
  });
  test(
      'curvature uses shortest metric distance and admits values below minus one',
      () {
    final graph = <String, Map<String, double>>{};
    void edge(String a, String b, double w) {
      graph.putIfAbsent(a, () => {})[b] = w;
      graph.putIfAbsent(b, () => {})[a] = w;
    }

    edge('a', 'b', .1);
    for (var i = 0; i < 5; i++) {
      edge('a', 'l$i', 1);
      edge('b', 'r$i', 1);
    }
    final k = MgdMath09.ollivierRicci(
        a: 'a', b: 'b', edgeWeight: .1, activeAdjacency: graph);
    expect(k, lessThan(-1));
    edge('a', 'x', .01);
    edge('x', 'b', .01);
    final actual = MgdMath09.ollivierRicci(
        a: 'a', b: 'b', edgeWeight: .1, activeAdjacency: graph);
    final denominatorInvariant = MgdMath09.ollivierRicci(
        a: 'a', b: 'b', edgeWeight: .02, activeAdjacency: graph);
    expect(actual, closeTo(denominatorInvariant, 1e-8));
  });
  test('actual Organismi context does not remove resolved Wikipedia or QID',
      () async {
    final ex = WebKnowledgeExplorer11(jsonLoader318: Sources318().call);
    final d = await ex.research(const ResearchGoal11(
        query:
            'Organismi Tassonomia Animali Piante definizione caratteristiche',
        topic: 'Organismi',
        contextTerms: ['Tassonomia', 'Animali', 'Piante'],
        reason: 'phone regression',
        value: 1));
    expect(d.documents.any((x) => x.meta318['resolvedTopic'] == true), true);
    expect(d.claims.any((x) => x.subjectSenseKey == 'wikidata:Q7239'), true);
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    ex.integrate(b, w, m, d);
    drain320(b, w, m);
    expect(m.claims.values.where((x) => x.status == 'documentata'), isNotEmpty);
    expect(
        ResearchSemantics317.answer('Cosa sono gli organismi?', m), isNotNull);
  });
  test(
      'context-only clinical taxonomy is rejected without substring conflation',
      () {
    const goal = ResearchGoal11(
        query: 'Organismi Tassonomia',
        topic: 'Organismi',
        contextTerms: ['Tassonomia', 'Animali', 'Piante'],
        reason: 'test',
        value: 1);
    expect(
        WebKnowledgeExplorer11.documentMatches320(
            goal,
            source320('Tassonomia e definizione dei registri clinici.',
                title: 'Registri clinici')),
        false);
    expect(
        WebKnowledgeExplorer11.documentMatches320(
            goal,
            source320('I microrganismi simbionti di piante e animali.',
                title: 'Microrganismi')),
        false);
  });
  test('compound singular search also requests plural title', () {
    expect(ResearchSemantics317.queryForms318('Amminoacido proteinogenico'),
        contains('amminoacidi proteinogenici'));
  });
  test('parentheses remain qualified evidence instead of being discarded', () {
    final d = source320('Il nucleotide è una molecola (con una base azotata).',
        title: 'Nucleotide');
    final x = ResearchSemantics317.extract('nucleotide', d.text, d).single;
    expect(x.object, contains('(con una base azotata)'));
    expect(x.meta317['qualifiers'], isNotEmpty);
    expect(ResearchSemantics317.evaluate(x)['verdict'], 'support');
  });
  test(
      'identified prose corroborates the same proposition without duplicate claims',
      () {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11(),
        ex = WebKnowledgeExplorer11();
    final wiki = WebDocument11(
        provider: 'Wikipedia IT',
        family: 'wikimedia',
        title: 'Organismo vivente',
        url: 'https://it.wikipedia.org/wiki/Organismo',
        text: 'Un organismo vivente è costituito da cellule.',
        trust: .84,
        meta318: {
          'wikidataId': 'Q7239',
          'resolvedTopic': true,
          'requestedTopic': 'Organismi'
        });
    final other = source320('Un organismo vivente è costituito da cellule.');
    ex.integrate(
        b,
        w,
        m,
        ResearchDraft11(
            goal: const ResearchGoal11(
                query: 'Organismi',
                topic: 'Organismi',
                reason: 'test',
                value: 1),
            documents: [wiki, other],
            claims: ResearchSemantics317.extractDocument318(
                'Organismi', wiki.text, wiki),
            passages: [],
            sentencesRead: 1));
    // External documents can use the resolved canonical subject, not just the query alias.
    ResearchSemantics317.enqueue(m, [other],
        topic: 'Organismo vivente', session: 'external');
    drain320(b, w, m);
    final c = m.claims.values
        .where((c) =>
            c.subjectSenseKey == 'wikidata:Q7239' && c.relation == 'ha parte')
        .single;
    expect(c.status, 'accettata');
    expect(c.sourceFamilies.length, 2);
    expect(m.claims.values.where((c) => c.relation == 'ha parte').length, 1);
    final n = m.evidence.length;
    ResearchSemantics317.enqueue(m, [other],
        topic: 'Organismo vivente', session: 'repeat');
    drain320(b, w, m);
    expect(m.evidence.length, n);
    final neg = source320('Un organismo vivente non è costituito da cellule.',
        url: 'https://third.example/contrary', family: 'third');
    ResearchSemantics317.enqueue(m, [neg],
        topic: 'Organismo vivente', session: 'negative');
    drain320(b, w, m);
    expect(c.status, 'quarantena');
    expect(c.meta317['usable'], false);
  });
  test('homonymous identity is not inferred from one matching relation', () {
    final m = ResearchMemory11();
    for (final id in ['Q1', 'Q2'])
      m.claims[id] = ResearchClaim11(
          key: id,
          subject: 'Mercurio',
          relation: 'tipo di',
          object: 'pianeta',
          confidence: .6,
          conflict: false,
          status: 'documentata',
          lastSeenIso: '',
          subjectSenseKey: 'wikidata:$id');
    final d = source320('Mercurio è un pianeta.', title: 'Mercurio');
    final x = ResearchSemantics317.extract('Mercurio', d.text, d).single;
    expect(ResearchSemantics317.alignIdentity320(x, m).subjectSenseKey, isNull);
  });
  test('sleep retains original source trust and identity through serialization',
      () {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        m = ResearchMemory11();
    m.passages.add(ResearchPassage11(
        id: 'p',
        topic: 'Organismi',
        provider: 'Wikipedia IT',
        sourceFamily: 'wikimedia',
        sourceTitle: 'Organismo vivente',
        sourceUrl: 'https://it.wikipedia.org/wiki/Organismo',
        text: 'Un organismo vivente è costituito da cellule.',
        trust: .84,
        meta318: {'wikidataId': 'Q7239', 'resolvedTopic': true}));
    final restored =
        ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(WebKnowledgeExplorer11().reprocessDuringSleep(b, w, restored),
        greaterThan(0));
    expect(restored.claims.values.single.status, 'documentata');
    expect(restored.evidence.single.trust, .84);
    expect(restored.claims.values.single.subjectSenseKey, 'wikidata:Q7239');
    expect(restored.passages.single.structured, true);
  });
  test('language content tracking survives trimming at identical list length',
      () {
    final m = ResearchMemory11();
    ResearchPassage11 passage(String id) => ResearchPassage11(
        id: id,
        topic: 'test',
        provider: 'source',
        sourceFamily: 'f',
        sourceTitle: 't',
        sourceUrl: 'https://source.example/$id',
        text: 'La frase $id è una osservazione.');
    m.passages.add(passage('old'));
    ResearchSemantics317.markLanguage320(
        m, ResearchSemantics317.pendingLanguage320(m).single);
    m.passages
      ..clear()
      ..add(passage('new'));
    expect(ResearchSemantics317.pendingLanguage320(m).single.text,
        contains('new'));
  });
  test(
      'learned surface composes an unseen fact; no answer hint or self-training',
      () {
    final l = MgdLanguage20();
    for (var i = 0; i < 6; i++)
      l.ingestText('Il cane è un mammifero. Il gatto contiene cellule.');
    final before = l.sentences;
    final out = l.realizeFact320('Lupo', 'tipo di', 'mammifero');
    expect(out, 'Lupo è mammifero.');
    expect(l.lastVisitedEdges21, greaterThan(0));
    expect(l.sentences, before);
    expect(l.realizeFact320('Lupo', 'orbita intorno a', 'Terra'), isNull);
    final restored = MgdLanguage20.fromJson(jsonDecode(jsonEncode(l.toJson())));
    expect(restored.realizeFact320('Lince', 'tipo di', 'mammifero'),
        'Lince è mammifero.');
  });
  test('generation gets a fact from memory without receiving its answer', () {
    final l = MgdLanguage20(), b = PlasticLanguageBrain04();
    l.ingestText('Il cane è un mammifero.');
    b.importTeacherFact08(
        subject: 'Lupo',
        relation: 'tipo di',
        object: 'mammifero',
        confidence: .9,
        source: 'fixture');
    expect(l.generate('Parlami del lupo', brain: b), 'Lupo è Mammifero.');
    expect(l.generate('Parlami di Nettuno', brain: b), isNull);
  });
  test('worker evolves memory off caller isolate without mutating source',
      () async {
    final f = fixture319(32);
    final before = f.world.toJson();
    final result = await MemoryRuntime319.compute320(f.brain, f.world);
    expect(f.world.toJson(), before);
    final w = MgdWorld06.fromJson(result.world);
    expect(w.thoughtCycles, 2);
    expect(w.runtime319['replayedTotal'], 8);
    expect(result.concepts, isNotEmpty);
  });
}
