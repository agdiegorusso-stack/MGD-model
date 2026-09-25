import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';

void main() {
  test('live Bioma reading diagnostic, reported separately from offline regressions', () async {
    final report=<String,dynamic>{'topic':'Bioma','status':'running'};
    final client=HttpClient()..connectionTimeout=const Duration(seconds:20);
    try {
      final uri=Uri.https('it.wikipedia.org','/w/api.php',{
        'action':'query','format':'json','prop':'extracts','explaintext':'1',
        'exintro':'1','redirects':'1','titles':'Bioma'});
      final request=await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader,'MGD-Neuro/0.32.3 source-reading-validation');
      final response=await request.close().timeout(const Duration(seconds:30));
      if(response.statusCode!=200) throw HttpException('Wikipedia HTTP '+response.statusCode.toString());
      final json=jsonDecode(await utf8.decoder.bind(response).join());
      final page=(json['query']['pages'] as Map).values.whereType<Map>().first;
      final text=page['extract'].toString();
      if(text.trim().isEmpty) throw StateError('Empty extract');
      final d=WebDocument11(provider:'Wikipedia IT',family:'wikimedia',
        title:page['title'].toString(),url:'https://it.wikipedia.org/wiki/Bioma',
        text:text,trust:.85);
      final b=PlasticLanguageBrain04(),w=MgdWorld06(),m=ResearchMemory11();
      WebKnowledgeExplorer11().integrate(b,w,m,ResearchDraft11(
        goal:const ResearchGoal11(topic:'Bioma',query:'Bioma',reason:'live diagnostic',value:1),
        documents:[d],claims:[],passages:[],sentencesRead:0));
      while(ResearchSemantics317.getPending(m)>0) ResearchSemantics317.processQueue(b,w,m);
      final structured=ResearchSemantics317.answer('Che cosa è un bioma?',m);
      final quoted=SourceMemory323.answer('Che cosa è un bioma?',m);
      report.addAll({'status':'completed','source':d.url,
        'documentCharacters':text.length,'structuredAnswer':structured,
        'sourceAnswer':quoted,'claims':m.claims.values.map((c)=>c.toJson()).toList(),
        'sourceMemory':SourceMemory323.stats(m)});
    } catch(e) {
      report.addAll({'status':'failed','error':e.toString()});
    } finally {
      client.close(force:true);
      File('live-bioma-0.32.3.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      print('LIVE323 '+jsonEncode(report));
    }
    // Network availability is reported, not substituted with a fixture.
  });
}
