import 'dart:math';

import 'native_mgd_engine_v09.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

String normalizeAdmin12(String value) => PlasticLanguageBrain04.normalizeText(value);

class EditableFact12 {
  final int subjectId;
  final int relationId;
  final String subject;
  final String relation;
  final String object;
  final double confidence;

  const EditableFact12({
    required this.subjectId,
    required this.relationId,
    required this.subject,
    required this.relation,
    required this.object,
    required this.confidence,
  });
}

class EditableWorldEdge12 {
  final String key;
  final String a;
  final String b;
  final String aLabel;
  final String bLabel;
  final double strength;
  final double cost;
  final double memory;
  final double material;
  final double curvature;
  final bool active;

  const EditableWorldEdge12({
    required this.key,
    required this.a,
    required this.b,
    required this.aLabel,
    required this.bLabel,
    required this.strength,
    required this.cost,
    required this.memory,
    required this.material,
    required this.curvature,
    required this.active,
  });
}

extension PlasticLanguageBrainAdmin12 on PlasticLanguageBrain04 {
  List<EditableFact12> editableFacts12() {
    final out = <EditableFact12>[];
    for (final f in cognitiveFacts06()) {
      if (f.subjectId < 0 || f.subjectId >= entities.length) continue;
      out.add(EditableFact12(
        subjectId: f.subjectId,
        relationId: f.relationId,
        subject: entities[f.subjectId].label,
        relation: f.relation,
        object: f.object,
        confidence: f.confidence,
      ));
    }
    out.sort((a, b) {
      final s = a.subject.toLowerCase().compareTo(b.subject.toLowerCase());
      if (s != 0) return s;
      final r = a.relation.toLowerCase().compareTo(b.relation.toLowerCase());
      if (r != 0) return r;
      return a.object.toLowerCase().compareTo(b.object.toLowerCase());
    });
    return out;
  }

  bool deleteFact12({
    required int subjectId,
    required int relationId,
    required String object,
    bool deleteSourceEpisodes = false,
  }) {
    final objectKey = PlasticLanguageBrain04.canonicalObject(object);
    RelationSlot04? target;
    String? targetKey;
    for (final entry in slots.entries) {
      final slot = entry.value;
      if (slot.subjectId != subjectId) continue;
      if (slot.relationId != relationId) continue;
      if (!slot.candidates.containsKey(objectKey)) continue;
      target = slot;
      targetKey = entry.key;
      break;
    }
    if (target == null || targetKey == null) return false;
    final candidate = target.candidates.remove(objectKey);
    if (candidate == null) return false;
    if (deleteSourceEpisodes && candidate.sourceEpisodes.isNotEmpty) {
      final ids = Set<int>.from(candidate.sourceEpisodes);
      episodes.removeWhere((e) => ids.contains(e.id));
    }
    if (target.candidates.isEmpty) slots.remove(targetKey);
    discoverConcepts();
    return true;
  }

  bool deleteFactByLabels12(
    String subject,
    String relation,
    String object, {
    bool deleteSourceEpisodes = false,
  }) {
    final ns = normalizeAdmin12(subject);
    final nr = normalizeAdmin12(relation);
    final no = PlasticLanguageBrain04.canonicalObject(object);
    for (final f in editableFacts12()) {
      if (normalizeAdmin12(f.subject) == ns &&
          normalizeAdmin12(f.relation) == nr &&
          PlasticLanguageBrain04.canonicalObject(f.object) == no) {
        return deleteFact12(
          subjectId: f.subjectId,
          relationId: f.relationId,
          object: f.object,
          deleteSourceEpisodes: deleteSourceEpisodes,
        );
      }
    }
    return false;
  }

  void upsertManualFact12({
    required String subject,
    required String relation,
    required String object,
    double confidence = 0.96,
  }) {
    final s = subject.trim();
    final r = relation.trim();
    final o = object.trim();
    if (s.isEmpty || r.isEmpty || o.isEmpty) return;
    importTeacherFact08(
      subject: s,
      relation: r,
      object: o,
      confidence: confidence.clamp(0.35, 1.0).toDouble(),
      source: 'utente-editor',
    );

    final ns = normalizeAdmin12(s);
    final nr = normalizeAdmin12(r);
    final no = PlasticLanguageBrain04.canonicalObject(o);
    for (final f in editableFacts12()) {
      if (normalizeAdmin12(f.subject) != ns ||
          normalizeAdmin12(f.relation) != nr ||
          PlasticLanguageBrain04.canonicalObject(f.object) != no) {
        continue;
      }
      for (final slot in slots.values) {
        if (slot.subjectId != f.subjectId || slot.relationId != f.relationId) {
          continue;
        }
        final c = slot.candidates[no];
        if (c != null) {
          c.display = o;
          c.confidence = confidence.clamp(0.35, 1.0).toDouble();
          c.supports = max(c.supports, 2);
          c.lastStep = step;
        }
      }
    }
    discoverConcepts();
  }

  void replaceFact12(
    EditableFact12 oldFact, {
    required String subject,
    required String relation,
    required String object,
    double confidence = 0.96,
  }) {
    deleteFact12(
      subjectId: oldFact.subjectId,
      relationId: oldFact.relationId,
      object: oldFact.object,
      deleteSourceEpisodes: true,
    );
    upsertManualFact12(
      subject: subject,
      relation: relation,
      object: object,
      confidence: confidence,
    );
  }

  bool renameEntity12(int entityId, String newLabel) {
    final label = newLabel.trim();
    if (label.isEmpty || entityId < 0 || entityId >= entities.length) {
      return false;
    }
    final entity = entities[entityId];
    final old = entity.label.trim();
    if (old.isNotEmpty) entity.aliases.add(normalizeAdmin12(old));
    entity.aliases.add(normalizeAdmin12(label));
    entity.label = label;
    return true;
  }

  int removeFactsForEntity12(int entityId) {
    var removed = 0;
    final removeSlots = <String>[];
    for (final entry in slots.entries) {
      if (entry.value.subjectId == entityId) {
        removed += entry.value.candidates.length;
        removeSlots.add(entry.key);
      }
    }
    for (final key in removeSlots) {
      slots.remove(key);
    }

    final label = entityId >= 0 && entityId < entities.length
        ? normalizeAdmin12(entities[entityId].label)
        : '';
    if (label.isNotEmpty) {
      for (final entry in slots.entries.toList()) {
        final slot = entry.value;
        final keys = slot.candidates.entries
            .where((e) => normalizeAdmin12(e.value.display) == label)
            .map((e) => e.key)
            .toList();
        for (final key in keys) {
          slot.candidates.remove(key);
          removed++;
        }
        if (slot.candidates.isEmpty) slots.remove(entry.key);
      }
    }
    discoverConcepts();
    return removed;
  }
}

extension MgdWorldAdmin12 on MgdWorld06 {
  String nodeLabel12(PlasticLanguageBrain04 brain, String node) {
    if (node.startsWith('e:')) {
      final id = int.tryParse(node.substring(2));
      if (id != null && id >= 0 && id < brain.entities.length) {
        return brain.entities[id].label;
      }
      return 'Entità $node';
    }
    if (node.startsWith('p:')) {
      final id = int.tryParse(node.substring(2));
      SensoryPrototype06? p;
      if (id != null) {
        for (final x in prototypes) {
          if (x.id == id) {
            p = x;
            break;
          }
        }
      }
      if (p != null) {
        return p.label?.trim().isNotEmpty == true
            ? '${p.label} (${p.modality} #${p.id})'
            : '${p.modality} #${p.id}';
      }
      return 'Pattern $node';
    }
    return node;
  }

  List<EditableWorldEdge12> editableWorldEdges12(
    PlasticLanguageBrain04 brain,
  ) {
    final out = <EditableWorldEdge12>[];
    for (final entry in edges.entries) {
      final e = entry.value;
      out.add(EditableWorldEdge12(
        key: entry.key,
        a: e.a,
        b: e.b,
        aLabel: nodeLabel12(brain, e.a),
        bLabel: nodeLabel12(brain, e.b),
        strength: MgdMath09.strength(
          weight: e.cost,
          memory: e.fast,
          material: e.slow,
        ),
        cost: e.cost,
        memory: e.fast,
        material: e.slow,
        curvature: e.curvature,
        active: e.cost <= MgdMath09.defaults.epsilon,
      ));
    }
    out.sort((a, b) => b.strength.compareTo(a.strength));
    return out;
  }

  bool deleteWorldEdge12(String key) => edges.remove(key) != null;

  void setEntityWorldEdge12(
    PlasticLanguageBrain04 brain, {
    required String entityA,
    required String entityB,
    required double strength,
  }) {
    final aLabel = entityA.trim();
    final bLabel = entityB.trim();
    if (aLabel.isEmpty || bLabel.isEmpty) return;
    final aId = brain.entityIdForLabel06(aLabel) ??
        brain.ensureSemanticEntity06(aLabel);
    final bId = brain.entityIdForLabel06(bLabel) ??
        brain.ensureSemanticEntity06(bLabel);
    if (aId == bId) return;
    final a = 'e:$aId';
    final b = 'e:$bId';
    final key = a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';
    final s = strength.clamp(0.0, 1.0).toDouble();
    final minCost = MgdMath09.defaults.c0;
    final maxCost = MgdMath09.defaults.epsilon + 0.55;
    final edge = edges.putIfAbsent(key, () => WorldEdge06(a: a, b: b));
    edge.cost = minCost + (1.0 - s) * (maxCost - minCost);
    edge.fast = max(edge.fast, 0.15 + 0.75 * s);
    edge.slow = max(edge.slow, 0.08 + 0.68 * s);
    edge.meta = max(edge.meta, 0.10 + 0.70 * s);
    edge.elig = max(edge.elig, 0.25 + 0.65 * s);
    edge.uses = max(edge.uses, 1);
    edge.lastUsed = step;
  }

  bool unlinkPrototype12(int prototypeId) {
    SensoryPrototype06? target;
    for (final p in prototypes) {
      if (p.id == prototypeId) {
        target = p;
        break;
      }
    }
    if (target == null) return false;
    target.semanticEntityId = null;
    target.label = null;
    final node = 'p:$prototypeId';
    edges.removeWhere((_, e) => e.a == node || e.b == node);
    return true;
  }

  bool rebindPrototype12(
    PlasticLanguageBrain04 brain,
    int prototypeId,
    String entityLabel,
  ) {
    SensoryPrototype06? target;
    for (final p in prototypes) {
      if (p.id == prototypeId) {
        target = p;
        break;
      }
    }
    if (target == null || entityLabel.trim().isEmpty) return false;
    final id = brain.entityIdForLabel06(entityLabel) ??
        brain.ensureSemanticEntity06(entityLabel.trim());
    final node = 'p:$prototypeId';
    edges.removeWhere((_, e) => e.a == node || e.b == node);
    target.semanticEntityId = id;
    target.label = brain.entities[id].label;
    final entityNode = 'e:$id';
    final key = node.compareTo(entityNode) <= 0
        ? '$node|$entityNode'
        : '$entityNode|$node';
    edges[key] = WorldEdge06(
      a: node,
      b: entityNode,
      cost: 0.20,
      fast: 0.88,
      slow: 0.72,
      elig: 0.92,
      meta: 0.80,
      uses: 2,
      lastUsed: step,
    );
    return true;
  }

  bool deleteThought12(ThoughtStep06 thought) {
    final before = thoughts.length;
    thoughts.removeWhere(
      (t) =>
          t.cycle == thought.cycle &&
          t.hypothesis == thought.hypothesis &&
          t.coherence == thought.coherence,
    );
    return thoughts.length != before;
  }

  void clearThoughts12() {
    thoughts.clear();
    hypothesisFatigue011.clear();
  }
}

int quarantineUnsafeResearch12(
  PlasticLanguageBrain04 brain,
  ResearchMemory11 memory,
) {
  var quarantined = 0;
  for (final claim in memory.claims.values) {
    if (claim.status == 'corretta_utente' || claim.sourceFamilies.contains('utente')) continue;
    final weakSources = claim.independentSourceCount < 2;
    final text = '${claim.subject} ${claim.relation} ${claim.object}'.toLowerCase();
    final suspicious =
        text.contains('articolo della wikipedia') ||
        text.contains('pagina di disambiguazione') ||
        text.contains('categoria wikimedia') ||
        RegExp(r'\bthe\b|\busing\b|\bsomething\b|\bfilm del 2025\b')
            .hasMatch(text);
    if (!weakSources && !suspicious) continue;
    final removed = brain.deleteFactByLabels12(
      claim.subject,
      claim.relation,
      claim.object,
      deleteSourceEpisodes: true,
    );
    if (removed) quarantined++;
    claim.status = 'quarantena';
    claim.confidence = min(claim.confidence, 0.34);
  }
  return quarantined;
}

void quarantineResearchClaim12(
  PlasticLanguageBrain04 brain,
  ResearchClaim11 claim,
) {
  brain.deleteFactByLabels12(
    claim.subject,
    claim.relation,
    claim.object,
    deleteSourceEpisodes: true,
  );
  claim.status = 'quarantena';
  claim.confidence = min(claim.confidence, 0.34);
}

void correctResearchClaim12(
  PlasticLanguageBrain04 brain,
  ResearchMemory11 memory,
  ResearchClaim11 claim, {
  required String subject,
  required String relation,
  required String object,
}) {
  brain.deleteFactByLabels12(
    claim.subject,
    claim.relation,
    claim.object,
    deleteSourceEpisodes: true,
  );
  memory.claims.remove(claim.key);

  final s = subject.trim();
  final r = relation.trim();
  final o = object.trim();
  if (s.isEmpty || r.isEmpty || o.isEmpty) return;
  brain.upsertManualFact12(
    subject: s,
    relation: r,
    object: o,
    confidence: 0.98,
  );
  final key = '${normalizeAdmin12(s)}|${normalizeAdmin12(r)}|${normalizeAdmin12(o)}';
  memory.claims[key] = ResearchClaim11(
    key: key,
    subject: s,
    relation: r,
    object: o,
    confidence: 0.98,
    conflict: false,
    status: 'corretta_utente',
    lastSeenIso: DateTime.now().toIso8601String(),
    evidenceIds: Set<String>.from(claim.evidenceIds),
    sourceFamilies: <String>{...claim.sourceFamilies, 'utente'},
  );
}
