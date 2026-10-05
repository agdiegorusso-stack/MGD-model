import 'dart:convert';
import 'package:mgd_neuro_mobile/knowledge_snapshot_v012.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/knowledge_inspector_v0315.dart';

WebDocument11 doc(String text,{String family='wikimedia',String url='https://it.wikipedia.org/wiki/Organismo',String title='Organismo'})=>
  WebDocument11(provider:'Wikipedia IT',family:family,title:title,url:url,text:text,trust:0.9);
ResearchDraft11 draft(WebDocument11 d,{String topic='Organismi',List<ExtractedClaim11> claims=const []})=>
  ResearchDraft11(goal:ResearchGoal11(query:topic,topic:topic,reason:'test',value:1),documents:[d],claims:claims,passages:const [],sentencesRead:1);
String assess(String text,{String r='tipo di',String o='organizzazione'})=>ResearchSemantics317.assess(text,subject:'Organismi',rel:r,object:o);
Map<String,dynamic> statement(String p,String target,{String rank='normal',Map<String,dynamic> qualifiers=const {}})=>{
  'id':'Q7239\$$p-$target','rank':rank,'qualifiers':qualifiers,
  'references':[{'hash':'ref1','snaks':{'P248':[{'snaktype':'value','datavalue':{'value':{'id':'Q1'}}}]}}],
  'mainsnak':{'snaktype':'value','property':p,'datavalue':{'type':'wikibase-entityid','value':{'id':target}}},
};
List<ExtractedClaim11> structured({String p='P527',String rank='normal',Map<String,dynamic> qualifiers=const {},String sid='Q7239',String label='Organismo'})=>ResearchSemantics317.structured(
  {'lastrevid':123,'claims':{p:[statement(p,'Q7868',rank:rank,qualifiers:qualifiers)]}},
  {'Q7868':{'labels':{'it':{'value':'cellula'}}}},id:sid,label:label,gloss:'essere vivente');
void drain(PlasticLanguageBrain04 b,MgdWorld06 w,ResearchMemory11 m){
  var i=0;while(ResearchSemantics317.getPending(m)>0&&i++<1000){ResearchSemantics317.processQueue(b,w,m,maxUnits:24);}
  expect(ResearchSemantics317.getPending(m),0);
}
void main(){
  test('progress counters match inspected rows after 37 queued documents',(){
    final b=PlasticLanguageBrain04();final w=MgdWorld06();final m=ResearchMemory11();
    final docs=List.generate(37,(i)=>doc('Gli organismi sono esseri viventi.',url:'https://source.test/$i',family:'one'));
    final d=ResearchDraft11(goal:ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1),documents:docs,claims:const [],passages:const [],sentencesRead:10);
    WebKnowledgeExplorer11().integrate(b,w,m,d);drain(b,w,m);
    final s=m.lastSession!;final view=MemoryInspector315(brain:b,world:w,research:m,language:MgdLanguage20());
    expect(s.documents,37);expect(view.sessionRows(s,'Documenti').length,37);
    expect(s.sentencesRead,37);expect(view.sessionRows(s,'Frasi lette').length,37);
    expect(s.candidates,1);expect(view.sessionRows(s,'Candidati').length,1);
    expect(s.audit315['documented'],1);expect(view.sessionRows(s,'Documentate').length,1);
    expect(s.sources,['Wikipedia IT']);expect(s.completedAtIso,isNotEmpty);
    expect(s.audit315['pendingDocuments'],0);expect(m.lastStatus,contains('0 documenti in coda'));
  });
  test('unfinished queue does not claim session completion',(){
    final b=PlasticLanguageBrain04();final w=MgdWorld06();final m=ResearchMemory11();
    final s=ResearchSession11(topic:'Organismi',query:'Organismi',reason:'test',startedAtIso:'test');
    m.sessions.add(s);
    ResearchSemantics317.enqueue(m,[doc('Gli organismi sono esseri viventi. Gli organismi hanno cellule.')],topic:'Organismi',session:'test');
    ResearchSemantics317.processQueue(b,w,m,maxUnits:1);
    expect(s.completedAtIso,isEmpty);expect(s.audit315['pendingDocuments'],1);
    expect(s.sentencesRead,1);expect(s.status,'lettura incrementale in corso');
    drain(b,w,m);expect(s.completedAtIso,isNotEmpty);expect(s.sentencesRead,2);
    expect(s.candidates,2);expect(s.audit315['pendingDocuments'],0);
  });
  test('repeated source extraction contributes one candidate and separate evidence',(){
    final b=PlasticLanguageBrain04();final w=MgdWorld06();final m=ResearchMemory11();
    final a=doc('Gli organismi sono esseri viventi.',url:'https://a.test/1',family:'a');
    final c=doc('Gli organismi sono esseri viventi.',url:'https://b.test/1',family:'b');
    final xs=[for(final x in [a,c])ExtractedClaim11(subject:'Organismi',relation:'tipo di',object:'esseri viventi',sentence:x.text,source:x,quality:0.9)];
    final d=ResearchDraft11(goal:ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1),documents:[a,c],claims:xs,passages:const [],sentencesRead:2);
    WebKnowledgeExplorer11().integrate(b,w,m,d);drain(b,w,m);
    final s=m.lastSession!;expect(s.candidates,1);expect(s.integrated,1);
    expect((s.audit315['candidates'] as List).length,1);expect(m.evidence.length,2);
  });

  test('full snapshot restores separate language metadata',(){
    final b=PlasticLanguageBrain04();final w=MgdWorld06();final m=ResearchMemory11();
    final bytes=KnowledgeSnapshot12.fullSnapshotBytes(b,w,m,languageModel:{'test':317});
    expect(KnowledgeSnapshot12.restoreSnapshotBytes(bytes).languageModel,{'test':317});
    final legacy=KnowledgeSnapshot12.fullSnapshotBytes(b,w,m);
    expect(KnowledgeSnapshot12.restoreSnapshotBytes(legacy).languageModel,isNull);
  });
  test('completed maintenance does not starve autonomous timer',(){
    final m=ResearchMemory11();expect(ResearchSemantics317.needsMaintenance(m),true);
    m.state317['migrationComplete']=true;expect(ResearchSemantics317.needsMaintenance(m),false);
    ResearchSemantics317.enqueue(m,[doc('Gli organismi sono esseri viventi.')],topic:'Organismi',session:'x');
    expect(ResearchSemantics317.needsMaintenance(m),true);
  });
  test('qualified multi-source claims never become unqualified facts',(){
    final b=PlasticLanguageBrain04();final w=MgdWorld06();final m=ResearchMemory11();
    b.ensureSemanticEntity06('Organismi');
    for(var n=0;n<2;n++){
      final d=doc('Alcuni organismi sono mammiferi.',family:'f$n',url:'https://f$n.test/organismi');
      WebKnowledgeExplorer11().integrate(b,w,m,draft(d));drain(b,w,m);
    }
    final c=m.claims.values.single;expect(c.status,'accettata');
    expect(c.meta317['qualifiers'],containsPair('scope','alcuni'));
    expect(b.slots.values.expand((s)=>s.candidates.values).where((c)=>c.epistemicStatus=='consolidated'),isEmpty);
    expect(w.stats().activeEdges,0);
  });

  test('different concepts cannot match a five-letter prefix',(){
    expect(ResearchSemantics317.sameSubject('organismi','organizzazione'),false);
    expect(ResearchSemantics317.sameObject('organizzazione','organo'),false);
    expect(ResearchSemantics317.sameSubject('organismi','organismo'),true);
  });
  test('co-occurrence does not support a type assertion',(){
    expect(assess('Gli organismi sono studiati in laboratorio.'),'unknown');
    expect(assess('Organizzazione e organismi sono discussi in un articolo.'),'unknown');
  });
  test('negation is contrary evidence, never support',(){
    expect(assess('Gli organismi non sono organizzazioni.'),'contradiction');
    expect(assess('Organisms are not organizations.'),'contradiction');
  });
  test('reverse relation cannot confirm a claim',(){
    expect(assess('Le cellule sono componenti degli organismi.',o:'cellula'),'unknown');
  });
  test('plural composition is recognized and cardinality is retained',(){
    const t='Gli organismi sono costituiti da una o più cellule.';
    expect(assess(t,r:'ha parte',o:'cellula'),'support');
    final x=ResearchSemantics317.extract('Organismi',t,doc(t)).single;
    expect(x.relation,'ha parte');expect(x.meta317['qualifiers']['cardinality'],'una o più');
  });
  test('condition and uncertainty do not become unqualified facts',(){
    for(final s in ['Gli organismi potrebbero essere organizzazioni.','Gli organismi sono organizzazioni se cambia il significato.','Organisms may be organizations.']){
      expect(assess(s),'unknown',reason:s);
    }
  });
  test('subset statements cannot confirm universal assertions',(){
    expect(assess('Alcuni organismi sono organizzazioni.'),'unknown');
    final x=ResearchSemantics317.extract('Organismi','Alcuni organismi sono organizzazioni.',doc('')).single;
    expect(x.meta317['qualifiers']['scope'],'alcuni');
  });
  test('title alone cannot supply the missing subject',(){
    expect(ResearchSemantics317.assess('I gruppi sono organizzazioni.',subject:'Organismi',rel:'tipo di',object:'organizzazione',title:'Organismi'),'unknown');
  });
  test('implicit subject requires the correct document title',(){
    expect(ResearchSemantics317.extract('Organismi','È una organizzazione.',doc('',title:'Finanza'),implicit:true),isEmpty);
  });
  test('controlled lexical translation keeps noun phrases distinct',(){
    expect(ResearchSemantics317.sameObject('monomero degli acidi nucleici','monomers of nucleic acids'),true);
    expect(ResearchSemantics317.sameObject('cellula vegetale','cellula animale'),false);
  });
  test('P31 and P279 have distinct predicates and keys',(){
    final a=structured(p:'P31').single,b=structured(p:'P279').single;
    expect(a.relation,'istanza di');expect(b.relation,'sottoclasse di');
    expect(ResearchSemantics317.claimKey(a),isNot(ResearchSemantics317.claimKey(b)));
  });
  test('structured data retains identifiers revision rank references and qualifiers',(){
    final q={'P580':[{'value':'2026'}]};final x=structured(qualifiers:q).single;
    expect(x.subjectSenseKey,'wikidata:Q7239');expect(x.meta317['objectSenseKey'],'wikidata:Q7868');
    expect(x.meta317['revision'],123);expect(x.meta317['references'],isNotEmpty);
    expect(x.meta317['qualifiers'],q);expect(x.meta317['rawStatement'],isNotEmpty);
  });
  test('deprecated statements do not document knowledge',(){
    expect(ResearchSemantics317.evaluate(structured(rank:'deprecated').single)['verdict'],'unknown');
  });
  test('incomplete structured metadata is not trusted by provider name',(){
    final x=ExtractedClaim11(subject:'Organismi',relation:'tipo di',object:'organizzazione',sentence:'Wikidata: Organismi — tipo di → organizzazione',source:doc(''),quality:1,meta317:{'extractor':'wikidata317'});
    expect(ResearchSemantics317.evaluate(x)['verdict'],'unknown');
  });
  test('homonymous QIDs never merge',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    for(final sid in ['Q7239','Q999']){
      final x=structured(sid:sid).single;
      WebKnowledgeExplorer11().integrate(b,w,m,draft(x.source,topic:'Organismo',claims:[x]));
    }
    expect(m.claims.length,2);
    expect(ResearchSemantics317.answer('Cosa è organismo?',m),contains('significati distinti'));
  });
  test('single clear source is documented and usable with its source',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    final d=doc('Gli organismi sono costituiti da cellule.');
    WebKnowledgeExplorer11().integrate(b,w,m,draft(d));drain(b,w,m);
    expect(m.claims.values.single.status,'documentata');
    final a=ResearchSemantics317.answer('Cosa sono gli organismi?',m);
    expect(a,contains('Documentata da una fonte'));expect(a,contains(d.url));
  });
  test('re-reading is idempotent across serialization and does not boost confidence',(){
    var m=ResearchMemory11();final b=PlasticLanguageBrain04(),w=MgdWorld06();
    final x=structured().single;final d=draft(x.source,claims:[x]);
    WebKnowledgeExplorer11().integrate(b,w,m,d);
    final n=m.evidence.length,confidence=m.claims.values.single.confidence;
    m=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    for(var i=0;i<10;i++)WebKnowledgeExplorer11().integrate(b,w,m,d);
    expect(m.evidence.length,n);expect(m.claims.values.single.confidence,confidence);
    expect(m.claims.values.single.status,'documentata');
  });
  test('two providers serving the same DOI are one provenance family',(){
    final a=doc('',family:'EuropePMC',url:'https://doi.org/10.1234/a');
    final b=doc('',family:'paper:doi:10.1234/a',url:'https://publisher.example/a');
    expect(ResearchSemantics317.family(a),ResearchSemantics317.family(b));
  });
  test('tracking parameters do not create a different source URL',(){
    expect(ResearchSemantics317.canonicalUrl('https://example.org/a?utm_source=x#section'),'https://example.org/a');
  });
  test('independent provenance groups corroborate only actual support',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    final a=doc('Gli organismi sono costituiti da cellule.');
    final z=doc('Gli organismi sono costituiti da cellule.',family:'enciclopedia',url:'https://encyclopedia.example/organismi');
    for(final d in [a,z]){WebKnowledgeExplorer11().integrate(b,w,m,draft(d));drain(b,w,m);}
    expect(m.claims.values.single.status,'accettata');expect(m.claims.values.single.sourceFamilies.length,2);
  });
  test('many irrelevant documents cannot corroborate organization claim',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    for(var i=0;i<4;i++){
      final d=doc('Gli organismi sono studiati in laboratorio.',family:'f$i',url:'https://example.org/$i');
      final x=ExtractedClaim11(subject:'Organismi',relation:'tipo di',object:'organizzazione',sentence:d.text,source:d,quality:1);
      WebKnowledgeExplorer11().integrate(b,w,m,draft(d,claims:[x]));drain(b,w,m);
    }
    expect(m.claims.values.single.status,'ipotesi_mgd');expect(m.claims.values.single.sourceFamilies,isEmpty);
    expect(ResearchSemantics317.answer('Cosa sono organismi?',m),isNull);
  });
  test('positive and negative evidence open a conflict and retract usability',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    for(final t in ['Gli organismi sono organizzazioni.','Gli organismi non sono organizzazioni.']){
      WebKnowledgeExplorer11().integrate(b,w,m,draft(doc(t)));drain(b,w,m);
    }
    expect(m.claims.values.single.conflict,true);expect(m.claims.values.single.status,'quarantena');
    expect(m.claims.values.single.meta317['usable'],false);
  });
  test('queue processes beyond ten documents and survives restart',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06();var m=ResearchMemory11();
    final docs=List.generate(37,(i)=>doc('Gli organismi sono studiati in laboratorio. Gli organismi sono costituiti da cellule.',family:'f$i',url:'https://example.org/$i'));
    ResearchSemantics317.enqueue(m,docs,topic:'Organismi',session:'s');
    ResearchSemantics317.processQueue(b,w,m,maxUnits:1);
    expect(ResearchSemantics317.getPending(m),greaterThan(0));
    m=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));drain(b,w,m);
    expect((m.state317['documentsRead'] as List).length,37);
    expect(m.claims.values.single.sourceFamilies.length,37);
  });
  test('legacy false consolidation is downgraded without deleting evidence',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    final sid=b.ensureSemanticEntity06('Organismi'),oid=b.ensureSemanticEntity06('organizzazione');
    b.importResearchFact028(subjectId:sid,relation:'tipo di',object:'organizzazione',sourceFamilies:['old']);
    w.consolidateSemanticLink029(sid,oid);
    final c=ResearchClaim11(key:'old',subject:'Organismi',relation:'tipo di',object:'organizzazione',confidence:0.84,conflict:false,status:'accettata',lastSeenIso:'',evidenceIds:{'e'},sourceFamilies:{'old'});
    m.claims[c.key]=c;m.evidence.add(ResearchEvidence11(id:'e',subject:c.subject,relation:c.relation,object:c.object,provider:'old',sourceFamily:'old',sourceTitle:'Old',sourceUrl:'https://old.example',excerpt:'Gli organismi sono studiati in laboratorio.',trust:0.9,retrievedAtIso:''));
    ResearchSemantics317.migrateClaim(b,w,m,c);
    expect(m.evidence.length,1);expect(c.status,'ipotesi_mgd');expect(c.meta317['before317']['status'],'accettata');
    expect(b.cognitiveFacts06().where((f)=>f.subjectId==sid&&f.object.toLowerCase()=='organizzazione'),isEmpty);
    expect(w.stats().activeEdges,0);
  });
  test('legacy repeated evidence is preserved but counted once',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    final c=ResearchClaim11(key:'old',subject:'Organismi',relation:'ha parte',object:'cellula',confidence:.8,conflict:false,status:'ipotesi_mgd',lastSeenIso:'');
    m.claims[c.key]=c;
    for(var i=0;i<14;i++){
      c.evidenceIds.add('e$i');m.evidence.add(ResearchEvidence11(id:'e$i',subject:c.subject,relation:c.relation,object:c.object,provider:'Wikipedia IT',sourceFamily:'wikimedia',sourceTitle:'Organismo',sourceUrl:'https://it.wikipedia.org/wiki/Organismo',excerpt:'Gli organismi sono costituiti da cellule.',trust:.9,retrievedAtIso:''));
    }
    ResearchSemantics317.migrateClaim(b,w,m,c);
    expect(m.evidence.length,14);expect(c.meta317['directSupports'],1);expect(c.status,'documentata');
  });
  test('manual corrections survive migration',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    final c=ResearchClaim11(key:'user',subject:'A',relation:'tipo di',object:'B',confidence:1,conflict:false,status:'corretta_utente',lastSeenIso:'');
    ResearchSemantics317.migrateClaim(b,w,m,c);expect(c.status,'corretta_utente');expect(c.confidence,1);
  });
  test('language learns web sentences independently, once, with provenance',()async{
    var language=MgdLanguage20();final m=ResearchMemory11();
    final d=doc('Gli organismi sono costituiti da cellule.');
    expect(await language.ingestWeb317(d),1);expect(language.stats().tokens,greaterThan(0));
    language=MgdLanguage20.fromJson(jsonDecode(jsonEncode(language.toJson())));
    expect(await language.ingestWeb317(d),0);expect(language.webSeen317.values.single['sourceUrl'],d.url);
    expect(m.claims,isEmpty);
  });
  test('English-only text is not silently added to Italian language memory',()async{
    final l=MgdLanguage20();expect(await l.ingestWeb317(doc('The organisms are made of cells.')),0);expect(l.sentences,0);
  });
  test('state roundtrip keeps proof metadata and document queue',(){
    final m=ResearchMemory11(),b=PlasticLanguageBrain04(),w=MgdWorld06();final x=structured().single;
    WebKnowledgeExplorer11().integrate(b,w,m,draft(x.source,claims:[x]));
    ResearchSemantics317.enqueue(m,[doc('Gli organismi sono costituiti da cellule.')],topic:'Organismi',session:'s');
    final restored=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(restored.evidence.single.meta317,m.evidence.single.meta317);
    expect(restored.claims.values.single.meta317,m.claims.values.single.meta317);
    expect(ResearchSemantics317.getPending(restored),1);
  });
  testWidgets('documented counter opens actual source-attributed records',(tester)async{
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();final x=structured().single;
    WebKnowledgeExplorer11().integrate(b,w,m,draft(x.source,claims:[x]));
    final inspector=MemoryInspector315(brain:b,world:w,research:m,language:MgdLanguage20());
    await tester.pumpWidget(MaterialApp(home:InspectorScope315(inspector:inspector,child:const Scaffold(body:InspectMetric315('Documentate','1')))));
    await tester.tap(find.text('1'));await tester.pumpAndSettle();
    expect(find.text('1 elementi · 1 totali'),findsOneWidget);
    expect(find.text('DOCUMENTATA'),findsOneWidget);
    await tester.tap(find.text('Organismo — ha parte → cellula'));await tester.pumpAndSettle();
    expect(find.text('Dettaglio'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
