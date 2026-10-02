from pathlib import Path
root=Path('mgd-neuro-app')
p=root/'lib/book_understanding_v0342.dart';s=p.read_text()
if 'BOOK_METRICS_REFINEMENT_0342' not in s:
    changes=[
      ("var correct=0, answered=0, wrongAnswers=0, unknownTotal=0, correctUnknown=0;", "var correct=0, answered=0, wrongAnswers=0, unknownTotal=0, correctUnknown=0;\n    var correctAnswerable=0;"),
      ("if(expect=='answer') {answerable++;if(r.answered)", "if(expect=='answer') {answerable++;if(ok)correctAnswerable++;if(r.answered)"),
      ("'tokenF1':answerable==0?null:f1/answerable,", "'correctAnswerable':correctAnswerable,'answerableAccuracy':answerable==0?null:correctAnswerable/answerable,\n      'answerPrecision':answered==0?null:correctAnswerable/answered,\n      'tokenF1':answerable==0?null:f1/answerable,"),
      ("q=q.replaceFirst(RegExp(r'^(?:secondo il libro|nel libro|secondo il testo|nel testo),?\\s+'),'');", "q=q.replaceFirst(RegExp(r'^(?:secondo il libro|nel libro|secondo il testo|nel testo),?\\s+'),'');\n    q=q.replaceFirst(RegExp(r'^(?:(?:puoi|potresti) (?:dirmi|spiegarmi)|mi dici|dimmi|spiegami)\\s+'),'');"),
    ]
    for old,new in changes:
        assert s.count(old)==1,(old,s.count(old));s=s.replace(old,new,1)
    s='// BOOK_METRICS_REFINEMENT_0342\n'+s;p.write_text(s)
p=root/'lib/book_lab_page_v0342.dart';s=p.read_text()
if 'BOOK_ANSWERABLE_METRIC_0342' not in s:
    old="Text('Domande non determinabili: ${r['correctUnknown']}/${r['unknownTotal']} riconosciute.'),"
    new="Text('Risposte corrette alle domande rispondibili: ${r['correctAnswerable'] ?? 'non misurato'}/${r['answerable']}.'),\n        "+old
    assert s.count(old)==1;s=s.replace(old,new);p.write_text('// BOOK_ANSWERABLE_METRIC_0342\n'+s)
p=root/'test/book_understanding_v0342_test.dart';s=p.read_text()
s=s.replace("expect(e.answer('Puoi spiegarmi cosa contiene il lorvante?').status,'unknown');", "expect(e.answer('Puoi spiegarmi cosa contiene il lorvante?').answer,'cristalli');\n    expect(e.answer('Puoi confrontare il lorvante con Mira?').status,'unknown');")
p.write_text(s)
p=root/'integration_test/runtime_android_v0319_test.dart';s=p.read_text().replace('Memorie MGD 0.34.1','Memorie MGD 0.34.2');p.write_text(s)
p=root/'tool/book_eval_v0342_test.dart';s=p.read_text()
s=s.replace("    expect((measured['results'] as List).where((r)=>r['correct']==false),isNotEmpty,\n      reason:'This reader is intentionally not presented as a general prose solver.');", "    print('BOOK342_FAILED_CASES ${jsonEncode((measured['results'] as List).where((r)=>r['correct']==false).map((r)=>r['case']['id']).toList())}');")
p.write_text(s)
