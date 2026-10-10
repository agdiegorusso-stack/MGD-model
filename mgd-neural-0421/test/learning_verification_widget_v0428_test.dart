import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/learning_verification_page_v0428.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  testWidgets('assessment card opens and preserves scope of source and control scores', (tester) async {
    final memory = ResearchMemory11();
    StudyGoal426.start(memory, 'la cellula');
    LearningVerification428.store(memory, {'mode': 'sources',
      'goalId': StudyGoal426.state(memory)!['id'], 'passed': 2, 'total': 8, 'results': []});
    LearningVerification428.store(memory, {'mode': 'controlled', 'passed': 4, 'total': 28, 'results': []});
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LearningVerificationCard428(
      memory: memory, busy: false, onOpen: () { opened = true; }))));
    expect(find.textContaining('2/8'), findsOneWidget);
    expect(find.textContaining('4/28'), findsOneWidget);
    await tester.tap(find.text('Verifica ciò che ha letto'));
    expect(opened, true);
    StudyGoal426.start(memory, 'i microrganismi');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LearningVerificationCard428(
      memory: memory, busy: true, onOpen: () { fail('Busy action must not fire'); }))));
    expect(find.textContaining('ancora da verificare'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
  testWidgets('mobile page runs source check and exposes expected answer and original passage', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final memory = ResearchMemory11();
    final q = const VerificationCase428(id: 'x', capability: 'recall',
      prompt: 'Che cosa contiene Alfa?', expected: 'Alfa — contiene → canale',
      subject: 'Alfa', relation: 'contiene', object: 'canale',
      sources: [{'title': 'Documento originale', 'text': 'Alfa contiene canale.', 'url': 'local://alfa'}]);
    await tester.pumpWidget(MaterialApp(home: LearningVerificationPage428(memory: memory,
      onRun: (mode, cancelled, progress) async {
        final report = await LearningVerification428.run(mode: mode, seed: 4,
          cases: [q], query: (_) async => const VerificationAnswer428('Nessuna risposta.', 'cognitivo'),
          cancelled: cancelled, progress: progress);
        LearningVerification428.store(memory, report);
        return report;
      }, onReview: (_) async {})));
    await tester.tap(find.text('Avvia verifica').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(q.prompt), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(q.prompt));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Risposta attesa:'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Alfa — contiene → canale'), findsOneWidget);
    expect(find.textContaining('Documento originale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('old source report cannot enqueue gaps into a different goal', (tester) async {
    final memory = ResearchMemory11();
    StudyGoal426.start(memory, 'la cellula');
    LearningVerification428.store(memory, {'mode': 'sources', 'goalId': 'old',
      'passed': 0, 'total': 1, 'at': '', 'version': '0.42.8',
      'results': [{'capability': 'recall', 'passed': false, 'claimKey': 'x',
        'subject': 'Altro', 'prompt': 'Domanda', 'expected': 'risposta', 'answer': {}}]});
    await tester.pumpWidget(MaterialApp(home: LearningVerificationPage428(memory: memory,
      onRun: (_, __, ___) async => {}, onReview: (_) async { fail('Wrong goal'); })));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Studia le lacune rilevate'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
