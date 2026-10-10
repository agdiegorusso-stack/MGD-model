import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  final t = DateTime.utc(2026, 10, 10);
  WebDocument11 doc(String text) => WebDocument11(provider: 'test',
    family: 'independent-test', title: 'Biologia cellulare',
    url: 'https://example.org/cell', text: text, trust: .8);
  String passage(String suffix) => List.filled(30, 'La cellula ha una membrana.').join(' ') + suffix;

  test('commands create topic, ordinary questions stay in chat', () {
    expect(StudyGoal426.command('Studiami tutto ciò che riguarda la cellula.'), 'la cellula');
    expect(StudyGoal426.command('Studia tutto quello che riguarda i microrganismi'), 'i microrganismi');
    expect(StudyGoal426.command('Cos’è la cellula?'), isNull);
  });
  test('goal and progress survive actual research JSON roundtrip', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'cellula', now: t);
    final q = StudyGoal426.next(m, now: t)!;
    StudyGoal426.record(m, StudyGoal426.state(m)!['id'], q, [doc(passage('A'))], now: t);
    final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(StudyGoal426.state(restored), StudyGoal426.state(m));
    expect(StudyGoal426.next(restored, now: t)!.query, isNot(q.query));
  });
  test('paused goal blocks research without deleting progress', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'cellula', now: t);
    StudyGoal426.pause(m, true);
    expect(StudyGoal426.next(m, now: t), isNull);
    StudyGoal426.pause(m, false);
    expect(StudyGoal426.next(m, now: t), isNotNull);
  });
  test('identical text is counted as novel once, changed text is novel', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'cellula', now: t);
    final id = StudyGoal426.state(m)!['id'] as String;
    final q = StudyGoal426.next(m, now: t)!;
    StudyGoal426.record(m, id, q, [doc(passage('A')), doc(passage('A'))], now: t);
    StudyGoal426.record(m, id, q, [doc(passage('B'))], now: t.add(const Duration(hours: 4)));
    final i = StudyGoal426.items(StudyGoal426.state(m)!).firstWhere((i) => q.query.endsWith(i['label']));
    expect(i['novel'], 2);
    expect(i['families'], ['independent-test']);
    expect(StudyGoal426.summary(m), contains('comprensione ancora da verificare'));
  });
  test('no result means retry, never completed or mastered', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'cellula', now: t);
    final id = StudyGoal426.state(m)!['id'] as String;
    for (var j = 0; j < 10; j++) {
      final q = StudyGoal426.next(m, now: t)!;
      StudyGoal426.record(m, id, q, const [], error: 'offline', now: t);
    }
    expect(StudyGoal426.next(m, now: t), isNull);
    expect(StudyGoal426.next(m, now: t.add(const Duration(days: 7))), isNotNull);
    expect(StudyGoal426.state(m)!.containsKey('completed'), isFalse);
  });
  test('a stale session cannot update a replacement goal', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'cellula', now: t);
    final id = StudyGoal426.state(m)!['id'] as String;
    final q = StudyGoal426.next(m, now: t)!;
    StudyGoal426.start(m, 'microrganismi', now: t.add(const Duration(seconds: 1)));
    StudyGoal426.record(m, id, q, [doc(passage('A'))], now: t);
    expect(StudyGoal426.items(StudyGoal426.state(m)!).every((i) => i['attempts'] == 0), isTrue);
    expect(m.state317['studyGoalHistory426'], hasLength(1));
  });
}
