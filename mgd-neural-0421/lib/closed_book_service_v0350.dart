import 'dart:async';
import 'dart:convert';
import 'closed_book_store_v0350.dart';
import 'book_understanding_v0342.dart';

class ClosedBookExam350 {
  /// References are compared only AFTER inference. No training callback exists.
  static Future<Map<String, dynamic>> run(
      ClosedRecallWorker350 worker, List<Map<String, dynamic>> input,
      {Map<String, dynamic> metadata = const {},
      bool Function()? cancelled,
      void Function(int, int)? progress}) async {
    final cases = BookExam342.validate(input),
        results = <Map<String, dynamic>>[];
    int correct = 0,
        answerable = 0,
        correctAnswerable = 0,
        wrongAnswers = 0,
        correctUnknown = 0,
        unknownTotal = 0,
        produced = 0;
    for (final c in cases) {
      if (cancelled?.call() == true) break;
      final r = await worker.call(
          'ask', {'question': c['question'], 'assumptions': c['assumptions']});
      final answered = {'direct', 'deduction'}.contains(r['status']);
      final ok = c['expected'] == 'unknown'
          ? r['status'] == 'unknown'
          : c['expected'] == 'conflict'
              ? r['status'] == 'conflict'
              : answered &&
                  (c['answers'] as List).any((x) =>
                      BookExam342.normalize('$x') ==
                      BookExam342.normalize('${r['answer']}'));
      if (ok) correct++;
      if (answered) {
        produced++;
        if (!ok) wrongAnswers++;
      }
      if (c['expected'] == 'answer') {
        answerable++;
        if (ok) correctAnswerable++;
      }
      if (c['expected'] == 'unknown') {
        unknownTotal++;
        if (ok) correctUnknown++;
      }
      results.add({'case': c, 'result': r, 'correct': ok});
      progress?.call(results.length, cases.length);
    }
    return {
      'version': '0.35.2',
      'mode': 'closed_book',
      'at': DateTime.now().toIso8601String(),
      'book': metadata['id'],
      'bookRevision': metadata['revision'],
      'total': results.length,
      'planned': cases.length,
      'cancelled': results.length < cases.length,
      'correct': correct,
      'answerable': answerable,
      'correctAnswerable': correctAnswerable,
      'produced': produced,
      'wrongAnswers': wrongAnswers,
      'unknownTotal': unknownTotal,
      'correctUnknown': correctUnknown,
      'rawPassagesRead': results.fold<int>(0,
          (a, r) => a + ((r['result'] as Map)['rawPassagesRead'] as int? ?? 0)),
      'results': results,
      'note':
          'Confronto normalizzato con riferimenti esterni, non giudice semantico. Le risposte di riferimento non sono trasmesse al motore.'
    };
  }
}

class ClosedBookBridge350 {
  static ClosedBookStore350? storeOverride;
  static bool enabled = false;
  static Future<void> forgetConcept(String label) async {
    if (!enabled && storeOverride == null) return;
    close();
    await (await store).forgetConcept(label);
  }

  static Future<ClosedBookStore350> get store async =>
      storeOverride ?? await ClosedBookStore350.shared;
  static ClosedRecallWorker350? _worker;
  static String? _book;
  static int? _revision;
  static ClosedBookStore350? _store;
  static void close() {
    _worker?.close();
    _worker = null;
    _book = null;
    _revision = null;
    _store = null;
  }

  static Future<String?> chat(String input) async {
    final prefix =
        RegExp(r'^\s*(?:libro|memoria|ricordo)\s*:\s*', caseSensitive: false);
    if (!prefix.hasMatch(input)) return null;
    if (!enabled && storeOverride == null) return null;
    final s = await store, id = await s.active();
    if (id == null)
      return null; // Compatibility: existing explicitly selected archive remains usable.
    final meta = await s.book(id);
    if (meta == null) {
      close();
      return 'Il libro selezionato è stato eliminato.';
    }
    final q = input.replaceFirst(prefix, '').trim();
    if (q.isEmpty)
      return 'Scrivi Libro: seguito dalla domanda, oppure Libro: riassumi.';
    if (_worker == null ||
        id != _book ||
        meta['revision'] != _revision ||
        !identical(s, _store)) {
      close();
      _worker = await ClosedRecallWorker350.open(await s.snapshot(id));
      _book = id;
      _revision = meta['revision'] as int;
      _store = s;
    }
    final r = await _worker!.call('ask', {'question': q});
    final notes = meta['complete'] == 1 ? '' : '\nLettura ancora parziale.';
    final count = (r['evidence'] as List? ?? []).length;
    return 'A libro chiuso — ${meta['title']}$notes\n${r['answer']}\n${r['reason']}'
        '\nMemoria strutturata: $count elementi utilizzati; nessuna consultazione del testo originale.';
  }

  static Future<void> reset() async {
    close();
    if (!enabled && storeOverride == null) return;
    await (await store).clear();
  }

  static Future<String> export(ClosedBookStore350 s, String id) async {
    final snapshot = await s.snapshot(id);
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 'mgd.closed-book.350',
      'memory': snapshot,
      'language': (await s.language(bookId: id)).counts,
      'reports': await s.reports(id),
      'rawTextIncluded': false
    });
  }
}
