// MGD Dialogue Engine 0.41.0
// Stateful, evidence-grounded dialogue over the predictive cognitive core and
// the persistent theory-of-mind store. It is deliberately generative at the
// discourse-plan level, but does not call or embed an external LLM.
import 'dart:convert';
import 'dart:math';

import 'cognitive_core_v0400.dart';
import 'social_cognition_v0410.dart';
import 'mgd_language_v020.dart';
import 'generative_language_v0420.dart';
import 'recursive_tom_v0420.dart';

class DialogueState410 {
  String focus='';
  String lastIntent='';
  final List<String> recent=[];
  int turns=0;

  Map<String,dynamic> toJson()=>{'focus':focus,'lastIntent':lastIntent,'recent':recent.take(10).toList(),'turns':turns};
  factory DialogueState410.fromJson(Map m) {
    final s=DialogueState410();
    s.focus='${m['focus']??''}';
    s.lastIntent='${m['lastIntent']??''}';
    s.turns=(m['turns'] as num? ?? 0).toInt();
    s.recent.addAll(List<String>.from(m['recent'] as List? ?? const []));
    return s;
  }
  DialogueState410();
}

class DialogueReply410 {
  final String text,intent;
  final double confidence;
  final bool inferred;
  const DialogueReply410(this.text,{required this.intent,required this.confidence,this.inferred=false});
}

class DialogueEngine410 {
  final CognitiveCore400 core;
  final TheoryOfMind410 mind;
  final SocialStore410 social;
  DialogueState410 state=DialogueState410();
  bool _loaded=false;

  DialogueEngine410(this.core,this.mind,this.social);

  Future<void> _load() async {
    if(_loaded)return;
    _loaded=true;
    final raw=await social.getMeta('dialogue_state');
    if(raw==null||raw.isEmpty)return;
    try { state=DialogueState410.fromJson(jsonDecode(raw) as Map); } catch(_){}
  }

  Future<void> _save() async {
    await social.setMeta('dialogue_state',jsonEncode(state.toJson()));
  }

  static bool _question(String x)=>x.trim().endsWith('?')||
      RegExp(r'^\s*(chi|cosa|che cosa|come|dove|quando|perché|perche|qual|quale|quali|cos|parlami|spieg\w*|approfondisci|continua|in che senso|e quindi|dimmi|secondo te|cosa pensi|che ne pensi|cosa crede|che cosa crede|cosa sa|che cosa sa)\b',caseSensitive:false).hasMatch(x);

  List<String> _content(String text)=>tokens400(text).where(isContent400).toList(growable:false);

  void _rememberFocus(Iterable<String> terms) {
    for(final t in terms.where((x)=>x.isNotEmpty)) {
      state.focus=t;
      state.recent.remove(t);
      state.recent.insert(0,t);
      if(state.recent.length>10)state.recent.removeLast();
    }
  }

  Future<DialogueReply410?> process(String raw) async {
    await _load();
    final text=raw.trim();
    if(text.isEmpty)return null;
    state.turns++;

    final q=canon410(text);
    final greeting=RegExp(r'^(ciao|salve|buongiorno|buonasera|hey|ehi)\b').hasMatch(q);
    if(greeting) {
      state.lastIntent='greeting';
      await _save();
      return DialogueReply410(
        state.focus.isEmpty
          ? 'Ciao. Sono operativo: posso ragionare su ciò che ho appreso, dirti cosa non so e aggiornare il mio modello durante il dialogo.'
          : 'Ciao. L’ultimo tema attivo nella mia memoria di dialogo è “${state.focus}”. Possiamo ripartire da lì oppure cambiare argomento.',
        intent:'greeting',confidence:.98);
    }

    if(!_question(text)) {
      final turn=await core.experience(text,source:'dialogo');
      final sentences=text.split(RegExp(r'(?<=[.!?])\s+|\n+')).where((x)=>x.trim().isNotEmpty);
      for(final sentence in sentences) {
        final f=FrameInducer400.induce(sentence);
        if(f.valid) await mind.experience(sentence,f);
      }
      _rememberFocus(turn.frame.concepts.where(isContent400).take(5));
      state.lastIntent='experience';
      await _save();
      final curiosity=turn.curiosity.isEmpty?null:turn.curiosity.first;
      if(turn.attention.salience>=.62 && curiosity!=null) {
        return DialogueReply410(
          'Ho aggiornato il modello. Questa esperienza ha salienza ${(turn.attention.salience*100).round()}% '
          '(sorpresa ${(turn.attention.surprise*100).round()}%, novità ${(turn.attention.novelty*100).round()}%). '
          'La lacuna più utile che emerge è: $curiosity',
          intent:'learn-and-curious',confidence:.90,inferred:true);
      }
      return DialogueReply410(
        turn.frame.valid
          ? 'Ho integrato questa esperienza nel modello del mondo e nella memoria semantica. '
            'Il focus attuale è “${state.focus}”.'
          : 'Ho acquisito le regolarità linguistiche del messaggio, ma non ho ancora estratto un evento abbastanza stabile da trattare come fatto.',
        intent:'learn',confidence:turn.frame.valid ? .86 : .58,inferred:true);
    }

    final tom=await mind.answer(text);
    if(tom!=null) {
      state.lastIntent='theory-of-mind';
      final terms=_content(text); if(terms.isNotEmpty)_rememberFocus(terms.take(3));
      await _save();
      return DialogueReply410(tom,intent:'theory-of-mind',confidence:.90,inferred:true);
    }

    if(RegExp(r'^(chi sei|cosa sei|che cosa sei)$').hasMatch(q)) {
      state.lastIntent='self-model'; await _save();
      return const DialogueReply410(
        'Sono MGD Neuro: un sistema sperimentale di apprendimento continuo. '
        'Mantengo separati fatti, associazioni, episodi, previsioni e modelli delle credenze altrui. '
        'Non ho coscienza né emozioni biologiche; posso però rappresentare incertezza, obiettivi e lacune informative.',
        intent:'self-model',confidence:1.0);
    }

    if(RegExp(r'^(come stai|come ti senti)$').hasMatch(q)) {
      final st=await core.store.stats(), ss=await social.stats();
      state.lastIntent='self-state'; await _save();
      return DialogueReply410(
        'Non provo stati emotivi umani. Il mio stato operativo adesso contiene ${st['concepts']} concetti, '
        '${st['relations']} relazioni e ${ss['beliefs']} credenze attribuite ad agenti; '
        'l’ultimo errore di previsione è ${((st['predictionError'] as num)*100).toStringAsFixed(0)}%.',
        intent:'self-state',confidence:1.0);
    }

    if(RegExp(r'^(cosa stai pensando|che cosa stai pensando|a cosa stai pensando)$').hasMatch(q)) {
      final gaps=await core.curiosity(limit:3);
      state.lastIntent='metacognition'; await _save();
      return DialogueReply410(
        state.focus.isEmpty
          ? 'Non ho un focus conversazionale stabile. Le mie principali lacune attive sono: ${gaps.join(' ')}'
          : 'Il focus attivo è “${state.focus}”. Sto soprattutto cercando di ridurre queste incertezze: ${gaps.join(' ')}',
        intent:'metacognition',confidence:.95,inferred:true);
    }

    if(RegExp(r'^(cosa non capisci|che cosa non capisci|cosa non sai|che cosa non sai)$').hasMatch(q)) {
      final gaps=await core.curiosity(limit:5);
      state.lastIntent='ignorance'; await _save();
      return DialogueReply410(
        gaps.isEmpty?'Non ho una lacuna sufficientemente saliente registrata in questo momento.'
          :'Le lacune informative con priorità maggiore sono: ${gaps.join(' ')}',
        intent:'ignorance',confidence:.94,inferred:true);
    }

    final follow=RegExp(r'^(spiegami meglio|approfondisci|continua|perché|perche|e quindi|in che senso)[?!.]*$').hasMatch(q);
    if(follow && state.focus.isNotEmpty) {
      final deep=await _deepDescription(state.focus);
      state.lastIntent='follow-up'; await _save();
      return DialogueReply410(deep,intent:'follow-up',confidence:.76,inferred:true);
    }

    final compare=RegExp(r'^(?:confronta|che differenza c.?è tra|qual è la differenza tra|differenza tra)\s+(.+?)\s+(?:e|con)\s+(.+)$').firstMatch(q);
    if(compare!=null) {
      final a=compare[1]!.trim(),b=compare[2]!.trim();
      _rememberFocus([a,b]);
      final ans=await _compare(a,b);
      state.lastIntent='compare'; await _save();
      return DialogueReply410(ans,intent:'compare',confidence:.78,inferred:true);
    }

    final opinion=RegExp(r'^(?:cosa pensi di|che cosa pensi di|che ne pensi di|secondo te)\s+(.+)$').firstMatch(q);
    if(opinion!=null) {
      final topic=opinion[1]!.trim();_rememberFocus([topic]);
      final ans=await _opinion(topic);
      state.lastIntent='opinion';await _save();
      return DialogueReply410(ans,intent:'opinion',confidence:.72,inferred:true);
    }

    final hypothetical=RegExp(r'^(?:cosa|che cosa)\s+(?:succederebbe|accadrebbe)\s+se\s+(.+)$').firstMatch(q);
    if(hypothetical!=null) {
      final ans=await _simulate(hypothetical[1]!);
      state.lastIntent='simulation';await _save();
      return DialogueReply410(ans,intent:'simulation',confidence:.64,inferred:true);
    }

    final direct=await core.answer(text);
    if(direct!=null && !direct.startsWith('Le associazioni più attive')) {
      final terms=_content(text);if(terms.isNotEmpty)_rememberFocus(terms.take(4));
      state.lastIntent='direct';await _save();
      return DialogueReply410(_naturalDirect(text,direct),intent:'direct',confidence:.91,inferred:true);
    }

    final why=RegExp(r'^perché\s+(.+)$').firstMatch(q)??RegExp(r'^perche\s+(.+)$').firstMatch(q);
    if(why!=null) {
      final ans=await _why(why[1]!);
      state.lastIntent='why';await _save();
      return DialogueReply410(ans,intent:'why',confidence:.60,inferred:true);
    }

    final cues=_content(text);
    if(cues.isNotEmpty)_rememberFocus(cues.take(4));
    final generic=await _generic(text,cues);
    state.lastIntent='open-question';await _save();
    return DialogueReply410(generic,intent:'open-question',confidence:.58,inferred:true);
  }

  String _naturalDirect(String prompt,String direct) {
    final d=direct.trim();
    if(d.isEmpty)return d;
    if(d.contains('.')||d.length>80)return d;
    final q=canon410(prompt);
    if(q.startsWith('chi '))return '${_cap(d)}.';
    if(q.startsWith('dove '))return 'La posizione che ricavo dalla memoria è: $d.';
    return '${_cap(d)}.';
  }

  Future<String> _deepDescription(String topic) async {
    final c=await core.store.concept(topic);
    if(c==null)return 'Su “$topic” non ho ancora abbastanza esperienza per approfondire senza inventare.';
    final rel=List<Map<String,dynamic>>.from((c['relations'] as List).map((x)=>Map<String,dynamic>.from(x as Map)));
    final assoc=List<Map<String,dynamic>>.from((c['associations'] as List).map((x)=>Map<String,dynamic>.from(x as Map)));
    final parts=<String>[];
    parts.add('Su “$topic” ho ${c['exposures']} osservazioni.');
    if(rel.isNotEmpty)parts.add('Le relazioni più concrete sono: ${rel.take(4).map(_renderRelation).join('; ')}.');
    if(assoc.isNotEmpty)parts.add('Le associazioni contestuali più forti sono ${assoc.take(5).map((x)=>x['term']).join(', ')}.');
    final neighbours=await core.store.semanticNeighbors420(topic,limit:5);
    if(neighbours.isNotEmpty) {
      parts.add('Nello spazio semantico appreso è vicino a ${neighbours.map((x)=>x['term']).join(', ')}');
    }
    final ignorance=await core.ignorance(topic);
    parts.add(ignorance);
    return parts.join(' ');
  }

  Future<String> _opinion(String topic) async {
    final c=await core.store.concept(topic);
    if(c==null)return 'Non ho ancora una base sufficiente per formulare una valutazione su “$topic”. Preferisco non inventarla.';
    final rel=(c['relations'] as List).cast<Map>().take(4).toList();
    final assoc=(c['associations'] as List).cast<Map>().take(5).map((x)=>x['term']).toList();
    final evidence=<String>[];
    if(rel.isNotEmpty)evidence.add(rel.map((x)=>_renderRelation(Map<String,dynamic>.from(x))).join('; '));
    if(assoc.isNotEmpty)evidence.add('associazioni: ${assoc.join(', ')}');
    return 'Non ho gusti personali, ma posso formulare una valutazione basata sulla mia esperienza: '
      '“$topic” è rappresentato soprattutto attraverso ${evidence.isEmpty?'evidenze ancora scarse':evidence.join('. ')}. '
      'La considero un’ipotesi aggiornabile, non un fatto assoluto.';
  }

  Future<String> _compare(String a,String b) async {
    final aa=(await core.store.associations(a,limit:20)).map((x)=>'${x['term']}').toSet();
    final bb=(await core.store.associations(b,limit:20)).map((x)=>'${x['term']}').toSet();
    final shared=aa.intersection(bb).take(5).toList();
    final onlyA=aa.difference(bb).take(4).toList(),onlyB=bb.difference(aa).take(4).toList();
    if(aa.isEmpty&&bb.isEmpty)return 'Non ho abbastanza esperienza di “$a” e “$b” per confrontarli.';
    return 'Nel mio modello, “$a” e “$b” condividono ${shared.isEmpty?'poche associazioni consolidate':shared.join(', ')}. '
      'Sono più specifiche di “$a”: ${onlyA.isEmpty?'nessuna abbastanza stabile':onlyA.join(', ')}. '
      'Sono più specifiche di “$b”: ${onlyB.isEmpty?'nessuna abbastanza stabile':onlyB.join(', ')}.';
  }

  Future<String> _simulate(String clause) async {
    final f=FrameInducer400.induce(clause);
    if(!f.valid)return 'Non riesco ancora a trasformare questa ipotesi in uno stato simulabile.';
    final next=await core.store.nextPredicates(f.predicate);
    if(next.isEmpty)return 'Posso rappresentare l’ipotesi “${f.subject} → ${f.predicate} → ${f.object}”, '
      'ma non ho ancora transizioni apprese sufficienti per prevederne una conseguenza.';
    final total=next.values.fold<int>(0,(a,b)=>a+b);
    final ranked=next.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    return 'Se assumo “${f.subject} → ${f.predicate} → ${f.object}”, le continuazioni che la mia esperienza rende più probabili sono: '
      '${ranked.take(3).map((e)=>'${e.key} (${(100*e.value/max(1,total)).round()}%)').join(', ')}. '
      'È una previsione statistica, non una conseguenza necessaria.';
  }

  Future<String> _why(String clause) async {
    final cues=_content(clause);
    if(cues.isEmpty)return 'Non ho abbastanza struttura nella domanda per cercare una causa.';
    final paths=await _relationEvidence(cues,limit:5);
    if(paths.isEmpty)return 'Non possiedo ancora una causa esplicita per questo. Posso cercare correlazioni, ma non voglio trasformarle in causalità senza evidenza.';
    return 'Non ho una prova causale diretta; le evidenze più vicine nel modello sono: ${paths.join('; ')}. '
      'Le tratterei come piste da verificare, non come spiegazione definitiva.';
  }

  Future<String> _generic(String prompt,List<String> cues) async {
    final expanded=<String>[...cues];
    for(final c in cues.take(3)) {
      final neighbours=await core.store.semanticNeighbors420(c,limit:3);
      for(final n in neighbours) {
        if((n['score'] as num).toDouble()>=.18) {
          final term='${n['term']}';
          if(!expanded.contains(term))expanded.add(term);
        }
      }
    }
    final path=await _pathBetweenCues(expanded);
    final evidence=await _relationEvidence(expanded,limit:6);
    final recall=await core.store.recall(expanded,limit:6);
    if(path!=null)return 'Riesco a collegare i concetti così: $path. '
      '${evidence.isEmpty?'': 'Le relazioni che sostengono il collegamento sono: ${evidence.take(3).join('; ')}.'}';
    if(evidence.isNotEmpty)return 'Quello che posso sostenere dalla memoria è questo: ${evidence.take(4).join('; ')}. '
      'Non ho ancora una rappresentazione abbastanza completa per andare oltre senza aumentare l’incertezza.';
    final strong=recall.where((x)=>(x['weight'] as double)>.06).map((x)=>'${x['term']}').where((x)=>!cues.contains(x)).take(5).toList();
    if(strong.isNotEmpty)return 'La domanda attiva soprattutto questi concetti nella mia memoria: ${strong.join(', ')}. '
      'Non ho ancora una relazione determinata che chiuda la risposta. Posso però usare questo vuoto come obiettivo di apprendimento.';
    final gaps=await core.curiosity(limit:2);
    return 'Non ho ancora una rappresentazione sufficiente per rispondere in modo affidabile. '
      '${gaps.isEmpty?'Mi serve un’esperienza o una definizione in più.':'La domanda che ridurrebbe maggiormente l’incertezza è: ${gaps.first}'}';
  }

  Future<List<String>> _relationEvidence(List<String> cues,{int limit=6}) async {
    final out=<String>[],seen=<String>{};
    for(final c in cues.take(5)) {
      final rows=await core.store.relations(c,limit:limit);
      for(final r in rows) {
        final text=_renderRelation(r);
        if(seen.add(text))out.add(text);
        if(out.length>=limit)return out;
      }
    }
    return out;
  }

  Future<String?> _pathBetweenCues(List<String> cues) async {
    final unique=cues.toSet().toList();
    if(unique.length<2)return null;
    final start=unique.first,target=unique.last;
    if(start==target)return null;
    final queue=<List<String>>[[start]];
    final visited=<String>{start};
    var expanded=0;
    while(queue.isNotEmpty&&expanded<120) {
      final path=queue.removeAt(0),node=path.last;expanded++;
      if(path.length>4)continue;
      final rows=await core.store.relations(node,limit:30);
      for(final r in rows) {
        final s='${r['subject']}',o='${r['object']}';
        final next=s.contains(node)?o:s;
        if(next.isEmpty||visited.contains(next))continue;
        final np=[...path,next];
        if(next.contains(target)||target.contains(next))return np.map(_cap).join(' → ');
        visited.add(next);queue.add(np);
      }
    }
    return null;
  }

  static String _renderRelation(Map<String,dynamic> r) {
    final s='${r['subject']}',p='${r['predicate']}',o='${r['object']}',l='${r['location']}';
    return '${_cap(s)} → ${r['negative']==1?'non ':''}$p → ${o.isEmpty?l:o}${o.isNotEmpty&&l.isNotEmpty?' ($l)':''}';
  }

  static String _cap(String s)=>s.isEmpty?s:'${s[0].toUpperCase()}${s.substring(1)}';
}

class DialogueBridge410 {
  static DialogueEngine410? _engine;
  static RecursiveTheoryOfMind420? _recursive420;
  static MgdLanguage20? _surfaceLanguage420;
  static int _surfaceLoadedTurn420 = -100;

  static Future<DialogueEngine410> get engine async {
    final existing=_engine;if(existing!=null)return existing;
    final core=await CognitiveCoreBridge400.core;
    final social=await SocialStore410.open();
    return _engine=DialogueEngine410(core,TheoryOfMind410(social),social);
  }

  static Future<RecursiveTheoryOfMind420> get recursive420 async {
    final existing=_recursive420;if(existing!=null)return existing;
    return _recursive420=RecursiveTheoryOfMind420(await RecursiveToMStore420.open());
  }

  static Future<String?> processChat(String text) async {
    final nested=await (await recursive420).answer(text);
    if(nested==null) {
      await (await recursive420).observe(text);
    }
    final e=await engine;
    final reply=nested==null ? await e.process(text) : DialogueReply410(
      nested,intent:'recursive-theory-of-mind',confidence:.88,inferred:true);
    if(reply==null)return null;
    final semantic=reply.text;
    if(semantic.split(RegExp(r'\s+')).length<6)return semantic;
    try {
      if(_surfaceLanguage420==null ||
          e.state.turns-_surfaceLoadedTurn420>=4) {
        _surfaceLanguage420=await MgdLanguagePersistence20().load();
        _surfaceLoadedTurn420=e.state.turns;
      }
      final lang=_surfaceLanguage420;
      if(lang!=null && lang.stats().sentences>=12) {
        final generated=GenerativeLanguage420(lang).realize(text,semantic,maxWords:72);
        if(generated!=null&&generated.trim().isNotEmpty)return generated;
      }
    } catch(_) {
      // Surface generation is optional: never lose a grounded semantic answer
      // because the language decoder or its snapshot is unavailable.
    }
    return semantic;
  }

  static Future<Map<String,dynamic>> stats() async {
    final e=await engine;
    final recursive=await recursive420;
    return {...await e.core.store.stats(),...await e.social.stats(),
      'secondOrderBeliefs':await recursive.store.count(),
      'focus':e.state.focus,'turns':e.state.turns};
  }

  static Future<void> reset() async {
    final e=await engine;
    e.state=DialogueState410();
    await e.social.clear();
    await (await recursive420).store.clear();
    await e.core.store.clear();
    e.core.workingMemory.clear();
  }

  static Future<void> close() async {
    final e=_engine;_engine=null;
    final r=_recursive420;_recursive420=null;
    _surfaceLanguage420=null;
    _surfaceLoadedTurn420=-100;
    if(e!=null)await e.social.close();
    if(r!=null)await r.store.close();
  }
}
