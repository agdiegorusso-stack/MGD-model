// Run from mgd-neuro-app with:
// dart --packages=.dart_tool/package_config.json ../experiments/mgd_v0330/benchmark.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../mgd-neuro-app/lib/experience_memory_v0330.dart';
import '../../mgd-neuro-app/lib/sensory_world_v06.dart';

Features33 stimulus(int label,Random rng) {
  final red=(label&1)==0, high=(label&2)!=0, text=(label&4)!=0;
  final picture=img.Image(width:48,height:48);
  // Disjoint generated samples; no image/sound filenames or labels enter x.
  for(var y=0;y<48;y++) {for(var x=0;x<48;x++) {
    final jitter=rng.nextInt(20), bright=205+rng.nextInt(26);
    picture.setPixelRgb(x,y,red?bright:jitter,10+jitter,red?jitter:bright);
  }}
  final bytes=Uint8List(16000),bd=ByteData.sublistView(bytes);
  final hz=(high?880:330)*(1+(rng.nextDouble()-.5)*.04);
  final phase=rng.nextDouble()*2*pi,volume=9000+rng.nextInt(6000);
  for(var i=0;i<8000;i++) {
    final signal=volume*sin(2*pi*hz*i/16000+phase)+rng.nextInt(100)-50;
    bd.setInt16(i*2,signal.round(),Endian.little);
  }
  return {
    'vision:v1':MgdWorld06.encodeVision33(Uint8List.fromList(img.encodePng(picture))),
    'audio:v1':MgdWorld06.encodeAudio33(bytes),
    'text:v1':ExperienceMemory33.textFeatures(text?'contesto beta':'contesto alfa')};
}
double accuracy(ExperienceMemory33 m,List<Map<String,dynamic>> samples,List<String> channels) {
  var correct=0;
  for(final sample in samples) {
    final x=sample['features'] as Features33;
    final p=m.predict({for(final c in channels) c:x[c]!});
    if(p.best==sample['label']) correct++;
  }
  return correct/samples.length;
}
double quantile(List<int> values,double q) {
  final sorted=values.toList()..sort();return sorted[(q*(sorted.length-1)).round()]/1000;
}
void main(List<String> args) {
  final out=Directory(args.isEmpty?'../experiments/mgd_v0330/results':args.first)..createSync(recursive:true);
  final summaries=<Map<String,dynamic>>[];
  for(var seed=6;seed<12;seed++) {
    final rng=Random(3300+seed),m=ExperienceMemory33();
    final training=<Map<String,dynamic>>[],holdout=<Map<String,dynamic>>[];
    for(var label=0;label<8;label++) {
      for(var i=0;i<12;i++) {holdout.add({'features':stimulus(label,rng),'label':'classe $label'});}
    }
    final learningTimes=<int>[];
    var oldBefore=0.0;
    for(var phase=0;phase<2;phase++) {
      final schedule=[for(var i=0;i<8;i++) for(var label=phase*4;label<phase*4+4;label++) label]..shuffle(rng);
      for(final label in schedule) {
        final x=stimulus(label,rng);
        training.add({'features':x,'label':'classe $label','phase':phase});
        m.learn(x,label:'classe $label');learningTimes.add(m.lastLearnMicros);
      }
      if(phase==0) oldBefore=accuracy(m,holdout.take(48).toList(),ExperienceMemory33.channels.toList());
    }
    final predictTimes=<int>[]; var nll=0.0, accepted=0, acceptedCorrect=0;
    for(final s in holdout) {
      final p=m.predict(s['features'] as Features33);predictTimes.add(m.lastPredictMicros);
      nll-=log(max(1e-12,p.probabilities[s['label']]??0));
      if(p.accepted) {accepted++;if(p.best==s['label']) acceptedCorrect++;}
    }
    final oldAfter=accuracy(m,holdout.take(48).toList(),ExperienceMemory33.channels.toList());
    final result=<String,dynamic>{
      'seed':seed,'train':training.length,'holdout':holdout.length,
      'accuracy':accuracy(m,holdout,ExperienceMemory33.channels.toList()),
      'imageOnly':accuracy(m,holdout,['vision:v1']),
      'audioOnly':accuracy(m,holdout,['audio:v1']),
      'textOnly':accuracy(m,holdout,['text:v1']),
      'imageAndAudio':accuracy(m,holdout,['vision:v1','audio:v1']),
      'oldHoldoutBeforeNewClasses':oldBefore,'oldHoldoutAfterNewClasses':oldAfter,
      'oldHoldoutForgetting':oldBefore-oldAfter,
      'holdoutNll':nll/holdout.length,'accepted':accepted,'acceptedCorrect':acceptedCorrect,
      'learningP50Ms':quantile(learningTimes,.5),'learningP95Ms':quantile(learningTimes,.95),
      'predictP50Ms':quantile(predictTimes,.5),'predictP95Ms':quantile(predictTimes,.95),
      'serializedBytes':m.serializedBytes,'metrics':m.metrics,
      'energyJoules':null,'energyNote':'Not measured. CPU latency is not energy.'};
    File('${out.path}/dataset-$seed.json').writeAsStringSync(jsonEncode({'train':training,'test':holdout}));
    summaries.add(result);stdout.writeln(jsonEncode(result));
  }
  File('${out.path}/app-core-results.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'scope':'Eight artificial classes; independent text cue, PNG colour and PCM tone. No general language or real-world recognition claim.',
    'seeds':summaries,'dart':Platform.version,'os':Platform.operatingSystem}));
}
