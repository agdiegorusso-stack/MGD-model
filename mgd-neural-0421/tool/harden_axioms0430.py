"""Bounded persistence, readable UI evidence and legacy source-retirement fix."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
p=root/'lib/neural_reading_v0439.dart';s=p.read_text()
marker='// Protect the previous teaching provenance even when generation fails.'
if marker not in s:
    anchor="    final live = fragments(m).map((r) => r['rid439']).toSet();\n    if (!batch.every"
    assert anchor in s
    s=s.replace(anchor,"    final live = fragments(m).map((r) => r['rid439']).toSet();\n    "+marker+"\n    if (!processed.every(live.contains)) return false;\n    if (!batch.every",1)
p.write_text(s)
p=root/'lib/axioms/axiom_store.dart';s=p.read_text()
if '_readPayload0430' not in s:
    s=s.replace('Future<void> open() async {','Future<void> open({String? databasePath}) async {')
    s=s.replace("openDatabase('${await getDatabasesPath()}/mgd_axioms_0430.db',","openDatabase(databasePath ?? '${await getDatabasesPath()}/mgd_axioms_0430.db',")
    s=s.replace(".query('current', where: 'id=1')",".query('current', columns: ['id'], where: 'id=1')")
    s=s.replace("jsonDecode(rows.single['payload'] as String)","jsonDecode(await _readPayload0430('current', 1))",1)
    s=re.sub(r"\.query\('history',\s*orderBy: 'id DESC',\s*limit: 1\)",".query('history', columns: ['id'], orderBy: 'id DESC', limit: 1)",s)
    s=s.replace("jsonDecode(rows.single['payload'] as String)","jsonDecode(await _readPayload0430('history', rows.single['id'] as int))",1)
    anchor='  Future<void> _commit(J next, String reason) async {'
    assert anchor in s
    helper="""  /// Read bounded slices rather than an entire multi-megabyte CursorWindow row.
  Future<String> _readPayload0430(String table, int id) async {
    if (!const ['current','history'].contains(table)) throw ArgumentError('Tabella non ammessa.');
    final sizes = await _db!.rawQuery('SELECT length(payload) AS n FROM $table WHERE id=?', [id]);
    if (sizes.isEmpty) throw StateError('Revisione assente. Nessuna memoria sostituita.');
    final length = (sizes.single['n'] as num).toInt();
    if (length < 2 || length > 8000000) throw const FormatException('Snapshot fuori limite.');
    final out = StringBuffer();
    for (var offset = 1; offset <= length; offset += 131072) {
      final rows = await _db!.rawQuery('SELECT substr(payload, ?, 131072) AS part FROM $table WHERE id=?', [offset,id]);
      if (rows.isEmpty || rows.single['part'] is! String) throw StateError('Snapshot incompleto.');
      out.write(rows.single['part'] as String);
    }
    return out.toString();
  }
  Future<void> closeStorage() async { final database=_db;_db=null;await database?.close(); }

"""
    s=s.replace(anchor,helper+anchor)
p.write_text(s)
p=root/'test/axioms0430_widget_test.dart';s=p.read_text()
if 'loadFonts0430' not in s:
    s="import 'dart:io';\nimport 'dart:typed_data';\n"+s
    helper="""
Future<void> loadFonts0430() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = <Directory>[if(root!=null)Directory('$root/bin/cache/artifacts/material_fonts')];
  var cursor = File(Platform.resolvedExecutable).parent;
  for (var i=0;i<8;i++) { candidates.add(Directory('${cursor.path}/material_fonts'));cursor=cursor.parent; }
  final dir = candidates.firstWhere((d)=>File('${d.path}/Roboto-Regular.ttf').existsSync());
  for (final name in ['Roboto','MaterialIcons']) {
    final path = '${dir.path}/${name=='Roboto'?'Roboto-Regular.ttf':'MaterialIcons-Regular.otf'}';
    final loader = FontLoader(name)..addFont(Future.value(ByteData.sublistView(await File(path).readAsBytes())));
    await loader.load();
  }
}
"""
    s=s.replace('void main() {',helper+'\nvoid main() {')
    s=s.replace('  TestWidgetsFlutterBinding.ensureInitialized();','  TestWidgetsFlutterBinding.ensureInitialized();\n  setUpAll(loadFonts0430);')
    s=s.replace('ThemeData.dark(useMaterial3: true)',"ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'Roboto')")
p.write_text(s)
p=root/'lib/axioms/axiom_page.dart';s=p.read_text()
if "fontFamily: 'Roboto'" not in s:
    s,n=re.subn(r'TextStyle\(\s*fontSize: 12,\s*height: 1\.25,',"TextStyle(fontFamily: 'Roboto', fontSize: 12, height: 1.25,",s)
    assert n==1
p.write_text(s)
print('Hardened source-retirement checks and bounded persistent reads; test screenshots use actual SDK fonts.')
