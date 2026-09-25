import 'dart:convert';
import 'dart:math';
import 'learned_reader_model_v0324.dart';

/// Supervised token-role model. Weights are trained, not a claim that MGD
/// mathematically implies grammar. Coverage: four relation families, Italian.
class Frame324 {
  final String agent, relation, patient, text;
  final bool negative, question;
  final double margin;
  final bool resolvedPronoun;
  const Frame324(this.agent, this.relation, this.patient, this.text,
      {this.negative = false, this.question = false, this.margin = 0,
       this.resolvedPronoun = false});
  String get signature => '$agent|$relation|$patient|$negative';
  bool get complete => agent != '*' && patient != '*';
  Map<String, dynamic> toJson() => {
    'agent':agent,'relation':relation,'patient':patient,'text':text,
    'negative':negative,'margin':margin,'resolvedPronoun':resolvedPronoun,
  };
}

class LearnedReader324 {
  static final Map<String,dynamic> model =
      jsonDecode(learnedReaderModel324) as Map<String,dynamic>;
  static final labels = List<String>.from(model['labels'] as List);
  static final lexicon = Set<String>.from(model['lexicon'] as List);
  static final predicates = Map<String,String>.from(model['predicateTokens'] as Map);
  static final weights = (model['weights'] as Map).map((k,v) =>
      MapEntry(k.toString(), (v as List).map((x)=>(x as num).toDouble()).toList()));
  static List<String> tokens(String text) => RegExp(r'[a-zàèéìòù0-9]+')
      .allMatches(text.toLowerCase()).map((m)=>m[0]!).toList();
  static const blocked = {
    'se','quando','qualora','forse','potrebbe','potrebbero','dovrebbe',
    'dovrebbero','sembra','sembrerebbe','nessuno','nessuna','mai','senza',
    'ogni','tutti','tutte','qualcuno','qualcuna','solo','soltanto','anche',
    'oppure','perché','perche','mentre','quindi','dice','afferma',
    'sostiene','pensa','crede','secondo','prima','dopo','domani','ieri',
    'e','o','ma','né','ne','che','cui','avrebbe','sarebbe',
  };
  static List<String> features(List<String> ts,int i) {
    final a=ts.map((t)=>lexicon.contains(t)?t:'@').toList();
    String at(int j)=>j<0||j>=a.length?'#':a[j];
    final f=<String>['bias'];
    for(var d=-3;d<=3;d++) { f.add('w$d=${at(i+d)}'); }
    f.add('pair=${at(i-1)}|${at(i)}|${at(i+1)}');
    f.add('start=${min(i,3)}'); f.add('end=${min(ts.length-1-i,3)}');
    final ps=<int>[];
    for(var j=0;j<ts.length;j++) { if(predicates.containsKey(ts[j])) ps.add(j); }
    final side=(i-(ps.isEmpty?i:ps.first)).sign;
    if(ps.isNotEmpty) {
      final d=i-ps.first;
      f.add('predSide=${d.sign}'); f.add('predDistance=${d.clamp(-4,4)}');
      final before=ts.take(ps.first).where(lexicon.contains).join('|');
      f.add('beforePred=$before|side=$side');
    }
    for(final t in a.where((t)=>t!='@').toSet()) { f.add('global=$t|side=$side'); }
    return f;
  }
  static bool handles(String text)=>tokens(text).any(predicates.containsKey);
  static bool isQuestion(String text) {
    final ts=tokens(text);
    return text.trim().endsWith('?') || ts.contains('chi') ||
      (ts.isNotEmpty && const {'cosa','come','dove','quando','quale','quali',
        'perché','perche','che','dimmi','spiega','spiegami'}.contains(ts.first));
  }
  static List<({String token,String label,double margin})> tag(String text) {
    final ts=tokens(text);
    return List.generate(ts.length,(i) {
      final s=List<double>.filled(labels.length,0);
      for(final f in features(ts,i)) {
        final w=weights[f]; if(w==null) continue;
        for(var k=0;k<s.length;k++) { s[k]+=w[k]; }
      }
      final order=List.generate(s.length,(j)=>j)..sort((a,b)=>s[b].compareTo(s[a]));
      return (token:ts[i],label:labels[order[0]],margin:s[order[0]]-s[order[1]]);
    });
  }
  static Frame324? parse(String text,{String? antecedent}) {
    final ts=tokens(text);
    if(ts.length<3||ts.length>24||ts.any(blocked.contains)) return null;
    // These question forms are recognized as questions but are outside this
    // first reader's trained query vocabulary. Never turn them into assertions.
    if(const {'cosa','come','dove','quando','quale','quali','perché','perche',
      'dimmi','spiega','spiegami'}.contains(ts.first)) return null;
    if(ts.where(predicates.containsKey).length!=1) return null;
    if(ts.where((t)=>t=='non').length>1) return null;
    if(RegExp(r'[,;:"“”]').hasMatch(text)) return null;
    final tagged=tag(text);
    final p=tagged.where((t)=>t.label.startsWith('P:')).toList();
    if(p.length!=1 || !predicates.containsKey(p.single.token) ||
       p.single.label!='P:${predicates[p.single.token]}') return null;
    var margin=double.infinity;
    String? span(String role) {
      final ids=<int>[];
      for(var i=0;i<tagged.length;i++) {
        if(tagged[i].label==role) { ids.add(i); margin=min(margin,tagged[i].margin); }
      }
      if(ids.isEmpty||ids.length>5) return null;
      if(ids.last-ids.first+1!=ids.length) return null;
      return ids.map((i)=>ts[i]).join(' ');
    }
    var a=span('A'),o=span('O');
    if(a==null||o==null||margin<1.0) return null;
    var resolved=false;
    const pronouns={'lo','la','lui','lei'};
    if(pronouns.contains(a)||pronouns.contains(o)) {
      if(antecedent==null || (pronouns.contains(a)&&pronouns.contains(o))) return null;
      if(pronouns.contains(a)) {a=antecedent;} else {o=antecedent;}
      resolved=true;
    }
    if(a=='chi') a='*';
    if(o=='chi') o='*';
    if((a=='*'&&o=='*') || a==o) return null;
    final question=isQuestion(text);
    if(!question&&(a=='*'||o=='*')) return null;
    return Frame324(a,p.single.label.substring(2),o,text,
      negative:ts.contains('non'),question:question,margin:margin,
      resolvedPronoun:resolved);
  }

  /// Deliberately narrow discourse resolver: one explicit entity in the
  /// immediately preceding simple introduction, never "last entity wins".
  static String? singleAntecedent(String text) {
    final ts=tokens(text);
    if(ts.length<2||ts.length>7||ts.any(blocked.contains)||isQuestion(text)) return null;
    if(!{'corre','dorme','arriva','cammina'}.contains(ts.last)) return null;
    final name=ts.take(ts.length-1).where((t)=>!{'il','la','lo','un','una'}.contains(t)).toList();
    if(name.isEmpty||name.any(lexicon.contains)) return null;
    return name.join(' ');
  }
}
