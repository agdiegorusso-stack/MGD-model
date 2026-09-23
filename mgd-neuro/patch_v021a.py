from pathlib import Path
import sys
root=Path(sys.argv[1])

p=root/'lib'/'mgd_language_v020.dart'
s=p.read_text()

anchor="""  String? generate(String context,{String? semanticHint,PlasticLanguageBrain04? brain,int maxWords=42}){
    _ensureIndexes21();
    final clock=Stopwatch()..start();
    lastVisitedEdges21=0;lastPeakFrontier21=0;lastStopReason21='';
    final seed=[...toks(context),...toks(semanticHint??'')];
    if(edges.length<8)return null;
    final wanted=seed.where((x)=>!punct(x)).toSet();
    final starts=_next('<bos>')..removeWhere((e)=>e.b=='<eos>');
    if(starts.isEmpty)return null;"""

replacement="""  String? generate(String context,{String? semanticHint,PlasticLanguageBrain04? brain,int maxWords=42}){
    _ensureIndexes21();
    final clock=Stopwatch()..start();
    lastVisitedEdges21=0;lastPeakFrontier21=0;lastStopReason21='';

    final contextTokens=toks(context).where((x)=>!punct(x)).toList();
    final hintText=(semanticHint??'').trim();
    final hintIsUncertain=hintText.startsWith('Non ho ancora una rappresentazione abbastanza stabile');
    final hintTokens=hintIsUncertain?const <String>[]:toks(hintText);

    // Meaning must constrain surface form. If the semantic MGD brain already
    // has a trusted answer, preserve that attractor instead of allowing the
    // language graph to wander into an unrelated high-frequency sentence.
    if(hintTokens.isNotEmpty){
      clock.stop();
      lastGenerateMicros21=clock.elapsedMicroseconds;
      lastStopReason21='attrattore semantico';
      final surfaced=_surface(hintTokens.take(maxWords).toList(),brain);
      return surfaced.trim().isEmpty?null:surfaced;
    }

    // A short utterance that has already been observed as a complete linguistic
    // unit may close on itself. This is structural, not a hard-coded greeting:
    // after MGD has seen a standalone token such as "ciao", its BOS/EOS
    // geometry can support a reciprocal short turn.
    if(contextTokens.isNotEmpty && contextTokens.length<=2){
      var closed=true;
      var previous='<bos>';
      for(final t in contextTokens){
        final e=edges[_ek(previous,t)];
        if(e==null){closed=false;break;}
        previous=t;
      }
      if(closed){
        final outs=_next(previous);
        closed=outs.any((e)=>e.b=='<eos>' || punct(e.b));
      }
      if(closed){
        clock.stop();
        lastGenerateMicros21=clock.elapsedMicroseconds;
        lastVisitedEdges21=contextTokens.length+1;
        lastPeakFrontier21=1;
        lastStopReason21='utteranza breve stabilizzata';
        return _surface(contextTokens,brain);
      }
    }

    // No semantic target and no learned closed short-turn attractor: abstain.
    // Starting from the global <bos> distribution here was the source of
    // fluent-looking but semantically unrelated replies.
    if(contextTokens.isEmpty || hintTokens.isEmpty){
      clock.stop();
      lastGenerateMicros21=clock.elapsedMicroseconds;
      lastStopReason21='nessun attrattore di risposta';
      return null;
    }

    final seed=[...contextTokens,...hintTokens];
    if(edges.length<8)return null;
    final wanted=seed.where((x)=>!punct(x)).toSet();
    final starts=_next('<bos>')..removeWhere((e)=>e.b=='<eos>');
    if(starts.isEmpty)return null;"""

if anchor not in s: raise SystemExit('generate anchor missing')
s=s.replace(anchor,replacement,1)
p.write_text(s)

p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()
old="""    answer ??= _generateFromState(prompt);
    if (answer.trim().isEmpty) {
      answer = 'Non ho ancora una rappresentazione abbastanza stabile per rispondere. Insegnamelo o correggimi.';
    }"""
new="""    // Free continuation from token statistics is not a semantic answer.
    // Use it only when the interpretation itself is already well constrained;
    // otherwise abstain and let the dedicated language/dialogue layer decide.
    if (answer == null && interpretation.confidence >= 0.72) {
      answer = _generateFromState(prompt);
    }
    if (answer == null || answer.trim().isEmpty) {
      answer = 'Non ho ancora una rappresentazione abbastanza stabile per rispondere. Insegnamelo o correggimi.';
    }"""
if old not in s: raise SystemExit('brain fallback anchor missing')
s=s.replace(old,new,1)
p.write_text(s)

p=root/'lib'/'main.dart'
s=p.read_text()
s=s.replace("title: const Text('MGD Neuro 0.20'),","title: const Text('MGD Neuro 0.21'),",1)
p.write_text(s)

p=root/'pubspec.yaml'
s=p.read_text()
s=s.replace('version: 0.21.0+33','version: 0.21.1+34')
p.write_text(s)
