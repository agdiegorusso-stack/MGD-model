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
    private val expectedHash = "2a72330b504a6596d53a2c00923c57173b10f1b83e6a541213ffec08d1fc5de8"

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
                        val reasoning = call.argument<Boolean>("reasoning") ?: false
                        val schema = call.argument<String>("schema")
                        worker.execute {
                            try {
                                if (turn != epoch.get()) error("Lettura interrotta")
                                val ready = ensureEngine()
                                val text = ready.createConversation(ConversationConfig(
                                    extraContext = mapOf("enable_thinking" to reasoning),
                                    thinkingConfig = ThinkingConfig(enableThinking = reasoning, thinkingTokenBudget = if (reasoning) 256 else 0),
                                    samplerConfig = SamplerConfig(topK = 20, topP = if (reasoning) 0.95 else 0.8, temperature = if (reasoning) 0.6 else 0.7, seed = 439),
                                    maxOutputToken = if (reasoning) 768 else 512,
                                    automaticToolCalling = false,
                                    enableResponseFormat = schema != null
                                )).use { conv ->
                                    active = conv
                                    conv.sendMessage(prompt, responseFormat = schema?.let { ResponseFormat.json(it) }).toString()
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
        val file = File(dir, "qwen3-1.7b-int4.litertlm")
        if (!file.isFile || file.length() != 977184032L) {
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
                check(hash == expectedHash && temp.length() == 977184032L) { "Modello locale danneggiato" }
                check(temp.renameTo(file)) { "Impossibile installare il lettore locale" }
            } finally { temp.delete() }
        }
        val ready = Engine(EngineConfig(modelPath = file.path,
            backend = Backend.CPU(threadCount = 3), maxNumTokens = 3072,
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
