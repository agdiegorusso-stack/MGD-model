import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'native_mgd_engine_v09.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';

class ScalingRow16 {
  final int edges;
  final int nodes;
  final int activeBudget;
  final int cycles;
  final int runs;
  final int visitedEdges;
  final int uniqueEdgeVisits;
  final int maxFrontier;
  final double sparseMs;
  final double sparseP95Ms;
  final double denseScanMs;
  final double denseP95Ms;
  final double dense96EstimateMs;
  final double memoryMb;

  const ScalingRow16({
    required this.edges,
    required this.nodes,
    required this.activeBudget,
    required this.cycles,
    required this.runs,
    required this.visitedEdges,
    required this.uniqueEdgeVisits,
    required this.maxFrontier,
    required this.sparseMs,
    required this.sparseP95Ms,
    required this.denseScanMs,
    required this.denseP95Ms,
    required this.dense96EstimateMs,
    required this.memoryMb,
  });

  factory ScalingRow16.fromMap(Map<String, dynamic> m) => ScalingRow16(
        edges: m['edges'] as int,
        nodes: m['nodes'] as int,
        activeBudget: m['activeBudget'] as int,
        cycles: m['cycles'] as int,
        runs: (m['runs'] as int?) ?? 1,
        visitedEdges: m['visitedEdges'] as int,
        uniqueEdgeVisits: (m['uniqueEdgeVisits'] as int?) ?? m['visitedEdges'] as int,
        maxFrontier: (m['maxFrontier'] as int?) ?? 0,
        sparseMs: (m['sparseMs'] as num).toDouble(),
        sparseP95Ms: ((m['sparseP95Ms'] ?? m['sparseMs']) as num).toDouble(),
        denseScanMs: (m['denseScanMs'] as num).toDouble(),
        denseP95Ms: ((m['denseP95Ms'] ?? m['denseScanMs']) as num).toDouble(),
        dense96EstimateMs: (m['dense96EstimateMs'] as num).toDouble(),
        memoryMb: (m['memoryMb'] as num).toDouble(),
      );

  double get uniqueFractionPerCycle =>
      edges <= 0 || cycles <= 0 ? 0 : uniqueEdgeVisits / (edges * cycles);

  double get totalVisitFactorPerCycle =>
      edges <= 0 || cycles <= 0 ? 0 : visitedEdges / (edges * cycles);
}

class RealGraphBenchmark17 {
  final int edges;
  final int nodes;
  final int cycles;
  final int runs;
  final int visitedEdges;
  final int uniqueEdgeVisits;
  final int maxFrontier;
  final double medianMs;
  final double p95Ms;
  final double uniqueFractionPerCycle;

  const RealGraphBenchmark17({
    required this.edges,
    required this.nodes,
    required this.cycles,
    required this.runs,
    required this.visitedEdges,
    required this.uniqueEdgeVisits,
    required this.maxFrontier,
    required this.medianMs,
    required this.p95Ms,
    required this.uniqueFractionPerCycle,
  });

  factory RealGraphBenchmark17.fromMap(Map<String, dynamic> m) =>
      RealGraphBenchmark17(
        edges: m['edges'] as int,
        nodes: m['nodes'] as int,
        cycles: m['cycles'] as int,
        runs: m['runs'] as int,
        visitedEdges: m['visitedEdges'] as int,
        uniqueEdgeVisits: m['uniqueEdgeVisits'] as int,
        maxFrontier: m['maxFrontier'] as int,
        medianMs: (m['medianMs'] as num).toDouble(),
        p95Ms: (m['p95Ms'] as num).toDouble(),
        uniqueFractionPerCycle: (m['uniqueFractionPerCycle'] as num).toDouble(),
      );
}

double _median17(List<double> xs) {
  if (xs.isEmpty) return 0;
  final s = List<double>.from(xs)..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

double _p9517(List<double> xs) {
  if (xs.isEmpty) return 0;
  final s = List<double>.from(xs)..sort();
  final idx = ((s.length - 1) * 0.95).ceil().clamp(0, s.length - 1).toInt();
  return s[idx];
}

Map<String, dynamic> _runSparse17({
  required Int32List offsets,
  required Int32List neighbors,
  required Int32List edgeIds,
  required Float32List weights,
  required int nodeCount,
  required int edgeCount,
  required int cycles,
  required int maxActive,
  required int seed,
  required Int32List edgeStamp,
}) {
  var state = seed & 0x7fffffff;
  int nextRand() {
    state = (1664525 * state + 1013904223) & 0x7fffffff;
    return state;
  }

  final active = Int32List(maxActive);
  final next = Int32List(maxActive);
  final nodeStamp = Int32List(nodeCount);
  var nodeStampValue = 1;
  var edgeStampValue = 1;
  var activeCount = min(64, maxActive);
  for (var i = 0; i < activeCount; i++) {
    active[i] = nextRand() % nodeCount;
  }

  var visited = 0;
  var uniqueVisited = 0;
  var maxFrontier = activeCount;
  var checksum = 0.0;
  final sw = Stopwatch()..start();

  for (var c = 0; c < cycles; c++) {
    nodeStampValue++;
    edgeStampValue++;
    if (nodeStampValue >= 0x7ffffffe) {
      nodeStamp.fillRange(0, nodeStamp.length, 0);
      nodeStampValue = 1;
    }
    if (edgeStampValue >= 0x7ffffffe) {
      edgeStamp.fillRange(0, edgeStamp.length, 0);
      edgeStampValue = 1;
    }

    var nextCount = 0;
    for (var i = 0; i < activeCount; i++) {
      final node = active[i];
      final start = offsets[node];
      final end = offsets[node + 1];
      for (var p = start; p < end; p++) {
        visited++;
        final eid = edgeIds[p];
        if (edgeStamp[eid] != edgeStampValue) {
          edgeStamp[eid] = edgeStampValue;
          uniqueVisited++;
        }
        final w = weights[eid];
        checksum += w * 0.0000001;
        if (w < 0.58) continue;
        final n = neighbors[p];
        if (nodeStamp[n] == nodeStampValue) continue;
        nodeStamp[n] = nodeStampValue;
        if (nextCount < maxActive) next[nextCount++] = n;
      }
    }
    if (nextCount == 0) {
      next[0] = nextRand() % nodeCount;
      nextCount = 1;
    }
    maxFrontier = max(maxFrontier, nextCount);
    activeCount = nextCount;
    for (var i = 0; i < activeCount; i++) {
      active[i] = next[i];
    }
  }
  sw.stop();

  return {
    'ms': sw.elapsedMicroseconds / 1000.0,
    'visited': visited,
    'uniqueVisited': uniqueVisited,
    'maxFrontier': maxFrontier,
    'checksum': checksum,
  };
}

Map<String, dynamic> runMgdScalingBenchmark16(Map<String, dynamic> input) {
  final sizes = (input['sizes'] as List).cast<int>();
  final cycles = input['cycles'] as int? ?? 24;
  final maxActive = input['maxActive'] as int? ?? 2048;
  final runs = max(3, input['runs'] as int? ?? 7);
  final rows = <Map<String, dynamic>>[];

  var globalState = 0x1234abcd;
  int nextRand() {
    globalState = (1664525 * globalState + 1013904223) & 0x7fffffff;
    return globalState;
  }

  for (final edgeCount in sizes) {
    final nodeCount = max(256, edgeCount ~/ 5);
    final a = Int32List(edgeCount);
    final b = Int32List(edgeCount);
    final weight = Float32List(edgeCount);
    final degree = Int32List(nodeCount);

    for (var i = 0; i < edgeCount; i++) {
      final x = nextRand() % nodeCount;
      var y = nextRand() % nodeCount;
      if (y == x) y = (y + 1) % nodeCount;
      a[i] = x;
      b[i] = y;
      weight[i] = 0.25 + (nextRand() % 7500) / 10000.0;
      degree[x]++;
      degree[y]++;
    }

    final offsets = Int32List(nodeCount + 1);
    for (var i = 0; i < nodeCount; i++) {
      offsets[i + 1] = offsets[i] + degree[i];
    }
    final neighbors = Int32List(edgeCount * 2);
    final edgeIds = Int32List(edgeCount * 2);
    final cursor = Int32List.fromList(offsets.sublist(0, nodeCount));
    for (var i = 0; i < edgeCount; i++) {
      var p = cursor[a[i]]++;
      neighbors[p] = b[i];
      edgeIds[p] = i;
      p = cursor[b[i]]++;
      neighbors[p] = a[i];
      edgeIds[p] = i;
    }

    final edgeStamp = Int32List(edgeCount);
    _runSparse17(
      offsets: offsets,
      neighbors: neighbors,
      edgeIds: edgeIds,
      weights: weight,
      nodeCount: nodeCount,
      edgeCount: edgeCount,
      cycles: min(4, cycles),
      maxActive: maxActive,
      seed: nextRand(),
      edgeStamp: edgeStamp,
    );

    final sparseTimes = <double>[];
    final denseTimes = <double>[];
    final visitedRuns = <int>[];
    final uniqueRuns = <int>[];
    final frontierRuns = <int>[];
    var checksum = 0.0;

    for (var run = 0; run < runs; run++) {
      final sparse = _runSparse17(
        offsets: offsets,
        neighbors: neighbors,
        edgeIds: edgeIds,
        weights: weight,
        nodeCount: nodeCount,
        edgeCount: edgeCount,
        cycles: cycles,
        maxActive: maxActive,
        seed: nextRand(),
        edgeStamp: edgeStamp,
      );
      sparseTimes.add((sparse['ms'] as num).toDouble());
      visitedRuns.add(sparse['visited'] as int);
      uniqueRuns.add(sparse['uniqueVisited'] as int);
      frontierRuns.add(sparse['maxFrontier'] as int);
      checksum += (sparse['checksum'] as num).toDouble();

      final swDense = Stopwatch()..start();
      var denseChecksum = 0.0;
      for (var i = 0; i < edgeCount; i++) {
        denseChecksum += weight[i] * (a[i] + 1) * 0.0000000001;
      }
      swDense.stop();
      denseTimes.add(swDense.elapsedMicroseconds / 1000.0);
      checksum += denseChecksum;
    }

    visitedRuns.sort();
    uniqueRuns.sort();
    frontierRuns.sort();
    final visitedMedian = visitedRuns[visitedRuns.length ~/ 2];
    final uniqueMedian = uniqueRuns[uniqueRuns.length ~/ 2];
    final frontierP95 = frontierRuns[((frontierRuns.length - 1) * 0.95).ceil()];
    final sparseMedian = _median17(sparseTimes);
    final denseMedian = _median17(denseTimes);

    final bytes = a.lengthInBytes +
        b.lengthInBytes +
        weight.lengthInBytes +
        degree.lengthInBytes +
        offsets.lengthInBytes +
        neighbors.lengthInBytes +
        edgeIds.lengthInBytes +
        edgeStamp.lengthInBytes +
        Int32List(maxActive).lengthInBytes * 2 +
        Int32List(nodeCount).lengthInBytes;

    rows.add({
      'edges': edgeCount,
      'nodes': nodeCount,
      'activeBudget': maxActive,
      'cycles': cycles,
      'runs': runs,
      'visitedEdges': visitedMedian,
      'uniqueEdgeVisits': uniqueMedian,
      'maxFrontier': frontierP95,
      'sparseMs': sparseMedian,
      'sparseP95Ms': _p9517(sparseTimes),
      'denseScanMs': denseMedian,
      'denseP95Ms': _p9517(denseTimes),
      'dense96EstimateMs': denseMedian * 96.0,
      'memoryMb': bytes / (1024.0 * 1024.0),
      'checksum': checksum,
    });
  }

  return {'rows': rows};
}

Map<String, dynamic> runRealGraphBenchmark17(Map<String, dynamic> input) {
  final rawEdges = (input['edges'] as List).cast<List<dynamic>>();
  final nodeCount = max(1, input['nodes'] as int? ?? 1);
  final cycles = input['cycles'] as int? ?? 96;
  final maxActive = input['maxActive'] as int? ?? 512;
  final runs = max(3, input['runs'] as int? ?? 7);
  final edgeCount = rawEdges.length;
  if (edgeCount == 0) {
    return {
      'edges': 0,
      'nodes': nodeCount,
      'cycles': cycles,
      'runs': runs,
      'visitedEdges': 0,
      'uniqueEdgeVisits': 0,
      'maxFrontier': 0,
      'medianMs': 0.0,
      'p95Ms': 0.0,
      'uniqueFractionPerCycle': 0.0,
    };
  }

  final a = Int32List(edgeCount);
  final b = Int32List(edgeCount);
  final weights = Float32List(edgeCount);
  final degree = Int32List(nodeCount);
  for (var i = 0; i < edgeCount; i++) {
    final row = rawEdges[i];
    final x = (row[0] as num).toInt().clamp(0, nodeCount - 1).toInt();
    final y = (row[1] as num).toInt().clamp(0, nodeCount - 1).toInt();
    a[i] = x;
    b[i] = y;
    weights[i] = (row[2] as num).toDouble().clamp(0.0, 1.0);
    degree[x]++;
    degree[y]++;
  }
  final offsets = Int32List(nodeCount + 1);
  for (var i = 0; i < nodeCount; i++) offsets[i + 1] = offsets[i] + degree[i];
  final neighbors = Int32List(edgeCount * 2);
  final edgeIds = Int32List(edgeCount * 2);
  final cursor = Int32List.fromList(offsets.sublist(0, nodeCount));
  for (var i = 0; i < edgeCount; i++) {
    var p = cursor[a[i]]++;
    neighbors[p] = b[i];
    edgeIds[p] = i;
    p = cursor[b[i]]++;
    neighbors[p] = a[i];
    edgeIds[p] = i;
  }

  final edgeStamp = Int32List(edgeCount);
  final times = <double>[];
  final visits = <int>[];
  final uniques = <int>[];
  final frontiers = <int>[];
  for (var run = 0; run < runs; run++) {
    final out = _runSparse17(
      offsets: offsets,
      neighbors: neighbors,
      edgeIds: edgeIds,
      weights: weights,
      nodeCount: nodeCount,
      edgeCount: edgeCount,
      cycles: cycles,
      maxActive: maxActive,
      seed: 0x51f15e + run * 7919,
      edgeStamp: edgeStamp,
    );
    times.add((out['ms'] as num).toDouble());
    visits.add(out['visited'] as int);
    uniques.add(out['uniqueVisited'] as int);
    frontiers.add(out['maxFrontier'] as int);
  }
  visits.sort();
  uniques.sort();
  frontiers.sort();
  final v = visits[visits.length ~/ 2];
  final u = uniques[uniques.length ~/ 2];
  final f = frontiers[((frontiers.length - 1) * 0.95).ceil()];
  return {
    'edges': edgeCount,
    'nodes': nodeCount,
    'cycles': cycles,
    'runs': runs,
    'visitedEdges': v,
    'uniqueEdgeVisits': u,
    'maxFrontier': f,
    'medianMs': _median17(times),
    'p95Ms': _p9517(times),
    'uniqueFractionPerCycle': u / (edgeCount * cycles),
  };
}

class MgdScalingLabPage16 extends StatefulWidget {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;

  const MgdScalingLabPage16({
    super.key,
    required this.brain,
    required this.world,
  });

  @override
  State<MgdScalingLabPage16> createState() => _MgdScalingLabPage16State();
}

class _MgdScalingLabPage16State extends State<MgdScalingLabPage16> {
  bool running = false;
  bool extended = false;
  List<ScalingRow16> rows = const [];
  RealGraphBenchmark17? real;
  String? error;

  Map<String, dynamic> _realGraphInput() {
    final ids = <String, int>{};
    int idFor(String key) => ids.putIfAbsent(key, () => ids.length);
    final edges = <List<dynamic>>[];

    for (final e in widget.world.edges.values) {
      final strength = MgdMath09.strength(
        weight: e.cost,
        memory: e.fast,
        material: e.slow,
      ).clamp(0.0, 1.0).toDouble();
      if (strength <= 0.01) continue;
      edges.add(<dynamic>[idFor(e.a), idFor(e.b), strength]);
    }
    for (final f in widget.brain.cognitiveFacts06()) {
      final o = f.objectEntityId;
      if (o == null) continue;
      edges.add(<dynamic>[
        idFor('e:${f.subjectId}'),
        idFor('e:$o'),
        f.confidence.clamp(0.0, 1.0).toDouble(),
      ]);
    }
    return <String, dynamic>{
      'edges': edges,
      'nodes': max(1, ids.length),
      'cycles': 96,
      'maxActive': 512,
      'runs': 7,
    };
  }

  Future<void> run() async {
    if (running) return;
    setState(() {
      running = true;
      error = null;
      rows = const [];
      real = null;
    });
    try {
      final sizes = <int>[1000, 10000, 100000, 500000, 1000000];
      if (extended) sizes.addAll(<int>[2000000, 5000000]);
      final syntheticFuture = compute(
        runMgdScalingBenchmark16,
        <String, dynamic>{
          'sizes': sizes,
          'cycles': 24,
          'maxActive': 2048,
          'runs': 7,
        },
      );
      final realFuture = compute(runRealGraphBenchmark17, _realGraphInput());
      final outputs = await Future.wait([syntheticFuture, realFuture]);
      final raw = outputs[0];
      final result = (raw['rows'] as List)
          .map((x) => ScalingRow16.fromMap(Map<String, dynamic>.from(x as Map)))
          .toList();
      final realResult = RealGraphBenchmark17.fromMap(
        Map<String, dynamic>.from(outputs[1]),
      );
      if (!mounted) return;
      setState(() {
        rows = result;
        real = realResult;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.brain.stats();
    final ws = widget.world.stats();
    final totalGraph = ws.worldEdges + bs.facts;
    final activeRatio = ws.worldEdges == 0 ? 0.0 : ws.activeEdges / ws.worldEdges;
    return Scaffold(
      appBar: AppBar(title: const Text('Laboratorio scaling MGD')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('Misuriamo, non presumiamo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Ogni taglia viene misurata 7 volte. Mostro mediana e p95, distinguo visite '
            'totali da archi unici e misuro anche il grafo reale corrente senza modificarlo.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScaleMetric16('Entità reali', '${bs.entities}'),
              _ScaleMetric16('Fatti reali', '${bs.facts}'),
              _ScaleMetric16('Legami mondo', '${ws.worldEdges}'),
              _ScaleMetric16('Archi attivi', '${ws.activeEdges}'),
              _ScaleMetric16('Totale grafo', '$totalGraph'),
              _ScaleMetric16('Attivi', '${(activeRatio * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Benchmark esteso fino a 5M archi'),
            subtitle: const Text(
              'Usa più RAM e può scaldare il telefono. Il benchmark gira in un isolate separato.',
            ),
            value: extended,
            onChanged: running ? null : (v) => setState(() => extended = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: running ? null : run,
            icon: running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed),
            label: Text(running ? 'Benchmark in corso…' : 'Esegui benchmark sul telefono'),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text('Errore: $error'),
          ],
          if (real != null) ...[
            const SizedBox(height: 18),
            Text('Grafo reale corrente', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_fmtInt(real!.nodes)} nodi • ${_fmtInt(real!.edges)} archi'),
                    Text(
                      '96 cicli • mediana ${real!.medianMs.toStringAsFixed(2)} ms • '
                      'p95 ${real!.p95Ms.toStringAsFixed(2)} ms',
                    ),
                    Text(
                      'visite totali ${_fmtInt(real!.visitedEdges)} • '
                      'archi unici ${_fmtInt(real!.uniqueEdgeVisits)}',
                    ),
                    Text(
                      'quota unica/ciclo ${(real!.uniqueFractionPerCycle * 100).toStringAsFixed(3)}% • '
                      'frontier p95 ${_fmtInt(real!.maxFrontier)}',
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Grafi sintetici', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ...rows.map((r) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_fmtInt(r.edges)} archi',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_fmtInt(r.nodes)} nodi • memoria typed-array ≈ '
                          '${r.memoryMb.toStringAsFixed(1)} MB • ${r.runs} run',
                        ),
                        Text(
                          '${r.cycles} cicli sparsi: mediana ${r.sparseMs.toStringAsFixed(2)} ms • '
                          'p95 ${r.sparseP95Ms.toStringAsFixed(2)} ms',
                        ),
                        Text(
                          'visite totali ${_fmtInt(r.visitedEdges)} • '
                          'archi unici ${_fmtInt(r.uniqueEdgeVisits)} • frontier p95 ${_fmtInt(r.maxFrontier)}',
                        ),
                        Text(
                          'quota archi unici/ciclo ≈ '
                          '${(r.uniqueFractionPerCycle * 100).toStringAsFixed(3)}% • '
                          'visite con ripetizioni ≈ ${(r.totalVisitFactorPerCycle * 100).toStringAsFixed(1)}%',
                        ),
                        Text(
                          'scansione completa: mediana ${r.denseScanMs.toStringAsFixed(2)} ms • '
                          'p95 ${r.denseP95Ms.toStringAsFixed(2)} ms • '
                          '96 scansioni stimate ${r.dense96EstimateMs.toStringAsFixed(0)} ms',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            Text('Cosa manca per il confronto Transformer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Queste misure quantificano RAM e latenza di propagazione. Per dire che MGD è superiore '
              'servono anche qualità, apprendimento da pochi esempi, forgetting e joule reali per compito.',
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmtInt(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return '$n';
  }
}

class _ScaleMetric16 extends StatelessWidget {
  final String label;
  final String value;
  const _ScaleMetric16(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
