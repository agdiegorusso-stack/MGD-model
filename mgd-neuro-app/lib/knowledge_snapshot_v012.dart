import 'dart:convert';
import 'dart:typed_data';

import 'brain_admin_v012.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

class RestoredSnapshot12 {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final Map<String,dynamic>? languageModel;

  const RestoredSnapshot12({
    required this.brain,
    required this.world,
    required this.research,
    this.languageModel,
  });
}

class KnowledgeSnapshot12 {
  static Uint8List fullSnapshotBytes(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory11 research, {Map<String,dynamic>? languageModel}
  ) {
    final data = <String, dynamic>{
      'format': 'mgd-neuro-snapshot-v1',
      'version': 12,
      'language': 'it',
      if(languageModel!=null)'languageModel':languageModel,
      'exportedAt': DateTime.now().toIso8601String(),
      'brain': brain.toJson(),
      'world': world.toJson(),
      'research': research.toJson(),
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }

  static RestoredSnapshot12 restoreSnapshotBytes(Uint8List bytes) {
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map) throw const FormatException('Snapshot non valido.');
    final j = Map<String, dynamic>.from(raw);
    if ((j['format'] ?? '').toString() != 'mgd-neuro-snapshot-v1') {
      throw const FormatException('Formato snapshot MGD non riconosciuto.');
    }
    final brainRaw = j['brain'];
    final worldRaw = j['world'];
    final researchRaw = j['research'];
    if (brainRaw is! Map || worldRaw is! Map || researchRaw is! Map) {
      throw const FormatException('Snapshot incompleto.');
    }
    final languageRaw=j['languageModel']??j['language'];
    return RestoredSnapshot12(
      languageModel:languageRaw is Map?Map<String,dynamic>.from(languageRaw):null,
      brain: PlasticLanguageBrain04.fromJson(
        Map<String, dynamic>.from(brainRaw),
      ),
      world: MgdWorld06.fromJson(Map<String, dynamic>.from(worldRaw)),
      research: ResearchMemory11.fromJson(
        Map<String, dynamic>.from(researchRaw),
      ),
    );
  }

  static Uint8List knowledgePackBytes(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory11 research,
  ) {
    final facts = <Map<String, dynamic>>[];
    for (final f in brain.editableFacts12()) {
      facts.add({
        'subject': f.subject,
        'relation': f.relation,
        'object': f.object,
        'confidence': f.confidence.clamp(0.35, 0.99),
      });
    }

    final links = <Map<String, dynamic>>[];
    for (final edge in world.editableWorldEdges12(brain)) {
      if (!edge.a.startsWith('e:') || !edge.b.startsWith('e:')) continue;
      if (edge.aLabel.trim().isEmpty || edge.bLabel.trim().isEmpty) continue;
      final strength = edge.strength.clamp(0.0, 1.0).toDouble();
      if (strength < 0.16) continue;
      links.add({
        'a': edge.aLabel,
        'b': edge.bLabel,
        'similarity': strength,
        'confidence': (0.35 + 0.55 * strength).clamp(0.35, 0.90),
      });
    }

    final acceptedResearch = research.claims.values
        .where((c) => c.status == 'accettata' || c.status == 'corretta_utente')
        .length;
    final data = <String, dynamic>{
      'format': 'mgd-teacher-pack-v1',
      'teacher': {
        'model': 'MGD Neuro 0.12 — conoscenza esportata',
        'source': 'cervello MGD persistente',
        'language': 'it',
        'exportedAt': DateTime.now().toIso8601String(),
        'facts': facts.length,
        'links': links.length,
        'acceptedResearch': acceptedResearch,
        'note': 'Esportazione portabile della conoscenza semantica. Può essere reimportata con Importa knowledge pack.',
      },
      'facts': facts,
      'links': links,
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }
}
