import 'dart:async';
import 'learned_reader_v0324.dart';
import 'native_mgd_engine_v09.dart';
import 'web_knowledge_explorer_v11.dart';

class Intake324 {
  final int added, corrected, duplicate, unresolved;
  final bool handled;
  final String message;
  const Intake324(this.added,this.corrected,this.duplicate,this.unresolved,
      this.handled,this.message);
}

/// Versioned, source-backed user assertions. No scientific truth is inferred
/// from geometry or from the classifier's uncalibrated score margin.
class RelationalMemory324 {
  static Map<String,dynamic> state(ResearchMemory11 memory) {
    final old=memory.state317['relationalMemory324'];
    if(old is Map<String,dynamic>) return old;
    final next=Map<String,dynamic>.from(old as Map? ?? {});
    memory.state317['relationalMemory324']=next;
    return next;
  }
  static Map<String,dynamic> _records(ResearchMemory11 memory) {
    final s=state(memory), old=s['records'];
    if(old is Map<String,dynamic>) return old;
    final next=Map<String,dynamic>.from(old as Map? ?? {});
    s['records']=next; return next;
  }
  static List<Map<String,dynamic>> rows(ResearchMemory11 memory,
      {bool includeHistory=true}) => _records(memory).values.whereType<Map>()
      .map((r)=>Map<String,dynamic>.from(r))
      .where((r)=>includeHistory||r['status']=='current').toList();

  static void _evolve(Map<String,dynamic> r,{required double reward}) {
    final step=MgdMath09.evolve(
      weight:(r['weight'] as num? ?? .98).toDouble(),
      memory:(r['memory'] as num? ?? 0).toDouble(),
      material:(r['material'] as num? ?? 0).toDouble(),
      coherenceAverage:(r['coherence'] as num? ?? 0).toDouble(),
      activation:1,reward:reward);
    r.addAll({'weight':step.weight,'memory':step.memory,
      'material':step.material,'coherence':step.coherenceAverage,
      'flux':step.informationalFlux,'active':step.active});
  }
  static void _bump(ResearchMemory11 m) {
    final s=state(m); s['revision']=(s['revision'] as num? ?? 0).toInt()+1;
    _indexes[m]=null;
  }
  static String _insert(ResearchMemory11 m,Frame324 f,String source,
      {String? replaces}) {
    final s=state(m);
    final sequence=(s['sequence'] as num? ?? 0).toInt()+1;
    s['sequence']=sequence;
    final id='r324:$sequence';
    final r=<String,dynamic>{...f.toJson(),'id':id,'sequence':sequence,
      'signature':f.signature,'source':source,'status':'current',
      'at':DateTime.now().toIso8601String(),'replaces':replaces};
    _evolve(r,reward:1);
    _records(m)[id]=r;
    if(replaces!=null) {
      final old=Map<String,dynamic>.from(_records(m)[replaces] as Map);
      old['status']='superseded'; old['supersededBy']=id;
      _evolve(old,reward:-1); _records(m)[replaces]=old;
    }
    _bump(m);
    return id;
  }
  static Intake324 learn(ResearchMemory11 m,String text,
      {String source='Chat utente'}) {
    final clock=Stopwatch()..start();
    final correction=RegExp(r'^\s*correggi\s*:\s*',caseSensitive:false);
    if(correction.hasMatch(text)) {
      final body=text.replaceFirst(correction,'').trim();
      final f=LearnedReader324.parse(body);
      if(f==null||!f.complete||f.question) {
        return const Intake324(0,0,0,1,true,
          'Correzione non applicata: scrivi una frase completa con agente, azione e oggetto.');
      }
      final candidates=rows(m,includeHistory:false).where((r)=>
        r['agent']==f.agent&&r['relation']==f.relation).toList();
      if(candidates.length!=1) {
        return const Intake324(0,0,0,1,true,
          'Correzione non applicata: serve una sola relazione precedente. Apri Relazioni apprese per scegliere quella da correggere.');
      }
      return correct(m,candidates.single['id'].toString(),body,source:source);
    }
    final signatures=rows(m).map((r)=>r['signature']).toSet();
    var added=0,duplicate=0,unresolved=0;
    var handled=false;
    String? antecedent;
    for(final sentence in text.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
      if(LearnedReader324.isQuestion(sentence)) {antecedent=null;continue;}
      final has=LearnedReader324.handles(sentence);
      handled=handled||has;
      final frame=LearnedReader324.parse(sentence,antecedent:antecedent);
      final previous=antecedent;
      antecedent=LearnedReader324.singleAntecedent(sentence);
      if(frame==null) {if(has) unresolved++;continue;}
      if(!frame.complete||frame.question) continue;
      // Reimporting an old assertion never resurrects a corrected revision.
      if(!signatures.add(frame.signature)) {duplicate++;continue;}
      _insert(m,frame,source);
      // Keep the entire two-sentence provenance for resolved pronouns.
      if(frame.resolvedPronoun && previous!=null) {
        final id='r324:${state(m)['sequence']}';
        final row=_records(m)[id] as Map;
        row['antecedent']=previous; row['contextText']=text;
      }
      added++;
    }
    final s=state(m);
    if(handled) {
      s['lastIntake']={'added':added,'duplicates':duplicate,
        'unresolved':unresolved,'micros':clock.elapsedMicroseconds};
    }
    return Intake324(added,0,duplicate,unresolved,handled,
      added>0 ? 'Ho conservato $added relazioni dal tuo testo. '
        '$unresolved frasi non interpretate; $duplicate già presenti.'
        : unresolved>0 ? 'Ho conservato il testo, ma non ricavo una relazione sicura: '
          'condizioni, riferimenti ambigui o costruzione fuori dal lettore sperimentale.'
        : 'Relazione già conservata; nessuna nuova evidenza aggiunta.');
  }
  static Future<Intake324> learnAsync(ResearchMemory11 m,String text,
      {String source='Testo insegnato'}) async {
    if(RegExp(r'^\s*correggi\s*:',caseSensitive:false).hasMatch(text)) {
      return learn(m,text,source:source);
    }
    final units=text.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    var added=0,corrected=0,duplicate=0,unresolved=0,handled=false;
    var carry='';
    for(var i=0;i<units.length;i+=24) {
      final group=units.skip(i).take(24).toList();
      final r=learn(m,[if(carry.isNotEmpty) carry,...group].join(' '),source:source);
      added+=r.added;corrected+=r.corrected;duplicate+=r.duplicate;
      unresolved+=r.unresolved;handled=handled||r.handled;
      carry=group.isNotEmpty&&LearnedReader324.singleAntecedent(group.last)!=null
        ?group.last:'';
      await Future<void>.delayed(Duration.zero);
    }
    return Intake324(added,corrected,duplicate,unresolved,handled,
      '$added relazioni apprese; $unresolved frasi non interpretate; $duplicate già presenti.');
  }
  static Intake324 correct(ResearchMemory11 m,String id,String replacement,
      {String source='Correzione utente'}) {
    final old=_records(m)[id] as Map?;
    final f=LearnedReader324.parse(replacement);
    if(old==null||old['status']!='current'||f==null||!f.complete||f.question) {
      return const Intake324(0,0,0,1,true,'Correzione non applicata: relazione o frase non valida.');
    }
    if(old['signature']==f.signature) {
      return const Intake324(0,0,1,0,true,'La relazione è già questa; nessuna modifica.');
    }
    final duplicate=rows(m,includeHistory:false).any((r)=>
      r['id']!=id && r['signature']==f.signature);
    if(duplicate) {
      return const Intake324(0,0,0,1,true,'Correzione non applicata: la relazione proposta è già presente.');
    }
    _insert(m,f,source,replaces:id);
    state(m)['lastIntake']={'added':0,'corrected':1,'duplicates':0,'unresolved':0};
    return const Intake324(0,1,0,0,true,
      'Correzione salvata. La relazione precedente resta nella cronologia ed è esclusa dalle risposte attuali.');
  }

  static final _indexes=Expando<_FrameIndex324>();
  static List<Map<String,dynamic>> find(ResearchMemory11 m,Frame324 q,
      {bool mgd=true}) {
    final index=_indexes[m]??=_FrameIndex324(rows(m,includeHistory:false));
    final candidates=index.find(q);
    candidates.sort((a,b) {
      if(!mgd) return (b['sequence'] as num).compareTo(a['sequence'] as num);
      double priority(Map<String,dynamic> r)=>MgdMath09.strength(
        weight:(r['weight'] as num).toDouble(),
        memory:(r['memory'] as num).toDouble(),
        material:(r['material'] as num).toDouble());
      final c=priority(b).compareTo(priority(a));
      return c!=0?c:(b['sequence'] as num).compareTo(a['sequence'] as num);
    });
    return candidates;
  }
  static String? answer(ResearchMemory11 m,String question,{bool mgd=true}) {
    if(!LearnedReader324.isQuestion(question)||
       !LearnedReader324.handles(question)) return null;
    final clock=Stopwatch()..start();
    final q=LearnedReader324.parse(question);
    if(q==null) return 'Non interpreto con sicurezza questa domanda. '
        'Il lettore sperimentale gestisce frasi semplici su inseguire, aiutare, contenere e possedere.';
    final matches=find(m,q,mgd:mgd);
    state(m)['lastQuery']={'micros':clock.elapsedMicroseconds,
      'candidates':matches.length,'mode':mgd?'MGD':'semplice'};
    if(matches.isEmpty) return 'Non ho una relazione insegnata che risponda a questa domanda.';
    final keys=<String,Set<bool>>{};
    for(final r in matches) {
      keys.putIfAbsent('${r['agent']}|${r['relation']}|${r['patient']}',()=>{})
        .add(r['negative']==true);
    }
    if(keys.values.any((v)=>v.length>1)) {
      return 'Ho affermazioni in conflitto sullo stesso fatto. '
          'Apri Relazioni apprese e correggi quella errata; non scelgo in base all’attivazione.';
    }
    final relevant=q.complete?matches:
      matches.where((r)=>(r['negative']==true)==q.negative).toList();
    if(relevant.isEmpty) return 'Non ho una relazione insegnata con questa polarità.';
    return 'Secondo il testo insegnato:\n'+relevant.map((r)=>
      '${r['agent']} ${r['negative']==true?'non ':''}${r['relation']} ${r['patient']}.\n'
      'Fonte: ${r['source']}. Versione ${r['sequence']}.').join('\n\n');
  }
  static Map<String,dynamic> stats(ResearchMemory11 m) {
    final all=rows(m),current=all.where((r)=>r['status']=='current').toList();
    return {'current':current.length,'history':all.length-current.length,
      'negative':current.where((r)=>r['negative']==true).length,
      'sources':all.map((r)=>r['source']).toSet().length,
      'lastIntake':state(m)['lastIntake'],'lastQuery':state(m)['lastQuery'],
      'training':LearnedReader324.model['training']};
  }
}
class _FrameIndex324 {
  final Map<String,List<Map<String,dynamic>>> byRelation={},byAgent={},byPatient={};
  _FrameIndex324(List<Map<String,dynamic>> rows) {
    for(final r in rows) {
      byRelation.putIfAbsent('${r['relation']}',()=>[]).add(r);
      byAgent.putIfAbsent('${r['relation']}|${r['agent']}',()=>[]).add(r);
      byPatient.putIfAbsent('${r['relation']}|${r['patient']}',()=>[]).add(r);
    }
  }
  List<Map<String,dynamic>> find(Frame324 q) {
    final source=q.agent!='*'?byAgent['${q.relation}|${q.agent}']:
      q.patient!='*'?byPatient['${q.relation}|${q.patient}']:byRelation[q.relation];
    return (source??const <Map<String,dynamic>>[]).where((r)=>
      (q.agent=='*'||r['agent']==q.agent)&&(q.patient=='*'||r['patient']==q.patient))
      .toList();
  }
}
