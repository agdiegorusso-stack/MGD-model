package it.diegorusso.mgd_neuro_mobile

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.ai.edge.litertlm.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

/** No network calls, no tool execution, no learning from generated answers. */
class NeuralReader439(private val context: Context, messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private val ui = Handler(Looper.getMainLooper())
    private val epoch = AtomicLong(0)
    private var engine: Engine? = null
    @Volatile private var active: Conversation? = null
    private val channel = MethodChannel(messenger, "mgd/neural-reader439")
    private val expectedHash = "03e7da1eb1108b50dffaa9bb52cc7bcbad2eb0c66ca990267f480c1e545d2856"

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> { cancel(); result.success(null) }
                "close" -> { cancel(); worker.execute { engine?.close(); engine = null }; result.success(null) }
                "generate" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt.isNullOrBlank() || prompt.length > 13000) {
                        result.error("INPUT", "Contesto troppo lungo o vuoto", null)
                    } else {
                        val turn = epoch.get()
                        worker.execute {
                            try {
                                if (turn != epoch.get()) error("Lettura interrotta")
                                val ready = ensureEngine()
                                val text = ready.createConversation(ConversationConfig(
                                    extraContext = mapOf("enable_thinking" to false),
                                    thinkingConfig = ThinkingConfig(enableThinking = false),
                                    samplerConfig = SamplerConfig(topK = 20, topP = 0.8, temperature = 0.0, seed = 439),
                                    maxOutputToken = 384,
                                    automaticToolCalling = false
                                )).use { conv ->
                                    active = conv
                                    conv.sendMessage(prompt).toString()
                                }
                                active = null
                                if (turn != epoch.get()) error("Lettura interrotta")
                                ui.post { result.success(text) }
                            } catch (e: Throwable) {
                                active = null
                                ui.post { result.error("LOCAL_READER", e.message ?: e.javaClass.simpleName, null) }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureEngine(): Engine {
        engine?.let { return it }
        val info = ActivityManager.MemoryInfo()
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info)
        check(!info.lowMemory && info.availMem > 1600L * 1024 * 1024) {
            "Memoria libera insufficiente per il lettore locale; i brani restano consultabili"
        }
        val dir = File(context.filesDir, "neural439").apply { mkdirs() }
        val file = File(dir, "qwen3-0.6b-int4.litertlm")
        if (!file.isFile || file.length() != 344671744L) {
            val temp = File(dir, "model.partial")
            val digest = MessageDigest.getInstance("SHA-256")
            try {
                context.assets.open("reader439/model.litertlm").use { input ->
                    temp.outputStream().use { output ->
                        val buf = ByteArray(1024 * 1024)
                        while (true) { val n = input.read(buf); if (n < 0) break
                            digest.update(buf, 0, n); output.write(buf, 0, n) }
                    }
                }
                val hash = digest.digest().joinToString("") { "%02x".format(it) }
                check(hash == expectedHash && temp.length() == 344671744L) { "Modello locale danneggiato" }
                check(temp.renameTo(file)) { "Impossibile installare il lettore locale" }
            } finally { temp.delete() }
        }
        val ready = Engine(EngineConfig(modelPath = file.path,
            backend = Backend.CPU(threadCount = 3), maxNumTokens = 2048,
            cacheDir = context.cacheDir.path))
        try { ready.initialize() } catch (e: Throwable) { ready.close(); throw e }
        engine = ready
        return ready
    }

    fun cancel() { epoch.incrementAndGet(); try { active?.cancelProcess() } catch (_: Throwable) {} }
    fun dispose() {
        cancel(); channel.setMethodCallHandler(null)
        worker.execute { engine?.close(); engine = null }; worker.shutdown()
    }
}
