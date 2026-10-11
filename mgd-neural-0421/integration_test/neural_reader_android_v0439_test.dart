import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mgd_neuro_mobile/neural_reading_v0439.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled native model reads new sources, answers and reloads on Android', (tester) async {
    NeuralReading439.enabled = true;
    final memory = ResearchMemory11();
    SourceMemory323.retain(memory, WebDocument11(provider: 'Testo nuovo',
      family: 'local', title: 'Racconto nuovo', url: 'local://android-test', trust: .9,
      text: 'Giulia mise la chiave nel cassetto. Poi spostò il libro sul tavolo.'));
    final examined = await NeuralReading439.examineNext(memory);
    expect(examined, true, reason: NeuralReading439.status);
    expect(NeuralReading439.notes(memory), isNotEmpty, reason: NeuralReading439.status);
    final before = jsonEncode(memory.toJson());
    var answer = await NeuralReading439.answer(memory, 'Dove si trova la chiave?');
    expect(answer, isNotNull, reason: NeuralReading439.status);
    expect(answer!.text.toLowerCase(), contains('cassetto'));
    expect(answer.proof['unknown'], false);
    expect(answer.proof['passages'], isNotEmpty);
    expect(jsonEncode(memory.toJson()), before);
    await NeuralReading439.close();
    answer = await NeuralReading439.answer(memory, 'Dove si trova la chiave?');
    expect(answer, isNotNull, reason: NeuralReading439.status);
    expect(answer!.text.toLowerCase(), contains('cassetto'));
    expect(memory.claims, isEmpty);
    expect(jsonEncode(memory.toJson()), before);
    await NeuralReading439.close();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
