# Contributo causale di MGD: protocollo della verifica 0.32.4

Fissato il 25 settembre 2026 prima dell'esecuzione di questa verifica. È un audit successivo al pilot precedente, non una sperimentazione cieca né una preregistrazione esterna.

App congelata al commit `336848c817d3fbed5c6b5906ff085d262d21e914`. Nessuna modifica ai pesi o all'APK.

## Domanda

Il nuovo modulo `RelationalMemory324` produce risposte migliori grazie alle sue equazioni MGD, a parità di lettore, dati, versionamento e indici?

Prima di attribuire un vantaggio sui Transformer a MGD, è necessario stabilire che MGD contribuisca causalmente al compito. Un sistema completo potrebbe superare una specifica baseline anche grazie ad altri componenti: questo protocollo non confonde le due affermazioni.

## Limite individuato nel pilot

La funzione di predizione precedente restituisce una relazione soltanto quando c'è esattamente un candidato; altrimenti restituisce null. Cambiare l'ordinamento non può modificare questa risposta, indipendentemente dai valori geometrici. Quell'ablazione non può quindi dimostrare un vantaggio dell'ordinamento MGD.

Nel modulo corrente, inoltre, ogni record nasce dallo stesso stato `(weight=.98, memory=0, material=0, coherence=0)` e riceve lo stesso passo con attivazione e ricompensa pari a 1. Le ripetizioni non rinforzano i record. Le correzioni aggiornano negativamente il vecchio record, ma lo escludono dalle risposte tramite `status=superseded`. La nuova versione riparte dallo stesso stato iniziale.

## Intervento e controlli

1. Generare una copia del modulo, rimuovendo l'import MGD, svuotando l'evoluzione e sostituendo l'intero ordinamento geometrico con quello cronologico. Non basta il parametro `mgd=false`.
2. Conservare identici lettore, pesi, regole, versionamento, fonti, deduplicazione, indici e formattazione. Il generatore verifica che il sorgente di partenza sia esattamente quello dell'APK.
3. Eseguire i 288 casi già pubblicati su entrambi, prima e dopo ripristino; pubblicare ogni predizione. Sono casi sintetici di sviluppo, non nuove prove indipendenti di generalizzazione.
4. Eseguire 20 sequenze pseudocasuali fissate (seed 932400–932419), ciascuna con 160 passi, 40 candidati concorrenti iniziali, correzioni, duplicazioni, negazioni, frasi condizionali e ripristini. Confrontare ordine dei candidati, testo delle risposte e record semantici. Sei query strutturate e quattro domande testuali per passo.
5. Controllo positivo: alterare deliberatamente la geometria di un record per imporre priorità diversa. Il test deve accorgersi del cambiamento d'ordine. Questa alterazione è artificiale e non conta come miglioramento di accuratezza.
6. Verificare che la variante priva di MGD non memorizzi campi geometrici e che la prova eserciti realmente inserimenti, correzioni e più candidati.

## Criterio di conclusione

Se le risposte e gli ordini sono identici senza i calcoli MGD, non attribuire a MGD l'accuratezza del modulo. Un'eventuale differenza richiede esame delle predizioni: una differenza da sola non significa miglioramento.

Non ripetere confronti con modelli linguistici per presentare come successo MGD un punteggio già spiegato integralmente dal lettore e dal versionamento. Il confronto Transformer precedente rimane non conclusivo. Non si può trasformare il mancato superamento dei controlli di una baseline in una dimostrazione generale.

## Argomento verificabile nel codice

Sotto le seguenti condizioni: memoria inizialmente vuota, sole operazioni pubbliche di apprendimento/correzione/interrogazione del modulo, serializzazione e ripristino fedeli, nessuna manipolazione esterna dei campi geometrici:

- Base: tutti i record nuovi ricevono lo stesso stato geometrico deterministico.
- Induzione: inserire un record o correggerne uno conserva l'uguaglianza tra gli stati dei record correnti; il record modificato negativamente diventa storico.
- Domande e duplicazioni non aggiornano la geometria.
- La priorità dei record correnti resta identica. Il confronto geometrico va sempre a pareggio e usa la sequenza cronologica.

Di conseguenza, nel modulo, ordinamento e risposte semantiche coincidono con la variante senza MGD. I dati geometrici visualizzati e i tempi di calcolo non sono identici. L'argomento non riguarda gli altri motori dell'app, un import con campi alterati, né tutte le possibili implementazioni della teoria MGD.

## Riproduzione

```sh
python3 tools/prepare_mgd_contribution_0324.py
cd mgd-neuro-app
flutter pub get
flutter test tool/mgd_contribution_0324_test.dart --reporter expanded
```

I file generati per l'ablazione sono controlli sperimentali, non modifiche distribuite nell'APK. Ambiente Flutter 3.47.5, runner Ubuntu; nessuna misura energetica o confronto generale di latenza è previsto.
