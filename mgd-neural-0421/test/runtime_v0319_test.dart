import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/memory_runtime_v0319.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/knowledge_inspector_v0315.dart';

({PlasticLanguageBrain04 brain,MgdWorld06 world}) fixture319([int count=16]) {
  final b=PlasticLanguageBrain04(),w=MgdWorld06();
  for(var n=0;n<count;n++) {
    final subject='Entità numero $n',object='Categoria ${n%4}';
    b.importTeacherFact08(subject:subject,relation:'tipo di',object:object,confidence:.85,source:'fixture319');
    final a=b.ensureSemanticEntity06(subject),z=b.ensureSemanticEntity06(object);
    w.importTeacherSemanticLink08(a,z,.55,confidence:.60);
  }
  return (brain:b,world:w);
}
Map<String,dynamic> binaryRoundtrip319(Map<String,dynamic> input) {
  dynamic norm(dynamic x) {
    if(x is Map)return <String,dynamic>{for(final e in x.entries)e.key.toString():norm(e.value)};
    if(x is List)return x.map(norm).toList();
    return x;
  }
  const codec=StandardMessageCodec();
  return norm(codec.decodeMessage(codec.encodeMessage(input))) as Map<String,dynamic>;
}
void main() {
  test('baseline think propagates but does not evolve imported priors: regression reproduced',(){
    final f=fixture319();
    final before=jsonEncode(f.world.edges.values.map((e)=>e.toJson()).toList());
    f.world.think(f.brain,cycles:24);
    expect(f.world.thoughtCycles,24);
    expect(jsonEncode(f.world.edges.values.map((e)=>e.toJson()).toList()),before);
    expect(f.world.entropicAge,0);
  });
  test('native runtime advances bounded geometry without manufacturing confirmations',(){
    final f=fixture319();
    final before=jsonEncode(f.brain.slots.values.map((s)=>s.toJson()).toList());
    final episodes=f.brain.episodes.length;
    final oldCosts={for(final e in f.world.edges.entries)e.key:e.value.cost};
    expect(MemoryRuntime319.pulse(f.brain,f.world,budget:4),4);
    final changed=f.world.edges.entries.where((e)=>e.value.cost!=oldCosts[e.key]).length;
    expect(changed,4);
    expect(f.world.thoughtCycles,2);
    expect(f.world.runtime319['replayedTotal'],4);
    expect(jsonEncode(f.brain.slots.values.map((s)=>s.toJson()).toList()),before);
    expect(f.brain.episodes.length,episodes);
    for(var n=0;n<12;n++)MemoryRuntime319.pulse(f.brain,f.world,budget:4);
    expect(f.world.stats().activeEdges,greaterThan(0));
    expect(f.world.entropicAge,greaterThan(0));
    expect(jsonEncode(f.brain.slots.values.map((s)=>s.toJson()).toList()),before);
  });
  test('hypotheses and review candidates are not replayed as established facts',(){
    final f=fixture319(2);
    for(final s in f.brain.slots.values)for(final c in s.candidates.values)c.epistemicStatus='hypothesis';
    final costs=jsonEncode(f.world.edges.values.map((e)=>e.toJson()).toList());
    expect(MemoryRuntime319.pulse(f.brain,f.world),0);
    expect(jsonEncode(f.world.edges.values.map((e)=>e.toJson()).toList()),costs);
    for(final s in f.brain.slots.values)for(final c in s.candidates.values)c.epistemicStatus='review';
    expect(MemoryRuntime319.pulse(f.brain,f.world),0);
  });
  test('empty memory remains empty rather than fabricated to populate counters',(){
    final b=PlasticLanguageBrain04(),w=MgdWorld06();
    expect(MemoryRuntime319.pulse(b,w),0);
    expect(w.edges,isEmpty);
    expect(b.concepts,isEmpty);
    expect(w.entropicAge,0);
  });
  test('concept discovery runs after imported facts and preserves its threshold',(){
    final f=fixture319(16);
    expect(f.brain.concepts,isEmpty);
    MemoryRuntime319.pulse(f.brain,f.world);
    expect(f.brain.concepts,isNotEmpty);
    final ids=f.brain.concepts.map((c)=>c.id).toList();
    MemoryRuntime319.pulse(f.brain,f.world);
    expect(f.brain.concepts.map((c)=>c.id),ids);
    expect(f.brain.concepts.every((c)=>c.entityIds.length>=2&&c.coherence>=.45),true);
  });
  test('binary roundtrip preserves exact native age cycles edges cursor and learned facts',(){
    final f=fixture319(24);
    for(var n=0;n<8;n++)MemoryRuntime319.pulse(f.brain,f.world);
    final b=PlasticLanguageBrain04.fromJson(binaryRoundtrip319(f.brain.toJson()));
    final w=MgdWorld06.fromJson(binaryRoundtrip319(f.world.toJson()));
    expect(w.toJson(),f.world.toJson());
    expect(b.cognitiveFacts06().length,f.brain.cognitiveFacts06().length);
    expect(b.episodes.length,f.brain.episodes.length);
    expect(b.concepts.map((c)=>c.toJson()).toList(),f.brain.concepts.map((c)=>c.toJson()).toList());
    MemoryRuntime319.pulse(b,w);
    expect(w.thoughtCycles,f.world.thoughtCycles+2);
    expect(w.entropicAge,greaterThanOrEqualTo(f.world.entropicAge));
  });
  test('old world snapshot migrates without resetting its counters or edges',(){
    final f=fixture319();f.world.thoughtCycles=240;f.world.entropicAge=9.11;
    final data=f.world.toJson()..remove('runtime319');
    final w=MgdWorld06.fromJson(binaryRoundtrip319(data));
    expect(w.thoughtCycles,240);expect(w.entropicAge,9.11);
    expect(w.edges.length,f.world.edges.length);
    MemoryRuntime319.pulse(f.brain,w);
    expect(w.thoughtCycles,242);expect(w.entropicAge,greaterThanOrEqualTo(9.11));
  });
  test('checkpoint snapshots all memories and concurrent saves drain to newest state',()async{
    final f=fixture319();final r=ResearchMemory11(),l=MgdLanguage20();
    final entered=Completer<void>(),release=Completer<void>();
    final writes=<Map<String,Map<String,dynamic>>>[];
    final cp=MemoryCheckpoint319(write:(data)async{
      writes.add(data);
      if(writes.length==1){entered.complete();await release.future;}
    });
    final first=cp.save(f.brain,f.world,r,l);
    await entered.future;
    MemoryRuntime319.pulse(f.brain,f.world);
    l.ingestText('La cellula è una struttura biologica.');
    final last=cp.save(f.brain,f.world,r,l);
    release.complete();await Future.wait([first,last]);
    expect(writes.length,2);
    expect(writes.last.keys,containsAll(['brain_v051','world_v06','research_v11','language_v20','checkpoint_v0319']));
    expect(writes.last['world_v06']!['thoughtCycles'],f.world.thoughtCycles);
    expect(writes.last['checkpoint_v0319']!['languageSentences'],l.sentences);
  });
  test('failed checkpoint propagates the error and permits an explicit later retry',()async{
    final f=fixture319();var fail=true;var written=0;
    final cp=MemoryCheckpoint319(write:(data)async{if(fail)throw StateError('disk failure');written++;});
    await expectLater(cp.save(f.brain,f.world,ResearchMemory11(),MgdLanguage20()),throwsStateError);
    fail=false;
    await cp.save(f.brain,f.world,ResearchMemory11(),MgdLanguage20());
    expect(written,1);
  });
  test('reading 2400 imported facts remains bounded to eight geometric rehearsals',(){
    final f=fixture319(2400),r=ResearchMemory11(),l=MgdLanguage20();
    final before=f.brain.cognitiveFacts06().length;
    final sw=Stopwatch()..start();
    MemoryRuntime319.pulse(f.brain,f.world,budget:8);
    sw.stop();
    expect(f.world.runtime319['lastReplayed'],8);
    expect(f.brain.cognitiveFacts06().length,before);
    final inspector=MemoryInspector315(brain:f.brain,world:f.world,research:r,language:l);
    expect(inspector.metricRows('Archi mondo').length,f.world.stats().worldEdges);
    expect(inspector.metricRows('Archi attivi').length,f.world.stats().activeEdges);
    expect(inspector.metricRows('Fatti cognitivi').length,before);
    print('RUNTIME319 fixture2400 pulse_ms=${sw.elapsedMilliseconds} facts=$before edges=${f.world.edges.length}');
  });
  testWidgets('narrative link list renders subject relation object rather than Elemento',(tester)async{
    final r=ResearchMemory11();
    r.narrativeLinks.add(NarrativeLink24(episodeId:'e24:1',from:'atomo',relation:'co-presente',to:'molecola',confidence:.5,source:'fonte test'));
    final i=MemoryInspector315(brain:PlasticLanguageBrain04(),world:MgdWorld06(),research:r,language:MgdLanguage20());
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:()=>i.openMetric(context,'Legami narrativi'),child:const Text('Apri'))))));
    await tester.tap(find.text('Apri'));await tester.pumpAndSettle();
    expect(find.text('atomo — co-presente → molecola'),findsOneWidget);
    expect(find.text('Elemento'),findsNothing);
    await tester.tap(find.text('atomo — co-presente → molecola'));await tester.pumpAndSettle();
    expect(find.textContaining('fonte test'),findsWidgets);
  });
}
