import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Uint8List _encodeBinary26(Map<String,dynamic> map){
  final data=const StandardMessageCodec().encodeMessage(map);
  if(data==null)return Uint8List(0);
  return data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes);
}

dynamic _normalizeDecoded26(dynamic value){
  if(value is Map){
    return <String,dynamic>{for(final e in value.entries)e.key.toString():_normalizeDecoded26(e.value)};
  }
  if(value is List)return value.map(_normalizeDecoded26).toList();
  return value;
}

Map<String,dynamic> _decodeBinary26(Uint8List bytes){
  final bd=ByteData.sublistView(bytes);
  final raw=const StandardMessageCodec().decodeMessage(bd);
  return Map<String,dynamic>.from(_normalizeDecoded26(raw) as Map);
}

class MgdStateStore26{
  MgdStateStore26._();
  static final MgdStateStore26 instance=MgdStateStore26._();
  Database? _db;
  Future<Database>? _opening;

  Future<Database> _open(){
    final ready=_db;
    if(ready!=null && ready.isOpen)return Future.value(ready);
    _db=null;
    return _opening??=_openInner().whenComplete(()=>_opening=null);
  }

  Future<Database> _openInner() async{
    final dir=await getApplicationDocumentsDirectory();
    final db=await openDatabase(
      '${dir.path}/mgd_neuro_v026.db',
      version:1,
      onConfigure:(db) async{
        // IMPORTANT on Android: journal_mode is a row-returning PRAGMA.
        // execute()/execSQL() throws:
        // "Queries can be performed using SQLiteDatabase query or rawQuery methods only."
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=NORMAL');
        await db.execute('PRAGMA temp_store=MEMORY');
        await db.execute('PRAGMA foreign_keys=ON');
      },
      onCreate:(db,_) async{
        await db.execute('CREATE TABLE state_snapshots (k TEXT PRIMARY KEY, payload BLOB NOT NULL, updated_at INTEGER NOT NULL)');
        await db.execute('CREATE TABLE graph_nodes (space TEXT NOT NULL, node TEXT NOT NULL, weight REAL NOT NULL DEFAULT 0, PRIMARY KEY(space,node))');
        await db.execute('CREATE TABLE graph_edges (space TEXT NOT NULL, src TEXT NOT NULL, rel TEXT NOT NULL, dst TEXT NOT NULL, weight REAL NOT NULL, PRIMARY KEY(space,src,rel,dst))');
        await db.execute('CREATE INDEX graph_edges_src_idx ON graph_edges(space,src)');
        await db.execute('CREATE INDEX graph_edges_dst_idx ON graph_edges(space,dst)');
      },
    );
    _db=db;
    return db;
  }

  Future<Map<String,dynamic>?> getMap(String key) async{
    final db=await _open();
    final rows=await db.query('state_snapshots',columns:['payload'],where:'k=?',whereArgs:[key],limit:1);
    if(rows.isEmpty)return null;
    final payload=rows.first['payload'];
    if(payload is! Uint8List || payload.isEmpty)throw StateError('Archivio $key presente ma non decodificabile. Scrittura sospesa.');
    return compute(_decodeBinary26,payload);
  }

  Future<void> putMap(String key,Map<String,dynamic> map) async{
    final payload=await compute(_encodeBinary26,map);
    final db=await _open();
    await db.insert('state_snapshots',{'k':key,'payload':payload,'updated_at':DateTime.now().millisecondsSinceEpoch},conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<void> putMapsAtomic319(Map<String,Map<String,dynamic>> maps) async {
    final encoded=<String,Uint8List>{};
    for(final entry in maps.entries) {
      encoded[entry.key]=await compute(_encodeBinary26,entry.value);
    }
    final db=await _open();
    await db.transaction((tx) async {
      final batch=tx.batch();
      final stamp=DateTime.now().millisecondsSinceEpoch;
      for(final e in encoded.entries) {
        batch.insert('state_snapshots',{'k':e.key,'payload':e.value,'updated_at':stamp},conflictAlgorithm:ConflictAlgorithm.replace);
      }
      await batch.commit(noResult:true);
    });
  }

  Future<void> close319() async {
    final db=_db; _db=null;
    if(db!=null && db.isOpen)await db.close();
  }

  Future<void> deleteKey(String key) async{
    final db=await _open();
    await db.delete('state_snapshots',where:'k=?',whereArgs:[key]);
  }

  Future<void> replaceGraph({required String space,required Iterable<String> nodes,required Iterable<({String src,String rel,String dst,double weight})> edges}) async{
    final db=await _open();
    await db.transaction((tx) async{
      await tx.delete('graph_edges',where:'space=?',whereArgs:[space]);
      await tx.delete('graph_nodes',where:'space=?',whereArgs:[space]);
      final batch=tx.batch();
      for(final n in nodes){
        batch.insert('graph_nodes',{'space':space,'node':n,'weight':0.0},conflictAlgorithm:ConflictAlgorithm.ignore);
      }
      for(final e in edges){
        batch.insert('graph_edges',{'space':space,'src':e.src,'rel':e.rel,'dst':e.dst,'weight':e.weight},conflictAlgorithm:ConflictAlgorithm.replace);
      }
      await batch.commit(noResult:true);
    });
  }

  Future<void> upsertGraphDelta271({
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

  Future<void> clearAll() async{
    final db=await _open();
    await db.transaction((tx) async{
      await tx.delete('state_snapshots');
      await tx.delete('graph_edges');
      await tx.delete('graph_nodes');
    });
  }
}
