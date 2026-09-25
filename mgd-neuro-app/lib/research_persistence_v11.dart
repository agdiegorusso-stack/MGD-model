import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'web_knowledge_explorer_v11.dart';
import 'mgd_state_store_v026.dart';

List<int> _encodeResearchMapGzip19(Map<String, dynamic> map) =>
    gzip.encode(utf8.encode(jsonEncode(map)));

Map<String, dynamic> _decodeResearchMapGzip19(List<int> bytes) =>
    Map<String, dynamic>.from(
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map,
    );

class ResearchPersistence11 {
  static const _fileName = 'mgd_neuro_research_v11.json.gz';
  static const _legacyFileName = 'mgd_neuro_research_v10.json.gz';

  Future<void>? _activeSave19;
  bool _saveQueued19 = false;
  ResearchMemory11? _saveMemory19;

  Future<Directory> _dir() => getApplicationDocumentsDirectory();
  Future<File> _file() async => File('${(await _dir()).path}/$_fileName');
  Future<File> _legacyFile() async => File('${(await _dir()).path}/$_legacyFileName');

  Future<ResearchMemory11?> _loadOne19(File f) async {
    if (!await f.exists()) return null;
    final map = await compute(_decodeResearchMapGzip19, await f.readAsBytes());
    return ResearchMemory11.fromJson(map);
  }

  Future<ResearchMemory11?> load() async {
    // A decode failure is not an empty archive. Surface it before any autosave.
    final stored=await MgdStateStore26.instance.getMap('research_v11');
    if(stored!=null)return ResearchMemory11.fromJson(stored);
    final f = await _file();
    try {
      final current = await _loadOne19(f);
      if (current != null) return current;
    } catch (_) {}
    try {
      final backup = await _loadOne19(File('${f.path}.bak'));
      if (backup != null) return backup;
    } catch (_) {}

    try {
      final legacy = await _legacyFile();
      if (!await legacy.exists()) return null;
      final map = await compute(_decodeResearchMapGzip19, await legacy.readAsBytes());
      return ResearchMemory11(
        enabled: map['enabled'] != false,
        dailyBudget: (map['dailyBudget'] as num?)?.toInt() ?? 0,
        requestsToday: (map['requestsToday'] as num?)?.toInt() ?? 0,
        dayKey: (map['dayKey'] ?? '').toString(),
        lastResearchAtIso: map['lastResearchAtIso'] as String?,
        lastGoal: map['lastGoal'] as String?,
        lastStatus: 'Motore ricerca 0.19 pronto; stato precedente migrato.',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ResearchMemory11 memory) {
    _saveMemory19 = memory;
    _saveQueued19 = true;
    return _activeSave19 ??= _drain19().whenComplete(() {
      _activeSave19 = null;
      if (_saveQueued19 && _saveMemory19 != null) save(_saveMemory19!);
    });
  }

  Future<void> _drain19() async {
    while (_saveQueued19 && _saveMemory19 != null) {
      _saveQueued19 = false;
      final memory = _saveMemory19!;
      memory.trim();
      await MgdStateStore26.instance.putMap('research_v11',memory.toJson());
    }
  }

  Future<void> clear() async {
    await MgdStateStore26.instance.deleteKey('research_v11');
    for (final f in [await _file(), await _legacyFile()]) {
      for (final x in [f, File('${f.path}.bak'), File('${f.path}.tmp')]) {
        if (await x.exists()) await x.delete();
      }
    }
  }
}
