import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mgd_neuro_mobile/closed_book_page_v0350.dart';
import 'package:mgd_neuro_mobile/closed_book_store_v0350.dart';
import 'package:mgd_neuro_mobile/closed_book_service_v0350.dart';
import 'package:mgd_neuro_mobile/story_graph_v0350.dart';
import 'package:mgd_neuro_mobile/main.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/mgd_state_store_v026.dart';
import 'package:mgd_neuro_mobile/memory_runtime_v0319.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/knowledge_inspector_v0315.dart';

Future<void> wait350(WidgetTester t, String prefix) async {
  for (var i = 0; i < 900; i++) {
    await t.pump(const Duration(milliseconds: 100));
    final f = find.byKey(const ValueKey('closed-status'));
    if (f.evaluate().isNotEmpty) {
      final value = t.widget<Text>(f).data ?? '';
      if (value.startsWith(prefix)) return;
      if (value.startsWith('Operazione interrotta') ||
          value.startsWith('Selezione non completata') ||
          value.startsWith('Memoria non aperta')) fail(value);
    }
  }
  fail('Timeout: $prefix');
}

Future<void> scroll350(WidgetTester t, Finder f, String page) async {
  await t.scrollUntilVisible(f, 180,
      scrollable: find
          .descendant(
              of: find.byKey(PageStorageKey('closed-scroll-$page')),
              matching: find.byType(Scrollable))
          .first);
  await t.pumpAndSettle();
}

Future<void> tab350(WidgetTester t, String name) async {
  await t.ensureVisible(find.widgetWithText(Tab, name));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(Tab, name));
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android: actual main entry, acquisition, event graph and Libro chat without source learning',
      (t) async {
    final old = MgdStateStore26.instance, s = await ClosedBookStore350.shared;
    await s.clear();
    await old.clearAll();
    final research = ResearchMemory11(enabled: false)
      ..state317
          .addAll({'migrationComplete': true, 'recovery320Complete': true});
    await MemoryCheckpoint319().save(
        PlasticLanguageBrain04(), MgdWorld06(), research, MgdLanguage20());
    await t.pumpWidget(const MgdNeuro04App());
    for (var i = 0;
        i < 300 && find.byType(InspectorScope315).evaluate().isEmpty;
        i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(InspectorScope315), findsOneWidget);
    await t.tap(find.text('Mente'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
        find.byKey(const ValueKey('closed-open350')), 180,
        scrollable: find.byType(Scrollable).last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('closed-open350')));
    await wait350(t, 'Pronto.');
    expect(find.byType(ClosedBookPage350), findsOneWidget);
    await scroll350(t, find.byKey(const ValueKey('closed-input')), 'read');
    await t.tap(find.byKey(const ValueKey('closed-input')));
    await t.enterText(find.byKey(const ValueKey('closed-input')),
        'Marta possedeva una chiave. La prestò a Luca. Luca la nascose sotto il vaso.');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await scroll350(t, find.byKey(const ValueKey('closed-learn')), 'read');
    await t.tap(find.byKey(const ValueKey('closed-learn')));
    await wait350(t, 'Lettura consolidata');
    await tab350(t, 'Ricorda');
    await scroll350(t, find.byKey(const ValueKey('closed-question')), 'recall');
    await t.tap(find.byKey(const ValueKey('closed-question')));
    await t.enterText(find.byKey(const ValueKey('closed-question')),
        'Chi nascose la chiave?');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await scroll350(t, find.byKey(const ValueKey('closed-ask')), 'recall');
    await t.tap(find.byKey(const ValueKey('closed-ask')));
    await wait350(t, 'Risposta da eventi');
    await scroll350(t, find.byKey(const ValueKey('closed-answer')), 'recall');
    expect(
        t
            .widget<SelectableText>(find.byKey(const ValueKey('closed-answer')))
            .data,
        'luca');
    await tab350(t, 'Storia');
    await scroll350(t, find.byType(StoryGraph350), 'story');
    expect(find.byType(StoryGraph350), findsOneWidget);
    final id = (await s.active())!, revision = (await s.book(id))!['revision'];
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await t.tap(find.text('Vivi'));
    await t.pumpAndSettle();
    final field = find.byType(TextField);
    await t.tap(field);
    await t.enterText(field, 'Libro: Dove si trova la chiave?');
    final send = find.ancestor(
        of: find.byIcon(Icons.arrow_upward), matching: find.byType(IconButton));
    for (var i = 0;
        i < 300 && t.widget<IconButton>(send).onPressed == null;
        i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tap(send.hitTestable());
    for (var i = 0; i < 600; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (t.widget<TextField>(field).controller!.text.isEmpty &&
          t.widget<IconButton>(send).onPressed != null) break;
    }
    await t.pumpAndSettle();
    final rendered = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join('\n');
    expect(rendered, contains('sotto il vaso'));
    expect(rendered, contains('A libro chiuso'));
    expect((await s.book(id))!['revision'], revision);
    expect(t.takeException(), isNull);
    print(
        'CLOSED350_ANDROID_UI mainEntry=true sourceTextStored=false graph=true chat=sotto_il_vaso queryNotLearned=true');
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    ClosedBookBridge350.close();
    await s.clear();
    await old.clearAll();
    await old.close319();
  });
  testWidgets(
      'Android: 12000-event book cancels, resumes, deletes source and recalls after SQL close',
      (t) async {
    final path = '${await getDatabasesPath()}/closed_stress350.db';
    await deleteDatabase(path);
    var s = await ClosedBookStore350.open(path: path);
    final dir = await getTemporaryDirectory(),
        f = File('${dir.path}/closed-stress350.txt'),
        source = StringBuffer();
    for (var i = 0; i < 12000; i++) {
      source.writeln('Persona$i apre la porta$i.');
    }
    await f.writeAsString(source.toString());
    final bytes = await f.length(),
        timer = Stopwatch()..start(),
        rss = ProcessInfo.currentRss;
    bool stop = false;
    final partial = await s.importFile(f,
        title: 'Stress350.txt',
        cancelled: () => stop,
        progress: (r) {
          if ((r['units'] as int) >= 2) stop = true;
        });
    expect(partial['complete'], 0);
    expect(partial['units'], 2);
    await s.close();
    s = await ClosedBookStore350.open(path: path);
    final full = await s.importFile(f, title: 'Stress350.txt');
    timer.stop();
    expect(full['complete'], 1);
    expect(full['events'], 12000);
    await f.delete();
    expect(await f.exists(), isFalse);
    final id = full['id'] as String, snapshot = await s.snapshot(id);
    await s.close();
    final worker = await ClosedRecallWorker350.open(snapshot);
    try {
      final a =
              await worker.call('ask', {'question': 'Che cosa apre Persona0?'}),
          b = await worker
              .call('ask', {'question': 'Che cosa apre Persona11999?'});
      expect(a['answer'], 'porta0');
      expect(b['answer'], 'porta11999');
      expect(a['rawPassagesRead'], 0);
      expect(b['rawPassagesRead'], 0);
      print(
          'CLOSED350_ANDROID_STRESS events=12000 bytes=$bytes elapsedMs=${timer.elapsedMilliseconds} rssStart=$rss rssEnd=${ProcessInfo.currentRss} cancelledUnits=2 fileDeleted=true sqliteClosedAtRecall=true first=porta0 last=porta11999');
    } finally {
      worker.close();
      await deleteDatabase(path);
    }
  });
  testWidgets(
      'Android: corrections, independent exam and multi-megabyte reports survive reopen',
      (t) async {
    final path = '${await getDatabasesPath()}/closed_records350.db';
    await deleteDatabase(path);
    var s = await ClosedBookStore350.open(path: path);
    final dir = await getTemporaryDirectory(),
        f = File('${dir.path}/closed-records350.txt')
          ..writeAsStringSync('Marta apre la porta. Luca legge il giornale.');
    final id = (await s.importFile(f, title: 'Records350.txt'))['id'] as String;
    await f.delete();
    final first = (await s.eventPage(id)).first;
    await s.correctEvent(
        id, '${first['id']}', {'subject': 'Nadia', 'object': 'finestra'});
    final worker = await ClosedRecallWorker350.open(await s.snapshot(id));
    try {
      final report = await ClosedBookExam350.run(worker, [
        {
          'id': 'corrected',
          'question': 'Chi apre la finestra?',
          'answers': ['nadia'],
          'expected': 'answer'
        },
        {
          'id': 'absent',
          'question': 'Di che colore è il giornale?',
          'answers': [],
          'expected': 'unknown'
        }
      ]);
      expect(report['correct'], 2);
      await s.saveReport(id, report);
      final payload = List.filled(2300000, 'à').join();
      await s.saveReport(id, {'payload': payload});
      bool legacyFailed = false;
      try {
        await s.db.query('reports', orderBy: 'id DESC', limit: 1);
      } on DatabaseException catch (e) {
        if (!'$e'.contains('CursorWindow') && !'$e'.contains('Row too big'))
          rethrow;
        legacyFailed = true;
      }
      await s.close();
      s = await ClosedBookStore350.open(path: path);
      expect((await s.reports(id)).single['payload'], payload);
      final reopened = await ClosedRecallWorker350.open(await s.snapshot(id));
      try {
        expect(
            (await reopened
                .call('ask', {'question': 'Chi apre la finestra?'}))['answer'],
            'nadia');
      } finally {
        reopened.close();
      }
      print(
          'CLOSED350_ANDROID_RECORDS corrected=nadia exam=2/2 reportUtf8Bytes=4600000 oldUnboundedReadFailed=$legacyFailed boundedRead=true reopen=true');
    } finally {
      worker.close();
      await s.close();
      await deleteDatabase(path);
    }
  });
}
