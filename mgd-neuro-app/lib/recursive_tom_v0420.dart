// MGD Recursive Theory of Mind 0.42.0
// Second-order perspective memory kept separate from world facts and first-order beliefs.
// No source sentence is stored: only the attributed mental relation.
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'cognitive_core_v0400.dart';
import 'social_cognition_v0410.dart';

class RecursiveToMStore420 {
  final Database db;
  RecursiveToMStore420._(this.db);

  static Future<RecursiveToMStore420> open() async {
    final dir=await getApplicationDocumentsDirectory();
    return openAt('${dir.path}/mgd_recursive_tom_0420.db');
  }

  static Future<RecursiveToMStore420> openAt(String path,{DatabaseFactory? factory}) async {
    final f=factory??databaseFactory;
    final db=await f.openDatabase(path,options:OpenDatabaseOptions(
      version:1,
      onConfigure:(db) async {
        try { await db.rawQuery('PRAGMA journal_mode=WAL'); } catch(_){}
        await db.execute('PRAGMA synchronous=NORMAL');
      },
      onCreate:(db,_) async {
        await db.execute('CREATE TABLE nested_beliefs('
          'outer_holder TEXT NOT NULL, inner_holder TEXT NOT NULL, '
          'subject TEXT NOT NULL, predicate TEXT NOT NULL, object TEXT NOT NULL DEFAULT "", '
          'location TEXT NOT NULL DEFAULT "", negative INTEGER NOT NULL DEFAULT 0, '
          'confidence REAL NOT NULL, updated_at INTEGER NOT NULL, '
          'PRIMARY KEY(outer_holder,inner_holder,subject,predicate))');
        await db.execute('CREATE INDEX nested_holder_idx ON nested_beliefs(outer_holder,inner_holder,updated_at DESC)');
      },
    ));
    return RecursiveToMStore420._(db);
  }

  Future<void> close()=>db.close();

  Future<void> put({
    required String outer,
    required String inner,
    required String subject,
    required String predicate,
    String object='',
    String location='',
    bool negative=false,
    double confidence=.68,
  }) async {
    final o=entity410(outer), i=entity410(inner), s=entity410(subject),
      p=canon410(predicate), ob=entity410(object), l=canon410(location);
    if(o.isEmpty||i.isEmpty||s.isEmpty||p.isEmpty)return;
    final now=DateTime.now().millisecondsSinceEpoch;
    await db.transaction((tx) async {
      await tx.delete('nested_beliefs',
        where:'outer_holder=? AND inner_holder=? AND subject=? AND predicate=?',
        whereArgs:[o,i,s,p]);
      await tx.insert('nested_beliefs',{
        'outer_holder':o,'inner_holder':i,'subject':s,'predicate':p,
        'object':ob,'location':l,'negative':negative?1:0,
        'confidence':confidence.clamp(0.0,1.0),'updated_at':now,
      },conflictAlgorithm:ConflictAlgorithm.replace);
    });
  }

  Future<Map<String,dynamic>?> slot(
      String outer,String inner,String subject,String predicate) async {
    final rows=await db.query('nested_beliefs',
      where:'outer_holder=? AND inner_holder=? AND subject=? AND predicate=?',
      whereArgs:[entity410(outer),entity410(inner),entity410(subject),canon410(predicate)],
      orderBy:'confidence DESC,updated_at DESC',limit:1);
    return rows.isEmpty?null:Map<String,dynamic>.from(rows.single);
  }

  Future<int> count() async =>
    Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM nested_beliefs'))??0;

  Future<void> clear()=>db.delete('nested_beliefs');
}

class RecursiveTheoryOfMind420 {
  final RecursiveToMStore420 store;
  RecursiveTheoryOfMind420(this.store);

  Future<bool> observe(String text) async {
    final q=canon410(text);
    final m=RegExp(
      r'^(.+?)\s+(?:pensa|crede|ritiene)\s+che\s+(.+?)\s+'
      r'(?:pensa|crede|ritiene)\s+che\s+(.+)$'
    ).firstMatch(q);
    if(m==null)return false;
    final outer=m[1]!.trim(), inner=m[2]!.trim();
    final frame=FrameInducer400.induce(m[3]!);
    if(!frame.valid)return false;
    final predicate=frame.location.isNotEmpty?'luogo':frame.predicate;
    await store.put(
      outer:outer,inner:inner,subject:frame.subject,predicate:predicate,
      object:frame.location.isNotEmpty?'':frame.object,
      location:frame.location,negative:frame.negative,
    );
    return true;
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    final m=RegExp(
      r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(.+?)\s+'
      r'(?:pensi|creda|ritenga|pensa|crede|ritiene)\s+che\s+'
      r'(?:sia|si trovi|è|e)\s+(.+)$'
    ).firstMatch(q);
    if(m==null)return null;
    final outer=m[1]!.trim(), inner=m[2]!.trim(), target=entity410(m[3]!);
    final b=await store.slot(outer,inner,target,'luogo');
    if(b==null) {
      return 'Non ho ancora una credenza di secondo ordine sufficientemente rappresentata per questa domanda.';
    }
    return 'Nel modello mentale attribuito a ${_cap(outer)}, ${_cap(inner)} pensa che '
      '${_cap(target)} si trovi ${b['location']}. '
      'È una credenza su una credenza, distinta sia dallo stato reale sia dalla credenza diretta di ${_cap(outer)}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
