"""Final preregistered paragraph audit: every failure is exported.
Real prose here is authored for this test, not an independent public book.
The first 17 development cases must never be described as a fresh holdout.
"""
import json,hashlib,time
from pathlib import Path
from reader import Reader,Coreference,SourceReader,fit_ranker

CASES=[
 {'id':'a01','text':'Ettore invia il fascicolo a Valentina oggi.','question':'Chi invia il fascicolo?','answer':'Ettore','scope':'asserted'},
 {'id':'a02','text':'Ettore invia il fascicolo a Valentina oggi.','question':'A chi invia il fascicolo Ettore?','answer':'Valentina','scope':'asserted'},
 {'id':'a03','text':'Ettore invia il fascicolo a Valentina oggi.','question':'Quando viene inviato il fascicolo?','answer':'oggi','scope':'asserted'},
 {'id':'a04','text':'Marcella non apre la cartella.','question':'Marcella apre davvero la cartella?','scope':'negated'},
 {'id':'a05','text':'Se il pacco è pronto, Ottavia porta la scatola.','question':'Qual è la condizione della consegna?','answer':'Se il pacco è pronto','scope':'conditional'},
 {'id':'a06','text':'Alessio mette la lettera nel cassetto.','question':'Dove viene messa la lettera?','answer':'nel cassetto','scope':'asserted'},
 {'id':'a07','text':'La lettera viene consegnata da Simone a Daniela oggi.','question':'Chi consegna la lettera?','answer':'Simone','scope':'asserted'},
 {'id':'a08','text':'La lettera viene consegnata da Simone a Daniela oggi.','question':'Chi riceve la lettera?','answer':'Daniela','scope':'asserted'},
 {'id':'a09','text':'Livia legge il giornale. Omar sposta la cartella sul tavolo.','question':'Che cosa legge Livia?','answer':'il giornale','scope':'asserted'},
 {'id':'a10','text':'Livia legge il giornale. Omar sposta la cartella sul tavolo.','question':'Chi sposta la cartella?','answer':'Omar','scope':'asserted'},
 {'id':'a11','text':'Federico porta la cartella a Ilaria. Ilaria promette di restituirla domani.','question':'Che cosa promette di restituire Ilaria?','answer':'la cartella','scope':'planned'},
 {'id':'a12','text':'Federico porta la cartella a Ilaria. Ilaria promette di restituirla domani.','question':'Quando è prevista la restituzione?','answer':'domani','scope':'planned'},
 {'id':'a13','text':'Alba consegna il quaderno a Renato. Renato promette di restituirlo oggi.','question':'Che cosa promette di restituire Renato?','answer':'il quaderno','scope':'planned'},
 {'id':'a14','text':'Miriam porta la lettera. Ernesto porta il giornale domani.','question':'Quando porta la lettera Miriam?','unknown':True},
 {'id':'a15','text':'Elisabetta promette di controllare il documento questa mattina.','question':'Il controllo è già avvenuto?','scope':'planned'},
 {'id':'a16','text':'Dopo aver terminato il lavoro, Vittoria ha prestato ad Andrea il volume che aveva comprato in libreria.','question':'Chi ha prestato il volume?','answer':'Vittoria','scope':'asserted','family':'complex_original_prose'},
 {'id':'a17','text':'Nessuno sa se Giulio abbia spedito la lettera.','question':'Giulio ha spedito davvero la lettera?','unknown':True,'family':'embedded_uncertainty'},
 {'id':'a18','text':'Rita porta il libro. Enrico prende il giornale. Enrico promette di restituirlo.','question':'Che cosa promette di restituire Enrico?','unknown':True,'family':'ambiguous_reference'},
 {'id':'a19','text':'Il trattamento descritto sostituisce solo alcune funzioni dell’organo; il testo non afferma che le ripristini tutte.','question':'Come funziona il trattamento?','unknown':True,'family':'technical_prose'},
 {'id':'a20','text':'La finestra è aperta. La finestra non è aperta.','question':'La finestra è davvero aperta?','unknown':True,'family':'contradiction'},
 {'id':'a21','text':'Ogni studente legge un libro diverso.','question':'Tutti gli studenti leggono lo stesso libro?','unknown':True,'family':'quantifier_scope'},
]

def main(out):
    protocol={'cases':CASES,'label_policy':'exact extracted argument AND event scope; whole-paragraph copying is not an answer',
       'authored_test_not_public_book_corpus':True,'synthetic_template_overlap_exists':True,
       'no_training_on_these_cases':True,'all_failures_reported':True}
    raw=json.dumps(protocol,ensure_ascii=False,sort_keys=True).encode();(out/'final-audit-protocol.json').write_bytes(raw)
    base=Reader(out/'reader443-final.json');ranker=fit_ranker(base,out/'event-ranker443.json')
    model=json.loads((out/'reader443-final.json').read_text());model['event_ranker']=ranker
    payload=json.dumps(model,ensure_ascii=False,separators=(',',':')).encode();(out/'reader443-deploy.json').write_bytes(payload)
    reader=Reader(out/'reader443-deploy.json');source=SourceReader(reader,Coreference(out/'coreference443.json'))
    results=[];started=time.perf_counter()
    for c in CASES:
        a=source.answer(c['text'],c['question'])
        ok=bool(a['unknown']) if c.get('unknown') else not a['unknown']
        if 'answer' in c:ok=ok and a.get('answer','').lower()==c['answer'].lower()
        if 'scope' in c:ok=ok and a.get('scope')==c['scope']
        results.append({**c,'correct':bool(ok),'result':a})
    elapsed=time.perf_counter()-started
    result={'cases':results,'correct':sum(x['correct'] for x in results),'total':len(results),
      'protocol_sha256':hashlib.sha256(raw).hexdigest(),'model_sha256':hashlib.sha256(payload).hexdigest(),
      'model_bytes':len(payload),'CPU_audit_seconds':elapsed,'includes_successful_abstentions':True,
      'general_understanding_solved':False,'brain_equivalence_proved':False,'phone_energy_measured':False}
    (out/'final-audit-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    # Cross-runtime reference is a numerical check, not another efficacy trial.
    reference=[{'text':c['text'],'query':c['question'],'inspection':reader.inspect(c['text']),
      'question':reader.inspect(c['question']),'answer':a['result']} for c,a in zip(CASES,results)]
    (out/'runtime-reference443.json').write_text(json.dumps(reference,ensure_ascii=False))
    print(json.dumps({k:v for k,v in result.items() if k!='cases'},ensure_ascii=False))
    print(json.dumps([{'id':x['id'],'ok':x['correct'],'unknown':x['result']['unknown'],'answer':x['result'].get('answer'),'scope':x['result'].get('scope')} for x in results],ensure_ascii=False))

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path(__file__).parent/'results_v2');main(p.parse_args().output)
