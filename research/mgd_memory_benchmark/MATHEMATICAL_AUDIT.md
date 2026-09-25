# Verifica mirata delle equazioni MGD

25 settembre 2026. Le pagine sotto sono le pagine PDF. Questa è una verifica
di alcune equazioni rilevanti per l'implementazione, non una revisione completa
di tutti i teoremi dei tre documenti. I PDF originali non sono inclusi nel repository.

Il codice [math_checks.py](math_checks.py) riproduce i controlli numerici;
[math_checks.json](results/math_checks.json) conserva i risultati.

## 1. Punto fisso: un'incoerenza di segno tra i documenti

Paper principale, p.17, eq.(6):

$$F(M,\chi)=\rho M+(1-\rho)\chi+\xi M(1-M).$$

Con forzante costante $\chi=p$, imporre $F(M,p)=M$ dà esattamente:

$$\xi M^2+(1-\rho-\xi)M-(1-\rho)p=0.$$

Per $\xi>0$, $0<\rho,p<1$, la radice positiva è:

$$M^*=\frac{\sqrt{(1-\rho-\xi)^2+4\xi(1-\rho)p}-(1-\rho-\xi)}{2\xi}.$$

La formula delle eq.(7)–(9), p.18, corrisponde invece al segno opposto del
termine logistico. Con i parametri della figura, $\rho=0{,}9$, $\xi=0{,}05$,
$p=0{,}5$:

| Quantità | Valore |
|---|---:|
| Radice stampata nell'eq.(9) | 0,3819660113 |
| Residuo $F(M,p)-M$ in quella radice | 0,02360679775 |
| Radice coerente con eq.(6) | 0,6180339887 |
| Residuo nella radice corretta | 0, entro precisione numerica |
| Iterazione deterministica dopo 10.000 passi | 0,6180339887 |

**Il secondo supplemento, p.38, dimostrazione del teorema 13.1, usa già il
polinomio corretto.** La critica riguarda quindi una reale incoerenza tra le
formule consegnate; non significa che tutte le versioni abbiano lo stesso errore.
L'esperimento di memoria usa fin dall'inizio la radice corretta.

### Equilibrio deterministico e media stocastica sono distinti

In regime stazionario, se i momenti esistono, la ricorrenza implica:

$$\xi\mathbb E[M^2]+(1-\rho-\xi)\mathbb E[M]-(1-\rho)\mathbb E[\chi]=0.$$

Sostituire $\mathbb E[M^2]$ con $\mathbb E[M]^2$ trascura la varianza. Inoltre,
quando l'attivazione dipende dalla materia attraverso i pesi, sostituire
$\mathbb E[\chi\mid M]$ con una costante richiede un'altra ipotesi.

Una simulazione con forzante Bernoulli indipendente di media 0,5, stessi
parametri, 10.000 passi scartati e 200.000 conservati dà media 0,613677 e
varianza 0,0119815. Il numero simulato non è una dimostrazione analitica del
limite: illustra la distinzione già implicata dall'identità dei momenti.

## 2. Invarianza di [0,1]: la condizione dichiarata non basta

Paper principale, p.17, lemma 9.2: è proposta la condizione $\xi\leq1-\rho$.
Prendere $\rho=0{,}2$, $\xi=0{,}6$, $M=0{,}5$, $\chi=1$ la soddisfa, ma:

$$F(0{,}5,1)=0{,}1+0{,}8+0{,}15=1{,}05.$$

Per questa mappa, con $0<\rho<1$ e $\xi\geq0$, la condizione necessaria e
sufficiente affinché **ogni** coppia $M,\chi\in[0,1]$ sia mandata in $[0,1]$ è:

$$0\leq\xi\leq\rho.$$

Infatti il limite inferiore è immediato perché tutti gli addendi di $F$ sono
non negativi; il massimo rispetto a $\chi$ è in $\chi=1$, e:

$$1-F(M,1)=(1-M)(\rho-\xi M).$$

Se $\xi\leq\rho$, il prodotto è non negativo. Se $\xi>\rho$, basta scegliere
$\rho/\xi<M<1$ per renderlo negativo. Nel caso $\rho\geq1/2$, la condizione
più restrittiva del paper è sufficiente; il controesempio riguarda la
formulazione generale. Il benchmark usa $\rho=0{,}8$, $\xi=0{,}1$ e soddisfa
entrambe le restrizioni.

## 3. Positività di lambda e stabilità discreta non sono equivalenti

Secondo supplemento, p.38, teorema 13.1. Con il punto fisso corretto, ponendo:

$$D=(1-\rho-\xi)^2+4\xi(1-\rho)p,$$

si ottengono direttamente:

$$F'(M^*)=1-\sqrt D,\qquad \lambda=1-F'(M^*)=\sqrt D>0.$$

La positività di $\lambda$ è quindi corretta. Non è però equivalente a
$|F'(M^*)|<1$ per tutti i $\xi\geq0$, come afferma il testo: manca il limite
inferiore $F'(M^*)>-1$ per una mappa a tempo discreto.

Con $\rho=0{,}8$, $\xi=3$, $p=0{,}5$ si ha:

$$M^*\simeq0{,}967777,\quad \lambda\simeq3{,}006659>0,
\quad F'(M^*)\simeq-2{,}006659.$$

Il punto fisso non è localmente attrattivo per la mappa deterministica.
La condizione corretta è $0<\sqrt D<2$. Il controesempio rientra nel
dominio $\xi\geq0$ enunciato dal teorema, ma **non** nel dominio di invarianza
$\xi\leq\rho$. Adottare quest'ultima restrizione elimina questo esempio e
fornisce anche l'attrattività locale del punto fisso con forzante costante.
Questo controllo non è una dimostrazione o confutazione completa dell'ergodicità
del modello spaziale rumoroso.

## 4. Entropia e flusso: distinguere affermazioni differenti

Paper principale, p.44, osservazione 23.3. L'entropia binaria è:

$$H(M)=-M\log_2M-(1-M)\log_2(1-M),\qquad
H'(M)=\log_2\frac{1-M}{M}.$$

Il massimo è soltanto in $M=1/2$. Un punto fisso arbitrario $M^*\in(0,1)$
non è necessariamente un massimo dell'entropia. Per il punto fisso corretto
del primo esempio, $H'(M^*)\simeq-0{,}694242$, non zero.

La proposizione 23.4 usa inoltre il lemma di invarianza per dedurre
$M\in(0,1)$, mentre il lemma enuncia $M\in[0,1]$. Nella sola ricorrenza locale,
con le due componenti $M=1$ e $\chi=1$, entrambe le variazioni sono nulle.
Questo mostra che invarianza chiusa e ricorrenza, da sole, non implicano
flusso strettamente positivo a ogni istante. Il controllo non simula l'intero
grafo accoppiato; l'ammissibilità dei segnali, l'inizializzazione e l'eventuale
legge stazionaria devono essere esplicitate per giustificare una proposizione
globale più forte.

## Conseguenze per un modello che apprende

Le ricorrenze di memoria esponenziale, una distanza di cammino con pesi positivi
e una dinamica della materia con limiti validi sono oggetti matematici
utilizzabili. Non specificano però da soli l'obiettivo di previsione, la
rappresentazione del testo, l'assegnazione dell'errore ai parametri o la regola
con cui una credenza sbagliata viene corretta. Neppure la validità di tutti i
teoremi geometrici implicherebbe automaticamente un errore di previsione minore
di quello di un Transformer.

L'esperimento allegato costruisce un ponte esplicito tra alcune ricorrenze e
una decisione misurabile, dichiarando gli adattamenti. La materia aiuta rispetto
alla sua rimozione; l'accuratezza complessiva rimane sotto Transformer ed EMA.
Questa evidenza sostiene un'indagine su quel meccanismo, non una superiorità
generale della teoria.

## Documenti esaminati e integrità

| Documento | Pagine | SHA-256 |
|---|---:|---|
| Generative_mhatematics_of_dimensions (8)(4).pdf | 52 | `d13ca7349a4a9e86f59a4de295c8b28fa844d78f2a7548f735bf62b6b5e03228` |
| mgd_op_resolutions_prima_parte (2)(3).pdf | 56 | `54ea46d47dc3f1c915f5d5a81658d7f9b6163ab4f76b97cf1341e2d35af871d1` |
| mgd_op_resolutions_seconda_parte (2)(2).pdf | 41 | `2f1860792383abac5faf41dbdfd4a2cf1eee4205391f0d54f3e9e6ed1f86097b` |

Lettura mirata alle dinamiche, agli equilibri e alle condizioni di stabilità,
con confronto tra i documenti. Nessuna attestazione di revisione integrale
delle 149 pagine o delle fonti bibliografiche da esse citate.
