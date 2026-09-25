import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';

import 'plastic_language_brain_v04.dart';
import 'web_knowledge_explorer_v11.dart';

typedef SemanticLink13 = ({
  String from,
  String relation,
  String to,
  double confidence,
});

class NavigableSemanticGraph13 extends StatefulWidget {
  final PlasticLanguageBrain04 brain;
  final ResearchMemory11? research;
  final int initialNodeLimit;
  final bool fullPage;

  const NavigableSemanticGraph13({
    super.key,
    required this.brain,
    this.research,
    this.initialNodeLimit = 40,
    this.fullPage = false,
  });

  @override
  State<NavigableSemanticGraph13> createState() =>
      _NavigableSemanticGraph13State();
}

class SemanticMapPage14 extends StatelessWidget {
  final PlasticLanguageBrain04 brain;
  final ResearchMemory11 research;

  const SemanticMapPage14({super.key, required this.brain, required this.research});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappa della conoscenza'),
        actions: [
          IconButton(
            tooltip: 'Istruzioni',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => const AlertDialog(
                title: Text('Come navigare'),
                content: Text(
                  'Cerca un concetto, tocca un nodo per aprirne il vicinato, '
                  'usa + e − per lo zoom e il pulsante adatta per rientrare nella vista. '
                  'Usa Mondo per la conoscenza consolidata, Concetti per i concetti cristallizzati (attiva Proto per i cluster instabili), Episodi per la memoria narrativa e Ipotesi per la quarantena epistemica. Gli archi con ? non sono verità consolidate; ⚠ indica un conflitto.',
                ),
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: NavigableSemanticGraph13(
            brain: brain,
            research: research,
            initialNodeLimit: 40,
            fullPage: true,
          ),
        ),
      ),
    );
  }
}

class _NavigableSemanticGraph13State extends State<NavigableSemanticGraph13> {
  final TransformationController _transform = TransformationController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String? _focus;
  final List<String?> _history = <String?>[];
  int _depth = 2;
  int _nodeLimit = 80;
  double _minConfidence = 0.35;
  bool _showRelations = false;
  bool _showNodeLabels = true;
  bool _showProto25=false;
  final GlobalKey _pngKey25=GlobalKey();
  String _memoryMode24='mondo';

  late List<SemanticLink13> _cachedLinks;
  late Set<String> _cachedNodes;
  _GraphLayout13? _layoutCache;
  String? _layoutCacheKey;
  Size _lastCanvasSize = const Size(1800, 1300);

  @override
  void initState() {
    super.initState();
    _nodeLimit = widget.initialNodeLimit;
    _refreshGraphCache();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitView();
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<SemanticLink13> get _allLinks => _cachedLinks;

  void _refreshGraphCache() {
    final links=<SemanticLink13>[];
    final research=widget.research;
    if(_memoryMode24=='mondo'){
      links.addAll(widget.brain.semanticGraph(limit:10000000).where((x)=>x.confidence>=_minConfidence));
    }else if(_memoryMode24=='ipotesi' && research!=null){
      for(final c in research.claims.values){
        if(c.status=='accettata'||c.status=='validata_llm'||c.status=='appresa_corpus')continue;
        if(c.confidence<.38)continue;
        final prefix=c.conflict?'⚠ ':'? ';
        links.add((from:c.subject,relation:'$prefix${c.relation}',to:c.object,confidence:c.confidence.clamp(.38,.58).toDouble()));
      }
    }else if(_memoryMode24=='concetti' && research!=null){
      final cs=research.emergentConcepts.values.where((c)=>c.crystallized||_showProto25).toList()..sort((a,b)=>b.quality.compareTo(a.quality));
      for(final c in cs.take(120)){
        final hub='${c.crystallized?'◆':'◇'} ${c.label}';
        for(final m in c.members.take(7)){
          if(PlasticLanguageBrain04.normalizeText(m)==PlasticLanguageBrain04.normalizeText(c.label))continue;
          links.add((from:hub,relation:c.crystallized?'associa':'proto-associa',to:m,confidence:max(.32,c.quality)));
        }
        for(final a in c.anchors.take(3))links.add((from:hub,relation:'contesto',to:a,confidence:max(.30,c.quality*.8)));
      }
    }else if(_memoryMode24=='episodi' && research!=null){
      for(final e in research.narrativeEpisodes.reversed.take(220)){
        final hub='Ep.${e.id}';
        for(final t in e.terms.take(5))links.add((from:hub,relation:'contiene',to:t,confidence:max(.34,e.salience*.75)));
      }
    }
    _cachedLinks=links;
    _cachedNodes=<String>{};
    if(_memoryMode24=='mondo')_cachedNodes.addAll(widget.brain.entities.map((e)=>e.label));
    for(final l in links){_cachedNodes..add(l.from)..add(l.to);}
    _layoutCache=null;_layoutCacheKey=null;
  }

  void _resetView() {
    _fitView();
  }

  void _fitView() {
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    if (media == null) {
      _transform.value = Matrix4.identity();
      return;
    }
    final width = max(280.0, media.size.width - (widget.fullPage ? 16.0 : 48.0));
    final height = widget.fullPage
        ? max(360.0, media.size.height - 250.0)
        : 470.0;
    final canvasWidth = _lastCanvasSize.width;
    final canvasHeight = _lastCanvasSize.height;
    final scale = min(width / canvasWidth, height / canvasHeight)
        .clamp(0.025, 1.0)
        .toDouble() * 0.94;
    final dx = (width - canvasWidth * scale) / 2;
    final dy = (height - canvasHeight * scale) / 2;
    _transform.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  void _zoomBy(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.025, 12.0).toDouble();
    if ((next - current).abs() < 0.0001) return;
    final ratio = next / max(current, 0.0001);
    final matrix = _transform.value.clone()..scale(ratio);
    _transform.value = matrix;
  }

  void _focusNode(String node, {bool remember = true}) {
    final n = node.trim();
    if (n.isEmpty) return;
    if (remember) _history.add(_focus);
    setState(() {
      _focus = n;
      _search.text = n;
      _showRelations = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  void _goBack() {
    if (_history.isEmpty) return;
    setState(() {
      _focus = _history.removeLast();
      _search.text = _focus ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  void _home() {
    if (_focus != null) _history.add(_focus);
    setState(() {
      _focus = null;
      _search.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  void _submitSearch(String raw) {
    final q = PlasticLanguageBrain04.normalizeText(raw);
    if (q.isEmpty) {
      _home();
      return;
    }
    final names = _cachedNodes;
    final exact = names.where(
      (n) => PlasticLanguageBrain04.normalizeText(n) == q,
    );
    if (exact.isNotEmpty) {
      _focusNode(exact.first);
      _searchFocus.unfocus();
      return;
    }
    final partial = names.where(
      (n) => PlasticLanguageBrain04.normalizeText(n).contains(q),
    );
    if (partial.isNotEmpty) {
      _focusNode(partial.first);
      _searchFocus.unfocus();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nessun nodo trovato per “$raw”.')),
    );
  }

  int _hash26(String s){
    var h=0x811c9dc5;
    for(final c in s.codeUnits){h^=c;h=(h*0x01000193)&0x7fffffff;}
    return h;
  }

  Map<String,int> _communities26(Set<String> nodes,List<SemanticLink13> links,Map<String,int> degree){
    final weighted=<String,Map<String,double>>{for(final n in nodes)n:<String,double>{}};
    for(final e in links){
      if(!nodes.contains(e.from)||!nodes.contains(e.to))continue;
      weighted[e.from]![e.to]=(weighted[e.from]![e.to]??0)+max(.08,e.confidence);
      weighted[e.to]![e.from]=(weighted[e.to]![e.from]??0)+max(.08,e.confidence);
    }
    final label=<String,String>{for(final n in nodes)n:n};
    final order=nodes.toList()..sort((a,b){
      final d=(degree[b]??0).compareTo(degree[a]??0);return d!=0?d:a.compareTo(b);
    });
    for(var iter=0;iter<7;iter++){
      var changed=0;
      final sizes=<String,int>{};
      for(final l in label.values)sizes[l]=(sizes[l]??0)+1;
      for(final n in order){
        final scores=<String,double>{};
        for(final e in weighted[n]!.entries){
          final l=label[e.key]!;
          scores[l]=(scores[l]??0)+e.value;
        }
        if(scores.isEmpty)continue;
        final current=label[n]!;
        scores[current]=(scores[current]??0)+.28*sqrt(1+(degree[n]??0));
        String best=current;var bestScore=-1e30;
        final keys=scores.keys.toList()..sort();
        for(final l in keys){
          final penalty=.055*log(1+(sizes[l]??1));
          final sc=scores[l]!-penalty;
          if(sc>bestScore){bestScore=sc;best=l;}
        }
        if(best!=current){label[n]=best;changed++;}
      }
      if(changed==0)break;
    }
    final canonical=<String,int>{};var next=0;
    final out=<String,int>{};
    for(final n in nodes){final l=label[n]!;out[n]=canonical.putIfAbsent(l,()=>next++);}
    return out;
  }

  Map<String,Offset> _topologicalPositions26({
    required Set<String> selected,
    required List<SemanticLink13> links,
    required Map<String,int> degree,
    required Size canvasSize,
  }){
    final center=Offset(canvasSize.width/2,canvasSize.height/2);
    final community=_communities26(selected,links,degree);
    final members=<int,List<String>>{};
    for(final n in selected)members.putIfAbsent(community[n]!,()=>[]).add(n);
    final cWeight=<int,double>{for(final c in members.keys)c:0};
    final inter=<int,Map<int,double>>{};
    for(final e in links){
      final a=community[e.from],b=community[e.to];if(a==null||b==null)continue;
      cWeight[a]=(cWeight[a]??0)+e.confidence;cWeight[b]=(cWeight[b]??0)+e.confidence;
      if(a!=b){inter.putIfAbsent(a,()=>{})[b]=(inter[a]?[b]??0)+e.confidence;inter.putIfAbsent(b,()=>{})[a]=(inter[b]?[a]??0)+e.confidence;}
    }
    final cs=members.keys.toList()..sort((a,b)=>((members[b]!.length*3)+(cWeight[b]??0)).compareTo((members[a]!.length*3)+(cWeight[a]??0)));
    final centers=<int,Offset>{};
    final radii=<int,double>{};
    final maxR=min(canvasSize.width,canvasSize.height)*.36;
    const ga=2.399963229728653;
    for(var i=0;i<cs.length;i++){
      final c=cs[i];
      radii[c]=52+18*sqrt(members[c]!.length.toDouble());
      if(i==0){centers[c]=center;continue;}
      final t=sqrt(i/max(1,cs.length-1));
      final angle=i*ga+((_hash26(members[c]!.first)%1000)/1000)*.7;
      centers[c]=center+Offset(cos(angle)*maxR*t,sin(angle)*maxR*t);
    }
    // Small force pass on community centroids: connected communities attract,
    // communities repel according to their visual radius. This preserves
    // topology while avoiding the identical sunflower image of 0.25.
    for(var iter=0;iter<28 && cs.length>1;iter++){
      final delta=<int,Offset>{for(final c in cs)c:Offset.zero};
      for(var i=0;i<cs.length;i++)for(var j=i+1;j<cs.length;j++){
        final a=cs[i],b=cs[j];var d=centers[b]!-centers[a]!;var dist=max(1.0,d.distance);final unit=d/dist;
        final minDist=(radii[a]!+radii[b]!)*1.45+36;
        final repel=max(0.0,minDist-dist)*.055 + 1400/(dist*dist);
        delta[a]=delta[a]!-unit*repel;delta[b]=delta[b]!+unit*repel;
      }
      for(final a in cs){
        for(final e in (inter[a]??const <int,double>{}).entries){
          if(a>=e.key)continue;final b=e.key;var d=centers[b]!-centers[a]!;final dist=max(1.0,d.distance);final unit=d/dist;
          final target=170+radii[a]!+radii[b]!;final pull=(dist-target)*.0045*min(4.0,1+e.value);
          delta[a]=delta[a]!+unit*pull;delta[b]=delta[b]!-unit*pull;
        }
      }
      for(final c in cs){
        final gravity=(center-centers[c]!)*.006;
        centers[c]=centers[c]!+delta[c]!+gravity;
      }
    }
    final pos=<String,Offset>{};
    for(final c in cs){
      final xs=members[c]!..sort((a,b){final d=(degree[b]??0).compareTo(degree[a]??0);return d!=0?d:a.compareTo(b);});
      final cc=centers[c]!;if(xs.isEmpty)continue;pos[xs.first]=cc;
      final localMax=max(55.0,radii[c]!*1.25);
      for(var i=1;i<xs.length;i++){
        final n=xs[i];final t=sqrt(i/max(1,xs.length-1));
        final jitter=((_hash26(n)%10000)/10000)*2*pi;
        final angle=i*ga+jitter*.42;
        pos[n]=cc+Offset(cos(angle)*localMax*t,sin(angle)*localMax*t);
      }
    }
    return pos;
  }

  _GraphLayout13 _layout() {
    final links = _allLinks;
    final cacheKey = '${_memoryMode24}|${_focus ?? ''}|$_depth|$_nodeLimit|${_minConfidence.toStringAsFixed(3)}|${links.length}';
    if (_layoutCacheKey == cacheKey && _layoutCache != null) {
      return _layoutCache!;
    }
    if (links.isEmpty) {
      const empty = _GraphLayout13(
        nodes: <String>[],
        links: <SemanticLink13>[],
        positions: <String, Offset>{},
        labelNodes: <String>{},
        degree: <String,int>{},
        canvasSize: Size(1800, 1300),
      );
      _layoutCache = empty;
      _layoutCacheKey = cacheKey;
      return empty;
    }

    final adjacency = <String, Set<String>>{};
    final degree = <String, int>{};
    for (final l in links) {
      adjacency.putIfAbsent(l.from, () => <String>{}).add(l.to);
      adjacency.putIfAbsent(l.to, () => <String>{}).add(l.from);
      degree[l.from] = (degree[l.from] ?? 0) + 1;
      degree[l.to] = (degree[l.to] ?? 0) + 1;
    }
    for (final node in _cachedNodes) {
      adjacency.putIfAbsent(node, () => <String>{});
      degree.putIfAbsent(node, () => 0);
    }

    final targetLimit = _nodeLimit < 0 ? _cachedNodes.length : min(_nodeLimit, _cachedNodes.length);
    final selected = <String>{};
    final level = <String, int>{};
    final focus = _focus;
    if (focus != null && adjacency.containsKey(focus)) {
      final queue = <String>[focus];
      level[focus] = 0;
      selected.add(focus);
      var head = 0;
      while (head < queue.length && selected.length < targetLimit) {
        final current = queue[head++];
        final d = level[current] ?? 0;
        if (d >= _depth) continue;
        final neighbors = (adjacency[current] ?? const <String>{}).toList()
          ..sort((a, b) => (degree[b] ?? 0).compareTo(degree[a] ?? 0));
        for (final next in neighbors) {
          if (selected.length >= targetLimit) break;
          if (selected.add(next)) {
            level[next] = d + 1;
            queue.add(next);
          }
        }
      }
    } else {
      final ranked = degree.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in ranked.take(targetLimit)) {
        selected.add(e.key);
      }
    }

    final visibleLinks = links
        .where((l) => selected.contains(l.from) && selected.contains(l.to))
        .toList(growable: false);

    final n = selected.length;
    final side = n <= 300
        ? 1800.0
        : n <= 1200
            ? 3600.0
            : n <= 3000
                ? 6000.0
                : n <= 10000
                    ? 10000.0
                    : min(18000.0, 10000.0 + sqrt(n - 10000) * 65.0);
    final canvasSize = Size(side, max(1300.0, side * 0.82));
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final positions = <String, Offset>{};

    if (focus != null && selected.contains(focus)) {
      positions[focus] = center;
      final levels = <int, List<String>>{};
      for (final node in selected) {
        if (node == focus) continue;
        final d = level[node] ?? _depth;
        levels.putIfAbsent(d, () => <String>[]).add(node);
      }
      final maxRadius = min(canvasSize.width, canvasSize.height) * 0.43;
      for (final entry in levels.entries) {
        final ring = entry.key;
        final nodes = entry.value
          ..sort((a, b) => (degree[b] ?? 0).compareTo(degree[a] ?? 0));
        final radius = maxRadius * ring / max(1, _depth);
        for (var i = 0; i < nodes.length; i++) {
          final angle = 2 * pi * i / max(1, nodes.length) - pi / 2;
          positions[nodes[i]] =
              center + Offset(cos(angle) * radius, sin(angle) * radius);
        }
      }
    } else {
      positions.addAll(_topologicalPositions26(
        selected:selected,
        links:visibleLinks,
        degree:degree,
        canvasSize:canvasSize,
      ));
    }

    final rankedForLabels = selected.toList()
      ..sort((a, b) => (degree[b] ?? 0).compareTo(degree[a] ?? 0));
    final labelBudget = n <= 300
        ? n
        : n <= 1000
            ? 120
            : n <= 3000
                ? 80
                : 48;
    final labelNodes = rankedForLabels.take(labelBudget).toSet();
    if (focus != null) labelNodes.add(focus);

    final result = _GraphLayout13(
      nodes: selected.toList(growable: false),
      links: visibleLinks,
      positions: positions,
      labelNodes: labelNodes,
      degree: {for(final n in selected)n:(degree[n]??0)},
      canvasSize: canvasSize,
    );
    _layoutCache = result;
    _layoutCacheKey = cacheKey;
    return result;
  }

  List<SemanticLink13> _connectionsOf(String node) {
    return _allLinks
        .where((l) => l.from == node || l.to == node)
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  Future<void> _setNodeLimit(int value) async {
    if (value < 0 && _cachedNodes.length > 3000) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mostrare tutti i nodi?'),
          content: Text(
            'La mappa contiene ${_cachedNodes.length} nodi. Verranno disegnati tutti, '
            'ma le etichette saranno ridotte automaticamente per evitare rallentamenti. '
            'Su grafi molto grandi pan e zoom possono comunque diventare meno fluidi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mostra tutti'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    setState(() {
      _nodeLimit = value;
      if (value < 0 || value > 750) {
        _showRelations = false;
        _showNodeLabels = false;
      }
      _layoutCache = null;
      _layoutCacheKey = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  void _refreshMap() {
    setState(() {
      _refreshGraphCache();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  Future<void> _savePng25() async{
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

  @override
  Widget build(BuildContext context) {
    final layout = _layout();
    _lastCanvasSize = layout.canvasSize;
    final selectedConnections = _focus == null
        ? const <SemanticLink13>[]
        : _connectionsOf(_focus!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Cerca un concetto e apri il suo vicinato',
                    suffixIcon: IconButton(
                      tooltip: 'Cerca',
                      onPressed: () => _submitSearch(_search.text),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(scrollDirection:Axis.horizontal,child:SegmentedButton<String>(
                  showSelectedIcon:false,
                  segments:const [
                    ButtonSegment(value:'mondo',label:Text('Mondo')),
                    ButtonSegment(value:'concetti',label:Text('Concetti')),
                    ButtonSegment(value:'episodi',label:Text('Episodi')),
                    ButtonSegment(value:'ipotesi',label:Text('Ipotesi')),
                  ],
                  selected:<String>{_memoryMode24},
                  onSelectionChanged:(v){setState((){_memoryMode24=v.first;_focus=null;_search.clear();_refreshGraphCache();});WidgetsBinding.instance.addPostFrameCallback((_)=>_fitView());},
                )),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Indietro',
                        onPressed: _history.isEmpty ? null : _goBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Vista globale',
                        onPressed: _home,
                        icon: const Icon(Icons.home_outlined),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Ricalcola layout topologico',
                        onPressed: _refreshMap,
                        icon: const Icon(Icons.refresh),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(tooltip:'Salva PNG',onPressed:_savePng25,icon:const Icon(Icons.image_outlined)),
                      const SizedBox(width:6),
                      IconButton.filledTonal(
                        tooltip: 'Riduci zoom',
                        onPressed: () => _zoomBy(0.75),
                        icon: const Icon(Icons.remove),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Adatta alla schermata',
                        onPressed: _fitView,
                        icon: const Icon(Icons.fit_screen),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Aumenta zoom',
                        onPressed: () => _zoomBy(1.33),
                        icon: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 12),
                      const Text('Profondità'),
                      const SizedBox(width: 6),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1')),
                          ButtonSegment(value: 2, label: Text('2')),
                          ButtonSegment(value: 3, label: Text('3')),
                        ],
                        selected: <int>{_depth},
                        onSelectionChanged: (v) {
                          setState(() {
                            _depth = v.first;
                            _layoutCache = null;
                            _layoutCacheKey = null;
                          });
                          _resetView();
                        },
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _nodeLimit,
                        underline: const SizedBox.shrink(),
                        items: <int>[40, 80, 150, 300, 750, 1500, 3000, -1]
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text(
                                    n < 0 ? 'Tutti (${_cachedNodes.length})' : '$n nodi',
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _setNodeLimit(v);
                        },
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Nomi'),
                        selected: _showNodeLabels,
                        onSelected: (v) {
                          if (v && layout.nodes.length > 3000) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Con migliaia di nodi mostro solo le etichette principali per mantenere la mappa fluida.',
                                ),
                              ),
                            );
                          }
                          setState(() => _showNodeLabels = v);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
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
                      ],

                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: widget.fullPage ? max(420.0, MediaQuery.of(context).size.height - 300.0) : 470,
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: layout.nodes.isEmpty
                ? const Center(child: Text('Nessun collegamento da mostrare.'))
                : RepaintBoundary(
                    key:_pngKey25,
                    child: InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(500),
                    minScale: 0.025,
                    maxScale: 12.0,
                    interactionEndFrictionCoefficient: 0.00005,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        String? hit;
                        var best = 30.0;
                        for (final e in layout.positions.entries) {
                          final d = (e.value - details.localPosition).distance;
                          if (d < best) {
                            best = d;
                            hit = e.key;
                          }
                        }
                        if (hit != null) _focusNode(hit!);
                      },
                      child: SizedBox(
                        width: layout.canvasSize.width,
                        height: layout.canvasSize.height,
                        child: CustomPaint(
                          isComplex: true,
                          willChange: false,
                          painter: _NavigableGraphPainter13(
                            layout: layout,
                            focus: _focus,
                            showRelations: _showRelations,
                            showNodeLabels: _showNodeLabels,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _focus == null
                      ? 'Vista topologica • ${layout.nodes.length}/${_cachedNodes.length} nodi • ${layout.links.length} archi'
                      : 'Focus: $_focus • ${selectedConnections.length} collegamenti totali',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (_focus != null && selectedConnections.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...selectedConnections.take(6).map((l) {
                    final other = l.from == _focus ? l.to : l.from;
                    final relation = l.from == _focus
                        ? l.relation
                        : '← ${l.relation}';
                    return InkWell(
                      onTap: () => _focusNode(other),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.hub_outlined, size: 16),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text('$relation → $other'),
                            ),
                            Text('${(l.confidence * 100).round()}%'),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 6),
                Text(
                  'Tocca un nodo per entrarci. La posizione globale è calcolata dalla topologia: comunità connesse stanno vicine, hub più centrali e nodi meno connessi in periferia. Usa + e − per lo zoom e Adatta per rientrare nella vista.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphLayout13 {
  final List<String> nodes;
  final List<SemanticLink13> links;
  final Map<String, Offset> positions;
  final Set<String> labelNodes;
  final Map<String,int> degree;
  final Size canvasSize;

  const _GraphLayout13({
    required this.nodes,
    required this.links,
    required this.positions,
    required this.labelNodes,
    required this.degree,
    required this.canvasSize,
  });
}

class _NavigableGraphPainter13 extends CustomPainter {
  final _GraphLayout13 layout;
  final String? focus;
  final bool showRelations;
  final bool showNodeLabels;

  const _NavigableGraphPainter13({
    required this.layout,
    required this.focus,
    required this.showRelations,
    required this.showNodeLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()..style = PaintingStyle.stroke;
    for (final l in layout.links) {
      final a = layout.positions[l.from];
      final b = layout.positions[l.to];
      if (a == null || b == null) continue;
      edgePaint
        ..strokeWidth = 0.7 + 3.0 * l.confidence.clamp(0.0, 1.0)
        ..color = Colors.white.withValues(
          alpha: 0.08 + 0.34 * l.confidence.clamp(0.0, 1.0),
        );
      canvas.drawLine(a, b, edgePaint);
      if (showRelations && layout.links.length <= 1200) {
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: l.relation,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 120);
        tp.paint(canvas, mid + const Offset(4, -14));
      }
    }

    for (final node in layout.nodes) {
      final p = layout.positions[node];
      if (p == null) continue;
      final selected = node == focus;
      final circle = Paint()
        ..color = selected
            ? Colors.amberAccent.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.84);
      final hubRadius=5.5+min(7.5,log(1+(layout.degree[node]??0))*1.65);
      canvas.drawCircle(p, selected ? 12 : hubRadius, circle);
      if (selected) {
        final halo = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.amberAccent.withValues(alpha: 0.35);
        canvas.drawCircle(p, 19, halo);
      }
      if (selected || (showNodeLabels && layout.labelNodes.contains(node))) {
        final tp = TextPainter(
          text: TextSpan(
            text: node,
            style: TextStyle(
              fontSize: selected ? 15 : (layout.nodes.length > 1000 ? 11 : 13),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.amberAccent : Colors.white70,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: selected ? 190 : 145);
        tp.paint(canvas, p + const Offset(13, -10));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NavigableGraphPainter13 oldDelegate) =>
      !identical(layout, oldDelegate.layout) ||
      focus != oldDelegate.focus ||
      showRelations != oldDelegate.showRelations ||
      showNodeLabels != oldDelegate.showNodeLabels;
}
