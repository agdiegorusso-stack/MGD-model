"""Apply the reviewed integration delta to 0.33.1; fail on unknown source.
The CI commits these materialized files before running the verification suite.
"""
from pathlib import Path
import re
import sys

root=Path(__file__).resolve().parents[1]

def replace(path,old,new,count=1):
    p=root/path;s=p.read_text()
    if new in s:return
    if s.count(old)!=count:
        raise RuntimeError(f'{path}: expected {count} integration anchors, got {s.count(old)}')
    p.write_text(s.replace(old,new))

replace('pubspec.yaml','version: 0.33.1+65','version: 0.34.0+66')
replace('pubspec.yaml','dev_dependencies:\n','dev_dependencies:\n  sqflite_common_ffi: 2.3.7\n  sqlite3: ^2.9.4\n')
replace('lib/memory_runtime_v0319.dart',"const mgdAppVersion319 = '0.33.1';","const mgdAppVersion319 = '0.34.0';")
replace('lib/main.dart',"import 'experience_page_v0330.dart';", "import 'experience_page_v0330.dart';\nimport 'cls_page_v0340.dart';\nimport 'cls_store_v0340.dart';\nimport 'cls_bridge_v0340.dart';")
replace('lib/main.dart','      _language20.bootstrapFromBrain(_brain);','      _language20.bootstrapFromBrain(_brain);\n      ClsBridge340.active = await ClsStore340.shared;')
replace('lib/main.dart','ExperiencePage33(world: _world, onSave: _checkpoint319)', 'ClsPage340(world: _world, onSave: _checkpoint319)')
replace('lib/main.dart',"      _language20.ingestText(text, reward: 0.38);", "      await ClsBridge340.observeText(text, source: 'Chat utente');\n      _language20.ingestText(text, reward: 0.38);")
replace('lib/main.dart','      final semanticAnswer = sourced317 ?? grounded ?? languageAnswer;', "      final episodic340 = sourced317 == null && grounded == null\n          ? await ClsBridge340.quote(text) : null;\n      final semanticAnswer = sourced317 ?? episodic340 ?? grounded ?? languageAnswer;")
replace('lib/main.dart','          : (sourced317 ??\n              fluent ??','          : (sourced317 ??\n              episodic340 ??\n              fluent ??')
replace('lib/main.dart','    await _languagePersistence20.clear();','    await _languagePersistence20.clear();\n    await ClsBridge340.clear();')
replace('lib/main.dart',"      if (_world.eventDriven33) {", "      if (_lifecycle319 == AppLifecycleState.resumed && !_busy && !_researchBusy &&\n          _uiIdle18 && _chat.text.isEmpty && ClsBridge340.active != null) {\n        try {\n          if (await ClsBridge340.active!.readSetting('auto') != 'false') {\n            await ClsBridge340.active!.consolidate(budget: 8);\n          }\n        } catch (e) {\n          if (mounted) setState(() => _status = 'Consolidamento CLS sospeso: $e');\n        }\n      }\n      if (_world.eventDriven33) {")
replace('lib/main.dart',"'su evento: pronto, ripasso automatico disattivato'", "'MGD su evento; consolidamento CLS secondo le impostazioni'")
old="""        _world.experience33 = await compute(learnWorker33, (
          memory: _world.experience33.toJson(),
          features: {'${_lastSense!.observation.modality}:v1': features},
          label: canonical,
          context: 'generale',
          description: 'Percezione confermata in chat'
        ));"""
new="""        await (await ClsStore340.shared).learn(
          {'${_lastSense!.observation.modality}:v1': features},
          label: canonical,
          text: 'Percezione confermata in chat',
          source: 'Sensore MGD: descrittori senza allegato originale',
        );"""
replace('lib/main.dart',old,new)
# The legacy counter remains explicitly labeled; the new page reads disk totals.
replace('lib/main.dart',"'${world.experience33.episodes.length} episodi confermati · ${world.experience33.conceptCount} categorie esperienziali'", "'Archivio precedente: ${world.experience33.episodes.length} episodi. Apri Esperienze per i totali CLS e l’atlante.'")
replace('lib/learning_service_v0321.dart',"import 'dart:isolate';", "import 'dart:isolate';\nimport 'cls_bridge_v0340.dart';")
replace('lib/learning_service_v0321.dart','    brain.discoverConcepts();',"    await ClsBridge340.observeText(text, source: 'Testo insegnato');\n    brain.discoverConcepts();")
replace('lib/knowledge_deletion_v0330.dart',"import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\nimport 'cls_bridge_v0340.dart';")
replace('lib/knowledge_deletion_v0330.dart',"        if (episodeNode33(e) == node || conceptNode33(e) == node) {", "        if (episodeNode33(e) == node || conceptNode33(e) == node) {\n          if (episodeNode33(e) == node) {\n            await ClsBridge340.deleteLegacy(e.id);\n          } else {\n            await ClsBridge340.forgetLabel(e.label);\n          }")
replace('lib/knowledge_deletion_v0330.dart',"    bool matches(String s) => PlasticLanguageBrain04.containsLabel33(s, node);", "    await ClsBridge340.forgetLabel(node);\n    bool matches(String s) => PlasticLanguageBrain04.containsLabel33(s, node);")
# Avoid re-reading an image selected by the user.
replace('lib/cls_page_v0340.dart',"    final bytes=await file.readAsBytes(),f=await compute(imageWorker33,await file.readAsBytes());", "    final bytes=await file.readAsBytes();\n    final f=await compute(imageWorker33,bytes);")
# Consistent backup even if another connection writes concurrently.
old="""    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    // DB export is guarded by the caller's editing lock. Sidecar WAL is flushed.
    return File(db.path).readAsBytes();"""
new="""    final snapshot=File('${db.path}.export-${DateTime.now().microsecondsSinceEpoch}');
    try {
      await db.execute('VACUUM INTO ?', [snapshot.path]);
      return await snapshot.readAsBytes();
    } finally {
      if(await snapshot.exists()) await snapshot.delete();
    }"""
replace('lib/cls_store_v0340.dart',old,new)

# Flutter's generated MainActivity is otherwise empty. Do not replace unknown
# custom native code, and keep all recorder/camera permissions from baseline.
activities=list((root/'android/app/src/main').rglob('MainActivity.kt'))
if activities:
    if len(activities)!=1:raise RuntimeError('Ambiguous MainActivity')
    p=activities[0];s=p.read_text()
    if 'mgd.cls/audio' not in s:
        if not re.search(r'class MainActivity\s*:\s*FlutterActivity\(\)\s*(?:\{\s*\})?\s*$',s):
            raise RuntimeError('Unknown custom MainActivity; not overwriting')
        package=re.search(r'^package\s+([^\s;]+)',s,re.M).group(1)
        p.write_text('package '+package+'\n'+r'''
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var playback: AudioTrack? = null
    private fun stopPlayback() {
        playback?.let { try { it.stop() } catch (_: Exception) {} ; it.release() }
        playback = null
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mgd.cls/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stop" -> { stopPlayback(); result.success(null) }
                    "play" -> {
                        val data = call.arguments as? ByteArray
                        if (data == null || data.isEmpty() || data.size % 2 != 0 || data.size > 4194304) {
                            result.error("INVALID_PCM", "PCM16 mono non valido", null)
                        } else {
                            try {
                                stopPlayback()
                                val track = AudioTrack.Builder()
                                    .setAudioAttributes(AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_MEDIA)
                                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                                    .setAudioFormat(AudioFormat.Builder()
                                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                                        .setSampleRate(16000).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                                    .setTransferMode(AudioTrack.MODE_STATIC)
                                    .setBufferSizeInBytes(data.size).build()
                                playback = track
                                if (track.write(data, 0, data.size) != data.size) {
                                    stopPlayback(); result.error("WRITE", "Scrittura audio incompleta", null)
                                } else { track.play(); result.success(null) }
                            } catch (e: Exception) {
                                stopPlayback(); result.error("PLAYBACK", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun onStop() { stopPlayback(); super.onStop() }
}
''')
print('CLS 0.34.0 integration materialized successfully')
