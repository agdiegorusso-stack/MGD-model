import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/learning_verification_v0428.dart';
import '../lib/verification_reader_v0428.dart';
import '../lib/study_goal_v0426.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';

// Explicit network regression, run separately from reproducible offline tests.
// Uses the production HTTP client, scheduler, acquisition, intake and storage.
void main() {
  sqfliteFfiInit();
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
          expect(draft.documents.any((d) => d.provider == 'Wikipedia IT' &&
              d.meta318['resolvedTopic'] == true), isTrue,
              reason: 'The root article content must be read; bibliographic title matches are insufficient.');
        }
      }
      // Regression for 0.42.11's 6/8 readings + empty source assessment.
      // Use one persistent goal through every seed area, then restore and query
      // its real memory. No test question or reference answer is ever taught.
      final m = ResearchMemory11();
      final b = PlasticLanguageBrain04(), w = MgdWorld06();
      final now = DateTime.now();
      StudyGoal426.start(m, 'la dialisi', now: now);
      final id = '${StudyGoal426.state(m)!['id']}';
      final areas = <Map<String, dynamic>>[];
      final explorer = WebKnowledgeExplorer11();
      for (var index = 0; index < 8; index++) {
        final goal = StudyGoal426.next(m, now: now)!;
        final draft = await explorer.research(goal).timeout(const Duration(minutes: 3));
        explorer.integrate(b, w, m, draft);
        for (var j = 0; j < 10000 && ResearchSemantics317.getPending(m) > 0; j++) {
          ResearchSemantics317.processQueue(b, w, m);
        }
        StudyGoal426.record(m, id, goal, draft.documents,
            error: draft.error, diagnostics: draft.diagnostics318, now: now);
        StudyGoal426.expand(m, id, draft);
        final row = {'area': goal.contextTerms.last, 'query': goal.query,
          'error': draft.error, 'documents': draft.documents.map((d) => {
            'provider': d.provider, 'title': d.title, 'url': d.url,
            'characters': d.text.length, 'excerpt': d.text.substring(0, d.text.length.clamp(0, 350).toInt()),
            'aliases': d.meta318['topicAliases432'],
          }).toList(), 'diagnostics': draft.diagnostics318};
        areas.add(row);
        print('AREA432 ${jsonEncode(row)}');
      }
      final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
      final cases = LearningVerification428.sourceCases(restored, 432);
      final coreReader = await VerificationReader428.open(factory: databaseFactoryFfi,
          temporaryRoot: Directory.systemTemp.path);
      late Map<String, dynamic> assessment;
      try {
        final frozen = jsonEncode(restored.toJson());
        assessment = await LearningVerification428.run(mode: 'sources', seed: 432,
            goalId: id, topic: 'la dialisi', cases: cases,
            query: (q) => MemoryQuery428.answer(b, restored, q, coreReader.core));
        expect(jsonEncode(restored.toJson()), frozen,
            reason: 'Assessments must not add questions/answer keys to retained learning.');
      } finally { await coreReader.close(); }
      final row = <String, dynamic>{'goal': 'la dialisi', 'scenario': 'dialisi-piano-fonti',
        'areas': areas, 'eligible': LearningVerification428.sourceClaims432(restored).length,
        'readings': StudyGoal426.items(StudyGoal426.state(restored)!)
            .where((i) => StudyGoal426.count(i, 'documents') > 0).length,
        'pending': ResearchSemantics317.getPending(restored), 'assessment': assessment};
      report.add(row);
      print('LIVE427 ${jsonEncode(row)}');
      expect(areas.map((a) => a['area']).toSet().length, 8);
      final scientific = areas.firstWhere((a) => a['area'] == 'evidenze scientifiche');
      expect((scientific['documents'] as List).whereType<Map>().any((d) =>
          d['provider'] == 'Europe PMC' && (d['characters'] as int) >= 80), isTrue,
          reason: 'Scientific area must read relevant abstract content from Europe PMC, not titles.');
      expect(assessment['total'], greaterThan(0), reason: jsonEncode(row));
      expect(assessment['passed'], greaterThan(0), reason: jsonEncode(assessment));
      expect(ResearchSemantics317.getPending(restored), 0);
    } finally {
      final out = File('tool/reports/live-study-0.42.7.json');
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    }
  }, timeout: const Timeout(Duration(minutes: 24)));
}
