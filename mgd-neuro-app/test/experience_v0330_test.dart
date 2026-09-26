import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mgd_neuro_mobile/experience_memory_v0330.dart';
import 'package:mgd_neuro_mobile/experience_page_v0330.dart';
import 'package:mgd_neuro_mobile/knowledge_deletion_v0330.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';
import 'package:mgd_neuro_mobile/mgd_language_v020.dart';
import 'package:mgd_neuro_mobile/navigable_graph_v013.dart';
import 'package:mgd_neuro_mobile/relational_memory_v0324.dart';

Features33 cue33(int visual, int audio, {double noise = 0}) => {
  'vision:v1': {'a': visual == 0 ? 1 : noise, 'b': visual == 1 ? 1 : noise},
  'audio:v1': {'a': audio == 0 ? 1 : noise, 'b': audio == 1 ? 1 : noise},
};
Uint8List picture33(bool red) {
  final i = img.Image(width: 48, height: 48);
  img.fill(i, color: img.ColorRgb8(red ? 230 : 15, 20, red ? 15 : 230));
  return Uint8List.fromList(img.encodePng(i));
}

Uint8List tone33(double hz) {
  final bytes = Uint8List(32000), data = ByteData.sublistView(Uint8List(32000));
  for (var i = 0; i < 16000; i++) {
    data.setInt16(
      i * 2,
      (12000 * sin(2 * pi * hz * i / 16000)).round(),
      Endian.little,
    );
  }
  bytes.setAll(0, data.buffer.asUint8List());
  return bytes;
}

void main() {
  test('complementary ambiguous channels resolve a joint label without target leakage', () {
    final m = ExperienceMemory33();
    for (var v = 0; v < 2; v++) {
      for (var a = 0; a < 2; a++) {
        m.learn(cue33(v, a), label: 'classe $v$a');
      }
    }
    for (var v = 0; v < 2; v++) {
      for (var a = 0; a < 2; a++) {
        final x = cue33(v, a, noise: .035), p = m.predict(x);
        expect(p.exactRecall, false);
        expect(p.best, 'classe $v$a');
        expect(p.accepted, true);
        expect(m.predict({'vision:v1': x['vision:v1']!}).accepted, false);
        expect(m.predict({'audio:v1': x['audio:v1']!}).accepted, false);
        expect(p.channels.length, 2);
      }
    }
  });
  test(
    'joint episode binding retains XOR even when marginal labels are identical',
    () {
      final m = ExperienceMemory33();
      for (var v = 0; v < 2; v++) {
        for (var a = 0; a < 2; a++) {
          m.learn(cue33(v, a), label: v == a ? 'uguali' : 'diversi');
        }
      }
      expect(m.predict(cue33(0, 1, noise: .03)).best, 'diversi');
      expect(m.predict(cue33(1, 1, noise: .03)).best, 'uguali');
    },
  );
  test(
    'same signal with conflicting confirmations abstains; deletion resolves it',
    () {
      final m = ExperienceMemory33(), x = cue33(0, 0);
      m.learn(x, label: 'uno');
      final wrong = m.learn(x, label: 'due');
      expect(m.predict(x).accepted, false);
      m.deleteWhere((e) => e.id == wrong.id);
      expect(m.predict(x).best, 'uno');
      expect(m.predict(x).accepted, true);
    },
  );
  test('new class does not overwrite exact retained examples and contexts stay independent', () {
    final m = ExperienceMemory33(), old = <Features33>[];
    for (var i = 0; i < 32; i++) {
      final x = {
        'text:v1': {'word$i': 1.0},
      };
      old.add(x);
      m.learn(x, label: 'classe$i', context: 'nomi');
    }
    for (var i = 0; i < old.length; i++) {
      expect(m.predict(old[i], context: 'nomi').best, 'classe$i');
    }
    m.learn(old.first, label: 'altro', context: 'suoni');
    expect(m.predict(old.first, context: 'nomi').best, 'classe0');
    expect(m.predict(old.first, context: 'suoni').best, 'altro');
    expect(m.episodes.length, 33);
  });
  test('near matches do not merge distinct confirmed episodes', () {
    final m = ExperienceMemory33();
    m.learn(cue33(0, 0), label: 'rosso');
    m.learn(cue33(0, 0, noise: .01), label: 'blu');
    expect(m.episodes.length, 2);
    expect(m.predict(cue33(0, 0)).best, 'rosso');
    expect(m.predict(cue33(0, 0, noise: .01)).best, 'blu');
  });
  test('unpaired modalities are not invented as a joint experience', () {
    final m = ExperienceMemory33(), x = cue33(0, 0);
    m.learn({'vision:v1': x['vision:v1']!}, label: 'rosso');
    m.learn({'audio:v1': x['audio:v1']!}, label: 'rosso');
    final p = m.predict(x);
    expect(p.accepted, false);
    expect(p.channels.length, 2);
    expect(p.reason, contains('non sono ancora associati'));
  });
  test('novel signal with only one trained class is not declared certain', () {
    final m = ExperienceMemory33();
    m.learn(cue33(0, 0), label: 'rosso');
    expect(m.predict(cue33(1, 1)).accepted, false);
  });
  test('prequential metrics are measured before insertion, no automatic prediction training', () {
    final m = ExperienceMemory33();
    m.learn(cue33(0, 0), label: 'rosso');
    expect(m.coldStarts, 1);
    expect(m.evaluated, 0);
    for (var i = 0; i < 5; i++) {
      m.predict(cue33(1, 1));
    }
    expect(m.episodes.length, 1);
    expect(m.evaluated, 0);
    m.learn(cue33(1, 1), label: 'blu');
    expect(m.evaluated, 1);
    expect(m.correct, 0);
    expect(m.logLoss, greaterThan(20));
  });
  test(
    'restored model makes identical predictions and retains active metric',
    () {
      final m = ExperienceMemory33();
      for (var i = 0; i < 16; i++) {
        m.learn(
          cue33(i % 2, i % 2, noise: i * .006),
          label: i.isEven ? 'rosso' : 'blu',
        );
      }
      final restored = ExperienceMemory33.fromJson(
        jsonDecode(jsonEncode(m.toJson())),
      );
      expect(restored.toJson(), m.toJson());
      expect(
        restored.predict(cue33(0, 0, noise: .033)).probabilities,
        m.predict(cue33(0, 0, noise: .033)).probabilities,
      );
      expect(m.acceptedUpdates + m.rejectedUpdates, greaterThan(0));
    },
  );
  test('deletion has the same prediction as deterministic rebuilding without removed data', () {
    final m = ExperienceMemory33(), fresh = ExperienceMemory33();
    for (var i = 0; i < 18; i++) {
      final x = cue33(i % 2, (i ~/ 2) % 2, noise: i * .002),
          label = i % 3 == 0 ? 'elimina' : 'resta${i % 2}';
      m.learn(x, label: label);
      if (label != 'elimina') fresh.learn(x, label: label);
    }
    expect(m.deleteConcept('elimina'), 6);
    expect(m.toJson()['weights'], fresh.toJson()['weights']);
    for (var i = 0; i < 4; i++) {
      expect(
        m.predict(cue33(i % 2, i ~/ 2, noise: .025)).probabilities,
        fresh.predict(cue33(i % 2, i ~/ 2, noise: .025)).probabilities,
      );
    }
    expect(m.evaluated, 0);
    expect(m.evaluationReset, true);
  });
  test(
    'features are immutable, validated, and names are not feature values',
    () {
      final m = ExperienceMemory33(), x = cue33(0, 0);
      final e = m.learn(x, label: 'risposta segreta');
      x['vision:v1']!['a'] = 99;
      expect(e.features['vision:v1']!['a'], 1);
      expect(() => e.features['vision:v1']!['a'] = 2, throwsUnsupportedError);
      expect(jsonEncode(e.features), isNot(contains('risposta segreta')));
      expect(
        () => m.learn({
          'vision:v1': {'x': double.nan},
        }, label: 'bad'),
        throwsArgumentError,
      );
      expect(
        () => m.predict({
          'audio:v2': {'x': 1},
        }),
        throwsArgumentError,
      );
      expect(() => m.predict({}), throwsArgumentError);
    },
  );
  test('word order features preserve role differences', () {
    expect(
      ExperienceMemory33.textFeatures('Mario segue Luca'),
      isNot(equals(ExperienceMemory33.textFeatures('Luca segue Mario'))),
    );
  });
  test('capacity refuses input without erasing any previous episode', () {
    final m = ExperienceMemory33();
    for (var i = 0; i < ExperienceMemory33.capacity; i++) {
      m.learn(cue33(0, 0), label: 'unica', context: 'contesto $i');
    }
    expect(() => m.learn(cue33(1, 1), label: 'nuova'), throwsStateError);
    expect(m.episodes.length, ExperienceMemory33.capacity);
    expect(m.predict(cue33(0, 0), context: 'contesto 0').best, 'unica');
  });
  test('actual PNG and PCM encoders feed complementary modalities', () {
    final m = ExperienceMemory33();
    for (final red in [true, false]) {
      for (final hz in [330.0, 880.0]) {
        m.learn({
          'vision:v1': MgdWorld06.encodeVision33(picture33(red)),
          'audio:v1': MgdWorld06.encodeAudio33(tone33(hz)),
        }, label: '$red $hz');
      }
    }
    final p = m.predict({
      'vision:v1': MgdWorld06.encodeVision33(picture33(false)),
      'audio:v1': MgdWorld06.encodeAudio33(tone33(880)),
    });
    expect(p.best, 'false 880.0');
    expect(p.channels.length, 2);
  });
  test('world persistence and runtime merge preserve new experiences and energy setting', () {
    final w = MgdWorld06();
    w.experience33.learn(cue33(0, 0), label: 'rosso');
    final restored = MgdWorld06.fromJson(jsonDecode(jsonEncode(w.toJson())));
    expect(restored.experience33.episodes.length, 1);
    expect(restored.eventDriven33, true);
    final stale = w.toJson();
    w.experience33.learn(cue33(1, 1), label: 'blu');
    w.applyRuntime320(stale);
    expect(w.experience33.episodes.length, 2);
    expect(MgdWorld06.fromJson({'version': 1}).experience33.episodes, isEmpty);
  });
  test(
    'named sensory prototype is not moved by unconfirmed similar exposure',
    () {
      final w = MgdWorld06(), b = PlasticLanguageBrain04();
      final first = w.observeVisionBytes(picture33(true));
      w.bindLast(label: 'Rosso', entityId: b.ensureSemanticEntity06('Rosso'));
      final before = Map.of(first.prototype.centroid);
      w.observeVisionBytes(picture33(true));
      expect(first.prototype.centroid, before);
    },
  );
  test('node deletion removes semantic, lexical, episodic, source and sensor references', () async {
    final b = PlasticLanguageBrain04(),
        w = MgdWorld06(),
        r = ResearchMemory11(enabled: false),
        l = MgdLanguage20();
    b.importTeacherFact08(
      subject: 'Mario',
      relation: 'possiede',
      object: 'libro',
      confidence: .9,
      source: 'test',
    );
    b.importTeacherFact08(
      subject: 'Anna',
      relation: 'possiede',
      object: 'penna',
      confidence: .9,
      source: 'test',
    );
    l.ingestText('Mario possiede un libro. Anna possiede una penna.');
    RelationalMemory324.learn(r, 'Mario possiede il libro.');
    SourceMemory323.retain(
      r,
      const WebDocument11(
        provider: 'test',
        family: 'test',
        title: 'memoria',
        url: 'https://example.invalid/test',
        text: 'Mario possiede un libro. Anna possiede una penna.',
        trust: .9,
      ),
    );
    w.observeVisionBytes(picture33(true));
    w.bindLast(label: 'Mario', entityId: b.ensureSemanticEntity06('Mario'));
    w.experience33.learn(cue33(0, 0), label: 'Mario');
    await KnowledgeDeletion33.delete(
      brain: b,
      world: w,
      research: r,
      language: l,
      mode: 'mondo',
      node: 'Mario',
    );
    expect(
      b.semanticGraph().any((e) => e.from == 'Mario' || e.to == 'Mario'),
      false,
    );
    expect(b.entities.where((e) => e.label == 'Mario'), isEmpty);
    expect(b.semanticGraph().any((e) => e.from == 'Anna'), true);
    expect(l.tokenCount.containsKey('mario'), false);
    expect(w.experience33.episodes, isEmpty);
    expect(w.prototypes.where((p) => p.label == 'Mario'), isEmpty);
    expect(
      SourceMemory323.rows(r).any((e) => '${e['text']}'.contains('Mario')),
      false,
    );
    expect(
      RelationalMemory324.rows(r).any((e) => e['agent'] == 'mario'),
      false,
    );
    final restored = PlasticLanguageBrain04.fromJson(
      jsonDecode(jsonEncode(b.toJson())),
    );
    expect(restored.semanticGraph().any((e) => e.from == 'Mario'), false);
    expect(
      restored.ensureSemanticEntity06('Mario'),
      greaterThan(b.entities.length - 1),
    );
  });
  testWidgets(
    'experience page teaches, predicts and saves without putting label in input',
    (tester) async {
      final w = MgdWorld06();
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ExperiencePage33(
            world: w,
            onSave: () async {
              saves++;
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('experience-input')),
        'saluto breve',
      );
      await tester.enterText(
        find.byKey(const ValueKey('experience-label')),
        'ciao',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('experience-teach')),
      );
      await tester.tap(find.byKey(const ValueKey('experience-teach')));
      await tester.runAsync(() async {
        for (var n = 0; n < 100 && w.experience33.episodes.isEmpty; n++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(w.experience33.episodes.single.label, 'ciao');
      expect(saves, 1);
      expect(
        jsonEncode(w.experience33.episodes.single.features),
        isNot(contains('ciao')),
      );
    },
  );
  testWidgets(
    'new isolated experience category is searchable in the world map',
    (tester) async {
      final w = MgdWorld06();
      w.experience33.learn(cue33(0, 0), label: 'Ciao');
      await tester.pumpWidget(
        MaterialApp(
          home: SemanticMapPage14(
            brain: PlasticLanguageBrain04(),
            world: w,
            research: ResearchMemory11(enabled: false),
            language: MgdLanguage20(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ciao');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Focus: Ciao • 0 collegamenti'), findsOneWidget);
    },
  );
}
