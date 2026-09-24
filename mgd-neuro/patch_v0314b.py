from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()

old="""  ResearchOutcome11 integrate(PlasticLanguageBrain04 brain, MgdWorld06 world, ResearchMemory11 memory, ResearchDraft11 draft) {
    final now = DateTime.now();
    final iso = now.toIso8601String();
    final session = ResearchSession11(topic: draft.goal.topic, query: draft.goal.query, reason: draft.goal.reason, startedAtIso: memory.lastResearchAtIso ?? iso);
    final sourceKeys = <String>{
      ...draft.documents.map((d) => d.url.isEmpty ? '${d.provider}|${d.title}' : d.url),
      ...draft.claims.map((c) => c.source.url.isEmpty ? '${c.source.provider}|${c.source.title}' : c.source.url),
    };
"""

new="""  ResearchOutcome11 integrate(PlasticLanguageBrain04 brain, MgdWorld06 world, ResearchMemory11 memory, ResearchDraft11 draft) {
    final now = DateTime.now();
    final iso = now.toIso8601String();

    // 0.31.4: every fetched independent document is also allowed to corroborate
    // near-gate hypotheses already in memory. Previously 20+ paper families
    // could be read during a generic topic search yet contribute zero evidence.
    final integratedClaims0314=<ExtractedClaim11>[
      ...draft.claims,
      ..._corroborationSweep0314(memory,draft),
    ];

    final session = ResearchSession11(topic: draft.goal.topic, query: draft.goal.query, reason: draft.goal.reason, startedAtIso: memory.lastResearchAtIso ?? iso);
    final sourceKeys = <String>{
      ...draft.documents.map((d) => d.url.isEmpty ? '${d.provider}|${d.title}' : d.url),
      ...integratedClaims0314.map((c) => c.source.url.isEmpty ? '${c.source.provider}|${c.source.title}' : c.source.url),
    };
"""
if old not in s:
    raise SystemExit('0314 integrate header anchor missing')
s=s.replace(old,new,1)

s=s.replace("""      ...draft.claims.map((c)=>c.source.provider),""","""      ...integratedClaims0314.map((c)=>c.source.provider),""",1)
s=s.replace("""      ...draft.claims.map((c)=>c.source.family),""","""      ...integratedClaims0314.map((c)=>c.source.family),""",1)
s=s.replace("""    session.candidates = draft.claims.length;""","""    session.candidates = integratedClaims0314.length;""",1)
s=s.replace("""    for (final c in draft.claims) {
      grouped.putIfAbsent(_claimSemanticKey0313(c), () => <ExtractedClaim11>[]).add(c);
    }
""","""    for (final c in integratedClaims0314) {
      grouped.putIfAbsent(_claimSemanticKey0313(c), () => <ExtractedClaim11>[]).add(c);
    }
""",1)

old="""    memory.lastStatus = 'Studio “${draft.goal.topic}”: ${session.documents} documenti, ${session.providers} provider, ${session.families} famiglie, ${draft.sentencesRead} frasi, ${draft.claims.length} candidati, $accepted consolidati, $hypotheses ipotesi MGD, $quarantined quarantena, $conflicts conflitti.';
"""
new="""    memory.lastStatus = 'Studio “${draft.goal.topic}”: ${session.documents} documenti, ${session.providers} provider, ${session.families} famiglie, ${draft.sentencesRead} frasi, ${integratedClaims0314.length} candidati, $accepted consolidati, $hypotheses ipotesi MGD, $quarantined quarantena, $conflicts conflitti.';
"""
if old not in s:
    raise SystemExit('0314 lastStatus anchor missing')
s=s.replace(old,new,1)

anchor="""  int reprocessDuringSleep(PlasticLanguageBrain04 brain, MgdWorld06 world, ResearchMemory11 memory, {int limit = 16}) {
"""
helper="""  List<ExtractedClaim11> _corroborationSweep0314(
    ResearchMemory11 memory,
    ResearchDraft11 draft,
  ) {
    if(draft.documents.isEmpty || memory.claims.isEmpty)return const <ExtractedClaim11>[];

    final topic=_n11(draft.goal.topic);
    final targets=memory.claims.values.where((c){
      if(c.status!='ipotesi_mgd' || c.conflict || c.sourceFamilies.length>=2)return false;
      if(!_verificationEligible0313(c))return false;
      final cs=_n11(c.subject);
      return cs==topic || _rootCompatible0311(_semanticStem0313(cs),_semanticStem0313(topic));
    }).toList()
      ..sort((a,b)=>_verificationPriority0313(b).compareTo(_verificationPriority0313(a)));

    if(targets.isEmpty)return const <ExtractedClaim11>[];

    final out=<ExtractedClaim11>[];
    final seen=<String>{};
    for(final claim in targets.take(8)){
      final aliases=<String>{claim.subject,draft.goal.topic};
      for(final doc in draft.documents.take(24)){
        if(claim.sourceFamilies.contains(doc.family))continue;
        var supported=false;
        for(final sentence in _sentences(doc.text).take(20)){
          if(!_verificationEvidenceSupports0313(
            sentence,
            documentTitle:doc.title,
            subject:claim.subject,
            subjectAliases:aliases,
            relation:claim.relation,
            object:claim.object,
          ))continue;
          final key='${claim.key}|${doc.family}|${doc.url}';
          if(!seen.add(key))break;
          out.add(ExtractedClaim11(
            subject:claim.subject,
            relation:claim.relation,
            object:claim.object,
            sentence:sentence,
            source:doc,
            quality:0.82,
            subjectSenseKey:claim.subjectSenseKey,
            subjectSenseLabel:claim.subjectSenseLabel,
            subjectSenseGloss:claim.subjectSenseGloss,
          ));
          supported=true;
          break;
        }
        if(supported && out.where((x)=>_n11(x.subject)==_n11(claim.subject) && _n11(x.relation)==_n11(claim.relation) && _objectsEquivalent0313(x.object,claim.object)).length>=3){
          break;
        }
      }
    }
    return _dedupeClaims(out);
  }

"""
if anchor not in s:
    raise SystemExit('0314 sleep anchor missing')
s=s.replace(anchor,helper+anchor,1)

p.write_text(s)
print('MGD Neuro 0.31.4 cross-document corroboration sweep applied')
