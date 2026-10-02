"""Idempotent checked refinements. CI commits each materialized delta."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]

def refine(path, callback):
    p=root/path;s=p.read_text();marker='CLS_REFINEMENT_0340_2'
    if marker in s:return
    p.write_text('// '+marker+'\n'+callback(s))

def sub(s,old,new,count=1):
    if s.count(old)!=count:raise RuntimeError(f'Expected {count} anchors: {old[:90]!r}, found {s.count(old)}')
    return s.replace(old,new)

def store(s):
    s=sub(s,"            onCreate: (db, _) async {", """            onCreate: (db, _) async {
              await db.execute('CREATE TABLE cue_keys(episode INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,context TEXT NOT NULL,signature TEXT NOT NULL,PRIMARY KEY(episode,signature))');
              await db.execute('CREATE INDEX cue_lookup ON cue_keys(context,signature,episode)');""")
    s=sub(s,'k: cue[c]![k]', 'k: double.parse(cue[c]![k]!.toStringAsFixed(10))')
    s=sub(s,"    final key = uid ??", """    final mediaIdentity='${image == null ? '' : sha256.convert(image)}:${audio == null ? '' : sha256.convert(audio)}';
    final key = uid ??""")
    s=sub(s,r".encode('$c\u0000$l\u0000$text\u0000$source\u0000$signature')",r".encode('$c\u0000$l\u0000$text\u0000$source\u0000$signature\u0000$mediaIdentity')")
    s=sub(s,'      final batch = tx.batch();\n      for (final channel in cue.entries)',"""      final batch = tx.batch();
      final channels=cue.keys.toList();
      for(var mask=1;mask<(1<<channels.length);mask++) {
        final part=<String,Map<String,double>>{for(var i=0;i<channels.length;i++)
          if((mask & (1<<i)) != 0) channels[i]:cue[channels[i]]!};
        batch.insert('cue_keys',{'episode':id,'context':c,'signature':_signature(part)});
      }
      for (final channel in cue.entries)""")
    s=sub(s,"      {String context = 'generale', int budget = 128}) async {", "      {String context = 'generale', int budget = 128, bool neighborhood = false}) async {",2)
    s=sub(s,'    final terms = <List<Object>>[];',"""    final exact=await db.rawQuery('SELECT MIN(e.id) AS id FROM cue_keys k JOIN episodes e ON e.id=k.episode WHERE k.context=? AND k.signature=? GROUP BY e.label ORDER BY id LIMIT 2',[c,_signature(cue)]);
    final ids=exact.map((r)=>r['id'] as int).toSet();
    if(ids.isNotEmpty && !neighborhood) {
      final selected=await db.query('episodes',columns:_cols,
        where:'id IN (${List.filled(ids.length,'?').join(',')})',whereArgs:ids.toList());
      return selected.map(pattern340).toList();
    }
    final terms = <List<Object>>[];""")
    start=s.index("    final ids = rows.map((r) => r['id'] as int).toSet();")
    stop=s.index('    if (ids.isEmpty) return [];',start)
    s=s[:start]+"    ids.addAll(rows.map((r)=>r['id'] as int));\n"+s[stop:]
    s=sub(s,'await candidates(cue, context: context, budget: budget);','await candidates(cue, context: context, budget: budget, neighborhood: neighborhood);')
    return s
refine('lib/cls_store_v0340.dart',store)

def page(s):
    s=sub(s,"import 'dart:async';","import 'dart:async';\nimport 'dart:convert';")
    s=sub(s,'  int _topicCursor = 0;','')
    s=sub(s,'    final topic = topics[_topicCursor++ % topics.length];',"""    final before=(await _store!.stats())['episodes']!;
    final timer=Stopwatch()..start();
    final history=jsonDecode(await _store!.readSetting('studyProgress')??'{}') as Map;
    final topic=StudyPriority340.choose(topics,history,DateTime.now().millisecondsSinceEpoch);
""")
    s=sub(s,'    await _refresh();\n    if (mounted)\n      setState(() => _status =\n          \'Studio di “$topic”: $n passaggi elaborati, con fonte conservata.\');',"""    final after=(await _store!.stats())['episodes']!;
    final previous=history[topic] as Map? ?? {};
    history[topic]={'visits':((previous['visits'] as num?)??0)+1,
      'gain':max(0,after-before),'cost':timer.elapsedMilliseconds/1000,
      'at':DateTime.now().millisecondsSinceEpoch};
    await _store!.setting('studyProgress',jsonEncode(history));
    await _refresh();
    if(mounted)setState(()=>_status='Studio di “$topic”: $n passaggi elaborati, ${after-before} nuovi episodi.');""")
    s=sub(s,'await _store!.recall(focus.cue, context: focus.context);','await _store!.recall(focus.cue, context: focus.context, neighborhood: true);')
    old="                  ListView(padding: const EdgeInsets.all(16), children: ["
    if s.count(old)!=4:raise RuntimeError('Expected four workspace lists')
    s=s.replace(old,"                  ListView(key: const ValueKey('cls-experience-list'), padding: const EdgeInsets.all(16), children: [",1)
    s=sub(s,'        constrained: false,\n        minScale: .25,\n        maxScale: 3,\n        child: SizedBox(', '        minScale: 1,\n        maxScale: 8,\n        child: FittedBox(fit: BoxFit.contain, child: SizedBox(')
    s=sub(s,'            ])));\n  }\n}\n\nclass _AtlasEdges340','            ]))));\n  }\n}\n\nclass _AtlasEdges340')
    s=sub(s,'    corrected.dispose();','    Future<void>.delayed(const Duration(milliseconds: 500), corrected.dispose);')
    return s
refine('lib/cls_page_v0340.dart',page)

def core(s):
    return sub(s,'class StudyPriority340 {',r'''class StudyPriority340 {
  /// Select only authorized topics using observed novelty, exploration and cost.
  static String choose(List<String> topics,Map history,int now) {
    if(topics.isEmpty)throw ArgumentError('Nessun argomento autorizzato.');
    String selected=topics.first;double best=-1;
    for(final topic in topics) {
      final item=history[topic];
      if(item is! Map)return topic;
      final visits=(item['visits'] as num?)?.toDouble()??0;
      final gain=(item['gain'] as num?)?.toDouble()??0;
      final age=max(0,now-((item['at'] as num?)?.toInt()??0))/3600000;
      final cost=max(0,(item['cost'] as num?)?.toDouble()??0);
      final value=score(novelty:max(0,gain)/(1+max(0,gain)),
        uncertainty:1/(1+max(0,visits)),contradiction:0,
        userInterest:1+min(age,24)/24,estimatedCost:cost/60);
      if(value>best){best=value;selected=topic;}
    }
    return selected;
  }
''')
refine('lib/cls_core_v0340.dart',core)

scroll=r'''    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('cls-teach')), 180,
      scrollable:find.descendant(of:find.byKey(const ValueKey('cls-experience-list')),
        matching:find.byType(Scrollable)).first);
'''
def tests(s):
    s=sub(s,"    await tester.ensureVisible(find.byKey(const ValueKey('cls-teach')));",scroll)
    marker="    test('failed validation cannot leave half an episode', () async {"
    s=sub(s,marker,r'''    test('different original media with identical descriptors are not lost',() async {
      final a=await store.learn(cue(1),label:'same',image:Uint8List.fromList([1,2]));
      final b=await store.learn(cue(1),label:'same',image:Uint8List.fromList([3,4]));
      expect(a,isNot(b));expect((await store.stats())['episodes'],2);
    });
    test('partial exact query discovers a conflicting class beyond shortlist',() async {
      for(var i=0;i<140;i++)await store.learn({'vision:v1':{'shape':1},'audio:v1':{'sound$i':1}},label:'majority',uid:'repeat$i');
      await store.learn({'vision:v1':{'shape':1},'audio:v1':{'rare':1}},label:'minority');
      final r=await store.recall({'vision:v1':{'shape':1}},budget:8);
      expect(r.conflict,true);expect(r.accepted,false);
    });
    test('exact recall has a fast path while atlas still finds neighbors',() async {
      await store.learn(cue(1),label:'a');await store.learn(cue(1,noise:.1),label:'a');
      expect((await store.recall(cue(1))).evidence.length,1);
      expect((await store.recall(cue(1),neighborhood:true)).evidence.length,2);
    });
    test('study scheduler explores unseen authorized topics',(){
      expect(StudyPriority340.choose(['italiano','biologia'],{'italiano':{'visits':1}},100),'biologia');
      expect(()=>StudyPriority340.choose([],{},100),throwsArgumentError);
    });
''' + marker)
    return s
refine('test/cls_v0340_test.dart',tests)

def android(s):
    s=sub(s,"    await tester.ensureVisible(find.byKey(const ValueKey('cls-teach')));",scroll)
    s=sub(s,"      final button =\n          tester.widget<FilledButton>(find.byKey(const ValueKey('cls-teach')));\n      if (button.onPressed != null) break;", "      final status=tester.widget<Text>(find.byKey(const ValueKey('cls-status'))).data??'';\n      if(status.contains('Archivio pronto'))break;")
    return s
refine('integration_test/cls_android_v0340_test.dart',android)
print('CLS refinements materialized')
