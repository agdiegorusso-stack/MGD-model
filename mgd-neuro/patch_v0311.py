from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()

# Keep the exact weak claim inside a diversity-verification goal.
old="""  final Set<String> avoidFamilies031;
  final bool diversityVerification031;

  const ResearchGoal11({
"""
new="""  final Set<String> avoidFamilies031;
  final bool diversityVerification031;
  final String? verifySubject031;
  final String? verifyRelation031;
  final String? verifyObject031;

  const ResearchGoal11({
"""
if old not in s: raise SystemExit('goal fields anchor missing')
s=s.replace(old,new,1)

old="""    this.contextTerms = const <String>[],
    this.avoidFamilies031 = const <String>{},
    this.diversityVerification031 = false,
  });
"""
new="""    this.contextTerms = const <String>[],
    this.avoidFamilies031 = const <String>{},
    this.diversityVerification031 = false,
    this.verifySubject031,
    this.verifyRelation031,
    this.verifyObject031,
  });
"""
if old not in s: raise SystemExit('goal ctor anchor missing')
s=s.replace(old,new,1)

old="""          avoidFamilies031: Set<String>.unmodifiable(c.sourceFamilies),
          diversityVerification031: c.sourceFamilies.length < 2,
        );
"""
new="""          avoidFamilies031: Set<String>.unmodifiable(c.sourceFamilies),
          diversityVerification031: c.sourceFamilies.length < 2,
          verifySubject031: c.subject,
          verifyRelation031: c.relation,
          verifyObject031: c.object,
        );
"""
if old not in s: raise SystemExit('goal weak-claim anchor missing')
s=s.replace(old,new,1)

# Align independent-source wording back onto the exact weak claim only when
# the new source sentence itself contains subject, object and relation evidence.
old="""      try {
        claims.addAll(await _wikidataClaims(topic));
      } catch (_) {
        // A throttled provider must not invalidate evidence already collected.
      }

      return ResearchDraft11(goal: goal, documents: docs, claims: _dedupeClaims(claims), passages: passages.take(40).toList(), sentencesRead: sentenceCount);
"""
new="""      try {
        claims.addAll(await _wikidataClaims(topic));
      } catch (_) {
        // A throttled provider must not invalidate evidence already collected.
      }

      if (goal.diversityVerification031 &&
          goal.verifySubject031 != null &&
          goal.verifyRelation031 != null &&
          goal.verifyObject031 != null) {
        final targetSubject=goal.verifySubject031!;
        final targetRelation=goal.verifyRelation031!;
        final targetObject=goal.verifyObject031!;
        for(final doc in docs.take(10)) {
          if(goal.avoidFamilies031.contains(doc.family)) continue;
          for(final sentence in _sentences(doc.text).take(24)) {
            if(!_verificationSentenceSupports031(
              sentence,
              subject:targetSubject,
              relation:targetRelation,
              object:targetObject,
            )) continue;
            claims.add(ExtractedClaim11(
              subject:targetSubject,
              relation:targetRelation,
              object:targetObject,
              sentence:sentence,
              source:doc,
              quality:0.80,
            ));
          }
        }
      }

      return ResearchDraft11(goal: goal, documents: docs, claims: _dedupeClaims(claims), passages: passages.take(40).toList(), sentencesRead: sentenceCount);
"""
if old not in s: raise SystemExit('research return anchor missing')
s=s.replace(old,new,1)

old="""  static String _claimKey028(ExtractedClaim11 c) =>
      '${_key(c.subject,c.relation,c.object)}|${_n11(c.subjectSenseKey ?? '')}';

  static List<ExtractedClaim11> _dedupeClaims(List<ExtractedClaim11> input) {
    final seen = <String>{};
    return input.where((c) => seen.add(_claimKey028(c))).toList();
  }

  static bool _functionalConflict"""
new="""  static String _claimKey028(ExtractedClaim11 c) =>
      '${_key(c.subject,c.relation,c.object)}|${_n11(c.subjectSenseKey ?? '')}';

  static String _claimEvidenceKey0311(ExtractedClaim11 c) {
    final sourceKey=c.source.url.trim().isNotEmpty
        ? c.source.url.trim().toLowerCase()
        : '${_n11(c.source.provider)}|${_n11(c.source.title)}|${c.source.text.hashCode}';
    return '${_claimKey028(c)}|$sourceKey';
  }

  // Dedupe repeated extraction inside ONE document, never across documents.
  // Otherwise two independent sources saying the same thing collapse to one
  // candidate before integrate() ever gets a chance to count two families.
  static List<ExtractedClaim11> _dedupeClaims(List<ExtractedClaim11> input) {
    final seen = <String>{};
    return input.where((c) => seen.add(_claimEvidenceKey0311(c))).toList();
  }

  static List<ExtractedClaim11> dedupeClaimsForTest0311(List<ExtractedClaim11> input) =>
      _dedupeClaims(input);

  static String _root0311(String raw) {
    var x=_n11(raw).replaceAll(RegExp(r'[^a-z0-9à-ÿ]+',caseSensitive:false),'').trim();
    if(x.length>5 && RegExp(r'[aeiouàèéìòù]$',caseSensitive:false).hasMatch(x)){
      x=x.substring(0,x.length-1);
    }
    return x;
  }

  static Set<String> _contentRoots0311(String text) {
    const stop=<String>{
      'il','lo','la','i','gli','le','un','uno','una','di','del','della','dei','delle',
      'a','al','alla','in','nel','nella','con','per','da','the','a','an','of','to','in',
      'and','or','is','are','was','were','be','being','as'
    };
    final out=<String>{};
    for(final t in _n11(text).split(RegExp(r'\\s+'))){
      if(t.length<3 || stop.contains(t))continue;
      final r=_root0311(t);
      if(r.length>=3)out.add(r);
    }
    return out;
  }

  static bool _mentions0311(String sentence,String phrase,{double ratio=0.60}) {
    final need=_contentRoots0311(phrase);
    if(need.isEmpty)return false;
    final have=_contentRoots0311(sentence);
    var hits=0;
    for(final n in need){
      if(have.any((h)=>h==n || h.startsWith(n) || n.startsWith(h)))hits++;
    }
    return hits/max(1,need.length)>=ratio;
  }

  static bool _relationCue0311(String sentence,String relation) {
    final s=' ${_n11(sentence)} ';
    switch(_n11(relation)){
      case 'tipo di':
        return RegExp(r'\\b(?:è|sono|is|are|type|class|category|classified)\\b',caseSensitive:false).hasMatch(s);
      case 'parte di':
        return s.contains(' parte di ') || s.contains(' part of ') || s.contains(' component of ') || s.contains(' componente di ');
      case 'ha':
      case 'ha parte':
        return RegExp(r'\\b(?:ha|hanno|has|have|contains|contiene|comprende)\\b',caseSensitive:false).hasMatch(s);
      case 'serve per':
        return s.contains(' serve per ') || s.contains(' used for ') || s.contains(' function ') || s.contains(' funzione ');
      default:
        final roots=_contentRoots0311(relation);
        if(roots.isEmpty)return true;
        final have=_contentRoots0311(sentence);
        return roots.any((r)=>have.any((h)=>h==r || h.startsWith(r) || r.startsWith(h)));
    }
  }

  static bool _verificationSentenceSupports031(
    String sentence,{
    required String subject,
    required String relation,
    required String object,
  }) {
    return _mentions0311(sentence,subject,ratio:0.50) &&
        _mentions0311(sentence,object,ratio:0.60) &&
        _relationCue0311(sentence,relation);
  }

  static bool verificationSentenceSupportsForTest0311(
    String sentence,{
    required String subject,
    required String relation,
    required String object,
  }) => _verificationSentenceSupports031(
    sentence,subject:subject,relation:relation,object:object);

  static bool _functionalConflict"""
if old not in s: raise SystemExit('dedupe anchor missing')
s=s.replace(old,new,1)

p.write_text(s)

# UI: distinguish document diversity from evidence diversity.
p=root/'lib'/'main.dart'
s=p.read_text()
s=s.replace("_Metric04('Famiglie fonte', '${research.evidence.map((e)=>e.sourceFamily).toSet().length}'),",
            "_Metric04('Famiglie con evidenza', '${research.evidence.map((e)=>e.sourceFamily).toSet().length}'),",1)
p.write_text(s)

# Version.
p=root/'pubspec.yaml'
s=p.read_text()
if 'version: 0.31.0+49' not in s: raise SystemExit('0.31 version anchor missing')
s=s.replace('version: 0.31.0+49','version: 0.31.1+50',1)
p.write_text(s)

# Regression tests for the exact zero-consolidation bug.
p=root/'test'/'web_knowledge_explorer_v11_test.dart'
s=p.read_text()
insert=r'''

  test('0.31.1 preserves same claim from independent documents before integration', () {
    const a=WebDocument11(
      provider:'Wikipedia IT',family:'wikimedia',title:'Nucleotide',
      url:'https://it.wikipedia.org/wiki/Nucleotide',
      text:'Il nucleotide è una molecola.',trust:0.90,
    );
    const b=WebDocument11(
      provider:'Europe PMC',family:'paper:doi:10.1000/test',title:'Nucleotide chemistry',
      url:'https://doi.org/10.1000/test',
      text:'A nucleotide is a molecule.',trust:0.93,
    );
    const ca=ExtractedClaim11(
      subject:'Nucleotide',relation:'tipo di',object:'molecola',
      sentence:'Il nucleotide è una molecola.',source:a,quality:0.95,
    );
    const cb=ExtractedClaim11(
      subject:'Nucleotide',relation:'tipo di',object:'molecola',
      sentence:'A nucleotide is a molecule.',source:b,quality:0.95,
    );
    final kept=WebKnowledgeExplorer11.dedupeClaimsForTest0311([ca,cb]);
    expect(kept.length,2);

    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    const goal=ResearchGoal11(query:'Nucleotide tipo di molecola',topic:'Nucleotide',reason:'test',value:1);
    final out=WebKnowledgeExplorer11().integrate(
      brain,world,memory,
      ResearchDraft11(goal:goal,documents:[a,b],claims:kept,passages:const [],sentencesRead:2),
    );
    expect(out.integrated,1);
    expect(memory.claims.values.single.status,'accettata');
    expect(memory.claims.values.single.independentSourceCount,2);
  });

  test('0.31.1 targeted verification accepts lexical scientific paraphrase', () {
    expect(
      WebKnowledgeExplorer11.verificationSentenceSupportsForTest0311(
        'A nucleotide is an organic molecule composed of a nucleobase, sugar and phosphate.',
        subject:'Nucleotide',
        relation:'tipo di',
        object:'molecola',
      ),
      isTrue,
    );
    expect(
      WebKnowledgeExplorer11.verificationSentenceSupportsForTest0311(
        'This paper discusses an unrelated clinical outcome.',
        subject:'Nucleotide',
        relation:'tipo di',
        object:'molecola',
      ),
      isFalse,
    );
  });
'''
idx=s.rfind('\n}')
if idx<0: raise SystemExit('test closing brace missing')
if '0.31.1 preserves same claim from independent documents before integration' not in s:
    s=s[:idx]+insert+s[idx:]
p.write_text(s)

print('MGD Neuro 0.31.1 corroboration-preservation patch applied')
