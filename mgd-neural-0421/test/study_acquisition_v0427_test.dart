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

  // Provider fixtures test acquisition and scheduling, not medical knowledge.
  const intro431 = 'La dialisi è il soggetto di questa scheda introduttiva di prova. '
      'Il testo iniziale identifica l’argomento e non descrive le altre aree del piano.';
  const structure431 = '== Struttura ==\n'
      'Questa sezione della scheda di prova descrive le parti del sistema. '
      'Il paragrafo completo viene conservato insieme alla fonte e al suo titolo.';
  const mechanism431 = '== Principio di funzionamento ==\n'
      'Questa sezione distinta della scheda di prova descrive un principio. '
      'Il suo contenuto è diverso dall’introduzione e dalla sezione precedente.';
  ResearchMemory11 structureGoal431() {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la dialisi', now: now);
    final g = StudyGoal426.state(m)!;
    g['items'] = [StudyGoal426.items(g).firstWhere((i) => i['label'] == 'struttura')];
    m.state317[StudyGoal426.key] = g;
    return m;
  }
  Future<ResearchDraft11> acquire431(ResearchGoal11 goal, String article,
      {List<Uri>? requests, String title = 'Dialisi'}) async {
    return WebKnowledgeExplorer11(jsonLoader318: (uri) async {
      requests?.add(uri);
      if (uri.host == 'it.wikipedia.org' && uri.queryParameters['titles'] != null &&
          uri.queryParameters['titles']!.split('|').any((s) => s.toLowerCase() == 'dialisi')) {
        return {'query': {'pages': [{
          'title': title, 'extract': article, 'fullurl': 'https://example.org/fixture431',
          'pageprops': <String, dynamic>{},
        }]}};
      }
      return <String, dynamic>{};
    }).research(goal);
  }

  test('dialysis structure uses root identity and reads its full section', () async {
    final m = structureGoal431();
    final goal = StudyGoal426.next(m, now: now)!;
    final requests = <Uri>[];
    expect(goal.query, 'la dialisi struttura');
    expect(goal.topic, 'dialisi');
    final draft = await acquire431(goal, '$intro431\n\n$structure431\n\n$mechanism431',
        requests: requests);
    expect(draft.error, isNull);
    expect(draft.documents, hasLength(1));
    expect(draft.documents.single.text, contains('parti del sistema'));
    expect(draft.documents.single.text, isNot(contains('scheda introduttiva')));
    expect(draft.documents.single.text, isNot(contains('sezione distinta')));
    expect(requests.where((u) => u.host == 'it.wikipedia.org'), isNotEmpty);
    expect(requests.where((u) => u.host == 'it.wikipedia.org')
        .every((u) => !u.queryParameters.containsKey('exintro')), isTrue);
    expect(draft.documents.single.meta318['studyArea431'], 'struttura');
    StudyGoal426.record(m, StudyGoal426.state(m)!['id'], goal, draft.documents,
        error: draft.error, now: now);
    final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(StudyGoal426.items(StudyGoal426.state(restored)!).single['documents'], 1);
    expect(StudyGoal426.state(restored)!['lastArea'], 'struttura');
  });

  test('generic areas cannot be filled by the same root introduction', () async {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la dialisi', now: now);
    final id = StudyGoal426.state(m)!['id'];
    for (var j = 0; j < 8; j++) {
      final goal = StudyGoal426.next(m, now: now)!;
      final draft = await acquire431(goal, intro431);
      StudyGoal426.record(m, id, goal, draft.documents, error: draft.error, now: now);
    }
    final read = StudyGoal426.items(StudyGoal426.state(m)!)
        .where((i) => StudyGoal426.count(i, 'documents') > 0).toList();
    expect(read, hasLength(1));
    expect(read.single['label'], 'definizioni');
  });

  test('missing generic area keeps zero readings and the next area advances', () async {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'la dialisi', now: now);
    final g = StudyGoal426.state(m)!;
    g['items'] = StudyGoal426.items(g)
        .where((i) => ['struttura', 'meccanismi'].contains(i['label'])).toList();
    m.state317[StudyGoal426.key] = g;
    final first = StudyGoal426.next(m, now: now)!;
    final missing = await acquire431(first, '$intro431\n\n$mechanism431');
    expect(missing.documents, isEmpty);
    expect(missing.claims, isEmpty);
    expect(missing.error, isNotNull);
    expect(missing.diagnostics318.any((d) => d['status'] == 'area non trattata'), isTrue);
    m.begin(first.query, now);
    StudyGoal426.record(m, g['id'], first, missing.documents, error: missing.error, now: now);
    final next = StudyGoal426.next(m, now: now)!;
    expect(next.query, 'la dialisi meccanismi');
    final found = await acquire431(next, '$intro431\n\n$mechanism431');
    expect(found.error, isNull);
    StudyGoal426.record(m, g['id'], next, found.documents, error: found.error, now: now);
    expect(StudyGoal426.items(StudyGoal426.state(m)!).first['documents'], 0);
    expect(StudyGoal426.next(m, now: now.add(const Duration(minutes: 1)))!.query, first.query);
  });

  test('0.42.10 blocked generic goal migrates retaining acquired readings and id', () {
    final m = structureGoal431();
    final g = StudyGoal426.state(m)!;
    g['schema'] = 2;
    g['paused'] = true;
    g['lastError'] = 'Nessun documento pertinente';
    g['hashes'] = ['retained'];
    final all = StudyGoal426.items(g);
    all.single.addAll({'lookup': 'la dialisi struttura', 'attempts': 4, 'failures': 4,
      'nextAt': now.add(const Duration(hours: 8)).toIso8601String()});
    g['items'] = [
      {...all.single, 'label': 'definizioni', 'lookup': 'dialisi',
        'documents': 2, 'novel': 2, 'families': ['wikimedia'],
        'failures': 0, 'lastError': null},
      ...all,
    ];
    m.state317[StudyGoal426.key] = g;
    m.begin('la dialisi struttura', now);
    m.state317['unrelatedMemory'] = 'preserved';
    StudyGoal426.upgrade(m);
    expect(StudyGoal426.next(m, now: now), isNull);
    StudyGoal426.pause(m, false);
    final restored = ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(StudyGoal426.next(restored, now: now)!.topic, 'dialisi');
    expect(StudyGoal426.state(restored)!['id'], g['id']);
    expect(StudyGoal426.state(restored)!['hashes'], ['retained']);
    final restoredItems = StudyGoal426.items(StudyGoal426.state(restored)!);
    expect(restoredItems.last['attempts'], 4);
    expect(restoredItems.first['documents'], 2);
    expect(restoredItems.first['families'], ['wikimedia']);
    expect(restored.state317['unrelatedMemory'], 'preserved');
  });

  test('generic fallback still rejects unrelated resolved search results', () async {
    final goal = StudyGoal426.next(structureGoal431(), now: now)!;
    // A search result must not be marked as an exact resolution of the root.
    final draft = await WebKnowledgeExplorer11(jsonLoader318: (uri) async {
      if (uri.host == 'it.wikipedia.org' && uri.queryParameters['generator'] == 'search') {
        return {'query': {'pages': [{
          'title': 'Orologio', 'extract': structure431,
          'fullurl': 'https://example.org/clock', 'pageprops': <String, dynamic>{},
        }]}};
      }
      return <String, dynamic>{};
    }).research(goal);
    expect(draft.documents, isEmpty);
    expect(draft.error, isNotNull);
    expect(draft.diagnostics318.any((d) => d['status'] == 'fuori argomento'), isTrue);
  });

  test('section selection applies to other roots and preserves discovered identity', () {
    final m = ResearchMemory11();
    StudyGoal426.start(m, 'i numeri complessi', now: now);
    final g = StudyGoal426.state(m)!;
    g['items'] = StudyGoal426.items(g).where((i) => i['label'] == 'struttura').toList();
    m.state317[StudyGoal426.key] = g;
    expect(StudyGoal426.next(m, now: now)!.topic, 'numeri complessi');
    expect(StudyGoal426.next(m, now: now)!.facetTerms431, contains('struttur'));
    const rootDoc = WebDocument11(provider: 'test', family: 'test',
      title: 'Numeri complessi', url: 'https://example.org/numbers',
      text: 'I numeri complessi sono l’argomento di questa scheda di prova.', trust: .8);
    StudyGoal426.expand(m, g['id'], ResearchDraft11(
      goal: StudyGoal426.next(m, now: now)!, documents: [rootDoc],
      claims: [const ExtractedClaim11(subject: 'Numeri complessi', relation: 'è',
        object: 'argomento', sentence: 'I numeri complessi sono l’argomento.',
        source: rootDoc, quality: .9)], passages: const [], sentencesRead: 1));
    expect(StudyGoal426.items(StudyGoal426.state(m)!), hasLength(1));
    g['items'] = [{...StudyGoal426.items(g).single,
      'label': 'Piano complesso', 'lookup': 'Piano complesso', 'discoveredFrom': 'https://example.org'}];
    m.state317[StudyGoal426.key] = g;
    expect(StudyGoal426.next(m, now: now)!.topic, 'Piano complesso');
    expect(StudyGoal426.next(m, now: now)!.facetTerms431, isEmpty);
    expect(WebKnowledgeExplorer11.facetText431(intro431, ['struttur']), isEmpty);
  });
}
