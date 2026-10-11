import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/neural_reading_v0439.dart';
import '../lib/web_knowledge_explorer_v11.dart';
void main() {
 test('emit actual MGD context and prompt for frozen fresh441 texts', () {
  final input=File('../mgd_reader_fresh441.json').readAsBytesSync();
  expect(sha256.convert(input).toString(),'c93bd5eaebd25a60718c6b0281cc26b9f1cf0c5ce48917d721f993896d348418');
  final prompts=<Map<String,dynamic>>[];
  for(final c in (jsonDecode(utf8.decode(input)) as List).cast<Map>()) {
   final m=ResearchMemory11();
   SourceMemory323.retain(m,WebDocument11(provider:'Verifica nuova',family:'local',title:'Archivio',url:'local://fresh441/${c['id']}',trust:.9,text:c['text']));
   final rows=NeuralReading439.context(m,c['question']);
   final query='${c['question']}\nScegli una risposta e riporta solo la lettera A, B, C o D nel campo answer.\n'+(c['options'] as Map).entries.map((e)=>'${e.key}: ${e.value}').join('\n');
   prompts.add({'id':c['id'],'domain':c['domain'],'rows':[for(var i=0;i<rows.length;i++) {'id':'P$i','text':rows[i]['text']}],'prompt':NeuralReading439.answerPrompt(query,rows),'available_rows':NeuralReading439.fragments(m).length});
  }
  expect(prompts.length,16);
  expect(prompts.every((p)=>(p['rows'] as List).isNotEmpty),true);
  final out=Directory('tool/reports')..createSync(recursive:true);
  File('${out.path}/fresh441-production-prompts.json').writeAsStringSync(jsonEncode(prompts));
 });
}
