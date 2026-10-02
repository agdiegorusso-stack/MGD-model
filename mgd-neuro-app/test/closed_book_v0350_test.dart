import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/narrative_memory_v0350.dart';
import 'package:mgd_neuro_mobile/competence_language_v0350.dart';
import 'package:mgd_neuro_mobile/closed_book_store_v0350.dart';
import 'package:mgd_neuro_mobile/closed_book_service_v0350.dart';

ClosedBookEngine350 engine350(String text) => ClosedBookEngine350(
    NarrativeCompiler350().compile(text, unitOrdinal: 0).events);
const story350 = 'Marta possedeva una chiave. La prestò a Luca. '
    'Luca la nascose sotto il vaso. La lanterna era rossa. '
    'Ogni neride è un mammifero. Ogni mammifero produce latte.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  group('source-free semantics', () {
    test('empty input and immutable list are safe', () {
      final e = ClosedBookEngine350(const []);
      expect(e.answer('Chi ha la chiave?')['status'], 'unknown');
      expect(e.summary(), contains('Non ci sono'));
    });
    test('the memory stores roles not a hidden source document', () {
      final u = NarrativeCompiler350().compile(story350, unitOrdinal: 0);
      final copy =
          jsonDecode(jsonEncode(u.events.map((e) => e.toJson()).toList()))
              as List;
      expect(jsonEncode(copy), isNot(contains(story350)));
      expect(copy.every((x) => !(x as Map).containsKey('text')), isTrue);
      final e = ClosedBookEngine350(
          copy.map((x) => Event350.fromJson(x as Map)).toList());
      expect(e.answer('Chi nascose la chiave?')['answer'], 'luca');
      expect(e.answer('Dove si trova la chiave?')['answer'], 'sotto il vaso');
      expect(e.answer('A chi Marta prestò la chiave?')['answer'], 'luca');
      expect(e.answer('Di che colore era la lanterna?')['answer'], 'rossa');
      expect(e.answer('Chi nascose la chiave?')['rawPassagesRead'], 0);
    });
    test('new subject applies rules without being saved', () {
      final e = engine350(story350);
      final before = jsonEncode(e.events.map((e) => e.toJson()).toList());
      expect(
          e.answer('Che cosa produce Zeta?',
              assumptions: 'Zeta è un neride.')['answer'],
          'latte');
      expect(e.answer('Che cosa produce Zeta?')['status'], 'unknown');
      expect(jsonEncode(e.events.map((e) => e.toJson()).toList()), before);
    });
    test('agent object reversal, passive and synonyms remain distinct', () {
      final e =
          engine350('Il cane insegue il gatto. Il topo è aiutato dal gatto.');
      expect(e.answer('Chi insegue il gatto?')['answer'], 'cane');
      expect(e.answer('Chi insegue il cane?')['status'], 'unknown');
      expect(e.answer('Chi aiuta il topo?')['answer'], 'gatto');
    });
    test('negation and explicit contradictory relation are not ignored', () {
      final e = engine350('Luca aiuta Marta. Luca non aiuta Marta.');
      expect(e.answer('Chi aiuta Marta?')['status'], 'conflict');
      final n = engine350('Luca non aiuta Marta.');
      expect(n.answer('Chi aiuta Marta?')['status'], 'unknown');
      expect(n.answer('Luca aiuta Marta?')['answer'], 'No');
    });
    test('contradictory universal membership prevents invalid transfer', () {
      final e =
          engine350('Ogni neride è un mammifero. Ogni mammifero produce latte. '
              'Luma è un neride. Luma non è un mammifero.');
      expect(e.answer('Che cosa produce Luma?')['status'], 'unknown');
    });
    test('last location updates and picking an object invalidates old location',
        () {
      final e = engine350('Marta mette la chiave sotto il vaso. '
          'Luca sposta la chiave nella scatola.');
      expect(e.answer('Dove si trova la chiave?')['answer'], 'nella scatola');
      final moved = engine350(
          'Marta mette la chiave sotto il vaso. Luca prende la chiave.');
      expect(moved.answer('Dove si trova la chiave?')['status'], 'unknown');
    });
    test('an observation with a spatial adjunct does not locate the observer',
        () {
      final e = engine350('Marta vede una luce nella torre.');
      expect(e.answer('Dove si trova Marta?')['status'], 'unknown');
    });
    test('unsupported speculation, quotation and conditions are not facts', () {
      for (final s in [
        'Forse Luca nasconde la chiave.',
        'Luca nasconde la chiave solo se Marta arriva.',
        'Marta dice che Luca nasconde la chiave.',
        'Luca nasconde la chiave mentre Marta legge.',
        'Il talverio contiene rame eccetto quando gela.',
      ]) {
        final e = engine350(s);
        expect(e.events, isEmpty, reason: s);
      }
    });
    test('ambiguous person pronouns are not resolved by name stereotypes', () {
      final a = engine350('Marta vede Anna. Lei nasconde la chiave.');
      final b = engine350('Marta incontra Luca. Lui nasconde la chiave.');
      expect(a.answer('Chi nasconde la chiave?')['status'], 'unknown');
      expect(b.answer('Chi nasconde la chiave?')['status'], 'unknown');
    });
    test('mismatched object clitics are not attached to arbitrary referents',
        () {
      final e = engine350('Marta possiede un vaso. La nasconde nella scatola.');
      expect(e.answer('Dove si trova il vaso?')['status'], 'unknown');
    });
    test('supported local subject ellipsis retains object continuity', () {
      final e = engine350('Marta possiede una chiave. La presta a Luca.');
      expect(e.answer('A chi Marta presta la chiave?')['answer'], 'luca');
    });
    test('explicit causation is different from adjacent events', () {
      final e =
          engine350('Marta chiude la porta perché il vento sposta le carte.');
      expect(e.answer('Perché Marta chiude la porta?')['answer'],
          contains('Vento sposta carte'));
      final adjacent =
          engine350('Il vento sposta le carte. Marta chiude la porta.');
      expect(adjacent.answer('Perché Marta chiude la porta?')['status'],
          'unknown');
    });
    test('chapters, missing portions and graph pagination stay visible', () {
      final c = NarrativeCompiler350().compile(
          'Capitolo 1\nMarta apre la porta.\n'
          'Questo brano lunghissimo allude a qualcosa di inafferrabile.\n'
          'Capitolo 2\nLuca legge il giornale.',
          unitOrdinal: 0);
      final e = ClosedBookEngine350(c.events, {'unparsed': 1});
      expect(e.summary(), contains('Capitolo 1'));
      expect(e.summary(), contains('Capitolo 2'));
      expect(e.summary(), contains('Sintesi parziale'));
      expect((e.graph(limit: 1)['events'] as List), hasLength(1));
      expect(e.graph(limit: 1)['more'], isTrue);
    });
    test('a verb homograph inside an explicit subject remains a noun', () {
      final e = engine350('La porta è aperta. La porta contiene un sensore.');
      expect(e.events.first.subject, 'porta');
      expect(e.events.first.predicate, 'stato');
      expect(e.answer('Che cosa contiene la porta?')['answer'], 'sensore');
    });
    test(
        'unknown surface verb can occupy learned explicit roles without guessed synonym',
        () {
      final e = engine350('Marta vernicia la sedia.');
      expect(e.answer('Chi vernicia la sedia?')['answer'], 'marta');
      expect(e.answer('Chi dipinge la sedia?')['status'], 'unknown');
    });
    test('a state is not extrapolated to an entire class', () {
      final e = engine350('Il talverio contiene rame. Nio è un talverio.');
      expect(e.answer('Che cosa contiene Nio?')['status'], 'unknown');
    });
    test('oversized and interrupted fragments cannot become a shortened fact',
        () {
      final c = compileRequest350({
        'text':
            'Marta nasconde la chiave ' + List.filled(300, 'lontano').join(' '),
        'safe': false,
        'state': <String, dynamic>{},
        'ordinal': 0
      });
      expect(c['events'], isEmpty);
      expect(c['issues'], contains('overlong_fragment'));
    });
  });
  group('language acquisition rather than storing sentences', () {
    test('untrained comparison declines and novel composition is learned', () {
      final m = CompetenceLanguage350();
      expect(
          m.compare([
            'Il bambino apre la porta.',
            'Il bambino aprono la porta.'
          ])['status'],
          'undetermined');
      expect(
          m.compose('La sorella', 'apre', 'il cancello')['status'], 'unknown');
      final c = NarrativeCompiler350().compile(
          'Il bambino apre la porta. La madre apre la scatola.',
          unitOrdinal: 0);
      m.apply(c.language);
      final r = m.compose('La sorella', 'apre', 'il cancello');
      expect(r['sentence'], 'La sorella apre il cancello.');
      expect(r['status'], 'construction');
      expect(
          jsonEncode(m.counts), isNot(contains('La madre apre la scatola.')));
      expect(m.counts['lexicon']?.containsKey('sorella'), isFalse);
      expect(m.compare(['xyz qqq', 'www zzz'])['status'], 'undetermined');
    });
    test(
        'head agreement can prefer new phrases across an intervening singular noun',
        () {
      final m = CompetenceLanguage350();
      for (final s in [
        'Le chiavi sono nuove.',
        'Le porte sono aperte.',
        'La chiave è nuova.',
        'Il vicino è gentile.'
      ]) {
        m.apply(NarrativeCompiler350().compile(s, unitOrdinal: 0).language);
      }
      final before = jsonEncode(m.counts);
      final r = m.compare([
        'Le chiavi del vicino sono nuove.',
        'Le chiavi del vicino è nuove.'
      ]);
      expect(r['best'], 'Le chiavi del vicino sono nuove.');
      expect(jsonEncode(m.counts), before);
    });
    test(
        'sense uses retain distinct relation contexts rather than one dominant meaning',
        () {
      final c = NarrativeCompiler350().compile(
          'La stella produce luce. La stella canta una canzone.',
          unitOrdinal: 0);
      final m = CompetenceLanguage350()..apply(c.language);
      expect(m.counts['sense:stella']?.keys, contains('subject|produce|luce'));
      expect(m.counts['sense:stella']?.keys, contains('subject|canta|canzone'));
    });
    test('subtraction is reversible and invalid removal is atomic', () {
      final a = NarrativeCompiler350()
          .compile('Marta apre la porta.', unitOrdinal: 0)
          .language;
      final b = NarrativeCompiler350()
          .compile('Luca legge il giornale.', unitOrdinal: 0)
          .language;
      final m = CompetenceLanguage350()
        ..apply(a)
        ..apply(b);
      m.apply(a, sign: -1);
      expect(m.counts, b.counts);
      final before = jsonEncode(m.counts);
      expect(() => m.apply(a, sign: -1), throwsStateError);
      expect(jsonEncode(m.counts), before);
    });
    test(
        'passive example cannot falsely teach its subject-verb agreement as active',
        () {
      final c = NarrativeCompiler350()
          .compile('Il topo è aiutato dalla bambina.', unitOrdinal: 0);
      expect(c.events, hasLength(1));
      expect(c.language.counts['agreement:word:bambina'], isNull);
    });
  });
  group('incremental SQLite and lifecycle', () {
    late Directory dir;
    late ClosedBookStore350 store;
    late String path;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mgd350-test-');
      path = '${dir.path}/memory.db';
      store = await ClosedBookStore350.open(
          path: path, factory: databaseFactoryFfi);
    });
    tearDown(() async {
      ClosedBookBridge350.close();
      ClosedBookBridge350.storeOverride = null;
      await store.close();
      await dir.delete(recursive: true);
    });
    Future<String> learn(String text, String name) async {
      final f = File('${dir.path}/$name')..writeAsStringSync(text);
      final r = await store.importFile(f, title: name);
      await f.delete();
      return r['id'] as String;
    }

    test(
        'file removed, SQL reopened and isolate still answers from structured memory',
        () async {
      final id = await learn(story350, 'libro.txt');
      expect(await File('${dir.path}/libro.txt').exists(), isFalse);
      await store.close();
      store = await ClosedBookStore350.open(
          path: path, factory: databaseFactoryFfi);
      final snapshot = await store.snapshot(id);
      expect(snapshot['metadata'], isNot(contains('state')));
      final w = await ClosedRecallWorker350.open(snapshot);
      try {
        expect(
            (await w
                .call('ask', {'question': 'Chi nascose la chiave?'}))['answer'],
            'luca');
      } finally {
        w.close();
      }
      final schema = await store.db
          .rawQuery('SELECT sql FROM sqlite_master WHERE type="table"');
      expect(jsonEncode(schema), isNot(contains('raw_text')));
      expect((await store.storageStats(id))['rawTextBytesStored'], 0);
    });
    test('idempotency is content based even when filename changes', () async {
      final id = await learn(story350, 'uno.txt'),
          before = await store.book(id);
      final second = await learn(story350, 'due.txt');
      expect(second, id);
      expect((await store.books()), hasLength(1));
      expect((await store.book(id))!['revision'], before!['revision']);
    });
    test(
        'cancelled import resumes without duplicate training and preserves both ends',
        () async {
      final source =
          List.generate(350, (i) => 'Persona$i apre la porta$i.').join('\n');
      final f = File('${dir.path}/large.txt')..writeAsStringSync(source);
      var cancelled = false;
      final partial = await store.importFile(f,
          title: 'large.txt',
          cancelled: () => cancelled,
          progress: (r) {
            cancelled = true;
          });
      expect(partial['complete'], 0);
      expect(partial['units'], 1);
      final full = await store.importFile(f, title: 'large.txt');
      expect(full['complete'], 1);
      final snap = await store.snapshot(full['id'] as String);
      expect((snap['events'] as List), hasLength(350));
      final m = await store
          .language(bookId: full['id'] as String, groups: {'lexicon'});
      expect(m.counts['lexicon']?['apre'], 350);
    });
    test(
        'book deletion subtracts only its learning and never mixes narrative identities',
        () async {
      final a = await learn('Marta nasconde la chiave sotto il vaso.', 'a.txt');
      final b = await learn(
          'Marta nasconde la chiave nella scatola. Luca legge il giornale.',
          'b.txt');
      expect((await store.word('giornale'))['observations'], 1);
      await store.forgetBook(a);
      expect(await store.book(a), isNull);
      final e = ClosedBookEngine350(
          ((await store.snapshot(b))['events'] as List)
              .map((x) => Event350.fromJson(x as Map))
              .toList());
      expect(e.answer('Dove si trova la chiave?')['answer'], 'nella scatola');
      expect((await store.word('vaso'))['observations'], 0);
      expect((await store.word('giornale'))['observations'], 1);
    });
    test(
        'external references are invisible to the worker and cannot teach answers',
        () async {
      final id = await learn(story350, 'r.txt');
      final snap = await store.snapshot(id),
          w = await ClosedRecallWorker350.open(snap);
      final before = jsonEncode(snap);
      try {
        final report = await ClosedBookExam350.run(w, [
          {
            'id': 'a',
            'question': 'Chi nascose la chiave?',
            'expected': 'answer',
            'answers': ['luca']
          },
          {
            'id': 'poison',
            'question': 'Quale password possiede Berto?',
            'expected': 'answer',
            'answers': ['ANSWER-SECRET-ONLY-IN-EXAM']
          },
          {
            'id': 'u',
            'question': 'Di che colore è il vaso?',
            'expected': 'unknown',
            'answers': []
          }
        ]);
        expect(report['correctAnswerable'], 1);
        expect(report['correctUnknown'], 1);
        expect((report['results'] as List)[1]['result']['answer'],
            isNot(contains('ANSWER-SECRET')));
        expect(jsonEncode(await store.snapshot(id)), before);
        await store.setCases(id, [
          {
            'id': 'a',
            'question': 'Chi nascose la chiave?',
            'expected': 'answer',
            'answers': ['luca']
          }
        ]);
        await store.saveReport(id, report);
        expect((await store.reports(id)).single['correct'], 2);
      } finally {
        w.close();
      }
    });
    test('large report uses bounded SQLite reads and survives reopen',
        () async {
      final id = await learn('Marta apre la porta.', 'x.txt');
      final report = {'payload': List.filled(2300000, 'à').join()};
      await store.saveReport(id, report);
      await store.close();
      store = await ClosedBookStore350.open(
          path: path, factory: databaseFactoryFfi);
      expect((await store.reports(id)).single['payload'], report['payload']);
    });
    test(
        'forget concept removes traces and blocks resumed imports from restoring them',
        () async {
      final id = await learn(
          'Marta nasconde la chiave. Luca legge il giornale.', 'x.txt');
      await store.forgetConcept('Marta');
      expect(jsonEncode(await store.snapshot(id)), isNot(contains('marta')));
      expect(jsonEncode((await store.language()).counts),
          isNot(contains('marta')));
      final other =
          await learn('Marta nasconde una borsa. Luca apre la porta.', 'y.txt');
      expect(jsonEncode(await store.snapshot(other)), isNot(contains('marta')));
      expect((await store.word('giornale'))['observations'], 1);
      expect(await store.forgottenHashes(), isNot(contains('marta')));
    });
    test('invalid file reports error without replacing existing memories',
        () async {
      final id = await learn(story350, 'a.txt');
      final f = File('${dir.path}/binary.txt')
        ..writeAsBytesSync([0x25, 0x50, 0x44, 0x46, 0, 1, 2]);
      await expectLater(
          store.importFile(f, title: 'binary.txt'), throwsFormatException);
      expect((await store.book(id))!['events'], 6);
      expect(store.importing, isFalse);
    });
    test('invalid unit ordering fails atomically', () async {
      await store.beginBook('id', 'book');
      final c = NarrativeCompiler350()
          .compile('Marta apre la porta.', unitOrdinal: 1);
      await expectLater(store.commitUnit('id', c.toJson()), throwsStateError);
      expect((await store.snapshot('id'))['events'], isEmpty);
    });
    test(
        'correction revises roles, statistics and evidence without saving a source sentence',
        () async {
      final id = await learn(
          'Marta apre la porta. Luca legge il giornale.', 'correction.txt');
      final first = (await store.eventPage(id)).first;
      final before = (await store.book(id))!['revision'];
      await store.correctEvent(
          id, '${first['id']}', {'subject': 'Nadia', 'object': 'finestra'});
      await store.close();
      store = await ClosedBookStore350.open(
          path: path, factory: databaseFactoryFfi);
      final snap = await store.snapshot(id);
      final e = ClosedBookEngine350((snap['events'] as List)
          .map((x) => Event350.fromJson(x as Map))
          .toList());
      expect(e.answer('Chi apre la finestra?')['answer'], 'nadia');
      expect(e.answer('Chi apre la porta?')['status'], 'unknown');
      expect(e.answer('Che cosa legge Luca?')['answer'], 'giornale');
      expect((await store.book(id))!['revision'], (before as int) + 1);
      final usage = await store.language(bookId: id);
      expect(usage.counts['agreement:word:marta'], isNull);
      expect(usage.counts['agreement:word:nadia']?['apre'], 1);
    });
    test(
        'bounded question and comparison budgets reject oversized input explicitly',
        () async {
      final e = engine350(story350);
      expect(e.answer(List.filled(5000, 'a').join())['budgetReached'], isTrue);
      await expectLater(store.compare([List.filled(3000, 'a').join(), 'prova']),
          throwsFormatException);
    });
    test('definitions remain contextual and are not invented from collocations',
        () async {
      final e = engine350(
          'Il norvente è un animale marino. La stella brilla nel cielo.');
      expect(
          e.answer('Che cosa significa norvente?')['answer'], 'animale marino');
      expect(e.answer("Cos'è la stella?")['status'], 'unknown');
    });
    test(
        'main chat bridge respects selected structured memory and reset clears it',
        () async {
      await learn(story350, 'x.txt');
      ClosedBookBridge350.storeOverride = store;
      final reply =
          await ClosedBookBridge350.chat('Libro: Chi nascose la chiave?');
      expect(reply, contains('luca'));
      expect(reply, contains('A libro chiuso'));
      await ClosedBookBridge350.reset();
      expect(await store.books(), isEmpty);
      expect(await ClosedBookBridge350.chat('Libro: Chi nascose la chiave?'),
          isNull);
    });
  });
}
