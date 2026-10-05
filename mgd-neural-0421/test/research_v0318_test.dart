import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/knowledge_inspector_v0315.dart';

const organismText="Un organismo vivente è un'entità, unicellulare o pluricellulare, soggetta alle leggi del mondo fisico e al controllo da parte dei sistemi che esprimono l'informazione in esso contenuta.";
const aminoText='Gli amminoacidi proteinogenici sono gli amminoacidi che vengono usati per la costruzione delle proteine.';
Map<String,dynamic> row(String id,String object,{String p='P527'})=>{
  'id':'$id\$$p-$object','rank':'normal','mainsnak':{'snaktype':'value','property':p,
    'datavalue':{'value':{'id':object},'type':'wikibase-entityid'}}};
class Sources318 {
  final bool amino,apiError,structuredError;
  final seen=<Uri>[];
  Sources318({this.amino=false,this.apiError=false,this.structuredError=false});
  Future<Map<String,dynamic>> call(Uri uri) async {
    seen.add(uri);final q=uri.queryParameters;
    if(uri.host=='it.wikipedia.org'){
      if(apiError)return {'error':{'code':'badvalue','info':'Fixture error'}};
      final id=amino?'Q500':'Q7239',title=amino?'Amminoacidi proteinogenici':'Organismo vivente';
      return {'query':{'redirects':[{'from':amino?'Amminoacido proteinogenico':'Organismo','to':title}],
        'pages':[{'pageid':1,'title':title,'extract':amino?aminoText:organismText,
          'fullurl':'https://it.wikipedia.org/wiki/${Uri.encodeComponent(title)}','pageprops':{'wikibase_item':id}}]}};
    }
    if(uri.host=='www.wikidata.org'){
      if(q['action']=='wbsearchentities')return {'search':amino?[]:[
        {'id':'Q7239','label':'organismo vivente','description':'entità dotata di vita','concepturi':'http://www.wikidata.org/entity/Q7239','match':{'type':'alias','text':'organismi viventi'},'aliases':['organismi viventi']},
        {'id':'Q4539','label':'società cooperativa','description':"società costituita per gestire in comune un'impresa",'concepturi':'http://www.wikidata.org/entity/Q4539','match':{'type':'alias','text':'organismi cooperativi'},'aliases':['organismi cooperativi']}]};
      if(q['action']=='wbgetentities'){
        if(structuredError)return {'error':{'code':'maxlag','info':'Replica not available'}};
        if(q['props']=='labels')return {'entities':{'Q7868':{'labels':{'it':{'value':amino?'amminoacido':'cellula'}}}}};
        final id=amino?'Q500':'Q7239';
        return {'entities':{id:{'lastrevid':123,'labels':{'it':{'value':amino?'amminoacido proteinogenico':'organismo vivente'}},
          'descriptions':{'it':{'value':amino?'amminoacido impiegato nelle proteine':'entità dotata di vita'}},
          'claims':{amino?'P279':'P527':[row(id,'Q7868',p:amino?'P279':'P527')]}}}};
      }
    }
    return {};
  }
}
void drain318(PlasticLanguageBrain04 b,MgdWorld06 w,ResearchMemory11 m){
  var n=0;while(ResearchSemantics317.getPending(m)>0&&n++<2000)ResearchSemantics317.processQueue(b,w,m);
  expect(ResearchSemantics317.getPending(m),0);
}
WebDocument11 doc318(String title,String text,{Map<String,dynamic> meta=const {}})=>WebDocument11(
  provider:'Wikipedia IT',family:'wikimedia',title:title,url:'https://it.wikipedia.org/wiki/${Uri.encodeComponent(title)}',text:text,trust:.84,meta318:meta);
void main(){
  test('actual 317 organism phrase now extracts its explicit source subject',(){
    final d=doc318('Organismo vivente',organismText);
    final xs=ResearchSemantics317.extractDocument318('Organismi',organismText,d,first:true);
    expect(xs,isNotEmpty);expect(xs.single.subject,'Organismo vivente');
    expect(ResearchSemantics317.evaluate(xs.single)['verdict'],'support');
    expect(xs.single.object,isNot('organizzazione'));
  });
  test('multiword singular and plural amino phrase match without prefix conflation',(){
    final xs=ResearchSemantics317.extract('Amminoacido proteinogenico',aminoText,doc318('Amminoacidi proteinogenici',aminoText));
    expect(xs,isNotEmpty);expect(ResearchSemantics317.evaluate(xs.single)['verdict'],'support');
    expect(ResearchSemantics317.sameSubject('Amminoacido proteinogenico','Amminoacidi proteinogenici'),true);
    expect(ResearchSemantics317.sameSubject('organismo','organizzazione'),false);
    expect(ResearchSemantics317.sameSubject('Amminoacidi proteinogenici','Amminoacidi non proteinogenici'),false);
  });
  test('full research path resolves Wikipedia redirect to QID and not first search label',()async{
    final src=Sources318();final ex=WebKnowledgeExplorer11(jsonLoader318:src.call);
    final draft=await ex.research(const ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1));
    expect(draft.error,isNull);expect(draft.documents,isNotEmpty);
    final structured=draft.claims.where((c)=>c.meta317['extractor']=='wikidata317').toList();
    expect(structured,isNotEmpty);expect(structured.every((c)=>c.subjectSenseKey=='wikidata:Q7239'),true);
    expect(structured.any((c)=>c.subjectSenseKey=='wikidata:Q4539'),false);
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    ex.integrate(b,w,m,draft);drain318(b,w,m);
    expect(m.claims.values.where((c)=>c.status=='documentata'),isNotEmpty);
    expect(m.evidence,isNotEmpty);expect(ResearchSemantics317.answer('Cosa sono gli organismi?',m),contains('Documentata da una fonte'));
    expect(src.seen.any((u)=>u.queryParameters['titles']?.contains('organismo')==true),true);
    expect(m.claims.values.any((c)=>c.subjectSenseKey=='wikidata:Q4539'),false);
  });
  test('empty Wikidata search does not discard a resolved Wikipedia identity',()async{
    final ex=WebKnowledgeExplorer11(jsonLoader318:Sources318(amino:true).call);
    final d=await ex.research(const ResearchGoal11(query:'Amminoacido proteinogenico',topic:'Amminoacido proteinogenico',reason:'test',value:1));
    expect(d.claims.where((c)=>c.subjectSenseKey=='wikidata:Q500'),isNotEmpty);
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();ex.integrate(b,w,m,d);drain318(b,w,m);
    expect(m.evidence,isNotEmpty);expect(m.claims.values.where((c)=>c.status=='documentata'),isNotEmpty);
    expect(ResearchSemantics317.answer('Cosa sono gli amminoacidi proteinogenici?',m),isNotNull);
  });
  test('HTTP 200 API errors are errors and remain visible in the session',()async{
    expect(()=>WebKnowledgeExplorer11.validateResponse318({'error':{'code':'maxlag'}}),throwsFormatException);
    final ex=WebKnowledgeExplorer11(jsonLoader318:Sources318(apiError:true,structuredError:true).call);
    final d=await ex.research(const ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1));
    expect(d.diagnostics318.where((x)=>x['status']=='errore'),isNotEmpty);
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();ex.integrate(b,w,m,d);drain318(b,w,m);
    expect(m.lastSession!.audit315['providerErrors'],greaterThan(0));
    expect(m.lastStatus,contains('Diagnostica ricerca'));
  });
  test('one unavailable structured provider does not discard prose evidence',()async{
    final ex=WebKnowledgeExplorer11(jsonLoader318:Sources318(structuredError:true).call);
    final d=await ex.research(const ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1));
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();ex.integrate(b,w,m,d);drain318(b,w,m);
    expect(m.claims.values.where((c)=>c.status=='documentata'),isNotEmpty);
    expect(d.diagnostics318.where((x)=>x['provider']=='Wikidata proprietà'&&x['status']=='errore'),isNotEmpty);
  });
  test('document queue and source serialization retain QID trust and redirect',(){
    final d=doc318('Organismo vivente',organismText,meta:{'wikidataId':'Q7239','resolvedTopic':true,'requestedTopic':'Organismi'});
    final restored=ResearchSemantics317.docFrom(jsonDecode(jsonEncode(ResearchSemantics317.docMap(d))));
    expect(restored.trust,d.trust);expect(restored.meta318,d.meta318);
    final m=ResearchMemory11(),b=PlasticLanguageBrain04(),w=MgdWorld06();
    ResearchSemantics317.enqueue(m,[restored],topic:'Organismi',session:'s');
    final back=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));drain318(b,w,back);
    expect(back.claims.values.single.subjectSenseKey,'wikidata:Q7239');
  });
  test('recovery re-reads saved zero-result 317 documents once without web',(){
    final m=ResearchMemory11(),b=PlasticLanguageBrain04(),w=MgdWorld06();
    final d=doc318('Amminoacidi proteinogenici',aminoText);
    final s=ResearchSession11(topic:'Amminoacido proteinogenico',query:'Amminoacido proteinogenico',reason:'old zero',startedAtIso:'old');
    s.audit315['documents']=[ResearchSemantics317.docMap(d)];m.sessions.add(s);
    m.state317['documentsRead']=[ResearchSemantics317.digest([ResearchSemantics317.canonicalUrl(d.url),d.text,ResearchSemantics317.concept(s.topic)])];
    expect(ResearchSemantics317.recoverTexts318(m),1);drain318(b,w,m);
    expect(m.claims.values.where((c)=>c.status=='documentata'),isNotEmpty);
    final n=m.evidence.length;expect(ResearchSemantics317.recoverTexts318(m),0);drain318(b,w,m);expect(m.evidence.length,n);
    expect(s.audit315['documents'],isNotEmpty);
  });
  test('passages outside retained audit are also recovered not erased',(){
    final m=ResearchMemory11(),b=PlasticLanguageBrain04(),w=MgdWorld06();
    m.passages.add(ResearchPassage11(id:'old',topic:'Amminoacido proteinogenico',provider:'Wikipedia IT',sourceFamily:'wikimedia',sourceTitle:'Amminoacidi proteinogenici',sourceUrl:'https://it.wikipedia.org/wiki/Amino',text:aminoText));
    expect(ResearchSemantics317.recoverTexts318(m),1);drain318(b,w,m);
    expect(m.passages.any((p)=>p.id=='old'),true);expect(m.evidence,isNotEmpty);
  });
  test('unknown syntax stays source text and zero result is not mislabeled success',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    final d=doc318('Organismo vivente','Le osservazioni richiedono ulteriori studi e non forniscono una definizione.');
    WebKnowledgeExplorer11().integrate(b,w,m,ResearchDraft11(goal:const ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1),documents:[d],claims:[],passages:[],sentencesRead:0));drain318(b,w,m);
    expect(m.claims,isEmpty);expect(m.evidence,isEmpty);expect(m.passages,isNotEmpty);
    expect(m.lastStatus,contains('nessuna proposizione interpretabile'));
    final view=MemoryInspector315(brain:b,world:w,research:m,language:MgdLanguage20());
    expect(view.metricRows('Documenti registrati').length,1);expect(view.metricRows('Diagnostica ricerca'),isNotEmpty);
  });
  test('source subjects are not renamed to unrelated search topic',(){
    final d=doc318('Società cooperativa',"La società cooperativa è una società costituita per gestire in comune un'impresa.");
    final xs=ResearchSemantics317.extractDocument318('Organismi',d.text,d,first:true);
    expect(xs.single.subject,'Società cooperativa');expect(xs.single.meta317['queryAliases318'],isNull);
  });
  test('qualifiers and polarity from same source are not collapsed in intake',(){
    final d=doc318('Organismi','');
    final xs=['Gli organismi sono organizzazioni.','Gli organismi non sono organizzazioni.'].expand((t)=>ResearchSemantics317.extract('Organismi',t,d)).toList();
    final out=WebKnowledgeExplorer11.dedupeClaimsForTest0311(xs);expect(out.length,2);
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    WebKnowledgeExplorer11().integrate(b,w,m,ResearchDraft11(goal:const ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1),documents:[],claims:out,passages:[],sentencesRead:0));
    expect(m.claims.values.single.status,'quarantena');
  });
  test('repeated whole research path is idempotent through restart',()async{
    final ex=WebKnowledgeExplorer11(jsonLoader318:Sources318().call);
    final d=await ex.research(const ResearchGoal11(query:'Organismi',topic:'Organismi',reason:'test',value:1));
    final b=PlasticLanguageBrain04(),w=MgdWorld06();var m=ResearchMemory11();ex.integrate(b,w,m,d);drain318(b,w,m);
    final n=m.evidence.length;final claims=m.claims.length;
    m=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    ex.integrate(b,w,m,d);drain318(b,w,m);expect(m.evidence.length,n);expect(m.claims.length,claims);
  });
  test('boot failure has protected retry screen rather than autosave of blank memory',(){
    final s=File('lib/main.dart').readAsStringSync();
    expect(s.replaceAll(RegExp(r'\s+'),''),contains('if(_bootError318!=null)'));expect(s,contains('Non sovrascrivo i dati con una memoria vuota'));
    final catchStart=s.indexOf('// A startup problem must not trap');
    final end=s.indexOf('  void _startMindTimer19',catchStart);
    expect(s.substring(catchStart,end),isNot(contains('_startMindTimer19();')));
    final lifecycle=s.substring(s.indexOf('  void didChangeAppLifecycleState'),s.indexOf('  Future<void> _save([String? label]'));
    expect(lifecycle.replaceAll(RegExp(r'\s+'),''),contains('if(!_ready||_bootError318!=null)return;'));
  });
}
