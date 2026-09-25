import 'dart:convert';
import 'dart:io';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
Future<void> main() async {
  final report=<Map<String,dynamic>>[];
  for(final topic in ['Organismi','Amminoacido proteinogenico']){
    final explorer=WebKnowledgeExplorer11();
    final d=await explorer.research(ResearchGoal11(query:topic,topic:topic,reason:'live end-to-end regression',value:1)).timeout(const Duration(minutes:3));
    final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
    explorer.integrate(b,w,m,d);
    for(var n=0;n<10000&&ResearchSemantics317.getPending(m)>0;n++)ResearchSemantics317.processQueue(b,w,m);
    final counts={'topic':topic,'documents':d.documents.length,'claims':m.claims.length,'documented':m.claims.values.where((c)=>c.status=='documentata').length,'evidence':m.evidence.length,'pending':ResearchSemantics317.getPending(m),'error':d.error};
    print(jsonEncode(counts));
    report.add({...counts,'diagnostics':d.diagnostics318,'memory':m.toJson(),'answer':ResearchSemantics317.answer('Cosa sono $topic?',m)});
  }
  await File('live-0318.json').writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  if(report.any((r)=>(r['documented'] as int)==0 || r['pending']!=0))throw StateError('A live topic still has zero documented knowledge; see diagnostics.');
}
