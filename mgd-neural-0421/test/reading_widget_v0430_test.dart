import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/learning_verification_page_v0428.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  testWidgets('new result shows readable entities and actual answer before expansion', (tester) async {
    final memory = ResearchMemory11();
    LearningVerification428.store(memory, {'mode': 'controlled', 'passed': 1, 'total': 1,
      'at': '', 'version': '0.42.10', 'results': [{
        'prompt': 'celzz0 contiene canzz0?', 'capability': 'application', 'passed': true,
        'reason': 'Esito tecnico', 'expected': 'si',
        'names': {'celzz0': 'Cellula A', 'canzz0': 'Canale A'},
        'answer': {'text': 'Sì. celzz0 contiene canzz0.\nPremesse e applicazione:\n1. fonte'},
      }]});
    await tester.pumpWidget(MaterialApp(home: LearningVerificationPage428(memory: memory,
        onRun: (_, __, ___) async => {}, onReview: (_) async {})));
    await tester.scrollUntilVisible(find.text('Cellula A contiene Canale A?'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('MGD: Sì. Cellula A contiene Canale A.'), findsOneWidget);
    expect(find.textContaining('celzz0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('custom reading accepts user questions and never displays an automatic score', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: LearningVerificationPage428(memory: ResearchMemory11(),
      onRun: (_, __, ___) async => {}, onReview: (_) async {},
      onCustom: (text, questions, _, __) async {
        calls++;
        expect(text, 'Quando vento è presente, telo si tende.');
        expect(questions, ['Se vento è presente, telo si tende?']);
        return {'mode': 'custom', 'version': '0.42.10', 'total': 1, 'at': '',
          'results': [{'prompt': questions.single, 'reason': 'Da valutare',
            'answer': {'text': 'Sì. telo si tende.'}, 'sources': [{'text': text}]}]};
      })));
    await tester.scrollUntilVisible(find.text('Prova un testo tuo'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Prova un testo tuo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Quando vento è presente, telo si tende.');
    await tester.enterText(find.byType(TextField).last, 'Se vento è presente, telo si tende?');
    await tester.ensureVisible(find.text('Leggi e rispondi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leggi e rispondi'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.scrollUntilVisible(find.text('Risposte al tuo testo'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 risposte da valutare'), findsOneWidget);
    expect(find.textContaining('prove superate'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
