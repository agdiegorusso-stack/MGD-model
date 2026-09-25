from pathlib import Path
import sys
root=Path(sys.argv[1])
def edit(name,old,new):
 p=root/name;s=p.read_text();assert old in s,(name,old[:80]);p.write_text(s.replace(old,new,1))
# Synthetic low-trust passage replay remains observational.
p=root/'test/web_knowledge_explorer_v11_test.dart';s=p.read_text().replace('expect(learned, 1);','expect(learned, 0);').replace('expect(memory.passages.single.structured, isTrue);','expect(memory.passages.single.structured, isFalse);');p.write_text(s)
edit('lib/main.dart','    _maintenance317=true;','    if(_chat.text.isNotEmpty||!ResearchSemantics317.needsMaintenance(_researchMemory))return;\n    _maintenance317=true;')
edit('lib/research_semantics_v0317.dart','  static int getPending(ResearchMemory11 m)',"""  static bool needsMaintenance(ResearchMemory11 m) => m.state317['migrationComplete']!=true || getPending(m)>0 ||
      ((m.state317['languagePassages'] as num?)?.toInt()??0)<m.passages.length ||
      ((m.state317['languageEvidence'] as num?)?.toInt()??0)<m.evidence.length;
  static int getPending(ResearchMemory11 m)""")
edit('lib/research_semantics_v0317.dart',"    if(sid!=null){\n      final owned=brain.reconcileResearch317(sid,c.relation,c.object,c.status,c.sourceFamilies);", """    final unqualified=c.meta317['qualifiers'] is! Map || (c.meta317['qualifiers'] as Map).isEmpty;
    final projectable=c.status=='accettata'&&unqualified;
    if(sid!=null){
      final owned=brain.reconcileResearch317(sid,c.relation,c.object,c.status=='accettata'&&!projectable?'documentata':c.status,c.sourceFamilies);""")
edit('lib/research_semantics_v0317.dart',"if(owned&&oid!=null&&oid!=sid&&c.status!='accettata')",'if(owned&&oid!=null&&oid!=sid&&!projectable)')
edit('lib/research_semantics_v0317.dart',"final senses=found.map((c)=>c.subjectSenseKey??concept(c.subject)).toSet();", "final senses=found.map((c)=>c.subjectSenseKey).whereType<String>().toSet();")
edit('lib/research_semantics_v0317.dart','    if(found.isEmpty)return null;',"""    if(found.isEmpty){
      final legacy=m.claims.values.any((c)=>c.meta317['engine']!=317&&(' $qt ').contains(' ${concept(c.subject)} '));
      return legacy?'Le fonti di questo argomento sono ancora in riesame. Non uso il vecchio consolidamento come conferma.':null;
    }""")
edit('lib/web_knowledge_explorer_v11.dart','    if (evidence.length > 12000) evidence.removeRange(0, evidence.length - 12000);',"""    if(evidence.length>12000){
      final used=claims.values.expand((c)=>c.evidenceIds).toSet();
      var surplus=evidence.length-12000;
      evidence.removeWhere((e)=>!used.contains(e.id)&&surplus-->0);
    }""")
edit('lib/web_knowledge_explorer_v11.dart',"      claims.removeWhere((k, _) => !keep.contains(k));", "      claims.removeWhere((k,c) => !keep.contains(k)&&!{'accettata','documentata','corretta_utente'}.contains(c.status));")
edit('lib/knowledge_snapshot_v012.dart','  final ResearchMemory11 research;','  final ResearchMemory11 research;\n  final Map<String,dynamic>? languageModel;')
edit('lib/knowledge_snapshot_v012.dart','    required this.research,','    required this.research,\n    this.languageModel,')
edit('lib/knowledge_snapshot_v012.dart','    ResearchMemory11 research,\n  ) {','    ResearchMemory11 research, {Map<String,dynamic>? languageModel}\n  ) {')
edit('lib/knowledge_snapshot_v012.dart',"      'language': 'it',","      'language': 'it',\n      if(languageModel!=null)'languageModel':languageModel,")
edit('lib/knowledge_snapshot_v012.dart','    return RestoredSnapshot12(','    final languageRaw=j[\'languageModel\']??j[\'language\'];\n    return RestoredSnapshot12(\n      languageModel:languageRaw is Map?Map<String,dynamic>.from(languageRaw):null,')
edit('lib/main.dart',"        _researchMemory.state317['migrationComplete']=false;", """        if(restored.languageModel!=null)_language20=MgdLanguage20.fromJson(restored.languageModel!);
        _researchMemory.state317['migrationComplete']=false;""")
p=root/'lib/main.dart';s=p.read_text();a=s.index('  Future<void> _importSnapshot12()');b=s.index('  Future<void> _openEditor12()',a);part=s[a:b].replace('      await _researchPersistence.save(_researchMemory);','      await _researchPersistence.save(_researchMemory);\n      await _languagePersistence20.save(_language20);');s=s[:a]+part+s[b:]
a=s.index('  Future<void> _exportSnapshot12()');b=s.index('  Future<void> _importSnapshot12()',a);part=s[a:b].replace('        _researchMemory,','        _researchMemory,languageModel:_language20.toJson(),');s=s[:a]+part+s[b:];p.write_text(s)
p=root/'test/research_v0317_test.dart';s=p.read_text();i=s.index('void main(){')+len('void main(){');s=s[:i]+"""
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
"""+s[i:];p.write_text(s)
p=root/'test/research_v0317_test.dart';s=p.read_text().replace("import 'dart:convert';","import 'dart:convert';\nimport 'package:mgd_neuro_mobile/knowledge_snapshot_v012.dart';");p.write_text(s)
# Study counters use the same rows as their drill-downs, including queued work.
f='lib/research_semantics_v0317.dart'
edit(f,'session.documents=draft.documents.length;session.sentencesRead=draft.sentencesRead;',"session.documents=draft.documents.length;session.sentencesRead=0;\n    session.sources.addAll(draft.documents.map((d)=>d.provider).toSet());")
edit(f,"'candidates':draft.claims.map(WebKnowledgeExplorer11.candidateRecord315).toList(),", "'candidates':<Map<String,dynamic>>[],\n      'preliminarySentencesRead':draft.sentencesRead,\n      'extractions':draft.claims.map(WebKnowledgeExplorer11.candidateRecord315).toList(),")
edit(f,'final clock=Stopwatch()..start();var units=0;', 'final touched=<ResearchSession11>{};\n    final clock=Stopwatch()..start();var units=0;')
edit(f,"if(ss.length<2000)ss.add({'text':text,'provider':doc.provider,'sourceTitle':doc.title,'sourceUrl':doc.url});", "ss.add({'text':text,'provider':doc.provider,'sourceTitle':doc.title,'sourceUrl':doc.url});\n          session.sentencesRead=ss.length;")
edit(f,'if(session!=null)_summary(m,session);','if(session!=null)touched.add(session);')
edit(f,"m.state317['queue']=queue;m.state317['documentsRead']=done.toList();", "m.state317['queue']=queue;m.state317['documentsRead']=done.toList();\n    for(final session in touched){_summary(m,session);}")
edit(f,"s.audit315['documented']=documented;", """s.audit315['documented']=documented;
    s.audit315['candidates']=ds;
    s.audit315['candidateCounting']='Proposizioni distinte; ripetizioni nelle evidenze, non nel numero dei candidati.';
    final pending=(m.state317['queue'] as List? ?? []).whereType<Map>().where((q)=>q['session']==s.startedAtIso).length;
    s.audit315['pendingDocuments']=pending;""")
edit(f,"s.status='conoscenza documentata con provenienza';s.completedAtIso=DateTime.now().toIso8601String();", "s.status=pending>0?'lettura incrementale in corso':'conoscenza documentata con provenienza';\n    s.completedAtIso=pending>0?'':DateTime.now().toIso8601String();")
edit('test/knowledge_inspector_v0315_test.dart',"expect(i.sessionRows(s,'Candidati').length,2);", "expect(i.sessionRows(s,'Candidati').length,1);\n    expect(s.candidates,1);")
edit('test/research_v0317_test.dart','void main(){',"""void main(){
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
""")
