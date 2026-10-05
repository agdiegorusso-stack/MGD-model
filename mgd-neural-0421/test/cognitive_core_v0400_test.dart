import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/cognitive_core_v0400.dart';

void main(){
  sqfliteFfiInit();
  group('MGD Cognitive Core 0.40',(){
    late Directory dir; late CognitiveStore400 store; late CognitiveCore400 core;
    setUp(() async { dir=await Directory.systemTemp.createTemp('mgd400-'); store=await CognitiveStore400.openAt('${dir.path}/c.db',factory:databaseFactoryFfi); core=CognitiveCore400(store); });
    tearDown(() async { await store.close(); await dir.delete(recursive:true); });

    test('learns a novel word from use without storing source sentences',() async {
      await core.experience('La glarpa beve acqua. La glarpa corre nel prato. Le glarpe hanno quattro zampe.');
      final d=await core.describeConcept('glarpa');
      expect(d,contains('glarpa'));
      expect(d,anyOf(contains('acqua'),contains('prato'),contains('bev')));
      final schema=await store.db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table'");
      expect(schema.join('\n'),isNot(contains('raw_text')));
      expect(schema.join('\n'),isNot(contains('sentence TEXT')));
    });

    test('prediction error falls when an event transition becomes expected',() async {
      await core.experience('Marta apre la porta. Luca entra nella stanza.');
      await core.experience('Marta apre la porta.');
      final r=await core.experience('Luca entra nella stanza.');
      expect(r.predictions,contains(stem400('entra')));
      expect(r.attention.surprise,lessThan(.9));
    });

    test('answers a novel relational question from world memory',() async {
      await core.experience('Marta apre la porta. Luca guarda Marta.');
      expect(await core.answer('Chi apre la porta?'),contains('marta'));
    });

    test('working memory is bounded but long-term concepts keep growing',() async {
      for(var i=0;i<30;i++){ await core.experience('Persona$i apre porta$i.'); }
      expect(core.workingMemory.length,lessThanOrEqualTo(12));
      final s=await store.stats();
      expect(s['concepts'],greaterThan(12));
    });

    test('curiosity is generated from uncertainty gaps',() async {
      await core.experience('La glarpa beve acqua.');
      final q=await core.curiosity(limit:10);
      expect(q,isNotEmpty);
      expect(q.join(' ').toLowerCase(),contains('glarpa'));
    });

    test('content-addressable recall activates related concepts',() async {
      await core.experience('La glarpa beve acqua. La glarpa corre nel prato.');
      final r=await store.recall(['glarpa','acqua'],limit:8);
      expect(r,isNotEmpty);
      expect(r.map((x)=>x['term']),contains('glarpa'));
    });
  });
}
