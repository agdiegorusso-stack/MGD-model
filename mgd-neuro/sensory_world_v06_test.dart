import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';

Uint8List solidPng(int r, int g, int b) {
  final image = img.Image(width: 32, height: 32);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List tone(double hz, {int sampleRate = 16000, double seconds = 1.0}) {
  final n = (sampleRate * seconds).round();
  final out = Uint8List(n * 2);
  final bd = ByteData.sublistView(out);
  for (var i = 0; i < n; i++) {
    final v = (sin(2 * pi * hz * i / sampleRate) * 0.45 * 32767).round();
    bd.setInt16(i * 2, v, Endian.little);
  }
  return out;
}

void main() {
  test('vision creates and reuses MGD sensory attractors', () {
    final world = MgdWorld06();
    final first = world.observeVisionBytes(solidPng(240, 30, 30));
    final repeat = world.observeVisionBytes(solidPng(240, 30, 30));
    final different = world.observeVisionBytes(solidPng(25, 40, 240));

    expect(first.created, isTrue);
    expect(repeat.created, isFalse);
    expect(repeat.prototype.id, first.prototype.id);
    expect(different.prototype.id, isNot(first.prototype.id));
    expect(world.stats().visualPatterns, greaterThanOrEqualTo(2));
  });

  test('audio similarity is learned from signal features without transcription', () {
    final world = MgdWorld06();
    final a = world.observeAudioPcm(tone(220));
    final b = world.observeAudioPcm(tone(220));
    final c = world.observeAudioPcm(tone(1000));

    expect(a.created, isTrue);
    expect(b.created, isFalse);
    expect(b.prototype.id, a.prototype.id);
    expect(c.prototype.id, isNot(a.prototype.id));
    expect(world.stats().auditoryPatterns, greaterThanOrEqualTo(2));
  });

  test('crossmodal experience creates MGD world links and semantic binding', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();

    world.observeVisionBytes(solidPng(230, 25, 25));
    world.observeAudioPcm(tone(440));
    expect(world.stats().worldEdges, greaterThan(0));

    final entity = brain.ensureSemanticEntity06('mela');
    world.bindLast(label: 'mela', entityId: entity);
    expect(world.stats().semanticBindings, 1);

    final trace = world.think(brain, cycles: 12, seedText: 'mela');
    expect(trace, isNotEmpty);
    expect(world.stats().thoughtCycles, 12);
  });

  test('world state survives JSON round trip', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final e = brain.ensureSemanticEntity06('campanello');
    world.observeAudioPcm(tone(750));
    world.bindLast(label: 'campanello', entityId: e);
    world.think(brain, cycles: 8, seedText: 'campanello');

    final restored = MgdWorld06.fromJson(world.toJson());
    expect(restored.stats().auditoryPatterns, world.stats().auditoryPatterns);
    expect(restored.stats().semanticBindings, world.stats().semanticBindings);
    expect(restored.stats().thoughtCycles, world.stats().thoughtCycles);
  });
}
