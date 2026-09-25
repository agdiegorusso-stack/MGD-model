# Una strada verificabile verso una memoria MGD competitiva

26 settembre 2026. Proposta e primitiva eseguibile, non risultato di superiorità.

## Obiettivo preciso

Il primo bersaglio è incorporare fatti nuovi e correggere fatti cambiati durante
l'uso, conservando quelli ancora validi, con memoria e tempi sostenibili.
Superare un Transformer su questo compito sarebbe un risultato utile e
circoscritto. Non equivarrebbe a superarlo nel linguaggio naturale o in ogni capacità.

Il benchmark precedente misura 84,27% per MGD, 85,87% per il piccolo Transformer
e 87,14% per EMA. La materia aiuta rispetto alla sua rimozione; il termine
di memoria aggiuntivo peggiora il risultato. Questi dati motivano una memoria
che corregga selettivamente il proprio stato anziché rinforzare soltanto
connessioni già attive. Non dicono ancora quale modifica funzionerà meglio.

## Cosa suggerisce la ricerca primaria

- [Gated DeltaNet, ICLR 2025](https://arxiv.org/abs/2412.06464): combina
  dimenticanza regolata e correzioni mirate con regola delta. È un precedente
  diretto, perciò la sola aggiunta di questi meccanismi non sarebbe una novità MGD.
- [Gated DeltaNet-2, rapporto tecnico del 21 maggio 2026](https://arxiv.org/abs/2605.22791):
  separa il controllo della cancellazione e della scrittura nella memoria
  ricorrente. Suggerisce di misurare separatamente correzione e conservazione.
- [Titans/MIRAS, Google Research](https://research.google/blog/titans-miras-helping-ai-have-long-term-memory/):
  tratta esplicitamente architettura della memoria, obiettivo interno,
  regolarizzazione della conservazione e algoritmo di aggiornamento.

Questi lavori offrono meccanismi e confronti pertinenti. Non sono stati
riprodotti integralmente qui e non provano che MGD li supererà. Alcuni sistemi
sono ibridi o forme di attenzione lineare: occorre confrontare implementazioni
precise, non etichette di famiglie.

## Proposta: la materia controlla quanto correggere

Una memoria $W_t$ associa una chiave $k_t$ al valore osservato $v_t$.
L'errore prima dell'aggiornamento è:

$$e_t=v_t-W_tk_t.$$

La primitiva in [plastic_memory.py](plastic_memory.py) usa:

$$\eta_t=\eta_{min}+(\eta_{max}-\eta_{min})(1-M_t),$$

$$W_{t+1}=W_t+\eta_t\frac{e_tk_t^\top}{\epsilon+\|k_t\|^2},$$

$$\chi_t=\exp(-\|e_t\|^2/s^2),\qquad
M_{t+1}=\rho M_t+(1-\rho)\chi_t+\xi M_t(1-M_t).$$

La materia elevata riduce il tasso di scrittura, per proteggere ciò che è
stabile; errori ripetuti riducono la coerenza e possono aumentare la plasticità.
Il comportamento effettivo dipende dai parametri e dalla scala dell'errore:
non è garantito che distingua un cambiamento vero dal rumore.

Questa è un'**estensione progettuale ispirata a MGD**. Il significato di chi,
la regola delta e il collegamento al tasso di apprendimento non sono teoremi
contenuti nei PDF. Il prototipo minimo ha un solo stato materiale per modulo;
passare a stati per regione o chiave richiede una scelta esplicita di indirizzamento
e un controllo della memoria consumata. Non implementa qui curvatura o dimensione.

### Una garanzia che si può dimostrare davvero

Per $0<\rho<1$, $0\leq\xi\leq\rho$ e $\chi_t\in[0,1]$, $M_t$ resta
in $[0,1]$. Scegliendo $0<\eta_{min}\leq\eta_{max}\leq1$, dopo l'aggiornamento:

$$v_t-W_{t+1}k_t=
\left(1-\eta_t\frac{\|k_t\|^2}{\epsilon+\|k_t\|^2}\right)e_t.$$

Per chiave non nulla e errore non nullo, la norma dell'errore su **questa
osservazione** si riduce strettamente. L'identità segue sostituendo $W_{t+1}$;
non richiede analogie con geometria fisica. Il controllo numerico su 1.000
aggiornamenti riproduce l'identità entro $1.34\times10^{-15}$.

La garanzia deriva dalla regola delta normalizzata e dal limite sul tasso,
non dimostra una novità della teoria MGD. Se l'osservazione è sbagliata,
ridurre quell'errore può peggiorare la conoscenza. Non garantisce minore errore
sui dati futuri, preservazione delle altre chiavi o italiano fluente.

## Confronto successivo necessario

Prima dell'esecuzione va congelato un protocollo completo con budget, seed,
griglie e soglie. Il documento presente definisce la scelta scientifica ma non
si presenta come preregistrazione di un esperimento già eseguito.

1. Compiti: nuovi fatti, sostituzione di associazioni, correzioni ripetute,
   rumore isolato e recupero di informazioni vecchie dopo molte distrazioni.
   Separare chiavi ortogonali e chiavi sovrapposte per misurare l'interferenza.
2. Predire prima di vedere la risposta richiesta. Consentire aggiornamenti
   soltanto dalle osservazioni previste dal protocollo, mai dalle etichette
   nascoste usate per misurare il test. Separare denoising dopo osservazione
   e previsione prima dell'osservazione, perché sono compiti diversi.
3. Controlli: EMA, delta con tasso fisso, delta con gate adattivo della stessa
   capacità, MGD senza materia/nonlinearità, precedente MGD e Transformer
   addestrato con budget dichiarato. Un controllo Bayesiano con probabilità
   note va indicato come privilegiato.
4. Usare validazione per scegliere parametri e nuovi test indipendenti dal
   precedente esperimento. Ripetere gli addestramenti; non selezionare il
   seed migliore sul test e non ritoccare i parametri dopo averlo visto.
5. Metriche: accuratezza per scenario, perdita predittiva, osservazioni
   necessarie a correggere un fatto, danno alle associazioni non cambiate,
   memoria massima e latenza p50/p95 sullo stesso dispositivo. Riportare
   pareggi e scambi tra metriche, senza condensarli in una vittoria generica.
6. Rivendicare un contributo MGD soltanto se la variante completa supera anche
   il gate adattivo non MGD, con un vantaggio ripetibile su test nuovi. Se il
   guadagno resta identico togliendo la materia, attribuirlo alla regola delta
   o alla progettazione della memoria, non a MGD.

Un confronto successivo sul testo richiederebbe encoder, decodifica e
addestramento con obiettivo linguistico, mantenendo pari dati e budget.
Un grafo di relazioni e la correttezza delle ricorrenze non sostituiscono
automaticamente questi componenti.

## Ordine delle correzioni ai paper

Prima uniformare le definizioni: forcing su linea o volume, chi geometrico o
Bernoulli, peso base o peso con feedback, rumore limitato o proiezione.
Poi riscrivere i lemmi elementari e le loro condizioni. Solo dopo riesaminare
energia, fasi, limiti continui e teoremi che ne dipendono. Le sezioni Julia,
RT, trascendenza e stabilità globale non devono essere usate come garanzie
per l'app finché non sono state ricostruite o ridimensionate.
