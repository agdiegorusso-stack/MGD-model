import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'mgd_language_v020.dart';
import 'mgd_state_store_v026.dart';

const mgdAppVersion319 = '0.32.1';

/// Rehearsal changes graph familiarity, NEVER evidence or factual confidence.
/// It only replays externally experienced/confirmed facts, not generated thoughts.
class MemoryRuntime319 {
  static Future<({Map<String, dynamic> world, List<Concept04> concepts})>
      compute320(PlasticLanguageBrain04 brain, MgdWorld06 world,
              {int cycles = 2, String? seedText}) =>
          Isolate.run(() {
            pulse(brain, world, cycles: cycles, seedText: seedText);
            return (world: world.toJson(), concepts: brain.concepts);
          });
  static int pulse(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world, {
    int budget = 8,
    int cycles = 2,
    String? seedText,
  }) {
    final clock = Stopwatch()..start();
    final eligible = <({int subject, int object, String label})>[];
    for (final slot in brain.slots.values) {
      if (slot.subjectId < 0 || slot.subjectId >= brain.entities.length)
        continue;
      for (final c in slot.candidates.values) {
        final experienced =
            c.epistemicStatus == 'experienced' && c.sourceEpisodes.isNotEmpty;
        final sourced =
            c.epistemicStatus == 'consolidated' && c.sourceFamilies.isNotEmpty;
        if (!(experienced || sourced) ||
            c.confidence < .50 ||
            c.contradictions > 0) continue;
        final object = brain.entityIdForLabel06(c.display);
        if (object == null || object == slot.subjectId) continue;
        eligible.add((
          subject: slot.subjectId,
          object: object,
          label: brain.entities[slot.subjectId].label,
        ));
      }
    }
    final state = world.runtime319;
    var cursor = (state['replayCursor'] as num?)?.toInt() ?? 0;
    var replayed = 0;
    String? cue = seedText;
    final count = min(max(0, budget), eligible.length);
    for (var n = 0; n < count; n++) {
      final f = eligible[(cursor + n) % eligible.length];
      // Three bounded native transitions: no direct assignment to cost/epsilon.
      world.rehearseExternalFact319(f.subject, f.object);
      cue ??= f.label;
      replayed++;
    }
    if (eligible.isNotEmpty) cursor = (cursor + count) % eligible.length;
    state['replayCursor'] = cursor;
    state['eligibleFacts'] = eligible.length;
    state['lastReplayed'] = replayed;
    state['replayedTotal'] =
        ((state['replayedTotal'] as num?)?.toInt() ?? 0) + replayed;
    final conceptRevision = Object.hashAll(
      brain.slots.values.expand(
        (s) => s.candidates.values.map(
          (c) => Object.hash(
            s.subjectId,
            c.display,
            c.confidence,
            c.contradictions,
            c.epistemicStatus,
          ),
        ),
      ),
    );
    if (state['conceptRevision320'] != conceptRevision) {
      state['conceptRevision320'] = conceptRevision;
      brain.discoverConcepts();
      state['conceptSlots'] = brain.slots.length;
      state['conceptEntities'] = brain.entities.length;
    }
    world.think(brain, cycles: cycles, seedText: cue);
    world.maintainCurvature319();
    clock.stop();
    state['lastPulseAt'] = DateTime.now().toIso8601String();
    state['lastPulseMicros'] = clock.elapsedMicroseconds;
    state['state'] = 'attivo';
    state['note'] =
        'Ripasso geometrico di fatti già acquisiti. Non aggiunge fonti, conferme o nuove affermazioni.';
    return replayed;
  }
}

/// All four memories are captured together, then committed in one transaction.
/// Requests coalesce; a later request waits for the complete drain, not an old write.
class MemoryCheckpoint319 {
  Future<void>? _active;
  bool _pending = false;
  late PlasticLanguageBrain04 _brain;
  late MgdWorld06 _world;
  late ResearchMemory11 _research;
  late MgdLanguage20 _language;
  final Future<void> Function(Map<String, Map<String, dynamic>>) write;
  MemoryCheckpoint319({
    Future<void> Function(Map<String, Map<String, dynamic>>)? write,
  }) : write = write ?? MgdStateStore26.instance.putMapsAtomic319;

  Future<void> save(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory11 research,
    MgdLanguage20 language,
  ) {
    _brain = brain;
    _world = world;
    _research = research;
    _language = language;
    _pending = true;
    return _active ??= _drain().whenComplete(() => _active = null);
  }

  Future<void> _drain() async {
    while (_pending) {
      _pending = false;
      final brain = _brain,
          world = _world,
          research = _research,
          language = _language;
      final maps = await Isolate.run<Map<String, Map<String, dynamic>>>(
        () => {
          'brain_v051': brain.toJson(),
          'world_v06': world.toJson(),
          'research_v11': research.toJson(),
          'language_v20': language.toJson(),
          'checkpoint_v0319': {
            'version': mgdAppVersion319,
            'at': DateTime.now().toIso8601String(),
            'brainEpisodes': brain.episodes.length,
            'worldCycles': world.thoughtCycles,
            'worldEdges': world.edges.length,
            'worldAge': world.entropicAge,
            'claims': research.claims.length,
            'evidence': research.evidence.length,
            'languageSentences': language.sentences,
          },
        },
      );
      await write(maps);
    }
  }
}
