from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')

# Brain persistence: snapshot creation off the UI isolate and no full graph rebuild.
p = root / 'lib' / 'persistence.dart'
s = p.read_text()
if "import 'dart:isolate';" not in s:
    s = s.replace("import 'dart:io';\n", "import 'dart:io';\nimport 'dart:isolate';\n", 1)
old = """  Future<void> _drainSaves19() async {
    while (_saveQueued19 && _saveBrain19 != null) {
      _saveQueued19 = false;
      final brain = _saveBrain19!;
      final snapshot = brain.toJson();
      await MgdStateStore26.instance.putMap('brain_v051', snapshot);
      // Keep a normalized semantic graph index in SQLite for graph-native
      // navigation/search without reparsing a monolithic snapshot.
      final semantic=brain.semanticGraph(limit:10000000);
      unawaited(MgdStateStore26.instance.replaceGraph(
        space:'world',
        nodes:brain.entities.map((e)=>e.label),
        edges:semantic.map((e)=>(src:e.from,rel:e.relation,dst:e.to,weight:e.confidence)),
      ));
    }
  }
"""
new = """  Future<Map<String, dynamic>> _snapshot271(PlasticLanguageBrain04 brain) {
    // Build the large serializable snapshot in a worker isolate.
    return Isolate.run<Map<String, dynamic>>(() => brain.toJson());
  }

  Future<void> _drainSaves19() async {
    while (_saveQueued19 && _saveBrain19 != null) {
      _saveQueued19 = false;
      final brain = _saveBrain19!;
      final snapshot = await _snapshot271(brain);
      await MgdStateStore26.instance.putMap('brain_v051', snapshot);
      // 0.27.1: do not rebuild the complete semantic graph on every save.
      // The operation that introduces knowledge updates its graph delta.
    }
  }

  Future<void> saveWithProgress271(
    PlasticLanguageBrain04 brain, {
    void Function(String stage)? onStage,
  }) async {
    final active = _activeSave19;
    if (active != null) await active;
    onStage?.call('snapshot');
    final snapshot = await _snapshot271(brain);
    onStage?.call('database');
    await MgdStateStore26.instance.putMap('brain_v051', snapshot);
  }
"""
if old not in s:
    raise SystemExit('persistence _drain anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)

# World snapshot off the UI isolate.
p = root / 'lib' / 'world_persistence_v06.dart'
s = p.read_text()
if "import 'dart:isolate';" not in s:
    s = s.replace("import 'dart:io';\n", "import 'dart:io';\nimport 'dart:isolate';\n", 1)
old = """      _saveQueued19 = false;
      final snapshot = _saveWorld19!.toJson();
      await MgdStateStore26.instance.putMap('world_v06',snapshot);
"""
new = """      _saveQueued19 = false;
      final world = _saveWorld19!;
      final snapshot = await Isolate.run<Map<String, dynamic>>(() => world.toJson());
      await MgdStateStore26.instance.putMap('world_v06',snapshot);
"""
if old not in s:
    raise SystemExit('world persistence anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)

# SQLite/WAL graph delta updater in bounded batches.
p = root / 'lib' / 'mgd_state_store_v026.dart'
s = p.read_text()
anchor = """  Future<void> clearAll() async{
"""
method = """  Future<void> upsertGraphDelta271({
    required String space,
    required Iterable<String> nodes,
    required Iterable<({String src,String rel,String dst,double weight})> edges,
    int batchSize=256,
    void Function(int completed,int total)? onProgress,
  }) async{
    final db=await _open();
    final nodeList=nodes.where((x)=>x.trim().isNotEmpty).toSet().toList(growable:false);
    final edgeList=edges.toList(growable:false);
    final total=nodeList.length+edgeList.length;
    if(total==0){onProgress?.call(0,0);return;}
    var done=0;

    for(var i=0;i<nodeList.length;i+=batchSize){
      final end=(i+batchSize<nodeList.length)?i+batchSize:nodeList.length;
      await db.transaction((tx) async{
        final batch=tx.batch();
        for(var j=i;j<end;j++){
          batch.insert('graph_nodes',{'space':space,'node':nodeList[j],'weight':0.0},conflictAlgorithm:ConflictAlgorithm.ignore);
        }
        await batch.commit(noResult:true);
      });
      done+=end-i;
      onProgress?.call(done,total);
      await Future<void>.delayed(Duration.zero);
    }

    for(var i=0;i<edgeList.length;i+=batchSize){
      final end=(i+batchSize<edgeList.length)?i+batchSize:edgeList.length;
      await db.transaction((tx) async{
        final batch=tx.batch();
        for(var j=i;j<end;j++){
          final e=edgeList[j];
          batch.insert('graph_edges',{'space':space,'src':e.src,'rel':e.rel,'dst':e.dst,'weight':e.weight},conflictAlgorithm:ConflictAlgorithm.replace);
        }
        await batch.commit(noResult:true);
      });
      done+=end-i;
      onProgress?.call(done,total);
      await Future<void>.delayed(Duration.zero);
    }
  }

"""
if 'upsertGraphDelta271' not in s:
    if anchor not in s:
        raise SystemExit('state store clearAll anchor missing')
    s = s.replace(anchor, method + anchor, 1)
p.write_text(s)

# Main UI: explicit Snapshot -> DB -> Graph -> completed flow.
p = root / 'lib' / 'main.dart'
s = p.read_text()
if "import 'mgd_state_store_v026.dart';" not in s:
    s = s.replace("import 'cognitive_induction_v024.dart';\n", "import 'cognitive_induction_v024.dart';\nimport 'mgd_state_store_v026.dart';\n", 1)

s = s.replace("MGD Neuro 0.27", "MGD Neuro 0.27.1")
s = s.replace("memoria MGD 0.27 • SQLite WAL", "memoria MGD 0.27.1 • SQLite WAL")
s = s.replace("Memorie MGD 0.27", "Memorie MGD 0.27.1")

anchor = """  Future<void> _importTeacherPack08() async {
"""
helper = """  Future<void> _saveTeacherImport271(
    TeacherPack08 pack,
    TeacherImportResult08 result,
  ) async {
    final sw=Stopwatch()..start();
    var stage='snapshot';

    void show(String text){
      if(!mounted)return;
      setState(()=>_status=text);
    }

    await _persistence.saveWithProgress271(
      _brain,
      onStage:(next){
        stage=next;
        if(next=='snapshot'){
          show('Salvataggio • 1/4 • snapshot cervello in background…');
        }else{
          show('Salvataggio • 2/4 • scrittura SQLite/WAL…');
        }
      },
    );

    if(stage!='database')show('Salvataggio • 2/4 • scrittura SQLite/WAL…');
    await Future.wait<void>([
      _worldPersistence.save(_world),
      _researchPersistence.save(_researchMemory),
      _languagePersistence20.save(_language20),
    ]);

    final graphNodes=<String>{};
    final graphEdges=<({String src,String rel,String dst,double weight})>[];
    for(final f in pack.facts){
      final a=f.subject.trim();
      final b=f.object.trim();
      if(a.isEmpty||b.isEmpty)continue;
      graphNodes..add(a)..add(b);
      graphEdges.add((src:a,rel:f.relation.trim(),dst:b,weight:f.confidence));
    }

    show('Salvataggio • 3/4 • indice grafo incrementale…');
    var lastPercent=-1;
    await MgdStateStore26.instance.upsertGraphDelta271(
      space:'world',
      nodes:graphNodes,
      edges:graphEdges,
      batchSize:256,
      onProgress:(done,total){
        if(!mounted)return;
        final percent=total==0?100:((done*100)/total).floor();
        if(percent==lastPercent && done!=total)return;
        lastPercent=percent;
        setState(()=>_status='Salvataggio • 3/4 • grafo '+done.toString()+'/'+total.toString()+' • '+percent.toString()+'%');
      },
    );

    sw.stop();
    show(
      'Salvataggio • 4/4 • completato in '+
      (sw.elapsedMilliseconds/1000).toStringAsFixed(1)+
      ' s • Teacher '+result.model+': '+
      result.facts.toString()+' fatti + '+
      result.links.toString()+' legami importati'
    );
  }

"""
if '_saveTeacherImport271(' not in s:
    if anchor not in s:
        raise SystemExit('main import method anchor missing')
    s = s.replace(anchor, helper + anchor, 1)

old = """      // Let the completed-import frame reach Android before snapshot creation.
      // The coalescing persistence layer will still make the import durable.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 120), () async {
        await _save(
          'Teacher ' +
              result.model +
              ': ' +
              result.facts.toString() +
              ' fatti + ' +
              result.links.toString() +
              ' legami latenti importati',
        );
      }));
"""
new = """      // Persist in visible stages. Snapshot generation runs off the UI isolate,
      // and only this pack's graph delta is written.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _saveTeacherImport271(pack,result);
"""
if old not in s:
    raise SystemExit('main old background save anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)

p = root / 'pubspec.yaml'
s = p.read_text()
if 'version: 0.27.0+42' not in s:
    raise SystemExit('pubspec version anchor missing')
s = s.replace('version: 0.27.0+42','version: 0.27.1+43',1)
p.write_text(s)

print('MGD Neuro 0.27.1 persistence patch applied')
