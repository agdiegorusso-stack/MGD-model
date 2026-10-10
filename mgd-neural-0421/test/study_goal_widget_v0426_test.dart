import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/study_goal_page_v0426.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  testWidgets('goal dialog forwards command topic and pause resumes stored plan',
      (tester) async {
    final memory = ResearchMemory11();
    String? started;
    bool? paused;
    Future<void> render() => tester.pumpWidget(MaterialApp(home: Scaffold(
      body: StudyGoalCard426(memory: memory, busy: false,
        onStart: (s) async { started = s; StudyGoal426.start(memory, s); },
        onPause: (p) async { paused = p; StudyGoal426.pause(memory, p); },
        onRetry: () async {}))));
    await render();
    await tester.tap(find.text('Nuovo obiettivo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),
        'Studiami tutto ciò che riguarda la cellula');
    await tester.tap(find.text('Avvia studio'));
    await tester.pumpAndSettle();
    expect(started, 'la cellula');
    await render();
    await tester.tap(find.text('Pausa'));
    await tester.pumpAndSettle();
    expect(paused, true);
    await render();
    expect(find.text('Riprendi'), findsOneWidget);
    expect(find.textContaining('comprensione ancora da verificare'), findsOneWidget);
  });

  testWidgets('failed source acquisition is visible and retry is actionable', (tester) async {
    final memory = ResearchMemory11();
    StudyGoal426.start(memory, 'la cellula');
    final goal = StudyGoal426.next(memory)!;
    StudyGoal426.record(memory, StudyGoal426.state(memory)!['id'], goal,
        const [], error: 'Wikipedia IT: HTTP 503',
        diagnostics: [{'provider': 'Wikipedia IT', 'status': 'errore', 'error': 'HTTP 503'}]);
    var retried = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: StudyGoalCard426(memory: memory, busy: false,
        onStart: (_) async {}, onPause: (_) async {},
        onRetry: () async { retried = true; })))));
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    expect(find.text('Esito delle fonti'), findsOneWidget);
    await tester.ensureVisible(find.text('Riprova ora'));
    await tester.tap(find.text('Riprova ora'));
    expect(retried, isTrue);
    expect(StudyGoal426.items(StudyGoal426.state(memory)!).first['documents'], 0);
  });
}
