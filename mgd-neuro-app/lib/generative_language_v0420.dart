// MGD Generative Language 0.42.0
// Conservative variable-order decoder built only from language transitions and
// 2-5 token chunks learned by MGD. It uses a semantic plan as a constraint and
// falls back when it cannot preserve enough content.
import 'dart:math';

import 'mgd_language_v020.dart';

class _GenEdge420 {
  final String next;
  final double score;
  const _GenEdge420(this.next,this.score);
}

class GenerativeLanguage420 {
  final MgdLanguage20 language;
  final Map<String,List<_GenEdge420>> outgoing={};
  final Map<String,Map<String,double>> continuations={};
  final Map<String,int> tokenCount={};

  static const stop=<String>{
    'il','lo','la','i','gli','le','un','uno','una','di','del','della','dei','degli','delle',
    'a','al','alla','allo','ai','agli','alle','da','dal','dalla','dallo','dai','dagli','dalle',
    'in','nel','nella','nello','nei','nelle','su','sul','sulla','sullo','con','per','tra','fra',
    'e','ed','o','oppure','ma','però','pero','che','cui','non','si','è','era','sono','erano',
    'io','tu','lui','lei','noi','voi','loro','questo','questa','quello','quella','questi','queste'
  };

  GenerativeLanguage420(this.language) {
    final j=language.toJson();
    tokenCount.addAll(Map<String,int>.from((j['tc'] as Map? ?? {}).map(
      (k,v)=>MapEntry('$k',(v as num).toInt()))));
    for(final raw in (j['e'] as List? ?? const [])) {
      final e=Map<String,dynamic>.from(raw as Map);
      final a='${e['a']}', b='${e['b']}';
      final uses=(e['u'] as num? ?? 0).toDouble();
      final slow=(e['s'] as num? ?? 0).toDouble();
      final material=(e['m'] as num? ?? 0).toDouble();
      final cost=(e['c'] as num? ?? 1.1).toDouble();
      final score=(1.65-cost)+.50*slow+.22*material+.035*log(1+uses);
      outgoing.putIfAbsent(a,()=>[]).add(_GenEdge420(b,score));
    }
    for(final xs in outgoing.values) {
      xs.sort((a,b)=>b.score.compareTo(a.score));
    }
    for(final raw in (j['ch'] as List? ?? const [])) {
      final c=Map<String,dynamic>.from(raw as Map);
      final text='${c['t']}', count=(c['c'] as num? ?? 0).toInt();
      final material=(c['m'] as num? ?? 0).toDouble();
      if(count<3)continue;
      final ts=text.split(' ').where((x)=>x.isNotEmpty).toList();
      if(ts.length<2)continue;
      for(var width=1;width<=min(4,ts.length-1);width++) {
        final prefix=ts.sublist(ts.length-1-width,ts.length-1).join('\u0002');
        final row=continuations.putIfAbsent(prefix,()=>{});
        final score=log(1+count)+.50*material+.14*width;
        row[ts.last]=max(row[ts.last]??double.negativeInfinity,score);
      }
    }
  }

  Map<String,double> _candidates(List<String> generated,Set<String> wanted) {
    if(generated.isEmpty) {
      return {for(final e in outgoing['<bos>']??const <_GenEdge420>[]) e.next:e.score};
    }
    for(var width=min(4,generated.length);width>=1;width--) {
      final key=generated.sublist(generated.length-width).join('\u0002');
      final row=continuations[key];
      if(row!=null&&row.isNotEmpty)return Map<String,double>.from(row);
    }
    return {for(final e in outgoing[generated.last]??const <_GenEdge420>[]) e.next:e.score};
  }

  static bool _content(String x)=>!MgdLanguage20.punct(x)&&!stop.contains(x)&&x.length>1;

  String? _clause(String clause,String context,{int maxWords=32}) {
    if(outgoing.length<50||tokenCount.length<30)return null;
    final wantedOrdered=<String>[];
    for(final t in MgdLanguage20.toks(clause).where(_content)) {
      if(tokenCount.containsKey(t)&&!wantedOrdered.contains(t))wantedOrdered.add(t);
      if(wantedOrdered.length>=10)break;
    }
    if(wantedOrdered.isEmpty)return null;
    final wanted=wantedOrdered.toSet();
    final contextual=MgdLanguage20.toks(context)
        .where(_content).where(tokenCount.containsKey).take(8).toSet();

    var active=<({List<String> xs,double score,Map<String,int> used,Set<String> covered})>[
      (xs:<String>[],score:0.0,used:<String,int>{},covered:<String>{})
    ];
    final finished=<({List<String> xs,double score,Set<String> covered})>[];

    for(var step=0;step<maxWords;step++) {
      final next=<({List<String> xs,double score,Map<String,int> used,Set<String> covered})>[];
      for(final b in active) {
        final candidates=_candidates(b.xs,wanted).entries.toList()
          ..sort((a,b)=>b.value.compareTo(a.value));
        for(final e in candidates.take(22)) {
          final tok=e.key;
          if(tok=='<bos>')continue;
          if(tok=='<eos>') {
            if(b.xs.length>=3) {
              final cov=b.covered.length/max(1,wanted.length);
              finished.add((xs:b.xs,score:b.score+1.4*cov,covered:b.covered));
            }
            continue;
          }
          final rep=b.used[tok]??0;
          if(rep>=2&&!MgdLanguage20.punct(tok))continue;
          final used=Map<String,int>.from(b.used)..[tok]=rep+1;
          final covered=Set<String>.from(b.covered);
          if(wanted.contains(tok))covered.add(tok);
          var score=b.score+e.value;
          if(wanted.contains(tok))score+=1.10;
          if(contextual.contains(tok))score+=.22;
          score-=.52*rep;
          if(MgdLanguage20.punct(tok)&&b.xs.length<3)score-=1.2;
          score-=.012*b.xs.length;
          next.add((xs:[...b.xs,tok],score:score,used:used,covered:covered));
        }
      }
      if(next.isEmpty)break;
      next.sort((a,b){
        final sa=a.score/(1+.028*a.xs.length), sb=b.score/(1+.028*b.xs.length);
        return sb.compareTo(sa);
      });
      active=next.take(32).toList();
    }

    if(finished.isEmpty) {
      for(final b in active.take(10)) {
        if(b.xs.length<4)continue;
        final cov=b.covered.length/max(1,wanted.length);
        finished.add((xs:b.xs,score:b.score+cov,covered:b.covered));
      }
    }
    if(finished.isEmpty)return null;
    finished.sort((a,b){
      final ca=a.covered.length/max(1,wanted.length);
      final cb=b.covered.length/max(1,wanted.length);
      final sa=a.score/(1+.022*a.xs.length)+1.6*ca;
      final sb=b.score/(1+.022*b.xs.length)+1.6*cb;
      return sb.compareTo(sa);
    });
    final best=finished.first;
    final coverage=best.covered.length/max(1,wanted.length);
    final required=wanted.length<=2?1.0:.58;
    if(coverage<required)return null;
    final lexical=best.xs.where(_content).toSet();
    final anchorCoverage=wanted.intersection(lexical).length/max(1,wanted.length);
    if(anchorCoverage<required)return null;
    var out=_surface(best.xs);
    if(out.split(' ').length<3)return null;
    if(!RegExp(r'[.!?]$').hasMatch(out))out+='.';
    return out;
  }

  String? realize(String context,String semanticPlan,{int maxWords=72}) {
    final plan=semanticPlan.trim();
    if(plan.isEmpty)return null;
    final clauses=plan.split(RegExp(r'(?<=[.!?])\s+'))
        .where((x)=>x.trim().isNotEmpty).take(4).toList();
    if(clauses.isEmpty)return null;
    final per=max(12,maxWords~/clauses.length);
    final out=<String>[];
    var generated=0;
    for(final c in clauses) {
      final g=_clause(c,context,maxWords:per);
      if(g==null)out.add(c.trim()); else {out.add(g);generated++;}
    }
    if(generated==0)return null;
    return out.join(' ');
  }

  static String _surface(List<String> xs) {
    final b=StringBuffer();
    const noSpace={'.',',','!','?',';',':'};
    for(final x in xs) {
      if(b.isNotEmpty&&!noSpace.contains(x))b.write(' ');
      b.write(x);
    }
    var s=b.toString().trim();
    if(s.isEmpty)return s;
    s=s[0].toUpperCase()+s.substring(1);
    return s;
  }
}
