import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'mgd_language_v020.dart';
import 'native_mgd_engine_v09.dart';
import 'mgd_state_store_v026.dart';
import 'brain_admin_v012.dart';

// Read-only inspector: browsing never changes confidence, memory or graph edges.
String _json315(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
Map<String, dynamic> _map315(Object? x) =>
    x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{'valore': x};
List<Map<String, dynamic>> _maps315(Object? x) =>
    x is List ? x.map(_map315).toList() : <Map<String, dynamic>>[];
String _status315(Object? status) => switch (status) {
      'accettata' => 'CORROBORATA',
      'documentata' => 'DOCUMENTATA',
      'ipotesi_mgd' => 'OSSERVATA',
      'quarantena' => 'QUARANTENA',
      _ => '$status',
    };
String _title315(Map<String, dynamic> m) {
  if (m['from'] != null && m['to'] != null) {
    return '${m['from']} — ${m['relation'] ?? 'collegato a'} → ${m['to']}';
  }
  if (m['subject'] != null && m['relation'] != null && m['object'] != null) {
    return '${m['subject']} — ${m['relation']} → ${m['object']}';
  }
  for (final k in [
    'titolo',
    'title',
    'sourceTitle',
    'label',
    'topic',
    'text',
    'userText',
    'hypothesis',
    'term',
    't',
    'id',
    'key',
    'valore'
  ]) {
    final v = m[k];
    if (v != null && '$v'.trim().isNotEmpty) return '$v';
  }
  if (m['a'] != null && m['b'] != null) return '${m['a']} → ${m['b']}';
  return 'Elemento';
}

String _subtitle315(Map<String, dynamic> m) {
  final parts = <String>[];
  if (m['status'] != null) parts.add(_status315(m['status']));
  for (final k in [
    'provider',
    'sourceFamily',
    'source',
    'episodeId',
    'startedAtIso',
    'retrievedAtIso',
    'nota'
  ]) {
    if (m[k] != null && '${m[k]}'.isNotEmpty) parts.add('${m[k]}');
  }
  return parts.join(' · ');
}

class InspectorScope315 extends InheritedWidget {
  final MemoryInspector315 inspector;
  const InspectorScope315(
      {super.key, required this.inspector, required super.child});
  static MemoryInspector315? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<InspectorScope315>()
      ?.inspector;
  @override
  bool updateShouldNotify(InspectorScope315 oldWidget) => true;
}

class InspectMetric315 extends StatelessWidget {
  final String label, value;
  final bool session;
  const InspectMetric315(this.label, this.value,
      {super.key, this.session = false});
  @override
  Widget build(BuildContext context) {
    final inspector = InspectorScope315.maybeOf(context);
    final shown = inspector?.metricValue321(label, session: session) ?? value;
    return Semantics(
      button: inspector != null,
      label: '$label: $shown. Apri dettagli',
      child: SizedBox(
          width: 120,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: inspector == null
                  ? null
                  : () => inspector.openMetric(context, label,
                      session: session, value: shown),
              child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(shown,
                                    maxLines: 1,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge))),
                        const Icon(Icons.chevron_right, size: 18)
                      ]),
                      Text(label, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  )),
            ),
          )),
    );
  }
}

class MemoryInspector315 {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final MgdLanguage20 language;
  MemoryInspector315(
      {required this.brain,
      required this.world,
      required this.research,
      required this.language});

  static const catalog = <String>[
    'Stato motore',
    'Diagnostica ricerca',
    'Recupero testi 0.31.8',
    'Esporta backup pre-0.31.8',
    'Documentate',
    'Corroborate web',
    'Osservate',
    'Coda di verifica',
    'Frasi web lingua',
    'Riesame 0.31.7',
    'Esporta backup pre-0.31.7',
    'Consolidate web',
    'Ipotesi MGD',
    'Quarantena',
    'Evidenze',
    'Provider visti',
    'Famiglie con evidenza',
    'Testi da elaborare',
    'Testi non interpretati',
    'Ricerche avviate oggi',
    'Ricerche oggi',
    'Tutte le ricerche',
    'Documenti registrati',
    'Tentativi di verifica',
    'Entità',
    'Fatti cognitivi',
    'Episodi relazionali',
    'Concetti relazionali',
    'Episodica web',
    'Tutti i cluster',
    'Concetti narrativi',
    'Legami narrativi',
    'Termini narrativi',
    'Archi mondo',
    'Prior deboli',
    'Pre-attivi',
    'Archi attivi',
    'Cicli MGD',
    'Relazioni richiamate',
    'Età τ',
    'κ medio',
    'Visione',
    'Udito',
    'Binding',
    'Osservazioni sensoriali',
    'Sensi lessicali',
    'Variazioni di risposta',
    'Memoria di lavoro',
    'Token',
    'Archi lingua',
    'Macro-nodi',
    'Frasi viste',
    'Ultimo apprendimento',
    'Forme linguistiche',
  ];

  Future<void> openCatalog(BuildContext context) => _list(
      context,
      'Esplora tutta la memoria',
      () => catalog
          .map((label) =>
              <String, dynamic>{'titolo': label, '_metric315': label})
          .toList(),
      note:
          'Tocca una categoria, poi un elemento. Consultazione in sola lettura; nessuna promozione automatica aggiuntiva.');

  String nodeLabel(String node) {
    final id = int.tryParse(node.split(':').last);
    if (id != null && node.startsWith('e:')) {
      for (final e in brain.entities) {
        if (e.id == id) return e.label;
      }
    }
    if (id != null && node.startsWith('p:')) {
      for (final p in world.prototypes) {
        if (p.id == id) return p.label ?? '${p.modality} #$id';
      }
    }
    return node;
  }

  Map<String, dynamic> edgeRecord(WorldEdge06 e) => <String, dynamic>{
        'titolo': '${nodeLabel(e.a)} ↔ ${nodeLabel(e.b)}',
        'status':
            e.cost <= MgdMath09.defaults.epsilon ? 'ATTIVO' : 'NON ATTIVO',
        'soglia epsilon': MgdMath09.defaults.epsilon,
        'distanza dalla soglia': e.cost - MgdMath09.defaults.epsilon,
        'nota':
            'Attivo significa costo ≤ epsilon. Non è una prova della verità di una proposizione. I pre-attivi sono un sottoinsieme dei non attivi.',
        ...e.toJson(),
      };
  Map<String, dynamic> _claimRow(ResearchClaim11 c) =>
      <String, dynamic>{...c.toJson(), '_claim315': c.key};
  Map<String, dynamic> _evidenceRow(ResearchEvidence11 e) =>
      <String, dynamic>{...e.toJson(), '_evidence315': e.id};

  List<Map<String, dynamic>> _groups(
      Iterable<ResearchEvidence11> evidence, bool family) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in evidence) {
      groups
          .putIfAbsent(family ? e.sourceFamily : e.provider, () => [])
          .add(_evidenceRow(e));
    }
    return groups.entries
        .map((e) => <String, dynamic>{
              'titolo': e.key,
              'nota': '${e.value.length} osservazioni registrate',
              'avvertenza': family
                  ? 'Famiglia assegnata dal software; un DOI diverso non dimostra da solo indipendenza scientifica.'
                  : 'Provider = canale di recupero, non necessariamente fonte indipendente.',
              'Evidenze associate': e.value,
            })
        .toList();
  }

  static const counted321 = {
    'Documentate',
    'Corroborate web',
    'Osservate',
    'Quarantena',
    'Evidenze',
    'Provider con evidenza',
    'Famiglie con evidenza',
    'Documenti registrati',
    'Documenti da leggere',
    'Testi da elaborare',
    'Testi non interpretati',
    'Episodi relazionali',
    'Fatti cognitivi',
    'Concetti relazionali',
    'Concetti narrativi',
    'Legami narrativi',
    'Archi mondo',
    'Prior deboli',
    'Pre-attivi',
    'Archi attivi',
    'Token',
    'Archi lingua',
    'Macro-nodi',
    'Vocabolario',
    'Archi unici',
    'Conoscenze documentate',
    'Conoscenze corroborate',
    'Forme linguistiche',
    'Relazioni richiamate',
  };
  String? metricValue321(String label, {bool session = false}) {
    if (session) {
      final s = research.lastSession;
      if (s == null) return '0';
      if (s.audit315.isEmpty) return null;
      return '${sessionRows(s, label).length}';
    }
    // Counting must not serialize thousands of records while a card builds.
    // Full records are materialized only when the user opens the inspector.
    final int? count = switch (label) {
      'Documentate' ||
      'Conoscenze documentate' =>
        research.claims.values.where((c) => c.status == 'documentata').length,
      'Corroborate web' ||
      'Conoscenze corroborate' =>
        research.claims.values.where((c) => c.status == 'accettata').length,
      'Osservate' =>
        research.claims.values.where((c) => c.status == 'ipotesi_mgd').length,
      'Quarantena' =>
        research.claims.values.where((c) => c.status == 'quarantena').length,
      'Evidenze' => research.evidence.length,
      'Provider con evidenza' =>
        research.evidence.map((e) => e.provider).toSet().length,
      'Famiglie con evidenza' =>
        research.evidence.map((e) => e.sourceFamily).toSet().length,
      'Documenti da leggere' => ResearchSemantics317.getPending(research),
      'Testi da elaborare' => research.pendingPassages321.length,
      'Testi non interpretati' => research.uninterpretedPassages321.length,
      'Episodi relazionali' => brain.episodes.length,
      'Fatti cognitivi' => brain.cognitiveFacts06().length,
      'Concetti relazionali' => brain.concepts.length,
      'Concetti narrativi' =>
        research.emergentConcepts.values.where((c) => c.crystallized).length,
      'Legami narrativi' => research.narrativeLinks.length,
      'Archi mondo' => world.edges.length,
      'Archi attivi' => world.edges.values
          .where((e) => e.cost <= MgdMath09.defaults.epsilon)
          .length,
      'Pre-attivi' => world.edges.values
          .where((e) =>
              e.cost > MgdMath09.defaults.epsilon &&
              e.cost <= MgdMath09.defaults.epsilon + .035 &&
              e.uses >= 2)
          .length,
      'Prior deboli' => world.edges.values
          .where((e) =>
              e.cost > MgdMath09.defaults.epsilon &&
              !(e.cost <= MgdMath09.defaults.epsilon + .035 && e.uses >= 2))
          .length,
      'Token' || 'Vocabolario' => language.tokenCount.length,
      'Archi lingua' || 'Archi unici' => language.edges.length,
      'Macro-nodi' => language.chunks.values.where((c) => c.count >= 4).length,
      'Relazioni richiamate' => world.thoughts.length,
      'Forme linguistiche' =>
        language.frames320.values.fold<int>(0, (n, f) => n + f.length),
      _ => null,
    };
    if (count != null) return '$count';
    if (counted321.contains(label)) return '${metricRows(label).length}';
    return switch (label) {
      'Cicli MGD' => '${world.thoughtCycles}',
      'Frasi viste' => '${language.sentences}',
      'Token visti' => '${language.stats().tokenOccurrences}',
      'Passaggi' => '${language.stats().edgeUses}',
      'Materia media' => language.stats().meanMaterial.toStringAsFixed(3),
      'κ medio' => world.edges.values.any((e) =>
              e.curvatureMeasured320 && e.cost <= MgdMath09.defaults.epsilon)
          ? world.stats().meanCurvature.toStringAsFixed(3)
          : 'Non misurata',
      'Ricerche avviate oggi' => '${research.requestsToday321}',
      _ => null,
    };
  }

  List<Map<String, dynamic>> metricRows(String label) {
    switch (label) {
      case 'Stato motore':
        return [
          {
            'titolo': 'Motore e ripristino 0.32.1',
            ...world.runtime319,
            'cicli conservati': world.thoughtCycles,
            'archi geometrici': world.edges.length,
            'archi attivi': world.stats().activeEdges,
            'eta entropica': world.entropicAge,
            'nota':
                'I ripassi cambiano la geometria, non il numero di fonti o lo stato delle conoscenze.'
          }
        ];
      case 'Diagnostica ricerca':
        return research.lastSession == null
            ? []
            : [
                {
                  'titolo':
                      '${research.lastSession!.topic}: acquisizione e interpretazione',
                  'documenti acquisiti': research.lastSession!.documents,
                  'frasi lette': research.lastSession!.sentencesRead,
                  'proposizioni': research.lastSession!.candidates,
                  'Esiti provider':
                      research.lastSession!.audit315['providerDiagnostics'] ??
                          [],
                  'nota':
                      research.lastSession!.audit315['extractionNote'] ?? '',
                  'ultimo errore': research.lastError ?? '',
                  'Documenti': research.lastSession!.audit315['documents'] ?? []
                }
              ];
      case 'Recupero testi 0.31.8':
        return [
          _map315(research.state317['recovery318'] ??
              {'nota': 'Nessun testo precedente da rileggere.'})
        ];
      case 'Conoscenze documentate':
      case 'Documentate':
        return research.claims.values
            .where((c) => c.status == 'documentata')
            .map(_claimRow)
            .toList();
      case 'Documenti da leggere':
      case 'Coda di verifica':
        return (research.state317['queue'] as List? ?? [])
            .map(_map315)
            .toList();
      case 'Frasi web lingua':
        return language.webSeen317.values.map(_map315).toList();
      case 'Riesame 0.31.7':
        return research.claims.values
            .where((c) => c.meta317.containsKey('before317'))
            .map(_claimRow)
            .toList();
      case 'Conoscenze corroborate':
      case 'Corroborate web':
      case 'Consolidate web':
        return research.claims.values
            .where((c) => c.status == 'accettata')
            .map(_claimRow)
            .toList();
      case 'Osservate':
      case 'Ipotesi MGD':
        return research.claims.values
            .where((c) => c.status == 'ipotesi_mgd')
            .map(_claimRow)
            .toList();
      case 'Quarantena':
        return research.claims.values
            .where((c) => c.status == 'quarantena')
            .map(_claimRow)
            .toList();
      case 'Conflitti':
        return research.claims.values
            .where((c) => c.conflict)
            .map(_claimRow)
            .toList();
      case 'Evidenze':
        return research.evidence.reversed.map(_evidenceRow).toList();
      case 'Provider con evidenza':
      case 'Provider visti':
        return _groups(research.evidence, false);
      case 'Famiglie con evidenza':
        return _groups(research.evidence, true);
      case 'Testi da elaborare':
        return research.pendingPassages321.map((p) => p.toJson()).toList();
      case 'Testi non interpretati':
        return research.uninterpretedPassages321
            .map((p) => <String, dynamic>{
                  ...p.toJson(),
                  'nota':
                      'Testo conservato, senza proposizione strutturata riconosciuta. Nuovo tentativo quando cambia il lettore.'
                })
            .toList();
      case 'Testi in attesa':
        return research.passages
            .where((p) => !p.structured)
            .map((p) => <String, dynamic>{
                  ...p.toJson(),
                  'nota':
                      'In attesa di estrazione/consolidamento strutturato. Non significa necessariamente che il testo non sia entrato nella memoria narrativa.'
                })
            .toList();
      case 'Ricerche avviate oggi':
        return [
          {
            'titolo': 'Richieste avviate oggi',
            'valore': research.requestsToday321,
            'nota':
                'Include richieste in corso o fallite. Una query ripetuta può avviare più richieste.',
            'ultime query': research.queryLastIso,
          }
        ];
      case 'Ricerche oggi':
      case 'Tutte le ricerche':
        final now = DateTime.now();
        return research.sessions.reversed
            .where((s) {
              if (label == 'Tutte le ricerche') return true;
              final t = DateTime.tryParse(s.startedAtIso)?.toLocal();
              return t != null &&
                  t.year == now.year &&
                  t.month == now.month &&
                  t.day == now.day;
            })
            .map((s) => <String, dynamic>{...s.toJson(), '_session315': true})
            .toList();
      case 'Documenti registrati':
        return ResearchSemantics317.uniqueDocuments320(research);
      case 'Tentativi di verifica':
        return research.sessions.reversed
            .expand((s) => _maps315(s.audit315['verification']))
            .toList();
      case 'Entità':
        return brain.entities.map((x) => x.toJson()).toList();
      case 'Fatti':
        return brain
            .editableFacts12()
            .map((x) => <String, dynamic>{
                  'subject': x.subject,
                  'relation': x.relation,
                  'object': x.object,
                  'confidence': x.confidence,
                  'subjectId': x.subjectId,
                  'relationId': x.relationId
                })
            .toList();
      case 'Fatti cognitivi':
        return brain
            .cognitiveFacts06()
            .map((x) => <String, dynamic>{
                  'subject': nodeLabel('e:${x.subjectId}'),
                  'relation': x.relation,
                  'object': x.object,
                  'confidence': x.confidence,
                  'subjectId': x.subjectId,
                  'relationId': x.relationId,
                  'objectEntityId': x.objectEntityId
                })
            .toList();
      case 'Episodi':
      case 'Episodi relazionali':
        return brain.episodes.reversed.map((x) => x.toJson()).toList();
      case 'Concetti':
      case 'Concetti relazionali':
        return brain.concepts.map((x) => x.toJson()).toList();
      case 'Episodica web':
        return research.narrativeEpisodes.reversed
            .map((x) => x.toJson())
            .toList();
      case 'Tutti i cluster':
        return research.emergentConcepts.values.map((x) => x.toJson()).toList();
      case 'Concetti narrativi':
        return research.emergentConcepts.values
            .where((x) => x.crystallized)
            .map((x) => x.toJson())
            .toList();
      case 'Legami narrativi':
        return research.narrativeLinks.map((x) => x.toJson()).toList();
      case 'Termini narrativi':
        return research.termMemory.values.map((x) => x.toJson()).toList();
      case 'Archi mondo':
      case 'Legami mondo':
      case 'Prior deboli':
      case 'Pre-attivi':
      case 'Archi attivi':
        final eps = MgdMath09.defaults.epsilon;
        return world.edges.values
            .where((e) {
              if (label == 'Archi attivi') return e.cost <= eps;
              if (label == 'Prior deboli')
                return e.cost > eps && !(e.cost <= eps + 0.035 && e.uses >= 2);
              if (label == 'Pre-attivi')
                return e.cost > eps && e.cost <= eps + 0.035 && e.uses >= 2;
              return true;
            })
            .map(edgeRecord)
            .toList();
      case 'Cicli MGD':
        return [
          {
            'titolo': 'Cicli eseguiti',
            'valore': world.thoughtCycles,
            'nota':
                'Passi di propagazione nel grafo, non numero di nuove deduzioni.',
            'Richiami conservati':
                world.thoughts.reversed.map((x) => x.toJson()).toList()
          }
        ];
      case 'Relazioni richiamate':
      case 'Passi mentali':
        return world.thoughts.reversed.map((x) => x.toJson()).toList();
      case 'Età τ':
      case 'Età mondo τ':
        return [
          {
            'titolo': 'Età entropica, non età cronologica',
            'valore': world.entropicAge,
            'ultimo flusso': world.lastEntropicFlux09,
            'passi': world.thoughtCycles,
            'nota':
                'Misura aggregata della dinamica. Non conta conoscenze né documenti.'
          }
        ];
      case 'κ medio':
        return [
          {
            'titolo': 'Curvatura: valori e definizione del contatore',
            'valore': world.stats().meanCurvature,
            'nota':
                'Media degli archi attivi misurati, inclusi gli zeri. Misure uniformi troncate a 12 nodi per vicinato: stima locale, aggiornata a lotti. Gli archi non ancora misurati sono esclusi.',
            'Archi e curvature': world.edges.values.map(edgeRecord).toList()
          }
        ];
      case 'Visione':
      case 'Pattern visivi':
        return world.prototypes
            .where((p) => p.modality == 'vision')
            .map((p) => p.toJson())
            .toList();
      case 'Udito':
      case 'Pattern uditivi':
        return world.prototypes
            .where((p) => p.modality == 'audio')
            .map((p) => p.toJson())
            .toList();
      case 'Binding':
        return world.prototypes
            .where((p) => p.semanticEntityId != null)
            .map((p) => <String, dynamic>{
                  ...p.toJson(),
                  'entità collegata': nodeLabel('e:${p.semanticEntityId}')
                })
            .toList();
      case 'Osservazioni sensoriali':
        return world.observations.reversed.map((x) => x.toJson()).toList();
      case 'Sensi lessicali':
        return brain.lexicalSenses028.values
            .expand((x) => x)
            .map((x) => x.toJson())
            .toList();
      case 'Variazioni di risposta':
        return brain.responseAttractors028.values
            .map((x) => x.toJson())
            .toList();
      case 'Memoria di lavoro':
        return brain.workingMemory
            .map((id) => brain.assemblies[id].toJson())
            .toList();
      case 'Vocabolario':
      case 'Token':
        return language.tokenCount.entries
            .map((e) =>
                <String, dynamic>{'titolo': e.key, 'occorrenze': e.value})
            .toList();
      case 'Archi unici':
      case 'Archi lingua':
        return language.edges.values.map((x) => x.toJson()).toList();
      case 'Macro-nodi':
        return language.chunks.values
            .where((c) => c.count >= 4)
            .map((x) => x.toJson())
            .toList();
      case 'Frasi viste':
        return [
          {
            'titolo': 'Frasi viste dal modulo linguistico',
            'contatore': language.sentences,
            'caratteri': language.characters,
            'nota':
                'Questo modulo conserva un contatore e strutture apprese, non un archivio integrale delle frasi. Gli episodi web sono in una memoria distinta.',
            'Macro-sequenze conservate':
                language.chunks.values.map((x) => x.toJson()).toList()
          }
        ];
      case 'Token visti':
        return [
          {
            'titolo': 'Occorrenze dei token',
            'valore': language.stats().tokenOccurrences,
            'Token': metricRows('Token')
          }
        ];
      case 'Passaggi':
        return [
          {
            'titolo': 'Usi delle transizioni',
            'valore': language.stats().edgeUses,
            'Archi': metricRows('Archi lingua')
          }
        ];
      case 'Materia media':
        return [
          {
            'titolo': 'Media della materia sugli archi linguistici',
            'valore': language.stats().meanMaterial,
            'Archi': metricRows('Archi lingua')
          }
        ];
      case 'Forme linguistiche':
        return language.frames320.entries
            .expand((e) => e.value.entries.map((f) => <String, dynamic>{
                  'titolo': f.key,
                  'relazione e numero': e.key,
                  'osservazioni': f.value
                }))
            .toList();
      case 'Ultimo apprendimento':
        return [
          Map<String, dynamic>.from(
              world.runtime319['lastLearning321'] as Map? ??
                  {'nota': 'Nessuna lettura misurata in questa versione.'})
        ];
      case 'Limite giornaliero':
        return [
          {
            'titolo': 'Nessun limite giornaliero',
            'nota':
                'Le richieste sullo stesso argomento possono comunque essere soggette a un intervallo di attesa.',
            'ricerche avviate': research.requestsToday,
            'ultime query': research.queryLastIso
          }
        ];
      default:
        return [
          {
            'titolo': label,
            'nota':
                'Dettaglio aggregato. Apri Esplora tutta la memoria per i singoli archivi.'
          }
        ];
    }
  }

  Future<void> openMetric(BuildContext context, String label,
      {bool session = false, String? value}) async {
    if (label == 'Esporta backup pre-0.31.7' ||
        label == 'Esporta backup pre-0.31.8') {
      final is318 = label.endsWith('0.31.8');
      final backup = await MgdStateStore26.instance
          .getMap(is318 ? 'before_research318' : 'before_research317');
      if (!context.mounted) return;
      if (backup == null) {
        await _list(context, label, () => [],
            note: 'Nessun backup di migrazione disponibile.');
        return;
      }
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(
          {'format': 'mgd-neuro-snapshot-v1', 'version': 317, ...backup})));
      await FilePicker.platform.saveFile(
          dialogTitle: label,
          fileName: is318
              ? 'MGD-backup-pre-0318.mgdbrain'
              : 'MGD-backup-pre-0317.mgdbrain',
          bytes: bytes);
      return;
    }
    if (session) {
      final s = research.lastSession;
      if (s == null) {
        await _list(context, label, () => [],
            note: 'Nessuna sessione disponibile.');
        return;
      }
      await _list(
          context, 'Ultimo studio · $label', () => sessionRows(s, label),
          note: s.audit315.isEmpty
              ? 'Sessione precedente alla 0.31.5: erano salvati i totali, non tutti gli elementi. Il dettaglio storico mancante non può essere ricostruito. Le nuove ricerche lo registrano.'
              : 'Risultati della sessione «${s.topic}». Gli esiti contano le valutazioni nella sessione; l’archivio globale conta le proposizioni uniche.');
      return;
    }
    await _list(context, label, () => metricRows(label),
        note: label == 'Passi mentali'
            ? '$value cicli totali; qui sono mostrati soltanto i pensieri ancora conservati, non ogni singolo ciclo.'
            : label == 'Ricerche oggi'
                ? 'Le richieste avviate ($value) possono superare le sessioni completate e conservate.'
                : label == 'Documenti registrati' ||
                        label == 'Tentativi di verifica'
                    ? 'Tracce complete delle ultime 8 sessioni dalla 0.31.5. I riepiloghi precedenti restano disponibili.'
                    : 'Elenco fotografato all’apertura. Usa Aggiorna per rileggere lo stato; tocca una voce per il dettaglio.');
  }

  List<Map<String, dynamic>> sessionRows(ResearchSession11 s, String label) {
    final a = s.audit315;
    if (a.isEmpty)
      return [
        {
          'titolo': 'Dettaglio storico non registrato',
          'nota':
              'Totali disponibili, elenco completo assente nelle vecchie versioni.',
          'riepilogo': s.toJson()
        }
      ];
    final docs = _maps315(a['documents']);
    final decisions = _maps315(a['decisions']);
    switch (label) {
      case 'Documenti':
        return docs;
      case 'Provider':
      case 'Famiglie':
        final key = label == 'Provider' ? 'provider' : 'family';
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final d in docs) {
          groups.putIfAbsent('${d[key]}', () => []).add(d);
        }
        return groups.entries
            .map((e) => <String, dynamic>{
                  'titolo': e.key,
                  'nota':
                      '${e.value.length} documenti; non sono conferme della stessa proposizione.',
                  'Documenti': e.value
                })
            .toList();
      case 'Frasi lette':
        return _maps315(a['sentences']);
      case 'Candidati':
        return decisions;
      case 'Proposizioni nuove':
        return decisions.where((d) => d['newClaim321'] == true).toList();
      case 'Già note':
        return decisions.where((d) => d['newClaim321'] != true).toList();
      case 'Nuove evidenze':
        final ids = decisions
            .expand((d) => d['newEvidenceIds321'] as List? ?? [])
            .toSet();
        return research.evidence
            .where((e) => ids.contains(e.id))
            .map(_evidenceRow)
            .toList();
      case 'Documentate':
        return decisions.where((d) => d['status'] == 'documentata').toList();
      case 'Osservate':
        return decisions.where((d) => d['status'] == 'ipotesi_mgd').toList();
      case 'Corroborate web':
      case 'Corroborate':
      case 'Consolidati':
        return decisions.where((d) => d['status'] == 'accettata').toList();
      case 'Ipotesi MGD':
        return decisions.where((d) => d['status'] == 'ipotesi_mgd').toList();
      case 'Quarantena':
        return decisions.where((d) => d['status'] == 'quarantena').toList();
      case 'Conflitti':
        return decisions.where((d) => d['conflict'] == true).toList();
      default:
        return [s.toJson()];
    }
  }

  Future<void> openClaim(BuildContext context, String key) async {
    final c = research.claims[key];
    if (c == null) {
      await _record(
          context, {'titolo': 'Proposizione non più disponibile', 'key': key});
      return;
    }
    final evidence =
        research.evidence.where((e) => c.evidenceIds.contains(e.id)).toList();
    final documents = evidence
        .map((e) => e.sourceUrl.isEmpty
            ? '${e.sourceFamily}|${e.sourceTitle}'
            : e.sourceUrl)
        .toSet();
    final sid = brain.entityIdForLabel06(c.subject);
    final oid = brain.entityIdForLabel06(c.object);
    final links = world.edges.values
        .where((e) =>
            sid != null &&
            oid != null &&
            ((e.a == 'e:$sid' && e.b == 'e:$oid') ||
                (e.b == 'e:$sid' && e.a == 'e:$oid')))
        .map(edgeRecord)
        .toList();
    final decisions = research.sessions.reversed
        .expand((s) => _maps315(s.audit315['decisions']))
        .where((d) => d['claimKey'] == key)
        .toList();
    final attempts = research.sessions.reversed
        .expand((s) => _maps315(s.audit315['verification']))
        .where((d) => d['claimKey'] == key)
        .toList();
    await _record(context, {
      'titolo': _title315(c.toJson()),
      'status': c.status,
      'Come interpretare lo stato':
          'DOCUMENTATA: supporto diretto riconosciuto da almeno una fonte. CORROBORATA: più gruppi di provenienza, non certificazione scientifica. OSSERVATA: contenuto conservato, non prova. Il punteggio non è una probabilità.',
      'Verifiche del consolidatore':
          WebKnowledgeExplorer11.inspectionGates315(c),
      'Punteggio euristico': c.confidence,
      'Osservazioni registrate': c.evidenceCount,
      'Documenti distinti rintracciabili': documents.length,
      'Famiglie assegnate': c.sourceFamilies.toList(),
      'Provider': c.sourceProviders.toList(),
      'Evidenze associate': evidence.map(_evidenceRow).toList(),
      'ID evidenze non più disponibili':
          c.evidenceIds.difference(evidence.map((e) => e.id).toSet()).toList(),
      'Archi geometrici con gli stessi estremi': links,
      'Avvertenza archi':
          'La ricerca usa gli ID risolti dalle etichette; sensi lessicali separati possono avere altri ID. Più relazioni possono condividere gli stessi estremi.',
      'Esiti registrati dalla 0.31.5': decisions,
      'Tentativi fonte per fonte dalla 0.31.5': attempts,
      'Dati della proposizione': c.toJson(),
    });
  }

  Future<void> _openItem(BuildContext context, Map<String, dynamic> m) async {
    if (m['_metric315'] != null) {
      await openMetric(context, '${m['_metric315']}');
      return;
    }
    if (m['_claim315'] != null) {
      await openClaim(context, '${m['_claim315']}');
      return;
    }
    if (m['_session315'] == true) {
      await _record(context, {
        ...m,
        'nota':
            'Apri audit315 per documenti, frasi, candidati, esiti e tentativi. Un audit vuoto indica una sessione storica senza dettagli.'
      });
      return;
    }
    if (m['_evidence315'] != null) {
      final claims = research.claims.values
          .where((c) => c.evidenceIds.contains('${m['_evidence315']}'))
          .map(_claimRow)
          .toList();
      await _record(context, {
        ...m,
        'nota':
            'Osservazione registrata dal software; può essere una rilettura dello stesso documento.',
        'Proposizioni collegate': claims
      });
      return;
    }
    if (m['claimKey'] != null) {
      await _record(context, {
        ...m,
        'Proposizione attuale': [
          {'titolo': _title315(m), '_claim315': m['claimKey']}
        ]
      });
      return;
    }
    await _record(context, m);
  }

  Future<void> _list(BuildContext context, String title,
      List<Map<String, dynamic>> Function() load,
      {String note = ''}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => InspectorList315(
            title: title, load: load, note: note, onOpen: _openItem)));
  }

  Future<void> _record(BuildContext context, Map<String, dynamic> data) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => InspectorRecord315(
            data: data,
            onNested: (ctx, title, value) {
              if (value is Map)
                return _record(ctx, {'titolo': title, ..._map315(value)});
              final rows = value is List
                  ? value.map(_map315).toList()
                  : [_map315(value)];
              return _list(ctx, title, () => rows);
            })));
  }
}

Future<void> _export315(BuildContext context, Object data) async {
  try {
    final text = await compute(_json315, data);
    if (!context.mounted) return;
    final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Esporta i dati visibili',
        fileName: 'MGD-ispezione-${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: Uint8List.fromList(utf8.encode(text)));
    if (context.mounted && path != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Esportazione salvata.')));
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Esportazione non riuscita: $e')));
  }
}

class InspectorList315 extends StatefulWidget {
  final String title, note;
  final List<Map<String, dynamic>> Function() load;
  final Future<void> Function(BuildContext, Map<String, dynamic>) onOpen;
  const InspectorList315(
      {super.key,
      required this.title,
      required this.load,
      required this.onOpen,
      this.note = ''});
  @override
  State<InspectorList315> createState() => _InspectorListState315();
}

class _InspectorListState315 extends State<InspectorList315> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [], _filtered = [];
  int _page = 0;
  String? _error;
  bool _loading = true;
  static const pageSize = 50;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    try {
      final rows = widget.load();
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
      _filter();
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _page = 0;
      _filtered = q.isEmpty
          ? _rows
          : _rows.where((r) => r.toString().toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _page * pageSize;
    final end = min(start + pageSize, _filtered.length);
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          IconButton(
              tooltip: 'Aggiorna',
              onPressed: _reload,
              icon: const Icon(Icons.refresh)),
          IconButton(
              tooltip: 'Esporta elenco filtrato',
              onPressed: _loading
                  ? null
                  : () => _export315(context,
                      {'categoria': widget.title, 'elementi': _filtered}),
              icon: const Icon(Icons.download)),
        ]),
        body: SafeArea(
            child: Column(children: [
          if (widget.note.isNotEmpty)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.note,
                    style: Theme.of(context).textTheme.bodySmall)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                  controller: _search,
                  onChanged: (_) => _filter(),
                  decoration: const InputDecoration(
                      labelText: 'Cerca nel contenuto',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder()))),
          Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                  '${_filtered.length} elementi · ${_rows.length} totali')),
          Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: SelectableText('Errore di lettura: $_error'))
                      : _filtered.isEmpty
                          ? const Center(
                              child:
                                  Text('Nessun elemento in questa categoria.'))
                          : ListView.builder(
                              itemCount: end - start,
                              itemBuilder: (ctx, i) {
                                final row = _filtered[start + i];
                                return ListTile(
                                  title: Text(_title315(row),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(_subtitle315(row),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => widget.onOpen(ctx, row),
                                );
                              })),
          if (_filtered.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  tooltip: 'Pagina precedente',
                  onPressed: _page == 0 ? null : () => setState(() => _page--),
                  icon: const Icon(Icons.chevron_left)),
              Text('${start + 1}–$end di ${_filtered.length}'),
              IconButton(
                  tooltip: 'Pagina successiva',
                  onPressed: end >= _filtered.length
                      ? null
                      : () => setState(() => _page++),
                  icon: const Icon(Icons.chevron_right)),
            ]),
        ])));
  }
}

class InspectorRecord315 extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(BuildContext, String, Object?) onNested;
  const InspectorRecord315(
      {super.key, required this.data, required this.onNested});
  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    try {
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          uri.host.isEmpty)
        throw const FormatException('URL HTTP/HTTPS non valido');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw StateError('Nessun browser disponibile');
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossibile aprire la fonte: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => !e.key.startsWith('_')).toList();
    return Scaffold(
        appBar: AppBar(title: const Text('Dettaglio'), actions: [
          IconButton(
              tooltip: 'Copia dettaglio',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _json315(data)));
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dettaglio copiato.')));
              },
              icon: const Icon(Icons.copy)),
          IconButton(
              tooltip: 'Esporta dettaglio',
              onPressed: () => _export315(context, data),
              icon: const Icon(Icons.download)),
        ]),
        body: SafeArea(
            child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: entries.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0)
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SelectableText(_title315(data),
                            style: Theme.of(ctx).textTheme.titleLarge));
                  final e = entries[i - 1];
                  final value = e.value;
                  if (value is Map || value is List) {
                    final count =
                        value is Map ? value.length : (value as List).length;
                    return Card(
                        child: ListTile(
                            title: Text(e.key),
                            subtitle: Text('$count elementi'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => onNested(ctx, e.key, value)));
                  }
                  final text = value == null
                      ? 'Non registrato'
                      : value is bool
                          ? (value ? 'Sì' : 'No')
                          : '$value';
                  final uri = Uri.tryParse(text);
                  final isUrl = uri != null &&
                      ['http', 'https'].contains(uri.scheme) &&
                      uri.host.isNotEmpty;
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key,
                                style: Theme.of(ctx).textTheme.labelLarge),
                            const SizedBox(height: 4),
                            SelectableText(
                                e.key == 'status' ? _status315(value) : text),
                            if (isUrl)
                              TextButton.icon(
                                  onPressed: () => _openUrl(ctx, text),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Apri fonte originale')),
                          ]));
                })));
  }
}
