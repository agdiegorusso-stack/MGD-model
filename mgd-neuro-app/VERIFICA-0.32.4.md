# MGD Neuro 0.32.4 — primo esperimento di lettura appresa

## Ambito
Un tagger lineare dei ruoli, addestrato con perceptron mediato su 700 esempi sintetici etichettati, interpreta quattro famiglie: inseguire, aiutare, contenere, possedere. Non è un modello linguistico generale e non deriva la grammatica dai teoremi MGD. Non usa pesi preaddestrati esterni. Il modello si rigenera con `node tool/train_reader_v0324.mjs --check`; il codice di training e i suoi dati sono pubblici nel repository.

## Uso nell'app
Scrivere in chat «Il norvente insegue il talverio.» e chiedere «Da chi viene rincorso il talverio?». Correggere con «Correggi: Il norvente insegue il felvario.». L'ultima correzione esplicita sostituisce il fatto precedente, conservandone la cronologia. La correzione per soggetto e relazione funziona soltanto se c'è un unico bersaglio; in caso contrario scegliere una riga in Mente → Relazioni apprese. La mappa Mondo include le nuove relazioni, distinguendole come insegnate.

I corpora e il pulsante di insegnamento passano anche nel lettore appreso. Le domande non sono fatti. Ripetere una fonte non aumenta prove o attivazione di queste relazioni. L'attività geometrica non modifica lo stato epistemico. Le relazioni conservano il testo fornito e sono affermazioni dell'utente, non fatti scientificamente verificati.

## Grammatica appresa e controlli
Il tagger assegna agente/oggetto/predicato tramite parametri appresi. Il vocabolario dei predicati è ricavato dal training; i nomi delle entità vengono mascherati durante la codifica per consentire nomi mai visti. Negazioni semplici sono mantenute. Un controllo conservativo rifiuta modalità, condizioni, coordinazioni e discorso riportato riconoscibili: non è una garanzia di copertura per qualunque frase italiana.

Il riferimento pronominale è risolto da una regola esplicita, non appresa: un solo referente nell'introduzione immediatamente precedente («Il topo corre. Il gatto lo insegue.»). Con più referenti o senza antecedente il lettore si astiene. Il margine del classificatore non è una probabilità calibrata.

## MGD e confronto
Ogni nuova osservazione o correzione aggiorna costi, memoria e materia con MgdMath09.evolve. Le risposte filtrano le versioni correnti e i ruoli; MGD ordina i candidati. La variante semplice usa lo stesso lettore, gli stessi fatti, lo stesso versionamento, e ordina cronologicamente. Il test misura quindi il contributo marginale dell'ordinamento geometrico: un pareggio significa che non è dimostrato un vantaggio di MGD su questo compito.

Il dataset è fissato prima della CI: 288 casi sintetici con nomi di entità assenti dal training, sei categorie, quattro famiglie di relazioni. I modelli di frase e il vocabolario verbale si sovrappongono al training: non è un test cieco di comprensione generale. I casi completi e ogni predizione vengono pubblicati. La baseline Qwen2.5-0.5B-Instruct usa le stesse affermazioni e domande con quattro alternative; deve superare controlli separati. Il suo pretraining ha un budget diverso e il confronto non dimostra superiorità architetturale.

## Verifiche richieste prima della consegna
Regressioni unitarie/interfaccia; rigenerazione esatta dei pesi; valutazione con ripristino JSON; test Android di chat, parafrasi, correzione, cronologia, mappa e ripristino SQLite; build firmata dopo il successo dei test. Il ripristino testato ricrea l'app e riapre il database, non copre ogni terminazione del processo Android.
