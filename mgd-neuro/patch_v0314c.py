from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')

p=root/'lib'/'main.dart'
s=p.read_text()
s=s.replace('MGD Neuro 0.31.3','MGD Neuro 0.31.4')
s=s.replace('Memorie MGD 0.31.3','Memorie MGD 0.31.4')
p.write_text(s)

p=root/'pubspec.yaml'
s=p.read_text()
if 'version: 0.31.3+52' not in s:
    raise SystemExit('0314 pubspec anchor missing')
s=s.replace('version: 0.31.3+52','version: 0.31.4+53',1)
p.write_text(s)

p=root/'test'/'web_knowledge_explorer_v11_test.dart'
s=p.read_text()
insert=r'''

  test('0.31.4 generic topic research can consolidate an existing weak claim from fetched papers', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    final now=DateTime.now().toIso8601String();

    memory.claims['legacy']=ResearchClaim11(
      key:'legacy',
      subject:'Nucleotide',
      relation:'tipo di',
      object:'monomero degli acidi nucleici',
      confidence:0.64,
      conflict:false,
      status:'ipotesi_mgd',
      lastSeenIso:now,
      evidenceIds:<String>{'old1','old2','old3','old4'},
      sourceFamilies:<String>{'wikimedia'},
      sourceProviders:<String>{'Wikipedia IT'},
    );

    const paper=WebDocument11(
      provider:'Europe PMC',
      family:'paper:doi:10.1234/nuc',
      title:'Nucleotides and nucleic acids',
      url:'https://doi.org/10.1234/nuc',
      text:'Nucleotides are monomers of nucleic acids. They are essential building blocks of DNA and RNA.',
      trust:0.93,
    );

    const goal=ResearchGoal11(
      query:'Nucleotide definizione caratteristiche',
      topic:'Nucleotide',
      reason:'argomento rilevante ma poco strutturato nel grafo',
      value:1,
    );

    final out=WebKnowledgeExplorer11().integrate(
      brain,
      world,
      memory,
      const ResearchDraft11(
        goal:goal,
        documents:[paper],
        claims:[],
        passages:[],
        sentencesRead:2,
      ),
    );

    expect(out.integrated,1);
    expect(memory.claims['legacy']!.status,'accettata');
    expect(memory.claims['legacy']!.independentSourceCount,2);
    expect(memory.claims['legacy']!.sourceFamilies,contains('paper:doi:10.1234/nuc'));
  });

  test('0.31.4 selector skips a cooling-down top claim and verifies the next one', () {
    final brain=PlasticLanguageBrain04();
    final world=MgdWorld06();
    final memory=ResearchMemory11();
    final now=DateTime.now();

    memory.claims['top']=ResearchClaim11(
      key:'top',
      subject:'Nucleotide',
      relation:'tipo di',
      object:'monomero degli acidi nucleici',
      confidence:0.68,
      conflict:false,
      status:'ipotesi_mgd',
      lastSeenIso:now.toIso8601String(),
      evidenceIds:<String>{'a','b','c','d','e'},
      sourceFamilies:<String>{'wikimedia'},
      sourceProviders:<String>{'Wikipedia IT'},
    );
    memory.claims['next']=ResearchClaim11(
      key:'next',
      subject:'RNA',
      relation:'tipo di',
      object:'acido nucleico',
      confidence:0.62,
      conflict:false,
      status:'ipotesi_mgd',
      lastSeenIso:now.toIso8601String(),
      evidenceIds:<String>{'f','g','h'},
      sourceFamilies:<String>{'wikimedia'},
      sourceProviders:<String>{'Wikidata'},
    );

    memory.begin('Nucleotide tipo di monomero degli acidi nucleici',now);
    final goal=WebKnowledgeExplorer11().selectGoal(brain,world,memory,force:false);
    expect(goal,isNotNull);
    expect(goal!.verifySubject031,'RNA');
  });
'''
idx=s.rfind('\n}')
if idx<0:
    raise SystemExit('0314 test closing brace missing')
if '0.31.4 generic topic research can consolidate an existing weak claim' not in s:
    s=s[:idx]+insert+s[idx:]
p.write_text(s)

print('MGD Neuro 0.31.4 version and regression tests applied')

# The preceding baseline is preserved; apply the integrity-checked 0.31.5 overlay.
import subprocess
subprocess.run([sys.executable, str(Path(__file__).with_name('install_v0315.py')), str(root)], check=True)
