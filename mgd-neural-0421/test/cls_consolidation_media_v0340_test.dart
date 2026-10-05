import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:image/image.dart' as img;
import 'package:mgd_neuro_mobile/cls_store_v0340.dart';
import 'package:mgd_neuro_mobile/cls_media_v0340.dart';
import 'experience_v0330_test.dart' show picture33,tone33;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  test('slow memory generalizes across variable nuisance without replacing exact episodes',() async {
    final store=await ClsStore340.open(path:inMemoryDatabasePath,factory:databaseFactoryFfi);
    try {
      for(final sign in [1.0,-1.0]) {
        for(var i=0;i<32;i++) {
          await store.learn({'vision:v1':{'signal':sign,
            'nuisanceA':cos(i*2.399963229728653),'nuisanceB':sin(i*2.399963229728653)}},
            label:sign>0?'positivo':'negativo',uid:'variation-$sign-$i');
        }
      }
      final unseen=<String,Map<String,double>>{'vision:v1':{'signal':1}};
      expect((await store.recall(unseen)).accepted,false);
      expect((await store.recallSlow(unseen)).evidence,isEmpty);
      expect(await store.consolidate(budget:64),64);
      final slow=await store.recallSlow(unseen);
      expect(slow.accepted,true);expect(slow.best,'positivo');
      expect((await store.stats())['episodes'],64);
      final first=(await store.page()).first;
      expect((await store.recall(unpackCue340(first['features']!))).accepted,true);
      expect(await store.consolidate(budget:64),0);
    } finally {await store.close();}
  });
  test('atlas previews contain real bounded image and nonzero recorded waveform',(){
    final preview=mediaPreview340({'image':picture33(true),'audio':tone33(440)});
    expect(preview.thumbnail,isNotNull);
    final decoded=img.decodeImage(preview.thumbnail!)!;
    expect(decoded.width,120);expect(decoded.height,90);
    expect(preview.waveform.length,64);
    expect(preview.waveform.every((x)=>x.isFinite&&x>=0&&x<=1),true);
    expect(preview.waveform.reduce(max),greaterThan(.1));
    final empty=mediaPreview340({'image':Uint8List.fromList([1,2]),'audio':Uint8List(32)});
    expect(empty.thumbnail,isNull);expect(empty.waveform.every((x)=>x==0),true);
  });
}
