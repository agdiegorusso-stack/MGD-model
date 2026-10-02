import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/narrative_memory_v0350.dart';
import 'package:mgd_neuro_mobile/competence_language_v0350.dart';
import 'package:mgd_neuro_mobile/book_understanding_v0342.dart';

void main() {
  test('development evaluation keeps every reference and every failure', () {
    final data = jsonDecode(
        File('tool/fixtures/closed_book_development_0350.json')
            .readAsStringSync()) as Map;
    final results = <Map<String, dynamic>>[],
        latencies = <int>[],
        rawHashes = <String>[];
    int correct = 0,
        answerable = 0,
        answerableCorrect = 0,
        wrong = 0,
        unknownCorrect = 0,
        unknown = 0,
        conflicts = 0,
        oldCorrect = 0,
        rawBytes = 0,
        eventBytes = 0,
        usageBytes = 0,
        parsed = 0,
        unparsed = 0;
    for (final book in data['books'] as List) {
      final text = book['text'] as String,
          c = NarrativeCompiler350().compile(text, unitOrdinal: 0);
      rawHashes.add(digest350(text));
      rawBytes += utf8.encode(text).length;
      eventBytes += utf8
          .encode(jsonEncode(c.events.map((e) => e.toJson()).toList()))
          .length;
      usageBytes += utf8.encode(jsonEncode(c.language.counts)).length;
      parsed += c.events.length;
      unparsed += c.issues.entries
          .where((e) => e.key != 'chapter_heading')
          .fold<int>(0, (a, e) => a + e.value);
      final engine = ClosedBookEngine350(
          c.events, {'id': book['id'], 'title': book['title']});
      final oldRows = text
          .split(RegExp(r'(?<=[.!?])\s+|\n+'))
          .asMap()
          .entries
          .map((e) => <String, dynamic>{
                'id': '${book['id']}:${e.key}',
                'text': e.value,
                'title': book['title'],
                'url': 'local://book/${book['id']}/${e.key}'
              })
          .toList();
      final old = BookEngine342(oldRows);
      for (final q in book['cases'] as List) {
        final reference = List<String>.from(q['answers'] as List),
            expectation = q['expected'];
        final out = engine.answer(q['question'] as String,
            assumptions: q['assumptions'] as String);
        final o = old.answer(q['question'] as String,
            assumptions: q['assumptions'] as String);
        bool score(String status, String answer) => expectation == 'unknown'
            ? status == 'unknown'
            : expectation == 'conflict'
                ? status == 'conflict'
                : {'direct', 'deduction'}.contains(status) &&
                    reference.any((a) =>
                        BookExam342.normalize(a) ==
                        BookExam342.normalize(answer));
        final ok = score('${out['status']}', '${out['answer']}'),
            oldOk = score(o.status, o.answer);
        if (ok) correct++;
        if (oldOk) oldCorrect++;
        if (expectation == 'answer') {
          answerable++;
          if (ok) answerableCorrect++;
        }
        if (expectation == 'unknown') {
          unknown++;
          if (ok) unknownCorrect++;
        }
        if (expectation == 'conflict' && ok) conflicts++;
        if (!ok && {'direct', 'deduction'}.contains(out['status'])) wrong++;
        results.add({
          'book': book['title'],
          'case': q,
          'result': out,
          'correct': ok,
          'oldArchiveReader': o.toJson(),
          'oldCorrect': oldOk
        });
        expect(out['rawPassagesRead'], 0);
        // Warm-query timing is diagnostic, not a claim about the user's phone.
        final timer = Stopwatch()..start();
        for (var i = 0; i < 5; i++) {
          engine.answer(q['question'] as String,
              assumptions: q['assumptions'] as String);
        }
        timer.stop();
        latencies.add(timer.elapsedMicroseconds ~/ 5);
      }
    }
    final learner = CompetenceLanguage350(), grammar = <Map<String, dynamic>>[];
    for (final text in data['grammarTraining'] as List) {
      learner.apply(
          NarrativeCompiler350().compile('$text', unitOrdinal: 0).language);
    }
    int grammarCorrect = 0, retained = 0;
    final before = jsonEncode(learner.counts);
    for (final pair in data['grammarPairs'] as List) {
      final items = ['${pair['incorrect']}', '${pair['correct']}'];
      final empty = CompetenceLanguage350().compare(items),
          r = learner.compare(items);
      final ok = r['best'] == pair['correct'];
      if (ok) grammarCorrect++;
      grammar.add({'case': pair, 'result': r, 'correct': ok, 'empty': empty});
    }
    expect(jsonEncode(learner.counts), before);
    final later = NarrativeCompiler350()
        .compile(
            'Luca legge il giornale. Le ragazze aprono il cofanetto. Il cassetto è rosso.',
            unitOrdinal: 0)
        .language;
    learner.apply(later);
    for (final g in grammar) {
      final pair = g['case'] as Map,
          r = learner.compare(['${pair['incorrect']}', '${pair['correct']}']);
      g['afterSecondReading'] = r;
      if (g['correct'] == true && r['best'] == pair['correct']) retained++;
    }
    learner.apply(later, sign: -1);
    expect(jsonEncode(learner.counts), before);
    latencies.sort();
    final report = {
      'version': '0.35.0',
      'label': data['label'],
      'sourceHashes': rawHashes,
      'total': results.length,
      'correct': correct,
      'answerable': answerable,
      'correctAnswerable': answerableCorrect,
      'wrongProduced': wrong,
      'unknown': unknown,
      'correctUnknown': unknownCorrect,
      'correctConflicts': conflicts,
      'oldArchiveCorrect': oldCorrect,
      'events': parsed,
      'unparsedUnits': unparsed,
      'rawPassagesRead': 0,
      'results': results,
      'grammar': {
        'trainingSentences': (data['grammarTraining'] as List).length,
        'total': grammar.length,
        'correct': grammarCorrect,
        'retainedAfterSecondReading': retained,
        'rows': grammar
      },
      'storage': {
        'rawUtf8Bytes': rawBytes,
        'eventJsonBytes': eventBytes,
        'usageJsonBytes': usageBytes,
        'note':
            'Structured representations can occupy more bytes than short source texts. No claim of guaranteed byte compression.'
      },
      'warmQueryMicros': {
        'median': latencies[latencies.length ~/ 2],
        'p95': latencies[((latencies.length - 1) * .95).round()],
        'environment':
            'Flutter host process, five warm calls per case; not phone or energy measurement'
      }
    };
    final path = Platform.environment['MGD_CLOSED_EVAL_OUT'] ??
        'benchmark-closed-0.35.0.json';
    File(path)
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    print(
        'CLOSED350 answerable=$answerableCorrect/$answerable unknown=$unknownCorrect/$unknown wrongProduced=$wrong oldArchiveCorrect=$oldCorrect/${results.length} grammar=$grammarCorrect/${grammar.length} retained=$retained/$grammarCorrect rawReads=0');
    expect(results.length,
        45); // Every authored case remains present, including failures.
  });
}
