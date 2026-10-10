import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10);
  final text = 'La cellula è l’unità fondamentale degli organismi viventi. '
      'La cellula ha una membrana che separa il citoplasma dall’ambiente esterno. '
      'Le cellule contengono materiale genetico e svolgono funzioni metaboliche.';
  Future<Map<String, dynamic>> loader(Uri u) async {
    if (u.host == 'it.wikipedia.org') {
      return {'query': {'pages': [{
        'title': 'Cellula', 'extract': text,
        'fullurl': 'https://it.wikipedia.org/wiki/Cellula',
        'pageprops': <String, dynamic>{},
      }]}};
    }
    return <String, dynamic>{};
  }

  test('goal acquires a resolved subject without requiring the whole plan label', () async {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la cellula', now: now);
    final goal = StudyGoal426.next(m, now: now)!;
    expect(goal.topic, 'Cellula');
    expect(goal.query, 'la cellula struttura e tipi cellulari');
    final explorer = WebKnowledgeExplorer11(jsonLoader318: loader);
    final draft = await explorer.research(goal);
    expect(draft.error, isNull);
    expect(draft.documents, isNotEmpty);
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    explorer.integrate(b, w, m, draft);
    while (ResearchSemantics317.getPending(m) > 0) {
      ResearchSemantics317.processQueue(b, w, m);
    }
    StudyGoal426.record(m, StudyGoal426.state(m)!['id'], goal,
        draft.documents, error: draft.error, diagnostics: draft.diagnostics318, now: now);
    expect(StudyGoal426.items(StudyGoal426.state(m)!).first['documents'], greaterThan(0));
    expect(m.lastSession!.documents, greaterThan(0));
    expect(SourceMemory323.stats(m)['passages'], greaterThan(0));
    final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(StudyGoal426.items(StudyGoal426.state(restored)!).first['documents'], greaterThan(0));
  });

  test('empty acquisition is an error with provider diagnostics', () async {
    final explorer = WebKnowledgeExplorer11(jsonLoader318: (u) async => {});
    final draft = await explorer.research(const ResearchGoal11(
      query: 'Cellula', topic: 'Cellula', reason: 'test', value: 1));
    expect(draft.documents, isEmpty);
    expect(draft.error, contains('Nessun documento pertinente'));
    expect(draft.diagnostics318, isNotEmpty);
  });

  test('failure retries after one minute despite research query history', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la cellula', now: now);
    final g = StudyGoal426.state(m)!;
    g['items'] = [StudyGoal426.items(g).first];
    m.state317[StudyGoal426.key] = g;
    final goal = StudyGoal426.next(m, now: now)!;
    m.begin(goal.query, now);
    StudyGoal426.record(m, g['id'], goal, const [], error: 'offline', now: now);
    expect(StudyGoal426.next(m, now: now.add(const Duration(seconds: 45))), isNull);
    expect(StudyGoal426.next(m, now: now.add(const Duration(minutes: 1))), isNotNull);
    StudyGoal426.retry(m);
    expect(StudyGoal426.next(m, now: now), isNotNull);
  });

  test('existing zero-reading goal migrates without clearing memory or pause', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la cellula', now: now);
    final g = StudyGoal426.state(m)!;
    g.remove('schema');
    final all = StudyGoal426.items(g);
    for (final item in all) {
      item.remove('lookup');
      item['attempts'] = 1;
      item['failures'] = 1;
      item['nextAt'] = now.add(const Duration(hours: 8)).toIso8601String();
      m.begin(StudyGoal426.query(g, item), now);
    }
    g['items'] = all;
    g['paused'] = true;
    m.state317[StudyGoal426.key] = g;
    m.state317['unrelatedMemory'] = 'preserved';
    StudyGoal426.upgrade(m);
    expect(StudyGoal426.next(m, now: now), isNull);
    StudyGoal426.pause(m, false);
    expect(StudyGoal426.next(m, now: now)!.topic, 'Cellula');
    expect(m.state317['unrelatedMemory'], 'preserved');
    expect(StudyGoal426.state(m)!['id'], g['id']);
    expect(StudyGoal426.items(StudyGoal426.state(m)!).first['attempts'], 1);
    expect(m.queryLastIso, isEmpty);
  });

  test('seed lookup subjects differ by area and discovered concepts keep their name', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la cellula', now: now);
    final first = StudyGoal426.next(m, now: now)!;
    StudyGoal426.record(m, StudyGoal426.state(m)!['id'], first, const [], now: now);
    final second = StudyGoal426.next(m, now: now)!;
    expect(second.topic, 'Membrana cellulare');
    expect(second.topic, isNot(first.topic));
    StudyGoal426.start(m, 'i microrganismi', now: now);
    expect(StudyGoal426.next(m, now: now)!.topic, 'Microrganismo');
    StudyGoal426.start(m, 'i numeri complessi', now: now);
    expect(StudyGoal426.next(m, now: now)!.topic, 'numeri complessi');
  });
}
