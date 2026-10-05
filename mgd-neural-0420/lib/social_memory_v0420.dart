// MGD Social Cognition 0.41.0
// Persistent first-order theory-of-mind: world state is kept separate from
// each agent's beliefs, goals and observations. No external LLM is used.
import 'package:sqflite/sqflite.dart';

import 'cognitive_frame_v0420.dart';

String canon410(String x) => norm420(x)
    .replaceAll(RegExp(r'[?!.;,:"«»]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String entity410(String x) => canon410(x)
    .replaceFirst(RegExp(r'^(?:il|lo|la|i|gli|le|un|uno|una)\s+'), '')
    .trim();

class MentalBelief410 {
  final String holder, subject, predicate, object, location, source;
  final bool negative;
  const MentalBelief410({
    required this.holder,
    required this.subject,
    required this.predicate,
    required this.object,
    required this.location,
    required this.negative,
    required this.source,
  });
  Map<String,dynamic> toJson()=> {
    'holder':holder,'subject':subject,'predicate':predicate,'object':object,
    'location':location,'negative':negative,'source':source,
  };
}

class SocialStore410 {
  final Database db;
  SocialStore410._(this.db);

  /// Social attribution shares the canonical database. No probability scores
  /// are fabricated from the presence of a statement.
  static Future<SocialStore410> usingDatabase(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS agents(name TEXT PRIMARY KEY,present INTEGER NOT NULL DEFAULT 1,location TEXT NOT NULL DEFAULT "",first_seen INTEGER NOT NULL,last_seen INTEGER NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS beliefs(holder TEXT NOT NULL,subject TEXT NOT NULL,predicate TEXT NOT NULL,object TEXT NOT NULL DEFAULT "",location TEXT NOT NULL DEFAULT "",negative INTEGER NOT NULL DEFAULT 0,source TEXT NOT NULL,updated_at INTEGER NOT NULL,PRIMARY KEY(holder,subject,predicate,object,location,negative))');
    await db.execute('CREATE INDEX IF NOT EXISTS beliefs_holder_idx ON beliefs(holder,updated_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS beliefs_subject_idx ON beliefs(subject,predicate,updated_at DESC)');
    await db.execute('CREATE TABLE IF NOT EXISTS goals(holder TEXT NOT NULL,goal TEXT NOT NULL,source TEXT NOT NULL,updated_at INTEGER NOT NULL,PRIMARY KEY(holder,goal))');
    await db.execute('CREATE TABLE IF NOT EXISTS observations(id INTEGER PRIMARY KEY AUTOINCREMENT,observer TEXT NOT NULL,subject TEXT NOT NULL,predicate TEXT NOT NULL,object TEXT NOT NULL DEFAULT "",location TEXT NOT NULL DEFAULT "",at INTEGER NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS social_meta(k TEXT PRIMARY KEY,v TEXT NOT NULL)');
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
        'negative':b.negative?1:0,
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
      orderBy:'updated_at DESC',limit:limit);
    return rows.map((r)=>MentalBelief410(
      holder:'${r['holder']}',subject:'${r['subject']}',predicate:'${r['predicate']}',
      object:'${r['object']}',location:'${r['location']}',negative:(r['negative'] as int)==1,
      source:'${r['source']}')).toList();
  }

  Future<MentalBelief410?> beliefSlot(String holder,String subject,String predicate) async {
    final rows=await db.query('beliefs',where:'holder=? AND subject=? AND predicate=?',
      whereArgs:[canon410(holder),canon410(subject),canon410(predicate)],
      orderBy:'updated_at DESC',limit:1);
    if(rows.isEmpty)return null;
    final r=rows.single;
    return MentalBelief410(holder:'${r['holder']}',subject:'${r['subject']}',
      predicate:'${r['predicate']}',object:'${r['object']}',location:'${r['location']}',
      negative:(r['negative'] as int)==1,
      source:'${r['source']}');
  }

  Future<void> putGoal(String holder,String goal,{String source='osservato'}) async {
    final h=canon410(holder),g=canon410(goal);
    if(h.isEmpty||g.isEmpty)return;
    await ensureAgent(h);
    await db.insert('goals',{'holder':h,'goal':g,
      'source':source,'updated_at':DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm:ConflictAlgorithm.replace);
  }

  Future<List<Map<String,dynamic>>> goalsOf(String holder,{int limit=8}) async =>
    (await db.query('goals',where:'holder=?',whereArgs:[canon410(holder)],
      orderBy:'updated_at DESC',limit:limit)).map((e)=>Map<String,dynamic>.from(e)).toList();

  Future<void> observe(String observer,CognitiveFrame420 frame) async {
    if(observer.isEmpty||!frame.valid)return;
    final now=DateTime.now().millisecondsSinceEpoch;
    await db.insert('observations',{
      'observer':canon410(observer),'subject':frame.subject,'predicate':frame.predicate,
      'object':frame.object,'location':frame.location,'at':now});
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
    return {'agents':await n('agents'),'beliefs':await n('beliefs'),'goals':await n('goals'),'observations':await n('observations')};
  }

  Future<void> clear() async {
    await db.transaction((tx) async {
      for(final t in ['agents','beliefs','goals','observations','social_meta']){await tx.delete(t);}
    });
  }
}

class TheoryOfMind410 {
  final SocialStore410 store;
  TheoryOfMind410(this.store);

  static bool _isLeave(String p)=>p.startsWith('esc')||p.startsWith('part');
  static bool _isEnter(String p)=>p.startsWith('entr')||p.startsWith('arriv')||p.startsWith('torn');
  static bool _isLocationChange(CognitiveFrame420 f)=>f.location.isNotEmpty &&
      (f.object.isNotEmpty||_isEnter(f.predicate)||f.predicate.startsWith('and'));

  Future<void> experience(String sentence,CognitiveFrame420 frame) async {
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
          location:frame.location,negative:frame.negative,source:'osservazione'));
      } else {
        await store.putBelief(MentalBelief410(
          holder:observer,subject:frame.subject,predicate:frame.predicate,
          object:frame.object,location:frame.location,negative:frame.negative,
          source:'osservazione'));
      }
    }
    if(_isLeave(frame.predicate)) await store.setPresence(actor,false);

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
