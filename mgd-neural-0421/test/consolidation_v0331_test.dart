import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/consolidation_settings_v0331.dart';
import '../lib/consolidation_provenance_v0331.dart';
import '../lib/knowledge_deletion_v0330.dart';
import '../lib/memory_runtime_v0319.dart';
import '../lib/mgd_language_v020.dart';
import '../lib/plastic_language_brain_v04.dart';
import '../lib/relational_memory_v0324.dart';
import '../lib/sensory_world_v06.dart';
import '../lib/web_knowledge_explorer_v11.dart';
import 'support/consolidation_checks_v0331.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'pure dynamics, response revocation, migration and provenance regressions',
      () {
    expect(runConsolidationChecks331()['passed'], 25);
  });

  test(
      'runtime worker preserves evidence, revokes corrections and cannot resurrect deletion',
      () async {
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    b.teachResponse('Dove vive Ada?', 'Roma');
    b.ensureSemanticEntity06('Roma');
    w.setConsolidationEnabled331(true);
    final before = jsonEncode(b.slots.values.map((s) => s.toJson()).toList());
    for (var i = 0; i < 20; i++) {
      MemoryRuntime319.pulse(b, w, cycles: 0);
    }
    expect(w.consolidationBasinCount331, greaterThan(0));
    expect(jsonEncode(b.slots.values.map((s) => s.toJson()).toList()), before);
    final stale = await MemoryRuntime319.compute320(b, w);
    b.reinforcePair('Dove vive Ada?', 'Roma', false);
    expect(MemoryRuntime319.pulse(b, w, cycles: 0), 0);
    w.applyRuntime320(stale.world);
    expect(w.consolidationBasinCount331, 0);
    expect(w.consolidationRevokedCount331, greaterThan(0));
    final restored = MgdWorld06.fromJson(jsonDecode(jsonEncode(w.toJson())));
    expect(MemoryRuntime319.pulse(b, restored, cycles: 0), 0);
    restored.sleepReplay();
    expect(restored.edges.values.every((e) => e.cost > 1), true);
    final deletedWorker = await MemoryRuntime319.compute320(b, restored);
    await KnowledgeDeletion33.delete(
        brain: b,
        world: restored,
        research: ResearchMemory11(),
        language: MgdLanguage20(),
        mode: 'mondo',
        node: 'Ada');
    restored.applyRuntime320(deletedWorker.world);
    expect(restored.edges, isEmpty);
    expect(MemoryRuntime319.pulse(b, restored, cycles: 0), 0);
    expect(restored.edges, isEmpty);
  });

  test(
      'correction while optional dynamics is off survives enable and old sources',
      () {
    final b = PlasticLanguageBrain04(), w = MgdWorld06();
    b.importTeacherFact08(
        subject: 'Ada',
        relation: 'vive a',
        object: 'Roma',
        confidence: .85,
        source: 'fonte-A');
    final a = b.ensureSemanticEntity06('Ada'),
        z = b.ensureSemanticEntity06('Roma');
    w.importTeacherSemanticLink08(a, z, .8);
    ConsolidationEvidence331.sync(b, w);
    w.integrateLanguageExperience09(b, 'Ada Roma', reward: -.65);
    expect(w.consolidationRevokedCount331, 1);
    w.setConsolidationEnabled331(true);
    for (var i = 0; i < 20; i++) {
      MemoryRuntime319.pulse(b, w, cycles: 0);
    }
    expect(w.consolidationBasinCount331, 0);
    expect(w.consolidationRevokedCount331, 1);
  });

  test(
      'final guard applies to relational output after restart without rewriting evidence',
      () {
    var b = PlasticLanguageBrain04();
    final memory = ResearchMemory11();
    RelationalMemory324.learn(memory, 'Mario possiede un libro.');
    const prompt = 'Che cosa possiede Mario?';
    final answer = RelationalMemory324.answerIfKnown(memory, prompt);
    expect(answer, isNotNull);
    Map<String, dynamic> evidenceSnapshot() {
      final copy = jsonDecode(jsonEncode(memory.toJson())) as Map<String, dynamic>;
      // Query latency is diagnostic telemetry, not learned evidence.
      (copy['state317']['relationalMemory324']['lastQuery'] as Map)
          .remove('micros');
      return copy;
    }
    final before = evidenceSnapshot();
    b.reinforcePair(prompt, answer!, false);
    b = PlasticLanguageBrain04.fromJson(jsonDecode(jsonEncode(b.toJson())));
    expect(
        b.guardResponse331(
            prompt, RelationalMemory324.answerIfKnown(memory, prompt)!),
        isNot(answer));
    expect(evidenceSnapshot(), before);
    b.reinforcePair(prompt, answer, true);
    expect(b.guardResponse331(prompt, answer), answer);
  });

  testWidgets(
      'world control is opt-in, explains scope and shows separate metric',
      (tester) async {
    final w = MgdWorld06();
    var busy = false;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return ConsolidationSettings331(
          world: w,
          busy: busy,
          onChanged: (v) => setState(() => w.setConsolidationEnabled331(v)));
    }))));
    expect(find.text('Consolida connessioni confermate'), findsOneWidget);
    expect(find.textContaining('La persistenza non verifica i fatti'),
        findsOneWidget);
    expect(w.consolidationEnabled331, false);
    await tester.tap(find.byKey(const ValueKey('consolidation-toggle-0331')));
    await tester.pump();
    expect(w.consolidationEnabled331, true);
    expect(find.byKey(const ValueKey('consolidation-metric-0331')),
        findsOneWidget);
    rebuild(() => busy = true);
    await tester.pump();
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const ValueKey('consolidation-toggle-0331')))
            .onChanged,
        isNull);
  });
}
