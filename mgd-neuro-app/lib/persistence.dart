import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'plastic_language_brain_v04.dart';
import 'mgd_state_store_v026.dart';

List<int> _encodeJsonMapGzip19(Map<String, dynamic> map) =>
    gzip.encode(utf8.encode(jsonEncode(map)));

Map<String, dynamic> _decodeJsonMapGzip19(List<int> bytes) =>
    Map<String, dynamic>.from(
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map,
    );

class Brain04Persistence {
  static const _fileName = 'mgd_neuro_brain_v051.json.gz';
  static const _oldV05FileName = 'mgd_neuro_brain_v05.json.gz';
  static const _oldV04FileName = 'mgd_neuro_brain_v04.json.gz';
  static const _oldV03FileName = 'mgd_neuro_brain_v03.json.gz';

  Future<void>? _activeSave19;
  bool _saveQueued19 = false;
  PlasticLanguageBrain04? _saveBrain19;

  Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }

  Future<void> save(PlasticLanguageBrain04 brain) {
    _saveBrain19 = brain;
    _saveQueued19 = true;
    return _activeSave19 ??= _drainSaves19().whenComplete(() {
      _activeSave19 = null;
      if (_saveQueued19 && _saveBrain19 != null) {
        // A request arrived at the end of the previous drain. Fire a fresh drain.
        save(_saveBrain19!);
      }
    });
  }

  Future<Map<String, dynamic>> _snapshot271(PlasticLanguageBrain04 brain) {
    // Build the large serializable snapshot in a worker isolate.
    return Isolate.run<Map<String, dynamic>>(() => brain.toJson());
  }

  Future<void> _drainSaves19() async {
    while (_saveQueued19 && _saveBrain19 != null) {
      _saveQueued19 = false;
      final brain = _saveBrain19!;
      final snapshot = await _snapshot271(brain);
      await MgdStateStore26.instance.putMap('brain_v051', snapshot);
      // 0.27.1: do not rebuild the complete semantic graph on every save.
      // The operation that introduces knowledge updates its graph delta.
    }
  }

  Future<void> saveWithProgress271(
    PlasticLanguageBrain04 brain, {
    void Function(String stage)? onStage,
  }) async {
    final active = _activeSave19;
    if (active != null) await active;
    onStage?.call('snapshot');
    final snapshot = await _snapshot271(brain);
    onStage?.call('database');
    await MgdStateStore26.instance.putMap('brain_v051', snapshot);
  }

  Future<void> _atomicReplace19(File file, List<int> bytes) async {
    final tmp = File('${file.path}.tmp');
    final bak = File('${file.path}.bak');
    try {
      if (await tmp.exists()) await tmp.delete();
      await tmp.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        try {
          if (await bak.exists()) await bak.delete();
          await file.copy(bak.path);
        } catch (_) {}
        await file.delete();
      }
      await tmp.rename(file.path);
    } finally {
      if (await tmp.exists()) {
        try { await tmp.delete(); } catch (_) {}
      }
    }
  }

  Future<PlasticLanguageBrain04?> _loadFile(File file) async {
    if (!await file.exists()) return null;
    final map = await compute(_decodeJsonMapGzip19, await file.readAsBytes());
    return PlasticLanguageBrain04.fromJson(map);
  }

  Future<PlasticLanguageBrain04?> _loadCurrentWithBackup19() async {
    final current = await _file(_fileName);
    try {
      final brain = await _loadFile(current);
      if (brain != null) return brain;
    } catch (_) {}
    try {
      return await _loadFile(File('${current.path}.bak'));
    } catch (_) {
      return null;
    }
  }

  Future<({PlasticLanguageBrain04 brain, bool migrated})?> load() async {
    // 0.26 canonical path: SQLite WAL + binary codec, not JSON parsing.
    final map=await MgdStateStore26.instance.getMap('brain_v051');
    if(map!=null)return (brain:PlasticLanguageBrain04.fromJson(map),migrated:false);
    // Legacy gzip/JSON is read only for one-time migration.
    final current = await _loadCurrentWithBackup19();
    if (current != null) { unawaited(MgdStateStore26.instance.putMap('brain_v051',current.toJson())); return (brain: current, migrated: false); }

    for (final legacyName in [_oldV05FileName, _oldV04FileName]) {
      try {
        final brain = await _loadFile(await _file(legacyName));
        if (brain != null) return (brain: brain, migrated: true);
      } catch (_) {}
    }

    try {
      final old = await _file(_oldV03FileName);
      if (await old.exists()) {
        final map = await compute(_decodeJsonMapGzip19, await old.readAsBytes());
        final brain = PlasticLanguageBrain04.migrateFromV03(map);
        return (brain: brain, migrated: true);
      }
    } catch (_) {}
    return null;
  }

  Future<void> clear() async {
    await MgdStateStore26.instance.deleteKey('brain_v051');
    for (final name in [
      _fileName,
      _oldV05FileName,
      _oldV04FileName,
      _oldV03FileName,
    ]) {
      final file = await _file(name);
      for (final f in [file, File('${file.path}.bak'), File('${file.path}.tmp')]) {
        if (await f.exists()) await f.delete();
      }
    }
  }
}
