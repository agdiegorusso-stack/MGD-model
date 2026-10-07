import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import 'cognitive_induction_v024.dart';
import 'mgd_language_v020.dart';
import 'mgd_state_store_v026.dart';
import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';

const memoryKeys425 = ['brain_v051', 'world_v06', 'research_v11', 'language_v20'];
const memoryNames425 = ['memoria relazionale', 'mondo', 'ricerca', 'lingua'];

class LoadedMemory425 {
  final PlasticLanguageBrain04 brain;
  final MgdWorld06 world;
  final ResearchMemory11 research;
  final MgdLanguage20 language;
  final bool existed, migrated, conceptMigration;
  final int semanticRepairs;
  final bool languageBootstrapped425;
  int elapsedMs425 = 0, maxUiGapMs425 = 0;
  LoadedMemory425(this.brain, this.world, this.research, this.language,
      {required this.existed, required this.migrated,
      required this.conceptMigration, required this.semanticRepairs,
      required this.languageBootstrapped425});
}

Map<String, dynamic>? _oldMap425(String documents, List<String> names,
    {bool compressed = true}) {
  Object? lastError;
  for (final name in names) {
    for (final suffix in ['', '.bak']) {
      final file = File('$documents/$name$suffix');
      if (!file.existsSync()) continue;
      try {
        final bytes = file.readAsBytesSync();
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(
            compressed ? gzip.decode(bytes) : bytes)) as Map);
      } catch (e) { lastError = e; }
    }
  }
  if (lastError != null) throw FormatException('Archivio precedente illeggibile: $lastError');
  return null;
}

/// This whole function runs in a worker. It returns live models by isolate exit,
/// rather than returning a huge map for the UI to reconstruct again.
LoadedMemory425 restoreMemoryFiles425(Map<String, String> files,
    String documents, {SendPort? progress}) {
  Map<String, dynamic>? read(String key) {
    final path = files[key];
    if (path == null) return null;
    return decodeSnapshot425(File(path).readAsBytesSync());
  }
  void phase(String text) => progress?.send(text);
  phase('Ricostruisco la memoria relazionale…');
  var brainMap = read('brain_v051');
  var migrated = false;
  PlasticLanguageBrain04 brain;
  if (brainMap != null) {
    if (![4, 5, 6, 7, 8].contains(brainMap['version'])) {
      throw const FormatException('Versione della memoria relazionale non supportata.');
    }
    brain = PlasticLanguageBrain04.fromJson(brainMap);
  } else {
    brainMap = _oldMap425(documents, ['mgd_neuro_brain_v051.json.gz']);
    if (brainMap == null) {
      brainMap = _oldMap425(documents,
          ['mgd_neuro_brain_v05.json.gz', 'mgd_neuro_brain_v04.json.gz']);
      migrated = brainMap != null;
    }
    if (brainMap != null) {
      brain = PlasticLanguageBrain04.fromJson(brainMap);
    } else {
      brainMap = _oldMap425(documents, ['mgd_neuro_brain_v03.json.gz']);
      migrated = brainMap != null;
      brain = brainMap == null ? PlasticLanguageBrain04()
          : PlasticLanguageBrain04.migrateFromV03(brainMap);
    }
  }
  final existed = brainMap != null;
  brainMap = null;
  phase('Ricostruisco il mondo…');
  final worldMap = read('world_v06') ?? _oldMap425(documents, ['mgd_neuro_world_v06.json.gz']);
  final world = worldMap == null ? MgdWorld06() : MgdWorld06.fromJson(worldMap);
  phase('Ricostruisco la memoria di ricerca…');
  final researchMap = read('research_v11') ?? _oldMap425(documents, ['mgd_neuro_research_v11.json.gz']);
  final research = researchMap == null ? ResearchMemory11() : ResearchMemory11.fromJson(researchMap);
  // Legacy v10 only contains configuration, not the current v11 claim memory.
  if (researchMap == null) {
    final old = _oldMap425(documents, ['mgd_neuro_research_v10.json.gz']);
    if (old != null) {
      research.enabled = old['enabled'] != false;
      research.dailyBudget = (old['dailyBudget'] as num?)?.toInt() ?? 0;
      research.requestsToday = (old['requestsToday'] as num?)?.toInt() ?? 0;
      research.dayKey = (old['dayKey'] ?? '').toString();
      research.lastResearchAtIso = old['lastResearchAtIso'] as String?;
      research.lastGoal = old['lastGoal'] as String?;
    }
  }
  phase('Ricostruisco la lingua…');
  final languageMap = read('language_v20') ?? _oldMap425(documents,
      ['mgd_language20.json'], compressed: false);
  final language = languageMap == null ? MgdLanguage20() : MgdLanguage20.fromJson(languageMap);
  phase('Verifico i collegamenti appresi…');
  final repairs = brain.repairSemanticCorrections0252();
  world.repairPendingCuriosity316(brain);
  final conceptMigration = research.termMemory.isNotEmpty &&
      (research.emergentConcepts.isEmpty || research.emergentConcepts.values.any((c) => c.quality <= 0));
  if (conceptMigration) {
    phase('Ricostruisco i concetti…');
    CognitiveInduction24.recrystallize(research);
  }
  if (migrated) {
    phase('Verifico la memoria precedente…');
    world.repairNaturalBindings071(brain);
    world.repairIdentityAliases081(brain);
    brain.repairTeacherFacts082();
    world.repairCurrentUserFromHistory091(brain);
    world.dedupeThoughts011();
  }
  phase('Preparo la lingua appresa…');
  final languageWasEmpty = language.sentences == 0;
  language.bootstrapFromBrain(brain, onProgress425: (done, total) {
    phase('Preparo la lingua appresa: $done/$total episodi');
  });
  return LoadedMemory425(brain, world, research, language,
      existed: existed, migrated: migrated, conceptMigration: conceptMigration,
      semanticRepairs: repairs,
      languageBootstrapped425: languageWasEmpty && language.sentences > 0);
}

class MemoryBoot425 {
  static Future<LoadedMemory425> load({void Function(String)? onStage}) async {
    final clock = Stopwatch()..start();
    var previous = DateTime.now(), maxGap = 0;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 32), (_) {
      final now = DateTime.now(), gap = now.difference(previous).inMilliseconds;
      if (gap > maxGap) maxGap = gap;
      previous = now;
    });
    SnapshotFiles425? snapshots;
    ReceivePort? updates;
    StreamSubscription<dynamic>? subscription;
    try {
    onStage?.call('Apro la memoria salvata…');
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    snapshots = await MgdStateStore26.instance.exportForRestore425(
      memoryKeys425, onProgress: (key, read, total) {
        final now = DateTime.now();
        if (read == total || now.difference(last).inMilliseconds >= 200) {
          last = now;
          final name = memoryNames425[memoryKeys425.indexOf(key)];
          onStage?.call('Leggo $name: ${(100 * read / total).round()}%');
        }
      });
    updates = ReceivePort();
    subscription = updates.listen((message) => onStage?.call(message as String));
      final documents = (await getApplicationDocumentsDirectory()).path;
      final files = snapshots.files, port = updates.sendPort;
      final restored = await _restoreWorker425(files, documents, port);
      restored.elapsedMs425 = clock.elapsedMilliseconds;
      final tail = DateTime.now().difference(previous).inMilliseconds;
      restored.maxUiGapMs425 = tail > maxGap ? tail : maxGap;
      return restored;
    } finally {
      heartbeat.cancel();
      await subscription?.cancel();
      updates?.close();
      await snapshots?.dispose();
    }
  }
}

// Keep the spawned closure in a small scope containing only worker input;
// it must not capture the UI's callbacks, subscriptions or heartbeat timer.
Future<LoadedMemory425> _restoreWorker425(Map<String, String> files,
    String documents, SendPort port) => Isolate.run(
        () => restoreMemoryFiles425(files, documents, progress: port));
