import 'dart:math';

import 'package:flutter/foundation.dart';

import 'plastic_language_brain_v04.dart';
import 'sensory_world_v06.dart';
import 'web_knowledge_explorer_v11.dart';
import 'cognitive_induction_v024.dart';

String _n22(String x)=>x
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9àèéìòù]+'),' ')
    .replaceAll(RegExp(r'\s+'),' ')
    .trim();

String _cleanSubject22(String raw){
  var s=raw
      .replaceAll(RegExp(r'^[\s\-–—•·*#\d.:;"“”«»]+'),'')
      .replaceAll(RegExp(r"^['’]+"),'')
      .trim();
  if(s.contains(',')){
    final first=s.split(',').first.trim();
    if(first.split(RegExp(r'\s+')).length<=6)s=first;
  }
  return s.replaceAll(RegExp(r'\s+'),' ').trim();
}

String _cleanObject22(String raw,{bool type=false}){
  var s=raw
      .replaceAll(RegExp(r'[,;]\s+(?:che|dove|quando|mentre|poiché|perché|il quale|la quale|i quali|le quali)\b.*$',caseSensitive:false),'')
      .replaceAll(RegExp(r'\s+'),' ')
      .trim();
  s=s.replaceAll(RegExp(r'[\s,;:.!?]+$'),'').trim();
  if(type){
    s=s.replaceFirst(RegExp(r'^(?:primo|prima|secondo|seconda|terzo|terza|quarto|quarta|quinto|quinta|sesto|sesta|settimo|settima|ottavo|ottava|nono|nona|decimo|decima)\s+',caseSensitive:false),'');
    final cut=RegExp(r'\s+(?:di|del|della|dei|degli|delle|nel|nella|nei|nelle)\s+',caseSensitive:false).firstMatch(s);
    if(cut!=null && cut.start>1)s=s.substring(0,cut.start).trim();
    final ws=s.split(RegExp(r'\s+'));
    if(ws.length>5)s=ws.take(5).join(' ');
  }
  return s;
}

bool _validSubject22(String s){
  if(s.length<2||s.length>90)return false;
  final words=s.split(RegExp(r'\s+'));
  if(words.length>9)return false;
  final n=_n22(s);
  const bad={'lui','lei','esso','essa','essi','esse','questo','questa','quello','quella','ciò','cio','che','chi','si','ne','io','tu','noi','voi','loro'};
  if(bad.contains(n))return false;
  final first=s.trimLeft();
  if(first.isEmpty)return false;
  final c=first.codeUnitAt(0);
  final upper=(c>=65&&c<=90)||'ÀÈÉÌÒÙ'.contains(first[0]);
  return upper;
}

bool _validObject22(String s){
  if(s.length<2||s.length>180)return false;
  final words=s.split(RegExp(r'\s+'));
  if(words.length>18)return false;
  final n=_n22(s);
  if(n.isEmpty||{'esso','essa','questo','questa','ciò','cio','che'}.contains(n))return false;
  return true;
}

bool _looksNarrative22(String sentence,String subject){
  final raw=sentence.trim();
  final ns=_n22(subject);
  const bad={'naturalmente','ora','cosi','così','senti','rise','disse','rispose','allora','poi','forse','certo'};
  if(bad.contains(ns))return true;
  if(RegExp(r'^(?:e|ma|ora|cos[iì]|se|quando|mentre|perch[eé]|come|poi|allora|naturalmente)\b',caseSensitive:false).hasMatch(subject))return true;
  if(RegExp(r'\b(?:io|tu|mio|mia|miei|mie|tuo|tua|tuoi|tue|noi|nostro|nostra|voi|vostro|vostra)\b',caseSensitive:false).hasMatch(subject))return true;
  if(RegExp(r'\b(?:disse|rispose|grid[oò]|rise|pens[oò]|guard[oò]|sent[iì]|vide|chiese|domand[oò]|esclam[oò]|sussurr[oò])\b',caseSensitive:false).hasMatch(raw))return true;
  if(raw.contains('«')||raw.contains('»')||raw.contains('“')||raw.contains('”')||raw.contains('—')||raw.contains('–'))return true;
  if(raw.startsWith('-')||subject.contains(':')||subject.contains(';')||subject.contains('?')||subject.contains('!'))return true;
  return false;
}

List<Map<String,dynamic>> _extractCorpusClaims22(Map<String,dynamic> input){
  final text=(input['text']??'').toString();
  final maxClaims=(input['maxClaims'] as num?)?.toInt()??3500;
  final normalized=text
      .replaceAll('\r','\n')
      .replaceAll(RegExp(r'\n{2,}'),'. ')
      .replaceAll(RegExp(r'[\t ]+'),' ');
  final sentences=normalized
      .split(RegExp(r'[.!?]+(?:\s+|$)|\n+'))
      .map((x)=>x.trim())
      .where((x)=>x.length>=8&&x.length<=650)
      .toList();

  final patterns=<({RegExp re,String relation,double quality,bool type})>[
    (re:RegExp(r'^(.{2,90}?)\s+(?:è|È)\s+(?:compost[oa]|costituit[oa]|format[oa])\s+da\s+(.+)$'),relation:'composto da',quality:.96,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+fa\s+parte\s+(?:di|del|della|dei|degli|delle)\s+(.+)$',caseSensitive:false),relation:'parte di',quality:.95,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+appartiene\s+(?:a|al|alla|ai|agli|alle)\s+(.+)$',caseSensitive:false),relation:'appartiene a',quality:.94,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+(?:si\s+trova|è\s+situat[oa])\s+(?:in|nel|nella|nei|nelle)\s+(.+)$',caseSensitive:false),relation:'si trova in',quality:.93,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+(?:vive|abita)\s+(?:in|nel|nella|nei|nelle)\s+(.+)$',caseSensitive:false),relation:'vive in',quality:.92,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+(?:deriva|proviene)\s+da\s+(.+)$',caseSensitive:false),relation:'deriva da',quality:.91,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+dipende\s+da\s+(.+)$',caseSensitive:false),relation:'dipende da',quality:.90,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+(?:serve\s+(?:a|per)|consente\s+di|permette\s+di)\s+(.+)$',caseSensitive:false),relation:'serve per',quality:.90,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+(?:usa|utilizza|impiega)\s+(.+)$',caseSensitive:false),relation:'usa',quality:.87,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+comprende\s+(.+)$',caseSensitive:false),relation:'comprende',quality:.88,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+contiene\s+(.+)$',caseSensitive:false),relation:'contiene',quality:.88,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+(?:ha|possiede)\s+(.+)$',caseSensitive:false),relation:'ha',quality:.85,type:false),
    (re:RegExp(r'^(.{2,90}?)\s+(?:è|È)\s+(?:un|uno|una)\s+(.+)$'),relation:'tipo di',quality:.97,type:true),
  ];

  final out=<Map<String,dynamic>>[];
  for(final sentence in sentences){
    if(out.length>=maxClaims)break;
    var clean=sentence
        .replaceAll(RegExp(r'\[[^\]]*\]'),' ')
        .replaceAll(RegExp(r'\([^)]{0,120}\)'),' ')
        .replaceAll(RegExp(r'\s+'),' ')
        .trim();
    if(clean.length<8)continue;
    for(final p in patterns){
      final m=p.re.firstMatch(clean);
      if(m==null)continue;
      final subject=_cleanSubject22(m.group(1)??'');
      final object=_cleanObject22(m.group(2)??'',type:p.type);
      if(!_validSubject22(subject)||!_validObject22(object)||_looksNarrative22(clean,subject))continue;
      if(_n22(subject)==_n22(object))continue;
      out.add({
        'subject':subject,
        'relation':p.relation,
        'object':object,
        'sentence':clean,
        'quality':p.quality,
      });
      break;
    }
  }
  return <Map<String,dynamic>>[
    {'_meta':true,'sentences':sentences.length},
    ...out,
  ];
}

class CorpusSemanticOutcome22{
  final int sentences;
  final int candidates;
  final int accepted;
  final int doubtful;
  final int conflicts;
  final int reinforced;
  final int entitiesTouched;
  CorpusSemanticOutcome22({required this.sentences,required this.candidates,required this.accepted,required this.doubtful,required this.conflicts,required this.reinforced,required this.entitiesTouched});
  String cognitiveSummary='';
  String get summary=>'${cognitiveSummary.isEmpty?'':cognitiveSummary+' · '}semantica: $candidates candidati, $accepted consolidati, $reinforced rinforzati, $doubtful dubbi, $conflicts conflitti';
}

class CorpusSemanticBridge22{
  static String _key(String s,String r,String o)=>'${_n22(s)}|${_n22(r)}|${_n22(o)}';

  static bool _conflict(PlasticLanguageBrain04 brain,String s,String r,String o){
    final ns=_n22(s),nr=_n22(r),no=_n22(o);
    for(final x in brain.semanticGraph(limit:100000)){
      if(x.confidence<.68)continue;
      if(_n22(x.from)==ns&&_n22(x.relation)==nr&&_n22(x.to)!=no)return true;
    }
    return false;
  }

  static Future<CorpusSemanticOutcome22> learn({
    required String text,
    required String sourceName,
    required PlasticLanguageBrain04 brain,
    required MgdWorld06 world,
    required ResearchMemory11 memory,
    String? sourceFamily,
  }) async{
    final cognitive=await CognitiveInduction24.learn(text:text,sourceName:sourceName,brain:brain,memory:memory);
    final rows=await compute(_extractCorpusClaims22,<String,dynamic>{'text':text,'maxClaims':3500});
    var sentenceCount=0;
    final claims=<Map<String,dynamic>>[];
    for(final row in rows){
      if(row['_meta']==true){sentenceCount=(row['sentences'] as num?)?.toInt()??0;}else{claims.add(row);}
    }
    final family=sourceFamily??'corpus:${_n22(sourceName)}';
    final now=DateTime.now();
    final iso=now.toIso8601String();
    final grouped=<String,List<Map<String,dynamic>>>{};
    for(final c in claims){
      final k=_key(c['subject'].toString(),c['relation'].toString(),c['object'].toString());
      grouped.putIfAbsent(k,()=> <Map<String,dynamic>>[]).add(c);
    }

    var accepted=0,doubtful=0,conflicts=0,reinforced=0,entities=0;
    final session=ResearchSession11(
      topic:sourceName,
      query:sourceName,
      reason:'apprendimento da corpus locale selezionato dall’utente',
      startedAtIso:iso,
      documents:1,
      sentencesRead:sentenceCount,
      candidates:grouped.length,
      sources:<String>['Corpus locale'],
    );

    var groupIndex=0;
    for(final entry in grouped.entries){
      groupIndex++;
      final xs=entry.value;
      final first=xs.first;
      final subject=first['subject'].toString();
      final relation=first['relation'].toString();
      final object=first['object'].toString();
      final avgQ=xs.map((x)=>(x['quality'] as num?)?.toDouble()??.75).reduce((a,b)=>a+b)/xs.length;
      final conflict=_conflict(brain,subject,relation,object);
      if(conflict)conflicts++;

      final existing=memory.claims[entry.key];
      final claim=existing??ResearchClaim11(
        key:entry.key,
        subject:subject,
        relation:relation,
        object:object,
        confidence:.40,
        conflict:false,
        status:'dubbia',
        lastSeenIso:iso,
      );
      claim.subject=subject;claim.relation=relation;claim.object=object;claim.lastSeenIso=iso;
      claim.conflict=claim.conflict||conflict;
      claim.sourceFamilies.add(family);

      final evidenceToKeep=xs.take(3).toList();
      for(var i=0;i<evidenceToKeep.length;i++){
        final x=evidenceToKeep[i];
        final evId='corpus:${now.microsecondsSinceEpoch}:$groupIndex:$i';
        memory.evidence.add(ResearchEvidence11(
          id:evId,
          subject:subject,
          relation:relation,
          object:object,
          provider:'Corpus locale',
          sourceFamily:family,
          sourceTitle:sourceName,
          sourceUrl:'local://$sourceName',
          excerpt:x['sentence'].toString().length>420?'${x['sentence'].toString().substring(0,420)}…':x['sentence'].toString(),
          trust:(.64+.30*((x['quality'] as num?)?.toDouble()??.75)).clamp(.0,1.0),
          retrievedAtIso:iso,
        ));
        claim.evidenceIds.add(evId);
      }

      final evidenceCount=claim.evidenceCount;
      final familyCount=claim.independentSourceCount;
      final proposed=(.32+.25*avgQ+.035*min(6,max(0,evidenceCount-1))+.09*min(3,max(0,familyCount-1))).clamp(.38,.92).toDouble();
      claim.confidence=max(claim.confidence,proposed);

      final alreadyAccepted=existing!=null&&{'accettata','validata_llm','appresa_corpus'}.contains(existing.status);
      final corroborated=familyCount>=2&&claim.confidence>=.54;
      final accept=!claim.conflict&&(alreadyAccepted||corroborated);

      if(accept){
        final sid=brain.entityIdForLabel06(subject)??brain.ensureSemanticEntity06(subject);
        entities++;
        int? oid;
        if(PlasticLanguageBrain04.lexicalTokens(object).length<=8){
          oid=brain.entityIdForLabel06(object)??brain.ensureSemanticEntity06(object);
          entities++;
        }
        final wasKnown=brain.semanticGraph(limit:100000).any((x)=>_n22(x.from)==_n22(subject)&&_n22(x.relation)==_n22(relation)&&_n22(x.to)==_n22(object)&&x.confidence>=.35);
        claim.status=alreadyAccepted?existing!.status:'appresa_corpus';
        claim.confidence=max(claim.confidence,.58);
        final prior=min(.64,claim.confidence);
        brain.importTeacherFact08(subject:subject,relation:relation,object:object,confidence:prior,source:'corpus:$sourceName');
        if(oid!=null&&sid!=oid){
          world.importTeacherSemanticLink08(sid,oid,.38+.26*prior,confidence:.40+.25*prior);
        }
        if(wasKnown){reinforced++;}else{accepted++;}
        if(session.learnedFacts.length<12)session.learnedFacts.add('$subject — $relation → $object');
      }else{
        claim.status='dubbia';
        doubtful++;
      }
      memory.claims[entry.key]=claim;
      if(groupIndex%120==0)await Future<void>.delayed(Duration.zero);
    }

    brain.discoverConcepts();
    world.think(brain,cycles:12,seedText:sourceName,stopFlux:.006);
    session.integrated=accepted+reinforced;
    session.doubtful=doubtful;
    session.contradictions=conflicts;
    session.status=session.integrated>0?'corpus integrato':'corpus acquisito con ipotesi';
    session.completedAtIso=DateTime.now().toIso8601String();
    memory.sessions.add(session);
    memory.lastStatus='Corpus “$sourceName”: $sentenceCount frasi, ${grouped.length} candidati, $accepted nuove conoscenze, $reinforced rinforzate, $doubtful dubbi, $conflicts conflitti.';
    memory.trim();
    final outcome=CorpusSemanticOutcome22(sentences:sentenceCount,candidates:grouped.length,accepted:accepted,doubtful:doubtful,conflicts:conflicts,reinforced:reinforced,entitiesTouched:entities);
    outcome.cognitiveSummary=cognitive.summary;
    return outcome;
  }
}
