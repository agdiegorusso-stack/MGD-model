import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/learned_reader_v0324.dart';
import 'package:mgd_neuro_mobile/relational_memory_v0324.dart' as full;
import 'package:mgd_neuro_mobile/ablation_no_mgd_v0324.dart' as ablated;
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';

const geometry={'weight','memory','material','coherence','flux','active'};
List<Map<String,dynamic>> semanticRows(List<Map<String,dynamic>> rows)=>
  rows.map((r)=>Map<String,dynamic>.from(r)
    ..removeWhere((k,v)=>geometry.contains(k)||k=='at')).toList();
String stable(dynamic x)=>jsonEncode(x);
List<String> signatures(List<Map<String,dynamic>> rows)=>rows.map((r)=>
  '${r['agent']}|${r['relation']}|${r['patient']}|${r['negative']}|${r['sequence']}').toList();
List<dynamic> intake(dynamic x)=>[x.added,x.corrected,x.duplicate,x.unresolved,x.handled,x.message];
Map<String,dynamic>? prediction(ResearchMemory11 m,String question,bool useMgd) {
  final q=LearnedReader324.parse(question);
  if(q==null) return null;
  final rows=useMgd?full.RelationalMemory324.find(m,q):ablated.NoMgdMemory324.find(m,q);
  if(rows.length!=1) return null;
  final r=rows.single;
  return {'agent':r['agent'],'relation':r['relation'],'patient':r['patient'],'negative':r['negative']==true};
}
void main() {
 test('full relational MGD removal, stress, and sensitive positive control',() {
  final report=<String,dynamic>{};
  final dataset=jsonDecode(File('tool/relational_eval_v0324.json').readAsStringSync()) as Map;
  var fullGood=0,noMgdGood=0,pairedDifferences=0,restoreDifferences=0;
  final caseRows=<Map<String,dynamic>>[];
  for(final dynamic raw in dataset['cases']) {
    final c=Map<String,dynamic>.from(raw as Map);
    var a=ResearchMemory11(),b=ResearchMemory11();
    for(final text in c['history'] as List) {
      full.RelationalMemory324.learn(a,text);
      ablated.NoMgdMemory324.learn(b,text);
    }
    final pa=prediction(a,c['question'],true),pb=prediction(b,c['question'],false);
    final ga=stable(pa)==stable(c['expected']),gb=stable(pb)==stable(c['expected']);
    fullGood+=ga?1:0;noMgdGood+=gb?1:0;
    pairedDifferences+=stable(pa)!=stable(pb)?1:0;
    a=ResearchMemory11.fromJson(jsonDecode(jsonEncode(a.toJson())));
    b=ResearchMemory11.fromJson(jsonDecode(jsonEncode(b.toJson())));
    final restoredA=prediction(a,c['question'],true),restoredB=prediction(b,c['question'],false);
    restoreDifferences+=(stable(restoredA)!=stable(restoredB)||stable(restoredA)!=stable(pa))?1:0;
    caseRows.add({'id':c['id'],'category':c['category'],'mgd':pa,'withoutMgd':pb,
      'mgdCorrect':ga,'withoutMgdCorrect':gb});
  }
  report['pilot']={'cases':caseRows.length,'mgdCorrect':fullGood,'withoutMgdCorrect':noMgdGood,
    'pairedPredictionDifferences':pairedDifferences,'restoreDifferences':restoreDifferences,
    'accuracyDeltaPercentagePoints':100*(fullGood-noMgdGood)/caseRows.length};
  final stressRows=<Map<String,dynamic>>[];
  var comparisons=0,orderDiff=0,answerDiff=0,recordDiff=0,nonUniform=0;
  var successfulCorrections=0,added=0,duplicates=0,maxCandidates=0,noMgdGeometryFields=0;
  const rels=['insegue','aiuta','contiene','possiede'];
  for(var seed=0;seed<20;seed++) {
    final random=Random(932400+seed);
    var a=ResearchMemory11(),b=ResearchMemory11();
    void learn(String s) {
      final x=full.RelationalMemory324.learn(a,s),y=ablated.NoMgdMemory324.learn(b,s);
      expect(intake(x),intake(y));
      added+=x.added;duplicates+=x.duplicate;successfulCorrections+=x.corrected;
    }
    // Dense, competing candidates: the query does not collapse to one record.
    for(var k=0;k<40;k++) {
      learn('Il norvente insegue il talverio$k.');
    }
    // Unambiguous explicit correction and rejection of the superseded reimport.
    learn('Il solvario aiuta il morvenio.');
    learn('Correggi: Il solvario aiuta il felvario.');
    learn('Il solvario aiuta il morvenio.');
    for(var step=0;step<160;step++) {
      final agent='agente${random.nextInt(12)}';
      final patient='oggetto${random.nextInt(24)}';
      final rel=rels[random.nextInt(rels.length)];
      if(step%11==0) {
        final current=full.RelationalMemory324.rows(a,includeHistory:false);
        final r=current[random.nextInt(current.length)];
        final text='Il ${r['agent']} ${r['relation']} il nuovo${seed}x$step.';
        final x=full.RelationalMemory324.correct(a,r['id'],text);
        final y=ablated.NoMgdMemory324.correct(b,r['id'],text);
        expect(intake(x),intake(y));successfulCorrections+=x.corrected;
      } else if(step%13==0) {
        learn('Se il $agent $rel il $patient, la porta si apre.');
      } else {
        final neg=step%7==0?'non ':'';
        final text='Il $agent $neg$rel il $patient.';
        learn(text);
        if(step%5==0) learn(text);
      }
      final queries=[
        const Frame324('*','insegue','*','',question:true),
        Frame324(agent,rel,'*','',question:true),
        Frame324('*',rel,patient,'',question:true),
        Frame324(agent,rel,patient,'',question:true),
        const Frame324('norvente','insegue','*','',question:true),
        const Frame324('solvario','aiuta','*','',question:true),
      ];
      for(final q in queries) {
        final ra=full.RelationalMemory324.find(a,q),rb=ablated.NoMgdMemory324.find(b,q);
        comparisons++;
        if(stable(signatures(ra))!=stable(signatures(rb))) orderDiff++;
        maxCandidates=max(maxCandidates,ra.length);
      }
      for(final text in ['Chi insegue il talverio0?','Il norvente insegue chi?',
        'Il solvario aiuta il morvenio?','Il solvario aiuta chi?']) {
        if(full.RelationalMemory324.answer(a,text)!=ablated.NoMgdMemory324.answer(b,text)) answerDiff++;
      }
      if(step%20==0) {
        final ra=full.RelationalMemory324.rows(a);
        final rb=ablated.NoMgdMemory324.rows(b);
        if(stable(semanticRows(ra))!=stable(semanticRows(rb))) recordDiff++;
        final values=ra.where((r)=>r['status']=='current').map((r)=>
          stable([r['weight'],r['memory'],r['material'],r['coherence']])).toSet();
        if(values.length>1) nonUniform++;
        noMgdGeometryFields+=rb.where((r)=>geometry.any(r.containsKey)).length;
        a=ResearchMemory11.fromJson(jsonDecode(jsonEncode(a.toJson())));
        b=ResearchMemory11.fromJson(jsonDecode(jsonEncode(b.toJson())));
      }
    }
    stressRows.add({'seed':932400+seed,'currentRecords':full.RelationalMemory324.rows(a,includeHistory:false).length,
      'historyRecords':full.RelationalMemory324.rows(a).length});
  }
  report['stress']={'seeds':20,'stepsPerSeed':160,'orderedQueryComparisons':comparisons,
    'orderedQueryDifferences':orderDiff,'formattedAnswerDifferences':answerDiff,
    'semanticRecordDifferences':recordDiff,'nonUniformCurrentStates':nonUniform,
    'noMgdRecordsWithGeometry':noMgdGeometryFields,'successfulCorrections':successfulCorrections,
    'added':added,'duplicates':duplicates,'maxCompetingCandidates':maxCandidates,'seedsDetail':stressRows};
  // Sensitivity control: artificially unequal geometry must alter the full
  // ranking. This is NOT evidence of improved semantic accuracy.
  final control=ResearchMemory11();
  full.RelationalMemory324.learn(control,'Il norvente insegue il talverio.');
  full.RelationalMemory324.learn(control,'Il norvente insegue il felvario.');
  final records=full.RelationalMemory324.state(control)['records'] as Map;
  final first=records.values.first as Map;
  first['weight']=.05;first['memory']=1.0;first['material']=1.0;
  final noControl=ResearchMemory11.fromJson(jsonDecode(jsonEncode(control.toJson())));
  const q=Frame324('norvente','insegue','*','',question:true);
  final mgdOrder=signatures(full.RelationalMemory324.find(control,q));
  final chronologicalOrder=signatures(ablated.NoMgdMemory324.find(noControl,q));
  final sensitive=stable(mgdOrder)!=stable(chronologicalOrder);
  report['positiveControl']={'artificialGeometryChangesOrder':sensitive,
    'mgdOrder':mgdOrder,'chronologicalOrder':chronologicalOrder,
    'notAnAccuracyGain':true};
  report['scope']='RelationalMemory324 only. Identical reader, language rules and versioning. Full removal of its MGD evolve/strength; other app subsystems are not evaluated.';
  report['gateDecision']=fullGood>noMgdGood?'investigate_gain':'no_causal_accuracy_gain_do_not_claim_MGD_superiority';
  final output={'summary':report,'cases':caseRows};
  File('mgd-contribution-0324.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  final short=Map<String,dynamic>.from(report);
  short['stress']=Map<String,dynamic>.from(report['stress'] as Map)..remove('seedsDetail');
  print('CONTRIBUTION324 '+jsonEncode(short));
  expect(sensitive,isTrue,reason:'The assay must detect an actual ranking intervention.');
  expect(added,greaterThan(800));
  expect(successfulCorrections,greaterThan(20));
  expect(maxCandidates,greaterThanOrEqualTo(40));
  expect(noMgdGeometryFields,0);
  // These are hypotheses under test, not a superiority gate.
  expect(orderDiff,0);expect(answerDiff,0);expect(recordDiff,0);
  expect(nonUniform,0);expect(pairedDifferences,0);expect(restoreDifferences,0);
 },timeout:const Timeout(Duration(minutes:8)));
}
