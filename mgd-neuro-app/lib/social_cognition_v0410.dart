// MGD Social Cognition 0.41.0
// Persistent first-order theory-of-mind: world state is kept separate from
// each agent's beliefs, goals and observations. No external LLM is used.
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'cognitive_core_v0400.dart';

String canon410(String x) => norm400(x)
    .replaceAll(RegExp(r'[?!.;,:"«»]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String entity410(String x) => canon410(x)
    .replaceFirst(RegExp(r'^(?:il|lo|la|i|gli|le|un|uno|una)\s+'), '')
    .trim();

class MentalBelief410 {
  final String holder, subject, predicate, object, location, source;
  final bool negative;
  final double confidence;
  const MentalBelief410({
    required this.holder,
    required this.subject,
    required this.predicate,
    required this.object,
    required this.location,
    required this.negative,
    required this.confidence,
    required this.source,
  });
  Map<String,dynamic> toJson()=> {
    'holder':holder,'subject':subject,'predicate':predicate,'object':object,
    'location':location,'negative':negative,'confidence':confidence,'source':source,
  };
}

class SocialStore410 {
  final Database db;
  SocialStore410._(this.db);

  static Future<SocialStore410> open() async {
    final dir=await getApplicationDocumentsDirectory();
    return openAt('${dir.path}/mgd_social_cognition_0410.db');
  }

  static Future<SocialStore410> openAt(String path,{DatabaseFactory? factory}) async {
    final f=factory??databaseFactory;
    final db=await f.openDatabase(path,options:OpenDatabaseOptions(
      version:1,
      onConfigure:(db) async {
        try { await db.rawQuery('PRAGMA journal_mode=WAL'); } catch(_){}
        await db.execute('PRAGMA synchronous=NORMAL');
      },
      onCreate:(db,_) async {
        await db.execute('CREATE TABLE agents(name TEXT PRIMARY KEY,present INTEGER NOT NULL DEFAULT 1,location TEXT NOT NULL DEFAULT "",first_seen INTEGER NOT NULL,last_seen INTEGER NOT NULL)');
        await db.execute('CREATE TABLE beliefs(holder TEXT NOT NULL,subject TEXT NOT NULL,predicate TEXT NOT NULL,object TEXT NOT NULL DEFAULT "",location TEXT NOT NULL DEFAULT "",negative INTEGER NOT NULL DEFAULT 0,confidence REAL NOT NULL,source TEXT NOT NULL,updated_at INTEGER NOT NULL,PRIMARY KEY(holder,subject,predicate,object,location,negative))');
        await db.execute('CREATE INDEX beliefs_holder_idx ON beliefs(holder,updated_at DESC)');
        await db.execute('CREATE INDEX beliefs_subject_idx ON beliefs(subject,predicate,updated_at DESC)');
        await db.execute('CREATE TABLE goals(holder TEXT NOT NULL,goal TEXT NOT NULL,confidence REAL NOT NULL,source TEXT NOT NULL,updated_at INTEGER NOT NULL,PRIMARY KEY(holder,goal))');
        await db.execute('CREATE TABLE observations(id INTEGER PRIMARY KEY AUTOINCREMENT,observer TEXT NOT NULL,subject TEXT NOT NULL,predicate TEXT NOT NULL,object TEXT NOT NULL DEFAULT "",location TEXT NOT NULL DEFAULT "",at INTEGER NOT NULL)');
        await db.execute('CREATE INDEX observations_observer_idx ON observations(observer,at DESC)');
        await db.execute('CREATE TABLE social_meta(k TEXT PRIMARY KEY,v TEXT NOT NULL)');
      },
    ));
    // Extensions are created lazily so existing 0.41 databases migrate
    // without destructive version changes.
    await db.execute('CREATE TABLE IF NOT EXISTS nested_beliefs(holder TEXT NOT NULL,about_holder TEXT NOT NULL,subject TEXT NOT NULL,predicate TEXT NOT NULL,object TEXT NOT NULL DEFAULT "",location TEXT NOT NULL DEFAULT "",negative INTEGER NOT NULL DEFAULT 0,confidence REAL NOT NULL,source TEXT NOT NULL,updated_at INTEGER NOT NULL,PRIMARY KEY(holder,about_holder,subject,predicate,object,location,negative))');
    await db.execute('CREATE INDEX IF NOT EXISTS nested_beliefs_holder_idx ON nested_beliefs(holder,about_holder,updated_at DESC)');
    return SocialStore410._(db);
  }

  Future<void> close()=>db.close();

  Future<void> ensureAgent(String name,{bool? present,String location=''}) async {
    final n=canon410(name);
    if(n.isEmpty) return;
    final now=DateTime.now().millisecondsSinceEpoch;
    await db.rawInsert(
      'INSERT INTO agents(name,present,location,first_seen,last_seen) VALUES(?,?,?,?,?) '
      'ON CONFLICT(name) DO UPDATE SET last_seen=excluded.last_seen'
      '${present==null?'':',present=excluded.present'}'
      '${location.isEmpty?'':',location=excluded.location'}',
      [n,present==false?0:1,location,now,now]);
  }

  Future<void> setPresence(String name,bool present,{String location=''}) async {
    await ensureAgent(name);
    final now=DateTime.now().millisecondsSinceEpoch;
    await db.update('agents',{'present':present?1:0,'location':location,'last_seen':now},where:'name=?',whereArgs:[canon410(name)]);
  }

  Future<Set<String>> presentAgents() async {
    final rows=await db.query('agents',columns:['name'],where:'present=1');
    return rows.map((r)=>'${r['name']}').toSet();
  }

  Future<void> putBelief(MentalBelief410 b,{bool replaceSlot=true}) async {
    final h=canon410(b.holder), s=canon410(b.subject), p=canon410(b.predicate),
      o=canon410(b.object), l=canon410(b.location);
    if(h.isEmpty||s.isEmpty||p.isEmpty) return;
    final now=DateTime.now().millisecondsSinceEpoch;
    await ensureAgent(h);
    await db.transaction((tx) async {
      if(replaceSlot) {
        // A belief about a mutable slot replaces the holder's older version,
        // while a different holder may still retain the obsolete state.
        await tx.delete('beliefs',where:'holder=? AND subject=? AND predicate=?',
          whereArgs:[h,s,p]);
      }
      await tx.insert('beliefs',{
        'holder':h,'subject':s,'predicate':p,'object':o,'location':l,
        'negative':b.negative?1:0,'confidence':b.confidence.clamp(0.0,1.0),
        'source':b.source,'updated_at':now,
      },conflictAlgorithm:ConflictAlgorithm.replace);
    });
  }

  Future<List<MentalBelief410>> beliefsOf(String holder,{String? about,int limit=20}) async {
    final h=canon410(holder);
    final a=about==null?'':canon410(about);
    final rows=await db.query('beliefs',
      where:a.isEmpty?'holder=?':'holder=? AND (subject LIKE ? OR object LIKE ? OR location LIKE ?)',
      whereArgs:a.isEmpty?[h]:[h,'%$a%','%$a%','%$a%'],
      orderBy:'confidence DESC,updated_at DESC',limit:limit);
    return rows.map((r)=>MentalBelief410(
      holder:'${r['holder']}',subject:'${r['subject']}',predicate:'${r['predicate']}',
      object:'${r['object']}',location:'${r['location']}',negative:(r['negative'] as int)==1,
      confidence:(r['confidence'] as num).toDouble(),source:'${r['source']}')).toList();
  }

  Future<MentalBelief410?> beliefSlot(String holder,String subject,String predicate) async {
    final rows=await db.query('beliefs',where:'holder=? AND subject=? AND predicate=?',
      whereArgs:[canon410(holder),canon410(subject),canon410(predicate)],
      orderBy:'confidence DESC,updated_at DESC',limit:1);
    if(rows.isEmpty)return null;
    final r=rows.single;
    return MentalBelief410(holder:'${r['holder']}',subject:'${r['subject']}',
      predicate:'${r['predicate']}',object:'${r['object']}',location:'${r['location']}',
      negative:(r['negative'] as int)==1,confidence:(r['confidence'] as num).toDouble(),
      source:'${r['source']}');
  }

  Future<void> putGoal(String holder,String goal,{double confidence=.8,String source='osservato'}) async {
    final h=canon410(holder),g=canon410(goal);
    if(h.isEmpty||g.isEmpty)return;
    await ensureAgent(h);
    await db.insert('goals',{'holder':h,'goal':g,'confidence':confidence.clamp(0.0,1.0),
      'source':source,'updated_at':DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<List<Map<String,dynamic>>> goalsOf(String holder,{int limit=8}) async =>
    (await db.query('goals',where:'holder=?',whereArgs:[canon410(holder)],
      orderBy:'confidence DESC,updated_at DESC',limit:limit)).map((e)=>Map<String,dynamic>.from(e)).toList();

  Future<void> observe(String observer,CognitiveFrame400 frame) async {
    if(observer.isEmpty||!frame.valid)return;
    final now=DateTime.now().millisecondsSinceEpoch;
    await db.insert('observations',{
      'observer':canon410(observer),'subject':frame.subject,'predicate':frame.predicate,
      'object':frame.object,'location':frame.location,'at':now});
  }

  Future<void> putNestedBelief({
    required String holder,
    required String aboutHolder,
    required String subject,
    required String predicate,
    String object='',
    String location='',
    bool negative=false,
    double confidence=.70,
    String source='attribuzione annidata',
  }) async {
    final h=entity410(holder), a=entity410(aboutHolder), s=entity410(subject),
      p=canon410(predicate), o=entity410(object), l=canon410(location);
    if(h.isEmpty||a.isEmpty||s.isEmpty||p.isEmpty)return;
    final now=DateTime.now().millisecondsSinceEpoch;
    await ensureAgent(h); await ensureAgent(a);
    await db.transaction((tx) async {
      await tx.delete('nested_beliefs',
        where:'holder=? AND about_holder=? AND subject=? AND predicate=?',
        whereArgs:[h,a,s,p]);
      await tx.insert('nested_beliefs',{
        'holder':h,'about_holder':a,'subject':s,'predicate':p,'object':o,
        'location':l,'negative':negative?1:0,'confidence':confidence.clamp(0.0,1.0),
        'source':source,'updated_at':now,
      },conflictAlgorithm:ConflictAlgorithm.replace);
    });
  }

  Future<Map<String,dynamic>?> nestedBeliefSlot(
      String holder,String aboutHolder,String subject,String predicate) async {
    final rows=await db.query('nested_beliefs',
      where:'holder=? AND about_holder=? AND subject=? AND predicate=?',
      whereArgs:[entity410(holder),entity410(aboutHolder),entity410(subject),canon410(predicate)],
      orderBy:'confidence DESC,updated_at DESC',limit:1);
    return rows.isEmpty?null:Map<String,dynamic>.from(rows.single);
  }

  Future<void> setMeta(String key,String value) async {
    await db.insert('social_meta',{'k':key,'v':value},conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<String?> getMeta(String key) async {
    final rows=await db.query('social_meta',columns:['v'],where:'k=?',whereArgs:[key],limit:1);
    return rows.isEmpty?null:'${rows.single['v']}';
  }

  Future<Map<String,dynamic>> stats() async {
    Future<int> n(String table) async => Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table'))??0;
    return {'agents':await n('agents'),'beliefs':await n('beliefs'),'nestedBeliefs':await n('nested_beliefs'),'goals':await n('goals'),'observations':await n('observations')};
  }

  Future<void> clear() async {
    await db.transaction((tx) async {
      for(final t in ['agents','beliefs','nested_beliefs','goals','observations','social_meta']){await tx.delete(t);}
    });
  }
}

class TheoryOfMind410 {
  final SocialStore410 store;
  TheoryOfMind410(this.store);

  static bool _isLeave(String p)=>p.startsWith('esc')||p.startsWith('part');
  static bool _isEnter(String p)=>p.startsWith('entr')||p.startsWith('arriv')||p.startsWith('torn');
  static bool _isLocationChange(CognitiveFrame400 f)=>f.location.isNotEmpty &&
      (f.object.isNotEmpty||_isEnter(f.predicate)||f.predicate.startsWith('and'));

  Future<void> experience(String sentence,CognitiveFrame400 frame) async {
    if(!frame.valid)return;
    final actor=canon410(frame.subject);
    if(actor.isEmpty)return;

    if(_isEnter(frame.predicate)) {
      await store.setPresence(actor,true,location:frame.location);
    } else {
      await store.ensureAgent(actor,present:true);
    }

    final observers=await store.presentAgents();
    observers.add(actor);
    for(final observer in observers) {
      await store.observe(observer,frame);
      if(_isLocationChange(frame)) {
        final target=frame.object.isNotEmpty?frame.object:frame.subject;
        await store.putBelief(MentalBelief410(
          holder:observer,subject:target,predicate:'luogo',object:'',
          location:frame.location,negative:frame.negative,confidence:.92,source:'osservazione'));
      } else {
        await store.putBelief(MentalBelief410(
          holder:observer,subject:frame.subject,predicate:frame.predicate,
          object:frame.object,location:frame.location,negative:frame.negative,
          confidence:.88,source:'osservazione'));
      }
    }
    if(_isLeave(frame.predicate)) await store.setPresence(actor,false);

    final q=canon410(sentence);
    final secondOrder=RegExp(r'^(.+?)\s+(?:pensa|crede|ritiene)\s+che\s+(.+?)\s+(?:pensa|crede|ritiene)\s+che\s+(.+)
    if(explicit!=null) {
      final holder=explicit[1]!.trim();
      final inner=FrameInducer400.induce(explicit[2]!);
      if(inner.valid) {
        await store.putBelief(MentalBelief410(holder:holder,subject:inner.subject,
          predicate:inner.location.isNotEmpty&&inner.object.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty&&inner.object.isNotEmpty?'':inner.object,
          location:inner.location,negative:inner.negative,
          confidence:q.contains(' sa che ')?1.0:.76,source:'attribuzione esplicita'));
      }
    }
    final desire=RegExp(r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$').firstMatch(q);
    if(desire!=null) await store.putGoal(desire[1]!,desire[2]!,confidence:.82,source:'attribuzione esplicita');
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    var nested=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(.+?)\s+(?:pensi|creda|ritenga|pensa|crede|ritiene)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q);
    if(secondOrder!=null) {
      final outer=secondOrder[1]!.trim(), innerHolder=secondOrder[2]!.trim();
      final inner=FrameInducer400.induce(secondOrder[3]!);
      if(inner.valid) {
        await store.putNestedBelief(
          holder:outer,aboutHolder:innerHolder,subject:inner.subject,
          predicate:inner.location.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty?'':inner.object,location:inner.location,
          negative:inner.negative,confidence:.68,source:'attribuzione esplicita di secondo ordine');
      }
    }
    final explicit=secondOrder==null
      ? RegExp(r'^(.+?)\s+(?:pensa|crede|ritiene|sa)\s+che\s+(.+)
    if(explicit!=null) {
      final holder=explicit[1]!.trim();
      final inner=FrameInducer400.induce(explicit[2]!);
      if(inner.valid) {
        await store.putBelief(MentalBelief410(holder:holder,subject:inner.subject,
          predicate:inner.location.isNotEmpty&&inner.object.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty&&inner.object.isNotEmpty?'':inner.object,
          location:inner.location,negative:inner.negative,
          confidence:q.contains(' sa che ')?1.0:.76,source:'attribuzione esplicita'));
      }
    }
    final desire=RegExp(r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$').firstMatch(q);
    if(desire!=null) await store.putGoal(desire[1]!,desire[2]!,confidence:.82,source:'attribuzione esplicita');
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    var m=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q)
      : null;
    if(explicit!=null) {
      final holder=explicit[1]!.trim();
      final inner=FrameInducer400.induce(explicit[2]!);
      if(inner.valid) {
        await store.putBelief(MentalBelief410(holder:holder,subject:inner.subject,
          predicate:inner.location.isNotEmpty&&inner.object.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty&&inner.object.isNotEmpty?'':inner.object,
          location:inner.location,negative:inner.negative,
          confidence:q.contains(' sa che ')?1.0:.76,source:'attribuzione esplicita'));
      }
    }
    final desire=RegExp(r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$').firstMatch(q);
    if(desire!=null) await store.putGoal(desire[1]!,desire[2]!,confidence:.82,source:'attribuzione esplicita');
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    var m=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q);
    if(nested!=null) {
      final outer=nested[1]!, inner=nested[2]!, target=entity410(nested[3]!);
      final b=await store.nestedBeliefSlot(outer,inner,target,'luogo');
      if(b==null)return 'Non ho ancora una credenza di secondo ordine sufficientemente rappresentata per questa domanda.';
      return 'Nel modello mentale attribuito a ${_cap(outer)}, ${_cap(inner)} pensa che ${_cap(target)} si trovi ${b['location']}. '
          'È una credenza su una credenza, non lo stato reale.';
    }
    var m=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q);
    if(secondOrder!=null) {
      final outer=secondOrder[1]!.trim(), innerHolder=secondOrder[2]!.trim();
      final inner=FrameInducer400.induce(secondOrder[3]!);
      if(inner.valid) {
        await store.putNestedBelief(
          holder:outer,aboutHolder:innerHolder,subject:inner.subject,
          predicate:inner.location.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty?'':inner.object,location:inner.location,
          negative:inner.negative,confidence:.68,source:'attribuzione esplicita di secondo ordine');
      }
    }
    final explicit=secondOrder==null
      ? RegExp(r'^(.+?)\s+(?:pensa|crede|ritiene|sa)\s+che\s+(.+)
    if(explicit!=null) {
      final holder=explicit[1]!.trim();
      final inner=FrameInducer400.induce(explicit[2]!);
      if(inner.valid) {
        await store.putBelief(MentalBelief410(holder:holder,subject:inner.subject,
          predicate:inner.location.isNotEmpty&&inner.object.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty&&inner.object.isNotEmpty?'':inner.object,
          location:inner.location,negative:inner.negative,
          confidence:q.contains(' sa che ')?1.0:.76,source:'attribuzione esplicita'));
      }
    }
    final desire=RegExp(r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$').firstMatch(q);
    if(desire!=null) await store.putGoal(desire[1]!,desire[2]!,confidence:.82,source:'attribuzione esplicita');
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    var m=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q)
      : null;
    if(explicit!=null) {
      final holder=explicit[1]!.trim();
      final inner=FrameInducer400.induce(explicit[2]!);
      if(inner.valid) {
        await store.putBelief(MentalBelief410(holder:holder,subject:inner.subject,
          predicate:inner.location.isNotEmpty&&inner.object.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty&&inner.object.isNotEmpty?'':inner.object,
          location:inner.location,negative:inner.negative,
          confidence:q.contains(' sa che ')?1.0:.76,source:'attribuzione esplicita'));
      }
    }
    final desire=RegExp(r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$').firstMatch(q);
    if(desire!=null) await store.putGoal(desire[1]!,desire[2]!,confidence:.82,source:'attribuzione esplicita');
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    var m=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q);
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q);
    if(secondOrder!=null) {
      final outer=secondOrder[1]!.trim(), innerHolder=secondOrder[2]!.trim();
      final inner=FrameInducer400.induce(secondOrder[3]!);
      if(inner.valid) {
        await store.putNestedBelief(
          holder:outer,aboutHolder:innerHolder,subject:inner.subject,
          predicate:inner.location.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty?'':inner.object,location:inner.location,
          negative:inner.negative,confidence:.68,source:'attribuzione esplicita di secondo ordine');
      }
    }
    final explicit=secondOrder==null
      ? RegExp(r'^(.+?)\s+(?:pensa|crede|ritiene|sa)\s+che\s+(.+)
    if(explicit!=null) {
      final holder=explicit[1]!.trim();
      final inner=FrameInducer400.induce(explicit[2]!);
      if(inner.valid) {
        await store.putBelief(MentalBelief410(holder:holder,subject:inner.subject,
          predicate:inner.location.isNotEmpty&&inner.object.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty&&inner.object.isNotEmpty?'':inner.object,
          location:inner.location,negative:inner.negative,
          confidence:q.contains(' sa che ')?1.0:.76,source:'attribuzione esplicita'));
      }
    }
    final desire=RegExp(r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$').firstMatch(q);
    if(desire!=null) await store.putGoal(desire[1]!,desire[2]!,confidence:.82,source:'attribuzione esplicita');
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    var m=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
).firstMatch(q)
      : null;
    if(explicit!=null) {
      final holder=explicit[1]!.trim();
      final inner=FrameInducer400.induce(explicit[2]!);
      if(inner.valid) {
        await store.putBelief(MentalBelief410(holder:holder,subject:inner.subject,
          predicate:inner.location.isNotEmpty&&inner.object.isNotEmpty?'luogo':inner.predicate,
          object:inner.location.isNotEmpty&&inner.object.isNotEmpty?'':inner.object,
          location:inner.location,negative:inner.negative,
          confidence:q.contains(' sa che ')?1.0:.76,source:'attribuzione esplicita'));
      }
    }
    final desire=RegExp(r'^(.+?)\s+(?:vuole|desidera|spera di)\s+(.+)$').firstMatch(q);
    if(desire!=null) await store.putGoal(desire[1]!,desire[2]!,confidence:.82,source:'attribuzione esplicita');
  }

  Future<String?> answer(String question) async {
    final q=canon410(question);
    var m=RegExp(r'^dove\s+(?:pensa|crede|ritiene)\s+(.+?)\s+che\s+(?:sia|si trovi|è|e)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final holder=m[1]!,target=m[2]!;
      final b=await store.beliefSlot(holder,entity410(target),'luogo');
      if(b==null)return '${_cap(holder)} non ha ancora una credenza rappresentata sulla posizione di ${_cap(target)}.';
      return 'Dal punto di vista di ${_cap(holder)}, ${_cap(target)} si trova ${b.location}. '
          'Questa è una credenza attribuita a ${_cap(holder)}, non necessariamente lo stato reale.';
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+?)\s+(?:di|su)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!,about=m[2]!;
      final bs=await store.beliefsOf(h,about:about,limit:6);
      if(bs.isEmpty)return 'Non ho ancora abbastanza evidenza per attribuire a ${_cap(h)} una credenza su ${_cap(about)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:pensa|crede|sa)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!;
      final bs=await store.beliefsOf(h,limit:6);
      if(bs.isEmpty)return 'Non ho ancora un modello mentale sufficientemente ricco di ${_cap(h)}.';
      return _beliefSummary(h,bs);
    }

    m=RegExp(r'^(?:cosa|che cosa)\s+(?:vuole|desidera)\s+(.+)$').firstMatch(q);
    if(m!=null) {
      final h=m[1]!, gs=await store.goalsOf(h);
      if(gs.isEmpty)return 'Non ho ancora un obiettivo attribuito a ${_cap(h)}.';
      return '${_cap(h)} risulta orientato soprattutto verso: ${gs.map((g)=>g['goal']).join('; ')}.';
    }
    return null;
  }

  static String _beliefSummary(String holder,List<MentalBelief410> bs) {
    String render(MentalBelief410 b) {
      if(b.predicate=='luogo') return '${_cap(b.subject)} → luogo → ${b.location}';
      return '${_cap(b.subject)} → ${b.negative?'non ':''}${b.predicate} → ${b.object}';
    }
    return 'Nel modello mentale attribuito a ${_cap(holder)} risultano: ${bs.map(render).join('; ')}.';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}
