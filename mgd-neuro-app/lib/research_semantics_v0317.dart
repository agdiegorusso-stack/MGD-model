part of 'web_knowledge_explorer_v11.dart';

/// Deterministic evidence handling. Geometry/frequency never constitute proof.
/// Unknown syntax is retained, not counted as an affirmative support.
class ResearchSemantics317 {
  static const properties = <String, String>{
    'P31': 'istanza di',
    'P279': 'sottoclasse di',
    'P361': 'parte di',
    'P527': 'ha parte',
    'P17': 'paese',
    'P131': 'si trova in',
    'P171': 'taxon superiore',
    'P366': 'serve per',
    'P495': 'paese di origine',
  };
  static const _words = <String, String>{
    'amminoacido': 'aminoacid',
    'amminoacidi': 'aminoacid',
    'aminoacido': 'aminoacid',
    'aminoacidi': 'aminoacid',
    'proteinogenico': 'proteinogenic',
    'proteinogenici': 'proteinogenic',
    'proteinogenica': 'proteinogenic',
    'proteinogeniche': 'proteinogenic',
    'vivente': 'living',
    'viventi': 'living',
    'organismo': 'organism',
    'organismi': 'organism',
    'organism': 'organism',
    'organisms': 'organism',
    'organizzazione': 'organization',
    'organizzazioni': 'organization',
    'organization': 'organization',
    'organizations': 'organization',
    'cellula': 'cell',
    'cellule': 'cell',
    'cell': 'cell',
    'cells': 'cell',
    'molecola': 'molecule',
    'molecole': 'molecule',
    'molecule': 'molecule',
    'molecules': 'molecule',
    'monomero': 'monomer',
    'monomeri': 'monomer',
    'monomer': 'monomer',
    'monomers': 'monomer',
    'nucleotide': 'nucleotide',
    'nucleotidi': 'nucleotide',
    'nucleotides': 'nucleotide',
    'acido': 'acid',
    'acidi': 'acid',
    'acid': 'acid',
    'acids': 'acid',
    'nucleico': 'nucleic',
    'nucleici': 'nucleic',
    'nucleic': 'nucleic',
    'proteina': 'protein',
    'proteine': 'protein',
    'protein': 'protein',
    'proteins': 'protein',
    'cane': 'dog',
    'cani': 'dog',
    'dog': 'dog',
    'dogs': 'dog',
    'mammifero': 'mammal',
    'mammiferi': 'mammal',
    'mammal': 'mammal',
    'mammals': 'mammal',
    'componente': 'component',
    'componenti': 'component',
    'component': 'component',
    'components': 'component',
  };
  static const _articles = {
    'il',
    'lo',
    'la',
    'i',
    'gli',
    'le',
    'un',
    'uno',
    'una',
    'l',
    'the',
    'a',
    'an',
  };
  static String norm(String s) => _n11(s);
  static List<String> tokens(String s) =>
      norm(s).split(' ').where((w) => w.isNotEmpty).toList();
  static String word(String w) => _words[w] ?? w;
  static String concept(String s) {
    final xs = tokens(s);
    while (xs.isNotEmpty && _articles.contains(xs.first)) {
      xs.removeAt(0);
    }
    return xs
        .map(
          (w) => const {
            'degli',
            'dei',
            'delle',
            'della',
            'del',
            'di',
            'of',
          }.contains(w)
              ? 'of'
              : word(w),
        )
        .join(' ')
        .replaceAll('nucleic acid', 'acid nucleic');
  }

  static String relation(String r) => switch (norm(r)) {
        'composto da' ||
        'costituito da' ||
        'comprende' ||
        'contiene' =>
          'ha parte',
        _ => norm(r),
      };
  static String digest(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
  static String canonicalUrl(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u == null || u.host.isEmpty) return raw.trim();
    final q = Map<String, String>.from(u.queryParameters)
      ..removeWhere((k, _) => k.startsWith('utm_') || k == 'fbclid');
    final clean = q.isEmpty
        ? u.replace(
            scheme: 'https',
            host: u.host.toLowerCase(),
            fragment: '',
            query: '',
          )
        : u.replace(
            scheme: 'https',
            host: u.host.toLowerCase(),
            fragment: '',
            queryParameters: q,
          );
    return clean.toString().replaceAll(RegExp(r'[/?#]+$'), '');
  }

  static String family(WebDocument11 d) {
    final doi = RegExp(
      r'10\.\d{4,9}/[^\s?#]+',
      caseSensitive: false,
    ).firstMatch('${d.family} ${d.url}');
    if (doi != null) return 'paper:doi:${doi.group(0)!.toLowerCase()}';
    final host = Uri.tryParse(d.url)?.host.toLowerCase() ?? '';
    if (host.endsWith('.wikipedia.org') ||
        host == 'wikidata.org' ||
        host.endsWith('.wikidata.org')) return 'wikimedia';
    return d.family.trim().isNotEmpty ? d.family : host;
  }

  static bool sameSubject(String a, String b) => concept(a) == concept(b);
  static bool sameObject(String a, String b) => concept(a) == concept(b);
  static bool _objectSupports(String actual, String requested) {
    final a = concept(actual), b = concept(requested);
    if (a == b) return true;
    if (b.isEmpty) return false;
    if (a.startsWith('$b ')) {
      final tail = a.substring(b.length).trim();
      // Only an explicitly more specific definition, not arbitrary word overlap.
      return RegExp(
        r'^(?:compost|costituit|composed|consisting|formato|formati|che |which |that )',
      ).hasMatch(tail);
    }
    return RegExp(
          r'^(?:organic|organica|organico|biological|biologica|biologico)\s+',
        ).hasMatch(a) &&
        _objectSupports(a.substring(a.indexOf(' ') + 1), b);
  }

  static String claimKey(ExtractedClaim11 c) => digest([
        c.subjectSenseKey ?? concept(c.subject),
        relation(c.relation),
        c.meta317['objectSenseKey'] ?? concept(c.object),
        c.meta317['qualifiers'] ?? {},
      ]);
  static bool equivalent(ExtractedClaim11 a, ResearchClaim11 b) =>
      (a.subjectSenseKey ?? '') == (b.subjectSenseKey ?? '') &&
      sameSubject(a.subject, b.subject) &&
      relation(a.relation) == relation(b.relation) &&
      sameObject(a.object, b.object) &&
      (a.meta317['objectSenseKey'] ?? '') ==
          (b.meta317['objectSenseKey'] ?? '') &&
      jsonEncode(a.meta317['qualifiers'] ?? {}) ==
          jsonEncode(b.meta317['qualifiers'] ?? {});

  static final _domainLead322 = RegExp(
      r'^In\s+(?:chimica|biologia|fisica|matematica|medicina|ecologia|genetica)\s*,\s*',
      caseSensitive: false);

  static bool _invalidSubject322(String subject) =>
      subject.contains(RegExp(r'[,;:]')) ||
      RegExp(r'^(?:uno|una|due|tre|[0-9]+)\s+(?:dei|degli|delle|di)\b',
              caseSensitive: false)
          .hasMatch(subject.trim());

  static bool _ambiguousCopula322(String subject, String object) {
    if (RegExp(
            r'^(?:spesso|talvolta|generalmente|solitamente|principalmente|normalmente|identificat[oaie]|distint[oaie]|definit[oaie]|classificat[oaie]|caratterizzat[oaie]|considerat[oaie]|suddivis[oaie]|chiamat[oaie])\b',
            caseSensitive: false)
        .hasMatch(object.trim())) return true;
    if (RegExp(r'^(?:in|nel|nella|nei|nelle|su|sul|sulla|per|con|tra|fra)\s+',
            caseSensitive: false)
        .hasMatch(object.trim())) return true;
    if (!RegExp(r'^(?:il|lo|la|i|gli|le)\s+|^l[’\x27]', caseSensitive: false)
        .hasMatch(object.trim())) return false;
    // A definite nominal can be a description of the same class ("gli
    // amminoacidi che..."). A different head can instead be inverse naming
    // or enumeration; this reader cannot safely turn it into X is-a Y.
    final s = concept(subject).split(' ').first;
    final o = concept(object).split(' ').first;
    return s != o;
  }

  static String? extractionIssue322(ResearchClaim11 claim) {
    if (claim.meta317['extractor'] != 'rules317') return null;
    if (_invalidSubject322(claim.subject))
      return 'Il soggetto contiene un inciso o un’enumerazione non risolta.';
    if (relation(claim.relation) == 'tipo di' &&
        claim.meta317['classRelation321'] != true &&
        _ambiguousCopula322(claim.subject, claim.object))
      return 'Copula ambigua: il testo non giustifica una relazione di appartenenza a una classe.';
    return null;
  }

  static int reviewExtractions322(
      PlasticLanguageBrain04 brain, MgdWorld06 world, ResearchMemory11 memory) {
    if (memory.state317['extractionReview322Complete'] == true) return 0;
    var changed = 0;
    for (final c in memory.claims.values) {
      final reason = extractionIssue322(c);
      if (reason == null || c.status == 'corretta_utente') continue;
      c.meta317['extractionReview322'] = reason;
      final before = c.status;
      reevaluate(brain, world, memory, c);
      for (final s in memory.sessions) {
        if ((s.audit315['decisions'] as List? ?? [])
            .whereType<Map>()
            .any((d) => d['claimKey'] == c.key)) {
          _recordDecision(s, c, before);
          _summary(memory, s);
        }
      }
      changed++;
    }
    memory.state317['extractionReview322Complete'] = true;
    memory.state317['extractionReview322Count'] = changed;
    return changed;
  }

  static List<ExtractedClaim11> extract(
    String subject,
    String sentence,
    WebDocument11 doc, {
    bool implicit = false,
  }) {
    var text = sentence
        .replaceAll(RegExp(r'\[[0-9, –-]+\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length < 8 || text.length > 1400 || _invalidSubject322(subject))
      return [];
    // Parentheses may contain conditions; do not erase them from evidence.
    if (RegExp(
      r'\b(?:se|qualora|forse|potrebbe|potrebbero|might|may|could|if|unless)\b',
      caseSensitive: false,
    ).hasMatch(text)) return [];
    final terms = tokens(subject);
    if (terms.isEmpty) return [];
    final domain = _domainLead322.firstMatch(text);
    var body = domain == null ? text : text.substring(domain.end);
    body = body.replaceFirst(
      RegExp(
        r'^(?:il|lo|la|i|gli|le|un|uno|una|the|a|an)\s+|^l[’\x27]',
        caseSensitive: false,
      ),
      '',
    );
    final scope = RegExp(
      r'^(alcuni|alcune|molti|molte|some|many|tutti|tutte|all)\s+',
      caseSensitive: false,
    ).firstMatch(body);
    final qualifiers = <String, dynamic>{
      if (domain != null) 'domainContext': domain.group(0)!.trim(),
    };
    if (scope != null) {
      qualifiers['scope'] = scope.group(1)!.toLowerCase();
      body = body.substring(scope.end);
    }
    final variants = <String>{subject};
    final phrasePattern = terms.map((term) {
      final forms = {
        term,
        ..._words.keys.where((k) => word(k) == word(term)),
      };
      return '(?:${forms.map(RegExp.escape).join('|')})';
    }).join(r'\s+');
    if (terms.length == 1) {
      variants.addAll(_words.keys.where((k) => word(k) == word(terms.single)));
    }
    Match? start;
    for (final v in variants) {
      final m = RegExp(
        '^${RegExp.escape(v)}(?=\\s|,|\\()',
        caseSensitive: false,
      ).firstMatch(body);
      if (m != null) {
        start = m;
        break;
      }
    }
    start ??= RegExp(
      '^$phrasePattern(?=\\s|,|\\()',
      caseSensitive: false,
    ).firstMatch(body);
    var implied = false;
    if (start != null) {
      body = body.substring(start.end).trimLeft();
      final app = RegExp(
        r'^,\s*(?:detto|detta|chiamato|chiamata|also called)[^,]{1,100},\s*',
        caseSensitive: false,
      ).firstMatch(body);
      if (app != null) body = body.substring(app.end);
    } else if (implicit && sameSubject(doc.title, subject)) {
      implied = true;
    } else {
      return [];
    }
    var negative = false;
    if (RegExp(r'^(?:non|not|never)\s+', caseSensitive: false).hasMatch(body)) {
      negative = true;
      body = body.replaceFirst(
        RegExp(r'^(?:non|not|never)\s+', caseSensitive: false),
        '',
      );
    }
    body = body.replaceFirstMapped(
      RegExp(r'^(is|are)\s+not\s+', caseSensitive: false),
      (m) {
        negative = true;
        return '${m[1]} ';
      },
    );
    final rules = <({String pattern, String rel})>[
      (
        pattern: r'^(?:è|sono)\s+(?:(?:una|un)\s+)?sottoclass[ei]\s+di\s+(.+)',
        rel: 'sottoclasse di'
      ),
      (
        pattern: r'^(?:è|sono)\s+(?:(?:una|un)\s+)?istanz[ae]\s+di\s+(.+)',
        rel: 'istanza di'
      ),
      (
        pattern:
            r'^(?:si trova|si trovano)\s+(?:in|nel|nella|nei|nelle)\s+(.+)',
        rel: 'si trova in'
      ),
      (
        pattern: r'^(?:vive|vivono)\s+(?:in|nel|nella|nei|nelle)\s+(.+)',
        rel: 'vive in'
      ),
      (pattern: r'^(?:mangia|mangiano)\s+(.+)', rel: 'mangia'),
      (pattern: r'^(?:studia|studiano)\s+(.+)', rel: 'studia'),
      (pattern: r'^(?:produce|producono)\s+(.+)', rel: 'produce'),
      (pattern: r'^(?:unisce|uniscono)\s+(.+)', rel: 'unisce'),
      (
        pattern:
            r'^(?:è|sono|is|are)\s+(?:compost[oaie]|costituit[oaie]|format[oaie])\s+da\s+(.+)',
        rel: 'ha parte',
      ),
      (
        pattern: r'^(?:is|are)\s+(?:composed|made|comprised)\s+of\s+(.+)',
        rel: 'ha parte',
      ),
      (
        pattern: r'^(?:consists?|consistono|consiste)\s+(?:of|di|in)\s+(.+)',
        rel: 'ha parte',
      ),
      (
        pattern:
            r'^(?:fa|fanno)\s+parte\s+(?:di|del|della|dei|degli|delle)\s+(.+)',
        rel: 'parte di',
      ),
      (
        pattern:
            r'^(?:è|sono|is|are)\s+(?:parte|part|componenti|components)\s+(?:di|del|della|dei|degli|delle|of)\s+(.+)',
        rel: 'parte di',
      ),
      (
        pattern:
            r'^(?:contiene|contengono|comprende|comprendono|contains?|includes?)\s+(.+)',
        rel: 'ha parte',
      ),
      (
        pattern:
            r'^(?:è|sono|is|are)\s+(?:(?:un|una|a)\s+)?(?:tipo|tipi|classe|classi|sottoclasse|type|kind|class)\s+(?:di|of)\s+(.+)',
        rel: 'tipo di',
      ),
      (pattern: r'^(?:serve|servono)\s+(?:a|per)\s+(.+)', rel: 'serve per'),
      (
        pattern: r'^(?:consente|consentono|permette|permettono)\s+di\s+(.+)',
        rel: 'serve per',
      ),
      (
        pattern: r'^(?:ha|hanno|possiede|possiedono|has|have)\s+(.+)',
        rel: 'ha',
      ),
      (
        pattern: r'^(?:è|sono|is|are)\s+(?:(?:un|uno|una|a|an)\s+)?(.+)',
        rel: 'tipo di',
      ),
    ];
    for (final r in rules) {
      final m = RegExp(r.pattern, caseSensitive: false).firstMatch(body);
      if (m == null) continue;
      var object = m.group(1)!.replaceAll(RegExp(r'[.;:]+$'), '').trim();
      if (r == rules.last && _ambiguousCopula322(subject, object)) return [];
      if (r.rel == 'tipo di' &&
          RegExp(
            r'^(?:non|not|stato|stata|stati|state|studiat|usato|usata|used|studied|found|shown|associat|dovut|causat|situat|compost|costituit)',
            caseSensitive: false,
          ).hasMatch(object)) return [];
      if (object.contains('(') || object.contains(')'))
        qualifiers['parentheticContext'] = true;
      final cardinal = RegExp(
        r'^(una o più|uno o più|one or more|due|tre|two|three|[0-9]+)\s+',
        caseSensitive: false,
      ).firstMatch(object);
      if (cardinal != null) {
        qualifiers['cardinality'] = cardinal.group(1);
        object = object.substring(cardinal.end);
      }
      // Keep restrictive clauses in the proposition, never truncate conditions.
      if (object.length < 2 ||
          object.length > 300 ||
          sameSubject(subject, object)) return [];
      return [
        ExtractedClaim11(
          subject: subject,
          relation: r.rel,
          object: object,
          sentence: text,
          source: doc,
          quality: implied ? 0.75 : 0.92,
          meta317: {
            'extractor': 'rules317',
            'polarity': negative ? -1 : 1,
            'qualifiers': qualifiers,
            'implicitSubject': implied,
            'classRelation321': r.rel == 'sottoclasse di' ||
                r.rel == 'istanza di' ||
                (r.rel == 'tipo di' &&
                    RegExp(r'^(?:è|sono|is|are)\s+(?:(?:un|una|a)\s+)?(?:tipo|tipi|classe|classi|type|kind|class)\s+',
                            caseSensitive: false)
                        .hasMatch(body)),
          },
        ),
      ];
    }
    return [];
  }

  /// Read explicit subjects in a multi-topic document. Never infer an omitted
  /// subject from a previous sentence or remove a negation/condition.
  static List<ExtractedClaim11> extractAny321(
      String sentence, WebDocument11 doc) {
    if (sentence.trim().endsWith('?')) return [];
    final m = RegExp(
            r'^(.{2,100}?)\s+(?=(?:non\s+)?(?:è|sono|ha|hanno|contiene|contengono|comprende|comprendono|serve|servono|consente|consentono|permette|permettono|fa|fanno|si trova|si trovano|vive|vivono|mangia|mangiano|studia|studiano|produce|producono|unisce|uniscono)\s)',
            caseSensitive: false)
        .firstMatch(sentence.trim().replaceFirst(_domainLead322, ''));
    if (m == null) return [];
    final subject = m[1]!.replaceFirst(
        RegExp(r'^(?:il|lo|la|i|gli|le|un|uno|una)\s+|^l[’\x27]',
            caseSensitive: false),
        '');
    if (RegExp(
            r'^(?:esso|essa|essi|esse|questo|questa|ciò|se|forse|alcuni|alcune)\b',
            caseSensitive: false)
        .hasMatch(subject)) return [];
    return extract(subject, sentence, doc);
  }

  static List<String> queryForms318(String topic) {
    const singular = {
      'organismi': 'organismo',
      'amminoacidi': 'amminoacido',
      'aminoacidi': 'aminoacido',
      'proteinogenici': 'proteinogenico',
      'viventi': 'vivente',
      'cellule': 'cellula',
      'molecole': 'molecola',
      'proteine': 'proteina',
      'nucleotidi': 'nucleotide',
      'mammiferi': 'mammifero',
    };
    final single = tokens(topic).map((w) => singular[w] ?? w).join(' ');
    final plural = {for (final e in singular.entries) e.value: e.key};
    final pluralForm = tokens(topic).map((w) => plural[w] ?? w).join(' ');
    return {
      topic.trim(),
      single,
      pluralForm,
    }.where((v) => v.isNotEmpty).toList();
  }

  static List<ExtractedClaim11> extractDocument318(
    String topic,
    String text,
    WebDocument11 doc, {
    bool first = false,
  }) {
    final isWiki = doc.provider == 'Wikipedia IT';
    final subject = isWiki ? doc.title : topic;
    final xs = extract(
      subject,
      text,
      doc,
      implicit: first && sameSubject(doc.title, subject),
    );
    return xs.map((x) {
      final qid = '${doc.meta318['wikidataId'] ?? ''}';
      final identified = isWiki && RegExp(r'^Q[1-9][0-9]*$').hasMatch(qid);
      return ExtractedClaim11(
        subject: x.subject,
        relation: x.relation,
        object: x.object,
        sentence: x.sentence,
        source: doc,
        quality: x.quality,
        subjectSenseKey: identified ? 'wikidata:$qid' : x.subjectSenseKey,
        subjectSenseLabel: identified ? doc.title : x.subjectSenseLabel,
        meta317: {
          ...x.meta317,
          'reader318': true,
          if (doc.meta318['resolvedTopic'] == true ||
              sameSubject(topic, subject))
            'queryAliases318': [topic, doc.title],
          if (identified) 'identityResolution318': doc.url,
        },
      );
    }).toList();
  }

  static String assess(
    String sentence, {
    required String subject,
    required String rel,
    required String object,
    Set<String> aliases = const {},
    String title = '',
  }) {
    final d = WebDocument11(
      provider: 'verification',
      family: '',
      title: title,
      url: '',
      text: sentence,
      trust: 0,
    );
    for (final alias in {subject, ...aliases}) {
      for (final x in extract(alias, sentence, d)) {
        final q = Map<String, dynamic>.from(
          x.meta317['qualifiers'] as Map? ?? {},
        );
        // A restricted subset cannot confirm an unrestricted universal claim.
        if (q.containsKey('scope') &&
            !{'tutti', 'tutte', 'all'}.contains(q['scope'])) continue;
        final r = relation(rel), xr = relation(x.relation);
        if ((r == xr || (r == 'sottoclasse di' && xr == 'tipo di')) &&
            _objectSupports(x.object, object))
          return x.meta317['polarity'] == -1 ? 'contradiction' : 'support';
      }
    }
    return 'unknown';
  }

  static Map<String, dynamic> evaluate(ExtractedClaim11 c) {
    final m = c.meta317;
    if (m['extractor'] == 'wikidata317') {
      final valid = c.subjectSenseKey?.startsWith('wikidata:') == true &&
          '${m['objectSenseKey'] ?? ''}'.startsWith('wikidata:') &&
          properties[m['property']] == relation(c.relation) &&
          '${m['statementId'] ?? ''}'.isNotEmpty;
      return {
        'verdict': valid && m['rank'] != 'deprecated' ? 'support' : 'unknown',
        'reason': valid
            ? 'Dichiarazione strutturata identificata; riferimenti e qualificatori conservati.'
            : 'Identità/proprietà della dichiarazione incompleta.',
      };
    }
    final verdict = assess(
      c.sentence,
      subject: c.subject,
      rel: c.relation,
      object: c.object,
      title: c.source.title,
      aliases: Set<String>.from(c.meta317['subjectAliases320'] as List? ?? []),
    );
    if (verdict != 'unknown')
      return {
        'verdict': verdict,
        'reason':
            'Relazione direzionale esplicita, non semplice co-occorrenza.',
      };
    // Scoped direct extractions can be documented WITH their qualifiers.
    if (m['extractor'] == 'rules317') {
      final xs = extract(
        c.subject,
        c.sentence,
        c.source,
        implicit: m['implicitSubject'] == true,
      );
      if (xs.any(
        (x) =>
            relation(x.relation) == relation(c.relation) &&
            sameObject(x.object, c.object),
      ))
        return {
          'verdict': m['polarity'] == -1 ? 'contradiction' : 'support',
          'reason': 'Frase esplicita con contesto/qualificatori conservati.',
        };
    }
    return {
      'verdict': 'unknown',
      'reason':
          'Non interpretabile con le regole disponibili; non conteggiata come prova.',
    };
  }

  static List<ExtractedClaim11> structured(
    Map<String, dynamic> entity,
    Map labels, {
    required String id,
    required String label,
    required String gloss,
  }) {
    final out = <ExtractedClaim11>[];
    final claims = entity['claims'];
    if (claims is! Map) return out;
    final doc = WebDocument11(
      provider: 'Wikidata proprietà',
      family: 'wikimedia',
      title: '$label — $gloss',
      url: 'https://www.wikidata.org/wiki/$id',
      text: '',
      trust: 0.94,
    );
    for (final p in properties.entries) {
      final rows = claims[p.key];
      if (rows is! List) continue;
      for (final row in rows.whereType<Map>()) {
        final snak = row['mainsnak'];
        if (snak is! Map || snak['snaktype'] != 'value') continue;
        final dv = snak['datavalue'];
        if (dv is! Map || dv['value'] is! Map) continue;
        final oid = '${(dv['value'] as Map)['id'] ?? ''}';
        final obj = labels[oid];
        if (obj is! Map || obj['labels'] is! Map) continue;
        final ls = obj['labels'] as Map;
        final l = ls['it'] ?? ls['en'];
        if (l is! Map) continue;
        final name = '${l['value'] ?? ''}';
        if (name.isEmpty) continue;
        out.add(
          ExtractedClaim11(
            subject: label,
            relation: p.value,
            object: name,
            sentence: 'Wikidata: $label — ${p.value} → $name',
            source: doc,
            quality: 0.98,
            subjectSenseKey: 'wikidata:$id',
            subjectSenseLabel: label,
            subjectSenseGloss: gloss,
            meta317: {
              'extractor': 'wikidata317',
              'property': p.key,
              'objectSenseKey': 'wikidata:$oid',
              'statementId': row['id'] ?? '',
              'rank': row['rank'] ?? 'normal',
              'qualifiers': row['qualifiers'] ?? {},
              'references': row['references'] ?? [],
              'revision': entity['lastrevid'],
              'rawStatement': Map<String, dynamic>.from(row),
            },
          ),
        );
      }
    }
    return out;
  }

  static ResearchOutcome11 integrate(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory11 memory,
    ResearchDraft11 draft,
  ) {
    final iso = DateTime.now().toIso8601String();
    // A structured API statement also has a source document. Keep it in the
    // session's inspectable intake, even if the provider returned no prose page.
    final documents = <String, WebDocument11>{};
    for (final d in [
      ...draft.documents,
      ...draft.claims.map((c) => c.source)
    ]) {
      documents.putIfAbsent(digest([canonicalUrl(d.url), d.text]), () => d);
    }
    final session = ResearchSession11(
      topic: draft.goal.topic,
      query: draft.goal.query,
      reason: draft.goal.reason,
      startedAtIso: iso,
    );
    session.documents = documents.length;
    session.sentencesRead = 0;
    session.sources.addAll(documents.values.map((d) => d.provider).toSet());
    session.providers = documents.values.map((d) => d.provider).toSet().length;
    session.families = documents.values.map(family).toSet().length;
    session.audit315.addAll({
      'version': '0.32.2',
      'documents': documents.values.map(docMap).toList(),
      'providerDiagnostics': draft.diagnostics318,
      'decisions': <Map<String, dynamic>>[],
      'verification': <Map<String, dynamic>>[],
      'candidates': <Map<String, dynamic>>[],
      'preliminarySentencesRead': draft.sentencesRead,
      'extractions':
          draft.claims.map(WebKnowledgeExplorer11.candidateRecord315).toList(),
      'nota':
          'Documentata = supporto diretto da una fonte; corroborata = gruppi di provenienza distinti, indipendenza scientifica non certificata.',
    });
    // Count the actual preliminary reading as well as later queue work.
    // The document/sentence key prevents counting the same reading twice.
    var preliminary = draft.sentencesRead;
    for (final d in draft.documents.take(10)) {
      for (final sentence
          in WebKnowledgeExplorer11._sentences(d.text).take(24)) {
        if (preliminary-- <= 0) break;
        recordSentence321(session, d, sentence, phase: 'lettura iniziale');
      }
    }
    memory.sessions.add(session);
    if (draft.error != null) {
      session.status = 'errore';
      memory.lastError = draft.error;
      memory.lastStatus = 'Ricerca fallita: ${draft.error}';
      return ResearchOutcome11(memory.lastStatus, 0, 0, 0);
    }
    for (final p in draft.passages) {
      if (!memory.passages.any(
        (x) => x.sourceUrl == p.sourceUrl && x.text == p.text,
      )) memory.passages.add(p);
    }
    final ordered = List<ExtractedClaim11>.of(draft.claims)
      ..sort(
        (a, b) => (b.subjectSenseKey != null ? 1 : 0).compareTo(
          a.subjectSenseKey != null ? 1 : 0,
        ),
      );
    for (final c in ordered) {
      _observe(brain, world, memory, c, session);
    }
    enqueue(memory, draft.documents, topic: draft.goal.topic, session: iso);
    processQueue(brain, world, memory, maxUnits: 24);
    _summary(memory, session);
    memory.lastError = null;
    memory.trim();
    return ResearchOutcome11(
      memory.lastStatus,
      session.audit315['newUsable321'] as int? ?? 0,
      session.doubtful,
      session.contradictions,
    );
  }

  static void recordSentence321(
      ResearchSession11 s, WebDocument11 d, String text,
      {required String phase}) {
    final rows = s.audit315
        .putIfAbsent('sentences', () => <Map<String, dynamic>>[]) as List;
    final key = digest([canonicalUrl(d.url), text]);
    if (!rows.whereType<Map>().any((x) => x['readingKey321'] == key)) {
      rows.add({
        'readingKey321': key,
        'text': text,
        'provider': d.provider,
        'sourceTitle': d.title,
        'sourceUrl': d.url,
        'fase': phase
      });
    }
    s.sentencesRead = rows.length;
  }

  static Map<String, dynamic> docMap(WebDocument11 d) => {
        'title': d.title,
        'provider': d.provider,
        'family': family(d),
        'sourceUrl': d.url,
        'text': d.text,
        'trust': d.trust,
        'meta318': d.meta318,
      };
  static WebDocument11 docFrom(Map d) => WebDocument11(
        provider: '${d['provider']}',
        family: '${d['family']}',
        title: '${d['title']}',
        url: '${d['sourceUrl']}',
        text: '${d['text'] ?? ''}',
        trust: (d['trust'] as num?)?.toDouble() ?? 0.65,
        meta318: Map<String, dynamic>.from(d['meta318'] as Map? ?? {}),
      );
  static bool needsRecovery318(ResearchMemory11 m) =>
      m.state317['recovery320Complete'] != true &&
      (m.passages.isNotEmpty ||
          m.sessions.any(
            (s) => (s.audit315['documents'] as List? ?? []).isNotEmpty,
          ));
  static int recoverTexts318(ResearchMemory11 m) {
    if (!needsRecovery318(m)) return 0;
    final before = getPending(m);
    for (final s in m.sessions) {
      final docs = (s.audit315['documents'] as List? ?? [])
          .whereType<Map>()
          .map(docFrom)
          .toList();
      enqueue(m, docs, topic: s.topic, session: s.startedAtIso);
    }
    // Passages outside the retained session audit are also kept and re-read.
    for (final p in m.passages.toList()) {
      enqueue(
        m,
        [
          WebDocument11(
            provider: p.provider,
            family: p.sourceFamily,
            title: p.sourceTitle,
            url: p.sourceUrl,
            text: p.text,
            trust: p.trust,
            meta318: p.meta318,
          ),
        ],
        topic: p.topic,
        session: 'recovery318',
      );
    }
    m.state317['recovery318Complete'] = true;
    m.state317['recovery320Complete'] = true;
    m.state317['recovery318'] = {
      'requeued': getPending(m) - before,
      'at': DateTime.now().toIso8601String(),
      'note':
          'Testi originali riletti; nessuna promozione automatica, nessuna cancellazione.',
    };
    return getPending(m) - before;
  }

  static bool needsMaintenance(ResearchMemory11 m) =>
      (m.claims.isNotEmpty &&
          m.state317['extractionReview322Complete'] != true) ||
      needsRecovery318(m) ||
      m.state317['migrationComplete'] != true ||
      getPending(m) > 0 ||
      pendingLanguage320(m).isNotEmpty ||
      m.pendingPassages321.isNotEmpty;
  static List<Map<String, dynamic>> uniqueDocuments320(ResearchMemory11 m) {
    final docs = <String, Map<String, dynamic>>{};
    for (final s in m.sessions.reversed) {
      for (final d
          in (s.audit315['documents'] as List? ?? []).whereType<Map>()) {
        final row = Map<String, dynamic>.from(d);
        docs.putIfAbsent(
          digest([canonicalUrl('${d['sourceUrl'] ?? ''}'), d['text']]),
          () => row,
        );
      }
    }
    return docs.values.toList();
  }

  static List<WebDocument11> pendingLanguage320(ResearchMemory11 m) {
    final seen = Set<String>.from(
      m.state317['languageSources320'] as List? ?? [],
    );
    final docs = <WebDocument11>[
      for (final p in m.passages)
        WebDocument11(
          provider: p.provider,
          family: p.sourceFamily,
          title: p.sourceTitle,
          url: p.sourceUrl,
          text: p.text,
          trust: p.trust,
          meta318: p.meta318,
        ),
      for (final e in m.evidence)
        WebDocument11(
          provider: e.provider,
          family: e.sourceFamily,
          title: e.sourceTitle,
          url: e.sourceUrl,
          text: e.excerpt,
          trust: e.trust,
        ),
    ];
    return docs.where((d) => !seen.contains(languageKey320(d))).toList();
  }

  static String languageKey320(WebDocument11 d) =>
      digest([canonicalUrl(d.url), norm(d.text)]);
  static void markLanguage320(ResearchMemory11 m, WebDocument11 d) {
    final seen = Set<String>.from(
      m.state317['languageSources320'] as List? ?? [],
    );
    seen.add(languageKey320(d));
    m.state317['languageSources320'] = seen.toList();
  }

  static int getPending(ResearchMemory11 m) =>
      (m.state317['queue'] as List? ?? []).length;
  static void enqueue(
    ResearchMemory11 m,
    Iterable<WebDocument11> docs, {
    required String topic,
    required String session,
  }) {
    final queue = List<Map<String, dynamic>>.from(
      (m.state317['queue'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final done = Set<String>.from(m.state317['documentsRead'] as List? ?? []);
    for (final d in docs) {
      if (d.text.trim().isEmpty) continue;
      final key = digest([
        'reader320',
        canonicalUrl(d.url),
        d.text,
        concept(topic),
      ]);
      if (done.contains(key)) continue;
      final existing = queue.where((q) => q['key'] == key).toList();
      if (existing.isNotEmpty) {
        existing.first['session'] = session;
        continue;
      }
      queue.add({
        ...docMap(d),
        'trust': d.trust,
        'topic': topic,
        'session': session,
        'key': key,
        'sentence': 0,
        'target': 0,
      });
    }
    m.state317['queue'] = queue;
  }

  static int processQueue(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory11 m, {
    int maxUnits = 24,
  }) {
    final queue = List<Map<String, dynamic>>.from(
      (m.state317['queue'] as List? ?? []).map(
        (x) => Map<String, dynamic>.from(x as Map),
      ),
    );
    final done = Set<String>.from(m.state317['documentsRead'] as List? ?? []);
    final touched = <ResearchSession11>{};
    final clock = Stopwatch()..start();
    var units = 0;
    while (queue.isNotEmpty &&
        units < maxUnits &&
        (units == 0 || clock.elapsedMilliseconds < 12)) {
      final q = queue.removeAt(0);
      final doc = docFrom(q);
      final sentences = WebKnowledgeExplorer11._sentences(doc.text);
      var i = (q['sentence'] as num?)?.toInt() ?? 0;
      if (i >= sentences.length) {
        done.add('${q['key']}');
        continue;
      }
      ResearchSession11? session;
      for (final s in m.sessions.reversed) {
        if (s.startedAtIso == q['session']) {
          session = s;
          break;
        }
      }
      final text = sentences[i];
      if (q['extracted'] != true) {
        if (session != null) {
          recordSentence321(session, doc, text, phase: 'lettura incrementale');
          final documents = session.audit315['documents'];
          if (documents is List) {
            for (final d in documents.whereType<Map>()) {
              if (d['sourceUrl'] == doc.url) d['frasi analizzate'] = i + 1;
            }
          }
        }
        final extracted = extractDocument318(
          '${q['topic']}',
          text,
          doc,
          first: i == 0,
        );
        if (extracted.isEmpty) extracted.addAll(extractAny321(text, doc));
        if (extracted.isEmpty) {
          final aliases = m.claims.values
              .where((c) =>
                  aliases320(c).any((a) => sameSubject(a, '${q['topic']}')))
              .expand(aliases320)
              .toSet();
          for (final alias in aliases) {
            extracted.addAll(extractDocument318(alias, text, doc));
          }
        }
        for (final c in extracted) {
          _observe(brain, world, m, c, session);
        }
        for (final p in m.passages) {
          if (p.sourceUrl == doc.url && p.text == text) {
            p.structured = extracted.isNotEmpty;
            p.meta318['extractorAttempt321'] = '321';
            p.lastAttemptIso = DateTime.now().toIso8601String();
          }
        }
        if (extracted.isEmpty &&
            !m.passages.any((p) => p.sourceUrl == doc.url && p.text == text)) {
          m.passages.add(
            ResearchPassage11(
              id: 'p318:${digest([canonicalUrl(doc.url), text])}',
              topic: '${q['topic']}',
              provider: doc.provider,
              sourceFamily: doc.family,
              sourceTitle: doc.title,
              sourceUrl: doc.url,
              text: text,
              trust: doc.trust,
              meta318: {...doc.meta318, 'extractorAttempt321': '321'},
            ),
          );
        }
        q['extracted'] = true;
        q['targets'] = m.claims.values
            .where(
              (c) => aliases320(c).any((a) => sameSubject(a, '${q['topic']}')),
            )
            .map((c) => c.key)
            .toList();
      }
      final targets = List<String>.from(q['targets'] as List? ?? []);
      var t = (q['target'] as num?)?.toInt() ?? 0;
      var checked = 0;
      while (t < targets.length && checked < 12) {
        final c = m.claims[targets[t++]];
        checked++;
        if (c == null) continue;
        final verdict = assess(
          text,
          subject: c.subject,
          rel: c.relation,
          object: c.object,
          title: doc.title,
          aliases: aliases320(c),
        );
        if (session != null) {
          final trace = session.audit315['verification'] as List?;
          if (trace != null && trace.length < 1000)
            trace.add({
              'claimKey': c.key,
              'sourceTitle': doc.title,
              'sourceUrl': doc.url,
              'esito': verdict,
              'Frasi confrontate': [
                {
                  'text': text,
                  'esito': verdict,
                  'motivo':
                      'Relazione e direzione esplicite; negazioni conservate.',
                },
              ],
            });
        }
        if (verdict == 'unknown') continue;
        if (c.meta317['qualifiers'] is Map &&
            (c.meta317['qualifiers'] as Map).isNotEmpty) continue;
        // Prose without explicit entity IDs cannot corroborate a homonymous sense.
        if (c.subjectSenseKey != null) {
          final xs = extractDocument318('${q['topic']}', text, doc);
          final linked = xs
              .map((x) => alignIdentity320(x, m))
              .where((x) => claimKey(x) == c.key);
          for (final x in linked) {
            _observe(brain, world, m, x, session);
          }
          continue;
        }
        _observe(
          brain,
          world,
          m,
          ExtractedClaim11(
            subject: c.subject,
            relation: c.relation,
            object: c.object,
            sentence: text,
            source: doc,
            quality: 0.90,
            meta317: {'polarity': verdict == 'contradiction' ? -1 : 1},
          ),
          session,
        );
      }
      if (t >= targets.length) {
        i++;
        q['sentence'] = i;
        q['target'] = 0;
        q['extracted'] = false;
        q.remove('targets');
      } else {
        q['target'] = t;
      }
      units++;
      if (i >= sentences.length)
        done.add('${q['key']}');
      else
        queue.add(q);
      if (session != null) touched.add(session);
    }
    m.state317['queue'] = queue;
    m.state317['documentsRead'] = done.toList();
    for (final session in touched) {
      _summary(m, session);
    }
    m.state317['lastBatchUnits'] = units;
    m.state317['lastBatchMs'] = clock.elapsedMilliseconds;
    return units;
  }

  static Set<String> aliases320(ResearchClaim11 c) => {
        c.subject,
        ...((c.meta317['queryAliases318'] as List?) ?? []).map((x) => '$x'),
      };

  static int observePassage321(
      PlasticLanguageBrain04 brain,
      MgdWorld06 world,
      ResearchMemory11 memory,
      ResearchPassage11 passage,
      List<ExtractedClaim11> claims) {
    final session = memory.sessions
        .where((s) => sameSubject(s.topic, passage.topic))
        .lastOrNull;
    final before = memory.claims.values
        .where((c) => c.meta317['usable'] == true)
        .map((c) => c.key)
        .toSet();
    for (final claim in claims) {
      _observe(brain, world, memory, claim, session);
    }
    if (session != null) _summary(memory, session);
    return memory.claims.values
        .where((c) => c.meta317['usable'] == true && !before.contains(c.key))
        .length;
  }

  /// Attach prose to a known identity only when the complete relation/object
  /// agrees and exactly one known sense fits. Word overlap is never enough.
  static ExtractedClaim11 alignIdentity320(
    ExtractedClaim11 x,
    ResearchMemory11 m,
  ) {
    if (x.subjectSenseKey != null) return x;
    final candidates = m.claims.values
        .where(
          (c) =>
              c.subjectSenseKey != null &&
              aliases320(c).any((a) => sameSubject(a, x.subject)) &&
              (relation(c.relation) == relation(x.relation) ||
                  (relation(c.relation) == 'sottoclasse di' &&
                      relation(x.relation) == 'tipo di')) &&
              sameObject(c.object, x.object) &&
              jsonEncode(c.meta317['qualifiers'] ?? {}) ==
                  jsonEncode(x.meta317['qualifiers'] ?? {}),
        )
        .toList();
    // Any other known homonymous sense needs an explicit source identity.
    final senses = m.claims.values
        .where(
          (c) =>
              c.subjectSenseKey != null &&
              aliases320(c).any((a) => sameSubject(a, x.subject)),
        )
        .map((c) => c.subjectSenseKey)
        .toSet();
    if (candidates.isEmpty || senses.length != 1) return x;
    final c = candidates.first;
    return ExtractedClaim11(
      subject: c.subject,
      relation: c.relation,
      object: c.object,
      sentence: x.sentence,
      source: x.source,
      quality: x.quality,
      subjectSenseKey: c.subjectSenseKey,
      subjectSenseLabel: c.subjectSenseLabel,
      subjectSenseGloss: c.subjectSenseGloss,
      meta317: {
        ...x.meta317,
        'queryAliases318': aliases320(c).toList(),
        'subjectAliases320': [x.subject, ...aliases320(c)],
        if (c.meta317['objectSenseKey'] != null)
          'objectSenseKey': c.meta317['objectSenseKey'],
        'identity320':
            'alias completo, relazione e oggetto coincidenti; un solo senso noto',
        'identityClaim320': c.key,
      },
    );
  }

  static void _observe(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory11 m,
    ExtractedClaim11 x,
    ResearchSession11? session,
  ) {
    x = alignIdentity320(x, m);
    var key = claimKey(x);
    ResearchClaim11? c = m.claims[key];
    if (c == null) {
      for (final old in m.claims.values) {
        if (equivalent(x, old)) {
          c = old;
          key = old.key;
          break;
        }
      }
    }
    final before = c?.status;
    final check = evaluate(x);
    final now = DateTime.now().toIso8601String();
    final evKey = 'e317:${digest([
          key,
          canonicalUrl(x.source.url),
          family(x.source),
          norm(x.sentence),
          x.meta317['statementId'],
          x.meta317['revision']
        ])}';
    ResearchEvidence11? previous;
    for (final e in m.evidence) {
      if (e.id == evKey) {
        previous = e;
        break;
      }
    }
    if (previous != null) {
      previous.meta317['lastSeen'] = now;
      if (c != null && session != null) _recordDecision(session, c, c.status);
      return;
    }
    c ??= ResearchClaim11(
      key: key,
      subject: x.subject,
      relation: relation(x.relation),
      object: x.object,
      confidence: 0,
      conflict: false,
      status: 'ipotesi_mgd',
      lastSeenIso: now,
      subjectSenseKey: x.subjectSenseKey,
      subjectSenseLabel: x.subjectSenseLabel,
      subjectSenseGloss: x.subjectSenseGloss,
    );
    final aliases = {
      ...aliases320(c),
      ...((x.meta317['queryAliases318'] as List?) ?? []).map((a) => '$a'),
    };
    c.meta317.addAll(x.meta317);
    c.meta317['queryAliases318'] = aliases.toList();
    c.meta317['engine'] = 317;
    final e = ResearchEvidence11(
      id: evKey,
      subject: x.subject,
      relation: relation(x.relation),
      object: x.object,
      provider: x.source.provider,
      sourceFamily: family(x.source),
      sourceTitle: x.source.title,
      sourceUrl: x.source.url,
      excerpt: x.sentence,
      trust: x.source.trust,
      retrievedAtIso: now,
      meta317: {
        ...x.meta317,
        ...check,
        'subjectSenseKey': x.subjectSenseKey,
        'firstSeen': now,
        'lastSeen': now,
      },
    );
    m.evidence.add(e);
    c.evidenceIds.add(evKey);
    c.lastSeenIso = now;
    m.claims[key] = c;
    reevaluate(brain, world, m, c);
    if (session != null) _recordDecision(session, c, before, evidenceId: evKey);
  }

  static void _recordDecision(
    ResearchSession11 session,
    ResearchClaim11 c,
    String? before, {
    String? evidenceId,
  }) {
    final ds = List<Map<String, dynamic>>.from(
      (session.audit315['decisions'] as List? ?? []).map(
        (x) => Map<String, dynamic>.from(x as Map),
      ),
    );
    final was = ds.where((d) => d['claimKey'] == c.key).toList();
    final original = was.isNotEmpty ? was.first['statusBefore'] : before;
    ds.removeWhere((d) => d['claimKey'] == c.key);
    ds.add({
      'claimKey': c.key,
      'subject': c.subject,
      'relation': c.relation,
      'object': c.object,
      'status': c.status,
      'statusBefore': original,
      'newClaim321': original == null,
      'newEvidenceIds321': {
        ...((was.isNotEmpty ? was.first['newEvidenceIds321'] : null) as List? ??
            []),
        if (evidenceId != null) evidenceId,
      }.toList(),
      'nuovo consolidamento':
          c.status == 'accettata' && original != 'accettata',
      'confidence': c.confidence,
      'conflict': c.conflict,
      'evidenceIds': c.evidenceIds.toList(),
      'sourceFamilies': c.sourceFamilies.toList(),
      'sourceProviders': c.sourceProviders.toList(),
      'motivi': Map<String, dynamic>.from(c.meta317),
    });
    session.audit315['decisions'] = ds;
  }

  static void reevaluate(
    PlasticLanguageBrain04 brain,
    MgdWorld06 world,
    ResearchMemory11 m,
    ResearchClaim11 c,
  ) {
    if (c.status == 'corretta_utente') return;
    final ev = m.evidence.where((e) => c.evidenceIds.contains(e.id)).toList();
    final unique = <String, ResearchEvidence11>{};
    for (final e in ev) {
      if (e.meta317['verdict'] == 'support' && e.trust >= 0.65)
        unique.putIfAbsent(
          digest([e.sourceFamily, canonicalUrl(e.sourceUrl), norm(e.excerpt)]),
          () => e,
        );
    }
    final direct = unique.values.toList();
    final negatives =
        ev.where((e) => e.meta317['verdict'] == 'contradiction').toList();
    c.sourceFamilies
      ..clear()
      ..addAll(direct.map((e) => e.sourceFamily));
    c.sourceProviders
      ..clear()
      ..addAll(direct.map((e) => e.provider));
    c.conflict = direct.isNotEmpty && negatives.isNotEmpty;
    final extractionIssue = extractionIssue322(c);
    if (extractionIssue != null)
      c.meta317['extractionReview322'] = extractionIssue;
    final suspicious = extractionIssue != null ||
        WebKnowledgeExplorer11._suspiciousKnowledge12(
          c.subject,
          c.relation,
          c.object,
        );
    final n = c.sourceFamilies.length;
    c.status = c.conflict || suspicious || negatives.isNotEmpty
        ? 'quarantena'
        : n >= 2
            ? 'accettata'
            : n == 1
                ? 'documentata'
                : 'ipotesi_mgd';
    c.confidence = c.conflict
        ? 0.25
        : n == 0
            ? 0.0
            : n == 1
                ? 0.60
                : 0.78;
    c.meta317.addAll({
      'engine': 317,
      'directSupports': direct.length,
      'negativeSupports': negatives.length,
      'verdict': c.status,
      'independence':
          'Gruppi di provenienza, non indipendenza scientifica certificata.',
      'usable': n > 0 && !c.conflict && !suspicious && negatives.isEmpty,
    });
    // Projection is not used to answer sourced questions; those use answer().
    // Retire old research-only facts even if the new evidence is weaker.
    final sid = c.subjectSenseKey == null
        ? brain.entityIdForLabel06(c.subject)
        : brain.registerLexicalSense028(
            surface: c.subject,
            senseKey: c.subjectSenseKey!,
            label: c.subjectSenseLabel ?? c.subject,
            gloss: c.subjectSenseGloss ?? '',
            confidence: 0.45,
            contextCues: [c.relation, c.object],
          );
    final unqualified = c.meta317['qualifiers'] is! Map ||
        (c.meta317['qualifiers'] as Map).isEmpty;
    final projectable = c.status == 'accettata' && unqualified;
    if (sid != null) {
      final owned = brain.reconcileResearch317(
        sid,
        c.relation,
        c.object,
        c.status == 'accettata' && !projectable ? 'documentata' : c.status,
        c.sourceFamilies,
      );
      final oid = brain.entityIdForLabel06(c.object);
      if (owned && oid != null && oid != sid && !projectable) {
        final other = m.claims.values.any(
          (x) =>
              x.key != c.key &&
              x.status == 'accettata' &&
              sameSubject(x.subject, c.subject) &&
              sameObject(x.object, c.object),
        );
        if (!other) world.retireResearchLink317(sid, oid);
      }
    }
    // Single-source documentation is usable through source-attributed retrieval,
    // not smuggled into the old unqualified fact generator.
    final projection = digest([c.status, c.sourceFamilies.toList()..sort()]);
    if (c.meta317['projection317'] == projection) return;
    c.meta317['projection317'] = projection;
    if (c.status == 'accettata' &&
        (c.meta317['qualifiers'] is! Map ||
            (c.meta317['qualifiers'] as Map).isEmpty)) {
      final s = sid ?? brain.ensureSemanticEntity06(c.subject);
      brain.importResearchFact028(
        subjectId: s,
        relation: c.relation,
        object: c.object,
        confidence: 0.65,
        sourceFamilies: c.sourceFamilies,
      );
      final o = brain.ensureSemanticEntity06(c.object);
      if (s != o)
        world.consolidateSemanticLink029(
          s,
          o,
          confidence: 0.65,
          independentFamilies: n,
        );
    }
  }

  static void _summary(ResearchMemory11 m, ResearchSession11 s) {
    final ds =
        (s.audit315['decisions'] as List? ?? []).whereType<Map>().toList();
    final keys = ds.map((d) => '${d['claimKey']}').toSet();
    final cs =
        keys.map((k) => m.claims[k]).whereType<ResearchClaim11>().toList();
    s.candidates = keys.length;
    s.integrated = cs.where((c) => c.status == 'accettata').length;
    s.doubtful = cs.where((c) => c.status == 'ipotesi_mgd').length;
    s.quarantined = cs.where((c) => c.status == 'quarantena').length;
    s.contradictions = cs.where((c) => c.conflict).length;
    final documented = cs.where((c) => c.status == 'documentata').length;
    s.audit315['documented'] = documented;
    s.audit315['candidates'] = ds;
    s.audit315['newClaims321'] =
        ds.where((d) => d['newClaim321'] == true).length;
    s.audit315['knownClaims321'] =
        ds.where((d) => d['newClaim321'] != true).length;
    s.audit315['newUsable321'] = ds
        .where((d) =>
            {'documentata', 'accettata'}.contains(d['status']) &&
            !{'documentata', 'accettata'}.contains(d['statusBefore']))
        .length;
    s.audit315['newEvidence321'] =
        ds.expand((d) => d['newEvidenceIds321'] as List? ?? []).toSet().length;
    s.audit315['candidateCounting'] =
        'Proposizioni distinte; ripetizioni nelle evidenze, non nel numero dei candidati.';
    final pending = (m.state317['queue'] as List? ?? [])
        .whereType<Map>()
        .where((q) => q['session'] == s.startedAtIso)
        .length;
    s.audit315['pendingDocuments'] = pending;
    s.learnedFacts
      ..clear()
      ..addAll(
        cs
            .where((c) => ds
                .any((d) => d['claimKey'] == c.key && d['newClaim321'] == true))
            .take(10)
            .map(
              (c) =>
                  '${c.status == 'documentata' ? 'Fonte' : c.status == 'accettata' ? 'Fonti' : '?'}: ${c.subject} — ${c.relation} → ${c.object}',
            ),
      );
    s.status = pending > 0
        ? 'lettura incrementale in corso'
        : cs.isEmpty
            ? 'testi acquisiti, nessuna proposizione interpretabile'
            : 'conoscenza documentata con provenienza';
    final failures = (s.audit315['providerDiagnostics'] as List? ?? [])
        .whereType<Map>()
        .where((d) => d['status'] == 'errore')
        .toList();
    s.audit315['providerErrors'] = failures.length;
    s.audit315['extractionNote'] = cs.isEmpty
        ? 'I testi sono conservati. Identità o sintassi non risolta: non è una conferma negativa né memoria cancellata.'
        : '';
    s.completedAtIso = pending > 0 ? '' : DateTime.now().toIso8601String();
    m.lastStatus =
        'Studio “${s.topic}”: $documented documentate, ${s.integrated} corroborate, ${s.doubtful} osservate, ${s.quarantined} da riesaminare. ${getPending(m)} documenti in coda.${cs.isEmpty ? ' ${s.documents} documenti acquisiti; nessuna proposizione interpretabile.' : ''}${failures.isNotEmpty ? ' ${failures.length} errori dei provider: apri Diagnostica ricerca.' : ''}';
  }

  static String? answer(
    String question,
    ResearchMemory11 m, {
    String? Function(String, String, String)? realize,
  }) {
    if (!question.trim().endsWith('?') &&
        !RegExp(
          r'^(?:cosa|cos[’\x27]|che|parlami|dimmi|come|quali|quale|spiega)',
          caseSensitive: false,
        ).hasMatch(question.trim())) return null;
    final qt = concept(question);
    final found = m.claims.values
        .where(
          (c) =>
              c.meta317['usable'] == true &&
              <String>[
                c.subject,
                ...((c.meta317['queryAliases318'] as List?) ?? []).map(
                  (v) => '$v',
                ),
              ].any((alias) => (' $qt ').contains(' ${concept(alias)} ')),
        )
        .toList();
    final qn = norm(question);
    final requested = RegExp(
                r'(?:compost|costituit|contien|conteng|quali parti)')
            .hasMatch(qn)
        ? 'ha parte'
        : RegExp(r'(?:a cosa serv|serve per|funzione)').hasMatch(qn)
            ? 'serve per'
            : RegExp(r'(?:dove|si trova)').hasMatch(qn)
                ? (RegExp(r'\bviv').hasMatch(qn) ? 'vive in' : 'si trova in')
                : RegExp(r'\bmangi').hasMatch(qn)
                    ? 'mangia'
                    : RegExp(r'\bprodu').hasMatch(qn)
                        ? 'produce'
                        : RegExp(r'\bstudi').hasMatch(qn)
                            ? 'studia'
                            : RegExp(r'\bunisc').hasMatch(qn)
                                ? 'unisce'
                                : null;
    if (requested != null)
      found.removeWhere((c) => relation(c.relation) != requested);
    if (found.isEmpty) {
      final legacy = m.claims.values.any(
        (c) =>
            c.meta317['engine'] != 317 &&
            (' $qt ').contains(' ${concept(c.subject)} '),
      );
      return legacy
          ? 'Le fonti di questo argomento sono ancora in riesame. Non uso il vecchio consolidamento come conferma.'
          : null;
    }
    final senses =
        found.map((c) => c.subjectSenseKey).whereType<String>().toSet();
    if (senses.length > 1)
      return 'Ho trovato significati distinti: ${found.map((c) => c.subjectSenseGloss?.isNotEmpty == true ? '${c.subject} (${c.subjectSenseGloss})' : c.subject).toSet().join('; ')}. Specifica il significato: non li considero la stessa entità.';
    found.sort((a, b) => b.confidence.compareTo(a.confidence));
    final lines = <String>[];
    for (final c in found.take(5)) {
      final ev = m.evidence
          .where(
            (e) =>
                c.evidenceIds.contains(e.id) &&
                e.meta317['verdict'] == 'support',
          )
          .toList();
      if (ev.isEmpty) continue;
      final e = ev.first;
      final conditions = c.meta317['qualifiers'];
      final statement = realize?.call(c.subject, c.relation, c.object) ??
          '${c.subject} — ${c.relation} → ${c.object}.';
      lines.add(
        '$statement\n${c.status == 'documentata' ? 'Documentata da una fonte' : 'Corroborata da ${c.sourceFamilies.length} gruppi di provenienza'}: ${e.sourceTitle} (${e.provider}).${conditions is Map && conditions.isNotEmpty ? '\nContesto/qualificatori della fonte: ${jsonEncode(conditions)}' : ''}\n${e.sourceUrl}',
      );
    }
    return lines.isEmpty ? null : lines.join('\n\n');
  }

  static void migrateClaim(
    PlasticLanguageBrain04 b,
    MgdWorld06 w,
    ResearchMemory11 m,
    ResearchClaim11 c,
  ) {
    if (c.meta317['engine'] == 317) return;
    if (c.status == 'corretta_utente') {
      c.meta317['engine'] = 317;
      c.meta317['migrationNote'] = 'Correzione esplicita utente conservata.';
      return;
    }
    final prior = {
      'status': c.status,
      'confidence': c.confidence,
      'families': c.sourceFamilies.toList(),
    };
    for (final e in m.evidence.where((e) => c.evidenceIds.contains(e.id))) {
      final d = WebDocument11(
        provider: e.provider,
        family: e.sourceFamily,
        title: e.sourceTitle,
        url: e.sourceUrl,
        text: e.excerpt,
        trust: e.trust,
      );
      final x = ExtractedClaim11(
        subject: c.subject,
        relation: c.relation,
        object: c.object,
        sentence: e.excerpt,
        source: d,
        quality: 0.7,
      );
      e.meta317.addAll(evaluate(x));
      e.meta317['legacy'] = true;
    }
    // Legacy structured rows lost P31/P279, qualifiers and object identity.
    // Preserve originals and schedule a refresh rather than inventing metadata.
    c.meta317['before317'] = prior;
    reevaluate(b, w, m, c);
    c.meta317['migrationNote'] =
        'Riesame conservativo degli estratti originali; le dichiarazioni strutturate prive dei metadati originali richiedono una nuova lettura.';
  }
}
