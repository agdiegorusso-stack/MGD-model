import 'package:flutter/material.dart';
import 'web_knowledge_explorer_v11.dart';
import 'relational_memory_v0324.dart';

class RelationalMemoryPage324 extends StatefulWidget {
  final ResearchMemory11 memory;
  final Future<void> Function() onSave;
  const RelationalMemoryPage324({super.key,required this.memory,required this.onSave});
  @override State<RelationalMemoryPage324> createState()=>_Page324State();
}
class _Page324State extends State<RelationalMemoryPage324> {
  var query='',history=false,busy=false;
  String status='';
  Future<void> edit(Map<String,dynamic> row) async {
    final controller=TextEditingController(text:
      '${row['agent']} ${row['negative']==true?'non ':''}${row['relation']} ${row['patient']}.');
    final replacement=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Correggi questa relazione'),
      content:TextField(controller:controller,autofocus:true,minLines:2,maxLines:5,
        decoration:const InputDecoration(labelText:'Frase completa corretta')),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Annulla')),
        FilledButton(onPressed:()=>Navigator.pop(c,controller.text),child:const Text('Salva correzione')),
      ]));
    // Wait for the dialog route to finish before disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds:300));controller.dispose();
    if(!mounted||replacement==null) return;
    setState(()=>busy=true);
    final result=RelationalMemory324.correct(widget.memory,row['id'].toString(),replacement);
    try { await widget.onSave(); if(mounted) setState(()=>status=result.message); }
    catch(e) {if(mounted) setState(()=>status='Modifica in memoria; salvataggio da riprovare: $e');}
    finally {if(mounted) setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context) {
    final stats=RelationalMemory324.stats(widget.memory);
    final rows=RelationalMemory324.rows(widget.memory,includeHistory:history)
      .where((r)=>'${r['agent']} ${r['relation']} ${r['patient']} ${r['text']}'
        .toLowerCase().contains(query.toLowerCase())).toList().reversed.toList();
    return Scaffold(appBar:AppBar(title:const Text('Relazioni apprese')),
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          const Text('Lettore sperimentale: inseguire, aiutare, contenere, possedere. '
            'Le frasi insegnate restano affermazioni dell’utente, con fonte e cronologia.'),
          const SizedBox(height:8),
          Text('${stats['current']} attuali · ${stats['history']} sostituite'),
          TextField(onChanged:(s)=>setState(()=>query=s),
            decoration:const InputDecoration(labelText:'Cerca una relazione',prefixIcon:Icon(Icons.search))),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Mostra cronologia'),
            value:history,onChanged:(v)=>setState(()=>history=v)),
          if(status.isNotEmpty) Text(status),
        ])),
        Expanded(child:rows.isEmpty?const Center(child:Text('Nessuna relazione in questa vista.')):
          ListView.builder(itemCount:rows.length,itemBuilder:(c,i) {
            final r=rows[i];
            final current=r['status']=='current';
            return Card(margin:const EdgeInsets.fromLTRB(12,4,12,8),child:Padding(
              padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${r['agent']} → ${r['negative']==true?'non ':''}${r['relation']} → ${r['patient']}',
                  style:Theme.of(c).textTheme.titleMedium),
                Text(current?'Attuale · versione ${r['sequence']}':'Sostituita da ${r['supersededBy']}'),
                SelectableText('Testo: ${r['contextText']??r['text']}'),
                Text('Fonte: ${r['source']}'),
                Text('Costo MGD: ${(r['weight'] as num).toStringAsFixed(3)} · '
                  'memoria: ${(r['memory'] as num).toStringAsFixed(3)} · '
                  'materia: ${(r['material'] as num).toStringAsFixed(3)}'),
                const Text('Queste misure descrivono la memoria, non la verità del fatto.',
                  style:TextStyle(fontSize:12)),
                if(current) TextButton.icon(onPressed:busy?null:()=>edit(r),
                  icon:const Icon(Icons.edit_outlined),label:const Text('Correggi')),
              ])));
          })),
      ])));
  }
}
