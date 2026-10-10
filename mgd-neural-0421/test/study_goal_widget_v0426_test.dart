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
        onPause: (p) async { paused = p; StudyGoal426.pause(memory, p); }))));
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
}
