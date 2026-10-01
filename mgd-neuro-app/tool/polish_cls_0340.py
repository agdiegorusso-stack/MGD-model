from pathlib import Path
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
    p.write_text('// '+marker+'\n'+s)
print('Version labels and actual media atlas integrated')
