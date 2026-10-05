import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mgd_neuro_mobile/main.dart';
import 'package:mgd_neuro_mobile/canonical_memory_v0420.dart';
import 'package:mgd_neuro_mobile/cognitive_coordinator_v0420.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('teach, answer, correct and reopen on Android', (tester) async {
    final dir = await Directory((await getTemporaryDirectory()).path).createTemp('mgd420-ui-');
    var memory = await CanonicalMemory420.open(path: '${dir.path}/test.db');
    try {
      await tester.pumpWidget(MgdNeuralApp420(memory: memory));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impara'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('teach420')), 'La glarpa produce latte.');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Apprendi testo'), 160,
          scrollable: find.byType(Scrollable));
      await tester.tap(find.text('Apprendi testo'));
      await tester.pumpAndSettle();
      final initial = await memory.stats();
      expect(initial['claims'], 1);
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('chat420')), 'Che cosa produce la glarpa?');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send420')));
      await tester.pumpAndSettle();
      expect(find.text('latte'), findsOneWidget);
      expect((await memory.stats())['passages'], initial['passages']);
      await tester.tap(find.text('Evidenze e correzioni'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correggi questa relazione'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('correction420')), 'La glarpa produce miele.');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect((await memory.stats())['revoked'], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await memory.close();
      memory = await CanonicalMemory420.open(path: '${dir.path}/test.db');
      final coordinator = await CognitiveCoordinator420.create(memory);
      final answer = await coordinator.process('Che cosa produce la glarpa?');
      expect(answer.status, 'direct'); expect(answer.text, 'miele');
      expect(answer.evidence, isNotEmpty);
      expect((await memory.stats())['claims'], 1);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await memory.close();
      await dir.delete(recursive: true);
    }
  });
}
