import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mgd_neuro_mobile/cls_core_v0340.dart';
import 'package:mgd_neuro_mobile/cls_store_v0340.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('dense indexed recall agrees with a full Hopfield reference on noisy held-out cues',() async {
    final directory=await Directory.systemTemp.createTemp('cls-dense-');
    final store=await ClsStore340.open(path:'${directory.path}/dense.sqlite',factory:databaseFactoryFfi);
    final random=Random(34002),records=<Pattern340>[];
    final learn=Stopwatch()..start();
    try {
      for(var i=0;i<384;i++) {
        final c=Hopfield340.normalize({'vision:v1':{
          for(var d=0;d<32;d++)'dim$d':random.nextDouble()*2-1}});
        final id=await store.learn(c,label:'oggetto$i',uid:'dense$i');
        records.add(Pattern340(id,'oggetto$i','generale',c));
      }
      final ingestUs=learn.elapsedMicroseconds;
      final exactUs=<int>[],noisyUs=<int>[],candidateCounts=<int>[];
      var correct=0,referenceCorrect=0;
      for(var trial=0;trial<16;trial++) {
        final index=(trial*23)%records.length,target=records[index];
        final clean=await store.recall(target.cue);
        exactUs.add(store.lastRecallMicros);
        expect(clean.accepted,true);expect(clean.best,target.label);
        final noisy=<String,Map<String,double>>{'vision:v1':{
          for(final e in target.cue['vision:v1']!.entries)
            e.key:e.value+(random.nextDouble()-.5)*.025}};
        final indexed=await store.recall(noisy);
        noisyUs.add(store.lastRecallMicros);candidateCounts.add(store.lastCandidates);
        final full=Hopfield340.recall(noisy,records);
        if(indexed.accepted&&indexed.best==target.label)correct++;
        if(full.accepted&&full.best==target.label)referenceCorrect++;
        expect(indexed.accepted,true);expect(indexed.best,target.label);
        expect(indexed.best,full.best);expect(store.lastCandidates,lessThanOrEqualTo(130));
      }
      int percentile(List<int> x,double q) {
        final s=List<int>.from(x)..sort();return s[(q*s.length).ceil()-1];
      }
      final report={
        'fixture':'384 synthetic dense 32-coordinate memories; 16 unseen noisy cues',
        'environment':'GitHub Linux runner, Flutter test JIT, SQLite WAL on disk',
        'seed':34002,'storedEpisodes':384,'queries':16,'indexedCorrect':correct,
        'fullHopfieldReferenceCorrect':referenceCorrect,'ingestMicroseconds':ingestUs,
        'exactP50Microseconds':percentile(exactUs,.5),'exactP95Microseconds':percentile(exactUs,.95),
        'noisyP50Microseconds':percentile(noisyUs,.5),'noisyP95Microseconds':percentile(noisyUs,.95),
        'maxCandidates':candidateCounts.reduce(max),
        'limitations':'Synthetic pattern completion only; not natural-image understanding, not Android latency, not energy or Transformer superiority.'};
      print('CLS_DENSE_BENCHMARK ${jsonEncode(report)}');
      await File('benchmark-dense-0.34.0.json').writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    } finally {
      await store.close();await directory.delete(recursive:true);
    }
  },timeout:const Timeout(Duration(minutes:3)));
}
