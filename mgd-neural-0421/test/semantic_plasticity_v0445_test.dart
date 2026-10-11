import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/own_reader_v0443.dart';
import '../lib/semantic_plasticity_v0445.dart';
import '../lib/neural_reading_v0439.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('source supervision rejects negative, hypothetical and embedded definitions', () {
    expect(SemanticPlasticity445.explicitDefinitions('«zanfra» significa «consegna».'),hasLength(1));
    for (final text in ['«zanfra» non significa «consegna».',
      'Se «zanfra» significa «consegna», Anna parte.',
      'Nessuno sa se «zanfra» significa «consegna».',
      'Marco sostiene che «zanfra» significa «consegna».']) {
      expect(SemanticPlasticity445.explicitDefinitions(text),isEmpty);
    }
  });
  test('persistent numerical input weights transfer an observed definition to unseen frames', () async {
    final base = await OwnReader443.load(), reader = base.withSemanticState(null);
    const text = 'Anna zanfra il libro a Marco oggi.';
    const query = 'A chi zanfra Anna il libro?';
    final before = reader.answer(text,query), fingerprint = reader.plasticity!.fingerprint();
    final state = reader.learnFromSources([{'rid439':'definition','text':'«zanfra» significa «consegna».'}]);
    expect(reader.plasticity!.fingerprint(),isNot(fingerprint));
    expect(state['definitionSteps'],greaterThan(0));
    expect((state['definitionLossAfter'] as num),lessThan((state['definitionLossBefore'] as num)));
    final after = reader.answer(text,query);
    expect(before['unknown']==true || before['answer']!='Marco',true);
    expect(after['unknown'],false); expect(after['answer'],'Marco');
    final restored = base.withSemanticState(jsonDecode(jsonEncode(state)) as Map);
    expect(restored.answer(text,query)['answer'],'Marco');
    // New people and a new object were never part of the learning targets.
    expect(restored.answer('Giulia zanfra la cartella a Paolo oggi.',
      'A chi zanfra Giulia la cartella?')['answer'],'Paolo');
    final same = restored.plasticity!.fingerprint();
    restored.learnFromSources([{'rid439':'definition','text':'«zanfra» significa «consegna».'}]);
    expect(restored.plasticity!.fingerprint(),same);
  });
  test('observed next words update the same input vectors on ordinary prose', () async {
    final base = await OwnReader443.load(), reader = base.withSemanticState(null);
    final before = reader.plasticity!.fingerprint();
    final state = reader.learnFromSources([{'rid439':'prose','text':
      'Anna legge il libro. Marco legge il libro. Giulia legge il libro. Paolo legge il libro.'}]);
    expect(state['predictionSteps'],greaterThan(0));
    expect(reader.plasticity!.fingerprint(),isNot(before));
    expect(state['definitionSteps'],0);
    // A change in next-word loss is not labeled semantic comprehension.
    expect(state['predictionLossBefore'],isA<num>()); expect(state['predictionLossAfter'],isA<num>());
  });
  test('conflicting source definitions suspend the learned interpretation and deletion removes influence', () async {
    final base = await OwnReader443.load(), reader = base.withSemanticState(null);
    reader.learnFromSources([{'rid439':'a','text':'«zanfra» significa «consegna».'}]);
    final state = reader.learnFromSources([{'rid439':'b','text':'«zanfra» significa «distrugge».'}]);
    expect(state['conflicts'],contains('zanfra'));
    expect(reader.answer('Anna zanfra il libro a Marco.', 'A chi zanfra Anna il libro?')['unknown'],true);
    final clean = SemanticPlasticity445.surviving(state,{'b'},32);
    expect(clean['weights'],isEmpty); expect(clean['processed'],isEmpty);
  });
  test('production study saves actual weights, reload uses them and answers cite the teaching passage', () async {
    final memory = ResearchMemory11();
    SourceMemory323.retain(memory,WebDocument11(provider:'Test',family:'local',title:'Glossario',url:'local://glossario',
      text:'«zanfra» significa «consegna».',trust:.9));
    NeuralReading439.enabled=true;
    try {
      expect(await NeuralReading439.examineNext(memory),true);
      expect(NeuralReading439.semanticState(memory)['definitionSteps'],greaterThan(0));
      final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(memory.toJson())));
      SourceMemory323.retain(restored,WebDocument11(provider:'Test',family:'local',title:'Episodio nuovo',url:'local://episodio',
        text:'Anna zanfra il libro a Marco oggi.',trust:.9));
      final original = jsonEncode(restored.toJson());
      final answer = await NeuralReading439.answer(restored,'A chi zanfra Anna il libro?');
      expect(answer,isNotNull); expect(answer!.text,contains('Marco'));
      expect(answer.text,contains('local://glossario'));
      expect(answer.proof['semanticWeightsPlastic'],true);
      expect(answer.proof['learningEvidence'],isNotEmpty);
      expect(answer.proof['semanticValidation'],false);
      expect(jsonEncode(restored.toJson()),original);
    } finally { NeuralReading439.enabled=false; }
  });
  test('a retired teaching source during the next learning job prevents committing its influence', () async {
    final memory = ResearchMemory11();
    SourceMemory323.retain(memory,WebDocument11(provider:'Test',family:'local',title:'Glossario',url:'local://teacher',
      text:'«zanfra» significa «consegna».',trust:.9));
    NeuralReading439.enabled=true;
    try {
      expect(await NeuralReading439.examineNext(memory),true);
      SourceMemory323.retain(memory,WebDocument11(provider:'Test',family:'local',title:'Nuovo',url:'local://new',
        text:'Anna legge il libro.',trust:.9));
      var calls=0;
      final changed = await NeuralReading439.examineNext(memory,shouldContinue:() {
        calls++;
        if (calls==2) SourceMemory323.forget33(memory,(s)=>s.contains('local://teacher'));
        return true;
      });
      expect(changed,false);
      expect(NeuralReading439.semanticState(memory)['weights'],isEmpty);
    } finally { NeuralReading439.enabled=false; }
  });
  test('bounded lexical transfer audit reports all failures and retention separately', () async {
    final base = await OwnReader443.load(), reader = base.withSemanticState(null);
    // Declared before the first CI run; these are artificial single-word
    // equivalences and short frames, not an independent general-text corpus.
    const aliases = ['blunfa','crelpa','drunfa','felpa','glunza','hufra','klonfa','lufpa','melza','norfra',
      'plunfa','prenza','quelfa','rufna','slunfa','trefpa','ulnfa','vrunza','welpa','zulfa'];
    final cases = <Map<String,dynamic>>[];
    for (final word in aliases) {
      cases.add({'word':word,'text':'Giulia $word la cartella a Paolo oggi.',
        'query':'A chi $word Giulia la cartella?','expected':'Paolo'});
      cases.add({'word':word,'text':'Anna $word il libro a Marco oggi.',
        'query':'Chi $word il libro a Marco?','expected':'Anna'});
    }
    bool correct(Map result, Map c) => result['unknown']==false && result['answer']==c['expected'];
    final before = [for (final c in cases) reader.answer(c['text'] as String,c['query'] as String)];
    final refs = (jsonDecode(File('tool/fixtures/runtime-reference443.json').readAsStringSync()) as List).whereType<Map>().toList();
    final retainedBefore = [for (final c in refs) reader.answer('${c['text']}','${c['query']}')];
    final state = reader.learnFromSources([for (final word in aliases)
      {'rid439':'definition:$word','text':'«$word» significa «consegna».'}]);
    final after = [for (final c in cases) reader.answer(c['text'] as String,c['query'] as String)];
    final retainedAfter = [for (final c in refs) reader.answer('${c['text']}','${c['query']}')];
    final results = {
      'protocol':'20 explicit equivalences, 40 untrained frames; artificial lexical transfer only',
      'general_comprehension_solved':false,'generated_answers_used_for_training':false,
      'total':cases.length,'before':List.generate(cases.length,(i)=>correct(before[i],cases[i])).where((x)=>x).length,
      'after':List.generate(cases.length,(i)=>correct(after[i],cases[i])).where((x)=>x).length,
      'cases':[for (var i=0;i<cases.length;i++) {...cases[i],'before':before[i],'after':after[i],
        'before_correct':correct(before[i],cases[i]),'after_correct':correct(after[i],cases[i])}],
      'retention_compares_predictions_not_truth':true,
      'retention_total':refs.length,'retention_changed':[for (var i=0;i<refs.length;i++)
        if (retainedBefore[i]['unknown']!=retainedAfter[i]['unknown'] || retainedBefore[i]['answer']!=retainedAfter[i]['answer'])
          {'text':refs[i]['text'],'query':refs[i]['query'],'before':retainedBefore[i],'after':retainedAfter[i]}],
      'definition_loss_before':state['definitionLossBefore'],'definition_loss_after':state['definitionLossAfter'],
      'prediction_loss_before':state['predictionLossBefore'],'prediction_loss_after':state['predictionLossAfter'],
    };
    Directory('tool/reports').createSync(recursive:true);
    File('tool/reports/semantic-learning445.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
    expect((results['after'] as int),greaterThan(results['before'] as int));
    expect(results['retention_changed'],isEmpty);
  });
}
