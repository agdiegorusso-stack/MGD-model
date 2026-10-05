import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/learned_reader_v0324.dart';
import 'package:mgd_neuro_mobile/relational_memory_v0324.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';

void main() {
 test('frozen reader and memory ablation, one exposure and corrections',() {
   final dataset=jsonDecode(File('tool/relational_eval_v0324.json').readAsStringSync()) as Map;
   final results=<Map<String,dynamic>>[];
   final summary=<String,dynamic>{};
   for(final mgd in [true,false]) {
     var correct=0,restoredCorrect=0;
     final times=<int>[],learningTimes=<int>[];
     final categories=<String,List<int>>{};
     for(final dynamic raw in dataset['cases']) {
       final c=Map<String,dynamic>.from(raw as Map);
       var m=ResearchMemory11();
       final learnClock=Stopwatch()..start();
       for(final text in c['history'] as List) {RelationalMemory324.learn(m,text as String);}
       learningTimes.add(learnClock.elapsedMicroseconds);
       Map<String,dynamic>? prediction(ResearchMemory11 memory) {
         final q=LearnedReader324.parse(c['question']);
         if(q==null) return null;
         final candidates=RelationalMemory324.find(memory,q,mgd:mgd);
         if(candidates.length!=1) return null;
         final r=candidates.single;
         return {'agent':r['agent'],'relation':r['relation'],'patient':r['patient'],
           'negative':r['negative']==true};
       }
       final clock=Stopwatch()..start();
       final p=prediction(m);times.add(clock.elapsedMicroseconds);
       final good=jsonEncode(p)==jsonEncode(c['expected']);
       if(good) correct++;
       m=ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
       final restored=jsonEncode(prediction(m))==jsonEncode(c['expected']);
       if(restored) restoredCorrect++;
       final counts=categories.putIfAbsent(c['category'],()=>[0,0]);
       counts[0]+=good?1:0;counts[1]++;
       results.add({'id':c['id'],'mode':mgd?'MGD':'simple','prediction':p,
         'expected':c['expected'],'correct':good,'restored':restored});
     }
     times.sort();learningTimes.sort();
     summary[mgd?'MGD':'simple']={'correct':correct,'total':times.length,
       'afterRestore':restoredCorrect,'queryMedianMicros':times[times.length~/2],
       'queryP95Micros':times[(times.length*.95).floor()],
       'learnMedianMicros':learningTimes[learningTimes.length~/2],
       'categories':categories};
   }
   final out={'scope':dataset['scope'],'summary':summary,'cases':results,
     'mgdContribution':'The ablation changes geometric ordering only; versioning, reader and facts are identical. Equal accuracy is evidence of no added accuracy on this task, not superiority.',
     'training':LearnedReader324.model['training']};
   File('relational-eval-0.32.4.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
   print('RELATIONAL324 '+jsonEncode(summary));
   // This run measures all cases. Accuracy is reported, not forced to 100%.
 });
}
