"""Apply the 0432 integration after the retained 0430 production patch.
All modifications are asserted and retained in the compiled-source artifact.
No checkpoint, database path, model file, application id or signing key is reset.
"""
from pathlib import Path
import hashlib, re
root = Path(__file__).resolve().parents[1]
app = root / 'mgd-neural-0421'
def replace(path, old, new):
    p = root/path; text = p.read_text()
    assert text.count(old) == 1, (path, old[:100], text.count(old))
    p.write_text(text.replace(old, new))

a = 'mgd-neural-0421/lib/axioms/'
replace(a+'axiom_store.dart', "import 'teacher_protocol0431.dart';", "import 'teacher_protocol0431.dart';\nimport 'teacher_compact0432.dart';")
replace(a+'axiom_store.dart', "part 'axiom_teacher0431.dart';", "part 'axiom_teacher0431.dart';\npart 'axiom_teacher0432.dart';")
p = app/'lib/axioms/axiom_store.dart'; text = p.read_text()
text,n = re.subn(r'teachWithEvidence0431\(text,\s*copyJ\(world\),\s*rounds\)', 'teachCompact0432(text, copyJ(world), rounds)', text)
assert n == 1; p.write_text(text)
# Preserve every legacy test on the legacy protocol; add a separate full suite
# for the new default entry point instead of weakening old expectations.
for name in ['axioms0431_teacher_protocol_test.dart', 'axioms0430_store_test.dart']:
    p=app/'test'/name; t=p.read_text(); assert '.teach(' in t
    p.write_text(t.replace('.teach(', '.teachWithEvidence0431('))
# Negation and grammatical literals already known to the student cannot be
# absorbed into a new predicate or misidentified as entity names.
replace(a+'teacher_compact0432.dart', 'if (surface.isEmpty || !surface.every(entity)) continue;',
    "if (surface.isEmpty || !surface.every(entity) || surface.contains('non')) continue;")
replace(a+'teacher_compact0432.dart', 'if (args.values.toSet().length != args.length) continue;',
    "final literals = <String>{\n          for (final f in s.frames) ...((f['parts'] as List).whereType<String>()),\n          for (final r in s.rules) ...((r['source'] as List).whereType<String>())\n        };\n        if (args.values.toSet().length != args.length || args.values.any(literals.contains)) continue;")

bridge = 'mgd-neural-0421/android/app/src/main/kotlin/it/diegorusso/mgd_neuro_mobile/AxiomTeacherBridge.kt'
replace(bridge, 'import android.os.StatFs', 'import android.os.StatFs\nimport android.os.SystemClock')
replace(bridge, '@Volatile private var phase = "idle"', '@Volatile private var phase = "idle"\n    @Volatile private var lastLoadMs = 0L\n    @Volatile private var lastGenerateMs = 0L')
replace(bridge, 'val path=file(id)\n                    check(path.isFile)',
    '''val selected=call.argument<String>("backend")?:"CPU"
                    check(selected in listOf("CPU","GPU","GPU_FP32")) { "Backend non valido." }
                    if (engine?.isInitialized()==true && loaded==id && backend==selected) {
                        return@background mapOf("loaded" to loaded,"backend" to backend,"reused" to true)
                    }
                    val loadStarted=SystemClock.elapsedRealtime()
                    val path=file(id)
                    check(path.isFile)''')
replace(bridge, '                    val selected=call.argument<String>("backend")?:"CPU"\n                    main.post', '                    main.post')
replace(bridge, 'val config=EngineConfig(modelPath=path.absolutePath, backend=if(selected=="GPU")Backend.GPU() else Backend.CPU(),\n                        cacheDir=File(context.cacheDir,"axiom-litert").apply{mkdirs()}.path,maxNumTokens=12288)',
    '''val config=EngineConfig(modelPath=path.absolutePath, backend=if(selected.startsWith("GPU"))Backend.GPU() else Backend.CPU(),
                        cacheDir=File(context.cacheDir,"axiom-litert-0432/$id/$selected").apply{mkdirs()}.path,maxNumTokens=4096,
                        activationDataType=if(selected=="GPU_FP32")ActivationDataType.FLOAT32 else null)''')
replace(bridge, '                    mapOf("loaded" to loaded,"backend" to backend)\n                }',
    '                    lastLoadMs=SystemClock.elapsedRealtime()-loadStarted\n                    mapOf("loaded" to loaded,"backend" to backend,"load_ms" to lastLoadMs)\n                }')
replace(bridge, '                    check(prompt.length+system.length<=40000)',
    '''                    val schema=call.argument<String>("json_schema")
                    val outputLimit=if(schema!=null)64 else 3072
                    val timeoutSeconds=if(schema!=null)60L else 240L
                    val generationStarted=SystemClock.elapsedRealtime()
                    check(schema==null || schema.length<=8000) { "Schema oltre limite." }
                    check(prompt.length+system.length<=if(schema!=null)8000 else 40000)''')
replace(bridge, 'thinkingConfig=ThinkingConfig(enableThinking=false,thinkingTokenBudget=0),maxOutputToken=3072)',
    'thinkingConfig=ThinkingConfig(enableThinking=false,thinkingTokenBudget=0),maxOutputToken=outputLimit,\n                        enableResponseFormat=schema!=null, enableSpeculativeDecoding=false)')
replace(bridge, 'val deadline=timer.schedule({cancel()},240,TimeUnit.SECONDS)', 'val deadline=timer.schedule({cancel()},timeoutSeconds,TimeUnit.SECONDS)')
replace(bridge, 'val response=session.sendMessage(prompt).toString()',
    'val response=if(schema==null)session.sendMessage(prompt).toString()\n                            else session.sendMessage(prompt,responseFormat=ResponseFormat.json(schema)).toString()')
replace(bridge, '                        deadline.cancel(false)\n                        synchronized(conversationLock)',
    '                        deadline.cancel(false)\n                        lastGenerateMs=SystemClock.elapsedRealtime()-generationStarted\n                        synchronized(conversationLock)')
replace(bridge, 'return mapOf("models" to models,"loaded" to loaded,"backend" to backend,"busy" to occupied.get(),"phase" to phase,',
    '''return mapOf("models" to models,"loaded" to loaded,"backend" to backend,"busy" to occupied.get(),"phase" to phase,
            "loadedSha256" to if(loaded.isEmpty())"" else modelOrCustomHash(loaded),
            "loadedName" to if(loaded=="custom")(prefs.getString("name:custom","Importato")?:"Importato") else loaded,
            "lastLoadMs" to lastLoadMs,"lastGenerateMs" to lastGenerateMs,"contextTokens" to 4096,''')
# Preserve the CPU/GPU selector and its reviewed golden layout. Precision
# overrides remain native-only until a separate interface test covers them.
replace(a+'axiom_page.dart', '          Text(status),',
    "          if ((data['loaded']?.toString() ?? '').isNotEmpty && data['lastLoadMs'] != null)\n            Text('Caricamento: ${data['lastLoadMs']} ms · ultima generazione: ${data['lastGenerateMs']} ms'),\n          Text(status),")
# Retain the existing integrity checks, updating only the changed native source.
p=root/'delivery0430/check_patch.py'; text=p.read_text()
old='5a716ceeaa0ee33d203a56082704ec4e966db1d0f4824adbd4a48f5b0b721b29'
assert old in text
p.write_text(text.replace(old, hashlib.sha256((root/bridge).read_bytes()).hexdigest()))
p=app/'pubspec.yaml'; text=p.read_text(); assert '0.43.1+111' in text
p.write_text(text.replace('0.43.1+111','0.43.2+112'))
p=root/'delivery0430/build_android.sh'; text=p.read_text()
text=text.replace('0.43.1','0.43.2').replace("versionCode='111'", "versionCode='112'").replace("'build':111", "'build':112")
# The user now reports protocol 0431; refuse an incompatible new random key.
needle='"$TOOLS/aapt" dump badging "$APK" > tool/reports/apk-identity0430.txt'
assert needle in text
text=text.replace(needle, needle+'''\npython3 - <<'PYSIGN'
from pathlib import Path
expected='d4974611809f5def4c01e0d805a124be0a9471d7532b15c8eeb8d6ec30eb78e1'
s=Path('tool/reports/apk-signature0430.txt').read_text()
assert expected in s, 'Signing certificate differs from installed 0.43.1; do not distribute as an update.'
PYSIGN''')
p.write_text(text)
print('0432 integration complete; old memory and signing paths unchanged.')
