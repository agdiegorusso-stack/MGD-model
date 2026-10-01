import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

typedef MediaPreview340=({Uint8List? thumbnail,List<double> waveform});

/// Original media remain in the archive. Only small derived previews travel to
/// the atlas; processing runs in a worker rather than on the UI isolate.
MediaPreview340 mediaPreview340(Map<String,Uint8List> media) {
  Uint8List? thumbnail;
  final bytes=media['image'];
  if(bytes!=null) {
    try {
      final decoded=img.decodeImage(bytes);
      if(decoded!=null)thumbnail=Uint8List.fromList(img.encodeJpg(
        img.copyResize(decoded,width:120,height:90,maintainAspect:true),quality:72));
    } catch(_) { /* An unavailable preview does not destroy the episode. */ }
  }
  final pcm=media['audio'],wave=<double>[];
  if(pcm!=null&&pcm.length>=2) {
    final data=ByteData.sublistView(pcm),n=pcm.length~/2,bars=min(64,pcm.length~/2);
    for(var b=0;b<bars;b++) {
      final first=b*n~/bars,last=(b+1)*n~/bars;
      double sum=0;
      for(var i=first;i<last;i++) {
        final sample=data.getInt16(i*2,Endian.little)/32768;
        sum+=sample*sample;
      }
      wave.add(sqrt(sum/(last-first)));
    }
  }
  return (thumbnail:thumbnail,waveform:wave);
}

class ExperiencePreview340 extends StatelessWidget {
  final MediaPreview340? preview;
  final IconData fallback;
  const ExperiencePreview340({super.key,this.preview,required this.fallback});
  @override Widget build(BuildContext context) {
    final p=preview;
    if(p==null)return Icon(fallback);
    return Column(mainAxisSize:MainAxisSize.min,children:[
      if(p.thumbnail!=null)Image.memory(p.thumbnail!,width:100,height:64,cacheWidth:120,fit:BoxFit.contain),
      if(p.waveform.isNotEmpty)SizedBox(width:100,height:26,child:CustomPaint(
        painter:_Waveform340(p.waveform,Theme.of(context).colorScheme.primary))),
      if(p.thumbnail==null&&p.waveform.isEmpty)Icon(fallback),
    ]);
  }
}
class _Waveform340 extends CustomPainter {
  final List<double> samples;final Color color;
  _Waveform340(this.samples,this.color);
  @override void paint(Canvas canvas,Size size) {
    final paint=Paint()..color=color..strokeWidth=1;
    canvas.drawLine(Offset(0,size.height/2),Offset(size.width,size.height/2),paint);
    for(var i=0;i<samples.length;i++) {
      final x=(i+.5)*size.width/samples.length,a=samples[i].clamp(0.0,1.0)*size.height/2;
      canvas.drawLine(Offset(x,size.height/2-a),Offset(x,size.height/2+a),paint);
    }
  }
  @override bool shouldRepaint(covariant _Waveform340 old)=>old.samples!=samples||old.color!=color;
}
