from pathlib import Path
import sys
import re

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib/web_knowledge_explorer_v11.dart'
s=p.read_text()

def replace(old,new):
    global s
    if old not in s:
        raise SystemExit('Missing exact source anchor: '+old[:160])
    s=s.replace(old,new,1)

replace('  final List<String> learnedFacts;','  final List<String> learnedFacts;\n  final Map<String,dynamic> audit315 = <String,dynamic>{};')
replace("        'learnedFacts': learnedFacts,","        'learnedFacts': learnedFacts,\n        'audit315': audit315,")
replace("        learnedFacts: ((j['learnedFacts'] as List?) ?? const []).map((e) => e.toString()).toList(),\n      );", "        learnedFacts: ((j['learnedFacts'] as List?) ?? const []).map((e) => e.toString()).toList(),\n      )..audit315.addAll(Map<String,dynamic>.from((j['audit315'] as Map?) ?? const {}));")
replace('  void trim() {', '''  void trim() {
    // Bound the new detailed audit, not the knowledge/evidence archives.
    for(final session in sessions.take(max(0,sessions.length-8))){
      if(session.audit315.isNotEmpty)session.audit315.clear();
    }''')

replace('''    final integratedClaims0314=<ExtractedClaim11>[
      ...draft.claims,
      ..._corroborationSweep0314(memory,draft),
    ];''','''    final verification315=<Map<String,dynamic>>[];
    final decisions315=<Map<String,dynamic>>[];
    final integratedClaims0314=<ExtractedClaim11>[
      ...draft.claims,
      ..._corroborationSweep0314(memory,draft,trace315:verification315),
    ];''')
replace('    session.sources.addAll(providerKeys);','''    session.sources.addAll(providerKeys);
    String docKey315(WebDocument11 d)=>d.url.isEmpty?'${d.provider}|${d.title}':d.url;
    final documents315=<String,Map<String,dynamic>>{};
    final sentences315=<Map<String,dynamic>>[];
    for(var i=0;i<draft.documents.length;i++){
      final d=draft.documents[i];
      final key=docKey315(d);
      final textLimit=min(30000,d.text.length);
      documents315[key]={
        'title':d.title,'provider':d.provider,'family':d.family,'sourceUrl':d.url,
        'text':d.text.substring(0,textLimit),'textTruncated':textLimit<d.text.length,
        'estrazione principale prevista':i<10,
        'nota':i<10?'Nei primi 10 documenti: fino a 24 frasi per estrazione.':'Fuori dal limite dei primi 10 documenti per estrazione principale.',
        'osservazioni candidate':integratedClaims0314.where((c)=>docKey315(c.source)==key).length,
      };
      if(i<10){
        for(final sentence in _sentences(d.text).take(24)){
          sentences315.add({'text':sentence,'provider':d.provider,'family':d.family,'sourceTitle':d.title,'sourceUrl':d.url,
            'Candidati associati':integratedClaims0314.where((c)=>docKey315(c.source)==key && c.sentence==sentence).map((c)=>candidateRecord315(c)).toList()});
        }
      }
    }
    // Structured Wikidata property sources may have no prose document.
    for(final c in integratedClaims0314){
      final d=c.source;
      documents315.putIfAbsent(docKey315(d),()=>{
        'title':d.title,'provider':d.provider,'family':d.family,'sourceUrl':d.url,
        'text':d.text.substring(0,min(30000,d.text.length)),
        'textTruncated':d.text.length>30000,
        'nota':'Sorgente di un candidato strutturato; non compresa nella lettura della prosa.',
      });
    }
    session.audit315.addAll({
      'version':'0.31.5',
      'documents':documents315.values.toList(),
      'sentences':sentences315,
      'candidates':integratedClaims0314.map(candidateRecord315).toList(),
      'decisions':decisions315,
      'verification':verification315,
      'limiti':{'documenti estrazione':10,'frasi per documento':24,'ipotesi verifica aggiuntiva':8,'documenti verifica aggiuntiva':24,'frasi verifica aggiuntiva':20},
      'avvertenza':'Gli esiti sono decisioni euristiche del software. Famiglie diverse non garantiscono indipendenza scientifica. La traccia verifica riguarda il confronto aggiuntivo, non le chiamate HTTP.',
    });''')
replace('      final combinedFamilies = <String>{...?previous?.sourceFamilies, ...currentFamilies};','''      final statusBefore315=previous?.status;
      final combinedFamilies = <String>{...?previous?.sourceFamilies, ...currentFamilies};''')
replace('      memory.claims[storageKey] = claim;','''      memory.claims[storageKey] = claim;
      decisions315.add({
        'claimKey':storageKey,'subject':claim.subject,'relation':claim.relation,'object':claim.object,
        'status':claim.status,'statusBefore':statusBefore315,
        'nuovo consolidamento':claim.status=='accettata' && statusBefore315!='accettata',
        'conflict':claim.conflict,'suspicious':suspicious,'confidence':claim.confidence,
        'sourceFamilies':claim.sourceFamilies.toList(),'sourceProviders':claim.sourceProviders.toList(),
        'evidenceIds':claim.evidenceIds.toList(),'motivi':inspectionGates315(claim),
      });''')
replace('    session.integrated = accepted;','''    // Display final recorded outcomes, including persistent conflict flags.
    accepted=decisions315.where((d)=>d['status']=='accettata').length;
    hypotheses=decisions315.where((d)=>d['status']=='ipotesi_mgd').length;
    quarantined=decisions315.where((d)=>d['status']=='quarantena').length;
    conflicts=decisions315.where((d)=>d['conflict']==true).length;
    session.integrated = accepted;''')
replace('''  List<ExtractedClaim11> _corroborationSweep0314(
    ResearchMemory11 memory,
    ResearchDraft11 draft,
  ) {''','''  List<ExtractedClaim11> _corroborationSweep0314(
    ResearchMemory11 memory,
    ResearchDraft11 draft, {
    List<Map<String,dynamic>>? trace315,
  }) {''')
replace('''    for(final claim in targets.take(8)){
      final aliases=<String>{claim.subject,draft.goal.topic};
      for(final doc in draft.documents.take(24)){
        if(claim.sourceFamilies.contains(doc.family))continue;
        var supported=false;
        for(final sentence in _sentences(doc.text).take(20)){''','''    for(final claim in targets.skip(8)){
      trace315?.add({'claimKey':claim.key,'subject':claim.subject,'relation':claim.relation,'object':claim.object,
        'esito':'Non esaminata: fuori dal limite di 8 ipotesi per ricerca.'});
    }
    for(final claim in targets.take(8)){
      final aliases=<String>{claim.subject,draft.goal.topic};
      var documentsExamined315=0;
      for(final doc in draft.documents.take(24)){
        documentsExamined315++;
        final audit=<String,dynamic>{'claimKey':claim.key,'subject':claim.subject,'relation':claim.relation,'object':claim.object,
          'sourceTitle':doc.title,'sourceUrl':doc.url,'provider':doc.provider,'family':doc.family,
          'metodo':'Confronto aggiuntivo lessicale 0.31.4'};
        trace315?.add(audit);
        if(claim.sourceFamilies.contains(doc.family)){
          audit['esito']='Saltata: famiglia già presente nella proposizione.';
          continue;
        }
        var supported=false;
        final checked=<Map<String,dynamic>>[];
        audit['Frasi confrontate']=checked;
        for(final sentence in _sentences(doc.text).take(20)){
          checked.add(verificationDiagnostics315(sentence,documentTitle:doc.title,
            subject:claim.subject,subjectAliases:aliases,relation:claim.relation,object:claim.object));''')
replace('''        if(supported && out.where((x)=>_n11(x.subject)==_n11(claim.subject) && _n11(x.relation)==_n11(claim.relation) && _objectsEquivalent0313(x.object,claim.object)).length>=3){
          break;
        }
      }
    }
    return _dedupeClaims(out);''','''        audit['esito']=supported?'Compatibilità lessicale rilevata; proposta come evidenza.':'Nessuna frase supera i tre controlli lessicali.';
        if(supported && out.where((x)=>_n11(x.subject)==_n11(claim.subject) && _n11(x.relation)==_n11(claim.relation) && _objectsEquivalent0313(x.object,claim.object)).length>=3){
          break;
        }
      }
      if(documentsExamined315<draft.documents.length){
        trace315?.add({'claimKey':claim.key,'subject':claim.subject,'relation':claim.relation,'object':claim.object,
          'esito':'Documenti ulteriori non esaminati: limite o obiettivo di 3 supporti raggiunto.',
          'documenti non esaminati':draft.documents.length-documentsExamined315});
      }
    }
    return _dedupeClaims(out);''')
anchor='  static bool _suspiciousKnowledge12(String subject, String relation, String object) {'
helper='''  static Map<String,dynamic> candidateRecord315(ExtractedClaim11 c)=>{
    'subject':c.subject,'relation':c.relation,'object':c.object,
    'text':c.sentence,'provider':c.source.provider,'family':c.source.family,
    'sourceTitle':c.source.title,'sourceUrl':c.source.url,'quality':c.quality,
    'subjectSenseKey':c.subjectSenseKey,
  };

  static Map<String,dynamic> inspectionGates315(ResearchClaim11 c)=>{
    'stato registrato':c.status,
    'famiglie assegnate':c.sourceFamilies.length,
    'minimo famiglie richiesto':2,
    'famiglie mancanti':max(0,2-c.sourceFamilies.length),
    'punteggio':c.confidence,'soglia punteggio':0.52,
    'soglia punteggio raggiunta':c.confidence>=0.52,
    'conflitto memorizzato':c.conflict,
    'filtro sospetto attuale':_suspiciousKnowledge12(c.subject,c.relation,c.object),
    'idonea alla verifica automatica':_verificationEligible0313(c),
    'priorità euristica attuale':_verificationPriority0313(c),
    'avvertenza':'Verifiche calcolate sullo stato attuale. Per il motivo storico esatto consultare gli esiti registrati dalla 0.31.5.',
  };

  static Map<String,dynamic> verificationDiagnostics315(String sentence,{
    required String documentTitle,required String subject,required Set<String> subjectAliases,
    required String relation,required String object,
  }){
    final subjectMatch=_mentions0311(sentence,subject,ratio:0.50) ||
      subjectAliases.any((a)=>_mentions0311(sentence,a,ratio:0.50)) ||
      _mentions0311(documentTitle,subject,ratio:0.50) ||
      subjectAliases.any((a)=>_mentions0311(documentTitle,a,ratio:0.50));
    final objectMatch=_mentions0311(sentence,object,ratio:0.60);
    final relationMatch=_relationCue0311(sentence,relation);
    return {'text':sentence,'soggetto o titolo compatibile':subjectMatch,
      'oggetto compatibile':objectMatch,'indizio di relazione':relationMatch,
      'test lessicale superato':subjectMatch && objectMatch && relationMatch,
      'nota':'Questi sono controlli lessicali, non una prova di implicazione logica o di correttezza scientifica.'};
  }

'''
replace(anchor,helper+anchor)
p.write_text(s)

p=root/'lib/main.dart'
s=p.read_text()
replace("import 'mgd_state_store_v026.dart';","import 'mgd_state_store_v026.dart';\nimport 'knowledge_inspector_v0315.dart';")
s=s.replace('MGD Neuro 0.31.4','MGD Neuro 0.31.5').replace('Memorie MGD 0.31.4','Memorie MGD 0.31.5')
replace('                child: pages[_tab],','''                child: InspectorScope315(
                  inspector:MemoryInspector315(brain:_brain,world:_world,research:_researchMemory,language:_language20),
                  child:pages[_tab],
                ),''')
start=s.index('class _Metric04 extends StatelessWidget {')
end=s.index('class _Meter04 extends StatelessWidget {',start)
s=s[:start]+'''class _Metric04 extends StatelessWidget {
  final String label,value;
  final bool session;
  const _Metric04(this.label,this.value,{this.session=false});
  @override Widget build(BuildContext context)=>InspectMetric315(label,value,session:session);
}

'''+s[end:]
start=s.index("                  Text('Ultimo studio:")
end=s.index("                  if (research.lastSession!.sources",start)
section=s[start:end]
section=re.sub(r"(_Metric04\([^\n]+)(\),)",r"\1, session:true\2",section)
s=s[:start]+section+s[end:]
replace("        Text('Mente', style: Theme.of(context).textTheme.titleLarge),",'''        Text('Mente', style: Theme.of(context).textTheme.titleLarge),
        OutlinedButton.icon(
          onPressed:()=>InspectorScope315.maybeOf(context)?.openCatalog(context),
          icon:const Icon(Icons.search),label:const Text('Esplora tutta la memoria'),
        ),
        const Text('Tocca qualsiasi contatore per vedere gli elementi e le fonti.'),''')
replace("        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n          Text('Memorie MGD 0.31.5'", "        Card(child:InkWell(onTap:()=>InspectorScope315.maybeOf(context)?.openCatalog(context),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[\n          Text('Memorie MGD 0.31.5'")
start=s.index("          Text('Memorie MGD 0.31.5'")
end=s.index('        const SizedBox(height: 12),',start)
s=s[:start]+s[start:end].replace('        ]))),','        ])))),',1)+s[end:]
replace("                          title: Text('${c.subject} — ${c.relation} → ${c.object}'),", "                          onTap:()=>InspectorScope315.maybeOf(context)?.openClaim(context,c.key),\n                          title: Text('${c.subject} — ${c.relation} → ${c.object}'),")
replace("                  Text(research.lastStatus),", "                  Text(research.lastStatus),") if '                  Text(research.lastStatus),' in s else None
# A visible entry to the complete session, instead of a six-line truncated preview.
replace("                  Text('Ultimo studio: ${research.lastSession!.topic}', style: Theme.of(context).textTheme.titleSmall),", "                  Text('Ultimo studio: ${research.lastSession!.topic}', style: Theme.of(context).textTheme.titleSmall),\n                  TextButton.icon(onPressed:()=>InspectorScope315.maybeOf(context)?.openMetric(context,'Documenti',session:true),icon:const Icon(Icons.open_in_new),label:const Text('Apri documenti ed esiti dello studio')),")
s=s.replace('Cerca su Wikipedia IT, Wikidata e DuckDuckGo; le informazioni web entrano solo come prior deboli con provenienza.', 'Interroga Wikipedia, Wikidata, DuckDuckGo, Europe PMC e Crossref. Il consolidamento richiede supporti riconosciuti per la stessa proposizione; apri i contatori per controllarli.')
p.write_text(s)

p=root/'pubspec.yaml'
s=p.read_text()
replace('version: 0.31.4+53','version: 0.31.5+54')
replace('  archive: ^4.3.0','  archive: ^4.3.0\n  url_launcher: ^6.3.2')
p.write_text(s)
print('MGD 0.31.5: read-only navigation and persistent research audit applied')
