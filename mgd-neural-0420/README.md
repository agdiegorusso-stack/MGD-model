# MGD Neural 0.42.0

Revisione del tuo sorgente MGD-Neuro 0.41.0 per un’installazione nuova. Nessuna migrazione dei vecchi archivi. La nuova app apre `mgd_canonical_0420.db` e usa quattro pagine: Chat, Impara, Sensi, Memoria.

**Stato della consegna:** sorgenti modificati, controlli locali eseguiti, 24 test Flutter e un test Android scritti. Flutter/Dart/SDK Android non sono disponibili nell’ambiente di revisione: analisi Dart, test Flutter, prova sul telefono e compilazione APK non sono stati eseguiti. Questo pacchetto non contiene un APK della versione nuova e non è una release validata.

## Cosa cambia

- Un coordinatore gestisce le domande della chat. Testi importati, esperienze, relazioni, prove originali, uso linguistico e collegamenti sensoriali condividono il database.
- Ogni relazione interpretata conserva il passaggio da cui proviene. Le domande e le risposte generate non diventano nuove prove. Una nuova relazione è consultabile subito, senza aspettare il consolidamento.
- Le correzioni sostituiscono la relazione scelta in una transazione e conservano l’originale. Gli archi consolidati restano correggibili.
- Le contraddizioni restano visibili. Il feedback modifica il recupero geometrico, senza trasformare familiarità, ripetizione o voto in verità.
- Il recupero usa i ruoli espliciti delle domande riconosciute e segue regole di classe. Un limite raggiunto produce una risposta con budget dichiarato.
- I TXT vengono letti a blocchi, con ripresa della compilazione dopo un’interruzione. I passaggi non interpretati restano consultabili. Le fonti si possono sfogliare per pagine, eliminare ed esportare in uno snapshot.
- Credenze e obiettivi attribuiti restano distinti dai fatti. I descrittori di foto e audio possono essere collegati a uno stesso concetto.
- I vecchi gestori di memoria e le pagine di laboratorio concorrenti sono stati rimossi dalla nuova copia. I file applicativi passano da 59 a 13. Sono stati tolti i vecchi benchmark e le percentuali arbitrarie di fiducia.

La grammatica è ancora finita. Non è un modello linguistico generale e non implementa una AGI. Il rapporto [docs/VERIFICA_0.42.0.md](docs/VERIFICA_0.42.0.md) distingue l’implementazione dalle capacità mancanti.

## Compilazione Android

Prerequisiti: Flutter >=3.44.0, Dart >=3.12.0, Java 17 e SDK Android configurato per Flutter. Il progetto conserva AGP 9.1.0 e Kotlin 2.4.0 del sorgente precedente, con wrapper Gradle 9.3.1. Prima della build controlla `flutter doctor -v` e completa le licenze SDK richieste.

Da una shell Bash, nella cartella del progetto:

```bash
bash tool/build_android.sh
```

Lo script esegue risoluzione delle dipendenze, formattazione, analisi, test Flutter e build release. Si ferma se un passaggio fallisce. Registra lo stato effettivo in `tool/reports/build_status.json`. I log del sorgente 0.41.0 non sono usati come prova della nuova versione.

APK atteso dopo una build riuscita: `build/app/outputs/flutter-apk/app-release.apk`. La firma predefinita usa la chiave di sviluppo generata da Gradle, adatta a un’installazione personale. Per una chiave propria configura `MGD_STORE_FILE`, `MGD_STORE_PASSWORD`, `MGD_KEY_ALIAS` e `MGD_KEY_PASSWORD` nell’ambiente. Nessuna chiave privata è inclusa.

Per la prova di integrazione su un dispositivo Android collegato:

```bash
flutter devices
flutter test integration_test/canonical_android_v0420_test.dart -d ID_DISPOSITIVO
```

Il test usa un database temporaneo separato. Verifica insegnamento dalla UI, domanda con prova, correzione e riapertura. I permessi di fotocamera/microfono e le importazioni da provider di file richiedono anche una prova manuale sul dispositivo.

## Uso iniziale

1. Installa la nuova versione dopo la compilazione e avviala con un archivio nuovo.
2. In Impara, inserisci `Il lorvante contiene cristalli.` e premi **Apprendi testo**.
3. In Chat, chiedi `Che cosa contiene il lorvante?`. Apri **Evidenze e correzioni** per verificare l’originale.
4. Correggi la relazione con una frase completa, per esempio `Il lorvante contiene quarzo.`. La risposta successiva deve usare la relazione nuova.
5. Per un TXT scegli la fonte della domanda. Per un’ipotesi temporanea usa `Ipotizza: Nova è un neride. | Che cosa possiede Nova?`, dopo avere insegnato una regola esplicita sulla classe neride.

Fotografie e registrazioni richiedono un’etichetta confermata da te. La similarità dei descrittori non equivale a riconoscimento degli oggetti o trascrizione della voce. Gli snapshot sono compatibili con lo schema nuovo `mgd.canonical.420`; gli archivi precedenti non vengono convertiti.

## Controlli locali disponibili

```bash
python3 tool/verify_project.py
```

Il risultato in `tool/reports/offline_checks.json` riguarda struttura lessicale/import locali, schema SQLite, vincoli, rollback, cancellazioni, indici e un riferimento matematico Python. Non è un compilatore Dart e non sostituisce i test Flutter.
