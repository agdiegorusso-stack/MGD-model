from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()

old_train = "  Future<void> train(String data)async{if(data.trim().isEmpty)return;setState(()=>busy=true);await Future<void>.delayed(Duration.zero);widget.language.ingestText(data,reward:.42);await widget.onSave();if(mounted)setState((){busy=false;status='Testo incorporato nella geometria linguistica MGD.';});}"
new_train = r'''  Future<void> train(String data,{String? sourceName})async{
    final raw=data.trim();
    if(raw.isEmpty){if(mounted)setState(()=>status='Il file non contiene testo leggibile.');return;}
    if(busy)return;
    final before=widget.language.stats();
    if(mounted)setState((){busy=true;status=sourceName==null?'Sto incorporando il testo…':'Sto importando $sourceName…';});
    try{
      const chunkSize=120000;
      var start=0;
      while(start<raw.length){
        var end=min(start+chunkSize,raw.length);
        if(end<raw.length){
          final searchStart=max(start,end-8000);
          final tail=raw.substring(searchStart,end);
          final cuts=RegExp(r'[.!?]\\s+|\\n+').allMatches(tail).toList();
          if(cuts.isNotEmpty)end=searchStart+cuts.last.end;
        }
        if(end<=start)end=min(start+chunkSize,raw.length);
        widget.language.ingestText(raw.substring(start,end),reward:.42);
        start=end;
        if(mounted)setState(()=>status=sourceName==null?'Sto leggendo… ${(100*start/raw.length).round()}%':'Sto leggendo $sourceName… ${(100*start/raw.length).round()}%');
        await Future<void>.delayed(Duration.zero);
      }
      await widget.onSave();
      final after=widget.language.stats();
      if(mounted)setState(()=>status='${sourceName==null?'Testo':'Corpus $sourceName'} incorporato: +${after.sentences-before.sentences} frasi, +${after.tokens-before.tokens} token, +${after.edges-before.edges} archi, +${after.chunks-before.chunks} macro-nodi.');
    }catch(e){
      if(mounted)setState(()=>status='Errore durante l’importazione: $e');
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }'''

old_pick = "  Future<void> pick()async{final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['txt','md','csv']);final p=r?.files.single.path;if(p==null)return;await train(await File(p).readAsString());}"
new_pick = r'''  Future<void> pick()async{
    if(busy)return;
    try{
      final r=await FilePicker.platform.pickFiles(
        type:FileType.custom,
        allowedExtensions:['txt','md','csv'],
        allowMultiple:false,
        withData:true,
      );
      if(r==null||r.files.isEmpty){if(mounted)setState(()=>status='Importazione annullata.');return;}
      final f=r.files.single;
      String data;
      if(f.bytes!=null){
        data=utf8.decode(f.bytes!,allowMalformed:true);
      }else if(f.path!=null){
        data=await File(f.path!).readAsString();
      }else{
        if(mounted)setState(()=>status='Android non ha restituito né i byte né un percorso leggibile per ${f.name}.');
        return;
      }
      await train(data,sourceName:f.name);
    }catch(e){
      if(mounted)setState(()=>status='Impossibile importare il corpus: $e');
    }
  }'''

if old_train not in s:
    raise SystemExit('train() anchor missing')
if old_pick not in s:
    raise SystemExit('pick() anchor missing')
s=s.replace(old_train,new_train,1).replace(old_pick,new_pick,1)
s=s.replace("label:const Text('Importa corpus .txt/.md')","label:const Text('Importa libro/corpus .txt/.md')",1)
p.write_text(s)

pub = root / 'pubspec.yaml'
ps = pub.read_text()
ps = ps.replace('version: 0.20.0+27', 'version: 0.20.1+28')
pub.write_text(ps)
