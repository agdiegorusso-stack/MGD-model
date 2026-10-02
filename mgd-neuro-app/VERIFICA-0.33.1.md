# MGD Neuro 0.33.1 — correzioni e consolidamento verificabile

Questa versione applica una parte circoscritta della revisione matematica MGD. Non implementa una teoria universale, AGI, né una dimostrazione di superiorità sui Transformer.

## Problemi riprodotti prima delle modifiche

- In uno stato saturo, un feedback negativo poteva lasciare il costo di una connessione al minimo: i termini di rinforzo compensavano la penalità.
- Il decadimento aggiornava `lastUsed` anche senza un nuovo uso. Il successivo controllo dell'età non poteva quindi potare una connessione vecchia.
- Il replay di una risposta rifiutata poteva tornare a rinforzarla; il canale delle risposte insegnate non aveva una revoca persistente.

Il controllo del punto fisso materiale nell'app precedente era già corretto: 1.212 casi hanno prodotto un residuo massimo di circa 1,11e-16. Questa versione non presenta tale formula come una nuova correzione.

## Regola nuova e ambito della prova

Il modulo `consolidation_v0331.dart` implementa una dinamica distinta da quella storica:

```
c' = max(c0, c + nu - lambda*u - theta*M)
M' = rho*M + (1-rho)*1{c <= epsilon}
```

Con `epsilon >= c0 > 0`, `theta > nu > 0`, `0 <= rho < 1` e impulsi non negativi, la regione `c <= epsilon`, `M >= nu/theta` è invariante in assenza di revoca. La condizione più forte `lambda > nu` permette l'acquisizione da un costo iniziale finito tramite impulsi unitari sufficienti. La prova non si applica alla somma arbitraria di questa regola e dei termini del motore storico.

La proprietà riguarda la persistenza di una connessione; non dimostra la verità della proposizione associata. La funzione opzionale deve usare conferme esterne con provenienza, tenere separati i contatori di consolidamento e di evidenza, e consentire che una correzione prevalga sulla persistenza. Ripetere internamente una memoria non crea una nuova fonte indipendente.

I salvataggi precedenti mantengono la nuova dinamica disabilitata. I nuovi campi sono versionati. La modalità a eventi della 0.33.0 e i salvataggi coerenti tra le memorie restano parte dei test di regressione.

## Verifiche della build

Sul codice congelato per questa versione, la verifica locale ha superato 252 test Flutter. I cinque test nuovi comprendono 25 controlli puri, eseguiti anche separatamente in JIT e AOT, più prove sul worker reale, sulla cancellazione, sulla revoca con dinamica disattivata e sul controllo UI. L'analisi statica termina senza errori: 40 warning e 9 info già presenti nel progetto (un warning in meno rispetto alla base). Gli otto test Android, inclusi i due nuovi su SQLite e sull'interazione di chat, sono un controllo distinto eseguito dalla pipeline.

La pipeline conserva gli esiti effettivi nei file `tests-0.33.1.log`, `benchmark-0.33.1.json`, `analyze-0.33.1.log` e `android-0.33.1.log`. Questo documento descrive i controlli, non anticipa il loro esito.

L'APK viene compilato dalla pipeline solo dopo i test unitari/widget, il benchmark, l'analisi statica e i test di ciclo di vita su Android. Il commit preciso è in `BUILD-COMMIT.txt`; identità, firma e SHA-256 del binario sono in `APK-VERSION.txt`, `APK-SIGNATURE.txt` e `APK-SHA256.txt`.

Identità attesa: `it.diegorusso.mgdneurostable`, versione `0.33.1`, codice `65`. Il certificato deve mantenere il fingerprint SHA-256 `bfd6e2660a3c3a6e3b37d1736e1619777b933e976c312c5b1c6cd38e908f1589`.

Durante la preparazione locale è stato risolto un problema della toolchain estratta: l'eseguibile `dartvm` mancava del bit di esecuzione. Prima della correzione, i test Flutter non erano partiti; quelle esecuzioni non vengono contate come test superati. Il risultato Android viene stabilito dalla pipeline, senza riutilizzare come prova i test di una versione precedente.

## Limiti della valutazione

Il controllo del lettore su 700 esempi di addestramento è una verifica di riproducibilità, non una misura di generalizzazione. Il benchmark applicativo non è un confronto controllato con Transformer moderni capaci di adattamento. Non sono stati misurati consumi energetici fisici né dimostrata assenza universale di oblio. I descrittori multimodali e la memoria episodica della 0.33.0 restano un prototipo, non comprensione generale di immagini e audio.
