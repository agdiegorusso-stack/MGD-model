import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:mgd_neuro_mobile/axioms/axiom_core.dart';
import 'package:mgd_neuro_mobile/axioms/axiom_store.dart';
import 'axioms0430_test.dart' show lessonPackage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ffi.sqfliteFfiInit(); sqlite.databaseFactory=ffi.databaseFactoryFfi;
  late Directory dir;
  final stores=<AxiomStore>[];
  Future<AxiomStore> open()async{final s=AxiomStore();stores.add(s);await s.open(databasePath:'${dir.path}/axioms.db');return s;}
  setUp(()async{
    dir=await Directory.systemTemp.createTemp('mgd-axioms0430-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AxiomStore.channel,(_)async=>null);
  });
  tearDown(()async{
    for(final s in stores){await s.closeStorage();s.dispose();}stores.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AxiomStore.channel,null);
    await dir.delete(recursive:true);
  });
  test('saved axiom memory reopens with the same revision and evidence',()async{
    final s=await open();final revision=s.student.revision;await s.testAll();expect(s.result!['passed'],276);
    await s.closeStorage();final restored=await open();expect(restored.student.revision,revision);expect(restored.state['events'],isNotEmpty);
  });
  test('multi-megabyte Unicode snapshots are restored through bounded reads',()async{
    final s=await open();final backup=jsonDecode(s.export()) as Map;
    final text='memoria è conoscenza 🧠 '*120000;
    (backup['state']['events'] as List).add({'kind':'large-persistence-test','payload':text});
    await s.import(jsonEncode(backup));expect(s.status,contains('importato'));
    await s.closeStorage();final restored=await open();expect(restored.state['events'][0]['payload'],text);
  });
  test('an invalid backup checksum cannot change the current model',()async{
    final s=await open();await s.testAll();final revision=s.student.revision;
    final backup=jsonDecode(s.export()) as Map;backup['revision']='wrong';
    await s.import(jsonEncode(backup));expect(s.student.revision,revision);expect(s.status,contains('Checksum'));
    await s.closeStorage();expect((await open()).student.revision,revision);
  });
  test('audits and test records preserve the prior knowledge revision for undo',()async{
    final s=await open();final revision=s.student.revision;
    final changed=AxiomStudent(s.state['model'] as Map);
    changed.applyLesson((lessonPackage()['lessons'] as List).single as Map);
    final backup=jsonDecode(s.export()) as Map;backup['state']['model']=changed.model;backup['revision']=changed.revision;
    await s.import(jsonEncode(backup));expect(s.student.revision,isNot(revision));
    await s.testAll();await s.testAll();await s.audit('rule:focus_preposition');
    final db=await sqlite.openDatabase('${dir.path}/axioms.db');
    expect((await db.rawQuery('SELECT COUNT(*) AS n FROM history')).single['n'],1);
    await s.undo();expect(s.student.revision,revision);expect(s.student.parse('Luca giunge a Pisa.')['status'],'unrecognized');
  });
  test('local teacher bridge is validated before its proposal reaches persistent memory',()async{
    var calls=0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AxiomStore.channel,(call)async{
      if(call.method=='generate'){calls++;return jsonEncode(lessonPackage());}return null;
    });
    final s=await open();
    await s.teach('Luca giunge a Pisa.',{'location':{'luca':'roma'},'holder':<String,dynamic>{},'owner':<String,dynamic>{}},3);
    expect(calls,1);expect(s.result!['accepted'],true);expect(s.student.parse('È a Torino che Elena giunge.')['status'],'ok');
    expect(s.state['probes'],hasLength(4));
    await s.closeStorage();expect((await open()).student.parse('Elena giunge a Genova.')['status'],'ok');
  });
  test('cancellation while the teacher is generating cannot commit a late lesson',()async{
    final started=Completer<void>(), response=Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AxiomStore.channel,(call)async{
      if(call.method=='generate'){started.complete();return response.future;}return null;
    });
    final s=await open();final revision=s.student.revision;
    final work=s.teach('Luca giunge a Pisa.',{'location':{'luca':'roma'},'holder':<String,dynamic>{},'owner':<String,dynamic>{}},3);
    await started.future;await s.stop();response.complete(jsonEncode(lessonPackage()));await work;
    expect(s.student.revision,revision);expect(s.state['probes'],isEmpty);
  });
}
