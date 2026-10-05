import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/closed_book_page_v0350.dart';
import 'package:mgd_neuro_mobile/closed_book_store_v0350.dart';
import 'package:mgd_neuro_mobile/story_graph_v0350.dart';

Future<void> wait350(WidgetTester tester, String prefix) async {
  for (var n = 0; n < 500; n++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 20));
    final f = find.byKey(const ValueKey('closed-status'));
    if (f.evaluate().isNotEmpty) {
      final status = tester.widget<Text>(f).data ?? '';
      if (status.startsWith(prefix)) return;
      if (status.startsWith('Operazione interrotta') ||
          status.startsWith('Memoria non aperta') ||
          status.startsWith('Selezione non completata')) fail(status);
    }
  }
  fail(
      'Timeout waiting for $prefix; current: ${tester.widget<Text>(find.byKey(const ValueKey('closed-status'))).data}');
}

Future<void> tab350(WidgetTester t, String name) async {
  await t.ensureVisible(find.widgetWithText(Tab, name));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(Tab, name));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(() async {
    final fontRoot = Platform.environment['MGD_TEST_FONT_ROOT'];
    if (fontRoot == null) return;
    for (final font in {
      'MGDReview': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf'
    }.entries) {
      final loader = FontLoader(font.key)
        ..addFont(Future.value(ByteData.sublistView(
            File('$fontRoot/${font.value}').readAsBytesSync())));
      await loader.load();
    }
  });
  testWidgets(
      'read actual pasted input, closed-book response, event graph, correction and independent exam',
      (t) async {
    final dir = Directory.systemTemp.createTempSync('mgd350-ui-');
    late ClosedBookStore350 store;
    await t.runAsync(() async {
      store = await ClosedBookStore350.open(
          path: '${dir.path}/db', factory: databaseFactoryFfi);
    });
    const path = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(path, (_) async => dir.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(path, null);
      await store.close();
      dir.deleteSync(recursive: true);
    });
    await t.pumpWidget(MaterialApp(
        theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: Platform.environment['MGD_TEST_FONT_ROOT'] == null
                ? null
                : 'MGDReview'),
        home: ClosedBookPage350(store: store)));
    await wait350(t, 'Pronto.');
    await t.ensureVisible(find.byKey(const ValueKey('closed-input')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('closed-input')),
        'Marta possedeva una chiave. La prestò a Luca. Luca la nascose sotto il vaso.');
    await t.ensureVisible(find.byKey(const ValueKey('closed-learn')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('closed-learn')));
    await wait350(t, 'Lettura consolidata');
    await t.pumpAndSettle();
    expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('closed-input')))
            .controller!
            .text,
        isEmpty);
    await tab350(t, 'Ricorda');
    await t.ensureVisible(find.byKey(const ValueKey('closed-question')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('closed-question')),
        'Chi nascose la chiave?');
    await t.ensureVisible(find.byKey(const ValueKey('closed-ask')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('closed-ask')));
    await wait350(t, 'Risposta da eventi');
    await t.pumpAndSettle();
    expect(
        t
            .widget<SelectableText>(find.byKey(const ValueKey('closed-answer')))
            .data,
        'luca');
    await tab350(t, 'Storia');
    expect(find.byType(StoryGraph350), findsOneWidget);
    await t.ensureVisible(find.text('Ricostruisci il riassunto'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ricostruisci il riassunto'));
    for (var n = 0; n < 25; n++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 20));
    }
    expect(find.byType(SelectableText), findsWidgets);
    await t.scrollUntilVisible(
        find.widgetWithText(ExpansionTile, 'Marta possedeva chiave.'), 200,
        scrollable: find
            .descendant(
                of: find.byKey(const PageStorageKey('closed-scroll-story')),
                matching: find.byType(Scrollable))
            .first);
    await t.pumpAndSettle();
    await t.tap(find.text('Marta possedeva chiave.').last);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Correggi il ricordo').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Correggi il ricordo').first);
    await t.pumpAndSettle();
    await t.enterText(
        find.byKey(const ValueKey('correct350-subject')), 'Nadia');
    await t.tap(find.text('Salva correzione'));
    await wait350(t, 'Ricordo corretto');
    await t.pumpAndSettle();
    String? id;
    await t.runAsync(() async {
      id = await store.active();
      await store.setCases(id!, [
        {
          'id': 'a',
          'question': 'Chi nascose la chiave?',
          'expected': 'answer',
          'answers': ['luca']
        },
        {
          'id': 'b',
          'question': 'Chi possiede la chiave?',
          'expected': 'answer',
          'answers': ['nadia']
        },
      ]);
    });
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await t.pumpWidget(MaterialApp(home: ClosedBookPage350(store: store)));
    await wait350(t, 'Pronto a libro chiuso');
    await tab350(t, 'Esame');
    await t.scrollUntilVisible(
        find.byKey(const ValueKey('closed-run-exam')), 150,
        scrollable: find
            .descendant(
                of: find.byKey(const PageStorageKey('closed-scroll-exam')),
                matching: find.byType(Scrollable))
            .first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('closed-run-exam')));
    await wait350(t, 'Esame conservato');
    await t.pumpAndSettle();
    await t.runAsync(() async {
      final r = (await store.reports(id!)).single;
      expect(r['correctAnswerable'], 2);
      expect((r['emptyControl'] as Map)['correctAnswerable'], 0);
    });
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets(
      'small phone and enlarged text remain scrollable; graph is inspectable',
      (t) async {
    final dir = Directory.systemTemp.createTempSync('mgd350-ui-small-');
    late ClosedBookStore350 store;
    await t.runAsync(() async {
      store = await ClosedBookStore350.open(
          path: '${dir.path}/db', factory: databaseFactoryFfi);
      final f = File('${dir.path}/book.txt')
        ..writeAsStringSync(
            'Marta presta la chiave a Luca. Luca nasconde la chiave sotto il vaso.');
      await store.importFile(f, title: 'Il prestito.txt');
      await f.delete();
    });
    addTearDown(() async {
      await store.close();
      dir.deleteSync(recursive: true);
    });
    await t.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
        theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: Platform.environment['MGD_TEST_FONT_ROOT'] == null
                ? null
                : 'MGDReview'),
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(360, 740), textScaler: TextScaler.linear(1.15)),
            child: RepaintBoundary(
                key: key, child: ClosedBookPage350(store: store)))));
    await wait350(t, 'Pronto a libro chiuso');
    await t.pumpAndSettle();
    await tab350(t, 'Storia');
    await t.scrollUntilVisible(find.byType(StoryGraph350), 150,
        scrollable: find
            .descendant(
                of: find.byKey(const PageStorageKey('closed-scroll-story')),
                matching: find.byType(Scrollable))
            .first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    if (Platform.environment['MGD_SCREENSHOT_DIR'] != null) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File(
            '${Platform.environment['MGD_SCREENSHOT_DIR']}/storia-0350.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
