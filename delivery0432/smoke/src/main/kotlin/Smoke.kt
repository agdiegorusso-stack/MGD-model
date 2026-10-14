import com.google.ai.edge.litertlm.*
import com.google.gson.GsonBuilder
import com.google.gson.JsonParser
import java.io.File
import java.security.MessageDigest

fun digest(path: File): String {
    val sha = MessageDigest.getInstance("SHA-256")
    path.inputStream().buffered().use { input ->
        val buffer = ByteArray(1024 * 1024)
        while (true) { val n = input.read(buffer); if (n < 0) break; sha.update(buffer, 0, n) }
    }
    return sha.digest().joinToString("") { "%02x".format(it) }
}

fun main(args: Array<String>) {
    require(args.size == 3) { "model_path prompts_path evidence_path" }
    val model = File(args[0]); val output = File(args[2]); output.parentFile.mkdirs()
    val expectedSha = "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c"
    val sha = digest(model)
    check(sha == expectedSha) { "Unexpected model bytes" }
    val prompts = JsonParser.parseString(File(args[1]).readText()).asJsonArray
    val evidence = mutableListOf<Map<String, Any?>>()
    val gson = GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create()
    val started = System.nanoTime()
    Engine(EngineConfig(modelPath = model.absolutePath, backend = Backend.CPU(),
        maxNumTokens = 4096, cacheDir = File(model.parentFile, "litert-cpu-smoke").apply { mkdirs() }.path)).use { engine ->
        engine.initialize()
        val loadMs = (System.nanoTime() - started) / 1_000_000
        for (item in prompts) {
            val q = item.asJsonObject
            val system = q["system"].asString; val prompt = q["prompt"].asString
            val request = q["request"].asString; val expected = q["expected_choice"].asString
            val configuration = ConversationConfig(
                systemInstruction = Contents.of(system),
                samplerConfig = SamplerConfig(topK = 20, topP = 0.9, temperature = 0.2),
                thinkingConfig = ThinkingConfig(enableThinking = false, thinkingTokenBudget = 0),
                maxOutputToken = 64, enableResponseFormat = true, enableSpeculativeDecoding = false)
            val t = System.nanoTime()
            var raw = ""; var error: String? = null; var choice: String? = null
            try {
                engine.createConversation(configuration).use { conversation ->
                    raw = conversation.sendMessage(prompt,
                        responseFormat = ResponseFormat.json(q["schema"].asString)).toString()
                }
                val parsed = JsonParser.parseString(raw).asJsonObject
                check(parsed.size() == 1) { "Unexpected fields" }
                choice = parsed["choice"].asString
            } catch (e: Exception) { error = e.toString() }
            val durationMs = (System.nanoTime() - t) / 1_000_000
            val row = linkedMapOf<String, Any?>(
                "request" to request, "raw_response" to raw, "choice" to choice,
                "expected_choice" to expected, "passed" to (choice == expected && error == null),
                "error" to error, "duration_ms" to durationMs, "model_load_ms" to loadMs,
                "prompt_characters" to (prompt.length + system.length), "max_output_tokens" to 64,
                "backend" to "CPU", "platform" to "GitHub Actions Linux x86_64 JVM, NOT Android GPU",
                "runtime_version" to "0.18.0", "model_sha256" to sha,
                "model" to "Gemma 4 E2B LiteRT, pinned official community conversion",
                "mock" to false, "phone_tested" to false)
            evidence.add(row); output.writeText(gson.toJson(evidence))
            println("REAL_GEMMA " + gson.toJson(row))
        }
    }
    check(evidence.size == 6 && evidence.all { it["passed"] == true }) {
        "Real Gemma did not pass all semantic-choice cases; evidence retained. Do not distribute as verified."
    }
}
