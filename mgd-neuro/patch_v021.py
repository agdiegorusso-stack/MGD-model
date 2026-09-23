from pathlib import Path
import sys

root=Path(sys.argv[1])

# --- language engine ---
p=root/'lib'/'mgd_language_v020.dart'
s=p.read_text()
if "package:flutter/foundation.dart" not in s:
    s=s.replace("import 'package:file_picker/file_picker.dart';", "import 'package:file_picker/file_picker.dart';\nimport 'package:flutter/foundation.dart';",1)
if "_encodeLanguageSnapshot21" not in s:
    s=s.replace("import 'sensory_world_v06.dart';", "import 'sensory_world_v06.dart';\n\nString _encodeLanguageSnapshot21(Map<String,dynamic> x)=>jsonEncode(x);",1)

old="""class _Chunk20 { final String text; int count; double material; _Chunk20(this.text,{this.count=0,this.material=0}); Map<String,dynamic> toJson()=>{'t':text,'c':count,'m':material}; factory _Chunk20.fromJson(Map<String,dynamic> j)=>_Chunk20(j['t'],count:(j['c'] as num?)?.toInt()??0,material:(j['m'] as num?)?.toDouble()??0); }

class MgdLanguage20 {"""
new="""class _Chunk20 { final String text; int count; double material; _Chunk20(this.text,{this.count=0,this.material=0}); Map<String,dynamic> toJson()=>{'t':text,'c':count,'m':material}; factory _Chunk20.fromJson(Map<String,dynamic> j)=>_Chunk20(j['t'],count:(j['c'] as num?)?.toInt()??0,material:(j['m'] as num?)?.toDouble()??0); }

class _BeamState21 {
  final List<String> out;
  final String current;
  final double score;
  final Map<String,int> used;
  final bool ended;
  const _BeamState21(this.out,this.current,this.score,this.used,{this.ended=false});
  double get meanScore=>score/max(1,out.length);
}

class MgdLanguage20 {"""
assert old in s
s=s.replace(old,new,1)

old="""  final Map<String,int> tokenCount={};
  final Map<String,_LangEdge20> edges={};
  final Map<String,_Chunk20> chunks={};
  int sentences=0, characters=0; double lastFlux=0;"""
new="""  final Map<String,int> tokenCount={};
  final Map<String,_LangEdge20> edges={};
  final Map<String,_Chunk20> chunks={};

  // MGD 0.21 Active Cognitive Graph. The persistent graph may grow without
  // bound; a thought only touches the locally active neighbourhood.
  final Map<String,List<_LangEdge20>> _outgoing21={};
  final Map<String,List<_Chunk20>> _chunksByHead21={};
  bool _indexesReady21=false;
  int lastGenerateMicros21=0;
  int lastVisitedEdges21=0;
  int lastPeakFrontier21=0;
  String lastStopReason21='';

  int sentences=0, characters=0; double lastFlux=0;"""
assert old in s
s=s.replace(old,new,1)

old="""  static bool punct(String x)=>const {'.','!','?',',',';',':'}.contains(x);
  String _ek(String a,String b)=>'$a\\u0001$b';

  void ingestText(String text,{double reward=.35}) {"""
new="""  static bool punct(String x)=>const {'.','!','?',',',';',':'}.contains(x);
  String _ek(String a,String b)=>'$a\\u0001$b';

  void _indexEdge21(_LangEdge20 e){
    final xs=_outgoing21.putIfAbsent(e.a,()=> <_LangEdge20>[]);
    if(!xs.contains(e))xs.add(e);
  }
  void _indexChunk21(_Chunk20 c){
    if(c.count<3)return;
    final ts=c.text.split(' ');
    if(ts.isEmpty)return;
    final xs=_chunksByHead21.putIfAbsent(ts.first,()=> <_Chunk20>[]);
    if(!xs.contains(c))xs.add(c);
  }
  void _rebuildIndexes21(){
    _outgoing21.clear();_chunksByHead21.clear();
    for(final e in edges.values)_indexEdge21(e);
    for(final c in chunks.values)_indexChunk21(c);
    _indexesReady21=true;
  }
  void _ensureIndexes21(){if(!_indexesReady21)_rebuildIndexes21();}

  void ingestText(String text,{double reward=.35}) {"""
assert old in s
s=s.replace(old,new,1)

old="""        final a=seq[i],b=seq[i+1],k=_ek(a,b); final e=edges.putIfAbsent(k,()=>_LangEdge20(a,b));
        final old=e.material; e.uses++;"""
new="""        final a=seq[i],b=seq[i+1],k=_ek(a,b);
        var e=edges[k];
        if(e==null){e=_LangEdge20(a,b);edges[k]=e;_indexEdge21(e);}
        final old=e.material; e.uses++;"""
assert old in s
s=s.replace(old,new,1)

old="""          final phrase=xs.sublist(i,i+n).join(' '); final c=chunks.putIfAbsent(phrase,()=>_Chunk20(phrase));
          c.count++; final target=(c.count/(c.count+4.0)).clamp(0.0,1.0); c.material=(.93*c.material+.07*target+xi*c.material*(1-c.material)).clamp(0.0,1.0);"""
new="""          final phrase=xs.sublist(i,i+n).join(' '); final c=chunks.putIfAbsent(phrase,()=>_Chunk20(phrase));
          c.count++; final target=(c.count/(c.count+4.0)).clamp(0.0,1.0); c.material=(.93*c.material+.07*target+xi*c.material*(1-c.material)).clamp(0.0,1.0);
          _indexChunk21(c);"""
assert old in s
s=s.replace(old,new,1)

old="""    chunks.removeWhere((_,c)=>c.count<3 && chunks.length>5000);
    lastFlux=flux;"""
new="""    final beforeChunks=chunks.length;
    chunks.removeWhere((_,c)=>c.count<3 && chunks.length>5000);
    if(chunks.length!=beforeChunks)_rebuildIndexes21();
    lastFlux=flux;"""
assert old in s
s=s.replace(old,new,1)

start=s.index("  List<_LangEdge20> _next(String from){")
end=s.index("  String _surface(", start)
old=s[start:end]
new=r'''  List<_LangEdge20> _next(String from){
    _ensureIndexes21();
    return List<_LangEdge20>.of(_outgoing21[from]??const <_LangEdge20>[]);
  }

  bool _active21(_LangEdge20 e,Set<String> wanted){
    return e.cost<=epsilon || e.material>=0.16 || e.slow>=0.22 || wanted.contains(e.b);
  }

  double _chunkBonus21(String token,Set<String> wanted){
    _ensureIndexes21();
    var best=0.0;
    for(final c in _chunksByHead21[token]??const <_Chunk20>[]){
      if(c.count<4)continue;
      var topic=0.0;
      if(wanted.isNotEmpty){
        final ts=c.text.split(' ');
        final hits=ts.where(wanted.contains).length;
        topic=.08*hits;
      }
      best=max(best,.10*c.material+.012*log(1+c.count)+topic);
    }
    return best;
  }

  List<_LangEdge20> _topEdges21(List<_LangEdge20> xs,int k,double Function(_LangEdge20) score){
    if(xs.length<=k){final out=List<_LangEdge20>.of(xs);out.sort((a,b)=>score(b).compareTo(score(a)));return out;}
    final best=<_LangEdge20>[];
    for(final e in xs){
      final v=score(e);
      var pos=0;
      while(pos<best.length && score(best[pos])>=v)pos++;
      if(pos<k){best.insert(pos,e);if(best.length>k)best.removeLast();}
    }
    return best;
  }

  List<_Chunk20> _topChunks21(String head,int k,Set<String>wanted){
    _ensureIndexes21();
    final xs=List<_Chunk20>.of(_chunksByHead21[head]??const <_Chunk20>[])
      ..removeWhere((c)=>c.count<4);
    xs.sort((a,b){
      double sc(_Chunk20 c){
        final ts=c.text.split(' ');
        final hits=ts.where(wanted.contains).length;
        return .7*c.material+.04*log(1+c.count)+.08*hits;
      }
      return sc(b).compareTo(sc(a));
    });
    return xs.take(k).toList();
  }

  String? generate(String context,{String? semanticHint,PlasticLanguageBrain04? brain,int maxWords=42}){
    _ensureIndexes21();
    final clock=Stopwatch()..start();
    lastVisitedEdges21=0;lastPeakFrontier21=0;lastStopReason21='';
    final seed=[...toks(context),...toks(semanticHint??'')];
    if(edges.length<8)return null;
    final wanted=seed.where((x)=>!punct(x)).toSet();
    final starts=_next('<bos>')..removeWhere((e)=>e.b=='<eos>');
    if(starts.isEmpty)return null;
    const beamWidth=8;
    const localWidth=8;
    final startBest=_topEdges21(starts.where((e)=>_active21(e,wanted)).toList(),beamWidth,(e)=>_scoreEdge(e,wanted));
    final usableStarts=startBest.isEmpty?_topEdges21(starts,beamWidth,(e)=>_scoreEdge(e,wanted)):startBest;
    var beam=< _BeamState21>[];
    for(final e in usableStarts){
      lastVisitedEdges21++;
      beam.add(_BeamState21(<String>[e.b],e.b,_scoreEdge(e,wanted),<String,int>{e.b:1}));
    }
    lastPeakFrontier21=beam.length;
    var stableSteps=0;
    var previousBest=-double.infinity;
    for(var step=0;step<maxWords && beam.isNotEmpty;step++){
      final expanded=<_BeamState21>[];
      for(final st in beam){
        if(st.ended){expanded.add(st);continue;}
        final local=_next(st.current);
        final active=local.where((e)=>_active21(e,wanted)).toList();
        final source=active.isEmpty?local:active;
        final top=_topEdges21(source,localWidth,(e)=>_scoreCandidate(e,wanted,st.used));
        lastVisitedEdges21+=source.length;
        for(final e in top){
          if(e.b=='<eos>'){
            if(st.out.length>=4)expanded.add(_BeamState21(st.out,st.current,st.score+.06,st.used,ended:true));
            continue;
          }
          if((st.used[e.b]??0)>=3 && !punct(e.b))continue;
          final out=List<String>.of(st.out)..add(e.b);
          final used=Map<String,int>.of(st.used)..[e.b]=(st.used[e.b]??0)+1;
          final score=st.score+_scoreCandidate(e,wanted,st.used)+_chunkBonus21(e.b,wanted);
          expanded.add(_BeamState21(out,e.b,score,used));
        }
        for(final c in _topChunks21(st.current,2,wanted)){
          final ts=c.text.split(' ');
          if(ts.length<2)continue;
          final tail=ts.skip(1).take(max(0,maxWords-st.out.length)).toList();
          if(tail.isEmpty)continue;
          final out=List<String>.of(st.out)..addAll(tail);
          final used=Map<String,int>.of(st.used);
          var repeated=false;
          for(final t in tail){used[t]=(used[t]??0)+1;if((used[t]??0)>3&&!punct(t))repeated=true;}
          if(repeated)continue;
          final macroScore=.38*c.material+.035*log(1+c.count)+tail.where(wanted.contains).length*.10;
          expanded.add(_BeamState21(out,tail.last,st.score+macroScore,used));
        }
      }
      if(expanded.isEmpty){lastStopReason21='frontiera esaurita';break;}
      expanded.sort((a,b)=>b.meanScore.compareTo(a.meanScore));
      beam=expanded.take(beamWidth).toList();
      lastPeakFrontier21=max(lastPeakFrontier21,beam.length);
      final best=beam.first;
      final delta=(best.meanScore-previousBest).abs();
      if(previousBest.isFinite && delta<0.0015 && best.out.length>=8){stableSteps++;}else{stableSteps=0;}
      previousBest=best.meanScore;
      if(best.ended){lastStopReason21='cammino terminato';break;}
      if(stableSteps>=3){lastStopReason21='Δτ locale stabilizzato';break;}
      if(clock.elapsedMilliseconds>=160){lastStopReason21='budget 160 ms';break;}
    }
    clock.stop();lastGenerateMicros21=clock.elapsedMicroseconds;
    if(lastStopReason21.isEmpty)lastStopReason21='limite cammino';
    if(beam.isEmpty)return null;
    beam.sort((a,b)=>b.meanScore.compareTo(a.meanScore));
    final out=_surface(beam.first.out,brain);
    if(out.split(RegExp(r'\s+')).where((x)=>x.isNotEmpty).length<4)return null;
    ingestText(out,reward:.10);
    return out;
  }

  double _scoreEdge(_LangEdge20 e,Set<String> wanted){
    final topic=wanted.contains(e.b) ? 0.22 : 0.0;
    final flow=(.45*e.slow+.35*min(e.material,mStar)+.20*(1-(e.cost/2.4))).clamp(0.0,1.0).toDouble();
    return (1.7-e.cost)+.52*e.slow+.24*min(e.material,mStar)-.65*max(0,e.material-mStar)+topic+_chunkBonus21(e.b,wanted)+.16*flow+log(1+e.uses)*.025;
  }
  double _scoreCandidate(_LangEdge20 e,Set<String>wanted,Map<String,int> used)=>_scoreEdge(e,wanted)-.30*(used[e.b]??0)+(punct(e.b) ? 0.02 : 0.0);

'''
s=s[:start]+new+s[end:]

old="""  factory MgdLanguage20.fromJson(Map<String,dynamic> j){final m=MgdLanguage20(); m.tokenCount.addAll(Map<String,int>.from((j['tc'] as Map? ??{}).map((k,v)=>MapEntry(k.toString(),(v as num).toInt())))); for(final x in (j['e'] as List? ?? const[])){final e=_LangEdge20.fromJson(Map<String,dynamic>.from(x));m.edges[m._ek(e.a,e.b)]=e;} for(final x in (j['ch'] as List? ?? const[])){final c=_Chunk20.fromJson(Map<String,dynamic>.from(x));m.chunks[c.text]=c;} m.sentences=(j['sentences'] as num?)?.toInt()??0;m.characters=(j['characters'] as num?)?.toInt()??0;m.lastFlux=(j['flux'] as num?)?.toDouble()??0;return m;}"""
new="""  factory MgdLanguage20.fromJson(Map<String,dynamic> j){final m=MgdLanguage20(); m.tokenCount.addAll(Map<String,int>.from((j['tc'] as Map? ??{}).map((k,v)=>MapEntry(k.toString(),(v as num).toInt())))); for(final x in (j['e'] as List? ?? const[])){final e=_LangEdge20.fromJson(Map<String,dynamic>.from(x));m.edges[m._ek(e.a,e.b)]=e;} for(final x in (j['ch'] as List? ?? const[])){final c=_Chunk20.fromJson(Map<String,dynamic>.from(x));m.chunks[c.text]=c;} m.sentences=(j['sentences'] as num?)?.toInt()??0;m.characters=(j['characters'] as num?)?.toInt()??0;m.lastFlux=(j['flux'] as num?)?.toDouble()??0;m._rebuildIndexes21();return m;}"""
assert old in s
s=s.replace(old,new,1)

old="""  Future<void> save(MgdLanguage20 m){
    // Snapshot synchronously, then serialize all disk writes. Autosave, lifecycle
    // save and corpus import can otherwise race on the same .tmp file.
    final payload=jsonEncode(m.toJson());
    final next=_saveTail.catchError((_){}).then((_)=>_writePayload(payload));
    _saveTail=next;
    return next;
  }"""
new="""  Future<void> save(MgdLanguage20 m) async{
    await Future<void>.delayed(Duration.zero);
    final snapshot=m.toJson();
    final payload=await compute(_encodeLanguageSnapshot21,snapshot);
    final next=_saveTail.catchError((_){}).then((_)=>_writePayload(payload));
    _saveTail=next;
    await next;
  }"""
assert old in s
s=s.replace(old,new,1)
p.write_text(s)

p=root/'lib'/'sensory_world_v06.dart'
s=p.read_text()
old="""  List<ThoughtStep06> think(PlasticLanguageBrain04 brain, {int cycles = 48, String? seedText}) {
    if (cycles <= 0) return const [];"""
new="""  List<ThoughtStep06> think(PlasticLanguageBrain04 brain, {int cycles = 48, String? seedText, double? stopFlux}) {
    if (cycles <= 0) return const [];"""
assert old in s
s=s.replace(old,new,1)
old="""    final produced = <ThoughtStep06>[];
    final fatigue = <String, double>{};"""
new="""    final produced = <ThoughtStep06>[];
    var actualCycles16=0;
    var quietCycles16=0;
    final fatigue = <String, double>{};"""
assert old in s
s=s.replace(old,new,1)
old="""    for (var c = 0; c < cycles; c++) {
      final next = <String, double>{};
      for (final entry in activation.entries) next[entry.key] = entry.value * 0.72;"""
new="""    for (var c = 0; c < cycles; c++) {
      actualCycles16=c+1;
      final previousActivation16=Map<String,double>.of(activation);
      final next = <String, double>{};
      for (final entry in activation.entries) next[entry.key] = entry.value * 0.72;"""
assert old in s
s=s.replace(old,new,1)
anchor="""      activation
        ..clear()
        ..addAll(next.map((k, v) => MapEntry(k, v.clamp(0.0, 1.0))));

      if (c % 4 == 3 || c == cycles - 1) {"""
repl="""      activation
        ..clear()
        ..addAll(next.map((k, v) => MapEntry(k, v.clamp(0.0, 1.0))));

      if(stopFlux!=null && c>=3){
        final keys16=<String>{...previousActivation16.keys,...activation.keys};
        var delta16=0.0;
        for(final k in keys16){delta16+=((activation[k]??0.0)-(previousActivation16[k]??0.0)).abs();}
        final normFlux16=keys16.isEmpty?0.0:delta16/keys16.length;
        if(normFlux16<stopFlux){quietCycles16++;}else{quietCycles16=0;}
        if(quietCycles16>=2)break;
      }

      if (c % 4 == 3 || c == cycles - 1) {"""
assert anchor in s
s=s.replace(anchor,repl,1)
s=s.replace("    thoughtCycles += cycles;","    thoughtCycles += actualCycles16;",1)
p.write_text(s)

p=root/'lib'/'main.dart'
s=p.read_text()
old="""    _world.integrateLanguageExperience09(
      _brain,
      text,
      reward: sensoryGrounding != null
          ? 0.9
          : (curiosityAnswer == null ? 0.35 : 0.75),
    );
    _world.think(_brain, cycles: 24, seedText: text);
    _brain.discoverConcepts();
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage04(user: false, text: answer, prompt: text));
      _busy = false;
      final s = _brain.stats();
      _status = 'Esperienza chiusa • Δτ ${s.lastFlux.toStringAsFixed(3)} • episodi ${s.episodes}';
    });
    _scrollDown();
    await _save('Memoria relazionale persistente aggiornata');
    _maybeAskCuriosity09();"""
new="""    _world.integrateLanguageExperience09(
      _brain,
      text,
      reward: sensoryGrounding != null
          ? 0.9
          : (curiosityAnswer == null ? 0.35 : 0.75),
    );
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage04(user: false, text: answer, prompt: text));
      _status = 'Risposta emersa • consolidamento entropico MGD…';
    });
    _scrollDown();
    await Future<void>.delayed(Duration.zero);
    _world.think(_brain, cycles: 24, seedText: text, stopFlux: 0.006);
    _brain.discoverConcepts();
    if (!mounted) return;
    setState(() {
      _busy = false;
      final bs = _brain.stats();
      _status = 'Esperienza chiusa • Δτ ${bs.lastFlux.toStringAsFixed(3)} • '
          'gen ${(_language20.lastGenerateMicros21/1000).toStringAsFixed(1)} ms • '
          '${_language20.lastVisitedEdges21} archi locali • ${_language20.lastStopReason21}';
    });
    _maybeAskCuriosity09();
    unawaited(Future<void>.delayed(const Duration(milliseconds: 80),
      ()=>_save('Memoria relazionale persistente aggiornata')));"""
assert old in s
s=s.replace(old,new,1)
s=s.replace("title: 'MGD Neuro 0.20',","title: 'MGD Neuro 0.21',",1)
p.write_text(s)

p=root/'pubspec.yaml'
s=p.read_text()
s=s.replace('version: 0.20.5+32','version: 0.21.0+33')
p.write_text(s)
