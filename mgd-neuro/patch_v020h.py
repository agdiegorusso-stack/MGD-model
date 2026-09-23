from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'mgd-neuro-app')
p = root / 'lib' / 'mgd_language_v020.dart'
s = p.read_text()

old_persistence = """class MgdLanguagePersistence20 {
  Future<File> _file() async=>File('${(await getApplicationDocumentsDirectory()).path}/mgd_language20.json');
  Future<MgdLanguage20?> load() async{try{final f=await _file();if(!await f.exists())return null;return MgdLanguage20.fromJson(jsonDecode(await f.readAsString()));}catch(_){return null;}}
  Future<void> save(MgdLanguage20 m) async{final f=await _file();final tmp=File('${f.path}.tmp');await tmp.writeAsString(jsonEncode(m.toJson()),flush:true);if(await f.exists())await f.delete();await tmp.rename(f.path);}
}"""

new_persistence = """class MgdLanguagePersistence20 {
  Future<void> _saveTail = Future<void>.value();

  Future<File> _file() async=>File('${(await getApplicationDocumentsDirectory()).path}/mgd_language20.json');

  Future<MgdLanguage20?> load() async{
    final f=await _file();
    try{
      if(!await f.exists())return null;
      return MgdLanguage20.fromJson(jsonDecode(await f.readAsString()));
    }catch(_){
      final bak=File('${f.path}.bak');
      try{
        if(await bak.exists())return MgdLanguage20.fromJson(jsonDecode(await bak.readAsString()));
      }catch(_){}
      return null;
    }
  }

  Future<void> save(MgdLanguage20 m){
    // Snapshot synchronously, then serialize all disk writes. Autosave, lifecycle
    // save and corpus import can otherwise race on the same .tmp file.
    final payload=jsonEncode(m.toJson());
    final next=_saveTail.catchError((_){}).then((_)=>_writePayload(payload));
    _saveTail=next;
    return next;
  }

  Future<void> _writePayload(String payload) async{
    final f=await _file();
    await f.parent.create(recursive:true);
    final stamp=DateTime.now().microsecondsSinceEpoch;
    final tmp=File('${f.path}.tmp.$stamp');
    final bak=File('${f.path}.bak');
    await tmp.writeAsString(payload,flush:true);
    try{
      if(await bak.exists())await bak.delete();
      if(await f.exists())await f.rename(bak.path);
      await tmp.rename(f.path);
      if(await bak.exists())await bak.delete();
    }catch(e){
      if(!await f.exists() && await bak.exists()){
        try{await bak.rename(f.path);}catch(_){}
      }
      rethrow;
    }finally{
      if(await tmp.exists()){
        try{await tmp.delete();}catch(_){}
      }
    }
  }
}"""

if old_persistence not in s:
    raise SystemExit('MgdLanguagePersistence20 anchor missing')
s=s.replace(old_persistence,new_persistence,1)

old_bytes = """      if(f.bytes!=null){
        data=utf8.decode(f.bytes!,allowMalformed:true);
      }else if(f.path!=null){
        data=await File(f.path!).readAsString();
      }else{
        if(mounted)setState(()=>status='Android non ha restituito né i byte né un percorso leggibile per ${f.name}.');
        return;
      }
      await train(data,sourceName:f.name);"""

new_bytes = """      if(f.bytes!=null && f.bytes!.isNotEmpty){
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

if old_bytes not in s:
    raise SystemExit('corpus byte-read anchor missing')
s=s.replace(old_bytes,new_bytes,1)

state_anchor="class _MgdLanguageLab20State extends State<MgdLanguageLab20>{
  final text=TextEditingController(); bool busy=false; String status='';"
state_repl="""class _MgdLanguageLab20State extends State<MgdLanguageLab20>{
  final text=TextEditingController(); bool busy=false; String status='';

  String _decodeCorpusBytes(List<int> bytes){
    if(bytes.isEmpty)return '';
    if(bytes.length>=2 && bytes[0]==0xFF && bytes[1]==0xFE){
      final units=<int>[];
      for(var i=2;i+1<bytes.length;i+=2)units.add(bytes[i]|(bytes[i+1]<<8));
      return String.fromCharCodes(units);
    }
    if(bytes.length>=2 && bytes[0]==0xFE && bytes[1]==0xFF){
      final units=<int>[];
      for(var i=2;i+1<bytes.length;i+=2)units.add((bytes[i]<<8)|bytes[i+1]);
      return String.fromCharCodes(units);
    }
    final decoded=utf8.decode(bytes,allowMalformed:true);
    final replacements='�'.allMatches(decoded).length;
    if(replacements>max(8,decoded.length~/200)){
      return latin1.decode(bytes,allowInvalid:true);
    }
    return decoded;
  }"""
if state_anchor not in s:
    raise SystemExit('language lab state anchor missing')
s=s.replace(state_anchor,state_repl,1)

p.write_text(s)

pub = root / 'pubspec.yaml'
ps = pub.read_text()
ps = ps.replace('version: 0.20.1+28', 'version: 0.20.2+29')
pub.write_text(ps)
