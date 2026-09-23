from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'mgd_language_v020.dart'
s=p.read_text()

old_stats="""class MgdLanguageStats20 {
  final int tokens;
  final int edges;
  final int chunks;
  final int sentences;
  final int characters;
  final double meanMaterial;
  final double lastFlux;
  const MgdLanguageStats20({required this.tokens,required this.edges,required this.chunks,required this.sentences,required this.characters,required this.meanMaterial,required this.lastFlux});
}"""

new_stats="""class MgdLanguageStats20 {
  // Unique graph sizes.
  final int tokens;
  final int edges;
  final int chunks;

  // Cumulative exposure counters. These keep increasing even when a corpus
  // contains only words/transitions the graph has already seen.
  final int tokenOccurrences;
  final int edgeUses;
  final int chunkOccurrences;
  final int sentences;
  final int characters;
  final double meanMaterial;
  final double lastFlux;

  const MgdLanguageStats20({
    required this.tokens,
    required this.edges,
    required this.chunks,
    required this.tokenOccurrences,
    required this.edgeUses,
    required this.chunkOccurrences,
    required this.sentences,
    required this.characters,
    required this.meanMaterial,
    required this.lastFlux,
  });
}"""
if old_stats not in s: raise SystemExit('stats class anchor missing')
s=s.replace(old_stats,new_stats,1)

old_fn="""  MgdLanguageStats20 stats(){
    final mean=edges.isEmpty?0.0:edges.values.fold<double>(0,(a,e)=>a+e.material)/edges.length;
    return MgdLanguageStats20(tokens:tokenCount.length,edges:edges.length,chunks:chunks.values.where((c)=>c.count>=4).length,sentences:sentences,characters:characters,meanMaterial:mean,lastFlux:lastFlux);
  }"""

new_fn="""  MgdLanguageStats20 stats(){
    final mean=edges.isEmpty?0.0:edges.values.fold<double>(0,(a,e)=>a+e.material)/edges.length;
    final tokenOccurrences=tokenCount.values.fold<int>(0,(a,v)=>a+v);
    final edgeUses=edges.values.fold<int>(0,(a,e)=>a+e.uses);
    final chunkOccurrences=chunks.values.fold<int>(0,(a,c)=>a+c.count);
    return MgdLanguageStats20(
      tokens:tokenCount.length,
      edges:edges.length,
      chunks:chunks.values.where((c)=>c.count>=4).length,
      tokenOccurrences:tokenOccurrences,
      edgeUses:edgeUses,
      chunkOccurrences:chunkOccurrences,
      sentences:sentences,
      characters:characters,
      meanMaterial:mean,
      lastFlux:lastFlux,
    );
  }"""
if old_fn not in s: raise SystemExit('stats() anchor missing')
s=s.replace(old_fn,new_fn,1)

old_status="""      if(mounted)setState(()=>status='${sourceName==null?'Testo':'Corpus $sourceName'} incorporato: +${after.sentences-before.sentences} frasi, +${after.tokens-before.tokens} token, +${after.edges-before.edges} archi, +${after.chunks-before.chunks} macro-nodi.');"""

new_status="""      final dSent=after.sentences-before.sentences;
      final dTokSeen=after.tokenOccurrences-before.tokenOccurrences;
      final dEdgeUses=after.edgeUses-before.edgeUses;
      final dChunkUses=after.chunkOccurrences-before.chunkOccurrences;
      final dVocab=after.tokens-before.tokens;
      final dEdges=after.edges-before.edges;
      final dChunks=after.chunks-before.chunks;
      final dMatter=after.meanMaterial-before.meanMaterial;
      if(mounted)setState(()=>status=
        '${sourceName==null?'Testo':'Corpus $sourceName'} appreso: '
        '+$dSent frasi, +$dTokSeen token letti, +$dEdgeUses transizioni rinforzate, '
        '+$dChunkUses sequenze elaborate. Nuove strutture: +$dVocab parole, '
        '+$dEdges archi, +$dChunks macro-nodi. Δ materia ${dMatter>=0?'+':''}${dMatter.toStringAsFixed(3)}.'
      );"""
if old_status not in s: raise SystemExit('import status anchor missing')
s=s.replace(old_status,new_status,1)

old_ui="""Wrap(spacing:8,runSpacing:8,children:[_LMetric20('Token','${s.tokens}'),_LMetric20('Archi','${s.edges}'),_LMetric20('Macro-nodi','${s.chunks}'),_LMetric20('Frasi viste','${s.sentences}'),_LMetric20('Materia media',s.meanMaterial.toStringAsFixed(3))])"""

new_ui="""Wrap(spacing:8,runSpacing:8,children:[
  _LMetric20('Vocabolario','${s.tokens}'),
  _LMetric20('Token visti','${s.tokenOccurrences}'),
  _LMetric20('Archi unici','${s.edges}'),
  _LMetric20('Passaggi','${s.edgeUses}'),
  _LMetric20('Macro-nodi','${s.chunks}'),
  _LMetric20('Frasi viste','${s.sentences}'),
  _LMetric20('Materia media',s.meanMaterial.toStringAsFixed(3))
])"""
if old_ui not in s: raise SystemExit('metrics UI anchor missing')
s=s.replace(old_ui,new_ui,1)

p.write_text(s)

pub=root/'pubspec.yaml'
ps=pub.read_text()
ps=ps.replace('version: 0.20.3+30','version: 0.20.4+31')
pub.write_text(ps)
