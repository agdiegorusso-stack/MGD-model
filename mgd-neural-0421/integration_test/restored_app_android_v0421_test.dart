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
    await tester.tap(find.text('Impara'));
    await settle421(tester);
    expect(find.byKey(const ValueKey('import-text421')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('teaching-text421')),
        'Il zorvello contiene cristalli. Marta apre la porta.');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle421(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('learn-text421')),
        180, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('learn-text421')));
    await settle421(tester);
    final cognitive = await CognitiveCoreBridge400.stats();
    expect(cognitive['relations'], greaterThanOrEqualTo(2));
    await tester.tap(find.text('Mappa'));
    await settle421(tester);
    await tester.enterText(find.byType(TextField), 'zorvello');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle421(tester);
    expect(find.textContaining('Focus: zorvello'), findsOneWidget);
    expect(find.byKey(const ValueKey('knowledge-map-nodes')), findsOneWidget);
    expect(find.byTooltip('Salva PNG'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    final png = await binding.takeScreenshot('restored-map421');
    final temp = await getTemporaryDirectory();
    await File('${temp.path}/restored-map421.png').writeAsBytes(png);
    await tester.tap(find.text('Vivi'));
    await settle421(tester);
    await tester.enterText(find.byKey(const ValueKey('chat421')),
        'Cosa contiene il zorvello?');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle421(tester);
    await tester.tap(find.byKey(const ValueKey('send421')));
    await settle421(tester);
    expect(find.textContaining('cristalli'), findsWidgets);
    expect((await CognitiveCoreBridge400.stats())['relations'],
        cognitive['relations'], reason: 'A question is not another fact.');
    await tester.tap(find.text('Mente'));
    await settle421(tester);
    await tester.scrollUntilVisible(find.text('Pensa 96 cicli'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Pensa 96 cicli'));
    await settle421(tester);
    expect(find.text('Dormi / consolida'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('cognitive-open400')),
        -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('cognitive-open400')));
    await settle421(tester);
    await tester.enterText(find.byType(TextField).first, 'Luca chiude la finestra.');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle421(tester);
    await tester.scrollUntilVisible(find.text('Vivi e impara'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Vivi e impara'));
    await settle421(tester);
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
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle421(tester);
    expect(find.textContaining('Focus: zorvello'), findsOneWidget);
    expect((await CognitiveCoreBridge400.stats())['relations'],
        afterLab['relations']);
    expect(tester.takeException(), isNull);
  });
}
