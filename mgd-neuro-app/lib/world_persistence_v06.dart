import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'sensory_world_v06.dart';
import 'mgd_state_store_v026.dart';

List<int> _encodeWorldMapGzip19(Map<String, dynamic> map) =>
    gzip.encode(utf8.encode(jsonEncode(map)));

Map<String, dynamic> _decodeWorldMapGzip19(List<int> bytes) =>
    Map<String, dynamic>.from(
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map,
    );

class WorldPersistence06 {
  static const _fileName = 'mgd_neuro_world_v06.json.gz';

  Future<void>? _activeSave19;
  bool _saveQueued19 = false;
  MgdWorld06? _saveWorld19;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<MgdWorld06?> _loadOne19(File f) async {
    if (!await f.exists()) return null;
    final map = await compute(_decodeWorldMapGzip19, await f.readAsBytes());
    return MgdWorld06.fromJson(map);
  }

  Future<MgdWorld06?> load() async {
    final map=await MgdStateStore26.instance.getMap('world_v06');
    if(map!=null)return MgdWorld06.fromJson(map);
    final f = await _file();
    try {
      final world = await _loadOne19(f);
      if (world != null) return world;
    } catch (_) {}
    try {
      return await _loadOne19(File('${f.path}.bak'));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(MgdWorld06 world) {
    _saveWorld19 = world;
    _saveQueued19 = true;
    return _activeSave19 ??= _drain19().whenComplete(() {
      _activeSave19 = null;
      if (_saveQueued19 && _saveWorld19 != null) save(_saveWorld19!);
    });
  }

  Future<void> _drain19() async {
    while (_saveQueued19 && _saveWorld19 != null) {
      _saveQueued19 = false;
      final world = _saveWorld19!;
      final snapshot = await Isolate.run<Map<String, dynamic>>(() => world.toJson());
      await MgdStateStore26.instance.putMap('world_v06',snapshot);
    }
  }

  Future<void> clear() async {
    await MgdStateStore26.instance.deleteKey('world_v06');
    final f = await _file();
    for (final x in [f, File('${f.path}.bak'), File('${f.path}.tmp')]) {
      if (await x.exists()) await x.delete();
    }
  }
}
