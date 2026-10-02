package it.diegorusso.mgd_neuro_mobile

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
