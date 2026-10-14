"""Idempotent, bounded integration into the existing app. Never touches user DBs."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
def replace(path,old,new,marker=None):
    p=ROOT/path;s=p.read_text()
    if marker and marker in s:return
    if new in s:return
    if s.count(old)!=1:raise RuntimeError(f'Integration anchor changed in {path}: {s.count(old)}')
    p.write_text(s.replace(old,new,1))
replace('lib/main.dart',"import 'dart:convert';","import 'dart:convert';\nimport 'axioms/axiom_page.dart';", "import 'axioms/axiom_page.dart';")
replace('lib/main.dart',"        actions: [\n          IconButton(\n            tooltip: 'Previsioni apprese',", "        actions: [\n          TextButton.icon(\n            key: const ValueKey('open-axiom-studio'),\n            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AxiomStudioPage())),\n            icon: const Icon(Icons.hub_outlined),\n            label: const Text('Assiomi'),\n          ),\n          IconButton(\n            tooltip: 'Previsioni apprese',", "ValueKey('open-axiom-studio')")
replace('lib/main.dart',"title: const Text('MGD Neuro $mgdAppVersion319'),","title: const Text('MGD Studio $mgdAppVersion319'),")
replace('pubspec.yaml','version: 0.42.22+104','version: 0.43.0+110')
replace('lib/memory_runtime_v0319.dart',"const mgdAppVersion319 = '0.42.22';","const mgdAppVersion319 = '0.43.0';")
k='android/app/src/main/kotlin/it/diegorusso/mgd_neuro_mobile/MainActivity.kt'
replace(k,'    private var playback: AudioTrack? = null','    private var playback: AudioTrack? = null\n    private var axiomTeacher: AxiomTeacherBridge? = null','private var axiomTeacher:')
replace(k,'        super.configureFlutterEngine(flutterEngine)','        super.configureFlutterEngine(flutterEngine)\n        axiomTeacher = AxiomTeacherBridge(this, flutterEngine.dartExecutor.binaryMessenger)','axiomTeacher = AxiomTeacherBridge')
replace(k,'    override fun onStop() { stopPlayback(); super.onStop() }','    override fun onStop() { axiomTeacher?.cancel(); stopPlayback(); super.onStop() }\n    override fun onDestroy() { axiomTeacher?.close(); axiomTeacher = null; super.onDestroy() }','override fun onDestroy()')
g='android/app/build.gradle.kts'
replace(g,'flutter {\n    source = "../.."\n}','flutter {\n    source = "../.."\n}\n\ndependencies {\n    implementation("com.google.ai.edge.litertlm:litertlm-android:0.18.0")\n}','litertlm-android:0.18.0')
replace('android/app/src/main/AndroidManifest.xml','        <activity\n','        <uses-native-library android:name="libvndksupport.so" android:required="false"/>\n        <uses-native-library android:name="libOpenCL.so" android:required="false"/>\n        <activity\n','libvndksupport.so')
# Review corrections, kept here so the integration transaction is reproducible.
replace('lib/axioms/axiom_core.dart','if(mask&(1<<i)!=0)','if((mask & (1<<i)) != 0)')
replace('android/app/src/main/kotlin/it/diegorusso/mgd_neuro_mobile/AxiomTeacherBridge.kt','val digest=MessageDigest.getInstance("SHA-256"), buffer=ByteArray(1024*1024)','val digest=MessageDigest.getInstance("SHA-256"); val buffer=ByteArray(1024*1024)')
# The target itself and operational transfer must pass, not just other easy examples.
p=ROOT/'lib/axioms/axiom_core.dart';s=p.read_text()
marker='final targetTask = proposal'
if marker not in s:
    anchor="  final protected=regression.where((q)=>original.probe(q)['passed']==true).toList();"
    addition="""  final targetTask = proposal['task'];
  if(targetTask is! Map || targetTask['text'] is! String || targetTask['intent'] is! String || targetTask['args'] is! Map) return {'accepted':false,'reason':'Il task originale deve essere annotato esplicitamente.'};
  if(tasks.any((q)=>q['before'] is! Map || q['expected_after'] is! Map || q['expected_status'] is! String)) return {'accepted':false,'reason':'Ogni prova deve verificare anche un effetto operativo, non soltanto riconoscere una frase.'};
  if(!tasks.any((q)=>const ['preconditions_false','needs_context','event_denied_no_update'].contains(q['expected_status']))) return {'accepted':false,'reason':'Manca un contrasto operativo: negazione, precondizione falsa o contesto insufficiente.'};
  final evaluationTasks = [targetTask, ...tasks];
"""
    assert s.count(anchor)==1;s=s.replace(anchor,addition+anchor)
    s=s.replace("final already=tasks.every", "final already=evaluationTasks.every")
    s=s.replace("final transfer=tasks.map", "final transfer=evaluationTasks.map")
    s=s.replace("'transfer_tested':tasks.length", "'transfer_tested':evaluationTasks.length")
    p.write_text(s)
# Derived operators are visibly decomposed instead of being labelled atomic.
p=ROOT/'lib/axioms/axiom_core.dart';s=p.read_text()
if "'primitive:boolean_not'" not in s:
    anchor='    String expression(Map e) {'
    addition="""    add('primitive:boolean_not','Negazione booleana','primitive',[],{'scope':'Operatore del DSL dichiarato.'});
    add('primitive:presence','Presenza del dato','primitive',[],{'scope':'Distinguere un campo assente da un valore nullo esplicito.'});
    add('primitive:neq','Diversità','expression',['primitive:eq','primitive:boolean_not'],{'definition':'not(eq(a,b))'});
    add('primitive:known','Valore noto','expression',['primitive:read','primitive:presence','primitive:null','primitive:eq','primitive:boolean_not'],{'definition':'Presenza epistemica del dato e valore diverso da null; il simulatore distingue assenza strutturale e dato ignoto.'});
"""
    assert s.count(anchor)==1;p.write_text(s.replace(anchor,addition+anchor))
# Tell the actual local model the complete schema, including the target and worlds.
p=ROOT/'lib/axioms/axiom_seed.dart';s=p.read_text()
if 'OBBLIGATORIO: aggiungi' not in s:
    s=s.replace("Restituisci SOLO un oggetto JSON, senza markdown, nel formato:","OBBLIGATORIO: aggiungi un campo task con text IDENTICO alla richiesta, intent, args, negated. Se è disponibile il mondo before, aggiungi expected_after ed expected_status senza cambiare before. Tutte le probes devono avere before, expected_after ed expected_status e almeno una deve negare l'evento o mostrare precondizioni false o contesto mancante. Non basta riconoscere una frase.\nRestituisci SOLO un oggetto JSON, senza markdown, nel formato:")
    p.write_text(s)
print('Integrated MGD Studio 0.43.0 axiom map and local teacher. Existing databases unchanged.')
