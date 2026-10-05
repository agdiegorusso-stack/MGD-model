import 'dart:math';

import 'package:flutter/material.dart';

import 'native_mgd_engine_v09.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

class ConceptFact16 {
  final String text;
  final double confidence;
  const ConceptFact16(this.text, this.confidence);
}

class ConceptNeighbor16 {
  final int entityId;
  final String label;
  final double strength;
  const ConceptNeighbor16({
    required this.entityId,
    required this.label,
    required this.strength,
  });
}

class ConceptModality16 {
  final String name;
  final int traces;
  final int observations;
  final double stability;
  final Map<String, double> centroid;

  const ConceptModality16({
    required this.name,
    required this.traces,
    required this.observations,
    required this.stability,
    required this.centroid,
  });

  bool get present => traces > 0;
}

class MultimodalConcept16 {
  final int entityId;
  final String label;
  final ConceptModality16 vision;
  final ConceptModality16 audio;
  final int languageEpisodes;
  final int webEvidence;
  final List<ConceptFact16> facts;
  final List<String> webClaims;
  final List<ConceptNeighbor16> neighbors;
  final Map<String, double> languageSignature;
  final Map<String, double> webSignature;
  final Map<String, double> fusedSignature;
  final double maturity;

  const MultimodalConcept16({
    required this.entityId,
    required this.label,
    required this.vision,
    required this.audio,
    required this.languageEpisodes,
    required this.webEvidence,
    required this.facts,
    required this.webClaims,
    required this.neighbors,
    required this.languageSignature,
    required this.webSignature,
    required this.fusedSignature,
    required this.maturity,
  });

  int get modalityCount {
    var n = 0;
    if (facts.isNotEmpty || languageEpisodes > 0) n++;
    if (vision.present) n++;
    if (audio.present) n++;
    if (webEvidence > 0) n++;
    return n;
  }

  List<String> get missingModalities {
    final out = <String>[];
    if (facts.isEmpty && languageEpisodes == 0) out.add('linguaggio');
    if (!vision.present) out.add('visione');
    if (!audio.present) out.add('udito');
    if (webEvidence == 0) out.add('ricerca');
    return out;
  }
}

class MultimodalConceptIndex16 {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;

  final Map<int, List<CognitiveFact06>> _facts = {};
  final Map<int, List<Episode04>> _episodes = {};
  final Map<int, List<SensoryPrototype06>> _prototypes = {};
  final Map<int, List<ResearchClaim11>> _claims = {};
  final Map<int, List<ConceptNeighbor16>> _neighbors = {};
  final Set<int> _candidateIds = {};

  MultimodalConceptIndex16({
    required this.brain,
    required this.world,
    required this.research,
  }) {
    _index();
  }

  void _index() {
    for (final f in brain.cognitiveFacts06()) {
      _facts.putIfAbsent(f.subjectId, () => <CognitiveFact06>[]).add(f);
      _candidateIds.add(f.subjectId);
      final oid = f.objectEntityId;
      if (oid != null) {
        _facts.putIfAbsent(oid, () => <CognitiveFact06>[]).add(f);
        _candidateIds.add(oid);
      }
    }

    for (final ep in brain.episodes) {
      final sid = ep.subjectId;
      if (sid == null) continue;
      _episodes.putIfAbsent(sid, () => <Episode04>[]).add(ep);
      _candidateIds.add(sid);
    }

    for (final p in world.prototypes) {
      final id = p.semanticEntityId;
      if (id == null) continue;
      _prototypes.putIfAbsent(id, () => <SensoryPrototype06>[]).add(p);
      _candidateIds.add(id);
    }

    for (final claim in research.claims.values) {
      final s = brain.entityIdForLabel06(claim.subject);
      final o = brain.entityIdForLabel06(claim.object);
      if (s != null) {
        _claims.putIfAbsent(s, () => <ResearchClaim11>[]).add(claim);
        _candidateIds.add(s);
      }
      if (o != null) {
        _claims.putIfAbsent(o, () => <ResearchClaim11>[]).add(claim);
        _candidateIds.add(o);
      }
    }

    for (final e in world.edges.values) {
      if (!e.a.startsWith('e:') || !e.b.startsWith('e:')) continue;
      final a = int.tryParse(e.a.substring(2));
      final b = int.tryParse(e.b.substring(2));
      if (a == null || b == null) continue;
      if (a < 0 || b < 0 || a >= brain.entities.length || b >= brain.entities.length) {
        continue;
      }
      final strength = MgdMath09.strength(
        weight: e.cost,
        memory: e.fast,
        material: e.slow,
      );
      if (strength <= 0.01) continue;
      _neighbors.putIfAbsent(a, () => <ConceptNeighbor16>[]).add(
            ConceptNeighbor16(
              entityId: b,
              label: brain.entities[b].label,
              strength: strength,
            ),
          );
      _neighbors.putIfAbsent(b, () => <ConceptNeighbor16>[]).add(
            ConceptNeighbor16(
              entityId: a,
              label: brain.entities[a].label,
              strength: strength,
            ),
          );
      _candidateIds
        ..add(a)
        ..add(b);
    }

    for (final e in brain.entities) {
      if (e.mentions > 0) _candidateIds.add(e.id);
    }
  }

  List<int> get candidateEntityIds {
    final ids = _candidateIds
        .where((id) => id >= 0 && id < brain.entities.length)
        .toList();
    ids.sort((a, b) {
      final ea = brain.entities[a];
      final eb = brain.entities[b];
      final scoreA = ea.mentions +
          (_facts[a]?.length ?? 0) * 2 +
          (_prototypes[a]?.length ?? 0) * 4 +
          (_claims[a]?.length ?? 0) * 2;
      final scoreB = eb.mentions +
          (_facts[b]?.length ?? 0) * 2 +
          (_prototypes[b]?.length ?? 0) * 4 +
          (_claims[b]?.length ?? 0) * 2;
      return scoreB.compareTo(scoreA);
    });
    return ids;
  }

  MultimodalConcept16 build(int entityId) {
    if (entityId < 0 || entityId >= brain.entities.length) {
      throw RangeError.index(entityId, brain.entities, 'entityId');
    }
    final entity = brain.entities[entityId];
    final protos = _prototypes[entityId] ?? const <SensoryPrototype06>[];
    final visionPs = protos.where((p) => p.modality == 'vision').toList();
    final audioPs = protos.where((p) => p.modality == 'audio').toList();
    final vision = _aggregateModality('visione', visionPs);
    final audio = _aggregateModality('udito', audioPs);

    final factRows = <ConceptFact16>[];
    final textual = <String>[];
    for (final f in _facts[entityId] ?? const <CognitiveFact06>[]) {
      String text;
      if (f.subjectId == entityId) {
        text = '${entity.label} — ${f.relation} → ${f.object}';
      } else {
        final subject = f.subjectId >= 0 && f.subjectId < brain.entities.length
            ? brain.entities[f.subjectId].label
            : 'entità ${f.subjectId}';
        text = '$subject — ${f.relation} → ${entity.label}';
      }
      factRows.add(ConceptFact16(text, f.confidence));
      textual.add(text);
    }
    factRows.sort((a, b) => b.confidence.compareTo(a.confidence));

    final episodes = _episodes[entityId] ?? const <Episode04>[];
    for (final ep in episodes.reversed.take(18)) {
      textual.add(ep.userText);
      if (ep.agentText != null) textual.add(ep.agentText!);
    }

    final claims = _claims[entityId] ?? const <ResearchClaim11>[];
    final webRows = <String>[];
    var evidence = 0;
    for (final c in claims) {
      evidence += c.evidenceCount;
      webRows.add('${c.subject} — ${c.relation} → ${c.object} '
          '[${(c.confidence * 100).round()}% • ${c.status}]');
    }

    final languageSignature = _textSignature(textual.join(' '), 't');
    final webSignature = _textSignature(webRows.join(' '), 'w');
    final fused = <String, double>{};
    _mergeSignature(fused, vision.centroid, 'v', 0.34);
    _mergeSignature(fused, audio.centroid, 'a', 0.26);
    _mergeSignature(fused, languageSignature, 't', 0.26);
    _mergeSignature(fused, webSignature, 'w', 0.14);
    _l2Normalize(fused);

    final neighbors = List<ConceptNeighbor16>.from(
      _neighbors[entityId] ?? const <ConceptNeighbor16>[],
    )..sort((a, b) => b.strength.compareTo(a.strength));

    final languageScore =
        min(1.0, factRows.length / 8.0 + episodes.length / 16.0);
    final visionScore = vision.present
        ? (0.55 * vision.stability +
                0.45 * min(1.0, vision.observations / 6.0))
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;
    final audioScore = audio.present
        ? (0.55 * audio.stability +
                0.45 * min(1.0, audio.observations / 6.0))
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;
    final webScore = min(1.0, evidence / 6.0);
    final relationalScore = min(1.0, neighbors.length / 8.0);
    final coverage =
        ([languageScore, visionScore, audioScore, webScore]
                    .where((x) => x > 0.02)
                    .length /
                4.0)
            .clamp(0.0, 1.0)
            .toDouble();

    final maturity = (0.28 * languageScore +
            0.22 * visionScore +
            0.18 * audioScore +
            0.12 * webScore +
            0.10 * relationalScore +
            0.10 * coverage)
        .clamp(0.0, 1.0)
        .toDouble();

    return MultimodalConcept16(
      entityId: entityId,
      label: entity.label,
      vision: vision,
      audio: audio,
      languageEpisodes: episodes.length,
      webEvidence: evidence,
      facts: factRows,
      webClaims: webRows,
      neighbors: neighbors,
      languageSignature: languageSignature,
      webSignature: webSignature,
      fusedSignature: fused,
      maturity: maturity,
    );
  }

  List<({MultimodalConcept16 concept, double similarity})> similarTo(
    int entityId, {
    int limit = 8,
    int scanLimit = 700,
  }) {
    final target = build(entityId);
    if (target.fusedSignature.isEmpty) return const [];
    final out = <({MultimodalConcept16 concept, double similarity})>[];
    for (final id in candidateEntityIds.take(scanLimit)) {
      if (id == entityId) continue;
      final other = build(id);
      if (other.fusedSignature.isEmpty) continue;
      final sim = _cosine(target.fusedSignature, other.fusedSignature);
      if (sim < 0.08) continue;
      out.add((concept: other, similarity: sim));
    }
    out.sort((a, b) => b.similarity.compareTo(a.similarity));
    return out.take(limit).toList();
  }

  ConceptModality16 _aggregateModality(
    String name,
    List<SensoryPrototype06> ps,
  ) {
    if (ps.isEmpty) {
      return ConceptModality16(
        name: name,
        traces: 0,
        observations: 0,
        stability: 0,
        centroid: const <String, double>{},
      );
    }
    final centroid = <String, double>{};
    var totalWeight = 0.0;
    var stability = 0.0;
    var observations = 0;
    for (final p in ps) {
      final w = max(0.10, p.stability) *
          (1.0 + log(1.0 + max(1, p.observations)));
      totalWeight += w;
      stability += p.stability * w;
      observations += p.observations;
      for (final e in p.centroid.entries) {
        centroid[e.key] = (centroid[e.key] ?? 0) + e.value * w;
      }
    }
    if (totalWeight > 0) {
      for (final k in centroid.keys.toList()) {
        centroid[k] = centroid[k]! / totalWeight;
      }
    }
    return ConceptModality16(
      name: name,
      traces: ps.length,
      observations: observations,
      stability: totalWeight <= 0 ? 0 : stability / totalWeight,
      centroid: centroid,
    );
  }

  Map<String, double> _textSignature(String text, String prefix) {
    final out = <String, double>{};
    final tokens = PlasticLanguageBrain04.lexicalTokens(text)
        .map(PlasticLanguageBrain04.normalizeText)
        .where((x) => x.length >= 2)
        .toList();
    if (tokens.isEmpty) return out;
    for (final token in tokens) {
      final bin = _stableHash(token) % 64;
      final key = '$prefix:$bin';
      out[key] = (out[key] ?? 0) + 1.0;
    }
    _l2Normalize(out);
    return out;
  }

  int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  void _mergeSignature(
    Map<String, double> target,
    Map<String, double> source,
    String namespace,
    double weight,
  ) {
    for (final e in source.entries) {
      target['$namespace:${e.key}'] =
          (target['$namespace:${e.key}'] ?? 0) + e.value * weight;
    }
  }

  void _l2Normalize(Map<String, double> x) {
    var sum = 0.0;
    for (final v in x.values) {
      sum += v * v;
    }
    if (sum <= 1e-12) return;
    final n = sqrt(sum);
    for (final k in x.keys.toList()) {
      x[k] = x[k]! / n;
    }
  }

  double _cosine(Map<String, double> a, Map<String, double> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final small = a.length <= b.length ? a : b;
    final large = identical(small, a) ? b : a;
    var dot = 0.0;
    var aa = 0.0;
    var bb = 0.0;
    for (final v in a.values) aa += v * v;
    for (final v in b.values) bb += v * v;
    for (final e in small.entries) {
      dot += e.value * (large[e.key] ?? 0);
    }
    if (aa <= 1e-12 || bb <= 1e-12) return 0;
    return (dot / sqrt(aa * bb)).clamp(0.0, 1.0).toDouble();
  }
}

class MultimodalConceptsPage16 extends StatefulWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;

  const MultimodalConceptsPage16({
    super.key,
    required this.brain,
    required this.world,
    required this.research,
  });

  @override
  State<MultimodalConceptsPage16> createState() =>
      _MultimodalConceptsPage16State();
}

class _MultimodalConceptsPage16State extends State<MultimodalConceptsPage16> {
  late MultimodalConceptIndex16 index;
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    index = MultimodalConceptIndex16(
      brain: widget.brain,
      world: widget.world,
      research: widget.research,
    );
    search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = PlasticLanguageBrain04.normalizeText(search.text);
    final ids = index.candidateEntityIds.where((id) {
      if (q.isEmpty) return true;
      final e = widget.brain.entities[id];
      final labels = <String>[e.label, ...e.aliases];
      return labels.any(
        (x) => PlasticLanguageBrain04.normalizeText(x).contains(q),
      );
    }).take(160).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Concetti multimodali')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Cerca un concetto…',
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: search.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Una stessa entità unisce linguaggio, fatti, immagini, suoni, '
                'ricerca web e relazioni in una firma MGD unica.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ids.isEmpty
                ? const Center(child: Text('Nessun concetto trovato.'))
                : ListView.builder(
                    itemCount: ids.length,
                    itemBuilder: (context, i) {
                      final c = index.build(ids[i]);
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${c.modalityCount}M'),
                        ),
                        title: Text(c.label),
                        subtitle: Text(
                          'testo ${c.facts.length} • visione ${c.vision.traces} • '
                          'audio ${c.audio.traces} • web ${c.webEvidence} • '
                          'maturità ${(c.maturity * 100).round()}%',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MultimodalConceptDetailPage16(
                              index: index,
                              entityId: c.entityId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MultimodalConceptDetailPage16 extends StatelessWidget {
  final MultimodalConceptIndex16 index;
  final int entityId;

  const MultimodalConceptDetailPage16({
    super.key,
    required this.index,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context) {
    final c = index.build(entityId);
    final similar = index.similarTo(entityId);
    return Scaffold(
      appBar: AppBar(title: Text(c.label)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            'Rappresentazione multimodale',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Firma fusa: ${c.fusedSignature.length} dimensioni attive • '
            '${c.modalityCount}/4 modalità • maturità ${(c.maturity * 100).round()}%',
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: c.maturity),
          if (c.missingModalities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Modalità ancora mancanti: ${c.missingModalities.join(', ')}'),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ModeCard16(
                icon: Icons.text_fields,
                title: 'Linguaggio',
                value: '${c.facts.length} fatti',
                detail: '${c.languageEpisodes} episodi',
                active: c.facts.isNotEmpty || c.languageEpisodes > 0,
              ),
              _ModeCard16(
                icon: Icons.visibility_outlined,
                title: 'Visione',
                value: '${c.vision.traces} pattern',
                detail:
                    '${c.vision.observations} osservazioni • ${(c.vision.stability * 100).round()}%',
                active: c.vision.present,
              ),
              _ModeCard16(
                icon: Icons.hearing_outlined,
                title: 'Udito',
                value: '${c.audio.traces} pattern',
                detail:
                    '${c.audio.observations} osservazioni • ${(c.audio.stability * 100).round()}%',
                active: c.audio.present,
              ),
              _ModeCard16(
                icon: Icons.travel_explore,
                title: 'Ricerca',
                value: '${c.webEvidence} evidenze',
                detail: '${c.webClaims.length} conoscenze web',
                active: c.webEvidence > 0,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Fatti collegati', style: Theme.of(context).textTheme.titleMedium),
          if (c.facts.isEmpty)
            const Text('Nessun fatto linguistico collegato.')
          else
            ...c.facts.take(16).map(
                  (f) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.hub_outlined, size: 19),
                    title: Text(f.text),
                    trailing: Text('${(f.confidence * 100).round()}%'),
                  ),
                ),
          const SizedBox(height: 12),
          Text('Vicinato MGD', style: Theme.of(context).textTheme.titleMedium),
          if (c.neighbors.isEmpty)
            const Text('Nessun collegamento mondo attivo.')
          else
            ...c.neighbors.take(12).map(
                  (n) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.account_tree_outlined, size: 19),
                    title: Text(n.label),
                    trailing: Text('${(n.strength * 100).round()}%'),
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => MultimodalConceptDetailPage16(
                          index: index,
                          entityId: n.entityId,
                        ),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          Text(
            'Concetti multimodalmente simili',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (similar.isEmpty)
            const Text('Non abbastanza informazione multimodale per il confronto.')
          else
            ...similar.map(
              (x) => ListTile(
                dense: true,
                leading: const Icon(Icons.blur_on, size: 19),
                title: Text(x.concept.label),
                subtitle: Text('${x.concept.modalityCount}/4 modalità'),
                trailing: Text('${(x.similarity * 100).round()}%'),
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => MultimodalConceptDetailPage16(
                      index: index,
                      entityId: x.concept.entityId,
                    ),
                  ),
                ),
              ),
            ),
          if (c.webClaims.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Conoscenza ricercata',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...c.webClaims.take(10).map(
                  (x) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('• $x'),
                  ),
                ),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _ModeCard16 extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final bool active;

  const _ModeCard16({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 7),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(value),
              Text(
                active ? detail : 'non ancora acquisito',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
