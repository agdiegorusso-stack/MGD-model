// BOOK_FIXTURE_PROVENANCE_0342
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/book_understanding_v0342.dart';
import '../lib/web_knowledge_explorer_v11.dart';

// Original controlled prose and separately authored references. This is a small
// development evaluation, NOT a held-out public benchmark or the user's book.
const passages342 = [
  'Il lorvante contiene cristalli.',
  'La capsula protegge il lorvante.',
  'Mira si trova a Selva.',
  'Ivo aiuta Mira.',
  'La navetta raggiunge il porto perché il vento cambia.',
  'Ogni neride è un mammifero.',
  'Ogni mammifero produce latte.',
  'Luma è un neride.',
  'Il veltro non contiene rame.',
  'Il veltro contiene ferro.',
  'La gemma contiene quarzo.',
  'La gemma non contiene quarzo.',
  'Il lumino funziona solo quando la leva è abbassata.',
  'Dopo aver lasciato il porto, Ada consegnò a Bruno la mappa che aveva trovato.',
  'Bruno la ripose nello zaino prima di salutare Ada.',
  'Il deposito ospitava sette casse, ma due furono trasferite al molo.',
  'Ada osservò la lanterna rossa accanto alla finestra.',
  'La sfera è un oggetto metallico.',
  'Lio produce latte.',
  'Ogni neride possiede una coda.',
  'Ogni neride non contiene rame.',
  'Il talverio non è un neride.',
];
List<Map<String, dynamic>> cases342() {
  var n = 0;
  Map<String, dynamic> c(
          String q, String category, List<String> answers, List<int> evidence,
          {String expected = 'answer', String hypotheses = ''}) =>
      {
        'id': 'original-prose-${++n}',
        'question': q,
        'category': category,
        'answers': answers,
        'support': evidence.map((i) => passages342[i]).toList(),
        'expected': expected,
        'assumptions': hypotheses,
        'origin': 'external_reference'
      };
  return [
    c('Che cosa contiene il lorvante?', 'diretta', ['cristalli'], [0]),
    c('Che cosa include il lorvante?', 'parafrasi', ['cristalli'], [0]),
    c('Che cosa comprende il lorvante?', 'parafrasi', ['cristalli'], [0]),
    c('Dove si trova Mira?', 'diretta', ['Selva'], [2]),
    c('Chi aiuta Mira?', 'diretta', ['Ivo'], [3]),
    c('Da chi è aiutata Mira?', 'parafrasi', ['Ivo'], [3]),
    c('Perché la navetta raggiunge il porto?', 'causa esplicita',
        ['il vento cambia'], [4]),
    c('Luma è un mammifero?', 'deduzione', ['Sì'], [5, 7]),
    c('Che cosa produce Luma?', 'deduzione', ['latte'], [5, 6, 7]),
    c('Che cosa produce Zeta?', 'trasferimento', ['latte'], [5, 6],
        hypotheses: 'Zeta è un neride.'),
    c('Che cosa produce Rivo?', 'non determinabile', [], [],
        expected: 'unknown'),
    c('Il veltro contiene rame?', 'negazione', ['No'], [8]),
    c('Il veltro contiene ferro?', 'diretta', ['Sì'], [9]),
    c('Il lumino funziona?', 'non determinabile', [], [], expected: 'unknown'),
    c('La gemma contiene quarzo?', 'contraddizione', [], [10, 11],
        expected: 'conflict'),
    c('Lio è un neride?', 'non determinabile', [], [], expected: 'unknown'),
    c('A chi Ada consegnò la mappa?', 'prosa narrativa', ['Bruno'], [13]),
    c('Dove ripose la mappa Bruno?', 'riferimenti pronominali',
        ['nello zaino', 'zaino'], [13, 14]),
    c('Quante casse rimasero nel deposito?', 'ragionamento numerico',
        ['5', 'cinque'], [15]),
    c('Di che colore era la lanterna?', 'prosa narrativa', ['rossa', 'rosso'],
        [16]),
    c('Che cosa è la sfera?', 'diretta', ['oggetto metallico'], [17]),
    c('Che cosa possiede Nova?', 'trasferimento', ['coda'], [19],
        hypotheses: 'Nova è un neride.'),
    c('Che cosa custodisce il lorvante?', 'parafrasi aperta', ['cristalli'],
        [0]),
    c('Il talverio produce latte?', 'non determinabile', [], [],
        expected: 'unknown'),
    c('Nova contiene rame?', 'trasferimento', ['No'], [20],
        hypotheses: 'Nova è un neride.'),
    c('Chi protegge il lorvante?', 'diretta', ['capsula', 'la capsula'], [1]),
  ];
}

void main() {
  test(
      'mixed prose report records every case including unsupported answerable questions',
      () {
    final memory = ResearchMemory11(enabled: false);
    SourceMemory323.retain(
        memory,
        WebDocument11(
            family: 'locale:test342',
            provider: 'Corpus originale di sviluppo',
            title: 'Piccolo mondo di prova',
            url: 'local://book/demo342/1',
            text: passages342.join('\n'),
            trust: .7));
    final rows = SourceMemory323.rows(memory),
        engine = BookEngine342(rows),
        cases = cases342();
    final beforeFacts = memory.claims.length, beforeRows = rows.length;
    final measured = BookExam342.run(engine, cases),
        empty = BookExam342.run(BookEngine342([]), cases);
    var oldAll = 0, newAll = 0, withSupport = 0;
    for (final c in cases) {
      final support = List<String>.from(c['support'] as List);
      if (support.isEmpty) continue;
      withSupport++;
      final old = SourceMemory323.search('${c['question']}', memory, limit: 5)
          .map((h) => bookNorm342(h.text))
          .toSet();
      final now = engine
          .search('${c['question']}', limit: 5)
          .map((h) => bookNorm342('${h['text']}'))
          .toSet();
      if (support.every((s) => old.contains(bookNorm342(s)))) oldAll++;
      if (support.every((s) => now.contains(bookNorm342(s)))) newAll++;
    }
    final report = {
      'protocol':
          'Original mixed prose, development diagnostic, not independent public SOTA validation.',
      'userBookAvailable': false,
      'reader': engine.stats(),
      'current': measured,
      'emptyControl': empty,
      'retrievalOnlyAt5': {
        'casesWithReferenceSupport': withSupport,
        'legacyAllSupportFound': oldAll,
        'newAllSupportFound': newAll,
        'note':
            'Lexical retrieval only. Multi-hop proofs use a different indexed rule path. This is not a comparison with a Transformer.'
      }
    };
    final path = Platform.environment['MGD_BOOK_EVAL_OUT'];
    if (path != null)
      File(path).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(report));
    File('book-demo-0.34.2.txt').writeAsStringSync(passages342.join('\n'));
    File('book-exam-demo-0.34.2.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'schema': 1, 'cases': cases}));
    print('BOOK342_MIXED_PROSE ${jsonEncode({
          'total': measured['total'],
          'correct': measured['correct'],
          'answered': measured['answered'],
          'wrongAnswers': measured['wrongAnswers'],
          'answerable': measured['answerable'],
          'correctUnknown': measured['correctUnknown'],
          'unknownTotal': measured['unknownTotal'],
          'supportChecked': measured['supportChecked'],
          'jointCorrect': measured['jointCorrect'],
          'categories': measured['categories'],
          'legacyRetrievalAt5': oldAll,
          'newRetrievalAt5': newAll,
          'referenceSupportCases': withSupport
        })}');
    expect(measured['total'], 26);
    expect((measured['results'] as List), hasLength(26));
    expect(memory.claims.length, beforeFacts);
    expect(SourceMemory323.rows(memory).length, beforeRows);
    // No accuracy threshold is used to delete or conceal failed questions.
    print(
        'BOOK342_FAILED_CASES ${jsonEncode((measured['results'] as List).where((r) => r['correct'] == false).map((r) => r['case']['id']).toList())}');
  });
}
