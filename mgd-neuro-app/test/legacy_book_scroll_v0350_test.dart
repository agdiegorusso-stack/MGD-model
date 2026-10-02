import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/book_lab_page_v0342.dart';
import 'package:mgd_neuro_mobile/book_lab_service_v0342.dart';
import 'package:mgd_neuro_mobile/book_understanding_v0342.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';

Future<void> reveal(WidgetTester t, Finder f, String key) async {
  final scrolling = find
      .descendant(
          of: find.byKey(PageStorageKey(key)),
          matching: find.byType(Scrollable))
      .first;
  t.state<ScrollableState>(scrolling).position.jumpTo(0);
  await t.pumpAndSettle();
  await t.scrollUntilVisible(f, 160, scrollable: scrolling);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'legacy reader: small viewport, real lazy scroll controls and distinct tab positions',
    (t) async {
      t.view.physicalSize = const Size(360, 560);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final m = ResearchMemory11(enabled: false);
      SourceMemory323.retain(
        m,
        WebDocument11(
          family: 'locale:scroll350',
          provider: 'widget fixture',
          title: 'Compatibilità',
          url: 'local://book/scroll350/1',
          trust: .7,
          text: 'Ogni neride è un mammifero. Ogni mammifero produce latte.',
        ),
      );
      BookLab342.state(m)['activeScope'] = 'book:scroll350';
      await t.pumpWidget(
        MaterialApp(
          home: BookLabPage342(memory: m, onSave: () async {}),
        ),
      );
      for (var i = 0; i < 200; i++) {
        await t.pump(const Duration(milliseconds: 30));
        final status =
            t
                .widget<Text>(find.byKey(const ValueKey('book-lab-status')))
                .data ??
            '';
        if (status.startsWith('Pronto.')) break;
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await reveal(
        t,
        find.byKey(const ValueKey('book-question')),
        'book-questions342',
      );
      await t.enterText(
        find.byKey(const ValueKey('book-question')),
        'Che cosa produce Zeta?',
      );
      await reveal(
        t,
        find.byKey(const ValueKey('book-hypotheses')),
        'book-questions342',
      );
      await t.enterText(
        find.byKey(const ValueKey('book-hypotheses')),
        'Zeta è un neride.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await reveal(
        t,
        find.byKey(const ValueKey('book-ask')),
        'book-questions342',
      );
      await t.tap(find.byKey(const ValueKey('book-ask')).hitTestable());
      for (var i = 0; i < 200; i++) {
        await t.pump(const Duration(milliseconds: 30));
        final status =
            t
                .widget<Text>(find.byKey(const ValueKey('book-lab-status')))
                .data ??
            '';
        if (status.startsWith('Risposta con')) break;
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await reveal(
        t,
        find.byKey(const ValueKey('book-answer')),
        'book-questions342',
      );
      expect(
        t
            .widget<SelectableText>(find.byKey(const ValueKey('book-answer')))
            .data,
        'latte',
      );
      await t.tap(find.widgetWithText(Tab, 'Esame'));
      await t.pumpAndSettle();
      expect(find.byKey(const PageStorageKey('book-exam342')), findsOneWidget);
      await t.tap(find.widgetWithText(Tab, 'Interroga'));
      await t.pumpAndSettle();
      await reveal(
        t,
        find.byKey(const ValueKey('book-ask')),
        'book-questions342',
      );
      expect(
        find.byKey(const ValueKey('book-ask')).hitTestable(),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
