import 'dart:convert';
import 'dart:typed_data';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';

class TeacherFact08 {
  final String subject;
  final String relation;
  final String object;
  final double confidence;

  const TeacherFact08({
    required this.subject,
    required this.relation,
    required this.object,
    required this.confidence,
  });

  factory TeacherFact08.fromJson(Map<String, dynamic> j) => TeacherFact08(
        subject: (j['subject'] ?? j['s'] ?? '').toString().trim(),
        relation: (j['relation'] ?? j['predicate'] ?? j['r'] ?? '')
            .toString()
            .trim(),
        object: (j['object'] ?? j['o'] ?? '').toString().trim(),
        confidence: ((j['confidence'] ?? j['score'] ?? 0.65) as num)
            .toDouble()
            .clamp(0.0, 1.0),
      );
}

class TeacherLink08 {
  final String a;
  final String b;
  final double similarity;
  final double confidence;

  const TeacherLink08({
    required this.a,
    required this.b,
    required this.similarity,
    required this.confidence,
  });

  factory TeacherLink08.fromJson(Map<String, dynamic> j) => TeacherLink08(
        a: (j['a'] ?? j['left'] ?? '').toString().trim(),
        b: (j['b'] ?? j['right'] ?? '').toString().trim(),
        similarity: ((j['similarity'] ?? j['score'] ?? 0) as num)
            .toDouble()
            .clamp(0.0, 1.0),
        confidence: ((j['confidence'] ?? 0.65) as num)
            .toDouble()
            .clamp(0.0, 1.0),
      );
}

class TeacherPack08 {
  final String model;
  final String source;
  final List<TeacherFact08> facts;
  final List<TeacherLink08> links;

  const TeacherPack08({
    required this.model,
    required this.source,
    required this.facts,
    required this.links,
  });

  factory TeacherPack08.fromBytes(Uint8List bytes) =>
      TeacherPack08.fromJson(jsonDecode(utf8.decode(bytes)));

  factory TeacherPack08.fromJson(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException(
        'Il knowledge pack deve essere un oggetto JSON.',
      );
    }
    final j = Map<String, dynamic>.from(raw);
    final format = (j['format'] ?? '').toString();
    if (format.isNotEmpty && !format.startsWith('mgd-teacher-pack')) {
      throw FormatException('Formato teacher pack non supportato: ' + format);
    }

    final teacher = j['teacher'] is Map
        ? Map<String, dynamic>.from(j['teacher'] as Map)
        : <String, dynamic>{};

    final facts = <TeacherFact08>[];
    for (final x in (j['facts'] as List?) ?? const []) {
      if (x is! Map) continue;
      final f = TeacherFact08.fromJson(Map<String, dynamic>.from(x));
      if (f.subject.isNotEmpty &&
          f.relation.isNotEmpty &&
          f.object.isNotEmpty) {
        facts.add(f);
      }
    }

    final links = <TeacherLink08>[];
    for (final x in (j['links'] as List?) ?? const []) {
      if (x is! Map) continue;
      final l = TeacherLink08.fromJson(Map<String, dynamic>.from(x));
      if (l.a.isNotEmpty &&
          l.b.isNotEmpty &&
          l.a != l.b &&
          l.similarity > 0) {
        links.add(l);
      }
    }

    return TeacherPack08(
      model: (teacher['model'] ?? j['model'] ?? 'unknown').toString(),
      source:
          (teacher['source'] ?? j['source'] ?? 'distilled-llm').toString(),
      facts: facts,
      links: links,
    );
  }
}

class TeacherImportResult08 {
  final String model;
  final int facts;
  final int links;
  final int entities;

  const TeacherImportResult08({
    required this.model,
    required this.facts,
    required this.links,
    required this.entities,
  });
}

TeacherImportResult08 importTeacherPack08(
  PlasticLanguageBrain04 brain,
  MgdWorld06 world,
  TeacherPack08 pack,
) {
  final before = brain.stats().entities;
  var importedFacts = 0;
  var importedLinks = 0;

  for (final f in pack.facts) {
    brain.importTeacherFact08(
      subject: f.subject,
      relation: f.relation,
      object: f.object,
      confidence: f.confidence,
      source: pack.model + ':' + pack.source,
    );
    importedFacts++;
  }

  for (final l in pack.links) {
    final a =
        brain.entityIdForLabel06(l.a) ?? brain.ensureSemanticEntity06(l.a);
    final b =
        brain.entityIdForLabel06(l.b) ?? brain.ensureSemanticEntity06(l.b);
    world.importTeacherSemanticLink08(
      a,
      b,
      l.similarity,
      confidence: l.confidence,
    );
    importedLinks++;
  }

  brain.discoverConcepts();
  world.think(brain, cycles: 36, seedText: pack.model);

  return TeacherImportResult08(
    model: pack.model,
    facts: importedFacts,
    links: importedLinks,
    entities: brain.stats().entities - before,
  );
}
