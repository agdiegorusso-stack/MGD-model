import '../lib/semantic_reasoning_v0435.dart';

/// New transfer/regression cases. These are developer-written checks of a
/// bounded grammar, not a blind assessment or a general intelligence claim.
List<Map<String, dynamic>> semanticTransfer435() {
  final rows = <Map<String, dynamic>>[];
  void check(
    String id,
    String text,
    String prompt,
    String expected, {
    bool unknown = false,
    bool unsupported = false,
    List<ReadingSource435>? sources,
  }) {
    final ss =
        sources ??
        [
          for (final e in text.split(RegExp(r'(?<=[.!?])\s+')).asMap().entries)
            ReadingSource435(
              '$id:${e.key}',
              e.value,
              id,
              'local://transfer/$id',
            ),
        ];
    final before = SemanticReasoning435.answer([], prompt);
    final answer = SemanticReasoning435.answer(ss, prompt);
    final passed =
        before == null &&
        (unsupported
            ? answer == null
            : answer != null &&
                  answer.unknown == unknown &&
                  RegExp(
                    expected,
                    caseSensitive: false,
                  ).hasMatch(answer.text.split('\n').first));
    rows.add({
      'id': id,
      'text': text,
      'prompt': prompt,
      'expectedPattern': expected,
      'unknownExpected': unknown,
      'unsupportedExpected': unsupported,
      'answer': answer?.text,
      'proof': answer?.proof,
      'passed': passed,
    });
  }

  const division =
      'La resa è la portata divisa per la durata: Q = p / t. La resa si misura in pezzi.';
  const product =
      'La resa è la portata moltiplicata per la durata: Q = p * t. La resa si misura in pezzi.';
  check(
    'formula-new-labels',
    division,
    'La portata vale 18 e la durata vale 3. Quanto vale la resa? Mostra il calcolo.',
    r'^6 pezzi',
  );
  check(
    'formula-source-reversed',
    product,
    'La portata vale 18 e la durata vale 3. Quanto vale la resa? Spiega.',
    r'^54 pezzi',
  );
  check(
    'formula-inverse',
    product,
    'La resa vale 54 e la durata vale 3. Quanto vale la portata?',
    r'^18\b',
  );
  check(
    'formula-missing',
    division,
    'La portata vale 18. Quanto vale la resa? Indica il dato mancante.',
    r'non determinabile.*durata',
    unknown: true,
  );
  check(
    'formula-zero',
    division,
    'La portata vale 18 e la durata vale 0. Quanto vale la resa?',
    r'non determinabile.*finita',
    unknown: true,
  );
  check(
    'formula-negation',
    'La resa non è la portata divisa per la durata: Q = p / t.',
    'La portata vale 18 e la durata vale 3. Quanto vale la resa?',
    '',
    unsupported: true,
  );
  check(
    'formula-only-question',
    'La resa è la portata divisa per la durata: Q = p / t?',
    'La portata vale 18 e la durata vale 3. Quanto vale la resa?',
    '',
    unsupported: true,
  );
  const sum = 'La spesa è la quota piu la tassa: S = q + t.';
  check(
    'formula-addition',
    sum,
    'La quota vale 11 e la tassa vale 4. Quanto vale la spesa?',
    r'^15\b',
  );
  check(
    'formula-inverse-addition',
    sum,
    'La spesa vale 15 e la tassa vale 4. Quanto vale la quota?',
    r'^11\b',
  );
  const mechanics =
      'La forza risultante è la massa moltiplicata per l’accelerazione: F = m * a. L’accelerazione ha la direzione della forza risultante. Forze in direzioni opposte si sottraggono.';
  check(
    'converted-unit',
    mechanics,
    'Una massa di 500 g subisce 3 N verso sinistra. Qual è l’accelerazione?',
    r'^6 m/s² verso sinistra',
  );
  check(
    'opposite-new-values',
    mechanics,
    'Una massa di 4 kg subisce 3 N verso destra e 11 N verso sinistra. Qual è l’accelerazione?',
    r'^2 m/s² verso sinistra',
  );
  check(
    'conflicting-inputs',
    mechanics,
    'La massa è 2 kg e la massa è 4 kg. La forza risultante è 8 N. Qual è l’accelerazione?',
    r'non determinabile.*conflitto',
    unknown: true,
  );
  check(
    'negative-mass',
    mechanics,
    'La massa è -2 kg e la forza risultante è 8 N. Qual è l’accelerazione?',
    r'non determinabile.*positiva',
    unknown: true,
  );
  final chain = [
    const ReadingSource435(
      '1',
      'Tutti i sensori sono dispositivi.',
      'Classi 1',
      'local://classes/1',
    ),
    const ReadingSource435(
      '2',
      'Tutti i dispositivi sono oggetti.',
      'Classi 2',
      'local://classes/2',
    ),
    const ReadingSource435(
      '3',
      'Lumo è un sensore.',
      'Istanza',
      'local://classes/3',
    ),
  ];
  check(
    'classes-across-documents',
    '',
    'Lumo è un oggetto? Spiega la catena.',
    r'^sì',
    sources: chain,
  );
  check(
    'classes-missing-link',
    '',
    'Lumo è un oggetto?',
    r'non determinabile.*regola',
    unknown: true,
    sources: [chain.first, chain.last],
  );
  check(
    'classes-conflict',
    '',
    'Lumo è un oggetto?',
    r'non determinabile.*conflitto',
    unknown: true,
    sources: [
      ...chain,
      const ReadingSource435(
        '4',
        'Lumo non è un oggetto.',
        'Negazione',
        'local://classes/4',
      ),
    ],
  );
  check(
    'classes-converse',
    '',
    'Di Pico sappiamo solo che è un oggetto. Possiamo concludere che è un dispositivo? Giustifica.',
    r'^no',
    sources: chain,
  );
  check(
    'classes-no-person-answer',
    '',
    'Nilo è un oggetto?',
    '',
    unsupported: true,
    sources: chain,
  );
  const ledger =
      'Nadia ha 80 crediti. Compra quattro biglietti che costano 9 crediti ciascuno, senza sconti. Poi riceve un accredito di 6 crediti. Non ci sono altre entrate o spese. Se restituisce un biglietto, il negozio restituisce esattamente i 9 crediti pagati.';
  check(
    'ledger-new-entities',
    ledger,
    'Quanto denaro resta a Nadia dopo acquisto e accredito? Mostra il calcolo.',
    r'^50 crediti',
  );
  check(
    'ledger-new-return',
    ledger,
    'Nadia restituisce due biglietti. Quanto ha ora?',
    r'^68 crediti',
  );
  check(
    'ledger-new-purchase',
    ledger,
    'Nadia compra anche due biglietti. Quanto ha ora?',
    r'^32 crediti',
  );
  check(
    'ledger-unknown-price',
    ledger,
    'Nadia compra anche una guida. Qual è il saldo finale?',
    r'non determinabile.*prezzo',
    unknown: true,
  );
  check(
    'ledger-open-world',
    ledger.replaceAll('Non ci sono altre entrate o spese.', ''),
    'Quanto denaro resta a Nadia?',
    r'non determinabile.*altre entrate',
    unknown: true,
  );
  const story =
      'Alle 14:00 Elio mette il pacco nel deposito. Alle 15:00 Sara sposta lo stesso pacco dal deposito alla cassa verde. Elio non vede questo spostamento e nessuno glielo racconta. Dopo Sara nessuno sposta il pacco.';
  check(
    'events-new-object',
    story,
    'Dove si trova il pacco alle 16:00? Spiega.',
    r'cassa verde',
  );
  check(
    'events-before-change',
    story,
    'Dove si trova il pacco alle 14:30?',
    r'deposito',
  );
  check(
    'perspective-new-person',
    story,
    'Dove cercherà per prima Elio, basandosi solo su ciò che sa?',
    r'deposito',
  );
  check(
    'events-open-world',
    story.replaceAll('Dopo Sara nessuno sposta il pacco.', ''),
    'Dove si trova il pacco alle 16:00?',
    r'non determinabile.*spostamenti',
    unknown: true,
  );
  const times =
      'Irene esce di casa alle 13:44 e impiega esattamente sei minuti per raggiungere la fermata. Gli autobus partono alle 13:50 e alle 14:10, senza ritardi. Il viaggio dura quindici minuti e termina davanti all’ufficio.';
  check(
    'schedule-boundary',
    times,
    'A che ora Irene arriva all’ufficio? Mostra i passaggi.',
    r'14:05',
  );
  check(
    'schedule-changed-start',
    times,
    'Se Irene esce invece alle 13:45, arriva entro le 14:15? Mostra i passaggi.',
    r'^no.*14:25',
  );
  check(
    'schedule-exhausted',
    times,
    'Se Irene esce invece alle 14:20, a che ora arriva?',
    r'non determinabile.*partenza',
    unknown: true,
  );
  const data =
      'La media di C passa da 12 a 15; quella di D da 4 a 9. Il miglioramento è la media finale meno quella iniziale.';
  check(
    'data-endpoint-versus-gain',
    data,
    'Quale classe migliora di più? Mostra il calcolo.',
    r'^la classe d',
  );
  check(
    'data-endpoint',
    data,
    'Quale classe ha la media finale più alta?',
    r'^la classe c',
  );
  check(
    'data-counterfactual',
    data,
    'Se la media iniziale di C fosse 10 e tutti gli altri dati restassero uguali, quale classe migliorerebbe di più?',
    r'^nessuna',
  );
  const rule = 'Se il sensore è spento, il robot Z non può rilevare ostacoli.';
  check(
    'conditional-new-action',
    rule,
    'Il sensore è spento. Il robot Z può ancora rilevare ostacoli? Spiega.',
    r'^no',
  );
  check(
    'conditional-premise-missing',
    rule,
    'Il robot Z può rilevare ostacoli?',
    r'non determinabile.*condizione',
    unknown: true,
  );
  check(
    'conditional-negated-premise',
    rule,
    'Il sensore non è spento. Il robot Z può rilevare ostacoli?',
    r'non determinabile.*condizione',
    unknown: true,
  );
  check(
    'new-verb-recall',
    'I motori azionano le pompe.',
    'Che cosa azionano i motori?',
    r'pompe',
  );
  check(
    'specific-missing-property',
    'La temperatura del serbatoio non è nota.',
    'Qual è la temperatura del serbatoio? Indica che cosa manca.',
    r'non determinabile.*temperatura',
    unknown: true,
  );
  check(
    'source-conflict',
    '',
    'La portata vale 18 e la durata vale 3. Quanto vale la resa?',
    r'non determinabile.*conflitto',
    unknown: true,
    sources: [
      ReadingSource435(
        'one',
        division.split('.').first,
        'Divisione',
        'local://division',
      ),
      ReadingSource435(
        'two',
        product.split('.').first,
        'Prodotto',
        'local://product',
      ),
    ],
  );
  check(
    'no-installed-equation',
    'Questo testo parla di oggetti.',
    'La massa vale 2 e la forza risultante vale 6. Qual è l’accelerazione?',
    '',
    unsupported: true,
  );
  return rows;
}
