import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/cls_core_v0340.dart';
import 'package:mgd_neuro_mobile/cls_store_v0340.dart';
import 'package:mgd_neuro_mobile/cls_page_v0340.dart';
import 'package:mgd_neuro_mobile/sensory_world_v06.dart';

Cue340 cue(int n,{double noise=0})=>{'vision:v1':{'f$n':1,'noise':noise}};
Pattern340 pattern(int id,String label,Cue340 c)=>Pattern340(id,label,'generale',Hopfield340.normalize(c));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  group('Hopfield and Italian core',(){
    test('modern Hopfield energy is non-increasing with fixed keys',(){
      final rng=Random(340);
      for(var trial=0;trial<12;trial++) {
        final records=List.generate(64,(i)=>pattern(i,'classe$i',{'vision:v1':{
          for(var d=0;d<24;d++)'d$d':rng.nextDouble()*2-1}}));
        final result=Hopfield340.recall(records[trial].cue,records,iterations:8);
        for(var i=1;i<result.energy.length;i++)expect(result.energy[i],lessThanOrEqualTo(result.energy[i-1]+1e-9));
        expect(result.best,'classe$trial');expect(result.accepted,true);
      }
    });
    test('partial multimodal cue retrieves the associated episode',(){
      final records=[pattern(1,'campana',{'vision:v1':{'circle':1},'audio:v1':{'ring':1}}),
        pattern(2,'tamburo',{'vision:v1':{'box':1},'audio:v1':{'beat':1}})];
      final r=Hopfield340.recall({'audio:v1':{'ring':1}},records);
      expect(r.best,'campana');expect(r.evidence.first.cue.containsKey('vision:v1'),true);
    });
    test('noise is tolerated; unrelated signal with one class is rejected',(){
      final records=[pattern(1,'uno',cue(1))];
      expect(Hopfield340.recall(cue(1,noise:.1),records).accepted,true);
      expect(Hopfield340.recall(cue(2),records).accepted,false);
    });
    test('exact conflicting confirmations do not become certainty',(){
      final r=Hopfield340.recall(cue(1),[pattern(1,'a',cue(1)),pattern(2,'b',cue(1))]);
      expect(r.conflict,true);expect(r.accepted,false);
    });
    test('different contexts and unbound modalities do not fabricate associations',(){
      final record=Pattern340(1,'rosso','colore',Hopfield340.normalize(cue(1)));
      expect(Hopfield340.recall(cue(1),[record]).evidence,isEmpty);
      expect(Hopfield340.recall({'audio:v1':{'sound':1}},[record],context:'colore').evidence,isEmpty);
    });
    test('numeric validation and stable softmax',(){
      expect(()=>Hopfield340.normalize({'vision:v1':{'x':double.nan}}),throwsArgumentError);
      expect(()=>Hopfield340.normalize({'vision:v1':{'x':0}}),throwsArgumentError);
      expect(()=>Hopfield340.normalize({}),throwsArgumentError);
      final p=Hopfield340.softmax([100000,100001]);expect(p.fold(0.0,(a,b)=>a+b),closeTo(1,1e-12));
      expect(p[1],greaterThan(p[0]));
    });
    test('Italian accents apostrophes punctuation and adjacent roles are preserved',(){
      expect(Italian340.tokens('L’acqua è già qui.'),["l'acqua",'è','già','qui','.']);
      expect(Italian340.features('Mario segue Luca'),isNot(Italian340.features('Luca segue Mario')));
      expect(Italian340.transitions('Il gatto dorme.')['il gatto\u0000dorme'],1);
    });
    test('chunking retains every word rather than truncating a book',(){
      final text=List.generate(1301,(i)=>'parola$i').join(' ');
      final chunks=Italian340.chunks(text).toList();
      expect(chunks.length,11);expect(chunks.join(' '),text);
    });
    test('study priorities expose interest contradiction and computational cost',(){
      final a=StudyPriority340.score(novelty:.5,uncertainty:.5,contradiction:0,userInterest:0,estimatedCost:1);
      final b=StudyPriority340.score(novelty:.5,uncertainty:.5,contradiction:1,userInterest:1,estimatedCost:1);
      expect(b,greaterThan(a));
    });
  });
  group('incremental SQLite memory',(){
    late ClsStore340 store;
    setUp(() async {store=await ClsStore340.open(path:inMemoryDatabasePath,factory:databaseFactoryFfi);});
    tearDown(() async {await store.close();});
    test('fast memory changes immediately, slow memory only after consolidation',() async {
      final id=await store.learn(cue(1),label:'campana');
      expect((await store.recall(cue(1))).best,'campana');
      expect((await store.recallSlow(cue(1))).evidence,isEmpty);
      expect(await store.consolidate(),1);expect((await store.recallSlow(cue(1))).best,'campana');
      expect((await store.get(id))!['consolidated'],1);expect(await store.consolidate(),0);
    });
    test('raw image and audio survive serialization; label not used as a feature',() async {
      final image=Uint8List.fromList([1,2,3,4]),audio=Uint8List.fromList([0,1,2,3]);
      final id=await store.learn(cue(1),label:'risposta segreta',image:image,audio:audio);
      final row=(await store.get(id))!;
      expect(row['image'],image);expect(row['audio'],audio);
      expect(jsonEncode(unpackCue340(row['features']!)),isNot(contains('risposta segreta')));
    });
    test('duplicate import is idempotent and replay does not inflate evidence',() async {
      final a=await store.learn(cue(1),label:'a',text:'Il gatto dorme.');
      final b=await store.learn(cue(1),label:'a',text:'Il gatto dorme.');
      expect(a,b);expect((await store.stats())['episodes'],1);
      await store.consolidate();await store.consolidate();
      expect((await store.nextWords('il gatto')).first['n'],1);
    });
    test('incremental language learns continuations from actual text',() async {
      await store.importText('Il gatto dorme. Il cane corre.');
      await store.consolidate();
      expect((await store.nextWords('il gatto')).first['token'],'dorme');
      expect(await store.continueText('Il cane',words:1),'il cane corre');
      expect((await store.stats())['vocabulary'],greaterThanOrEqualTo(5));
    });
    test('deletion removes media postings audit and exact language contribution',() async {
      final a=await store.learn(cue(1),label:'a',text:'Il gatto dorme.');
      await store.learn(cue(2),label:'b',text:'Il cane corre.');
      await store.consolidate();await store.correct(a,'corretto');await store.consolidate();
      await store.delete(a);
      expect(await store.get(a),isNull);
      expect(await store.db.query('postings',where:'episode=?',whereArgs:[a]),isEmpty);
      expect(await store.db.query('audit',where:'episode=?',whereArgs:[a]),isEmpty);
      expect(await store.db.query('grams',where:'token=?',whereArgs:['gatto']),isEmpty);
      expect((await store.nextWords('il cane')).first['token'],'corre');
      expect((await store.recall(cue(1))).accepted,false);
    });
    test('correction revokes the old slow prototype and keeps the original cue',() async {
      final id=await store.learn(cue(1),label:'sbagliato');await store.consolidate();
      await store.correct(id,'corretto');
      expect((await store.recall(cue(1))).best,'corretto');
      expect(await store.db.query('prototypes',where:'label=?',whereArgs:['sbagliato']),isEmpty);
      await store.consolidate();expect((await store.recallSlow(cue(1))).best,'corretto');
    });
    test('migration is idempotent and deletion cannot resurrect a legacy episode',() async {
      final old={'id':1,'label':'vecchio','context':'generale','description':'memoria',
        'source':'test','at':'2026-09-01T00:00:00Z','features':cue(1)};
      expect(await store.migrateLegacy([old]),1);expect(await store.migrateLegacy([old]),0);
      final id=(await store.page()).single['id'] as int;await store.delete(id);
      expect(await store.migrateLegacy([old]),0);expect((await store.stats())['episodes'],0);
    });
    test('archive grows past 2048 without evicting old records; candidates stay bounded',() async {
      final watch=Stopwatch()..start();
      for(var i=0;i<2055;i++)await store.learn(cue(i),label:'classe$i',uid:'grow$i');
      final learnMicros=watch.elapsedMicroseconds;
      expect((await store.stats())['episodes'],2055);
      expect((await store.recall(cue(0))).best,'classe0');
      expect((await store.recall(cue(2054))).best,'classe2054');
      expect(store.lastCandidates,lessThanOrEqualTo(256));
      final first=await store.page(limit:64),second=await store.page(after:first.last['id'] as int,limit:64);
      expect(first.map((e)=>e['id']).toSet().intersection(second.map((e)=>e['id']).toSet()),isEmpty);
      final report={'fixture':'2055 sparse synthetic episodes, Flutter test host',
        'episodes':2055,'totalLearnMicros':learnMicros,'lastRecallTotalMicros':store.lastRecallMicros,
        'candidates':store.lastCandidates,'note':'Not device energy measurement, not a Transformer comparison.'};
      print('CLS_BENCHMARK ${jsonEncode(report)}');
      final dest=Platform.environment['MGD_CLS_BENCHMARK_OUT'];
      if(dest!=null)await File(dest).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    },timeout:const Timeout(Duration(minutes:4)));
    test('failed validation cannot leave half an episode',() async {
      await expectLater(store.learn({'vision:v1':{'x':double.infinity}},label:'bad'),throwsArgumentError);
      expect((await store.stats())['episodes'],0);
    });
    test('same signal with incompatible labels is detected through disk retrieval',() async {
      await store.learn(cue(1),label:'a');await store.learn(cue(1),label:'b');
      final r=await store.recall(cue(1));expect(r.conflict,true);expect(r.accepted,false);
    });
  });
  test('reopen and consistent SQLite backup retain text media and corrections',() async {
    final dir=await Directory.systemTemp.createTemp('mgd-cls-test-');
    final path='${dir.path}/memory.sqlite';
    var store=await ClsStore340.open(path:path,factory:databaseFactoryFfi);
    try {
      final id=await store.learn(cue(2),label:'prima',text:'La luce cambia.',audio:Uint8List.fromList([1,0,2,0]));
      await store.consolidate();await store.correct(id,'dopo');await store.consolidate();
      await store.close();store=await ClsStore340.open(path:path,factory:databaseFactoryFfi);
      expect((await store.recall(cue(2))).best,'dopo');
      expect((await store.get(id))!['audio'],Uint8List.fromList([1,0,2,0]));
      final bytes=await store.exportDatabase();final backup='${dir.path}/backup.sqlite';
      await File(backup).writeAsBytes(bytes);
      final restored=await ClsStore340.open(path:backup,factory:databaseFactoryFfi);
      expect((await restored.recall(cue(2))).best,'dopo');await restored.close();
    } finally {await store.close();await dir.delete(recursive:true);}
  });
  testWidgets('CLS page teaches through real SQLite and exposes all four workspaces',(tester) async {
    late ClsStore340 store;
    await tester.runAsync(() async {store=await ClsStore340.open(path:inMemoryDatabasePath,factory:databaseFactoryFfi);});
    await tester.pumpWidget(MaterialApp(home:ClsPage340(world:MgdWorld06(),onSave:() async {},store:store)));
    await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:500)));await tester.pumpAndSettle();
    expect(find.text('Atlante'),findsOneWidget);expect(find.text('Italiano'),findsOneWidget);expect(find.text('Studio'),findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('cls-input')),'saluto breve');
    await tester.enterText(find.byKey(const ValueKey('cls-label')),'ciao');
    await tester.ensureVisible(find.byKey(const ValueKey('cls-teach')));await tester.tap(find.byKey(const ValueKey('cls-teach')));
    await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:600)));await tester.pumpAndSettle();
    await tester.runAsync(() async {expect((await store.stats())['episodes'],1);});
    await tester.pumpWidget(const SizedBox());await tester.runAsync(store.close);
  });
}
