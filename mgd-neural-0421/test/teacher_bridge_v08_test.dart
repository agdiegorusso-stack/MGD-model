import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:mgd_neuro_mobile/plastic_language_brain_v04.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';
import 'package:mgd_neuro_mobile/teacher_bridge_v08.dart';

void main() {
  test('teacher pack imports explicit facts as weak plastic priors', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'mgd-teacher-pack-v1',
          'teacher': {'model': 'test-llm', 'source': 'unit'},
          'facts': [
            {'s': 'cane', 'r': 'is_a', 'o': 'animale', 'confidence': 0.8},
            {'s': 'gatto', 'r': 'is_a', 'o': 'animale', 'confidence': 0.8},
          ],
          'links': [
            {
              'a': 'cane',
              'b': 'gatto',
              'similarity': 0.82,
              'confidence': 0.7
            },
          ],
        }),
      ),
    );

    final beforeEdges = world.stats().worldEdges;
    final result = importTeacherPack08(
      brain,
      world,
      TeacherPack08.fromBytes(bytes),
    );

    expect(result.model, 'test-llm');
    expect(result.facts, 2);
    expect(result.links, 1);
    expect(brain.entityIdForLabel06('cane'), isNotNull);
    expect(brain.entityIdForLabel06('gatto'), isNotNull);
    expect(brain.entityIdForLabel06('animale'), isNotNull);
    expect(
      brain.cognitiveFacts06().any(
        (f) => f.relation == 'è' && f.object.toLowerCase() == 'animale',
      ),
      isTrue,
    );
    expect(world.stats().worldEdges, greaterThan(beforeEdges));
  });

  test('async teacher import is equivalent and reports progress', () async {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final pack = TeacherPack08.fromJson({
      'format': 'mgd-teacher-pack-v1',
      'teacher': {'model': 'async-test', 'source': 'unit'},
      'facts': List.generate(96, (i) => {
        's': 'soggetto $i',
        'r': 'is_a',
        'o': 'classe ${i % 8}',
        'confidence': 0.8,
      }),
      'links': List.generate(32, (i) => {
        'a': 'soggetto $i',
        'b': 'soggetto ${i + 1}',
        'similarity': 0.7,
        'confidence': 0.7,
      }),
    });

    final progress = <int>[];
    final result = await importTeacherPackAsync08(
      brain,
      world,
      pack,
      maxItemsPerSlice: 8,
      onProgress: (completed, total, stage) {
        progress.add(completed);
      },
    );

    expect(result.facts, 96);
    expect(result.links, 32);
    expect(progress.length, greaterThan(3));
    expect(progress.last, 128);
    expect(brain.entityIdForLabel06('soggetto 95'), isNotNull);
  });

  test('teacher pack can decode asynchronously', () async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 'mgd-teacher-pack-v1',
      'teacher': {'model': 'decode-test'},
      'facts': [
        {'s': 'cellula', 'r': 'is_a', 'o': 'unità biologica'}
      ],
      'links': const [],
    })));
    final pack = await TeacherPack08.fromBytesAsync(bytes);
    expect(pack.model, 'decode-test');
    expect(pack.facts.single.subject, 'cellula');
  });

  test('teacher semantic link remains an ordinary plastic MGD edge', () {
    final brain = PlasticLanguageBrain04();
    final world = MgdWorld06();
    final a = brain.ensureSemanticEntity06('cane');
    final b = brain.ensureSemanticEntity06('lupo');

    world.importTeacherSemanticLink08(a, b, 0.9, confidence: 0.6);
    final afterOne = world.stats().meanSlow;
    world.importTeacherSemanticLink08(a, b, 0.9, confidence: 0.6);
    final afterTwo = world.stats().meanSlow;

    expect(afterOne, greaterThan(0));
    expect(afterTwo, greaterThanOrEqualTo(afterOne));
  });

  test('alternate teacher pack field names are accepted', () {
    final pack = TeacherPack08.fromJson({
      'format': 'mgd-teacher-pack-v1',
      'model': 'teacher-x',
      'facts': [
        {
          'subject': 'Roma',
          'predicate': 'is_a',
          'object': 'città',
          'score': 0.9,
        },
      ],
      'links': [
        {'left': 'Roma', 'right': 'Milano', 'score': 0.7},
      ],
    });

    expect(pack.model, 'teacher-x');
    expect(pack.facts.single.subject, 'Roma');
    expect(pack.links.single.b, 'Milano');
  });

  test('teacher is_a answers natural Italian yes-no query', () {
    final brain = PlasticLanguageBrain04();
    brain.importTeacherFact08(
      subject: 'cane',
      relation: 'is_a',
      object: 'mammifero',
      confidence: 0.92,
    );

    expect(brain.respond('il cane è un mammifero?').toLowerCase(), 'sì.');
  });

  test('teacher is_a remains multi-valued taxonomy', () {
    final brain = PlasticLanguageBrain04();
    brain.importTeacherFact08(
      subject: 'cane',
      relation: 'is_a',
      object: 'animale',
      confidence: 0.92,
    );
    brain.importTeacherFact08(
      subject: 'cane',
      relation: 'is_a',
      object: 'mammifero',
      confidence: 0.92,
    );

    expect(brain.respond('il cane è un animale?').toLowerCase(), 'sì.');
    expect(brain.respond('il cane è un mammifero?').toLowerCase(), 'sì.');
    final open = brain.respond('che cosa è il cane?').toLowerCase();
    expect(open, contains('animale'));
    expect(open, contains('mammifero'));
  });

  test('teacher ha answers natural Italian yes-no query', () {
    final brain = PlasticLanguageBrain04();
    brain.importTeacherFact08(
      subject: 'uccello',
      relation: 'ha',
      object: 'piume',
      confidence: 0.92,
    );

    expect(brain.respond("l'uccello ha piume?").toLowerCase(), 'sì.');
  });


  test('decodes MGD ZIP bundle and prefers ALL_IN_ONE', () async {
    const payload = {
      'format': 'mgd-teacher-pack-v1',
      'teacher': {'model': 'zip-test', 'source': 'unit'},
      'facts': [
        {
          'subject': 'cellula',
          'relation': 'contiene',
          'object': 'DNA',
          'confidence': 0.9
        }
      ],
      'links': []
    };

    final archive = Archive()
      ..addFile(ArchiveFile.string('manifest.json', '{"kind":"manifest"}'))
      ..addFile(
        ArchiveFile.string(
          'BIOLOGY_GIGAPACK_ALL_IN_ONE.mgd.json',
          jsonEncode(payload),
        ),
      );
    final zipped = ZipEncoder().encode(archive);
    final pack = await TeacherPack08.fromBytesAsync(Uint8List.fromList(zipped));

    expect(pack.model, 'zip-test');
    expect(pack.facts.length, 1);
    expect(pack.facts.single.subject, 'cellula');
    expect(pack.facts.single.object, 'DNA');
  });

}
