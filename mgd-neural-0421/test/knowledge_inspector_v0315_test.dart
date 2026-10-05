import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/knowledge_inspector_v0315.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/native_mgd_engine_v09.dart';

ResearchClaim11 claim315(String key,String status)=>ResearchClaim11(
  key:key,subject:'Soggetto $key',relation:'tipo di',object:'categoria $key',
  confidence:0.64,conflict:false,status:status,lastSeenIso:DateTime.now().toIso8601String(),
  sourceFamilies:<String>{'famiglia A',if(status=='accettata')'famiglia B'},
  sourceProviders:<String>{'Provider A'},evidenceIds:<String>{'ev-$key'},
);
MemoryInspector315 fixture315(){
  final memory=ResearchMemory11();
  for(var i=0;i<2;i++)memory.claims['ok$i']=claim315('ok$i','accettata');
  for(var i=0;i<18;i++)memory.claims['weak$i']=claim315('weak$i','ipotesi_mgd');
  memory.claims['blocked']=claim315('blocked','quarantena');
  memory.evidence.add(ResearchEvidence11(id:'ev-ok0',subject:'Soggetto ok0',relation:'tipo di',object:'categoria ok0',
    provider:'Provider A',sourceFamily:'famiglia A',sourceTitle:'Fonte di prova',sourceUrl:'https://example.invalid/source',
    excerpt:'Testo originale di prova, non una conferma scientifica.',trust:0.9,retrievedAtIso:DateTime.now().toIso8601String()));
  return MemoryInspector315(brain:PlasticLanguageBrain04(),world:MgdWorld06(),research:memory,language:MgdLanguage20());
}
void main(){
  test('two accepted, eighteen hypotheses and one quarantine have exact lists',(){
    final i=fixture315();
    expect(i.metricRows('Consolidate web').length,2);
    expect(i.metricRows('Ipotesi MGD').length,18);
    expect(i.metricRows('Quarantena').length,1);
    expect(i.metricRows('Evidenze').length,1);
    expect(i.metricRows('Archi attivi'),isEmpty);
    for(final label in MemoryInspector315.catalog){expect(()=>i.metricRows(label),returnsNormally,reason:label);}
  });
  test('edge filters use exactly the same thresholds as world counters',(){
    final i=fixture315();final eps=MgdMath09.defaults.epsilon;
    i.world.edges['a']=WorldEdge06(a:'e:0',b:'e:1',cost:eps-0.01,uses:4);
    i.world.edges['b']=WorldEdge06(a:'e:2',b:'e:3',cost:eps+0.02,uses:3);
    i.world.edges['c']=WorldEdge06(a:'e:3',b:'e:4',cost:eps+0.20,uses:1);
    expect(i.metricRows('Archi attivi').length,i.world.stats().activeEdges);
    expect(i.metricRows('Pre-attivi').length,i.world.stats().preActiveEdges030);
    expect(i.metricRows('Prior deboli').length,1);
    expect(i.metricRows('Archi mondo').length,3);
  });
  test('inspection does not change stored knowledge',(){
    final i=fixture315();final before=i.research.toJson().toString();
    for(final label in MemoryInspector315.catalog){i.metricRows(label);}
    expect(i.research.toJson().toString(),before);
  });
  test('legacy sessions explicitly disclose missing audit instead of fake lists',(){
    final i=fixture315();
    final s=ResearchSession11(topic:'Storico',query:'q',reason:'r',startedAtIso:'2026-09-24T10:00:00',documents:24);
    final restored=ResearchSession11.fromJson(s.toJson()..remove('audit315'));
    expect(restored.audit315,isEmpty);
    expect(i.sessionRows(restored,'Documenti').single['titolo'],'Dettaglio storico non registrato');
  });
  test('integration records actual documents candidates decisions and gates persistently',(){
    final i=fixture315();
    const a=WebDocument11(provider:'Provider A',family:'A',title:'Nucleotide',url:'https://example.invalid/a',text:'Il nucleotide è una molecola.',trust:0.90);
    const b=WebDocument11(provider:'Provider B',family:'B',title:'Nucleotide',url:'https://example.invalid/b',text:'Nucleotide is a molecule.',trust:0.93);
    const goal=ResearchGoal11(query:'Nucleotide',topic:'Nucleotide',reason:'test',value:1);
    WebKnowledgeExplorer11().integrate(i.brain,i.world,i.research,const ResearchDraft11(goal:goal,documents:[a,b],claims:[
      ExtractedClaim11(subject:'Nucleotide',relation:'tipo di',object:'molecola',sentence:'Il nucleotide è una molecola.',source:a,quality:0.95),
      ExtractedClaim11(subject:'Nucleotide',relation:'tipo di',object:'molecola',sentence:'Nucleotide is a molecule.',source:b,quality:0.95),
    ],passages:[],sentencesRead:2));
    final s=i.research.lastSession!;
    expect(i.sessionRows(s,'Documenti').length,2);
    expect(i.sessionRows(s,'Candidati').length,1);
    expect(s.candidates,1);
    expect(i.sessionRows(s,'Consolidati').length,1);
    expect(s.integrated,1);
    expect((s.audit315['decisions'] as List).single['nuovo consolidamento'],true);
    final restored=ResearchMemory11.fromJson(i.research.toJson());
    expect(restored.lastSession!.audit315['documents'],s.audit315['documents']);
    expect(restored.lastSession!.audit315['decisions'],s.audit315['decisions']);
  });
  test('additional verification has a sentence-by-sentence diagnostic, without changing its policy',(){
    final i=fixture315();
    i.research.claims['nuc']=ResearchClaim11(key:'nuc',subject:'Nucleotide',relation:'tipo di',object:'monomero degli acidi nucleici',confidence:0.64,conflict:false,status:'ipotesi_mgd',lastSeenIso:'',sourceFamilies:<String>{'wikimedia'});
    const p=WebDocument11(provider:'Europe PMC',family:'paper:example',title:'Nucleotides',url:'https://example.invalid/nuc',text:'Nucleotides are monomers of nucleic acids.',trust:0.93);
    WebKnowledgeExplorer11().integrate(i.brain,i.world,i.research,const ResearchDraft11(
      goal:ResearchGoal11(query:'Nucleotide',topic:'Nucleotide',reason:'test',value:1),documents:[p],claims:[],passages:[],sentencesRead:1));
    final trace=i.research.lastSession!.audit315['verification'] as List;
    expect(trace,isNotEmpty);
    final checked=trace.first['Frasi confrontate'] as List;
    expect(checked.single['text'],p.text);
    expect(checked.single.containsKey('esito'),true);
    expect(checked.single.containsKey('motivo'),true);
  });
  testWidgets('tap 2 opens only the two consolidated claims and source details',(tester) async {
    final i=fixture315();
    await tester.pumpWidget(MaterialApp(home:InspectorScope315(inspector:i,child:const Scaffold(body:Wrap(children:[
      InspectMetric315('Consolidate web','2'),InspectMetric315('Ipotesi MGD','18'),
    ])))));
    await tester.tap(find.text('2'));await tester.pumpAndSettle();
    expect(find.text('2 elementi · 2 totali'),findsOneWidget);
    expect(find.text('Soggetto ok0 — tipo di → categoria ok0'),findsOneWidget);
    expect(find.textContaining('Soggetto weak0'),findsNothing);
    await tester.tap(find.text('Soggetto ok0 — tipo di → categoria ok0'));await tester.pumpAndSettle();
    expect(find.text('Dettaglio'),findsOneWidget);
    await tester.scrollUntilVisible(find.text('Evidenze associate'),200,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();
    await tester.tap(find.text('Evidenze associate'));await tester.pumpAndSettle();
    expect(find.text('1 elementi · 1 totali'),findsOneWidget);
    await tester.tap(find.text('Soggetto ok0 — tipo di → categoria ok0'));await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Apri fonte originale'),200,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();
    expect(find.text('https://example.invalid/source'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('tap 18 gives searchable hypotheses, not accepted items',(tester) async {
    final i=fixture315();
    await tester.pumpWidget(MaterialApp(home:InspectorScope315(inspector:i,child:const Scaffold(body:InspectMetric315('Ipotesi MGD','18')))));
    await tester.tap(find.text('18'));await tester.pumpAndSettle();
    expect(find.text('18 elementi · 18 totali'),findsOneWidget);
    await tester.enterText(find.byType(TextField),'weak17');await tester.pumpAndSettle();
    expect(find.text('1 elementi · 18 totali'),findsOneWidget);
    expect(find.text('Soggetto weak17 — tipo di → categoria weak17'),findsOneWidget);
  });
  testWidgets('zero remains clickable and explains the empty category',(tester) async {
    final i=fixture315();
    await tester.pumpWidget(MaterialApp(home:InspectorScope315(inspector:i,child:const Scaffold(body:InspectMetric315('Archi attivi','0')))));
    await tester.tap(find.text('0'));await tester.pumpAndSettle();
    expect(find.text('Nessun elemento in questa categoria.'),findsOneWidget);
  });
  testWidgets('large lists are paginated and navigable',(tester) async {
    final i=fixture315();for(var n=0;n<123;n++){i.language.tokenCount['term$n']=n;}
    await tester.pumpWidget(MaterialApp(home:InspectorScope315(inspector:i,child:const Scaffold(body:InspectMetric315('Token','123')))));
    await tester.tap(find.text('123'));await tester.pumpAndSettle();
    expect(find.text('1–50 di 123'),findsOneWidget);
    await tester.tap(find.byTooltip('Pagina successiva'));await tester.pumpAndSettle();
    expect(find.text('51–100 di 123'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
