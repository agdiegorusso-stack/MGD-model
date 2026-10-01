/// Sparse modern Hopfield retrieval and language statistics, without pretrained
/// weights. Inspired by CLS; not a reconstruction of biological neural tissue.
library;

import 'dart:math';

typedef Cue340 = Map<String, Map<String, double>>;
String norm340(String s) => s.trim().toLowerCase().replaceAll('’', "'")
    .replaceAll(RegExp(r'\s+'), ' ');

class Pattern340 {
  final int id;
  final String label, context, text, source;
  final Cue340 cue;
  const Pattern340(this.id, this.label, this.context, this.cue,
      {this.text = '', this.source = ''});
}

class Recall340 {
  final List<Pattern340> evidence;
  final List<double> weights, energy;
  final Map<String, double> labels;
  final double similarity;
  final bool accepted, conflict;
  final int micros;
  const Recall340(this.evidence, this.weights, this.energy, this.labels,
      this.similarity, this.accepted, this.conflict, this.micros);
  String? get best => labels.isEmpty ? null :
      (labels.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))).first.key;
}

class Hopfield340 {
  static Cue340 normalize(Cue340 input) {
    if (input.isEmpty || input.length > 3) {
      throw ArgumentError('Serve almeno un canale sensoriale, al massimo tre.');
    }
    final out = <String, Map<String, double>>{};
    for (final channel in input.entries) {
      if (!{'text:v1','vision:v1','audio:v1'}.contains(channel.key) ||
          channel.value.isEmpty || channel.value.length > 512) {
        throw ArgumentError('Canale o dimensione non validi: ${channel.key}');
      }
      double n = 0;
      for (final e in channel.value.entries) {
        if (e.key.isEmpty || e.key.length > 160 || !e.value.isFinite ||
            e.value.abs() > 1e6) throw ArgumentError('Coordinata non valida.');
        n += e.value * e.value;
      }
      if (n <= 1e-20) throw ArgumentError('Stimolo senza segnale.');
      final scale = sqrt(n);
      out[channel.key] = Map.unmodifiable({for (final e in channel.value.entries)
        if (e.value != 0) e.key: e.value / scale});
    }
    return Map.unmodifiable(out);
  }

  static Map<String,double> flatten(Cue340 cue, Iterable<String> channels) {
    final keys = channels.toList();
    final scale = sqrt(keys.length);
    return {for (final c in keys) for (final e in cue[c]!.entries)
      '$c\u0000${e.key}': e.value / scale};
  }

  static double dot(Map<String,double> a, Map<String,double> b) {
    if (a.length > b.length) return dot(b,a);
    var s = 0.0;
    for (final e in a.entries) { s += e.value * (b[e.key] ?? 0); }
    return s;
  }

  static List<double> softmax(List<double> values) {
    if (values.isEmpty) return [];
    if (values.any((x)=>!x.isFinite)) throw ArgumentError('Logit non finito.');
    final peak = values.reduce(max);
    final mass = values.map((x)=>exp(x-peak)).toList();
    final sum = mass.fold(0.0,(a,b)=>a+b);
    return mass.map((x)=>x/sum).toList();
  }

  /// E(q)=||q||²/2-logsumexp(beta X'q)/beta, up to constants.
  /// Keys remain fixed within retrieval; the updated state is NOT renormalized.
  static double energyOf(Map<String,double> q,
      List<Map<String,double>> keys, double beta) {
    final logits = keys.map((k)=>beta*dot(k,q)).toList();
    final peak = logits.reduce(max);
    final lse = peak + log(logits.fold(0.0,(a,b)=>a+exp(b-peak)));
    return .5*dot(q,q)-lse/beta;
  }

  static Recall340 recall(Cue340 input, Iterable<Pattern340> records,
      {String context='generale', double beta=12, int iterations=3}) {
    if (!beta.isFinite || beta <= 0 || iterations < 1 || iterations > 32) {
      throw ArgumentError('Parametri Hopfield non validi.');
    }
    final watch = Stopwatch()..start();
    final cue = normalize(input), c = norm340(context);
    final pool = records.where((e)=>norm340(e.context)==c &&
        cue.keys.every(e.cue.containsKey)).toList();
    if (pool.isEmpty) return Recall340([],[],[],{},0,false,false,
        watch.elapsedMicroseconds);
    final q0 = flatten(cue,cue.keys);
    final keys = pool.map((e)=>flatten(normalize(e.cue),cue.keys)).toList();
    var q = Map<String,double>.of(q0);
    final energies = <double>[energyOf(q,keys,beta)];
    var mass = <double>[];
    for (var step=0;step<iterations;step++) {
      mass = softmax(keys.map((k)=>beta*dot(k,q)).toList());
      final next = <String,double>{};
      for (var i=0;i<keys.length;i++) {
        for (final e in keys[i].entries) {
          next[e.key]=(next[e.key]??0)+mass[i]*e.value;
        }
      }
      final nextEnergy = energyOf(next,keys,beta);
      // Defensive numerical check; no claim for changing candidate sets.
      if (nextEnergy > energies.last + 1e-9) break;
      energies.add(nextEnergy);
      final delta = dot(q,q)+dot(next,next)-2*dot(q,next);
      q=next;
      if (delta.abs()<1e-12) break;
    }
    mass=softmax(keys.map((k)=>beta*dot(k,q)).toList());
    final original = keys.map((k)=>dot(k,q0)).toList();
    final nearest = original.reduce(max);
    final exact = <String>{};
    for(var i=0;i<pool.length;i++) {
      if(original[i]>1-1e-9) exact.add(norm340(pool[i].label));
    }
    final labels = <String,double>{}, counts=<String,int>{};
    for(var i=0;i<pool.length;i++) {
      final label=norm340(pool[i].label);
      labels[label]=(labels[label]??0)+mass[i];
      counts[label]=(counts[label]??0)+1;
    }
    // Class-balanced reporting avoids equating duplicate exemplars with truth.
    for(final label in labels.keys.toList()) {
      labels[label]=labels[label]!/counts[label]!;
    }
    final total=labels.values.fold(0.0,(a,b)=>a+b);
    for(final label in labels.keys.toList()) { labels[label]=labels[label]!/total; }
    final rank=labels.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    final conflict=exact.length>1;
    final accepted=!conflict && (exact.length==1 || (nearest>=.82 &&
        rank.first.value>=.72 &&
        (rank.length==1 || rank.first.value-rank[1].value>=.20)));
    // Exact observations take precedence over a basin reached from a noisy cue.
    if(exact.length==1) {
      labels.clear(); labels[exact.single]=1;
    }
    final order=List.generate(pool.length,(i)=>i)
      ..sort((a,b)=>original[b].compareTo(original[a]));
    return Recall340(order.map((i)=>pool[i]).toList(),
        order.map((i)=>mass[i]).toList(),energies,labels,nearest,
        accepted,conflict,watch.elapsedMicroseconds);
  }
}

class Italian340 {
  static final _tokens=RegExp(r"[a-zà-öø-ÿ]+(?:'[a-zà-öø-ÿ]+)?|[0-9]+|[.,!?;:]");
  static List<String> tokens(String text)=>_tokens.allMatches(norm340(text))
      .map((m)=>m.group(0)!).toList();

  /// Lexical, not semantic, features. Labels are never inserted into the cue.
  static Map<String,double> features(String text) {
    final words=tokens(text).where((w)=>!RegExp(r'^[.,!?;:]$').hasMatch(w)).toList();
    final out=<String,double>{};
    for(var i=0;i<words.length;i++) {
      final w='w:${words[i]}'; out[w]=(out[w]??0)+1;
      if(i>0) { final b='b:${words[i-1]} ${words[i]}'; out[b]=(out[b]??0)+.7; }
    }
    final ranked=out.entries.where((e)=>e.key.length<=160).toList()
      ..sort((a,b) { final n=b.value.compareTo(a.value); return n!=0?n:a.key.compareTo(b.key); });
    return Map.fromEntries(ranked.take(512));
  }

  /// Per-observation sufficient statistics. The store keeps contributions so
  /// deletion subtracts them; replay of a source is not counted as new evidence.
  static Map<String,int> transitions(String text,{int order=3}) {
    if(order<0 || order>5) throw ArgumentError('Ordine non valido.');
    final result=<String,int>{};
    var history=<String>['<s>'];
    for(final t in [...tokens(text),'<e>']) {
      for(var n=0;n<=min(order,history.length);n++) {
        final suffix=history.sublist(history.length-n).join(' ');
        final key='$suffix\u0000$t';
        result[key]=(result[key]??0)+1;
      }
      history.add(t);
      if(history.length>order) history=history.sublist(history.length-order);
      if(t=='.'||t=='!'||t=='?') history=['<s>'];
    }
    return result;
  }

  static Iterable<String> chunks(String text,{int words=120}) sync* {
    if(words<1) throw ArgumentError('Dimensione non valida.');
    final parts=RegExp(r'\S+\s*').allMatches(text);
    var buffer=StringBuffer(),count=0;
    for(final p in parts) {
      buffer.write(p.group(0)); count++;
      if(count>=words || buffer.length>=5000) {
        yield buffer.toString().trim(); buffer=StringBuffer();count=0;
      }
    }
    if(buffer.isNotEmpty) yield buffer.toString().trim();
  }
}

class StudyPriority340 {
  /// A transparent scheduling score, not consciousness or a personal desire.
  static double score({required double novelty,required double uncertainty,
      required double contradiction,required double userInterest,
      required double estimatedCost}) {
    final xs=[novelty,uncertainty,contradiction,userInterest,estimatedCost];
    if(xs.any((x)=>!x.isFinite||x<0)) throw ArgumentError('Priorità non valida.');
    return (novelty+uncertainty+2*contradiction+2*userInterest)/(1+estimatedCost);
  }
}
