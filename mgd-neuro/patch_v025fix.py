from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'lib'/'navigable_graph_v013.dart'
s=p.read_text()

bad_method="""  Future<void> _savePng25() async{
    try{
      final boundary=_pngKey25.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if(boundary==null)throw StateError('Mappa non pronta');
      final image=await boundary.toImage(pixelRatio:2.0);
      final data=await image.toByteData(format:ui.ImageByteFormat.png); image.dispose();
      if(data==null)throw StateError('PNG non disponibile');
      final bytes=Uint8List.view(data.buffer,data.offsetInBytes,data.lengthInBytes);
      final stamp=DateTime.now().millisecondsSinceEpoch;
      await FilePicker.platform.saveFile(dialogTitle:'Salva mappa MGD in PNG',fileName:'MGD-mappa-${_memoryMode24}-$stamp.png',bytes:bytes);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Mappa PNG salvata.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Errore PNG: $e')));}
  }

"""
if bad_method in s:
    s=s.replace(bad_method,'',1)
else:
    raise SystemExit('misplaced PNG method not found')
anchor="""  void _refreshMap() {
    setState(() {
      _refreshGraphCache();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  Widget build(BuildContext context) {"""
replacement="""  void _refreshMap() {
    setState(() {
      _refreshGraphCache();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

"""+bad_method+"""  @override
  Widget build(BuildContext context) {"""
if anchor not in s: raise SystemExit('state build insertion anchor missing')
s=s.replace(anchor,replacement,1)
start=s.index("                      FilterChip(\n                        label: const Text('Relazioni'),")
end=s.index("\n\n                    ],",start)
block="""                      FilterChip(
                        label: const Text('Relazioni'),
                        selected: _showRelations,
                        onSelected: (v) {
                          if (v && layout.links.length > 1200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Le etichette delle relazioni vengono limitate sui grafi molto densi.',
                                ),
                              ),
                            );
                          }
                          setState(() => _showRelations = v);
                        },
                      ),
                      if(_memoryMode24=='concetti') ...[
                        const SizedBox(width:8),
                        FilterChip(
                          label:const Text('Proto'),
                          selected:_showProto25,
                          onSelected:(v){
                            setState((){_showProto25=v;_focus=null;_refreshGraphCache();});
                            WidgetsBinding.instance.addPostFrameCallback((_)=>_fitView());
                          },
                        ),
                      ],"""
s=s[:start]+block+s[end:]
p.write_text(s)
