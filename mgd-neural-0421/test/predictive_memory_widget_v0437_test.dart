import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/predictive_memory_page_v0437.dart';

void main() {
  testWidgets('Prediction probe is read-only and memory rehearsal saves', (tester) async {
    final brain = PlasticLanguageBrain04()..learnEvent('Il gatto dorme.');
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: PredictiveMemoryPage437(
        brain: brain, onSave: () async { saves++; })));
    expect(find.text('Previsioni apprese'), findsOneWidget);
    final exposures = brain.predictor437.exposures;
    await tester.enterText(find.byType(TextField), 'Il gatto');
    await tester.ensureVisible(find.text('Prevedi la prossima parola'));
    await tester.tap(find.text('Prevedi la prossima parola'));
    await tester.pump();
    expect(brain.predictor437.exposures, exposures);
    await tester.ensureVisible(find.text('Ripassa testi già osservati'));
    await tester.tap(find.text('Ripassa testi già osservati'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(brain.predictor437.exposures, greaterThan(exposures));
  });
}
