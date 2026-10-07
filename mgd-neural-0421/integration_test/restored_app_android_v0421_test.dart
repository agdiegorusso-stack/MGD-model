import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mgd_neuro_mobile/main.dart';
import 'package:mgd_neuro_mobile/mgd_state_store_v026.dart';
import 'package:mgd_neuro_mobile/cls_bridge_v0340.dart';
import 'package:mgd_neuro_mobile/cls_store_v0340.dart';
import 'package:mgd_neuro_mobile/cognitive_core_v0400.dart';
import 'package:mgd_neuro_mobile/dialogue_engine_v0410.dart';
import 'package:mgd_neuro_mobile/knowledge_inspector_v0315.dart';

Future<void> settle421(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 45));
}

Future<void> ready421(WidgetTester tester, Finder button) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final matches = button.evaluate();
    if (matches.length == 1) {
      final widget = matches.single.widget;
      if ((widget is ButtonStyleButton && widget.onPressed != null) ||
          (widget is IconButton && widget.onPressed != null)) {
        await settle421(tester);
        return;
      }
    }
  }
  throw TestFailure('The operation did not finish: $button');
}

Finder button421(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton))
    .first;

Future<void> keyboardClosed421(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  do {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.view.viewInsets.bottom == 0) {
      await settle421(tester);
      return;
    }
  } while (DateTime.now().isBefore(deadline));
  throw TestFailure('The Android keyboard did not close.');
}

Future<void> sendTopic423(WidgetTester tester, String topic) async {
  await keyboardClosed421(tester);
  await ready421(tester, find.byKey(const ValueKey('send421')));
  // Set the editing value with the IME disconnected: closing the native
  // keyboard after tester.enterText can replay its stale empty editing state.
  final field = tester.widget<TextField>(find.byKey(const ValueKey('chat421')));
  field.controller!.value = TextEditingValue(text: topic,
      selection: TextSelection.collapsed(offset: topic.length));
  await settle421(tester);
  expect(field.controller!.text, topic);
  expect(tester.widget<IconButton>(find.byKey(const ValueKey('send421'))).onPressed,
      isNotNull);
  await tester.tap(find.byKey(const ValueKey('send421')));
}

Future<ChatMessage04> reply423(WidgetTester tester, String prompt) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final page = tester.widget<LivePage07>(find.byType(LivePage07));
    final replies = page.messages.where((m) => !m.user && m.prompt == prompt);
    if (!page.busy && replies.isNotEmpty) return replies.last;
  }
  final page = tester.widget<LivePage07>(find.byType(LivePage07));
  throw TestFailure('No completed reply for $prompt. Messages: '
      '${page.messages.map((m) => m.text).toList()}. '
      'UI: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');
}

Future<void> showReply423(WidgetTester tester, String expected) async {
  // A builder can leave the last long message outside its estimated extent.
  // Scroll as a user would, then assert the actual rendered response too.
  final finder = find.textContaining(expected);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: find.byType(Scrollable).first, maxScrolls: 20);
  }
  await settle421(tester);
  expect(finder, findsWidgets);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('teach, map, answer, engine controls and persisted restart',
      (tester) async {
    await MgdStateStore26.instance.clearAll();
    ClsBridge340.active = await ClsStore340.shared;
    await ClsBridge340.clear();
    await DialogueBridge410.reset();
    await tester.pumpWidget(const MgdNeuro04App());
    for (var n = 0; n < 150; n++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(InspectorScope315).evaluate().isNotEmpty) break;
    }
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('MGD Neuro 0.42.5'), findsOneWidget);
    await tester.tap(find.text('Impara'));
    await settle421(tester);
    expect(find.byKey(const ValueKey('teaching-text421')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('teaching-text421')),
        'Il zorvello contiene cristalli. Marta apre la porta.');
    await keyboardClosed421(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('learn-text421')),
        180, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('import-text421')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn-text421')));
    await ready421(tester, find.byKey(const ValueKey('learn-text421')));
    await settle421(tester);
    final cognitive = await CognitiveCoreBridge400.stats();
    expect(cognitive['relations'], greaterThanOrEqualTo(2));
    await tester.tap(find.text('Mappa'));
    await settle421(tester);
    await tester.enterText(find.byType(TextField), 'zorvello');
    await tester.tap(find.byTooltip('Cerca'));
    await keyboardClosed421(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    final png = await binding.takeScreenshot('restored-map421');
    final temp = await getTemporaryDirectory();
    await File('${temp.path}/restored-map421.png').writeAsBytes(png);
    final focus = find.textContaining(
        RegExp(r'Focus:\s*zorvello\b', caseSensitive: false));
    if (focus.evaluate().isEmpty) {
      debugPrint('MAP421: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');
    }
    expect(focus, findsOneWidget);
    expect(find.byKey(const ValueKey('knowledge-map-nodes')), findsOneWidget);
    expect(find.byTooltip('Salva PNG'), findsOneWidget);
    await tester.tap(find.text('Vivi'));
    await settle421(tester);
    await tester.enterText(find.byKey(const ValueKey('chat421')),
        'Cosa contiene il zorvello?');
    await keyboardClosed421(tester);
    await tester.tap(find.byKey(const ValueKey('send421')));
    await ready421(tester, find.byKey(const ValueKey('send421')));
    await settle421(tester);
    expect(find.textContaining('cristalli'), findsWidgets);
    expect((await CognitiveCoreBridge400.stats())['relations'],
        cognitive['relations'], reason: 'A question is not another fact.');
    // Regression: original brain knowledge is visible in Mondo but was ignored
    // by the chat, which quoted the just-entered topic from CLS instead.
    final inspector423 = tester.widget<InspectorScope315>(find.byType(InspectorScope315)).inspector;
    inspector423.brain.importTeacherFact08(subject: 'Muscolo scheletrico',
        relation: 'ha funzione', object: 'Movimento volontario', confidence: .95);
    inspector423.brain.importTeacherFact08(subject: 'Movimento volontario',
        relation: 'è funzione associata a', object: 'Muscolo scheletrico', confidence: .95);
    inspector423.brain.importTeacherFact08(subject: 'Rattus',
        relation: 'tipo di', object: 'Roditore', confidence: .95);
    // 0.42.4: compatible containment/localization facts must coexist on Android.
    for (final fixture424 in [
      ('Cellula eucariotica', 'contiene o ospita', 'nucleo'),
      ('Cellula eucariotica', 'contiene o ospita', 'mitocondrio'),
      ('Proteina AOX2 (Arabidopsis thaliana)', 'ha localizzazione o associazione cellulare annotata in', 'cloroplasto'),
      ('Proteina AOX2 (Arabidopsis thaliana)', 'ha localizzazione o associazione cellulare annotata in', 'mitocondrio'),
    ]) {
      inspector423.brain.importTeacherFact08(subject: fixture424.$1,
          relation: fixture424.$2, object: fixture424.$3, confidence: .9);
    }
    await sendTopic423(tester, 'cellula eucariotica');
    final compatible424 = await reply423(tester, 'cellula eucariotica');
    expect(compatible424.text, allOf(contains('Nucleo'), contains('Mitocondrio')));
    expect(compatible424.text, isNot(contains('IN CONFLITTO')));
    final episodes423 = (await ClsBridge340.active!.db.query('episodes')).length;
    for (final topic423 in ['movimento volontario', 'rattus', 'Parlami del rattus']) {
      await sendTopic423(tester, topic423);
      final reply = await reply423(tester, topic423);
      final expected = topic423 == 'movimento volontario'
          ? 'Muscolo scheletrico — ha funzione → Movimento volontario'
          : 'Rattus — è → Roditore';
      debugPrint('CHAT423: $topic423 -> ${reply.text}');
      expect(reply.text, contains(expected));
      await showReply423(tester, expected);
    }
    expect(find.textContaining('Passaggio richiamato, non verificato:'), findsNothing);
    expect((await ClsBridge340.active!.db.query('episodes')).length, episodes423);
    expect((await CognitiveCoreBridge400.stats())['relations'], cognitive['relations']);
    final chatPng423 = await binding.takeScreenshot('chat-map423');
    await File('${temp.path}/chat-map423.png').writeAsBytes(chatPng423);
    await tester.tap(find.text('Mente'));
    await settle421(tester);
    await tester.scrollUntilVisible(find.text('Pensa 96 cicli'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Pensa 96 cicli'));
    await ready421(tester, button421('Pensa 96 cicli'));
    await settle421(tester);
    expect(find.text('Dormi / consolida'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('cognitive-open400')),
        -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('cognitive-open400')));
    await settle421(tester);
    await tester.enterText(find.byType(TextField).first, 'Luca chiude la finestra.');
    await keyboardClosed421(tester);
    await tester.scrollUntilVisible(button421('Vivi e impara').hitTestable(), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(button421('Vivi e impara'));
    await settle421(tester);
    await tester.tap(button421('Vivi e impara').hitTestable());
    await ready421(tester, button421('Vivi e impara'));
    await settle421(tester);
    await tester.scrollUntilVisible(find.textContaining('Frame:'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Frame:'), findsOneWidget);
    expect(find.textContaining('Salienza'), findsOneWidget);
    final afterLab = await CognitiveCoreBridge400.stats();
    expect(afterLab['relations'], greaterThan(cognitive['relations'] as num));
    await tester.pageBack();
    await settle421(tester);
    await tester.pumpWidget(const SizedBox());
    await settle421(tester);
    await tester.pumpWidget(const MgdNeuro04App());
    for (var n = 0; n < 150; n++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(InspectorScope315).evaluate().isNotEmpty) break;
    }
    await tester.tap(find.text('Mappa'));
    await settle421(tester);
    await tester.enterText(find.byType(TextField), 'zorvello');
    await tester.tap(find.byTooltip('Cerca'));
    await keyboardClosed421(tester);
    expect(find.textContaining(RegExp(r'Focus:\s*zorvello\b', caseSensitive: false)), findsOneWidget);
    expect((await CognitiveCoreBridge400.stats())['relations'],
        afterLab['relations']);
    await tester.tap(find.text('Vivi'));
    await settle421(tester);
    await sendTopic423(tester, 'cellula eucariotica');
    final restartedCompatible424 = await reply423(tester, 'cellula eucariotica');
    expect(restartedCompatible424.text, allOf(contains('Nucleo'), contains('Mitocondrio')));
    expect(restartedCompatible424.text, isNot(contains('IN CONFLITTO')));
    await sendTopic423(tester, 'movimento volontario');
    final restartedReply423 = await reply423(tester, 'movimento volontario');
    expect(restartedReply423.text, contains('Muscolo scheletrico — ha funzione → Movimento volontario'));
    await showReply423(tester, 'Muscolo scheletrico — ha funzione → Movimento volontario');
    await tester.tap(find.text('Mappa'));
    await settle421(tester);
    await tester.enterText(find.byType(TextField), 'zorvello');
    await tester.tap(find.byTooltip('Cerca'));
    await keyboardClosed421(tester);
    // Deleting from the restored map must also remove the newer SQL memory.
    await tester.scrollUntilVisible(find.text('Elimina nodo e riferimenti'), 120,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Elimina nodo e riferimenti').hitTestable());
    await settle421(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await settle421(tester);
    final deletionDeadline = DateTime.now().add(const Duration(seconds: 45));
    while (find.textContaining(RegExp(r'Focus:\s*zorvello\b',
            caseSensitive: false)).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deletionDeadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining(RegExp(r'Focus:\s*zorvello\b',
        caseSensitive: false)), findsNothing);
    final core = await CognitiveCoreBridge400.core;
    expect(await core.store.concept('zorvello'), isNull);
    expect(await core.store.answerRelation('Cosa contiene il zorvello?'), isNull);
    final retained = await ClsBridge340.active!.db.query('episodes');
    expect(retained.any((row) => '${row['text']}'.contains('zorvello')), false);
    expect(await core.store.concept('marta'), isNotNull);
    await tester.pumpWidget(const SizedBox());
    await settle421(tester);
    await tester.pumpWidget(const MgdNeuro04App());
    for (var n = 0; n < 150; n++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(InspectorScope315).evaluate().isNotEmpty) break;
    }
    await tester.tap(find.text('Mappa'));
    await settle421(tester);
    await tester.enterText(find.byType(TextField), 'zorvello');
    await tester.tap(find.byTooltip('Cerca'));
    await keyboardClosed421(tester);
    expect(find.textContaining('non è presente nelle memorie consultabili'),
        findsOneWidget);
    expect(await (await CognitiveCoreBridge400.core).store.concept('zorvello'),
        isNull);
    expect(tester.takeException(), isNull);
  });
}
