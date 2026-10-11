import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/own_reader_v0443.dart';
import '../lib/neural_reading_v0439.dart';
import '../lib/reading_memory_v0438.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('learned own weights are portable: Python and Dart probabilities agree', () async {
    final reader=await OwnReader443.load();
    expect(reader.model['transformer'],false);
    expect(reader.model['learned_entity_factorization'],true);
    final references=jsonDecode(File('tool/fixtures/runtime-reference443.json').readAsStringSync()) as List;
    for (final row in references.whereType<Map>()) {
      final actual=reader.inspect('${row['text']}'), expected=row['inspection'] as Map;
      expect(actual['tokens'],expected['tokens']);
      final a=actual['scopeDistribution'] as List, b=expected['scope_distribution'] as List;
      for (var i=0;i<a.length;i++) { expect(a[i],closeTo((b[i] as num).toDouble(),1e-8)); }
      final q=reader.inspect('${row['query']}'), eq=row['question'] as Map;
      expect(q['questionType'],eq['question_type']);
      expect(q['questionConfidence'],closeTo((eq['question_confidence'] as num).toDouble(),1e-8));
      final answer=reader.answer('${row['text']}','${row['query']}'), answerPython=row['answer'] as Map;
      expect(answer['unknown'],answerPython['unknown']);
      if (answerPython['unknown']==false) {
        expect(answer['answer'],contains(answerPython['answer']));
        expect(answer['scope'],answerPython['scope']);
      }
    }
  });
  test('a reference binds to a learned span and preserves planned rather than completed', () async {
    final reader=await OwnReader443.load();
    const text='Anna consegna il libro a Marco. Marco promette di restituirlo domani.';
    final events=reader.events(text), answer=reader.answer(text,'Che cosa promette di restituire Marco?');
    expect(answer['unknown'],false);expect(answer['answer'],contains('il libro'));
    expect(answer['scope'],'planned');
    expect(events.last['sourceSentences'],contains('Anna consegna il libro a Marco.'));
    expect((events.last['spans'] as List).whereType<Map>().any((s)=>s['resolvedFrom']=='restituirlo'),true);
  });
  test('production reader cites the original context and never makes its own answer a fact', () async {
    final memory=ResearchMemory11();
    SourceMemory323.retain(memory,WebDocument11(provider:'Test',family:'local',title:'Prestito',url:'local://prestito',
      text:'Anna consegna il libro a Marco. Marco promette di restituirlo domani.',trust:.9));
    final before=jsonEncode(memory.toJson());NeuralReading439.enabled=true;
    try {
      final answer=await NeuralReading439.answer(memory,'Che cosa promette di restituire Marco?');
      expect(answer,isNotNull);expect(answer!.text,contains('il libro'));
      expect(answer.text,contains('local://prestito'));expect(answer.proof['semanticValidation'],false);
      expect(answer.proof['weightsUpdated'],false);expect(jsonEncode(memory.toJson()),before);
    } finally { NeuralReading439.enabled=false; }
  });
}
