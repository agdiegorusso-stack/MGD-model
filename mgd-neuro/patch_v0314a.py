from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()

old="""    if (weak.isNotEmpty) {
      final c = weak.first;
      final q = '${c.subject} ${c.relation} ${c.object}';
      if (force || memory.canResearch(q, now: now, repeatAfter: const Duration(hours: 8))) {
        return ResearchGoal11(
          query: q,
          topic: c.subject,
          reason: c.sourceFamilies.length < 2
              ? 'ricerca deliberata di una fonte indipendente'
              : 'verifica di una conoscenza ancora debole',
          value: 0.90,
          avoidFamilies031: Set<String>.unmodifiable(c.sourceFamilies),
          diversityVerification031: c.sourceFamilies.length < 2,
          verifySubject031: c.subject,
          verifyRelation031: c.relation,
          verifyObject031: c.object,
        );
      }
    }
"""

new="""    // 0.31.4: do not give up on verification just because the highest-priority
    // claim is still inside its cooldown. Walk the ranked queue and verify the
    // next useful claim instead of falling back to generic topic exploration.
    for (final c in weak) {
      final q = '${c.subject} ${c.relation} ${c.object}';
      if (!force && !memory.canResearch(q, now: now, repeatAfter: const Duration(hours: 8))) {
        continue;
      }
      return ResearchGoal11(
        query: q,
        topic: c.subject,
        reason: c.sourceFamilies.length < 2
            ? 'ricerca deliberata di una fonte indipendente'
            : 'verifica di una conoscenza ancora debole',
        value: 0.90,
        avoidFamilies031: Set<String>.unmodifiable(c.sourceFamilies),
        diversityVerification031: c.sourceFamilies.length < 2,
        verifySubject031: c.subject,
        verifyRelation031: c.relation,
        verifyObject031: c.object,
      );
    }
"""
if old not in s:
    raise SystemExit('0.31.4 selector anchor missing')
s=s.replace(old,new,1)
p.write_text(s)
print('MGD Neuro 0.31.4 verification queue selector applied')
