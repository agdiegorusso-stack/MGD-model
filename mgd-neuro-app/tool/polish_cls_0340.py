from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
p=root/'lib/main.dart';s=p.read_text()
s=s.replace("'MGD Neuro 0.33.1'","'MGD Neuro $mgdAppVersion319'")
s=s.replace("'Memorie MGD 0.33.1'","'Memorie MGD $mgdAppVersion319'")
p.write_text(s)
p=root/'lib/cls_page_v0340.dart';s=p.read_text()
marker='CLS_MEDIA_ATLAS_0340'
if marker not in s:
    def sub(old,new):
        global s
        if s.count(old)!=1:raise RuntimeError(f'Unexpected atlas anchor {old!r}: {s.count(old)}')
        s=s.replace(old,new)
    sub("import 'cls_core_v0340.dart';","import 'cls_core_v0340.dart';\nimport 'cls_media_v0340.dart';")
    sub('  Pattern340? _focus;','  Pattern340? _focus;\n  Map<int,MediaPreview340> _previews={};')
    a=s.index('  Future<void> _select(');b=s.index('  Future<void> _legacyDelete(',a)
    s=s[:a]+'''  Future<void> _select(Pattern340 focus) => _run(() async {
    final neighbors=await _store!.recall(focus.cue,context:focus.context,neighborhood:true);
    final previews=<int,MediaPreview340>{};
    final ids={focus.id,...neighbors.evidence.take(24).map((e)=>e.id)};
    for(final id in ids) {
      if(_cancel||!mounted||!_foreground)break;
      if(_previews.containsKey(id)){previews[id]=_previews[id]!;continue;}
      final rows=await _store!.db.query('episodes',columns:['image','audio'],where:'id=?',whereArgs:[id]);
      if(rows.isEmpty)continue;
      final media=<String,Uint8List>{for(final e in rows.single.entries)
        if(e.value is Uint8List)e.key:e.value as Uint8List};
      if(media.isNotEmpty)previews[id]=await compute(mediaPreview340,media);
    }
    if(mounted)setState((){_focus=focus;_neighbors=neighbors;_previews=previews;});
  });
''' +s[b:]
    sub('onOpen: _detail','previews: _previews, onOpen: _detail')
    sub('  final ValueChanged<int> onOpen;','  final ValueChanged<int> onOpen;\n  final Map<int,MediaPreview340> previews;')
    sub('      required this.onOpen});','      required this.onOpen, this.previews=const {}});')
    sub("Icon(nodes[i].cue.containsKey('vision:v1')", "ExperiencePreview340(preview:previews[nodes[i].id], fallback:nodes[i].cue.containsKey('vision:v1')")
    s='// '+marker+'\n'+s

if 'CLS_LEGACY_READONLY_0340' not in s:
    s,n=re.subn(r'ExperiencePage33\(\s*world: widget.world,\s*onSave: widget.onSave\)',
        'LegacySnapshotView340(world: widget.world)',s)
    if n!=1:raise RuntimeError(f'Expected one legacy route, found {n}')
    s+='''
// CLS_LEGACY_READONLY_0340
/// Edits happen only through the migrated archive, never through two unsynced
/// copies. The legacy snapshot remains inspectable for compatibility.
class LegacySnapshotView340 extends StatelessWidget {
  final MgdWorld06 world;
  const LegacySnapshotView340({super.key,required this.world});
  @override Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('Archivio precedente · sola lettura')),
    body:SafeArea(child:Column(children:[
      const Padding(padding:EdgeInsets.all(16),child:Text(
        'Questa è la copia di compatibilità. Per imparare, correggere o eliminare usa Esperienza e Atlante: le modifiche devono avere un solo percorso.')),
      Expanded(child:ListView.builder(itemCount:world.experience33.episodes.length,
        itemBuilder:(context,index) {
          final e=world.experience33.episodes[index];
          return ListTile(title:Text(e.label),subtitle:Text(
            '${e.context} · ${e.source}\\n${e.description}',maxLines:4,overflow:TextOverflow.ellipsis));
        }))])));
}
'''
p.write_text(s)
print('Version labels, media atlas and read-only compatibility view integrated')
