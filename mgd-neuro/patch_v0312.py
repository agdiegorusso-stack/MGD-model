from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()

# 0.31.2: scientific verification searches the subject itself (and an English
# lexical alias when available), not only the noisy full Italian claim string.
old="""      final scientificFirst = goal.diversityVerification031 ||
          _looksScientific031('$topic ${goal.query} ${goal.contextTerms.join(' ')}');
      final requests = <Future<List<WebDocument11>>>[
        if (scientificFirst) safeDocs(_europePmc031(goal.query)),
        if (scientificFirst) safeDocs(_crossref031(goal.query)),
        safeDocs(_wikipedia(topic)),
        safeDocs(_wikidata(topic)),
        safeDocs(_duck(topic)),
        if (!scientificFirst) safeDocs(_crossref031(goal.query)),
      ];
"""
new="""      final scientificFirst = goal.diversityVerification031 ||
          _looksScientific031('$topic ${goal.query} ${goal.contextTerms.join(' ')}');

      final scientificQueries0312=<String>{goal.query.trim()};
      if(goal.diversityVerification031 && goal.verifySubject031!=null){
        final subject=goal.verifySubject031!.trim();
        if(subject.isNotEmpty)scientificQueries0312.add(subject);
        try{
          final aliases=await _wikidataLexicalAliases0312(subject);
          for(final a in aliases.take(2)){
            if(a.trim().isNotEmpty)scientificQueries0312.add(a.trim());
          }
        }catch(_){}
      }
      final preferredQueries0312=scientificQueries0312
          .where((q)=>q.trim().isNotEmpty)
          .toList()
        ..sort((a,b){
          final as=a.split(RegExp(r'\\s+')).length;
          final bs=b.split(RegExp(r'\\s+')).length;
          return as.compareTo(bs);
        });
      final requests = <Future<List<WebDocument11>>>[
        if (scientificFirst)
          for(final q in preferredQueries0312.take(2)) safeDocs(_europePmc031(q)),
        if (scientificFirst)
          for(final q in preferredQueries0312.take(2)) safeDocs(_crossref031(q)),
        safeDocs(_wikipedia(topic)),
        safeDocs(_wikidata(topic)),
        safeDocs(_duck(topic)),
        if (!scientificFirst) safeDocs(_crossref031(goal.query)),
      ];
"""
if old not in s: raise SystemExit('0.31.2 request planner anchor missing')
s=s.replace(old,new,1)

# English scientific prose must produce structured candidates too.
old="""    final rules = <({RegExp re, String relation, double quality})>[
      (re: RegExp(r'^(?:è|e)\s+(?:un|uno|una)\s+(.+)', caseSensitive: false), relation: 'tipo di', quality: 0.95),
"""
new="""    final rules = <({RegExp re, String relation, double quality})>[
      (re: RegExp(r'^(?:è|e)\s+(?:un|uno|una)\s+(.+)', caseSensitive: false), relation: 'tipo di', quality: 0.95),
      (re: RegExp(r'^(?:is|are)\s+(?:a|an)\s+(.+)', caseSensitive: false), relation: 'tipo di', quality: 0.93),
      (re: RegExp(r'^(?:is|are)\s+(?:a\s+)?(?:type|class|category|kind)\s+of\s+(.+)', caseSensitive: false), relation: 'tipo di', quality: 0.92),
      (re: RegExp(r'^(?:is|are)\s+(?:composed|comprised|made)\s+of\s+(.+)', caseSensitive: false), relation: 'composto da', quality: 0.91),
      (re: RegExp(r'^(?:consists|consist)\s+of\s+(.+)', caseSensitive: false), relation: 'composto da', quality: 0.91),
      (re: RegExp(r'^(?:is|are)\s+part\s+of\s+(.+)', caseSensitive: false), relation: 'parte di', quality: 0.90),
      (re: RegExp(r'^(?:belongs|belong)\s+to\s+(.+)', caseSensitive: false), relation: 'appartiene a', quality: 0.89),
      (re: RegExp(r'^(?:has|have|contains|contain)\s+(.+)', caseSensitive: false), relation: 'ha', quality: 0.85),
      (re: RegExp(r'^(?:is|are)\s+used\s+(?:to|for)\s+(.+)', caseSensitive: false), relation: 'serve per', quality: 0.87),
      (re: RegExp(r'^(?:includes|include|comprises|comprise)\s+(.+)', caseSensitive: false), relation: 'comprende', quality: 0.82),
"""
if old not in s: raise SystemExit('0.31.2 extractor rules anchor missing')
s=s.replace(old,new,1)

# Allow English implicit-subject starts.
old="""    } else if (allowImplicitSubject && RegExp(r'^(?:è|e|ha|possiede|serve|consente|permette|usa|utilizza|comprende|appartiene|fa\s+parte|si\s+trova|vive)(?:\s|$)', caseSensitive: false).hasMatch(clean)) {
"""
new="""    } else if (allowImplicitSubject && RegExp(r'^(?:è|e|ha|possiede|serve|consente|permette|usa|utilizza|comprende|appartiene|fa\s+parte|si\s+trova|vive|is|are|has|have|contains|contain|consists|consist|belongs|belong|includes|include|comprises|comprise)(?:\s|$)', caseSensitive: false).hasMatch(clean)) {
"""
if old not in s: raise SystemExit('0.31.2 implicit subject anchor missing')
s=s.replace(old,new,1)

# Lexical aliases are used ONLY to retrieve/recognize the same subject cross-language.
anchor="""  Future<List<WebDocument11>> _europePmc031(String q) async {
"""
helper="""  Future<List<String>> _wikidataLexicalAliases0312(String term) async {
    final search=await _json(Uri.https('www.wikidata.org','/w/api.php',{
      'action':'wbsearchentities',
      'search':term,
      'language':'it',
      'uselang':'it',
      'limit':'2',
      'format':'json',
      'origin':'*',
    }));
    final rows=(search['search'] as List?)??const [];
    final ids=<String>[];
    for(final x in rows){
      if(x is! Map)continue;
      final id=(x['id']??'').toString();
      if(id.isNotEmpty)ids.add(id);
    }
    if(ids.isEmpty)return const <String>[];
    final data=await _json(Uri.https('www.wikidata.org','/w/api.php',{
      'action':'wbgetentities',
      'ids':ids.join('|'),
      'props':'labels|aliases',
      'languages':'it|en',
      'format':'json',
      'origin':'*',
    }));
    final entities=data['entities'];
    if(entities is! Map)return const <String>[];
    final out=<String>{term.trim()};
    for(final raw in entities.values){
      if(raw is! Map)continue;
      final j=Map<String,dynamic>.from(raw);
      final labels=j['labels'];
      if(labels is Map){
        for(final lang in const ['it','en']){
          final v=labels[lang];
          if(v is Map){
            final x=(v['value']??'').toString().trim();
            if(x.length>=2 && x.split(RegExp(r'\\s+')).length<=6)out.add(x);
          }
        }
      }
      final aliases=j['aliases'];
      if(aliases is Map){
        for(final lang in const ['it','en']){
          final xs=aliases[lang];
          if(xs is List){
            for(final v in xs.take(4)){
              if(v is! Map)continue;
              final x=(v['value']??'').toString().trim();
              if(x.length>=2 && x.split(RegExp(r'\\s+')).length<=6)out.add(x);
            }
          }
        }
      }
    }
    return out.toList();
  }

"""
if anchor not in s: raise SystemExit('0.31.2 EuropePMC anchor missing')
if '_wikidataLexicalAliases0312' not in s:
    s=s.replace(anchor,helper+anchor,1)

p.write_text(s)

# Correct visible version so we can tell which APK is actually running.
p=root/'lib'/'main.dart'
s=p.read_text()
s=s.replace('MGD Neuro 0.31.0','MGD Neuro 0.31.2')
s=s.replace('Memorie MGD 0.31','Memorie MGD 0.31.2')
p.write_text(s)

p=root/'pubspec.yaml'
s=p.read_text()
if 'version: 0.31.1+50' not in s: raise SystemExit('0.31.2 pubspec anchor missing')
s=s.replace('version: 0.31.1+50','version: 0.31.2+51',1)
p.write_text(s)

# Regression tests: English scientific text must be extractable and independently corroboratable.
p=root/'test'/'web_knowledge_explorer_v11_test.dart'
s=p.read_text()
insert=r'''

  test('0.31.2 extracts English scientific copular claims', () {
    const doc=WebDocument11(
      provider:'Europe PMC',
      family:'paper:doi:10.1000/nucleotide',
      title:'Nucleotide chemistry',
      url:'https://doi.org/10.1000/nucleotide',
      text:'A nucleotide is a molecule.',
      trust:0.93,
    );
    final xs=WebKnowledgeExplorer11().extractClaimsFromSentence(
      'Nucleotide',
      'Nucleotide is a molecule.',
      doc,
    );
    expect(xs,isNotEmpty);
    expect(xs.first.relation,'tipo di');
    expect(xs.first.object.toLowerCase(),contains('molecule'));
  });

  test('0.31.2 English paper can promote an existing Wikimedia hypothesis', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    final explorer=WebKnowledgeExplorer11();
    const wiki=WebDocument11(
      provider:'Wikipedia IT',family:'wikimedia',title:'Nucleotide',
      url:'https://it.wikipedia.org/wiki/Nucleotide',
      text:'Il nucleotide è un monomero degli acidi nucleici.',trust:0.90,
    );
    const paper=WebDocument11(
      provider:'Europe PMC',family:'paper:doi:10.1000/nuc',
      title:'Nucleotides',url:'https://doi.org/10.1000/nuc',
      text:'Nucleotides are monomers of nucleic acids.',trust:0.93,
    );
    const goal=ResearchGoal11(query:'Nucleotide monomero acidi nucleici',topic:'Nucleotide',reason:'test',value:1);
    explorer.integrate(
      brain,world,memory,
      ResearchDraft11(
        goal:goal,documents:[wiki],
        claims:[ExtractedClaim11(
          subject:'Nucleotide',relation:'tipo di',object:'monomero degli acidi nucleici',
          sentence:'Il nucleotide è un monomero degli acidi nucleici.',source:wiki,quality:0.95)],
        passages:const [],sentencesRead:1),
    );
    expect(memory.claims.values.single.status,'ipotesi_mgd');
    expect(
      WebKnowledgeExplorer11.verificationSentenceSupportsForTest0311(
        'Nucleotides are monomers of nucleic acids.',
        subject:'Nucleotide',
        relation:'tipo di',
        object:'monomero degli acidi nucleici',
      ),
      isTrue,
    );
    explorer.integrate(
      brain,world,memory,
      ResearchDraft11(
        goal:goal,documents:[paper],
        claims:[ExtractedClaim11(
          subject:'Nucleotide',relation:'tipo di',object:'monomero degli acidi nucleici',
          sentence:'Nucleotides are monomers of nucleic acids.',source:paper,quality:0.80)],
        passages:const [],sentencesRead:1),
    );
    final claim=memory.claims.values.single;
    expect(claim.status,'accettata');
    expect(claim.independentSourceCount,2);
  });
'''
idx=s.rfind('\n}')
if idx<0: raise SystemExit('0.31.2 test closing brace missing')
if '0.31.2 extracts English scientific copular claims' not in s:
    s=s[:idx]+insert+s[idx:]
p.write_text(s)

print('MGD Neuro 0.31.2 cross-language source verification patch applied')
