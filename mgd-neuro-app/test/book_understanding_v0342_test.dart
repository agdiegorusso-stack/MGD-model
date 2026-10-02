import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/book_understanding_v0342.dart';
import '../lib/book_lab_service_v0342.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/sensory_world_v06.dart';

List<Map<String, dynamic>> book(List<String> texts,
        {String title = 'Manuale', String identity = 'abc'}) =>
    List.generate(
        texts.length,
        (i) => {
              'id': '$identity:$i',
              'text': texts[i],
              'title': title,
              'url': 'local://book/$identity/$i',
              'provider': 'Test'
            });
Map<String, dynamic> examCase(String q, List<String> answers,
        {String expected = 'answer',
        String hypotheses = '',
        List<String> support = const []}) =>
    {
      'id': q,
      'question': q,
      'expected': expected,
      'answers': answers,
      'assumptions': hypotheses,
      'support': support,
      'category': 'test',
      'origin': 'external_reference'
    };
void main() {
  test('answers require explicit objects and quote exact evidence', () {
    final e = BookEngine342(book(['Il lorvante contiene cristalli.']));
    final r = e.answer('Che cosa contiene il lorvante?');
    expect(r.answer, 'cristalli');
    expect(r.status, 'direct');
    expect(r.evidence.single['text'], 'Il lorvante contiene cristalli.');
    expect(e.answer('Che cosa contiene il norvante?').status, 'unknown');
  });
  test(
      'supported lexical paraphrases do not require identical question wording',
      () {
    final e = BookEngine342(book(['Il lorvante contiene cristalli.']));
    expect(e.answer('Che cosa include il lorvante?').answer, 'cristalli');
    expect(e.answer('Che cosa comprende il lorvante?').answer, 'cristalli');
    expect(e.answer('Che cosa custodisce il lorvante?').status, 'unknown');
  });
  test('agent and patient are directional, active and passive questions agree',
      () {
    final e = BookEngine342(book(['Ivo aiuta Mira.']));
    expect(e.answer('Chi aiuta Mira?').answer, 'ivo');
    expect(e.answer('Da chi è aiutata Mira?').answer, 'ivo');
    expect(e.answer('Mira aiuta Ivo?').status, 'unknown');
  });
  test('passive declaratives bind direction conservatively', () {
    final e = BookEngine342(book(['Mira è aiutata da Ivo.']));
    expect(e.answer('Chi aiuta Mira?').answer, 'ivo');
    expect(e.answer('Che cosa aiuta Ivo?').answer, 'mira');
  });
  test('definitions and locations are distinct relation slots', () {
    final e = BookEngine342(book(
        ['Il lorvante è un oggetto metallico.', 'Mira si trova a Selva.']));
    expect(e.answer('Che cosa è il lorvante?').answer, 'oggetto metallico');
    expect(e.answer('Dove si trova Mira?').answer, 'selva');
    expect(e.answer('Che cosa contiene Mira?').status, 'unknown');
  });
  test('explicit causes are quoted, not inferred from adjacent events', () {
    final e = BookEngine342(book([
      'La nave raggiunge il porto perché il vento cambia.',
      'Mira raggiunge Selva.'
    ]));
    expect(e.answer('Perché la nave raggiunge il porto?').answer,
        'il vento cambia');
    expect(e.answer('Perché Mira raggiunge Selva?').status, 'unknown');
  });
  test('negation gives No only with explicit opposite evidence', () {
    final e = BookEngine342(book(['Il veltro non contiene rame.']));
    expect(e.answer('Il veltro contiene rame?').answer, 'No');
    expect(e.answer('Il veltro non contiene rame?').answer, 'Sì');
    expect(e.answer('Il veltro contiene ferro?').status, 'unknown');
    expect(e.answer('Che cosa contiene il veltro?').status, 'unknown');
  });
  test('conflicting assertions preserve both supporting passages', () {
    final e = BookEngine342(
        book(['La gemma contiene quarzo.', 'La gemma non contiene quarzo.']));
    final r = e.answer('La gemma contiene quarzo?');
    expect(r.status, 'conflict');
    expect(r.evidence, hasLength(2));
    expect(r.answered, false);
  });
  test(
      'class transitivity and explicit universal properties keep complete proof',
      () {
    final e = BookEngine342(book([
      'Ogni neride è un mammifero.',
      'Ogni mammifero produce latte.',
      'Luma è un neride.'
    ]));
    final r = e.answer('Che cosa produce Luma?');
    expect(r.status, 'deduction');
    expect(r.answer, 'latte');
    expect(r.evidence, hasLength(3));
    expect(e.answer('Luma è un mammifero?').answer, 'Sì');
  });
  test('new entity transfer uses transient assumptions, never gold answers',
      () {
    final e = BookEngine342(
        book(['Ogni neride è un mammifero.', 'Ogni mammifero produce latte.']));
    final fingerprint = e.fingerprint, count = e.facts.length;
    expect(e.answer('Che cosa produce Zeta?').status, 'unknown');
    final r =
        e.answer('Che cosa produce Zeta?', assumptions: 'Zeta è un neride.');
    expect(r.answer, 'latte');
    expect(r.status, 'deduction');
    expect(r.evidence.where((r) => r['hypothesis'] == true), hasLength(1));
    expect(e.answer('Che cosa produce Zeta?').status, 'unknown');
    expect(e.facts.length, count);
    expect(e.fingerprint, fingerprint);
  });
  test('unsupported or universal assumptions abort rather than partially apply',
      () {
    final e = BookEngine342(book(['Ogni neride produce latte.']));
    expect(
        e
            .answer('Che cosa produce Zeta?',
                assumptions: 'Zeta è un neride. Forse Zeta si nasconde.')
            .status,
        'unknown');
    expect(
        e
            .answer('Che cosa produce Zeta?',
                assumptions: 'Ogni Zeta produce latte.')
            .status,
        'unknown');
  });
  test('no converse implication and no universal from one exemplar', () {
    final e = BookEngine342(book([
      'Ogni neride produce latte.',
      'Lio produce latte.',
      'Il talverio produce nettare.',
      'Zeta è un talverio.'
    ]));
    expect(e.answer('Lio è un neride?').status, 'unknown');
    expect(e.answer('Che cosa produce Zeta?').status, 'unknown');
  });
  test('contradictory membership blocks inherited properties', () {
    final e = BookEngine342(book([
      'Ogni neride produce latte.',
      'Luma è un neride.',
      'Luma non è un neride.'
    ]));
    expect(e.answer('Che cosa produce Luma?').status, 'unknown');
    expect(e.answer('Luma è un neride?').status, 'conflict');
  });
  test('late intermediate contradiction invalidates dependent conclusions', () {
    final e = BookEngine342(book([
      'Ogni neride è un mammifero.',
      'Ogni mammifero produce latte.',
      'Luma è un neride.',
      'Luma non è un mammifero.'
    ]));
    expect(e.answer('Che cosa produce Luma?').status, 'unknown');
  });
  test('negative universal property is not reversed into a positive', () {
    final e = BookEngine342(
        book(['Ogni neride non contiene rame.', 'Luma è un neride.']));
    expect(e.answer('Luma contiene rame?').answer, 'No');
    expect(e.answer('Che cosa contiene Luma?').status, 'unknown');
  });
  test(
      'conditions, exceptions, reporting and temporal clauses are not stripped',
      () {
    for (final text in [
      'Il talverio contiene rame solo se piove.',
      'Il talverio contiene rame quando piove.',
      'Il talverio contiene rame eccetto quando gela.',
      'Secondo Mira il talverio contiene rame.',
      'Il talverio contiene rame prima di partire.',
      'Forse il talverio contiene rame.',
      'Il talverio contiene rame, ma non sempre.'
    ]) {
      final e = BookEngine342(book([text]));
      expect(e.answer('Il talverio contiene rame?').status, 'unknown',
          reason: text);
      expect(e.search('talverio'), isNotEmpty);
    }
  });
  test(
      'operational reasoning budget is reported, not mistaken for a negative answer',
      () {
    final texts = [
      'Luma è un classe0.',
      for (var i = 0; i < 12; i++) 'Ogni classe$i è un classe${i + 1}.'
    ];
    final r = BookEngine342(book(texts)).answer('Luma è un classe12?');
    expect(r.status, 'unknown');
    expect(r.budgetReached, true);
  });
  test('retrieval tolerates extra words but never turns a hit into an answer',
      () {
    final e = BookEngine342(
        book(['Il lorvante contiene cristalli.', 'Mira aiuta Ivo.']));
    expect(e.search('Puoi spiegarmi cosa contiene il lorvante?').first['text'],
        'Il lorvante contiene cristalli.');
    expect(e.answer('Puoi spiegarmi cosa contiene il lorvante?').answer,
        'cristalli');
    expect(
        e.answer('Puoi confrontare il lorvante con Mira?').status, 'unknown');
  });
  test(
      'source scopes distinguish equal filenames for new imports and flag legacy grouping',
      () {
    final rows = [
      ...book(['Il lorvante contiene rame.'], identity: 'a'),
      ...book(['Il lorvante contiene ferro.'], identity: 'b')
    ];
    expect(BookLab342.scopes(rows), hasLength(2));
    final e =
        BookEngine342(rows.where((r) => bookScope342(r) == 'book:a').toList());
    expect(e.answer('Che cosa contiene il lorvante?').answer, 'rame');
    expect(bookScope342({'title': 'Manuale', 'url': 'local://corpus/old'}),
        'legacy:Manuale');
  });
  test('case validation rejects malformed or empty references', () {
    expect(() => BookExam342.validate([examCase('Domanda?', [])]),
        throwsFormatException);
    expect(
        () => BookExam342.validate([
              examCase('D?', ['a']),
              examCase('D?', ['b'])
            ]),
        throwsFormatException);
    expect(() => BookExam342.validate({'unknown': []}), throwsFormatException);
  });
  test('references cannot teach an empty reader the expected answer', () {
    final e = BookEngine342([]),
        c = examCase('Che cosa contiene il lorvante?', ['cristalli']);
    final r = BookExam342.run(e, [c]);
    expect(r['correct'], 0);
    expect(r['answered'], 0);
    expect(e.facts, isEmpty);
    expect(e.rows, isEmpty);
    final after = BookEngine342(book(['Il lorvante contiene cristalli.']));
    expect(BookExam342.run(after, [c])['correct'], 1);
  });
  test(
      'answer scoring and independently specified evidence scoring remain distinct',
      () {
    const text = 'Il lorvante contiene cristalli.';
    final e = BookEngine342(book([text]));
    final cases = [
      examCase('Che cosa contiene il lorvante?', ['cristalli'],
          support: [text]),
      examCase('Che cosa include il lorvante?', ['cristalli'],
          support: ['Una fonte sbagliata.']),
      examCase('Che cosa comprende il lorvante?', ['cristalli'])
    ];
    final r = BookExam342.run(e, cases);
    expect(r['correct'], 3);
    expect(r['supportChecked'], 2);
    expect(r['supportCorrect'], 1);
    expect(r['jointCorrect'], 1);
  });
  test('unknown cases do not inflate answered count, and metrics expose them',
      () {
    final r = BookExam342.run(BookEngine342([]), [
      examCase('Che cosa contiene X?', [], expected: 'unknown'),
      examCase('Che cosa produce Y?', ['latte'])
    ]);
    expect(r['total'], 2);
    expect(r['correct'], 1);
    expect(r['answered'], 0);
    expect(r['unknownTotal'], 1);
    expect(r['answerable'], 1);
    expect(r['tokenF1'], 0);
  });
  test('auto probes carry a non-independent label in every report', () {
    final e = BookEngine342(book(['Il lorvante contiene cristalli.']));
    final probes = e.probes();
    expect(probes.single['origin'], 'auto_same_parser_not_independent');
    expect(BookExam342.run(e, probes)['referenceKind'],
        'contains_non_independent_auto_probes');
  });
  test(
      'fingerprint changes with text and source but not answer order or queries',
      () {
    final a = book(['Il lorvante contiene cristalli.', 'Mira aiuta Ivo.']);
    expect(BookEngine342(a).fingerprint,
        BookEngine342(a.reversed.toList()).fingerprint);
    expect(BookEngine342(a).fingerprint,
        isNot(BookEngine342(book(['Il lorvante contiene rame.'])).fingerprint));
  });
  test(
      'exam state survives serialization without adding facts or source passages',
      () {
    final m = ResearchMemory11(enabled: false);
    SourceMemory323.retain(
        m,
        WebDocument11(
            provider: 'Test',
            title: 'Manuale',
            url: 'local://book/abc/1',
            text: 'Il lorvante contiene cristalli.',
            trust: .7));
    final before = SourceMemory323.rows(m).length, claims = m.claims.length;
    final cases = [
      examCase('Che cosa contiene il lorvante?', ['cristalli'])
    ];
    BookLab342.setCases(m, 'book:abc', cases);
    BookLab342.retainReport(m, 'book:abc',
        BookExam342.run(BookEngine342(BookLab342.rows(m)), cases));
    final restored =
        ResearchMemory11.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(BookLab342.cases(restored, 'book:abc'), hasLength(1));
    expect(BookLab342.reports(restored, 'book:abc'), hasLength(1));
    expect(SourceMemory323.rows(restored).length, before);
    expect(restored.claims.length, claims);
  });
  test(
      'persistent worker handles repeated questions and fails cleanly after close',
      () async {
    final w =
        await BookWorker342.open(book(['Il lorvante contiene cristalli.']));
    for (var i = 0; i < 3; i++) {
      final r =
          await w.call('ask', {'question': 'Che cosa include il lorvante?'});
      expect(r['answer'], 'cristalli');
    }
    await expectLater(w.call('not-an-operation'), throwsStateError);
    expect(
        (await w.call(
            'ask', {'question': 'Che cosa contiene il lorvante?'}))['status'],
        'direct');
    w.close();
    await expectLater(w.call('ask', {'question': 'Cosa?'}), throwsStateError);
  });
  testWidgets(
      'language screen exposes the book laboratory without altering existing counters',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MgdLanguageLab20(
            brain: PlasticLanguageBrain04(),
            world: MgdWorld06(),
            research: ResearchMemory11(enabled: false),
            language: MgdLanguage20(),
            onSave: () async {})));
    expect(find.byKey(const ValueKey('book-lab-open')), findsOneWidget);
    expect(find.text('Vocabolario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
