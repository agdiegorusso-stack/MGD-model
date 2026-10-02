// Book QA is a source-scoped reader, not an LLM or a proof of general understanding.
// The evaluator NEVER supplies reference answers to the reader. Unknown is not false.
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

String bookNorm342(String x) => x.toLowerCase().replaceAll('’', "'")
    .replaceAll(RegExp(r'\s+'), ' ').trim();
String bookEntity342(String x) => bookNorm342(x)
    .replaceFirst(RegExp(r'^(?:il |lo |la |i |gli |le |un |uno |una |l\x27|un\x27)'), '')
    .replaceAll(RegExp(r'[.!?]+$'), '').trim();
String bookScope342(Map<String,dynamic> row) {
  final u = '${row['url'] ?? ''}';
  final m = RegExp(r'^local://book/([^/]+)/').firstMatch(u);
  return m == null ? 'legacy:${row['title'] ?? ''}' : 'book:${m[1]}';
}
String bookFingerprint342(List<Map<String,dynamic>> rows) {
  final ordered = rows.map((r) => '${r['id']}\u0000${r['text']}\u0000${r['url']}').toList()..sort();
  return sha256.convert(utf8.encode(ordered.join('\u0001'))).toString();
}

class BookResult342 {
  final String status, answer, reason;
  final List<Map<String,dynamic>> evidence, related;
  final int micros;
  final bool budgetReached;
  const BookResult342(this.status, this.answer, this.reason, this.evidence,
      this.related, this.micros, {this.budgetReached = false});
  bool get answered => status == 'direct' || status == 'deduction';
  Map<String,dynamic> toJson() => {'status':status,'answer':answer,'reason':reason,
    'evidence':evidence,'related':related,'micros':micros,'budgetReached':budgetReached};
  String render() {
    final label = {'direct':'Risposta dal testo', 'deduction':'Deduzione dalle premesse',
      'unknown':'Risposta non determinata', 'conflict':'Contraddizione nel materiale'}[status];
    final refs = evidence.isNotEmpty ? evidence : related;
    return '$label\n$answer\n$reason' + (refs.isEmpty ? '' : '\n\n' +
      (evidence.isEmpty ? 'Passaggi da controllare (non costituiscono una risposta):\n' : 'Evidenze:\n') +
      refs.map((r) => '«${r['text']}»\n${r['title']} • ${r['url']}').join('\n\n'));
  }
}

class BookFact342 {
  final String subject, relation, object;
  final bool negative, universal, derived;
  final List<String> proof, dependencies;
  final int depth;
  const BookFact342(this.subject,this.relation,this.object,this.negative,
      this.universal,this.proof,{this.derived=false,this.depth=0,this.dependencies=const []});
  String get atom => '$subject|$relation|$object';
  String get key => '$atom|$negative';
}
class _Query342 {
  final String mode, subject, relation, object;
  final bool negative;
  const _Query342(this.mode,this.subject,this.relation,this.object,{this.negative=false});
}
class _Closure342 {
  final List<BookFact342> facts;
  final bool truncated;
  const _Closure342(this.facts,this.truncated);
}

class BookEngine342 {
  final List<Map<String,dynamic>> rows;
  final Map<String,Map<String,dynamic>> byId = {};
  final List<BookFact342> facts = [];
  final Map<String,List<BookFact342>> bySubject = {}, rules = {};
  final Map<String,List<Map<String,dynamic>>> causes = {};
  final Map<String,Map<int,int>> postings = {};
  final List<int> lengths = [];
  late final double averageLength;
  late final String fingerprint;
  int skippedLong = 0;
  static const int maxDepth = 6, maxDerived = 512;
  static const verbs = <String,String>{
    'si trova nel':'luogo','si trova nella':'luogo','si trova in':'luogo','si trova a':'luogo',
    'si trovano nel':'luogo','si trovano nella':'luogo','si trovano in':'luogo','si trovano a':'luogo',
    'dipende da':'dipende','dipendono da':'dipende',
    'contiene':'contiene','contengono':'contiene','include':'contiene','includono':'contiene',
    'comprende':'contiene','comprendono':'contiene',
    'produce':'produce','producono':'produce','genera':'produce','generano':'produce',
    'possiede':'possiede','possiedono':'possiede','ha':'possiede','hanno':'possiede',
    'aiuta':'aiuta','aiutano':'aiuta','assiste':'aiuta','assistono':'aiuta',
    'insegue':'insegue','inseguono':'insegue','rincorre':'insegue','rincorrono':'insegue',
    'trasporta':'trasporta','trasportano':'trasporta','raggiunge':'raggiunge','raggiungono':'raggiunge',
    'precede':'precede','precedono':'precede','segue':'segue','seguono':'segue',
    'protegge':'protegge','proteggono':'protegge','separa':'separa','separano':'separa',
    'misura':'misura','misurano':'misura','assorbe':'assorbe','assorbono':'assorbe',
    'utilizza':'utilizza','utilizzano':'utilizza','usa':'utilizza','usano':'utilizza',
    'converte':'converte','convertono':'converte','causa':'causa','causano':'causa',
    'vive a':'luogo','vive in':'luogo','abita a':'luogo','abita in':'luogo',
  };
  static const passive = {'contenuto':'contiene','contenuta':'contiene','aiutato':'aiuta',
    'aiutata':'aiuta','inseguito':'insegue','inseguita':'insegue','prodotto':'produce',
    'prodotta':'produce','trasportato':'trasporta','trasportata':'trasporta'};
  static final _verbPattern = (verbs.keys.toList()..sort((a,b)=>b.length.compareTo(a.length)))
      .map(RegExp.escape).join('|');
  static final _passivePattern = passive.keys.map(RegExp.escape).join('|');
  static final _scope = RegExp(r'\b(?:se|quando|qualora|salvo|eccetto|tranne|forse|potrebbe|potrebbero|può|possono|sembra|sembrano|secondo|dice|afferma|sostiene|solitamente|spesso|talvolta|nessuno|nessuna|alcuni|alcune|solo|soltanto|prima|dopo|ieri|domani|mentre|ma|oppure)\b');
  static const _stop = {'il','lo','la','i','gli','le','un','uno','una','l','di','del','della',
    'dei','degli','delle','a','al','alla','da','dal','dalla','in','nel','nella','per','con',
    'e','o','è','sono','che','cosa','chi','dove','quando','perché','perche','quale','quali',
    'mi','puoi','dire','dimmi','spiega','spiegami','secondo','libro','testo','si','ogni'};
  static List<String> terms(String x) => RegExp(r'[a-zàèéìòù0-9]+')
      .allMatches(bookNorm342(x)).map((m)=>m[0]!).where((t)=>!_stop.contains(t))
      .map((t)=>verbs[t] ?? t).toList();

  BookEngine342(List<Map<String,dynamic>> input) : rows = List.unmodifiable(input.map((r)=>Map<String,dynamic>.from(r))) {
    fingerprint = bookFingerprint342(rows);
    for(var i=0;i<rows.length;i++) {
      final r=rows[i], id='${r['id']}'; byId[id]=r;
      final text='${r['text'] ?? ''}', ts=terms(text);
      lengths.add(ts.length);
      for(final t in ts) {final p=postings.putIfAbsent(t,()=>{}); p[i]=(p[i] ?? 0)+1;}
      if(text.length>1200) {skippedLong++; continue;}
      final cause=RegExp(r'^(.+?)\s+(?:perché|poiché)\s+(.+?)[.!]?$').firstMatch(bookNorm342(text));
      if(cause!=null) {
        final event=atomic(cause[1]!,id);
        if(event!=null && !event.universal) {
          causes.putIfAbsent(event.key,()=>[]).add({...r,'cause':cause[2]!.replaceAll(RegExp(r'[.!]+$'),'')});
        }
        continue; // A causal clause is not split into unconditional assertions.
      }
      final f=atomic(text,id); if(f==null) continue;
      facts.add(f);
      (f.universal ? rules : bySubject).putIfAbsent(f.subject,()=>[]).add(f);
    }
    averageLength=lengths.isEmpty?1:max(1,lengths.fold<int>(0,(a,b)=>a+b)/lengths.length).toDouble();
  }

  static BookFact342? atomic(String text,String id) {
    var s=bookNorm342(text);
    if(s.endsWith('?') || s.length>1200 || _scope.hasMatch(s) ||
      RegExp(r'[,;:"“”\n]|\b(?:e|o|né|perché|perche|poiché)\b').hasMatch(s)) return null;
    s=s.replaceAll(RegExp(r'[.!]+$'),'').trim();
    var universal=false;
    if(s.startsWith('ogni ')) {universal=true; s=s.substring(5);}
    if(RegExp(r'^(?:tutti|tutte|nessun|nessuna|ciascun|ciascuna)\b').hasMatch(s)) return null;
    final p=RegExp('^(.+?)\\s+(non\\s+)?(?:è|viene)\\s+($_passivePattern)\\s+(?:da |dal |dalla |dallo |dall[\x27])(.+)\$').firstMatch(s);
    if(p!=null && !universal) return _fact(p[4]!,passive[p[3]]!,p[1]!,p[2]!=null,false,id);
    final v=RegExp('^(.+?)\\s+(non\\s+)?($_verbPattern)\\s+(.+)\$').firstMatch(s);
    if(v!=null) return _fact(v[1]!,verbs[v[3]]!,v[4]!,v[2]!=null,universal,id);
    final c=RegExp(r'^(.+?)\s+(non\s+)?(?:è|sono)\s+(.+)$').firstMatch(s);
    if(c==null) return null;
    final nominal=RegExp(r'^(?:un |uno |una |un\x27)').hasMatch(c[3]!);
    return _fact(c[1]!,nominal?'tipo':'stato',c[3]!,c[2]!=null,universal,id);
  }
  static BookFact342? _fact(String s,String r,String o,bool n,bool u,String id) {
    s=bookEntity342(s); o=bookEntity342(o);
    if(s.isEmpty||o.isEmpty||s.length>100||o.length>240||s==o ||
        RegExp(r'\b(?:chi|cosa|dove|come|quale|che|questo|quello|egli|ella|lui|lei)\b').hasMatch(s)) return null;
    return BookFact342(s,r,o,n,u,[id]);
  }

  static _Query342? parseQuestion(String question) {
    var q=bookNorm342(question).replaceAll(RegExp(r'[?!.]+$'),'').trim();
    q=q.replaceFirst(RegExp(r'^(?:secondo il libro|nel libro|secondo il testo|nel testo),?\s+'),'');
    final d=RegExp(r'^(?:che cos\x27è|cos\x27è|che cosa è|cosa è|che cosa sono|cosa sono|di che tipo è)\s+(.+)$').firstMatch(q);
    if(d!=null) return _Query342('objects',bookEntity342(d[1]!),'tipo','');
    final why=RegExp(r'^(?:perché|perche|per quale motivo)\s+(.+)$').firstMatch(q);
    if(why!=null) {
      final a=atomic(why[1]!,'q');
      return a==null?null:_Query342('why',a.subject,a.relation,a.object,negative:a.negative);
    }
    final where=RegExp(r'^(?:dove|in quale luogo)\s+(?:si trova|si trovano|è|sono|vive|abita)\s+(.+)$').firstMatch(q);
    if(where!=null) return _Query342('objects',bookEntity342(where[1]!),'luogo','');
    final p=RegExp('^da chi (?:è|viene) ($_passivePattern) (.+)\$').firstMatch(q);
    if(p!=null) return _Query342('subjects','',passive[p[1]]!,bookEntity342(p[2]!));
    final what=RegExp('^(?:che cosa|cosa) ($_verbPattern) (.+)\$').firstMatch(q);
    if(what!=null) return _Query342('objects',bookEntity342(what[2]!),verbs[what[1]]!,'');
    final who=RegExp('^chi ($_verbPattern) (.+)\$').firstMatch(q);
    if(who!=null) return _Query342('subjects','',verbs[who[1]]!,bookEntity342(who[2]!));
    final a=atomic(q,'q');
    if(a==null||a.universal) return null;
    return _Query342('polar',a.subject,a.relation,a.object,negative:a.negative);
  }

  List<Map<String,dynamic>> search(String question,{int limit=5}) {
    final query=terms(question).toSet(), scores=<int,double>{}, matched=<int,int>{};
    for(final t in query) {
      final ps=postings[t]; if(ps==null) continue;
      final idf=log(1+(rows.length-ps.length+.5)/(ps.length+.5));
      for(final e in ps.entries) {
        scores[e.key]=(scores[e.key]??0)+idf*e.value*2.2/(e.value+1.2*(.25+.75*lengths[e.key]/averageLength));
        matched[e.key]=(matched[e.key]??0)+1;
      }
    }
    // OR retrieval finds evidence despite extra question words. It never asserts entailment.
    final ids=scores.keys.toList()..sort((a,b){
      final sa=scores[a]!*(matched[a]!/max(1,query.length));
      final sb=scores[b]!*(matched[b]!/max(1,query.length));
      final c=sb.compareTo(sa); return c!=0?c:a.compareTo(b);
    });
    return ids.take(limit).map((i)=>{...rows[i],'retrievalScore':scores[i],
      'lexicalCoverage':matched[i]!/max(1,query.length)}).toList();
  }

  _Closure342 closure(String subject,List<BookFact342> assumptions) {
    final all=<String,BookFact342>{};
    for(final f in [...?bySubject[subject],...assumptions.where((f)=>f.subject==subject)]) {all.putIfAbsent(f.key,()=>f);}
    final queue=all.values.toList(); var truncated=false, derived=0;
    for(var i=0;i<queue.length;i++) {
      final member=queue[i];
      if(member.relation!='tipo'||member.negative) continue;
      if(all.containsKey('${member.atom}|true')) continue;
      final applicable=rules[member.object] ?? const <BookFact342>[];
      if(member.depth>=maxDepth) {if(applicable.isNotEmpty) truncated=true; continue;}
      for(final r in applicable) {
        final f=BookFact342(subject,r.relation,r.object,r.negative,false,
          {...member.proof,...r.proof}.toList(),derived:true,depth:member.depth+1,
          dependencies:[...member.dependencies,member.key]);
        if(all.containsKey(f.key)) continue;
        if(derived>=maxDerived) {truncated=true; break;}
        derived++; all[f.key]=f; queue.add(f);
      }
      if(truncated && derived>=maxDerived) break;
    }
    final valid=all.values.where((f)=>f.dependencies.every((d){
      final split=d.lastIndexOf('|'); final opposite=d.substring(0,split)+(d.endsWith('|true')?'|false':'|true');
      return !all.containsKey(opposite);
    })).toList();
    return _Closure342(valid,truncated);
  }

  BookResult342 answer(String question,{String assumptions=''}) {
    final clock=Stopwatch()..start(), extra=<String,Map<String,dynamic>>{};
    final related=search(question);
    BookResult342 result(String status,String a,String why,List<String> ids,{bool limited=false}) =>
      BookResult342(status,a,why,ids.toSet().map((id)=>extra[id]??byId[id]).whereType<Map<String,dynamic>>().toList(),
        related,clock.elapsedMicroseconds,budgetReached:limited);
    final q=parseQuestion(question);
    if(q==null) return result('unknown','Non ricavo una risposta con il lettore attuale.',
      'Forma, riferimenti o condizioni non supportati. I passaggi trovati sono consultabili, non una risposta verificata.',[]);
    final hypothetical=<BookFact342>[];
    if(assumptions.trim().isNotEmpty) {
      final units=assumptions.split(RegExp(r'(?<=[.!?])\s+|\n+')).where((s)=>s.trim().isNotEmpty).toList();
      for(var i=0;i<units.length;i++) {
        final id='hypothesis:$i', f=atomic(units[i],id);
        if(f==null||f.universal) return result('unknown','Ipotesi non interpretata in modo univoco.',
          'Usa premesse individuali esplicite. Le ipotesi non vengono salvate come fatti del libro.',[]);
        hypothetical.add(f); extra[id]={'id':id,'text':units[i],'title':'Ipotesi della domanda — non salvata','url':'hypothesis://question','hypothesis':true};
      }
    }
    if(q.mode=='why') {
      if(hypothetical.isNotEmpty) return result('unknown','Non applico cause a ipotesi nuove.',
        'Il lettore delle cause richiede una motivazione esplicita nel testo.',[]);
      final cs=causes['${q.subject}|${q.relation}|${q.object}|${q.negative}'] ?? [];
      if(cs.isEmpty) return result('unknown','Nel materiale selezionato non trovo una motivazione esplicita.',
        'La vicinanza fra frasi non dimostra una causa.',[]);
      return result('direct',cs.map((r)=>r['cause']).toSet().join('; '),
        'Motivazione esplicitamente attribuita dal testo; non una verifica causale esterna.',cs.map((r)=>'${r['id']}').toList());
    }
    final c=q.mode=='subjects' ? _Closure342([...facts.where((f)=>!f.universal),...hypothetical],false) : closure(q.subject,hypothetical);
    if(c.truncated) return result('unknown','Ricerca delle premesse interrotta al budget operativo.',
      'La conoscenza non è stata cancellata. Non certifico una risposta dopo una ricerca incompleta.',[],limited:true);
    final selected=c.facts.where((f)=>f.relation==q.relation &&
      (q.mode=='subjects'?f.object==q.object:f.subject==q.subject) &&
      (q.mode=='polar'?f.object==q.object:true)).toList();
    if(selected.isEmpty) return result('unknown','Non ho una risposta sostenuta dalle premesse disponibili.',
      'Assenza di prova non significa falso. Nessun fatto è stato aggiunto dalla domanda.',[]);
    final atoms=<String,Set<bool>>{};
    for(final f in selected) {atoms.putIfAbsent(f.atom,()=>{}).add(f.negative);}
    if(atoms.values.any((v)=>v.length>1)) return result('conflict','Il materiale sostiene versioni incompatibili.',
      'Conservo entrambe le evidenze; non scelgo la più ripetuta come verità.',selected.expand((f)=>f.proof).toList());
    final used=q.mode=='polar'?selected:selected.where((f)=>!f.negative).toList();
    if(used.isEmpty) return result('unknown','Il testo esclude alcuni casi, ma non determina la risposta richiesta.',
      'Una negazione non identifica automaticamente un’alternativa.',selected.expand((f)=>f.proof).toList());
    final answer=q.mode=='polar' ? (used.first.negative==q.negative?'Sì':'No') :
      (used.map((f)=>q.mode=='subjects'?f.subject:f.object).toSet().toList()..sort()).join('; ');
    final inferred=used.any((f)=>f.derived);
    return result(inferred?'deduction':'direct',answer,
      (inferred?'Regola esplicita: appartenenza a una classe + proprietà universale della classe. ':'Lettura delle relazioni esplicite. ')+
      (hypothetical.isEmpty?'Risultato relativo al materiale selezionato, non certificazione della sua verità.':'Conclusione condizionata alle ipotesi della domanda; nessuna ipotesi è stata memorizzata.'),
      used.expand((f)=>f.proof).toList());
  }

  Map<String,dynamic> stats()=>{'passages':rows.length,'parsedStatements':facts.length,
    'universalRules':facts.where((f)=>f.universal).length,'explicitCauses':causes.values.fold<int>(0,(n,x)=>n+x.length),
    'skippedLong':skippedLong,'fingerprint':fingerprint,'maxDepth':maxDepth,'maxDerived':maxDerived};

  List<Map<String,dynamic>> probes({int limit=24}) {
    final eligible=facts.where((f)=>!f.universal&&!f.negative&&{'contiene','produce','possiede','aiuta','insegue','tipo','luogo'}.contains(f.relation)).toList();
    final out=<Map<String,dynamic>>[];
    for(var n=0;n<min(limit,eligible.length);n++) {
      final f=eligible[(n*eligible.length/min(limit,eligible.length)).floor()];
      final q=f.relation=='tipo'?'Che cosa è ${f.subject}?':f.relation=='luogo'?'Dove si trova ${f.subject}?':'Che cosa ${f.relation} ${f.subject}?';
      out.add({'id':'probe:$n','question':q,'assumptions':'','category':'autoprova',
        'expected':'answer','answers':[f.object],'support':f.proof.map((id)=>byId[id]!['text']).toList(),
        'origin':'auto_same_parser_not_independent'});
    }
    return out;
  }
}

class BookExam342 {
  static String normalize(String x)=>bookNorm342(x).replaceAll(RegExp(r'[^a-zàèéìòù0-9 ]'),' ')
      .replaceAll(RegExp(r'\s+'),' ').trim();
  static double tokenF1(String prediction,String reference) {
    final a=normalize(prediction).split(' ').where((x)=>x.isNotEmpty).toList();
    final b=normalize(reference).split(' ').where((x)=>x.isNotEmpty).toList();
    if(a.isEmpty||b.isEmpty) return a.isEmpty&&b.isEmpty?1:0;
    final counts=<String,int>{}; for(final t in b) {counts[t]=(counts[t]??0)+1;}
    var common=0; for(final t in a) {if((counts[t]??0)>0) {common++;counts[t]=counts[t]!-1;}}
    return 2*common/(a.length+b.length);
  }
  static List<Map<String,dynamic>> validate(dynamic value) {
    final raw=value is Map?value['cases']:value;
    if(raw is! List) throw const FormatException('Serve una lista cases di domande.');
    final ids=<String>{}, result=<Map<String,dynamic>>[];
    for(final item in raw) {
      if(item is! Map) throw const FormatException('Domanda non valida.');
      final c=Map<String,dynamic>.from(item), id='${c['id']??''}';
      if(id.isEmpty||!ids.add(id)||c['question'] is! String||'${c['question']}'.trim().isEmpty ||
        !{'answer','unknown','conflict'}.contains(c['expected'])) throw const FormatException('ID, domanda o risultato atteso non valido.');
      final answers=c['answers']??[], support=c['support']??[];
      if(answers is! List||support is! List||answers.any((x)=>x is! String)||support.any((x)=>x is! String) ||
        (c['expected']=='answer'&&(answers.isEmpty||answers.every((x)=>'$x'.trim().isEmpty)))) {
        throw const FormatException('Le risposte determinabili richiedono almeno una risposta di riferimento.');
      }
      if(c['assumptions']!=null&&c['assumptions'] is! String) throw const FormatException('Ipotesi non valida.');
      result.add({...c,'answers':answers,'support':support,'assumptions':c['assumptions']??'',
        'category':c['category']??'non classificata','origin':c['origin']??'external_reference'});
    }
    return result;
  }
  static Map<String,dynamic> run(BookEngine342 engine,List<Map<String,dynamic>> input) {
    final cases=validate(input), results=<Map<String,dynamic>>[], categories=<String,Map<String,int>>{};
    var correct=0, answered=0, wrongAnswers=0, unknownTotal=0, correctUnknown=0;
    var supportChecked=0, supportCorrect=0, joint=0, answerable=0; double f1=0;
    for(final c in cases) {
      // Gold/reference/support/origin/category never enter answer().
      final r=engine.answer(c['question'] as String,assumptions:c['assumptions'] as String);
      final refs=List<String>.from(c['answers'] as List), support=List<String>.from(c['support'] as List);
      final expect=c['expected'];
      final ok=expect=='unknown'?r.status=='unknown':expect=='conflict'?r.status=='conflict':
        r.answered&&refs.any((x)=>normalize(x)==normalize(r.answer));
      if(r.answered) answered++; if(ok) correct++;
      if(r.answered&&!ok) wrongAnswers++;
      if(expect=='unknown') {unknownTotal++;if(ok) correctUnknown++;}
      if(expect=='answer') {answerable++;if(r.answered) f1+=refs.fold<double>(0,(v,x)=>max(v,tokenF1(r.answer,x)));}
      final proofTexts=r.evidence.map((e)=>bookNorm342('${e['text']}')).toSet();
      final check=support.isNotEmpty;
      final proofOK=check&&support.every((s)=>proofTexts.contains(bookNorm342(s)));
      if(check) {supportChecked++;if(proofOK) supportCorrect++;if(ok&&proofOK) joint++;}
      final cat=categories.putIfAbsent('${c['category']}',()=>{'total':0,'correct':0,'answered':0});
      cat['total']=cat['total']!+1;if(ok) cat['correct']=cat['correct']!+1;if(r.answered) cat['answered']=cat['answered']!+1;
      results.add({'case':c,'result':r.toJson(),'correct':ok,'supportChecked':check,'supportCorrect':check?proofOK:null});
    }
    return {'schema':1,'readerVersion':'0.34.2','at':DateTime.now().toIso8601String(),
      'fingerprint':engine.fingerprint,'total':cases.length,'correct':correct,'answered':answered,
      'wrongAnswers':wrongAnswers,'coverage':cases.isEmpty?null:answered/cases.length,
      'accuracy':cases.isEmpty?null:correct/cases.length,'answerable':answerable,
      'tokenF1':answerable==0?null:f1/answerable,'unknownTotal':unknownTotal,'correctUnknown':correctUnknown,
      'supportChecked':supportChecked,'supportCorrect':supportCorrect,'jointCorrect':joint,
      'referenceKind':cases.any((c)=>c['origin']=='auto_same_parser_not_independent')?'contains_non_independent_auto_probes':'external_reference',
      'categories':categories,'results':results,'limitations':'Exact-match e token-F1 rispetto ai riferimenti; non un giudice semantico generale. Supporto confrontato solo quando fornito. Autoprove separate da esami indipendenti.'};
  }
}
