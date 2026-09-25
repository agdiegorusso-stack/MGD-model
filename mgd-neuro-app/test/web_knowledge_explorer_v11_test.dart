import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';

void main() {
  const wiki = WebDocument11(provider:'Wikipedia IT', family:'wikimedia', title:'Telefono cellulare', url:'https://it.wikipedia.org/wiki/Telefono_cellulare', text:'', trust:0.84);

  test('parses definition with appositive and parentheses removed', () {
    final x = WebKnowledgeExplorer11().extractClaimsFromSentence('telefono cellulare', 'Il telefono cellulare, detto anche cellulare, è un dispositivo elettronico portatile.', wiki);
    expect(x, isNotEmpty);
    expect(x.first.relation, 'tipo di');
    expect(x.first.object.toLowerCase(), contains('dispositivo elettronico'));
  });

  test('parses implicit subject in first sentences', () {
    final x = WebKnowledgeExplorer11().extractClaimsFromSentence('telefono cellulare', 'È un dispositivo che permette di comunicare a distanza.', wiki, allowImplicitSubject:true);
    expect(x, isNotEmpty);
    expect(x.first.relation, 'tipo di');
  });

  test('parses function language', () {
    final x = WebKnowledgeExplorer11().extractClaimsFromSentence('telefono cellulare', 'Il telefono cellulare consente di comunicare a distanza.', wiki);
    expect(x.single.relation, 'serve per');
    expect(x.single.object.toLowerCase(), contains('comunicare'));
  });

  test('integration produces detailed session and keeps provenance', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final memory = ResearchMemory11();
    final explorer = WebKnowledgeExplorer11();
    final claim = explorer.extractClaimsFromSentence('cane','Il cane è un mammifero.',wiki).single;
    final goal = const ResearchGoal11(query:'cane definizione', topic:'cane', reason:'test', value:0.9);
    memory.begin(goal.query, DateTime.now());
    final out = explorer.integrate(brain, world, memory, ResearchDraft11(goal:goal, documents:const [wiki], claims:[claim], passages:const [], sentencesRead:3));
    expect(out.integrated, 1);
    expect(out.doubtful, 0);
    expect(memory.lastSession, isNotNull);
    expect(memory.lastSession!.sentencesRead, 0);
    expect(memory.lastSession!.audit315['preliminarySentencesRead'], 3);
    expect(memory.lastSession!.audit315['sentences'] ?? [], isEmpty);
    expect(memory.lastSession!.learnedFacts, isNotEmpty);
    expect(memory.evidence, isNotEmpty);
  });

  test('unstructured passages survive and are revisited', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final memory = ResearchMemory11();
    memory.passages.add(ResearchPassage11(id:'p1', topic:'cane', provider:'Wikipedia IT', sourceFamily:'wikipedia', sourceTitle:'Cane', sourceUrl:'https://example.test', text:'Il cane è un mammifero.'));
    final learned = WebKnowledgeExplorer11().reprocessDuringSleep(brain, world, memory);
    expect(learned, 1);
    expect(memory.passages.single.attempts, 1);
    expect(memory.passages.single.structured, isTrue);
    expect(memory.claims.values.single.status,'documentata');
  });

  test('manual research has no daily hard cap', () {
    final memory = ResearchMemory11(
      enabled: true,
      dailyBudget: 24,
      requestsToday: 240,
    );
    expect(memory.canResearchManual('chimica organica'), isTrue);
  });

  test('old 24/day setting migrates to unlimited', () {
    final memory = ResearchMemory11.fromJson({
      'enabled': true,
      'dailyBudget': 24,
      'requestsToday': 24,
      'dayKey': '2026-09-22',
    });
    expect(memory.dailyBudget, 0);
    expect(memory.canResearch('nuovo argomento', repeatAfter: Duration.zero), isTrue);
  });


  test('single-source research is usable only through source-attributed retrieval', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final memory = ResearchMemory11();
    final explorer = WebKnowledgeExplorer11();
    final claim = explorer.extractClaimsFromSentence('cane','Il cane è un mammifero.',wiki).single;
    final goal = const ResearchGoal11(query:'cane definizione', topic:'cane', reason:'test', value:0.9);
    final out = explorer.integrate(brain, world, memory, ResearchDraft11(goal:goal, documents:const [wiki], claims:[claim], passages:const [], sentencesRead:1));
    expect(out.integrated, 1);
    expect(out.doubtful, 0);
    expect(memory.claims.values.single.status, 'documentata');
    expect(ResearchSemantics317.answer('Cosa è il cane?',memory),contains('Documentata da una fonte'));
    expect(ResearchSemantics317.answer('Cosa è il cane?',memory),contains(wiki.url));
  });

  test('evidence from a second independent family promotes a prior hypothesis', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final memory = ResearchMemory11();
    final explorer = WebKnowledgeExplorer11();
    const other = WebDocument11(provider:'Enciclopedia', family:'example.org', title:'Cane', url:'https://example.org/cane', text:'', trust:0.90);
    final a = explorer.extractClaimsFromSentence('cane','Il cane è un mammifero.',wiki).single;
    final b = explorer.extractClaimsFromSentence('cane','Il cane è un mammifero.',other).single;
    const goal = ResearchGoal11(query:'cane definizione', topic:'cane', reason:'test', value:0.9);
    explorer.integrate(brain, world, memory, const ResearchDraft11(goal:goal, documents:[wiki], claims:[], passages:[], sentencesRead:0));
    explorer.integrate(brain, world, memory, ResearchDraft11(goal:goal, documents:const [wiki], claims:[a], passages:const [], sentencesRead:1));
    final second = explorer.integrate(brain, world, memory, ResearchDraft11(goal:goal, documents:const [other], claims:[b], passages:const [], sentencesRead:1));
    expect(second.integrated, 0); // Already usable; only corroboration is new.
    expect(memory.lastSession!.integrated, 1);
    expect(memory.claims.values.single.status, 'accettata');
  });


  test('corroborated claim activates world edge while a single source stays a prior', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final memory = ResearchMemory11();
    final explorer = WebKnowledgeExplorer11();

    ResearchDraft11 draftFor(String provider, String family) {
      final doc = WebDocument11(
        provider: provider,
        family: family,
        title: 'Test',
        url: 'https://example.test/$provider',
        text: 'ATP è una molecola.',
        trust: 0.9,
      );
      return ResearchDraft11(
        goal: const ResearchGoal11(query: 'ATP', topic: 'ATP', reason: 'test', value: 1),
        documents: [doc],
        claims: [ExtractedClaim11(subject: 'ATP', relation: 'tipo di', object: 'molecola', sentence: 'ATP è una molecola.', source: doc, quality: 0.95)],
        passages: const [],
        sentencesRead: 1,
      );
    }

    explorer.integrate(brain, world, memory, draftFor('Fonte A', 'famiglia-a'));
    expect(memory.claims.values.single.status, 'documentata');
    expect(world.stats().activeEdges, 0);

    explorer.integrate(brain, world, memory, draftFor('Fonte B', 'famiglia-b'));
    expect(memory.claims.values.single.status, 'accettata');
    expect(world.stats().activeEdges, greaterThanOrEqualTo(1));
  });


  test('0.31 weak claim asks specifically for a missing independent family', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    memory.claims['x']=ResearchClaim11(
      key:'x',subject:'Nucleotide',relation:'tipo di',object:'molecola',
      confidence:0.60,conflict:false,status:'ipotesi_mgd',lastSeenIso:DateTime.now().toIso8601String(),
      sourceFamilies:<String>{'wikimedia'},sourceProviders:<String>{'Wikipedia IT','Wikidata'},
    );
    final goal=WebKnowledgeExplorer11().selectGoal(brain,world,memory,force:true);
    expect(goal,isNotNull);
    expect(goal!.diversityVerification031,isTrue);
    expect(goal.avoidFamilies031,contains('wikimedia'));
    expect(goal.reason,contains('indipendente'));
  });


  test('0.31.1 preserves same claim from independent documents before integration', () {
    const a=WebDocument11(
      provider:'Wikipedia IT',family:'wikimedia',title:'Nucleotide',
      url:'https://it.wikipedia.org/wiki/Nucleotide',
      text:'Il nucleotide è una molecola.',trust:0.90,
    );
    const b=WebDocument11(
      provider:'Europe PMC',family:'paper:doi:10.1000/test',title:'Nucleotide chemistry',
      url:'https://doi.org/10.1000/test',
      text:'A nucleotide is a molecule.',trust:0.93,
    );
    const ca=ExtractedClaim11(
      subject:'Nucleotide',relation:'tipo di',object:'molecola',
      sentence:'Il nucleotide è una molecola.',source:a,quality:0.95,
    );
    const cb=ExtractedClaim11(
      subject:'Nucleotide',relation:'tipo di',object:'molecola',
      sentence:'A nucleotide is a molecule.',source:b,quality:0.95,
    );
    final kept=WebKnowledgeExplorer11.dedupeClaimsForTest0311([ca,cb]);
    expect(kept.length,2);

    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    const goal=ResearchGoal11(query:'Nucleotide tipo di molecola',topic:'Nucleotide',reason:'test',value:1);
    final out=WebKnowledgeExplorer11().integrate(
      brain,world,memory,
      ResearchDraft11(goal:goal,documents:[a,b],claims:kept,passages:const [],sentencesRead:2),
    );
    expect(out.integrated,1);
    expect(memory.claims.values.single.status,'accettata');
    expect(memory.claims.values.single.independentSourceCount,2);
  });

  test('0.31.1 targeted verification accepts lexical scientific paraphrase', () {
    expect(
      WebKnowledgeExplorer11.verificationSentenceSupportsForTest0311(
        'A nucleotide is an organic molecule composed of a nucleobase, sugar and phosphate.',
        subject:'Nucleotide',
        relation:'tipo di',
        object:'molecola',
      ),
      isTrue,
    );
    expect(
      WebKnowledgeExplorer11.verificationSentenceSupportsForTest0311(
        'This paper discusses an unrelated clinical outcome.',
        subject:'Nucleotide',
        relation:'tipo di',
        object:'molecola',
      ),
      isFalse,
    );
  });


  test('0.31.2 extracts English scientific copular claims', () {
    const doc=WebDocument11(
      provider:'Europe PMC',
      family:'paper:doi:10.1000/nucleotide',
      title:'Nucleotide chemistry',
      url:'https://doi.org/10.1000/nucleotide',
      text:'A nucleotide is a molecule.',
      trust:0.93,
    );
    final xs=WebKnowledgeExplorer11().extractClaimsFromSentence(
      'Nucleotide',
      'Nucleotide is a molecule.',
      doc,
    );
    expect(xs,isNotEmpty);
    expect(xs.first.relation,'tipo di');
    expect(xs.first.object.toLowerCase(),contains('molecule'));
  });

  test('0.31.2 English paper can promote an existing Wikimedia hypothesis', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    final explorer=WebKnowledgeExplorer11();
    const wiki=WebDocument11(
      provider:'Wikipedia IT',family:'wikimedia',title:'Nucleotide',
      url:'https://it.wikipedia.org/wiki/Nucleotide',
      text:'Il nucleotide è un monomero degli acidi nucleici.',trust:0.90,
    );
    const paper=WebDocument11(
      provider:'Europe PMC',family:'paper:doi:10.1000/nuc',
      title:'Nucleotides',url:'https://doi.org/10.1000/nuc',
      text:'Nucleotides are monomers of nucleic acids.',trust:0.93,
    );
    const goal=ResearchGoal11(query:'Nucleotide monomero acidi nucleici',topic:'Nucleotide',reason:'test',value:1);
    explorer.integrate(
      brain,world,memory,
      ResearchDraft11(
        goal:goal,documents:[wiki],
        claims:[ExtractedClaim11(
          subject:'Nucleotide',relation:'tipo di',object:'monomero degli acidi nucleici',
          sentence:'Il nucleotide è un monomero degli acidi nucleici.',source:wiki,quality:0.95)],
        passages:const [],sentencesRead:1),
    );
    expect(memory.claims.values.single.status,'documentata');
    expect(
      WebKnowledgeExplorer11.verificationSentenceSupportsForTest0311(
        'Nucleotides are monomers of nucleic acids.',
        subject:'Nucleotide',
        relation:'tipo di',
        object:'monomero degli acidi nucleici',
      ),
      isTrue,
    );
    explorer.integrate(
      brain,world,memory,
      ResearchDraft11(
        goal:goal,documents:[paper],
        claims:[ExtractedClaim11(
          subject:'Nucleotide',relation:'tipo di',object:'monomero degli acidi nucleici',
          sentence:'Nucleotides are monomers of nucleic acids.',source:paper,quality:0.80)],
        passages:const [],sentencesRead:1),
    );
    final claim=memory.claims.values.single;
    expect(claim.status,'accettata');
    expect(claim.independentSourceCount,2);
  });


  test('0.31.3 verification prioritizes a near-gate claim over a noisy fragment', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    final now=DateTime.now().toIso8601String();
    memory.claims['noise']=ResearchClaim11(
      key:'noise',subject:'Organismi',relation:'composto da',
      object:'due componenti in stretta relazione la prima rappresentata dagli organismi viventi e',
      confidence:0.34,conflict:false,status:'ipotesi_mgd',lastSeenIso:now,
      evidenceIds:<String>{'n1'},sourceFamilies:<String>{'wikimedia'},sourceProviders:<String>{'Wikidata'},
    );
    memory.claims['good']=ResearchClaim11(
      key:'good',subject:'Nucleotide',relation:'tipo di',object:'monomero degli acidi nucleici',
      confidence:0.64,conflict:false,status:'ipotesi_mgd',lastSeenIso:now,
      evidenceIds:<String>{'g1','g2','g3','g4'},sourceFamilies:<String>{'wikimedia'},sourceProviders:<String>{'Wikipedia IT'},
    );
    final goal=WebKnowledgeExplorer11().selectGoal(brain,world,memory,force:true);
    expect(goal,isNotNull);
    expect(goal!.verifySubject031,'Nucleotide');
    expect(goal.verifyObject031,'monomero degli acidi nucleici');
  });

  test('0.31.3 semantic claim key merges scientific cognate paraphrases', () {
    const wiki=WebDocument11(provider:'Wikipedia IT',family:'wikimedia',title:'Nucleotide',url:'https://it.wikipedia.org/wiki/Nucleotide',text:'x',trust:0.9);
    const paper=WebDocument11(provider:'Europe PMC',family:'paper:doi:10.1/x',title:'Nucleotide',url:'https://doi.org/10.1/x',text:'x',trust:0.93);
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    const goal=ResearchGoal11(query:'Nucleotide',topic:'Nucleotide',reason:'test',value:1);
    final out=WebKnowledgeExplorer11().integrate(
      brain,world,memory,
      ResearchDraft11(goal:goal,documents:[wiki,paper],claims:const [
        ExtractedClaim11(subject:'Nucleotide',relation:'tipo di',object:'monomero degli acidi nucleici',sentence:'Il nucleotide è un monomero degli acidi nucleici.',source:wiki,quality:0.95),
        ExtractedClaim11(subject:'Nucleotide',relation:'tipo di',object:'monomers of nucleic acids',sentence:'Nucleotides are monomers of nucleic acids.',source:paper,quality:0.90),
      ],passages:const [],sentencesRead:2),
    );
    expect(out.integrated,1);
    expect(memory.claims.values.where((c)=>c.status=='accettata').length,1);
    expect(memory.claims.values.single.independentSourceCount,2);
  });


  test('0.31.4 generic topic research can consolidate an existing weak claim from fetched papers', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    final now=DateTime.now().toIso8601String();

    memory.claims['legacy']=ResearchClaim11(
      key:'legacy',
      subject:'Nucleotide',
      relation:'tipo di',
      object:'monomero degli acidi nucleici',
      confidence:0.64,
      conflict:false,
      status:'ipotesi_mgd',
      lastSeenIso:now,
      evidenceIds:<String>{'old1','old2','old3','old4'},
      sourceFamilies:<String>{'wikimedia'},
      sourceProviders:<String>{'Wikipedia IT'},
    );

    const paper=WebDocument11(
      provider:'Europe PMC',
      family:'paper:doi:10.1234/nuc',
      title:'Nucleotides and nucleic acids',
      url:'https://doi.org/10.1234/nuc',
      text:'Nucleotides are monomers of nucleic acids. They are essential building blocks of DNA and RNA.',
      trust:0.93,
    );

    const goal=ResearchGoal11(
      query:'Nucleotide definizione caratteristiche',
      topic:'Nucleotide',
      reason:'argomento rilevante ma poco strutturato nel grafo',
      value:1,
    );

    final out=WebKnowledgeExplorer11().integrate(
      brain,
      world,
      memory,
      const ResearchDraft11(
        goal:goal,
        documents:[paper],
        claims:[],
        passages:[],
        sentencesRead:2,
      ),
    );

    expect(out.integrated,1);
    expect(memory.claims['legacy']!.status,'documentata');
    expect(memory.claims['legacy']!.independentSourceCount,1);
    expect(memory.claims['legacy']!.sourceFamilies,contains('paper:doi:10.1234/nuc'));
  });

  test('0.31.4 selector skips a cooling-down top claim and verifies the next one', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    final now=DateTime.now();

    memory.claims['top']=ResearchClaim11(
      key:'top',
      subject:'Nucleotide',
      relation:'tipo di',
      object:'monomero degli acidi nucleici',
      confidence:0.68,
      conflict:false,
      status:'ipotesi_mgd',
      lastSeenIso:now.toIso8601String(),
      evidenceIds:<String>{'a','b','c','d','e'},
      sourceFamilies:<String>{'wikimedia'},
      sourceProviders:<String>{'Wikipedia IT'},
    );
    memory.claims['next']=ResearchClaim11(
      key:'next',
      subject:'RNA',
      relation:'tipo di',
      object:'acido nucleico',
      confidence:0.62,
      conflict:false,
      status:'ipotesi_mgd',
      lastSeenIso:now.toIso8601String(),
      evidenceIds:<String>{'f','g','h'},
      sourceFamilies:<String>{'wikimedia'},
      sourceProviders:<String>{'Wikidata'},
    );

    memory.begin('Nucleotide tipo di monomero degli acidi nucleici',now);
    final goal=WebKnowledgeExplorer11().selectGoal(brain,world,memory,force:false);
    expect(goal,isNotNull);
    expect(goal!.verifySubject031,'RNA');
  });

}
