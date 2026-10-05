import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  test('record frozen source-selection evaluation, including failures', () {
    final raw=File('tool/source_eval_v0323.json').readAsStringSync();
    final data=jsonDecode(raw) as Map;
    final results=<Map<String,dynamic>>[];
    for(final row in (data['cases'] as List).cast<Map>()) {
      final m=ResearchMemory11();
      final clock=Stopwatch()..start();
      var id=0;
      for(final d in (row['documents'] as List)) {
        id++;
        SourceMemory323.retain(m,WebDocument11(provider:'Evaluation',
          family:'eval',title:'Document '+id.toString(),
          url:'local://evaluation/'+id.toString(),text:d.toString(),trust:.5));
      }
      final intakeMicros=clock.elapsedMicroseconds;
      clock.reset();
      final hits=SourceMemory323.search(row['question'].toString(),m,limit:1);
      final elapsed=clock.elapsedMicroseconds;
      final selected=hits.isEmpty?0:int.parse(hits.single.url.split('/').last);
      final restored=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
      final replay=SourceMemory323.search(row['question'].toString(),restored,limit:1);
      final stable= (replay.isEmpty?0:int.parse(replay.single.url.split('/').last))==selected;
      results.add({
        'id':row['id'],'category':row['category'],'question':row['question'],
        'expected':row['expected'],'selected':selected,'correct':selected==row['expected'],
        'intakeMs':intakeMicros/1000,'queryMs':elapsed/1000,'restartStable':stable,
        'passage':hits.isEmpty?null:hits.single.text,
      });
    }
    final report={
      'system':'MGD application source memory 0.32.3 (lexical inverted index + BM25)',
      'scope':data['scope'],'datasetSha256':ResearchSemantics317.digest(data),
      'platform':Platform.operatingSystem,'total':results.length,
      'correct':results.where((r)=>r['correct']==true).length,'cases':results,
      'notMeasured':['General language generation','Implicit behavioral learning','Training a neural language model'],
    };
    File('source-eval-mgd-0.32.3.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report));
    print(jsonEncode({...report}..remove('cases')));
    expect(results,hasLength(24));
    expect(results.every((r)=>r['restartStable']==true),true);
  });
}
