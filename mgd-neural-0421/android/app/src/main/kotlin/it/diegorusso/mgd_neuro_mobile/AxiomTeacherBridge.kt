package it.diegorusso.mgd_neuro_mobile

import android.app.Activity
import android.app.ActivityManager
import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.view.WindowManager
import com.google.ai.edge.litertlm.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** The LLM is an untrusted lesson proposer. It has no database or tool access. */
class AxiomTeacherBridge(private val activity: Activity, messenger: BinaryMessenger) {
    data class Model(val id: String, val label: String, val repo: String, val revision: String,
        val file: String, val bytes: Long, val sha: String) {
        val url get() = "https://huggingface.co/$repo/resolve/$revision/$file"
    }
    private val catalog = listOf(
        Model("gemma4-e2b", "Gemma 4 E2B", "litert-community/gemma-4-E2B-it-litert-lm",
            "6e5c4f1e395deb959c494953478fa5cec4b8008f", "gemma-4-E2B-it.litertlm", 2588147712L,
            "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c"),
        Model("gemma4-e4b", "Gemma 4 E4B", "litert-community/gemma-4-E4B-it-litert-lm",
            "28299f30ee4d43294517a4ac93abd6163412f07f", "gemma-4-E4B-it.litertlm", 3659530240L,
            "0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0")
    )
    private val context = activity.applicationContext
    private val root = File(requireNotNull(context.getExternalFilesDir(null)), "axiom-teachers").apply { mkdirs() }
    private val prefs = context.getSharedPreferences("axiom-teachers-0430", Context.MODE_PRIVATE)
    private val downloads = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val timer = Executors.newSingleThreadScheduledExecutor()
    private val channel = MethodChannel(messenger, "mgd.axioms/teacher")
    private val occupied = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)
    private val conversationLock = Any()
    @Volatile private var engine: Engine? = null
    @Volatile private var conversation: Conversation? = null
    @Volatile private var loaded = ""
    @Volatile private var backend = ""
    @Volatile private var phase = "idle"
    @Volatile private var alive = true

    init { channel.setMethodCallHandler(::handle) }
    private fun file(id: String) = File(root, "$id.litertlm")
    private fun model(id: String) = catalog.firstOrNull { it.id == id }
        ?: throw IllegalArgumentException("Modello non presente nel catalogo verificato.")
    private fun reply(result: MethodChannel.Result, value: Any?) { main.post { if (alive) result.success(value) } }
    private fun error(result: MethodChannel.Result, e: Throwable) { main.post { if (alive) result.error("AXIOM_TEACHER", e.message ?: e.javaClass.simpleName, null) } }
    private fun background(result: MethodChannel.Result, task: () -> Any?) {
        if (!occupied.compareAndSet(false, true)) { result.error("BUSY", "È già in corso un'operazione sul modello.", null); return }
        cancelled.set(false)
        worker.execute {
            try { reply(result, task()) } catch (e: Throwable) { error(result, e) }
            finally { occupied.set(false); phase = "idle"; main.post { if(alive) activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) } }
        }
    }
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when(call.method) {
                "status" -> result.success(status())
                "download" -> {
                    val m = model(requireNotNull(call.argument<String>("id")))
                    val existing = prefs.getLong("download:${m.id}", -1)
                    if (existing >= 0 && downloadState(existing)["status"] in listOf(DownloadManager.STATUS_PENDING, DownloadManager.STATUS_RUNNING, DownloadManager.STATUS_PAUSED)) {
                        result.success(existing); return
                    }
                    check(StatFs(root.path).availableBytes > m.bytes + 536870912L) { "Spazio insufficiente: servono il modello più almeno 512 MB liberi." }
                    check(loaded != m.id) { "Scarica dalla RAM il modello prima di sostituirlo." }
                    if(existing >= 0) downloads.remove(existing)
                    val part=File(root,"${m.id}.part");part.delete()
                    val request=DownloadManager.Request(Uri.parse(m.url))
                        .setTitle("MGD Studio · ${m.label}")
                        .setDescription("Modello locale Apache 2.0; verifica SHA-256 prima dell'uso")
                        .setDestinationUri(Uri.fromFile(part))
                        .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                        .setAllowedOverRoaming(false)
                        .setAllowedOverMetered(call.argument<Boolean>("metered") == true)
                    if(call.argument<Boolean>("metered") != true) request.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
                    val id=downloads.enqueue(request)
                    prefs.edit().putLong("download:${m.id}",id).apply();result.success(id)
                }
                "cancelDownload" -> {
                    val id=requireNotNull(call.argument<String>("id"));model(id)
                    val download=prefs.getLong("download:$id",-1);if(download>=0)downloads.remove(download)
                    prefs.edit().remove("download:$id").apply();File(root,"$id.part").delete();result.success(null)
                }
                "verify" -> background(result) { verify(model(requireNotNull(call.argument<String>("id")))) }
                "import" -> background(result) {
                    val source=File(requireNotNull(call.argument<String>("path")))
                    check(source.isFile && source.name.endsWith(".litertlm",true)) { "Serve un file .litertlm compatibile, non GGUF o safetensors." }
                    check(source.length() in 1048576L..12000000000L) { "Dimensione del modello non valida." }
                    check(StatFs(root.path).availableBytes > source.length()+268435456L) { "Spazio insufficiente per importare il modello." }
                    check(loaded!="custom") { "Scarica dalla RAM il modello importato prima di sostituirlo." }
                    phase="importing"
                    val part=File(root,"custom.part")
                    source.inputStream().use { input -> part.outputStream().use { output ->
                        val buffer=ByteArray(1024*1024)
                        while(true) { if(cancelled.get())throw InterruptedException("Importazione annullata.");val n=input.read(buffer);if(n<0)break;output.write(buffer,0,n) }
                    } }
                    val digest=hash(part)
                    val dest=file("custom"); if(dest.exists())check(dest.delete());check(part.renameTo(dest))
                    prefs.edit().putString("sha:custom",digest).putLong("size:custom",dest.length()).putString("name:custom",source.name).apply()
                    mapOf("id" to "custom","sha256" to digest,"source_verified" to false)
                }
                "load" -> background(result) {
                    val id=requireNotNull(call.argument<String>("id"))
                    check(id=="custom" || catalog.any{it.id==id}) { "Identificatore non valido." }
                    val path=file(id)
                    check(path.isFile) { "Modello non installato: scaricalo e verifica il file." }
                    val expected=modelOrCustomHash(id)
                    check(expected.isNotEmpty()) { "Modello non verificato." }
                    phase="checking";check(hash(path)==expected) { "Checksum diverso: file danneggiato, non viene caricato." }
                    unload()
                    phase="loading"
                    val selected=call.argument<String>("backend")?:"CPU"
                    main.post { if(alive)activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
                    val config=EngineConfig(modelPath=path.absolutePath, backend=if(selected=="GPU")Backend.GPU() else Backend.CPU(),
                        cacheDir=File(context.cacheDir,"axiom-litert").apply{mkdirs()}.path,maxNumTokens=12288)
                    val candidate=Engine(config)
                    try { candidate.initialize(); if(cancelled.get()){candidate.close();throw InterruptedException("Caricamento annullato.")};engine=candidate;loaded=id;backend=selected }
                    catch(e:Throwable) { if(candidate.isInitialized())try{candidate.close()}catch(_:Throwable){};throw e }
                    mapOf("loaded" to loaded,"backend" to backend)
                }
                "unload" -> background(result) { unload(); null }
                "generate" -> background(result) {
                    val system=requireNotNull(call.argument<String>("system"));val prompt=requireNotNull(call.argument<String>("prompt"))
                    check(prompt.length+system.length<=40000) { "Richiesta troppo grande per il contesto locale configurato." }
                    val activeEngine=engine?:throw IllegalStateException("Scarica, verifica e carica un insegnante dalla schermata Modelli.")
                    phase="teaching"
                    main.post { if(alive)activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
                    val config=ConversationConfig(systemInstruction=Contents.of(system),
                        samplerConfig=SamplerConfig(topK=20,topP=0.9,temperature=0.2),
                        thinkingConfig=ThinkingConfig(enableThinking=false,thinkingTokenBudget=0),maxOutputToken=3072)
                    val session=activeEngine.createConversation(config)
                    synchronized(conversationLock) { conversation=session }
                    val deadline=timer.schedule({cancel()},240,TimeUnit.SECONDS)
                    try {
                        val response=session.sendMessage(prompt).text
                        check(!cancelled.get()) { "Generazione interrotta: nessuna lezione applicata." }
                        response
                    } finally {
                        deadline.cancel(false)
                        synchronized(conversationLock) { conversation=null;session.close() }
                    }
                }
                "cancel" -> { cancel();result.success(null) }
                else -> result.notImplemented()
            }
        } catch(e:Throwable) { error(result,e) }
    }
    private fun modelOrCustomHash(id:String):String = if(id=="custom")prefs.getString("sha:custom","")?:"" else model(id).sha
    private fun hash(path:File):String {
        phase="checking"
        val digest=MessageDigest.getInstance("SHA-256"), buffer=ByteArray(1024*1024)
        path.inputStream().use { input -> while(true) {
            if(cancelled.get())throw InterruptedException("Verifica annullata.")
            val n=input.read(buffer);if(n<0)break;digest.update(buffer,0,n)
        } }
        return digest.digest().joinToString(""){"%02x".format(it)}
    }
    private fun verify(m:Model):Map<String,Any> {
        val part=File(root,"${m.id}.part")
        val id=prefs.getLong("download:${m.id}",-1)
        check(id>=0 && downloadState(id)["status"]==DownloadManager.STATUS_SUCCESSFUL) { "Il download non è ancora completo." }
        check(part.isFile && part.length()==m.bytes) { "Dimensione diversa dal file ufficiale." }
        check(hash(part)==m.sha) { "SHA-256 non corrispondente: modello rifiutato." }
        check(loaded!=m.id) { "Scarica dalla RAM il modello prima di sostituirlo." }
        val dest=file(m.id);if(dest.exists())check(dest.delete());check(part.renameTo(dest))
        prefs.edit().putString("sha:${m.id}",m.sha).putLong("size:${m.id}",m.bytes).remove("download:${m.id}").apply()
        return mapOf("id" to m.id,"verified" to true,"sha256" to m.sha)
    }
    private fun downloadState(id:Long):Map<String,Any> {
        downloads.query(DownloadManager.Query().setFilterById(id)).use { c ->
            if(!c.moveToFirst())return mapOf("status" to 0,"done" to 0L)
            return mapOf("status" to c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)),
                "done" to c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)),
                "reason" to c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)))
        }
    }
    private fun status():Map<String,Any> {
        val memory=ActivityManager.MemoryInfo();(context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory)
        val models=catalog.map { m -> mapOf<String,Any>("id" to m.id,"label" to m.label,"bytes" to m.bytes,"sha256" to m.sha,
            "url" to m.url,"license" to "Apache-2.0","installed" to file(m.id).isFile,
            "download" to downloadState(prefs.getLong("download:${m.id}",-1))) }.toMutableList()
        if(file("custom").isFile) models.add(mapOf("id" to "custom","label" to (prefs.getString("name:custom","Importato")?:"Importato"),"bytes" to file("custom").length(),"installed" to true,"source_verified" to false,"sha256" to modelOrCustomHash("custom")))
        return mapOf("models" to models,"loaded" to loaded,"backend" to backend,"busy" to occupied.get(),"phase" to phase,
            "freeBytes" to StatFs(root.path).availableBytes,"availableRam" to memory.availMem,"totalRam" to memory.totalMem)
    }
    private fun unload() { engine?.let { if(it.isInitialized())it.close() };engine=null;loaded="";backend="" }
    fun cancel() {
        cancelled.set(true)
        synchronized(conversationLock) { try{conversation?.cancelProcess()}catch(_:Throwable){} }
    }
    fun close() {
        alive=false;cancel();channel.setMethodCallHandler(null)
        worker.execute { try{unload()}catch(_:Throwable){} };worker.shutdown();timer.shutdownNow()
    }
}
