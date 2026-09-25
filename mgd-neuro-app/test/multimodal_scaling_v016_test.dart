import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mgd_neuro_mobile/mgd_scaling_lab_v016.dart';
import 'package:mgd_neuro_mobile/multimodal_concept_v016.dart';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/web_knowledge_explorer_v11.dart';

void main() {
  test('one entity fuses language vision audio and researched evidence', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final research = ResearchMemory11();

    brain.importTeacherFact08(
      subject: 'cane',
      relation: 'tipo di',
      object: 'mammifero',
      confidence: 0.9,
      source: 'test',
    );
    final dog = brain.entityIdForLabel06('cane') ??
        brain.ensureSemanticEntity06('cane');

    final image = img.Image(width: 24, height: 24);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgba(x, y, 120 + x, 80 + y, 50, 255);
      }
    }
    world.observeVisionBytes(Uint8List.fromList(img.encodePng(image)));
    world.bindLast(label: 'cane', entityId: dog);

    const sampleRate = 16000;
    final pcm = ByteData(sampleRate * 2);
    for (var i = 0; i < sampleRate; i++) {
      final value = (sin(2 * pi * 440 * i / sampleRate) * 12000).round();
      pcm.setInt16(i * 2, value, Endian.little);
    }
    world.observeAudioPcm(pcm.buffer.asUint8List(), sampleRate: sampleRate);
    world.bindLast(label: 'cane', entityId: dog);

    research.claims['cane|produce|suono'] = ResearchClaim11(
      key: 'cane|produce|suono',
      subject: 'cane',
      relation: 'produce',
      object: 'suono',
      confidence: 0.55,
      conflict: false,
      status: 'dubbia',
      lastSeenIso: DateTime.now().toIso8601String(),
      evidenceIds: {'e1', 'e2'},
      sourceFamilies: {'a', 'b'},
    );

    final index = MultimodalConceptIndex16(
      brain: brain,
      world: world,
      research: research,
    );
    final concept = index.build(dog);

    expect(concept.vision.present, isTrue);
    expect(concept.audio.present, isTrue);
    expect(concept.facts, isNotEmpty);
    expect(concept.webEvidence, 2);
    expect(concept.modalityCount, 4);
    expect(concept.fusedSignature, isNotEmpty);
    expect(concept.maturity, greaterThan(0.2));
  });

  test('synthetic sparse benchmark scales without mutating live model', () {
    final result = runMgdScalingBenchmark16({
      'sizes': <int>[1000, 10000],
      'cycles': 4,
      'maxActive': 128,
    });
    final rows = result['rows'] as List;
    expect(rows.length, 2);
    expect((rows.last as Map)['edges'], 10000);
    expect(((rows.last as Map)['visitedEdges'] as int), greaterThan(0));
    expect(((rows.last as Map)['memoryMb'] as num), greaterThan(0));
  });
}
