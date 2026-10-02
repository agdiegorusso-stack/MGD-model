import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mgd_neuro_mobile/book_import_v0341.dart';
import 'package:mgd_neuro_mobile/mgd_state_store_v026.dart';
import 'package:mgd_neuro_mobile/memory_runtime_v0319.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/cls_bridge_v0340.dart';
import 'package:mgd_neuro_mobile/cls_store_v0340.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android: reproduce oversized legacy BLOB query and verify sliced read after reopen',
      (tester) async {
    final store = MgdStateStore26.instance;
    final text = List.filled(6 * 1024 * 1024, 'a').join();
    await store
        .putMap('book_blob341', {'text': text, 'sentinel': 'preservato'});
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase('${dir.path}/mgd_neuro_v026.db');
    var legacyFailed = false;
    try {
      await db.query('state_snapshots',
          columns: ['payload'], where: 'k=?', whereArgs: ['book_blob341']);
    } catch (e) {
      legacyFailed = true;
      print('BOOK341_BASELINE_RAW_QUERY_FAILURE: $e');
    }
    print('BOOK341_BASELINE_FAILED=$legacyFailed');
    await store.close319();
    final restored = await store.getMap('book_blob341');
    expect(restored!['text'], text);
    expect(restored['sentinel'], 'preservato');
    await store.deleteKey('book_blob341');
    print('BOOK341_SLICED_BLOB_REOPEN_OK bytes=${text.length}');
  });
  testWidgets(
      'Android: original language screen imports prose, exposes cancellation and keeps learned memory after reopen',
      (tester) async {
    final store = MgdStateStore26.instance;
    final models = BookModels341(PlasticLanguageBrain04(), MgdWorld06(),
        ResearchMemory11(enabled: false), MgdLanguage20());
    BookModels341 current = models;
    final checkpoint = MemoryCheckpoint319();
    ClsBridge340.active = await ClsStore340.shared;
    await tester.pumpWidget(MaterialApp(
        home: MgdLanguageLab20(
            brain: models.brain,
            world: models.world,
            research: models.research,
            language: models.language,
            onModels341: (m) => current = m,
            onSave: () => checkpoint.save(current.brain, current.world,
                current.research, current.language))));
    await tester.pumpAndSettle();
    final text = List.generate(
        160,
        (i) => 'Il quaderno descrive il campione $i. '
            'La membrana separa gli ambienti della cellula.\n').join();
    await tester.enterText(find.byType(TextField).first, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('Impara testo incollato'));
    await tester.tap(find.text('Impara testo incollato'));
    var sawCancel = false, done = false;
    for (var i = 0; i < 1800; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey('book-import-cancel'))
          .evaluate()
          .isNotEmpty) sawCancel = true;
      final status = find.byKey(const ValueKey('book-import-status'));
      if (status.evaluate().isNotEmpty) {
        final value = tester.widget<Text>(status).data ?? '';
        if (value.startsWith('Libro elaborato e salvato')) {
          done = true;
          break;
        }
        if (value.startsWith('Importazione interrotta')) fail(value);
      }
    }
    expect(done, true);
    expect(sawCancel, true);
    expect(current.language.sentences, greaterThan(100));
    await tester.pumpWidget(const SizedBox());
    await store.close319();
    final language = await store.getMap('language_v20');
    expect(MgdLanguage20.fromJson(language!).sentences,
        current.language.sentences);
    print(
        'BOOK341_ANDROID_UI_REOPEN_OK chars=${text.length} sentences=${current.language.sentences}');
  });
}
