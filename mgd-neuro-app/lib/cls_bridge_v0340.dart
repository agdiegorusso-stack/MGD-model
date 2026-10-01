import 'cls_core_v0340.dart';
import 'cls_store_v0340.dart';
import 'web_knowledge_explorer_v11.dart';

/// Runtime integration is explicitly activated by the app, not by unit tests.
/// Generated answers are never used as new external observations.
class ClsBridge340 {
  static ClsStore340? active;
  static bool question(String text)=>text.trim().endsWith('?')||RegExp(
    r'^\s*(chi|cosa|come|quando|dove|perch[eé]|quanto|quale|quali|che\s+cosa)\b',
    caseSensitive:false).hasMatch(text);
  static Future<void> observeText(String text,{String source='Testo utente'}) async {
    final store=active;
    if(store==null||text.trim().isEmpty||question(text)||RegExp(
      r'^\s*(correggi|continua)\s*:',caseSensitive:false).hasMatch(text))return;
    await store.importText(text,source:source);
    await store.consolidate(budget:2);
  }
  static Future<void> observeDocument(WebDocument11 doc) async {
    final store=active;if(store==null)return;
    await store.importText(doc.text,source:'${doc.provider}: ${doc.url}',label:doc.title);
  }
  static Future<String?> quote(String question) async {
    final store=active;if(store==null)return null;
    final command=RegExp(r'^\s*continua\s*:\s*',caseSensitive:false);
    if(command.hasMatch(question)) {
      final result=await store.continueText(question.replaceFirst(command,''));
      return result.isEmpty?'Non ho ancora sequenze linguistiche consolidate.':
        'Continuazione statistica sperimentale (non risposta fattuale):\n$result';
    }
    final f=Italian340.features(question);if(f.isEmpty)return null;
    final recall=await store.recall({'text:v1':f});
    if(!recall.accepted||recall.conflict||recall.evidence.isEmpty)return null;
    final e=recall.evidence.first;
    if(e.text.trim().isEmpty)return null;
    return 'Passaggio richiamato, non verificato:\n${e.text}\nFonte: ${e.source}';
  }
  static Future<void> deleteLegacy(int id) async {
    final store=active;if(store==null)return;
    final rows=await store.db.query('legacy',where:'uid=?',whereArgs:['legacy33:$id']);
    for(final row in rows) {if(row['episode']!=null)await store.delete(row['episode'] as int);}
  }
  static Future<void> forgetLabel(String label) async {
    final store=active;if(store==null)return;
    final rows=await store.db.query('episodes',columns:['id'],where:'label=?',whereArgs:[norm340(label)]);
    for(final row in rows) {await store.delete(row['id'] as int);}
  }
  static Future<void> clear() async {
    final store=active;if(store==null)return;
    await store.db.transaction((tx) async {
      await tx.delete('episodes');await tx.delete('prototypes');await tx.delete('grams');
      await tx.delete('legacy');await tx.delete('audit');await tx.delete('settings');
    });
    store.revision++;
  }
}
