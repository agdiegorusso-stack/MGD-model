import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'semantic_plasticity_v0445.dart';

/// Learned recurrent roles and question interpretation. No pretrained model,
/// transformer, fixed entity table, or cloud inference. Answers are extractive.
/// Scope, reference resolution and truth are separate from syntactic roles.
class OwnReader443 {
  final Map<String, dynamic> model;
  final Map<String, List<List<double>>> matrices = {};
  final Map<String, List<double>> vectors = {};
  final List<double> corefWeights;
  SemanticPlasticity445? plasticity;
  static Future<OwnReader443>? _loading;
  static final tokenPattern = RegExp(r"[\wÀ-ÿ]+(?:['’][\wÀ-ÿ]+)?|[^\w\s]", unicode: true);
  OwnReader443(this.model, this.corefWeights) {
    for (final e in (model['parameters'] as Map).entries) {
      final raw = e.value as List;
      if (raw.first is List) {
        matrices['${e.key}'] = raw.map((r) => (r as List).map((x) => (x as num).toDouble()).toList()).toList();
      } else {
        vectors['${e.key}'] = raw.map((x) => (x as num).toDouble()).toList();
      }
    }
    if (model['question_bag'] is Map) {
      final b=model['question_bag'] as Map;
      matrices['question_bag.weight']=(b['weight'] as List).map((r) => (r as List).map((v) => (v as num).toDouble()).toList()).toList();
      vectors['question_bag.bias']=(b['bias'] as List).map((v) => (v as num).toDouble()).toList();
    }
  }
  static Future<OwnReader443> load() => _loading ??= _load();
  static Future<OwnReader443> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/reader443.json');
      if (sha256.convert(utf8.encode(raw)).toString()!=SemanticPlasticity445.baseModelId) {
        throw const FormatException('Aggiornare la revisione della plasticità per questi pesi di base.');
      }
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final c = jsonDecode(await rootBundle.loadString('assets/coreference443.json')) as Map;
      return OwnReader443(m, (c['weights'] as List).map((x) => (x as num).toDouble()).toList());
    } catch (_) { _loading = null; rethrow; }
  }
  static List<String> tokenize(String text) => tokenPattern.allMatches(text).map((m) => m.group(0)!).toList();
  static int hash(String s) {
    var h = 2166136261;
    for (final c in s.runes) { h = ((h ^ c) * 16777619) & 0xffffffff; }
    return h;
  }
  static List<int> features(String word, int buckets) {
    final s = '^${word.toLowerCase()}\$';
    final grams = <String>[s];
    for (final n in [2,3,4]) { for (var i = 0; i + n <= s.length; i++) { grams.add(s.substring(i,i+n)); } }
    return grams.take(40).map((g) => hash(g) % buckets).toList();
  }
  static Map<int,double> questionFeatures(String text,int buckets) {
    final words=tokenize(text).map((w) => w.toLowerCase()).toList(), counts=<int,double>{};
    void add(String s,double value) { final k=hash(s)%buckets; counts[k]=(counts[k]??0)+value; }
    for (final n in [1,2,3]) { for (var i=0;i+n<=words.length;i++) { add('w$n:${words.sublist(i,i+n).join(' ')}',1); } }
    for (final w in words) {
      final t='^$w\$';
      for (final n in [3,4]) { for (var i=0;i+n<=t.length;i++) { add('c:${t.substring(i,i+n)}',.18); } }
    }
    final norm=math.sqrt(counts.values.fold(0.0,(a,b) => a+b*b));
    return {for (final e in counts.entries) e.key:e.value/(norm==0?1:norm)};
  }
  static List<double> softmax(List<double> a) {
    final highest = a.reduce(math.max);
    final e = a.map((x) => math.exp(x - highest)).toList();
    final sum = e.fold(0.0, (a,b) => a+b);
    return e.map((x) => x/sum).toList();
  }
  static double dot(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) { sum += a[i] * b[i]; }
    return sum;
  }
  List<double> linear(String name, List<double> x) {
    final w = matrices['$name.weight']!, b = vectors['$name.bias']!;
    return List.generate(b.length,(i) => dot(w[i],x)+b[i]);
  }
  static int argmax(List<double> x) {
    var best = 0;
    for (var i = 1; i < x.length; i++) { if (x[i] > x[best]) best = i; }
    return best;
  }
  List<double> baseVector(String word) {
    final embedding = matrices['embedding.weight']!, d = model['embedding'] as int;
    final ids = features(word, model['buckets'] as int), f = List<double>.filled(d,0);
    for (final id in ids) { for (var j=0; j<d; j++) { f[j] += embedding[id][j]/ids.length; } }
    return f;
  }
  OwnReader443 withSemanticState(Map? state) {
    final reader = OwnReader443(model,corefWeights);
    reader.plasticity = SemanticPlasticity445.restore(state,model['embedding'] as int);
    return reader;
  }
  Map<String,dynamic> learnFromSources(List<Map<String,dynamic>> rows) {
    final p = plasticity ??= SemanticPlasticity445(model['embedding'] as int);
    p.learn(rows,baseVector,tokenize);
    return p.toJson();
  }
  Map<String, dynamic> inspect(String text) {
    final words = tokenize(text);
    if (words.isEmpty) return {'text':text,'tokens':words,'spans':<Map<String,dynamic>>[], 'scope':'asserted','scopeConfidence':0.0,'questionType':'summary','questionConfidence':0.0,'scopeDistribution':<double>[.25,.25,.25,.25]};
    final d = model['embedding'] as int;
    final x = <List<double>>[];
    for (final word in words) {
      final f = plasticity?.vector(word,baseVector) ?? baseVector(word);
      final upper = RegExp(r'[A-ZÀ-ÖØ-Þ]').hasMatch(word.substring(0,1));
      final alpha = RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(word);
      final extra=<double>[upper ? 1 : 0, upper && word.length > 1 && word.toUpperCase()==word ? 1 : 0,
        RegExp(r'\d').hasMatch(word) ? 1 : 0, alpha ? 0 : 1];
      if (matrices.containsKey('entity.weight')) {
        final z=linear('entity',[...f,...extra])[0], entity=1/(1+math.exp(-z.clamp(-40.0,40.0)));
        final id=vectors['entity_embedding']!;
        for (var j=0;j<d;j++) { f[j]=f[j]*(1-entity)+id[j]*entity; }
      }
      x.add([...f,...extra]);
    }
    final states = <List<List<double>>>[], finalStates = <List<double>>[];
    for (final reverse in [false,true]) {
      final suffix = reverse ? '_reverse' : '';
      final wi = matrices['rnn.weight_ih_l0$suffix']!, wh = matrices['rnn.weight_hh_l0$suffix']!;
      final bi = vectors['rnn.bias_ih_l0$suffix']!, bh = vectors['rnn.bias_hh_l0$suffix']!;
      var h = List<double>.filled(model['hidden'] as int,0);
      final hs = List<List<double>>.generate(words.length, (_) => []);
      for (var step = 0; step < words.length; step++) {
        final j = reverse ? words.length-1-step : step;
        h = List.generate(h.length,(i) {
          final z = (dot(wi[i],x[j]) + dot(wh[i],h) + bi[i] + bh[i]).clamp(-20.0,20.0);
          final e = math.exp(2*z); return (e-1)/(e+1);
        });
        hs[j] = h;
      }
      states.add(hs); finalStates.add(h);
    }
    final probabilities = [for (var j = 0; j < words.length; j++) softmax(linear('tag',[...states[0][j],...states[1][j]]))];
    final labels = probabilities.map(argmax).toList();
    final spans = <Map<String,dynamic>>[];
    for (var start = 0; start < words.length;) {
      final label = labels[start]; var end = start+1;
      while (end < words.length && labels[end]==label) { end++; }
      if (label != 0) spans.add({'role':model['roles'][label], 'text':words.sublist(start,end).join(' '),
        'confidence':probabilities.sublist(start,end).map((p) => p[label]).reduce(math.min),'tokenStart':start,'tokenEnd':end});
      start = end;
    }
    final pooled = [...finalStates[0],...finalStates[1]];
    final scope = softmax(linear('scope',pooled));
    List<double> q;
    if (model['question_bag'] is Map) {
      final bag=model['question_bag'] as Map;
      final qw=matrices['question_bag.weight']!;
      final logits=List<double>.from(vectors['question_bag.bias']!);
      for (final f in questionFeatures(text,bag['buckets'] as int).entries) { for (var i=0;i<logits.length;i++) { logits[i]+=qw[f.key][i]*f.value; } }
      q=softmax(logits);
    } else { q=softmax(linear('question',pooled)); }
    return {'text':text,'tokens':words,'spans':spans,'scope':model['scopes'][argmax(scope)],
      'scopeConfidence':scope.reduce(math.max),'questionType':model['questions'][argmax(q)],
      'questionConfidence':q.reduce(math.max),'scopeDistribution':scope,
      'semanticRevision':plasticity?.revision ?? 0};
  }
  Map<String,dynamic>? resolve(String reference,List<Map<String,dynamic>> candidates) {
    if (candidates.isEmpty) return null;
    final ref = reference.toLowerCase(), scores = <double>[];
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i], t = '${candidates[i]['text']}';
      final last = t.split(' ').last.toLowerCase();
      final first=t.split(' ').first.toLowerCase();
      final feminine=['la','una'].contains(first) || (!['il','lo','un','uno'].contains(first) && last.endsWith('a'));
      final masculine=['il','lo','un','uno'].contains(first) || (!['la','una'].contains(first) && last.endsWith('o'));
      final personal = ['lei','ella','lui','egli'].contains(ref);
      final upper = t.substring(0,1).toUpperCase()==t.substring(0,1);
      final f = <double>[1,c['role']=='object'?1:0,c['role']=='agent'?1:0,c['role']=='recipient'?1:0,
        1/(1+candidates.length-i),(ref.endsWith('la') || ['lei','ella','la'].contains(ref)) && feminine?1:0,
        (ref.endsWith('lo') || ['lui','egli','lo'].contains(ref)) && masculine?1:0,
        personal && upper?1:0,(['lo','la','li','le'].contains(ref) || ref.length>5) && !upper?1:0];
      scores.add(dot(f,corefWeights));
    }
    final p = softmax(scores), order = List.generate(p.length,(i) => i)..sort((a,b) => p[b].compareTo(p[a]));
    if (order.length>1 && p[order[0]]-p[order[1]]<.30) return null;
    return {...candidates[order[0]],'referenceConfidence':p[order[0]]};
  }
  List<Map<String,dynamic>> events(String text) {
    final candidates = <Map<String,dynamic>>[], result = <Map<String,dynamic>>[];
    for (final sentence in text.trim().split(RegExp(r'(?<=[.!?])\s+'))) {
      if (sentence.trim().isEmpty) continue;
      final e = inspect(sentence), spans = e['spans'] as List<Map<String,dynamic>>;
      e['scopeConflict']=e['scope']=='asserted' && spans.any((s) => s['role']=='negation');
      e['sourceSentences'] = <String>[sentence];
      for (final s in List<Map<String,dynamic>>.from(spans)) {
        if (['reference','predicate_reference'].contains(s['role'])) {
          final c = resolve('${s['text']}',candidates);
          if (c==null) { e['unresolvedReference']=true; }
          else {
            spans.add({...c,'role':'object','resolvedFrom':s['text']});
            final quote = '${c['sourceSentence']}';
            if (!(e['sourceSentences'] as List).contains(quote)) (e['sourceSentences'] as List).add(quote);
          }
        }
      }
      for (final s in spans) { if (['agent','object','recipient'].contains(s['role']) && s['resolvedFrom']==null) candidates.add({...s,'sourceSentence':sentence}); }
      result.add(e);
    }
    return result;
  }
  Map<String,dynamic> answer(String text,String query) {
    if (plasticity != null && tokenize('$text $query').any((w)=>plasticity!.conflicts.contains(w.toLowerCase()))) {
      return {'unknown':true,'answer':'Le fonti conservate danno definizioni incompatibili di un termine. Il significato resta da chiarire.'};
    }
    final q = inspect(query), es = events(text);
    if (es.isEmpty || (q['questionConfidence'] as double)<.55 || q['questionType']=='unsupported') return {'unknown':true,'answer':'Domanda fuori dalle capacità verificate del lettore.'};
    final queryWords = tokenize(query).where((w) => w.length>3).map((w) => w.toLowerCase()).toSet();
    var best = es.last, score = -1.0;
    for (final e in es) {
      final words = (e['tokens'] as List).map((w) => '$w'.toLowerCase()).toSet();
      var current = queryWords.intersection(words).length.toDouble();
      if (model['event_ranker'] is Map) {
        final rank=model['event_ranker'] as Map;
        current=dot(rankFeatures(query,e,'${q['questionType']}',es.indexOf(e),es.length),
          (rank['weight'] as List).map((v) => (v as num).toDouble()).toList());
      }
      if (current>=score) { score=current; best=e; }
    }
    final kind = '${q['questionType']}';
    if (kind=='summary') return {'unknown':false,'answer':text,'sourceSentences':es.map((e) => e['text']).toList(),'extractive':true};
    String answer;
    if (kind=='status') {
      answer = {'asserted':'Il testo presenta l’evento come affermato.','negated':'Il testo nega l’evento.',
        'conditional':'Il testo presenta l’evento sotto una condizione.','planned':'Il testo presenta una promessa o un evento previsto.'}[best['scope']]!;
    } else {
      final spans = (best['spans'] as List<Map<String,dynamic>>).where((s) => s['role']==kind && (s['confidence'] as num)>=.55).toList();
      if (spans.isEmpty) return {'unknown':true,'answer':'Il dato richiesto manca o il lettore non lo riconosce con sufficiente confidenza.'};
      answer = spans.map((s) => '${s['text']}').toSet().join('; ');
    }
    if ((best['scopeConfidence'] as num)<.55 || best['scopeConflict']==true) return {'unknown':true,'answer':'La negazione o la condizione del brano resta incerta.'};
    final scope = '${best['scope']}';
    if (kind!='status' && scope!='asserted') answer += ' (evento ${ {'negated':'negato','conditional':'condizionato','planned':'promesso o previsto'}[scope]})';
    final learnedDefinitions = <Map<String,dynamic>>[];
    if (plasticity != null) {
      final needed = tokenize('$text $query').map((w)=>w.toLowerCase()).toSet();
      final seen = <String>{};
      for (var depth=0; depth<12; depth++) {
        final fresh = needed.difference(seen);
        if (fresh.isEmpty) break;
        seen.addAll(fresh);
        for (final word in fresh) {
          for (final d in plasticity!.definitions[word] ?? <Map<String,dynamic>>[]) {
            learnedDefinitions.add({'word':word,...d}); needed.add('${d['target']}');
          }
        }
      }
    }
    return {'unknown':false,'answer':answer,'scope':scope,'sourceSentences':best['sourceSentences'],'extractive':true,'semanticValidation':false,
      'learnedDefinitions':learnedDefinitions};
  }
  static List<double> rankFeatures(String query,Map event,String kind,int index,int count) {
    final qw=tokenize(query).where((w) => w.length>3).map((w) => w.toLowerCase()).toSet();
    final ew=(event['tokens'] as List).map((w) => '$w'.toLowerCase()).where((w) => w.length>3).toSet();
    Set<String> grams(String word) => {for (var i=0;i<math.max(1,word.length-2);i++) word.substring(i,math.min(i+3,word.length))};
    var matches=0.0;
    for (final q in qw) {
      final g=grams(q);var highest=0.0;
      for (final w in ew) { final wg=grams(w);highest=math.max(highest,2*g.intersection(wg).length/(g.length+wg.length)); }
      matches+=highest;
    }
    var confidence=0.0;
    for (final s in (event['spans'] as List).whereType<Map>()) { if (s['role']==kind) confidence=math.max(confidence,(s['confidence'] as num).toDouble()); }
    return [1,qw.intersection(ew).length/math.max(1,qw.length),matches/math.max(1,qw.length),confidence,index/math.max(1,count-1)];
  }
  Future<String> generate(String prompt) async {
    final marker = prompt.indexOf('DATI:\n');
    if (marker<0) throw const FormatException('Mancano i brani');
    final rows = (jsonDecode(prompt.substring(marker+6)) as List).whereType<Map>().toList();
    final questionStart = prompt.indexOf('DOMANDA: ');
    if (questionStart<0) {
      final notes = <Map<String,dynamic>>[];
      for (final r in rows) { for (final e in events('${r['text']}')) {
        notes.add({'text':e['text'],'evidence':[r['id']],'roles':e['spans'],'scope':e['scope'],'extractive':true});
      } }
      return jsonEncode({'notes':notes});
    }
    final question = prompt.substring(questionStart+9,marker).trim();
    final grouped = <String,List<Map>>{};
    for (final r in rows) { grouped.putIfAbsent('${r['url'] ?? r['title']}',() => []).add(r); }
    Map<String,dynamic>? selected;var highest=-1;
    final qw=tokenize(question).where((w) => w.length>3).map((w) => w.toLowerCase()).toSet();
    for (final group in grouped.values) {
      final text=group.map((r) => '${r['text']}').join(' '), a=answer(text,question);
      if (a['unknown']==true) continue;
      final overlap=qw.intersection(tokenize(text).map((w) => w.toLowerCase()).toSet()).length;
      if (overlap>highest) { highest=overlap; selected={...a,'evidence':[for (final r in group) r['id']]}; }
    }
    return jsonEncode(selected ?? {'unknown':true,'answer':'Non riesco a ricavare il dato dai brani esaminati.','evidence':[]});
  }
}
