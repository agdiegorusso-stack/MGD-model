from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()

old_picker = """      final r=await FilePicker.platform.pickFiles(
        type:FileType.custom,
        allowedExtensions:['txt','md','csv'],
        allowMultiple:false,
        withData:true,
      );"""

new_picker = """      final r=await FilePicker.platform.pickFiles(
        type:FileType.any,
        allowMultiple:false,
        withData:false,
        withReadStream:true,
      );"""

if old_picker not in s:
    raise SystemExit('picker options anchor missing')
s=s.replace(old_picker,new_picker,1)

old_read = """      String data;
      if(f.bytes!=null && f.bytes!.isNotEmpty){
        data=_decodeCorpusBytes(f.bytes!);
      }else if(f.path!=null){
        final rawBytes=await File(f.path!).readAsBytes();
        data=_decodeCorpusBytes(rawBytes);
      }else{
        if(mounted)setState(()=>status='Android non ha restituito dati leggibili per ${f.name}.');
        return;
      }
      if(data.trim().isEmpty){
        if(mounted)setState(()=>status='Il file ${f.name} risulta vuoto o usa una codifica non leggibile.');
        return;
      }
      await train(data,sourceName:f.name);"""

new_read = """      final rawBytes=<int>[];

      // Android SAF often exposes a content:// document with no usable filesystem
      // path. FilePicker's readStream reads the document through the provider
      // instead of assuming that it is a normal File.
      final stream=f.readStream;
      if(stream!=null){
        await for(final chunk in stream){
          rawBytes.addAll(chunk);
          if(mounted && f.size>0){
            final pct=(100*rawBytes.length/f.size).clamp(0,100).round();
            setState(()=>status='Sto leggendo ${f.name}… $pct%');
          }
        }
      }

      // Fallbacks for providers/platforms that do expose bytes or a real path.
      if(rawBytes.isEmpty && f.bytes!=null && f.bytes!.isNotEmpty){
        rawBytes.addAll(f.bytes!);
      }
      if(rawBytes.isEmpty && f.path!=null && f.path!.isNotEmpty){
        try{
          final diskFile=File(f.path!);
          if(await diskFile.exists())rawBytes.addAll(await diskFile.readAsBytes());
        }catch(_){}
      }

      if(rawBytes.isEmpty){
        if(mounted)setState(()=>status='Android ha restituito 0 byte per ${f.name}. Riprova scegliendo il file da File/Download, non da una anteprima.');
        return;
      }

      final data=_decodeCorpusBytes(rawBytes);
      if(data.trim().isEmpty){
        if(mounted)setState(()=>status='Il file ${f.name} contiene ${rawBytes.length} byte, ma non è stato possibile decodificarli come testo.');
        return;
      }
      await train(data,sourceName:f.name);"""

if old_read not in s:
    raise SystemExit('corpus read anchor missing')
s=s.replace(old_read,new_read,1)

s=s.replace(
    "if(raw.isEmpty){if(mounted)setState(()=>status='Il file non contiene testo leggibile.');return;}",
    "if(raw.isEmpty){if(mounted)setState(()=>status=sourceName==null?'Il riquadro è vuoto. Incolla del testo oppure usa Importa libro/corpus.':'Il corpus selezionato non contiene testo decodificabile.');return;}",
    1,
)

p.write_text(s)

pub = root / 'pubspec.yaml'
ps = pub.read_text()
ps = ps.replace('version: 0.20.2+29', 'version: 0.20.3+30')
pub.write_text(ps)
