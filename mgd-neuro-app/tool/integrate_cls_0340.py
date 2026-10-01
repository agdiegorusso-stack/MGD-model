"""Validate integrated runtime and materialize native Android support.
Existing .33 snapshots remain untouched. Run from the committed .34 branch.
"""
from pathlib import Path
import re
import runpy
root=Path(__file__).resolve().parents[1]
checks={
 'pubspec.yaml':['version: 0.34.0+66','sqflite_common_ffi:'],
 'lib/main.dart':['ClsBridge340.active = await ClsStore340.shared','ClsPage340(world: _world','await ClsBridge340.clear()','await ClsBridge340.observeText'],
 'lib/cls_store_v0340.dart':['VACUUM INTO'],
 'lib/learning_service_v0321.dart':['await ClsBridge340.observeText'],
}
for path,markers in checks.items():
    text=(root/path).read_text()
    for marker in markers:
        if marker not in text:raise RuntimeError(f'{path}: missing committed integration {marker}')
runpy.run_path(str(root/'tool/refine_cls_0340.py'))

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
print('CLS 0.34.0 integration validated')
