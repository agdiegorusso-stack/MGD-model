import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/main.dart';
import 'package:mgd_neuro_mobile/curiosity_actions_v0316.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';

class Fixture316 {
  final brain = PlasticLanguageBrain04();
  final world = MgdWorld06();
  late final int a, b;
  Fixture316({String first = 'Società cooperativa', String second = 'Organizzazione'}) {
    a = brain.ensureSemanticEntity06(first);
    b = brain.ensureSemanticEntity06(second);
    final nodes = ['e:$a', 'e:$b']..sort();
    world.edges['${nodes[0]}|${nodes[1]}'] = WorldEdge06(a: nodes[0], b: nodes[1],
      cost: 0.1, fast: 0.8, slow: 0.8, uses: 8);
  }
  void ask() { expect(world.nextCuriosityQuestion09(brain), isNotNull); }
  void fact(int s, int o) => brain.importTeacherFact08(subject: brain.entities[s].label,
    relation: 'is_a', object: brain.entities[o].label, confidence: 0.99);
}

Future<void> mountLive316(WidgetTester tester, Fixture316 f, {
    List<ChatMessage04>? messages, bool busy = false,
    Future<void> Function(String, String)? onResult,
    Future<void> Function(ChatMessage04)? onCorrect,
    Future<void> Function(ChatMessage04)? onVariation,
}) async {
  final chat = TextEditingController(), label = TextEditingController();
  final scroll = ScrollController();
  addTearDown(() { chat.dispose(); label.dispose(); scroll.dispose(); });
  final rows = messages ?? [ChatMessage04(user: false,
    text: f.world.pendingCuriosityQuestion09!, curiosityKey316: f.world.pendingCuriosityKey316)];
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
    builder: (context, setState) => LivePage07(brain: f.brain, world: f.world,
      messages: rows, controller: chat, scroll: scroll, busy: busy,
      last: null, labelController: label,
      onCuriosityBusy316: (v) => setState(() => busy = v),
      onCuriosityResult316: (u, a) async {
        if (onResult != null) await onResult(u, a);
        setState(() {});
      },
      onSend: () async {}, onFeedback: (_, __) async {},
      onCorrect: onCorrect ?? (_) async {}, onAddVariation: onVariation ?? (_) async {},
      onCamera: () async {}, onGallery: () async {}, onListen: () async {}, onBind: () async {},
    ),
  ))));
  await tester.pumpAndSettle();
}

void main() {
  test('unknown co-activation asks a neutral relation, never a class name', () {
    final f = Fixture316(); f.ask();
    expect(f.world.pendingCuriosityType09, 'relation');
    expect(f.world.pendingCuriosityQuestion09, contains('non basta'));
    expect(f.world.pendingCuriosityQuestion09, isNot(contains('regione molto coesa')));
  });
  test('known cooperative -> organization hierarchy does not ask again', () {
    final f = Fixture316(); f.fact(f.a, f.b);
    expect(f.world.nextCuriosityQuestion09(f.brain), isNull);
  });
  test('known inverse hierarchy is checked too', () {
    final f = Fixture316(); f.fact(f.b, f.a);
    expect(f.world.nextCuriosityQuestion09(f.brain), isNull);
  });
  test('transitive hierarchy is not mistaken for an unnamed class', () {
    final f = Fixture316();
    final middle = f.brain.ensureSemanticEntity06('Impresa');
    f.fact(f.a, middle); f.fact(middle, f.b);
    expect(f.world.nextCuriosityQuestion09(f.brain), isNull);
  });
  test('members with a known common parent need no new group name', () {
    final f = Fixture316(first: 'Cane', second: 'Gatto');
    final animal = f.brain.ensureSemanticEntity06('Animale');
    f.fact(f.a, animal); f.fact(f.b, animal);
    expect(f.world.nextCuriosityQuestion09(f.brain), isNull);
  });
  test('skip does not modify brain or permit immediate repeat', () {
    final f = Fixture316(); f.ask();
    final before = f.brain.encodeJson();
    expect(f.world.consumeCuriosityAnswer09(f.brain, 'Salta.'), contains('saltata'));
    expect(f.brain.encodeJson(), before);
    expect(f.world.pendingCuriosityKey316, isNull);
    f.world.step += 1000;
    expect(f.world.nextCuriosityQuestion09(f.brain), isNull);
  });
  test('single category label is not silently installed as a category', () {
    final f = Fixture316(); f.ask(); final before = f.brain.encodeJson();
    expect(f.world.consumeCuriosityAnswer09(f.brain, 'Organizzazione'), contains('Rispondi'));
    expect(f.brain.encodeJson(), before);
    expect(f.world.pendingCuriosityKey316, isNotNull);
  });
  test('explicit Italian relation creates only the intended directed fact', () {
    final f = Fixture316(); f.ask();
    final result = f.world.consumeCuriosityAnswer09(f.brain,
      'La società cooperativa è un tipo di organizzazione.');
    expect(result, contains('registrato'));
    final facts = f.brain.cognitiveFacts06();
    expect(facts.any((x) => x.subjectId == f.a && x.objectEntityId == f.b), isTrue);
    expect(facts.any((x) => x.subjectId == x.objectEntityId), isFalse);
    expect(f.brain.entityIdForLabel06('La società cooperativa è un tipo di organizzazione'), isNull);
    expect(f.world.pendingCuriosityKey316, isNull);
  });
  test('ambiguous text is not learned and keeps question open', () {
    final f = Fixture316(); f.ask(); final before = f.brain.encodeJson();
    expect(f.world.consumeCuriosityAnswer09(f.brain, 'Sono cose molto diverse'), contains('Non ho interpretato'));
    expect(f.brain.encodeJson(), before);
    expect(f.world.pendingCuriosityKey316, isNotNull);
  });
  test('unrelated question does not become the category name', () {
    final f = Fixture316(); f.ask(); final key = f.world.pendingCuriosityKey316;
    expect(f.world.consumeCuriosityAnswer09(f.brain, 'Che ore sono?'), isNull);
    expect(f.world.pendingCuriosityKey316, key);
  });
  test('structured answer validates selected relation before learning', () {
    final f = Fixture316(); f.ask(); final before = f.brain.encodeJson();
    expect(f.world.teachCuriosityRelation316(f.brain,
      expectedKey: f.world.pendingCuriosityKey316!, relation: 'mammiferi'), contains('Scegli'));
    expect(f.brain.encodeJson(), before);
  });
  test('structured answer respects reversed direction', () {
    final f = Fixture316(); f.ask();
    f.world.teachCuriosityRelation316(f.brain,
      expectedKey: f.world.pendingCuriosityKey316!, relation: 'part_of', reverse: true);
    expect(f.brain.cognitiveFacts06().any((x) => x.subjectId == f.b && x.objectEntityId == f.a), isTrue);
    expect(f.brain.cognitiveFacts06().any((x) => x.subjectId == f.a && x.objectEntityId == f.b), isFalse);
  });
  test('self-classification is rejected even with malformed restored state', () {
    final f = Fixture316(); f.ask(); f.world.pendingCuriosityEntities09 = [f.a, f.a];
    final before = f.brain.encodeJson();
    expect(f.world.teachCuriosityRelation316(f.brain,
      expectedKey: f.world.pendingCuriosityKey316!, relation: 'is_a'), contains('Non posso'));
    expect(f.brain.encodeJson(), before);
  });
  test('taxonomy cycles are rejected without adding a fact', () {
    final f = Fixture316(); f.ask(); f.fact(f.b, f.a);
    final before = f.brain.encodeJson();
    expect(f.world.teachCuriosityRelation316(f.brain,
      expectedKey: f.world.pendingCuriosityKey316!, relation: 'is_a'), contains('ciclo'));
    expect(f.brain.encodeJson(), before);
  });
  test('stale card cannot answer or dismiss a different pending question', () {
    final f = Fixture316(); f.ask(); final key = f.world.pendingCuriosityKey316!;
    f.world.pendingCuriosityEntities09 = [f.b, f.a];
    final before = f.brain.encodeJson();
    expect(f.world.dismissCuriosity316(expectedKey: key), isFalse);
    expect(f.world.teachCuriosityRelation316(f.brain, expectedKey: key, relation: 'is_a'), contains('chiusa'));
    expect(f.brain.encodeJson(), before);
    expect(f.world.pendingCuriosityKey316, isNotNull);
  });
  test('legacy pending class question is migrated without learning', () {
    final f = Fixture316();
    f.world.pendingCuriosityType09 = 'concept-name';
    f.world.pendingCuriosityQuestion09 = 'Come chiami il gruppo?';
    f.world.pendingCuriosityEntities09 = [f.a, f.b];
    final before = f.brain.encodeJson();
    final restored = MgdWorld06.fromJson(f.world.toJson());
    expect(restored.repairPendingCuriosity316(f.brain), isTrue);
    expect(restored.pendingCuriosityType09, 'relation');
    expect(f.brain.encodeJson(), before);
  });
  test('legacy pending question about known hierarchy is dismissed', () {
    final f = Fixture316(); f.fact(f.a, f.b);
    f.world.pendingCuriosityType09 = 'concept-name';
    f.world.pendingCuriosityQuestion09 = 'Nome del gruppo?';
    f.world.pendingCuriosityEntities09 = [f.a, f.b];
    final before = f.brain.encodeJson();
    expect(f.world.repairPendingCuriosity316(f.brain), isTrue);
    expect(f.world.pendingCuriosityKey316, isNull);
    expect(f.brain.encodeJson(), before);
  });
  test('valid question and its stable key survive persistence', () {
    final f = Fixture316(); f.ask(); final restored = MgdWorld06.fromJson(f.world.toJson());
    expect(restored.pendingCuriosityKey316, f.world.pendingCuriosityKey316);
    expect(restored.repairPendingCuriosity316(f.brain), isFalse);
  });
  test('invalid entity IDs in restored question are dismissed safely', () {
    final f = Fixture316(); f.ask(); f.world.pendingCuriosityEntities09 = [-1, 999999];
    expect(f.world.repairPendingCuriosity316(f.brain), isTrue);
    expect(f.world.pendingCuriosityKey316, isNull);
  });

  for (final action in ['Rispondi', 'Correggi', 'Aggiungi variazione']) {
    testWidgets('actual LivePage: $action opens a usable dialog without prompt', (tester) async {
      final f = Fixture316(); f.ask(); final before = f.brain.encodeJson();
      await mountLive316(tester, f);
      expect(find.byIcon(Icons.thumb_up_alt_outlined), findsNothing);
      await tester.tap(find.byKey(ValueKey('curiosity-$action')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('relation-kind')), findsOneWidget);
      await tester.tap(find.text('Annulla')); await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(f.brain.encodeJson(), before);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('actual LivePage: Salta immediately closes question without learning', (tester) async {
    final f = Fixture316(); f.ask(); final before = f.brain.encodeJson();
    var calls = 0;
    await mountLive316(tester, f, onResult: (u, a) async { calls++; expect(u, 'Salta'); });
    await tester.tap(find.byKey(const ValueKey('curiosity-Salta'))); await tester.pumpAndSettle();
    expect(calls, 1); expect(f.world.pendingCuriosityKey316, isNull);
    expect(find.byKey(const ValueKey('curiosity-closed')), findsOneWidget);
    expect(f.brain.encodeJson(), before);
  });
  testWidgets('correction can reject association without deleting any facts', (tester) async {
    final f = Fixture316(); f.ask(); final before = f.brain.encodeJson();
    await mountLive316(tester, f);
    await tester.tap(find.byKey(const ValueKey('curiosity-Correggi'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Scarta associazione')); await tester.pumpAndSettle();
    expect(f.world.pendingCuriosityKey316, isNull); expect(f.brain.encodeJson(), before);
  });
  testWidgets('saving requires an explicit relation then learns exact endpoints', (tester) async {
    final f = Fixture316(); f.ask(); var persisted = 0;
    await mountLive316(tester, f, onResult: (_, __) async { persisted++; });
    await tester.tap(find.byKey(const ValueKey('curiosity-Rispondi'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Salva')); await tester.pumpAndSettle();
    expect(find.text('Scegli una relazione prima di salvare.'), findsOneWidget);
    expect(persisted, 0);
    await tester.tap(find.byKey(const ValueKey('relation-kind'))); await tester.pumpAndSettle();
    await tester.tap(find.text('È un tipo di').last); await tester.pumpAndSettle();
    await tester.tap(find.text('Salva')); await tester.pumpAndSettle();
    expect(persisted, 1);
    expect(f.brain.cognitiveFacts06().any((x) => x.subjectId == f.a && x.objectEntityId == f.b), isTrue);
    expect(f.world.pendingCuriosityKey316, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('variation dialog supports reversing relationship direction', (tester) async {
    final f = Fixture316(); f.ask(); await mountLive316(tester, f);
    await tester.tap(find.byKey(const ValueKey('curiosity-Aggiungi variazione'))); await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile)); await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('relation-subject'))).data, 'Organizzazione');
    await tester.tap(find.byKey(const ValueKey('relation-kind'))); await tester.pumpAndSettle();
    await tester.tap(find.text('È collegato a').last); await tester.pumpAndSettle();
    await tester.tap(find.text('Salva')); await tester.pumpAndSettle();
    expect(f.brain.cognitiveFacts06().any((x) => x.subjectId == f.b && x.objectEntityId == f.a), isTrue);
  });
  testWidgets('modal lock prevents duplicated dialogs on rapid taps', (tester) async {
    final f = Fixture316(); f.ask(); await mountLive316(tester, f);
    final finder = find.byKey(const ValueKey('curiosity-Correggi'));
    await tester.tap(finder); await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle(); expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Annulla')); await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing); expect(tester.takeException(), isNull);
  });
  testWidgets('busy state disables all question actions visibly', (tester) async {
    final f = Fixture316(); f.ask(); await mountLive316(tester, f, busy: true);
    final button = tester.widget<TextButton>(find.byKey(const ValueKey('curiosity-Salta')));
    expect(button.onPressed, isNull);
  });
  testWidgets('spontaneous statements do not display dead QA controls', (tester) async {
    final f = Fixture316();
    await mountLive316(tester, f, messages: [ChatMessage04(user: false, text: 'Osservo la memoria.')]);
    expect(find.text('Correggi'), findsNothing); expect(find.text('Aggiungi variazione'), findsNothing);
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsNothing);
  });
  testWidgets('ordinary response retains correction and variation callbacks', (tester) async {
    final f = Fixture316(); var correct = 0, variation = 0;
    await mountLive316(tester, f,
      messages: [ChatMessage04(user: false, text: 'Bene', prompt: 'Come stai?')],
      onCorrect: (_) async { correct++; }, onVariation: (_) async { variation++; });
    await tester.tap(find.text('Correggi')); await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi variazione')); await tester.pumpAndSettle();
    expect(correct, 1); expect(variation, 1);
  });
  testWidgets('failed persistence shows an error and releases busy lock', (tester) async {
    final f = Fixture316(); f.ask();
    await mountLive316(tester, f, onResult: (_, __) async { throw StateError('test save failure'); });
    await tester.tap(find.byKey(const ValueKey('curiosity-Salta'))); await tester.pumpAndSettle();
    expect(find.textContaining('salvataggio non completato'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('correction text controller survives closing animation', (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
      TextButton(onPressed: () async { result = await showTextDialog316(context, title: 'Correzione', hint: 'Risposta'); },
        child: const Text('Apri'))))));
    await tester.tap(find.text('Apri')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Risposta corretta');
    await tester.tap(find.text('Impara')); await tester.pumpAndSettle();
    expect(result, 'Risposta corretta'); expect(tester.takeException(), isNull);
  });
  test('root wiring restores question and handles controls before generic learning', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('final repairedQuestion316 = _world.repairPendingCuriosity316(_brain)'));
    expect(source, contains('curiosityKey316: _world.pendingCuriosityKey316'));
    final handler = source.substring(source.indexOf('  Future<void> _send() async {'));
    expect(handler.indexOf('questionAnswer316'), lessThan(handler.indexOf('final sensoryGrounding')));
    expect(handler.substring(0, handler.indexOf('final sensoryGrounding')), contains('return;'));
    expect(source, contains('onCuriosityResult316: _curiosityResult316'));
  });
}
