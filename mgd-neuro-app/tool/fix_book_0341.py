"""Checked, idempotent 0.34.1 book-import repair applied to materialized 0.34.0."""
from pathlib import Path
import sys
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]

def patch(path, fn):
    p=root/path; s=p.read_text()
    if 'BOOK_IMPORT_REPAIR_0341' in s:return
    p.write_text('// BOOK_IMPORT_REPAIR_0341\n'+fn(s))
def sub(s,a,b):
    if s.count(a)!=1: raise RuntimeError(f'Expected one anchor {a[:100]!r}, found {s.count(a)}')
    return s.replace(a,b)

def language(s):
    s=sub(s,"import 'dart:io';", "import 'dart:io';\nimport 'dart:isolate';\nimport 'book_import_v0341.dart';\nimport 'cls_bridge_v0340.dart';")
    s=sub(s,'void ingestText(String text, {double reward = .35}) {',
      'void ingestText(String text, {double reward = .35, bool learnFrames341 = true}) {')
    s=sub(s,'      _learnFrame320(sentence);','      if (learnFrames341) _learnFrame320(sentence);')
    s=sub(s,'class MgdLanguageLab20 extends StatefulWidget {', '''class MgdLanguageLab20 extends StatefulWidget {
  final void Function(BookModels341)? onModels341;
  final void Function(bool)? onImportBusy341;''')
    s=sub(s,'  const MgdLanguageLab20({\n    super.key,', '''  const MgdLanguageLab20({
    super.key,
    this.onModels341,
    this.onImportBusy341,''')
    start=s.index('  String _decodeCorpusBytes(')
    end=s.index('  @override\n  Widget build(BuildContext context)',start)
    s=s[:start]+r'''
  BookModels341? _models341;
  MgdLanguageStats20? _stats341;
  bool _cancel341 = false;
  final _repaint341 = Stopwatch()..start();
  MgdLanguage20 get _language341 => _models341?.language ?? widget.language;
  ResearchMemory11 get _research341 => _models341?.research ?? widget.research;

  void _progress341(String message,{bool force=false}) {
    if (!mounted || (!force && _repaint341.elapsedMilliseconds < 200)) return;
    _repaint341.reset();
    setState(() => status=message);
  }
  @override
  void dispose() {
    _cancel341=true;
    text.dispose();
    super.dispose();
  }
  void _adopt341(BookModels341 models) {
    _models341=models;
    _stats341=models.language.stats();
    widget.onModels341?.call(models);
  }
  Future<void> _restore341() async {
    final maps=<String,Map<String,dynamic>>{};
    for(final key in ['brain_v051','world_v06','research_v11','language_v20']) {
      final map=await MgdStateStore26.instance.getMap(key);
      if(map==null) throw StateError('Checkpoint di recupero incompleto: $key');
      maps[key]=map;
    }
    final recovered=await Isolate.run(()=>BookModels341.fromMaps(maps));
    _adopt341(recovered);
  }
  Future<void> _import341(Future<File?> Function() select, String Function() source) async {
    if(busy) return;
    _cancel341=false;
    _stats341=_language341.stats();
    setState(()=>busy=true);
    File? staged;
    var suspended=false, restoreFailed=false;
    try {
      staged=await select();
      if(staged==null || _cancel341) {
        _progress341('Importazione annullata.',force:true); return;
      }
      // Drain older writes BEFORE the worker becomes the sole snapshot writer.
      await widget.onSave();
      widget.onImportBusy341?.call(true); suspended=true;
      final models=_models341 ?? BookModels341(widget.brain,widget.world,
        widget.research,widget.language);
      final result=await BookImporter341.run(file:staged,source:source(),models:models,
        cancelled:()=>_cancel341 || !mounted,
        checkpoint:MgdStateStore26.instance.putEncodedAtomic341,
        archive:(chunk,name) async {
          final store=ClsBridge340.active;
          if(store!=null) await store.importText(chunk,source:name,label:'testo');
        },
        progress:(blocks,chars,phase)=>_progress341('$phase: $blocks blocchi, $chars caratteri.'));
      _adopt341(result.models);
      _progress341('${result.cancelled ? 'Interrotto e salvato' : 'Libro elaborato e salvato'}: '
        '${result.blocks} blocchi, ${result.characters} caratteri. '
        '${result.skipped} blocchi già appresi, non ricontati. '
        '${result.oversized} frammenti lunghi conservati senza dedurne fatti. '
        'Il testo conservato non equivale a comprensione completa.',force:true);
    } catch(e,st) {
      if(suspended) {
        try { await _restore341(); }
        catch(recovery) {
          restoreFailed=true;
          _progress341('Importazione interrotta: $e. Recupero non completato: $recovery. '
            'Salvataggio automatico sospeso; non cancellare i dati.',force:true);
        }
      }
      if(!restoreFailed) _progress341('Importazione interrotta: $e. '
        'Le memorie salvate sono conservate; puoi riselezionare il libro per riprendere.',force:true);
      try {
        final directory=await getApplicationDocumentsDirectory();
        await File('${directory.path}/book-import-last-error.txt').writeAsString(
          '${DateTime.now().toIso8601String()}\n$e\n$st',flush:true);
      } catch(_) {}
    } finally {
      if(suspended && !restoreFailed) widget.onImportBusy341?.call(false);
      if(staged!=null) {
        try { await staged.delete(); } catch(_) {}
      }
      if(mounted) setState(()=>busy=false);
    }
  }
  Future<void> train(String data,{String? sourceName}) async {
    if(data.trim().isEmpty || busy) return;
    await _import341(() async {
      final dir=await getTemporaryDirectory();
      final file=File('${dir.path}/mgd-book-${DateTime.now().microsecondsSinceEpoch}.txt');
      await file.writeAsString(data,flush:true);
      return file;
    },()=>sourceName ?? 'testo incollato');
  }
  Future<void> pick() async {
    var source='Libro TXT';
    await _import341(() async {
      final result=await FilePicker.platform.pickFiles(type:FileType.any,
        allowMultiple:false,withData:false,withReadStream:true);
      if(result==null || result.files.isEmpty) return null;
      final selected=result.files.single;
      source=selected.name;
      BookText341.validateName(source);
      Stream<List<int>>? stream=selected.readStream;
      if(stream==null && selected.path!=null) stream=File(selected.path!).openRead();
      if(stream==null && selected.bytes!=null) stream=Stream.value(selected.bytes!);
      if(stream==null) throw StateError('Android non ha fornito un flusso leggibile.');
      final dir=await getTemporaryDirectory();
      final file=File('${dir.path}/mgd-book-${DateTime.now().microsecondsSinceEpoch}.txt');
      try {
        await BookText341.stage(stream,file,name:source,cancelled:()=>_cancel341,
          progress:(n)=>_progress341('Lettura di $source: $n byte, senza caricare tutto in RAM.'));
        return file;
      } catch(_) {
        if(await file.exists()) await file.delete();
        rethrow;
      }
    },()=>source);
  }

''' + s[end:]
    # Only the widget rendering is changed; the language model API remains intact.
    start=s.index('class _MgdLanguageLab20State')
    part=s[start:]
    part=part.replace('final s = widget.language.stats();','final s = _stats341 ??= _language341.stats();')
    part=part.replace('widget.research.claims.values.where','_research341.claims.values.where')
    part=sub(part,"                Text(status)","                Text(status, key: const ValueKey('book-import-status'))")
    part=sub(part,"              if (status.isNotEmpty) ...[",'''              if(busy) ...[
                const LinearProgressIndicator(),
                TextButton.icon(key:const ValueKey('book-import-cancel'),
                  onPressed:()=>setState(()=>_cancel341=true),
                  icon:const Icon(Icons.stop_circle_outlined),
                  label:const Text('Interrompi e conserva i progressi')),
              ],
              if (status.isNotEmpty) ...[''')
    s=s[:start]+part
    return s
patch('lib/mgd_language_v020.dart',language)

def main(s):
    s=sub(s,"import 'dart:async';", "import 'dart:async';\nimport 'book_import_v0341.dart';")
    s=sub(s,'  Future<void> _checkpoint319() async {',
      '  bool _bookImportBusy341 = false;\n\n  Future<void> _checkpoint319() async {\n    if (_bookImportBusy341) return;')
    s=sub(s,'                  onSave: _saveAllSilent22))))', '''                  onImportBusy341: (active) => _bookImportBusy341 = active,
                  onModels341: (models) {
                    _brain = models.brain;
                    _world = models.world;
                    _researchMemory = models.research;
                    _language20 = models.language;
                  },
                  onSave: _saveAllSilent22))))''')
    return s
patch('lib/main.dart',main)

def corpus(s):
    s=sub(s,'    String? sourceFamily,','    String? sourceFamily,\n    bool inlineExtraction341 = false,')
    s=sub(s,'    final claims = await compute(_extract321, doc);',
      '    final claims = inlineExtraction341 ? _extract321(doc) : await compute(_extract321, doc);')
    return s
patch('lib/corpus_semantic_bridge_v022.dart',corpus)

def state(s):
    start=s.index('  Future<Map<String,dynamic>?> getMap(String key) async{')
    end=s.index('  Future<void> putMap(',start)
    s=s[:start]+'''  Future<Map<String,dynamic>?> getMap(String key) async {
    final db=await _open();
    // Android CursorWindow has a per-row capacity: never select a whole large
    // BLOB. Read bounded slices from ONE consistent SQLite transaction.
    final payload=await db.transaction<Uint8List?>((tx) async {
      final size=await tx.rawQuery('SELECT length(payload) AS n FROM state_snapshots WHERE k=?',[key]);
      if(size.isEmpty) return null;
      final n=size.single['n'] as int;
      if(n<=0) throw StateError('Archivio $key presente ma vuoto.');
      final out=BytesBuilder(copy:false);
      for(var offset=0;offset<n;offset+=262144) {
        final rows=await tx.rawQuery('SELECT substr(payload,?,?) AS part FROM state_snapshots WHERE k=?',
          [offset+1,262144,key]);
        final part=rows.single['part'];
        if(part is! Uint8List || part.isEmpty) throw StateError('Archivio $key incompleto.');
        out.add(part);
      }
      final bytes=out.takeBytes();
      if(bytes.length!=n) throw StateError('Dimensione archivio $key incoerente.');
      return bytes;
    });
    return payload==null ? null : compute(_decodeBinary26,payload);
  }

  Future<void> putEncodedAtomic341(Map<String,Uint8List> encoded) async {
    final db=await _open();
    await db.transaction((tx) async {
      final batch=tx.batch(),stamp=DateTime.now().millisecondsSinceEpoch;
      for(final entry in encoded.entries) {
        batch.insert('state_snapshots',{'k':entry.key,'payload':entry.value,'updated_at':stamp},
          conflictAlgorithm:ConflictAlgorithm.replace);
      }
      await batch.commit(noResult:true);
    });
  }

''' +s[end:]
    return s
patch('lib/mgd_state_store_v026.dart',state)

def semantics(s):
    s=sub(s,'  static int processQueue(','''  // Bounded transient cache: a document is not split again for every sentence
  // or every 12 ms work slice. It is NOT duplicated into persisted snapshots.
  static final _queueSentenceCache341 = <String,List<String>>{};
  static int queueTokenizations341 = 0;
  static List<String> _queueSentences341(String key,String text) {
    final cached=_queueSentenceCache341[key];
    if(cached!=null) return cached;
    if(_queueSentenceCache341.length>=4) _queueSentenceCache341.remove(_queueSentenceCache341.keys.first);
    queueTokenizations341++;
    return _queueSentenceCache341[key]=WebKnowledgeExplorer11._sentences(text);
  }

  static int processQueue(''')
    s=sub(s,'      final sentences = WebKnowledgeExplorer11._sentences(doc.text);',
      "      final sentences = _queueSentences341('${q['key']}',doc.text);")
    return s
patch('lib/research_semantics_v0317.dart',semantics)
p=root/'lib/memory_runtime_v0319.dart';p.write_text(p.read_text().replace("mgdAppVersion319 = '0.34.0'","mgdAppVersion319 = '0.34.1'"))
p=root/'pubspec.yaml';p.write_text(p.read_text().replace('version: 0.34.0+66','version: 0.34.1+67'))
p=root/'integration_test/runtime_android_v0319_test.dart';p.write_text(p.read_text().replace('Memorie MGD 0.34.0','Memorie MGD 0.34.1'))
print('0.34.1 checked patches applied')
