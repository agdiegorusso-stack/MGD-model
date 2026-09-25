# Revisione estesa dei PDF MGD

26 settembre 2026 (Europe/Rome).

**I documenti contengono errori sostanziali, oltre ai segni già individuati.
Alcuni enunciati hanno controesempi espliciti; altri sono presentati come
teoremi ma il ragionamento riportato non li dimostra.** Le parti matematiche
elementari valide possono essere conservate. La superiorità predittiva di
un'architettura MGD rimane una questione sperimentale aperta.

Questa revisione segue le definizioni e le dipendenze dei risultati centrali
nei tre PDF, confrontando anche correzioni e versioni discordanti. Non è una
certificazione esaustiva di tutte le 149 pagine. Non sostituisce una revisione
indipendente da parte di specialisti dei diversi ambiti.

Abbreviazioni: **P** = paper principale (52 pagine); **C1** = primo supplemento
(56); **C2** = secondo supplemento (41). I riferimenti indicano pagine PDF.
I nomi e gli hash dei documenti sono nell'[audit precedente](../mgd_memory_benchmark/MATHEMATICAL_AUDIT.md).
Gli originali non sono modificati né inclusi in questo repository.

## Come leggere l'esito

- **Confutato nelle condizioni scritte:** un controesempio viola l'enunciato.
- **Passaggio di prova invalido:** la conclusione potrebbe richiedere un'altra
  dimostrazione o ipotesi aggiuntive; non la si dichiara automaticamente falsa.
- **Modelli o versioni incoerenti:** si cambia la dinamica o la convenzione senza
  dimostrare che il risultato continui a valere.

[checks.py](checks.py) riproduce i calcoli e i controesempi finiti;
[results.json](results.json) conserva i valori. Le conclusioni asintotiche
sono motivate qui con argomenti analitici, non dedotte da una simulazione finita.

## 1. Deriva negativa non significa assorbimento permanente

**P p.10, teorema 4.3; C1 p.29, lemma 11.5. Confutato.**

Un sottocaso ammesso è $\eta=\mu=0$, con:

$$w_{t+1}=\max(0.1,w_t-U_t+0.25),\quad U_t\sim\mathrm{Bernoulli}(0.9).$$

Qui $p_c=0.25$, $p=0.9>1-p_c$ e la deriva senza riflessione è $-0.65$.
Eppure quattro zeri consecutivi, partendo dal limite inferiore, producono:

$$0.1\to0.35\to0.60\to0.85\to1.10.$$

Con soglia $\varepsilon=1$ l'arco diventa inattivo. La probabilità di ogni
blocco disgiunto di quattro zeri è $10^{-4}>0$; tali blocchi indipendenti
si verificano infinitamente spesso quasi certamente. Partendo da qualunque
peso almeno 0.1, ciascun blocco forza nuovamente il superamento della soglia.

Si possono studiare ritorni al limite, distribuzione stazionaria e frequenza
di attivazione. Non segue la permanenza al limite o l'attivazione definitiva.
Il supplemento ripete lo stesso errore: escursioni che ritornano non sono
escursioni che, da un certo momento, non accadono più.

## 2. La geometria forzata su una linea non è una griglia 2D omogenea

**P pp.8–10, definizione 2.1 ed eq.(1)–(4). Modello/enunciati incompatibili.**

L'uso è assegnato agli archi orizzontali su $L=\mathbb Z\times\{0\}$ e agli
archi verticali incidenti a $L$; altrove è nullo. Con inizializzazione uniforme
finita e memoria iniziale nulla fuori da $L$, gli altri archi diventano inattivi.

Anche mantenendo attivi tutti gli archi favoriti, resta una linea con due
foglie per vertice, non $\mathbb Z^2$. Per pesi unitari:

$$|B(0,r)|=6r-1\quad(r\geq1\text{ intero}),$$

quindi la crescita è lineare. Se restano soltanto gli archi verticali incidenti
alla linea, ogni componente ha al massimo tre vertici: la dimensione
macroscopica è 0, non 1. Una versione con forzante estesa a tutta la griglia
è possibile, ma è un modello diverso da definire e analizzare separatamente.

Inoltre, su un arco verticale incidente a $L$, un estremo è fuori dalla linea.
La sua memoria resta zero se inizialmente nulla. Perciò il termine
$\min(m(x),m(y))$ è zero e quello $\mu|m(x)-m(y)|$ può essere non nullo.
La formula simmetrica della deriva verticale in eq.(4) non segue dal lemma
di uniformità **sulla** linea.

## 3. Una correzione limitata del peso non è una deriva aggiunta a ogni passo

**P pp.11–12, S2/S5 e proposizione 5.4. Passaggio invalido.**

Le regole scritte aggiornano il peso base $w$ e poi costruiscono:

$$\widetilde w_t=\max(c_0,w_t-\eta_M\min(M_t(x),M_t(y))).$$

Per $M\in[0,1]$, $|\widetilde w_t-w_t|\leq\eta_M$. Una differenza limitata
non cambia il limite del peso diviso per $t$. Se $M=1$ è costante e il clipping
non interviene, $\Delta\widetilde w_t=\Delta w_t$: non si sottrae nuovamente
$\eta_M$ a ogni incremento.

La soglia efficace ottenuta sottraendo $\eta_M$ alla deriva richiede una
ricorrenza con feedback cumulativo diversa da S2/S5. Occorre scegliere quale
dinamica si intende, prima di trasferire le conclusioni al codice.

## 4. La prova della supermartingala ignora la riflessione al limite

**P pp.14–15, lemma 6.6. Passaggio invalido e incompatibilità del bound persistente.**

Nel primo esempio, al limite $w=c_0$ si ha:

$$\mathbb E[\Delta w\mid w=c_0]=(1-p)\nu=0.025>0,$$

mentre la deriva dell'incremento prima del clipping è $-0.65$. Le due quantità
non sono intercambiabili. Il primo termine della dimostrazione usa la deriva
non riflessa anche quando il peso è al limite.

Più in generale, un'energia non negativa integrabile non può avere per sempre
una deriva condizionale $\leq-\delta|A_t|$ con $\delta>0$ e almeno un arco
attivo permanente: sommando le aspettative si otterrebbe un'energia attesa
negativa. Una formulazione valida deve far cessare la discesa al minimo,
oppure usare un drift fuori da un insieme di ritorno, con termini residui.

## 5. Equilibrio e stabilità: le correzioni precedenti restano necessarie

**P pp.17–19; C2 p.38. Errori già riprodotti nell'audit precedente.**

Per $F(M,\chi)=\rho M+(1-\rho)\chi+\xi M(1-M)$, con $0<\rho<1$ e $\xi\geq0$:

$$\xi(M^*)^2+(1-\rho-\xi)M^*-(1-\rho)p=0,$$

$$0\leq\xi\leq\rho\quad\text{garantisce e caratterizza l'invarianza di }[0,1]
\text{ per ogni }M,\chi\in[0,1].$$

Il polinomio è già corretto in C2 p.38, ma non nelle eq.(7)–(9) di P.
La condizione $\lambda=1-F'(M^*)>0$ non basta da sola: per attrattività locale
discreta occorre $|F'(M^*)|<1$. La media di un processo stocastico non coincide
automaticamente con il punto fisso ottenuto sostituendo la forzante con la sua media.

## 6. La probabilità dichiarata nulla sotto alpha = 1/2 non è nulla

**C1 p.5, eq.(5), finestra fissata [0.4,0.6]. Confutato.**

La variabile normalizzata stazionaria è:

$$X=(1-\alpha)\sum_{j\geq0}\alpha^jB_j,\qquad B_j\sim\mathrm{Bernoulli}(1/2).$$

Con $\alpha=0.49$, i primi quattro bit $0111$ forzano:

$$X\in[0.43235199,0.49]\subset[0.4,0.6].$$

I bit $1000$ forzano invece $X\in[0.51,0.56764801]$, ancora nella finestra.
Le due configurazioni disgiunte hanno probabilità $1/16$ ciascuna:

$$\boxed{\delta_1(0.49)\geq1/8=12.5\%>0.}$$

Il vuoto centrale del supporto per $\alpha<1/2$ non contiene necessariamente
tutta la finestra scelta. Inoltre, la legge di $X$ varia debolmente in modo
continuo con $\alpha$; a $1/2$ è uniforme e i bordi della finestra non hanno
atomi. Quindi $\delta_1(\alpha)\to0.2$ anche da sinistra. Il salto da zero
a 0.2 dichiarato per questa finestra non esiste.

## 7. Supporto pieno, densità e minorazione uniforme sono proprietà diverse

**P pp.38–39, teorema 20.1. Enunciato troppo forte e bound confutato.**

Il supporto pieno per $\alpha>1/2$ dà massa positiva a ogni intervallo aperto
non vuoto. Non implica una densità, né una minorazione uniforme della massa
proporzionale alla lunghezza.

Per un controesempio elementare al bound, porre $\alpha=0.75$, $\beta=0.25$
e $I=[0,0.078310546875]$. Per cadere in $I$ i primi cinque bit devono essere
zero, quindi $\mu(I)\leq1/32=0.03125$. Il bound scritto richiederebbe invece
$\mu(I)\geq|I|/2=0.0391552734375$.

Il teorema di Solomyak riguarda **quasi ogni** parametro, non tutti. Per
$\alpha=(\sqrt5-1)/2$, reciproco di un numero di Pisot, la convoluzione
Bernoulli simmetrica è singolare. Fonte primaria di riscontro:
[Solomyak, Notes on Bernoulli convolutions, teorema 2.4 e sezione sulla continuità assoluta](https://u.math.biu.ac.il/~solomyb/RESEARCH/Bernotes.pdf).
Si conserva il risultato topologico sul supporto, separandolo dalle altre rivendicazioni.

## 8. Media temporale, oscillazioni e indipendenza delle memorie

**C2 pp.4–5, lemma 2.1 e teorema 2.2. Passaggi invalidi.**

L'oscillazione della configurazione non impedisce la convergenza della sua
media temporale. Se la dimensione istantanea fosse sempre 1, come nel passaggio
riportato, la sua media sarebbe esattamente 1. Se è un'osservabile integrabile
di un processo stazionario ergodico, la media converge anche se la misura
stazionaria è singolare. L'argomento scritto non prova la non esistenza di
$D_{avg}$. Questo non è una dimostrazione generale dell'esistenza per ogni
versione del grafo: vanno controllati osservabile e ordine dei limiti.

Anche la legge congiunta dichiarata come prodotto è incompatibile con la
forzante complementare. In stazionarietà:

$$m_t^\parallel+m_t^\perp=\frac{\beta}{1-\alpha}.$$

Per margini non degeneri, le due memorie hanno correlazione $-1$, non sono
indipendenti. Inoltre la classificazione in tre tipi omette il caso in cui
nessuna direzione è attiva, che richiede un'esclusione dimostrata.

## 9. Il lemma di deriva del minimo ha un controesempio in un solo passo

**C1 p.14, lemma 9.3. Confutato.**

Porre $M^\parallel=M^\perp=0$, stato ammesso. Con forzante complementare
il passo successivo è $(1-\rho,0)$ oppure $(0,1-\rho)$. Il minimo resta zero:

$$\mathbb E[m_{t+1}-m_t]=0.$$

Per $\xi>(1-\rho)/2$ e una soglia $M^*>0$, il lemma pretende una quantità
almeno $\kappa_\xi M^*>0$. La dimostrazione segue una componente senza tenere
conto che l'altra può diventare il minimo. Le conclusioni sui tempi di uscita
basate su quel lemma devono essere ridimostrate. Inoltre un limite
$\xi\to\infty$ esce dal dominio di invarianza della ricorrenza non proiettata.

## 10. La trasformazione verso Julia/Mandelbrot è errata

**C2 pp.12–15; C1 pp.4 e 53 per soglie alternative. Confutato per la mappa scritta.**

Per $F(z)=-\xi z^2+(\rho+\xi)z+(1-\rho)p$, con $\xi>0$, porre:

$$w=-\xi z+\frac{\rho+\xi}{2}.$$

Si ottiene esattamente $w'=w^2+c$, dove:

$$c=\frac{\rho+\xi}{2}-\frac{(\rho+\xi)^2}{4}-\xi(1-\rho)p.$$

La scala $-2\xi$ usata in C2 non normalizza il coefficiente quadratico a 1.
Le formule successive per $c$ sono tra loro incoerenti.

Con $\rho=0.8$, $p=0.5$:

| xi | c corretto |
|---:|---:|
| 0.05 | 0.239375 |
| 0.10 | 0.237500 |
| 0.1183 | 0.2365012775 |

Per tutti questi valori $0<c<1/4$. L'intervallo $[0,1/2]$ è invariante
per $w\mapsto w^2+c$: l'orbita critica che parte da 0 resta limitata per
ogni tempo. In particolare non diverge a $\xi=0.05<\xi_c=0.1$.
Neppure spostare la soglia a 0.1183, come fa C1, risolve il problema.

Anzi, nel dominio corretto $0<\xi\leq\rho<1$, con $0<p<1$, ponendo
$D=(1-\rho-\xi)^2+4\xi(1-\rho)p$, si ha $0<D<1$ e $c=(1-D)/4\in(0,1/4)$.
Il presunto passaggio attraverso il bordo di Mandelbrot non si verifica
all'interno di questo dominio. Non sono quindi dimostrate le transizioni e
i limiti di dimensione di Hausdorff costruiti su quel passaggio.

## 11. Rumore gaussiano, spazio degli stati e criterio di Dobrushin

**C2 pp.27–29 e 33–34. Problemi distinti.**

La dinamica aggiunge rumore gaussiano non limitato, ma dichiara lo stato
confinato in $[0,1]$. Con accoppiamento nullo, $M_0=0$ e $p=1/2$, l'evento
$U=0$, rumore negativo ha probabilità $1/4$ e porta subito $M_1<0$.
Clipping, riflessione o rumore limitato cambierebbero il modello e richiedono
nuove prove. La funzione di Lyapunov con $\log M$ non è definita lì.
L'uso di Jensen per ogni $\kappa\geq0$ richiede inoltre una combinazione
convessa: nella forma scritta occorre $0\leq\kappa\leq1$.

Il lemma 11.2 scrive $c_{xy}=(1-\rho)\alpha/4$ per ciascuno dei quattro
vicini e poi somma ottenendo $4(1-\rho)\alpha$. La somma sarebbe
$(1-\rho)\alpha$. C'è anche un problema precedente: moltiplicare la distanza
totale di variazione per l'ampiezza $1-\rho$ non è corretto.

Tenendo fisso lo stato del sito, il kernel a un passo è una miscela di due
Gaussiane separate di $a=1-\rho$. La sua sensibilità a un singolo vicino è:

$$\frac{\alpha}{4}\left[2\Phi\left(\frac{1-\rho}{2\sigma}\right)-1\right].$$

Con $\rho=0.8$, $\alpha=1$, $\sigma=0.03$ vale circa 0.249785 per vicino.
Questa correzione riguarda il kernel di transizione: non prova da sola
l'unicità della misura stazionaria. La specificazione Gibbs e la dipendenza
dallo stato precedente dello stesso sito devono essere trattate separatamente.
La soglia universale $\rho=3/4$ non è stabilita dalla prova presentata.

## 12. Il limite termodinamico usa un'energia diversa da quella definita

**C1 pp.34–35, lemma 13.2 e teorema 13.4. Bound confutato; normalizzazione incoerente.**

Il termine orizzontale dell'energia somma tutti gli archi della famiglia, ma
il bound usa $w\leq\varepsilon$, valido solo per gli archi attivi.
In una scatola $3\times3$, con i due archi orizzontali sulla linea di peso 100,
$c_0=0.1$, $\varepsilon=C=1$, $\gamma=\zeta=0$ e altri archi inattivi:

$$e_0=2(100-0.1)/9=22.2>1.9=B.$$

Anche concedendo lo stato collassato descritto, i termini residui sono
sostenuti su $L\cap\Lambda$: crescono come $O(n)$. Dividendo per il volume
$O(n^2)$ danno zero, non la densità positiva dichiarata. Va scelto se
normalizzare per la linea o estendere effettivamente la dinamica al volume.

## 13. Il minimo taglio non commuta con l'aspettativa

**C2 pp.21–23, teoremi 8.4 e 8.6. Passaggio invalido e controllo dimensionale fallito.**

Due archi in serie con capacità equiprobabili $(1,0.1)$ e $(0.1,1)$ danno:

$$\mathbb E[\min(c_1,c_2)]=0.1,\qquad
\min(\mathbb E[c_1],\mathbb E[c_2])=0.55.$$

Il teorema max-flow/min-cut è applicabile a ogni rete realizzata, ma non
autorizza l'identificazione tra minimo delle capacità medie e media dei
minimi. L'esempio confuta quel passaggio generale; non simula la legge
stazionaria completa di MGD.

Con le definizioni della sezione, il taglio di frontiera è ammissibile e
ogni suo arco attivo ha peso al massimo $\varepsilon$. Quindi:

$$\frac{|\gamma_A|_w}{\varepsilon|\partial A|}\leq1.$$

La tabella 6 riporta invece rapporti 1.47, 1.56, 1.40 e altri superiori a 1.
O la normalizzazione/simulazione è diversa da quella dichiarata, oppure quei
numeri non possono essere valori della quantità definita. Una legge entropia–
taglio richiede ulteriori ipotesi; non segue dal solo max-flow/min-cut.

## 14. La divergenza KL è quadratica, non un costo temporale lineare universale

**C2 pp.25–27. Errori algebrici/numerici e passaggio alla metrica non dimostrato.**

Per Bernoulli, con logaritmi naturali:

$$D_{KL}(M\Vert M+\delta)=\frac{\delta^2}{2M(1-M)}+
\frac{(2M-1)\delta^3}{3M^2(1-M)^2}+O(\delta^4).$$

Il termine cubico dell'eq.(35) ha il segno opposto a quello corretto,
pur essendo i passaggi intermedi compatibili con il segno corretto.
$D_{KL}/|\delta|\to0$; la stessa osservazione 9.2 lo riconosce.
Un'approssimazione in media non dà una costante valida punto per punto
lungo tutti i cammini, né permette di riscalare anche il termine spaziale.
Va inoltre distinto $\mathbb E|\delta|$ dalla deviazione standard.

La formula scritta dà $\sigma_{eff}=\sqrt{p(1-p)}(1-\rho)=0.1$ per
$p=0.5$, $\rho=0.8$. La tabella 7 usa invece 0.25. L'equivalenza tra
quasi-metriche non è dimostrata dalla catena di passaggi riportata.

## 15. La non esistenza di una forma chiusa non è stata dimostrata

**C1 pp.12–13, teorema 8.1. Non dimostrato.**

Il testo lo presenta esplicitamente con un argomento euristico: dipendere
da tutte le cifre binarie non esclude una forma chiusa. Anche la funzione
identità dipende dal numero completo e ha una formula elementare. Occorre
definire la classe di espressioni ammesse e provare una vera ostruzione.

Inoltre il teorema 3.6 afferma $C(w)<1$ per tutti i valori, mentre la tabella
di p.12 riporta 1.25 e 1.13. Questa è un'incoerenza interna, non una prova
che quei numeri simulati siano corretti. La classificazione di OP7b come
risolto negativamente va rimossa fino a una dimostrazione adeguata.

## Dipendenze da riesaminare

| Problema a monte | Risultati che non possono essere usati senza nuova verifica |
|---|---|
| Permanenza al limite, forcing localizzato | Collasso definitivo, cascade dimensionali, parte delle fasi 1D/2D |
| Clipping e drift dell'energia | Supermartingala, convergenza al minimo, argomenti sulla freccia del tempo che la utilizzano |
| Equilibrio e minimo delle due componenti | Soglie della materia, tempi di uscita e formule di stabilità del floor |
| Finestra IFS e legge congiunta | Transizione a 1/2, formule per dimensione media, parte delle rivendicazioni sul vuoto |
| Coniugio quadratico | Transizione Julia, correlazione con il collasso, limiti di Hausdorff dichiarati |
| Spazio degli stati con rumore e Dobrushin | Prove globali di unicità/ergodicità su Z² |
| Energia e minimo taglio | Limite termodinamico e formula RT proposta |

Una dipendenza da una prova errata rende un risultato **da ridimostrare**;
non significa automaticamente che ogni possibile riformulazione sia falsa.
Anche l'identificazione con il flusso di Ricci va tenuta come programma aperto:
scrivere drift = termine di curvatura + residuo per definizione non controlla
la grandezza del residuo e non dimostra un limite continuo.

## Cosa conservare e come proseguire

Restano utilizzabili la distanza di cammino con pesi positivi (P, teorema 1.3),
la ricorrenza esponenziale della memoria e il suo limite uniforme (eq.(1),
lemma 6.2), la contrazione delle mappe IFS con lo stesso forcing e la
ricorrenza della materia con il dominio corretto. Sono componenti matematiche;
il loro collegamento con accuratezza, generalizzazione e linguaggio va costruito.

Il [prototipo di aggiornamento](plastic_memory.py) proposto qui usa la materia
per regolare una memoria con correzione dell'errore. Ne verifichiamo una
proprietà locale su 1.000 aggiornamenti: l'errore sulla singola osservazione
usata per l'aggiornamento diminuisce secondo l'identità prevista. **Non è un
nuovo risultato di benchmark, né una prova di generalizzazione o superiorità.**

La [proposta sperimentale](NEXT_EXPERIMENT.md) distingue il contributo MGD
dalla regola delta preesistente e fissa quali confronti servono. Nessun PDF
originale è stato riscritto presentando come corretti teoremi non ancora provati.

Riproduzione, da questa directory con NumPy installato:

```bash
python checks.py
```
