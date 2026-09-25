import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';

bool _hasPrefix08(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

Uint8List _stripUtf8Bom08(Uint8List bytes) {
  if (_hasPrefix08(bytes, const [0xEF, 0xBB, 0xBF])) {
    return Uint8List.sublistView(bytes, 3);
  }
  return bytes;
}

Map<String, dynamic> _decodeTeacherJsonMap08(
  Uint8List bytes, {
  String sourceName = 'knowledge pack',
}) {
  try {
    final text = utf8.decode(_stripUtf8Bom08(bytes));
    final raw = jsonDecode(text);
    if (raw is! Map) {
      throw FormatException(
        '$sourceName: il knowledge pack deve essere un oggetto JSON.',
      );
    }
    return Map<String, dynamic>.from(raw);
  } on FormatException catch (e) {
    throw FormatException('$sourceName: ${e.message}');
  }
}

Map<String, dynamic> _decodeTeacherZip08(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final jsonFiles = archive
      .where((f) {
        if (!f.isFile) return false;
        final name = f.name.toLowerCase();
        return name.endsWith('.mgd.json') ||
            (name.endsWith('.json') && !name.endsWith('manifest.json'));
      })
      .toList();

  if (jsonFiles.isEmpty) {
    throw const FormatException(
      'Archivio ZIP valido, ma non contiene alcun file .mgd.json.',
    );
  }

  // Prefer the canonical all-in-one pack when present. This is exactly the
  // layout used by MGD_Biology_GigaPack_v2.zip.
  jsonFiles.sort((a, b) {
    int score(String name) {
      final n = name.toLowerCase();
      if (n.contains('all_in_one') || n.contains('all-in-one')) return 3;
      if (n.endsWith('.mgd.json')) return 2;
      return 1;
    }

    final byScore = score(b.name).compareTo(score(a.name));
    if (byScore != 0) return byScore;
    return b.size.compareTo(a.size);
  });

  final best = jsonFiles.first;
  return _decodeTeacherJsonMap08(
    best.content,
    sourceName: 'ZIP/${best.name}',
  );
}

Map<String, dynamic> _decodeTeacherPackJson08(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const FormatException('Knowledge pack vuoto.');
  }

  // ZIP local-file signature: 50 4B 03 04.
  if (_hasPrefix08(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
    return _decodeTeacherZip08(bytes);
  }

  // GZIP: 1F 8B.
  if (_hasPrefix08(bytes, const [0x1F, 0x8B])) {
    final decoded = GZipDecoder().decodeBytes(bytes, verify: true);
    return _decodeTeacherJsonMap08(
      decoded,
      sourceName: 'knowledge pack GZIP',
    );
  }

  return _decodeTeacherJsonMap08(bytes);
}

typedef TeacherImportProgress08 = void Function(
  int completed,
  int total,
  String stage,
);

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

  static Future<TeacherPack08> fromBytesAsync(Uint8List bytes) async {
    final decoded = await compute(_decodeTeacherPackJson08, bytes);
    return TeacherPack08.fromJson(decoded);
  }

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
    final a = brain.ensureSemanticEntity06(f.subject);
    final b = brain.ensureSemanticEntity06(f.object);
    if (a != b) {
      world.importTeacherSemanticLink08(
        a,
        b,
        0.42 + 0.28 * f.confidence,
        confidence: 0.45 + 0.25 * f.confidence,
      );
    }
    importedFacts++;
  }

  for (final l in pack.links) {
    final a = brain.ensureSemanticEntity06(l.a);
    final b = brain.ensureSemanticEntity06(l.b);
    world.importTeacherSemanticLink08(
      a,
      b,
      l.similarity,
      confidence: l.confidence,
    );
    importedLinks++;
  }

  // Deliberately do not run global concept discovery or a 36-cycle thought
  // burst here. Both are optional consolidation steps, not prerequisites for
  // making imported facts queryable, and doing them inline makes large packs
  // monopolize Flutter's UI isolate.
  return TeacherImportResult08(
    model: pack.model,
    facts: importedFacts,
    links: importedLinks,
    entities: brain.stats().entities - before,
  );
}

Future<TeacherImportResult08> importTeacherPackAsync08(
  PlasticLanguageBrain04 brain,
  MgdWorld06 world,
  TeacherPack08 pack, {
  int maxItemsPerSlice = 24,
  Duration maxSlice = const Duration(milliseconds: 10),
  TeacherImportProgress08? onProgress,
}) async {
  if (maxItemsPerSlice < 1) {
    throw ArgumentError.value(maxItemsPerSlice, 'maxItemsPerSlice');
  }

  final before = brain.stats().entities;
  final total = pack.facts.length + pack.links.length;
  var importedFacts = 0;
  var importedLinks = 0;
  var itemsInSlice = 0;
  var sliceClock = Stopwatch()..start();

  Future<void> yieldIfNeeded(String stage, {bool force = false}) async {
    final completed = importedFacts + importedLinks;
    final due = force ||
        itemsInSlice >= maxItemsPerSlice ||
        sliceClock.elapsed >= maxSlice;
    if (!due) return;
    onProgress?.call(completed, total, stage);
    // Duration.zero posts the continuation back to the event queue, allowing
    // Flutter to paint and Android to service input between mutation batches.
    await Future<void>.delayed(Duration.zero);
    itemsInSlice = 0;
    sliceClock = Stopwatch()..start();
  }

  onProgress?.call(0, total, 'Preparazione');
  await Future<void>.delayed(Duration.zero);

  for (final f in pack.facts) {
    brain.importTeacherFact08(
      subject: f.subject,
      relation: f.relation,
      object: f.object,
      confidence: f.confidence,
      source: pack.model + ':' + pack.source,
    );
    final a = brain.ensureSemanticEntity06(f.subject);
    final b = brain.ensureSemanticEntity06(f.object);
    if (a != b) {
      world.importTeacherSemanticLink08(
        a,
        b,
        0.42 + 0.28 * f.confidence,
        confidence: 0.45 + 0.25 * f.confidence,
      );
    }
    importedFacts++;
    itemsInSlice++;
    await yieldIfNeeded('Fatti');
  }

  await yieldIfNeeded('Legami', force: true);

  for (final l in pack.links) {
    final a = brain.ensureSemanticEntity06(l.a);
    final b = brain.ensureSemanticEntity06(l.b);
    world.importTeacherSemanticLink08(
      a,
      b,
      l.similarity,
      confidence: l.confidence,
    );
    importedLinks++;
    itemsInSlice++;
    await yieldIfNeeded('Legami');
  }

  await yieldIfNeeded('Completato', force: true);

  return TeacherImportResult08(
    model: pack.model,
    facts: importedFacts,
    links: importedLinks,
    entities: brain.stats().entities - before,
  );
}
