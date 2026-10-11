import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/reading_memory_page_v0438.dart';
import '../lib/web_knowledge_explorer_v11.dart';

void main() {
  testWidgets('reading page exposes source text and searches at phone width', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final memory = ResearchMemory11();
    SourceMemory323.retain(memory, const WebDocument11(provider: 'Test', family: 'test',
      title: 'Procedura Merlo', url: 'local://merlo',
      text: 'La pompa trasporta il liquido. Il sensore misura la pressione.', trust: .8));
    await tester.pumpWidget(MaterialApp(home: ReadingMemoryPage438(memory: memory)));
    expect(find.text('2 passaggi conservati · 1 fonti'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pressione');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('1 passaggi pertinenti'), findsOneWidget);
    expect(find.text('Il sensore misura la pressione.'), findsOneWidget);
    expect(find.text('La pompa trasporta il liquido.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
