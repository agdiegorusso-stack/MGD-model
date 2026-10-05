import 'package:flutter/material.dart';
import 'cognitive_core_v0400.dart';

class CognitiveCorePage400 extends StatefulWidget {
  final Future<CognitiveTurn400?> Function(String text)? onLearn;
  const CognitiveCorePage400({super.key, this.onLearn});
  @override
  State<CognitiveCorePage400> createState()=>_CognitiveCorePage400State();
}

class _CognitiveCorePage400State extends State<CognitiveCorePage400> {
  final experience=TextEditingController();
  final prompt=TextEditingController();
  Map<String,dynamic> stats={};
  List<String> curiosity=[];
  String answer='';
  CognitiveTurn400? last;
  bool busy=false;

  @override void initState(){ super.initState(); _refresh(); }
  @override void dispose(){ experience.dispose(); prompt.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    final c=await CognitiveCoreBridge400.core;
    final s=await c.store.stats(), q=await c.curiosity(limit:6);
    if(mounted) setState((){stats=s;curiosity=q;});
  }

  Future<void> _learn() async {
    final text=experience.text.trim(); if(text.isEmpty||busy)return;
    setState(()=>busy=true);
    try{
      final c=await CognitiveCoreBridge400.core;
      final r = widget.onLearn == null
          ? await c.experience(text,source:'laboratorio')
          : await widget.onLearn!(text);
      if(mounted) setState((){last=r; experience.clear();});
      await _refresh();
    } finally { if(mounted)setState(()=>busy=false); }
  }

  Future<void> _ask() async {
    final text=prompt.text.trim(); if(text.isEmpty||busy)return;
    setState(()=>busy=true);
    try{
      final c=await CognitiveCoreBridge400.core;
      final r=await c.answer(text);
      if(mounted)setState(()=>answer=r??'Non ho ancora una rappresentazione sufficiente per rispondere.');
      await _refresh();
    } finally { if(mounted)setState(()=>busy=false); }
  }

  Widget metric(String k,String v)=>Chip(label:Text('$k: $v'));

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('MGD Cognitive Core 0.40')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Ciclo: percepisci → prevedi → confronta → attenzione → impara → astrai → consolida → richiama.',style:TextStyle(fontWeight:FontWeight.w600)),
      const SizedBox(height:8),
      const Text('Memoria persistente incrementale: concetti, relazioni, costruzioni, transizioni ed episodi salienti. Il testo originale non è conservato dal Cognitive Core.'),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        metric('Concetti','${stats['concepts']??0}'),metric('Relazioni','${stats['relations']??0}'),
        metric('Episodi','${stats['episodes']??0}'),metric('Costruzioni','${stats['constructions']??0}'),
        metric('Cicli','${stats['cycles']??0}'),metric('Errore pred.','${((stats['predictionError']??0.0) as num).toStringAsFixed(2)}'),
      ]),
      const SizedBox(height:18),
      TextField(controller:experience,maxLines:6,decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Nuova esperienza / testo')),
      const SizedBox(height:8),
      FilledButton.icon(onPressed:busy?null:_learn,icon:const Icon(Icons.psychology_alt_outlined),label:const Text('Vivi e impara')),
      if(last!=null) Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Frame: ${last!.frame.subject} → ${last!.frame.predicate} → ${last!.frame.object}'),
        Text('Salienza ${(last!.attention.salience*100).round()}% · sorpresa ${(last!.attention.surprise*100).round()}% · novità ${(last!.attention.novelty*100).round()}% · incertezza ${(last!.attention.uncertainty*100).round()}%'),
        if(last!.predictions.isNotEmpty) Text('Predizioni precedenti: ${last!.predictions.join(', ')}'),
      ]))),
      const SizedBox(height:18),
      TextField(controller:prompt,maxLines:3,decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Parla con la memoria cognitiva')),
      const SizedBox(height:8),
      FilledButton.tonalIcon(onPressed:busy?null:_ask,icon:const Icon(Icons.chat_bubble_outline),label:const Text('Chiedi')),
      if(answer.isNotEmpty) Card(child:Padding(padding:const EdgeInsets.all(12),child:Text(answer))),
      const SizedBox(height:18),
      Text('Curiosità attive',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:6),
      if(curiosity.isEmpty) const Text('Nessun gap prioritario ancora rilevato.'),
      ...curiosity.map((q)=>ListTile(leading:const Icon(Icons.help_outline),title:Text(q))),
    ]));
}
