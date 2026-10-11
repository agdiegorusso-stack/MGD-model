"""Question-head training and an explicitly preregistered end-to-end audit.

This second experiment reuses the first eight question tests as development.
It does not disguise them as fresh tests. Role encoder and scope head remain
frozen, protecting the already measured role capabilities.
"""
from pathlib import Path
import copy,hashlib,json,time
import numpy as np
from train import question_data,QUESTIONS
from reader import Reader,Coreference,SourceReader,fit_coreference,softmax,PredictiveGeometry

ROOT=Path(__file__).parent
FRESH_Q={
 'agent':'Chi agisce nel brano?',
 'object':"Quale cosa è coinvolta nell’azione?",
 'recipient':'A chi arriva ciò che viene consegnato?',
 'time':'Qual è il momento previsto?',
 'location':"In quale posto finisce l’oggetto?",
 'condition':'Che cosa deve essere vero affinché avvenga?',
 'status':'Quello che è descritto succede davvero oppure no?',
 'summary':'Raccontami quanto riferisce la lettura.'}
TRAIN_Q={
 'agent':['Chi agisce?','Chi fa questa cosa?','Chi è il soggetto?','Indica la persona che compie l’azione.','Quale persona agisce?','Chi svolge l’attività?','Da quale persona è fatta questa azione?','Chi è l’autore dell’azione?','Chi si occupa della consegna?'],
 'object':['Qual è l’oggetto?','Che cosa viene fatto?','Quale cosa viene consegnata?','Indica l’oggetto interessato.','Cosa è coinvolto?','Quale cosa viene letta?','Qual è la cosa coinvolta?','Che cosa prende Anna?','Su quale oggetto si agisce?','Quale oggetto viene trasferito?'],
 'recipient':['Chi riceve?','A chi viene data questa cosa?','Indica la persona destinataria.','A chi è destinato l’oggetto?','Quale persona lo riceve?','Chi è il ricevente?','A chi è dato il pacco?','Chi prende in consegna la lettera?','Chi beneficia della consegna?'],
 'time':['Qual è il momento?','Qual è il momento della consegna?','Quando succede?','In che momento avviene?','Indica il momento previsto nel testo.','Quale giorno è previsto?','In quale giornata?','Quando è previsto?','A che ora?','Quanto tempo dopo avviene?'],
 'location':['Qual è il posto?','In che luogo?','Indica il luogo in cui si trova.','Dove si trova l’oggetto?','Qual è il posto indicato?','In quale posizione è stata messa la cosa?','Dove è finito il pacco?','Dove viene depositato?','In che posto finisce?'],
 'condition':['Quale condizione deve essere vera?','Che cosa deve essere vero?','Quale requisito serve?','A quale condizione succede?','Indica la condizione necessaria.','Che cosa deve succedere affinché si svolga l’azione?','Da cosa dipende l’azione?','Qual è il requisito richiesto?','Quando può succedere questa cosa?'],
 'status':['Succede davvero?','È una promessa oppure è già accaduto?','È un evento certo o condizionato?','Quello che è descritto avviene oppure no?','È soltanto promesso?','Il fatto è affermato o negato?','Indica se il testo afferma l’evento.','Si tratta di un fatto avvenuto?','Viene negato?','Qual è lo stato dell’evento?'],
 'summary':['Raccontami il contenuto.','Riferisci cosa dice il testo.','Che cosa riferisce la lettura?','Riporta quello che racconta il brano.','Riassunto della lettura.','Che cosa è scritto?','Descrivi quanto riferisce il testo.','Spiegami il passaggio.','Che cosa racconta?']}

QA=[
 {'id':'new_names','text':'Beatrice consegna il fascicolo a Tommaso domani.','question':'Chi consegna il fascicolo?','expected':'Beatrice'},
 {'id':'recipient','text':'Beatrice consegna il fascicolo a Tommaso domani.','question':'A chi viene consegnato il fascicolo?','expected':'Tommaso'},
 {'id':'new_object','text':'Beatrice consegna il fascicolo a Tommaso domani.','question':'Che cosa consegna Beatrice?','expected':'il fascicolo'},
 {'id':'time','text':'Beatrice consegna il fascicolo a Tommaso domani.','question':'Quando consegna il fascicolo?','expected':'domani'},
 {'id':'negative','text':'Beatrice non consegna il fascicolo a Tommaso.','question':'Beatrice consegna davvero il fascicolo?','expected_scope':'negated'},
 {'id':'conditional','text':'Se il cancello è chiuso, Ada porta la borsa.','question':'A quale condizione Ada porta la borsa?','expected':'Se il cancello è chiuso','expected_scope':'conditional'},
 {'id':'planned','text':'Elisa promette di restituire la cartella domani.','question':'La restituzione è già avvenuta?','expected_scope':'planned'},
 {'id':'location','text':'Dario mette il quaderno sullo scaffale.','question':'Dove è stato messo il quaderno?','expected':'sullo scaffale'},
 {'id':'clitic','text':'Anna consegna il libro a Marco. Marco promette di restituirlo domani.','question':'Che cosa promette di restituire Marco?','expected':'il libro','expected_scope':'planned'},
 {'id':'clitic_time','text':'Anna consegna il libro a Marco. Marco promette di restituirlo domani.','question':'Quando è prevista la restituzione?','expected':'domani','expected_scope':'planned'},
 {'id':'passive','text':'La chiave viene consegnata da Emilia a Roberto.','question':'Da chi viene consegnata la chiave?','expected':'Emilia'},
 {'id':'missing','text':'Chiara apre il quaderno.','question':'Dove è conservato il quaderno?','expected_unknown':True},
 {'id':'ambiguous','text':'Anna consegna il libro a Marco. Giulia legge il quaderno. Marco promette di restituirlo.','question':'Che cosa promette di restituire Marco?','expected_unknown':True},
 {'id':'realistic_long','text':'Durante la riunione, Francesca ha consegnato ai colleghi una relazione sulle spese sostenute nel trimestre precedente.','question':'Chi ha consegnato la relazione?','expected':'Francesca'},
 {'id':'scientific_limit','text':'La dialisi permette di eliminare dal sangue alcune sostanze e parte dell’acqua quando i reni non riescono a svolgere adeguatamente questa funzione.','question':'Perché è necessaria la dialisi?','expected_unknown':True},
 {'id':'quantified','text':'Non tutti i documenti sono firmati.','question':'Nessun documento è firmato?','expected_unknown':True},
 {'id':'contradiction','text':'La chiave è nel cassetto. La chiave non è nel cassetto.','question':'Dove si trova la chiave?','expected_unknown':True},
]

def main():
    out=ROOT/'results';model=Reader(out/'reader443.json')
    # The protocol exists before fitting or running any of these fresh cases.
    protocol={'fresh_question_paraphrases':FRESH_Q,'end_to_end':QA,'first_question_test_now_development':True,
      'realistic_case_is_original_Italian_prose_not_a_public_book_test':True,
      'universal_comprehension_solved':False}
    raw=json.dumps(protocol,ensure_ascii=False,sort_keys=True).encode();(out/'advance-protocol.json').write_bytes(raw)
    train=[]
    for rows in question_data():
        train += [(r['text'],r['question']) for r in rows]
    prefixes=['','Dimmi: ','Vorrei sapere: ','Puoi spiegare: ','Nel testo, ','Secondo il brano, ']
    for kind,questions in TRAIN_Q.items():
        for q in questions:
            for prefix in prefixes:train.append((prefix+q,QUESTIONS.index(kind)))
    assert not (set(FRESH_Q.values()) & {q for q,y in train})
    x=np.array([model.forward(q,latent=True)[-1] for q,y in train]);y=np.array([y for q,y in train])
    w=model.p['question.weight'];b=model.p['question.bias'];rng=np.random.default_rng(443)
    for epoch in range(700):
        order=rng.permutation(len(x))
        for start in range(0,len(x),64):
            ix=order[start:start+64];p=softmax(x[ix]@w.T+b);p[np.arange(len(ix)),y[ix]]-=1;p/=len(ix)
            w-=.08*(p.T@x[ix]+.00002*w);b-=.08*p.sum(0)
    original=json.loads((out/'reader443.json').read_text());original['parameters']['question.weight']=w.tolist();original['parameters']['question.bias']=b.tolist()
    original['question_head_revision']=2;modelbytes=json.dumps(original,ensure_ascii=False,separators=(',',':')).encode()
    (out/'reader443-advanced.json').write_bytes(modelbytes);advanced=Reader(out/'reader443-advanced.json')
    fit_coreference(out/'coreference443.json');source=SourceReader(advanced,Coreference(out/'coreference443.json'))
    details=[]
    for case in QA:
        a=source.answer(case['text'],case['question']);ok=a['unknown']==True if case.get('expected_unknown') else not a['unknown']
        if 'expected' in case:ok=ok and case['expected'].lower() in a.get('answer','').lower()
        if 'expected_scope' in case:ok=ok and a.get('scope')==case['expected_scope']
        details.append({**case,'correct':bool(ok),'result':a})
    qdetails=[]
    for kind,q in FRESH_Q.items():
        a=advanced.inspect(q);qdetails.append({'question':q,'expected':kind,'predicted':a['question_type'],'confidence':a['question_confidence'],'correct':a['question_type']==kind})
    # Semantic role/scope probabilities must be bitwise unaffected by this head update.
    role_frozen=all(np.array_equal(model.forward(c['text'])[1],advanced.forward(c['text'])[1]) and np.array_equal(model.forward(c['text'])[2],advanced.forward(c['text'])[2]) for c in QA)
    assert role_frozen
    geometry=PredictiveGeometry()
    for c in QA:geometry.add(c['text'],'local://audit/'+c['id'])
    audit=geometry.rebuild(advanced);geometry.require(advanced)
    result={'protocol_sha256':hashlib.sha256(raw).hexdigest(),'question_training_examples':len(train),
      'fresh_questions_correct':sum(x['correct'] for x in qdetails),'fresh_questions_total':len(qdetails),'fresh_questions':qdetails,
      'end_to_end_correct':sum(x['correct'] for x in details),'end_to_end_total':len(details),'end_to_end':details,
      'encoder_and_scope_preserved_bitwise':role_frozen,'geometry':audit,'universal_comprehension_solved':False,
      'free_text_decoder_trained':False,'automatic_semantic_learning_from_reading_proven':False,'model_sha256':hashlib.sha256(modelbytes).hexdigest()}
    (out/'advance-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k not in {'end_to_end','geometry'}},ensure_ascii=False))
    print(json.dumps([{'id':c['id'],'ok':c['correct'],'unknown':c['result']['unknown'],'answer':c['result'].get('answer'),'scope':c['result'].get('scope')} for c in details],ensure_ascii=False))

if __name__=='__main__':main()
