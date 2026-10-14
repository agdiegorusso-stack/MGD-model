import 'package:flutter_test/flutter_test.dart';
import 'package:mgd_neuro_mobile/axioms/axiom_core.dart';
import 'package:mgd_neuro_mobile/axioms/axiom_seed.dart';

J moveProbe(String id,String who,String place,String text,{bool neg=false}){
  final before=<String,dynamic>{'location':{who:'roma'},'holder':<String,dynamic>{},'owner':<String,dynamic>{}};
  final after=copyJ(before);if(!neg)after['location'][who]=place;
  return {'id':id,'text':text,'intent':'move','args':{'who':who,'where':place},'negated':neg,'before':before,'expected_after':after,'expected_status':neg?'event_denied_no_update':'applied'};
}
J lessonPackage()=>{
  'diagnosis':'Manca solo il collegamento lessicale giunge → move; il ruolo destinazione è già disponibile.',
  'task':moveProbe('task','luca','pisa','Luca giunge a Pisa.'),
  'lessons':[{'kind':'anchored','id':'lesson-giunge','text':'Luca giunge a Roma.','anchor':'giunge','intent':'move','args':{'who':'luca','where':'roma'}}],
  'probes':[
    moveProbe('t1','anna','bari','Anna giunge a Bari.'),
    moveProbe('t2','marco','milano','È a Milano che Marco giunge.'),
    moveProbe('t3','sofia','genova','Sofia non giunge a Genova.',neg:true),
  ],
};
void main(){
  late AxiomStudent s;
  setUp(()=>s=AxiomStudent(axiomSeed()));
  test('v03 checkpoint has the actual compositional inventory',(){
    expect(s.frames.length,13);expect(s.lexicon.length,27);expect(s.rules.length,6);expect(s.programs.length,6);
  });
  test('all 276 specified operational regression worlds pass',(){
    final cases=axiomRegression();expect(cases.length,276);
    for(final q in cases){final r=s.probe(q);expect(r['passed'],true,reason:canonical(r));}
  });
  test('focus and known predicate recombine without the exact sentence',(){
    final r=s.parse('È a Pisa che Vittorio arriva.');
    expect(r['status'],'ok');expect(r['args'],{'who':'vittorio','where':'pisa'});
    expect(r['proof'],contains('rule:focus_preposition'));
  });
  test('negation does not perform the event or invent an opposite',(){
    final before={'location':{'luca':'roma','sofia':'roma'},'holder':{'chiave':'luca'},'owner':{'chiave':'luca'}};
    final r=s.execute('È la chiave che Luca non porge a Sofia.',before);
    expect(r['status'],'event_denied_no_update');expect(r['world'],before);expect(r['reading']['negated'],true);
  });
  test('missing context is not replaced with an axiom',(){
    final before={'location':{'luca':'roma'},'holder':{'chiave':'luca'},'owner':{'chiave':'luca'}};
    final r=s.execute('Luca consegna la chiave a Sofia.',before);
    expect(r['status'],'needs_context');expect(r['missing_facts'],contains('location:sofia'));expect(r['teach_axiom_instead'],false);expect(r['world'],before);
  });
  test('physical possession and ownership remain distinct',(){
    final before={'location':{'luca':'roma','sofia':'roma'},'holder':{'chiave':'luca'},'owner':{'chiave':'luca'}};
    final r=s.execute('Luca porge la chiave a Sofia.',before);
    expect(r['world']['holder']['chiave'],'sofia');expect(r['world']['owner']['chiave'],'luca');
  });
  test('known false guard rejects even with another unknown fact',(){
    final before={'location':{},'holder':{'chiave':'marco'},'owner':{}};
    final r=s.execute('Luca porge la chiave a Sofia.',before);
    expect(r['status'],'preconditions_false');expect(r['world'],before);
  });
  test('large input is search limited, not evidence of absent axioms',(){
    expect(s.parse(List.filled(60,'parola').join(' '))['status'],'search_limit');
    expect(s.parse('@not Luca va a Roma')['status'],'search_limit');
  });
  test('unseen nested belief remains explicitly unrecognized',(){
    expect(s.parse('Luca crede che Sofia sia a Roma.')['status'],'unrecognized');
  });
  test('contradictory lexical supervision is detected as ambiguity',(){
    s.anchored({'id':'bad','text':'Luca va a Roma.','anchor':'va','intent':'own','args':{'who':'luca','where':'roma'}});
    expect(s.parse('Anna va a Pisa.')['status'],'ambiguous');
  });
  test('teacher acceptance requires target, operational transfer and retention',(){
    final r=validateTeaching(s,lessonPackage(),axiomRegression());
    expect(r['accepted'],true,reason:canonical(r));expect(r['protected_tested'],276);expect(r['transfer_tested'],4);
    final taught=AxiomStudent(r['model'] as Map);
    expect(taught.parse('È a Torino che Elena giunge.')['status'],'ok');
    expect(s.parse('È a Torino che Elena giunge.')['status'],'unrecognized',reason:'Original must remain unchanged before commit.');
  });
  test('repeating successful lessons does not manufacture new axioms',(){
    final first=validateTeaching(s,lessonPackage(),axiomRegression());
    final second=validateTeaching(AxiomStudent(first['model'] as Map),lessonPackage(),axiomRegression());
    expect(second['accepted'],false);expect(second['reason'].toString(),contains('già'));
  });
  test('easy probes cannot conceal a failed user target',(){
    final p=lessonPackage();p['task']=moveProbe('task','luca','pisa','Luca si teletrasporta a Pisa.');
    expect(validateTeaching(s,p,axiomRegression())['accepted'],false);
  });
  test('parse-only probes are not accepted as understanding',(){
    final p=lessonPackage();for(final q in p['probes'] as List){(q as Map).remove('before');}
    expect(validateTeaching(s,p,axiomRegression())['accepted'],false);
  });
  test('probe contamination and duplicate role assignments are rejected',(){
    final p=lessonPackage();p['probes'][0]['text']='Luca giunge a Roma.';
    expect(validateTeaching(s,p,axiomRegression())['accepted'],false);
  });
  test('unknown primitive cannot be accepted from an LLM assertion',(){
    final p=lessonPackage();p['lessons']=[{'kind':'absolute_truth','id':'fake','axiom':'tutto'}];
    expect(validateTeaching(s,p,axiomRegression())['accepted'],false);
  });
  test('a destructive existing-program correction fails protected cases',(){
    final p=lessonPackage();p['lessons']=[{'kind':'program','id':'bad-write','intent':'move','program':{'guards':[],'writes':[{'relation':'owner','target_arg':'who','value':{'kind':'arg','arg':'where'}}]}}];
    expect(validateTeaching(s,p,axiomRegression())['accepted'],false);
  });
  test('minimum repair is only over the finite proposed alternatives',(){
    final p=lessonPackage();(p['lessons'] as List).insert(0,{'kind':'anchored','id':'irrelevant','text':'Luca zompa a Roma.','anchor':'zompa','intent':'move','args':{'who':'luca','where':'roma'}});
    final r=validateTeaching(s,p,axiomRegression());expect(r['accepted'],true);expect(r['mask'],2);
  });
  test('rewrite cannot copy or silently discard variables',(){
    final m=axiomSeed();(m['rules'] as List).add({'id':'rule:bad','source':[{'name':'x','minimum':1,'maximum':1,'entity':true}],'target':[r'$x',r'$x']});
    expect(()=>AxiomStudent(m),throwsFormatException);
  });
  test('unknown relation and double writes are rejected before execution',(){
    expect(()=>AxiomStudent.validateProgram({'guards':[],'writes':[{'relation':'filesystem','target_arg':'who','value':{'kind':'arg','arg':'where'}}]}),throwsFormatException);
    final p=copyJ(s.programs['move'] as Map);(p['writes'] as List).add(copyJ((p['writes'] as List).first as Map));expect(()=>AxiomStudent.validateProgram(p),throwsFormatException);
  });
  test('the graph is connected to real mutable interpreter components',(){
    final nodes=s.graph();expect(nodes.any((n)=>n['id']=='program:give'),true);
    expect(nodes.firstWhere((n)=>n['id']=='primitive:known')['type'],'expression');
    final ids=nodes.map((n)=>n['id']).toSet();for(final n in nodes){for(final d in n['depends'] as List)expect(ids.contains(d),true,reason:'Dangling dependency $d');}
    final minus=s.without('rule:focus_preposition');expect(minus.parse('È a Pisa che Vittorio arriva.')['status'],'unrecognized');
  });
  test('ablation returns a concrete necessity witness without touching original',(){
    final revision=s.revision;
    final r=axiomJob({'job':'ablate','node':'write:move:0','model':s.model,'probes':axiomRegression()});
    expect(r['regressions'] as int,greaterThan(0));expect(r['witnesses'],isNotEmpty);expect(r['absolute_minimality'],false);expect(s.revision,revision);
  });
  test('empty evidence is inconclusive and never certifies redundancy',(){
    final r=axiomJob({'job':'ablate','node':'rule:focus_preposition','model':s.model,'probes':[]});
    expect(r['status'],'inconclusive');expect(r['absolute_minimality'],false);
  });
  test('the fixed DSL cannot pretend that a primitive was ablated',(){
    expect(()=>s.without('primitive:read'),throwsFormatException);
  });
  test('serialization preserves model and operational behavior',(){
    final restored=AxiomStudent(copyJ(s.model));expect(restored.revision,s.revision);
    expect(restored.execute('Luca va a Roma.',{'location':{'luca':'pisa'}})['world'],{'location':{'luca':'roma'}});
  });
}
