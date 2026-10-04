import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/closed_book_page_v0350.dart';
import 'package:mgd_neuro_mobile/closed_book_store_v0350.dart';

Future<void> ready350(WidgetTester t, String prefix) async {
  for (var i = 0; i < 500; i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await t.pump(const Duration(milliseconds: 20));
    final f = find.byKey(const ValueKey('closed-status'));
    if (f.evaluate().isNotEmpty &&
        (t.widget<Text>(f).data ?? '').startsWith(prefix)) return;
  }
  fail('Did not reach $prefix');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets(
      'answer evidence uses its own boolean storage, not the parent scroll double',
      (t) async {
    final d = Directory.systemTemp.createTempSync('mgd-expansion350-');
    late ClosedBookStore350 store;
    await t.runAsync(() async {
      store = await ClosedBookStore350.open(
          path: '${d.path}/db', factory: databaseFactoryFfi);
      final f = File('${d.path}/book.txt')
        ..writeAsStringSync(
            'Marta presta la chiave a Luca. Luca nasconde la chiave sotto il vaso.');
      await store.importFile(f, title: 'Evidenze');
      await f.delete();
    });
    addTearDown(() async {
      await store.close();
      d.deleteSync(recursive: true);
    });
    await t.pumpWidget(MaterialApp(home: ClosedBookPage350(store: store)));
    await ready350(t, 'Pronto a libro chiuso');
    await t.tap(find.widgetWithText(Tab, 'Ricorda'));
    await t.pumpAndSettle();
    final list = find.byKey(const PageStorageKey('closed-scroll-recall'));
    final element = t.element(list);
    // Deterministically reproduce the real scroll restoration value from Android.
    PageStorage.of(element).writeState(element, 96.0);
    await t.enterText(find.byKey(const ValueKey('closed-question')),
        'Chi nasconde la chiave?');
    await t.ensureVisible(find.byKey(const ValueKey('closed-ask')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('closed-ask')));
    await ready350(t, 'Risposta da eventi');
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byType(ExpansionTile).first, 140,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)).first);
    await t.pumpAndSettle();
    final evidence =
        t.widgetList<ExpansionTile>(find.byType(ExpansionTile)).toList();
    expect(evidence, isNotEmpty);
    expect(evidence.map((e) => e.key).toSet().length, evidence.length);
    for (final e in evidence) {
      expect(e.key, isA<PageStorageKey<String>>());
    }
    await t.tap(find.byType(ExpansionTile).first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.widgetWithText(Tab, 'Italiano'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(Tab, 'Ricorda'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
        t
            .widget<SelectableText>(find.byKey(const ValueKey('closed-answer')))
            .data,
        'luca');
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
