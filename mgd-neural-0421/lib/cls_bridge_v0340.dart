import 'closed_book_service_v0350.dart';
import 'cls_core_v0340.dart';
import 'cls_store_v0340.dart';
import 'web_knowledge_explorer_v11.dart';
import 'plastic_language_brain_v04.dart';

/// Runtime integration is explicitly activated by the app, not by unit tests.
/// Generated answers are never used as new external observations.
class ClsBridge340 {
  static ClsStore340? active;
  static bool question(String text) =>
      text.trim().endsWith('?') ||
      RegExp(r'^\s*(chi|cosa|come|quando|dove|perch[eé]|quanto|quale|quali|che\s+cosa)\b',
              caseSensitive: false)
          .hasMatch(text);
  static Future<void> observeText(String text,
      {String source = 'Testo utente'}) async {
    final store = active;
    if (store == null || text.trim().isEmpty) return;
    final observed = text.split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .where((part) => part.trim().isNotEmpty && !question(part) &&
            !RegExp(r'^\s*(correggi|continua)\s*:', caseSensitive: false)
                .hasMatch(part))
        .join('\n');
    if (observed.isEmpty) return;
    await store.importText(observed, source: source);
    await store.consolidate(budget: 2);
  }

  static Future<void> observeDocument(WebDocument11 doc) async {
    final store = active;
    if (store == null) return;
    await store.importText(doc.text,
        source: '${doc.provider}: ${doc.url}', label: doc.title);
  }

  static Future<String?> quote(String question) async {
    final store = active;
    if (store == null) return null;
    final command = RegExp(r'^\s*continua\s*:\s*', caseSensitive: false);
    if (command.hasMatch(question)) {
      final result =
          await store.continueText(question.replaceFirst(command, ''));
      return result.isEmpty
          ? 'Non ho ancora sequenze linguistiche consolidate.'
          : 'Continuazione statistica sperimentale (non risposta fattuale):\n$result';
    }
    final f = Italian340.features(question);
    if (f.isEmpty) return null;
    final recall = await store.recall({'text:v1': f});
    if (!recall.accepted || recall.conflict || recall.evidence.isEmpty)
      return null;
    final e = recall.evidence.first;
    if (e.text.trim().isEmpty) return null;
    return 'Passaggio richiamato, non verificato:\n${e.text}\nFonte: ${e.source}';
  }

  static Future<void> deleteLegacy(int id) async {
    final store = active;
    if (store == null) return;
    final rows = await store.db
        .query('legacy', where: 'uid=?', whereArgs: ['legacy33:$id']);
    for (final row in rows) {
      if (row['episode'] != null) await store.delete(row['episode'] as int);
    }
  }

  static Future<void> forgetLabel(String label) async {
    await ClosedBookBridge350.forgetConcept(label);
    final store = active;
    if (store == null) return;
    var after = 0;
    while (true) {
      final rows = await store.db.query('episodes',
          columns: ['id', 'label', 'text', 'source'], where: 'id>?',
          whereArgs: [after], orderBy: 'id', limit: 256);
      if (rows.isEmpty) break;
      after = rows.last['id'] as int;
      for (final row in rows) {
        if (['label', 'text', 'source'].any((field) =>
            PlasticLanguageBrain04.containsLabel33('${row[field] ?? ''}', label))) {
          // The store removes this episode's language delta and invalidates its
          // prototype as well as the retained text and media references.
          await store.delete(row['id'] as int);
        }
      }
    }
  }

  static Future<void> clear() async {
    await ClosedBookBridge350.reset();
    final store = active;
    if (store == null) return;
    await store.db.transaction((tx) async {
      await tx.delete('episodes');
      await tx.delete('prototypes');
      await tx.delete('grams');
      await tx.delete('legacy');
      await tx.delete('audit');
      await tx.delete('settings');
    });
    store.revision++;
  }
}
