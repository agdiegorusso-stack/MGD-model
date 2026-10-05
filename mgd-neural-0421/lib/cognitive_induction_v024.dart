import 'dart:math';

import 'plastic_language_brain_v04.dart';
import 'web_knowledge_explorer_v11.dart';

String _k24(String x)=>PlasticLanguageBrain04.normalizeText(x).replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'),' ').replaceAll(RegExp(r'\s+'),' ').trim();

class CognitiveOutcome24{
  final int episodes;
  final int concepts;
  final int narrativeLinks;
  final int terms;
  const CognitiveOutcome24({required this.episodes,required this.concepts,required this.narrativeLinks,required this.terms});
  String get summary=>'cognizione: +$episodes episodi, $concepts concetti emergenti, $narrativeLinks legami narrativi, $terms termini attivi';
}

class CognitiveInduction24{
  static const _stop=<String>{
    'a','ad','al','alla','allo','ai','agli','alle','da','dal','dalla','dallo','dei','degli','delle','di','del','della','dello','e','ed','o','oppure','ma','che','chi','cui','con','come','per','tra','fra','su','sul','sulla','sullo','un','uno','una','il','lo','la','i','gli','le','in','nel','nella','nello','nei','nelle','non','si','se','mi','ti','ci','vi','ne','io','tu','lui','lei','noi','voi','loro','mio','mia','tuo','tua','suo','sua','questo','questa','quello','quella','era','è','sono','fu','ha','hanno','aveva','avevano','più','meno','molto','molta','molti','molte','poi','ora','così','allora','già','ancora','anche','solo','tutto','tutta','tutti','tutte'
  };

  static List<String> _terms(String sentence){
    final xs=PlasticLanguageBrain04.lexicalTokens(sentence)
      .map(_k24)
      .where((x)=>x.length>=3&&!_stop.contains(x)&&!RegExp(r'^\d+$').hasMatch(x))
      .toList();
    final seen=<String>{};
    return xs.where(seen.add).take(12).toList();
  }

  static List<String> _sentences(String raw)=>raw
      .replaceAll('\r','\n')
      .replaceAll(RegExp(r'\n{2,}'),'. ')
      .split(RegExp(r'[.!?]+(?:\s+|$)|\n+'))
      .map((x)=>x.trim())
      .where((x)=>x.length>=12&&x.length<=650)
      .toList();

  static Set<String> _topNeighbors(String term,ResearchMemory11 memory,{int k=10}){
    final t=memory.termMemory[term];
    if(t==null||t.co.isEmpty)return <String>{};
    final xs=t.co.entries.where((e)=>memory.termMemory.containsKey(e.key)).toList()
      ..sort((a,b){
        final ta=memory.termMemory[a.key]!,tb=memory.termMemory[b.key]!;
        final sa=a.value/sqrt(max(1,t.count*ta.count));
        final sb=b.value/sqrt(max(1,t.count*tb.count));
        return sb.compareTo(sa);
      });
    return xs.take(k).map((e)=>e.key).toSet();
  }

  static bool _functionLike25(String x){
    const bad={'avesse','avrebbe','avessero','fosse','fossero','sarebbe','siano','sia','quei','quelle','quelli','qualche','ogni','altro','altra','altri','altre','certo','certa','pure','quasi','proprio','invece','dunque','ebbene'};
    return _stop.contains(x)||bad.contains(x);
  }
  static double _labelScore25(String x,ResearchMemory11 m){
    final t=m.termMemory[x]; if(t==null)return 0;
    return log(1+t.count)/sqrt(max(1,t.co.length));
  }
  static void recrystallize(ResearchMemory11 m){_rebuildConcepts(m);m.trim();}

  static void _rebuildConcepts(ResearchMemory11 memory){
    final candidates=memory.termMemory.values.where((t)=>t.count>=4&&t.co.length>=2&&!_functionLike25(t.term)).toList()
      ..sort((a,b)=>b.count.compareTo(a.count));
    final terms=candidates.take(420).map((x)=>x.term).toList();
    // Build each local neighbourhood exactly once. With ~1,800 active terms
    // the previous implementation could sort neighbour lists hundreds of
    // thousands of times during startup.
    final neighborCache=<String,Set<String>>{
      for(final t in terms) t:_topNeighbors(t,memory),
    };
    final used=<String>{};
    final found=<String,EmergentConcept24>{};
    var idx=0;
    for(final a in terms){
      if(used.contains(a))continue;
      final na=neighborCache[a]??<String>{};
      if(na.length<2)continue;
      final group=<String>[a];
      var simSum=0.0;
      for(final b in terms){
        if(a==b||used.contains(b))continue;
        final nb=neighborCache[b]??<String>{};
        if(nb.length<2)continue;
        final union=na.union(nb);
        final sim=union.isEmpty?0.0:na.intersection(nb).length/union.length;
        if(sim>=.24){group.add(b);simSum+=sim;if(group.length>=7)break;}
      }
      if(group.length<2)continue;
      group.removeWhere(_functionLike25);
      if(group.length<2)continue;
      group.sort((x,y)=>_labelScore25(y,memory).compareTo(_labelScore25(x,memory)));
      var common=Set<String>.of(neighborCache[group.first]??<String>{});
      for(final g in group.skip(1))common=common.intersection(neighborCache[g]??<String>{});
      final sources=<String>{};
      var support=0;
      for(final g in group){final tm=memory.termMemory[g];if(tm!=null){support+=tm.count;sources.addAll(tm.sources);}}
      final coherence=(simSum/max(1,group.length-1)).clamp(0,1).toDouble();
      final diversity=min(1.0,sources.length/2.0);
      final context=min(1.0,common.length/3.0);
      final supportScore=min(1.0,support/80.0);
      final quality=(.45*coherence+.25*diversity+.20*context+.10*supportScore).clamp(0.0,1.0).toDouble();
      final crystallized=quality>=.43 && support>=18 && (sources.length>=2 || support>=80);
      final id='c24:${group.take(4).join('|')}';
      found[id]=EmergentConcept24(id:id,label:group.first,members:group,anchors:common.take(5).toList(),support:support,coherence:coherence,quality:quality,crystallized:crystallized,sources:sources);
      used.addAll(group);idx++;if(idx>=120)break;
    }
    memory.emergentConcepts
      ..clear()
      ..addAll(found);
  }

  static Future<int> backfillLegacyPassages030({
    required PlasticLanguageBrain04 brain,
    required ResearchMemory11 memory,
    int maxSources=24,
  }) async {
    final grouped=<String,List<String>>{};
    final labels=<String,String>{};
    for(final p in memory.passages){
      final key=memory.cognitiveSourceKey030(provider:p.provider,family:p.sourceFamily,title:p.sourceTitle,url:p.sourceUrl);
      if(memory.cognitiveSources030.contains(key))continue;
      grouped.putIfAbsent(key,()=> <String>[]).add(p.text);
      labels[key]='${p.provider}: ${p.sourceTitle}';
    }
    for(final e in memory.evidence){
      final key=memory.cognitiveSourceKey030(provider:e.provider,family:e.sourceFamily,title:e.sourceTitle,url:e.sourceUrl);
      if(memory.cognitiveSources030.contains(key))continue;
      grouped.putIfAbsent(key,()=> <String>[]).add(e.excerpt);
      labels[key]='${e.provider}: ${e.sourceTitle}';
    }
    var processed=0;
    for(final entry in grouped.entries.take(maxSources)){
      final unique=entry.value.map((x)=>x.trim()).where((x)=>x.isNotEmpty).toSet().take(48);
      final body=unique.join('. ');
      if(body.trim().isEmpty){memory.cognitiveSources030.add(entry.key);continue;}
      await learn(text:body,sourceName:labels[entry.key]??'Ricerca web migrata',brain:brain,memory:memory);
      memory.cognitiveSources030.add(entry.key);
      processed++;
      await Future<void>.delayed(Duration.zero);
    }
    return processed;
  }

  static Future<CognitiveOutcome24> learn({required String text,required String sourceName,required PlasticLanguageBrain04 brain,required ResearchMemory11 memory})async{
    final sentences=_sentences(text);
    var addedEpisodes=0;
    var addedLinks=0;
    final now=DateTime.now();
    for(var i=0;i<sentences.length;i++){
      final sentence=sentences[i];
      final terms=_terms(sentence);
      final report=brain.learnNarrativeEpisode24(sentence,reward:.07);
      memory.narrativeSentencesSeen++;
      for(final t in terms){
        final tm=memory.termMemory.putIfAbsent(t,()=>TermMemory24(t));
        tm.count++;tm.sources.add(sourceName);
      }
      for(var a=0;a<terms.length;a++){
        for(var b=a+1;b<min(terms.length,a+7);b++){
          final x=terms[a],y=terms[b];
          memory.termMemory[x]?.co[y]=(memory.termMemory[x]?.co[y]??0)+1;
          memory.termMemory[y]?.co[x]=(memory.termMemory[y]?.co[x]??0)+1;
        }
      }
      if(terms.length>=2){
        final salient=(report.novelty>.28||report.predictionError>.35||i%4==0);
        if(salient){
          final id=memory.nextNarrativeEpisodeId++;
          memory.narrativeEpisodes.add(NarrativeEpisode24(id:id,source:sourceName,text:sentence,terms:terms.take(8).toList(),salience:(.35+.35*report.novelty+.2*report.predictionError).clamp(.0,1.0).toDouble(),createdAtIso:now.toIso8601String()));
          addedEpisodes++;
          final hub=terms.first;
          for(final t in terms.skip(1).take(4)){
            memory.narrativeLinks.add(NarrativeLink24(episodeId:'e24:$id',from:hub,relation:'co-presente',to:t,confidence:(.34+.25*report.novelty).clamp(.34,.72).toDouble(),source:sourceName));
            addedLinks++;
          }
        }
      }
      if(i%40==0)await Future<void>.delayed(Duration.zero);
    }
    _rebuildConcepts(memory);
    memory.trim();
    return CognitiveOutcome24(episodes:addedEpisodes,concepts:memory.emergentConcepts.values.where((c)=>c.crystallized).length,narrativeLinks:addedLinks,terms:memory.termMemory.length);
  }
}
