import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'web_knowledge_explorer_v10.dart';

class ResearchPersistence10 {
  static const _fileName = 'mgd_neuro_research_v10.json.gz';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<ResearchMemory10?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = utf8.decode(gzip.decode(await f.readAsBytes()));
      return ResearchMemory10.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ResearchMemory10 memory) async {
    memory.trim();
    final f = await _file();
    final bytes =
        gzip.encode(utf8.encode(jsonEncode(memory.toJson())));
    await f.writeAsBytes(bytes, flush: true);
  }

  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
