import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';

// Explicit network regression, run separately from reproducible offline tests.
// Uses the production HTTP client, scheduler, acquisition, intake and storage.
void main() {
  test('real goals and migrated dialysis structure acquire and persist sourced readings', () async {
    HttpOverrides.global = null;
    final report = <Map<String, dynamic>>[];
    try {
      for (final scenario in ['la cellula', 'i microrganismi', 'la dialisi', 'dialisi-struttura-04210']) {
        final migrated = scenario == 'dialisi-struttura-04210';
        final topic = migrated ? 'la dialisi' : scenario;
        final m = ResearchMemory11();
        final b = PlasticLanguageBrain04(), w = MgdWorld06();
        StudyGoal426.start(m, topic);
        if (migrated) {
          final old = StudyGoal426.state(m)!;
          old['schema'] = 2;
          old['items'] = StudyGoal426.items(old)
              .where((i) => i['label'] == 'struttura').map((i) => {
                ...i, 'lookup': 'la dialisi struttura', 'attempts': 2, 'failures': 2,
                'nextAt': DateTime.now().add(const Duration(hours: 8)).toIso8601String(),
              }).toList();
          m.state317[StudyGoal426.key] = old;
        }
        final id = StudyGoal426.state(m)!['id'] as String;
        final goal = StudyGoal426.next(m)!;
        final explorer = WebKnowledgeExplorer11();
        final draft = await explorer.research(goal).timeout(const Duration(minutes: 3));
        explorer.integrate(b, w, m, draft);
        for (var i = 0; i < 10000 && ResearchSemantics317.getPending(m) > 0; i++) {
          ResearchSemantics317.processQueue(b, w, m);
        }
        StudyGoal426.record(m, id, goal, draft.documents,
            error: draft.error, diagnostics: draft.diagnostics318);
        final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
        final row = {
          'goal': topic, 'scenario': scenario, 'query': goal.query, 'lookup': goal.topic,
          'documents': draft.documents.map((d) => {
            'title': d.title, 'url': d.url, 'provider': d.provider,
            'characters': d.text.length,
          }).toList(),
          'readings': StudyGoal426.items(StudyGoal426.state(restored)!).first['documents'],
          'documented': m.claims.values.where((c) => c.status == 'documentata').length,
          'claims': m.claims.length,
          'sourceMemory': SourceMemory323.stats(restored),
          'pending': ResearchSemantics317.getPending(m),
          'error': draft.error, 'diagnostics': draft.diagnostics318,
        };
        report.add(row);
        print('LIVE427 ${jsonEncode(row)}');
        expect(draft.error, isNull, reason: jsonEncode(row));
        expect(row['readings'] as int, greaterThan(0));
        expect(SourceMemory323.stats(restored)['passages'], greaterThan(0));
        if (!migrated) expect(m.claims, isNotEmpty);
        expect(ResearchSemantics317.getPending(m), 0);
        if (migrated) {
          expect(goal.query, 'la dialisi struttura');
          expect(goal.topic, 'dialisi');
          expect(draft.documents.every((d) => d.meta318['studyArea431'] == 'struttura'), isTrue);
        }
      }
    } finally {
      final out = File('tool/reports/live-study-0.42.7.json');
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
