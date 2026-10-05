// Structured situation memory. Source text is available only during compilation.
// At recall the API accepts events, not a document, path, source index or corpus.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'book_understanding_v0342.dart';
import 'competence_language_v0350.dart';

String digest350(String s) => sha256.convert(utf8.encode(s)).toString();
String entity350(String s) =>
    bookEntity342(s).replaceAll(RegExp(r'\s+'), ' ').trim();
String pretty350(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class Event350 {
  final String id, unit, subject, predicate, object, surface, subjectSurface;
  final String target, location, kind, chapter, epistemic;
  final bool negative, universal;
  final int ordinal;
  final List<String> links;
  final String resolution;
  const Event350(
      {required this.id,
      required this.unit,
      required this.ordinal,
      required this.subject,
      required this.predicate,
      this.object = '',
      this.surface = '',
      this.subjectSurface = '',
      this.target = '',
      this.location = '',
      this.kind = 'event',
      this.chapter = '',
      this.epistemic = 'asserted',
      this.negative = false,
      this.universal = false,
      this.links = const [],
      this.resolution = 'explicit'});
  Map<String, dynamic> toJson() => {
        'id': id,
        'unit': unit,
        'ordinal': ordinal,
        'subject': subject,
        'predicate': predicate,
        'object': object,
        'surface': surface,
        'subjectSurface': subjectSurface,
        'target': target,
        'location': location,
        'kind': kind,
        'chapter': chapter,
        'epistemic': epistemic,
        'negative': negative,
        'universal': universal,
        'links': links,
        'resolution': resolution
      };
  factory Event350.fromJson(Map m) => Event350(
      id: '${m['id']}',
      unit: '${m['unit']}',
      ordinal: (m['ordinal'] as num).toInt(),
      subject: '${m['subject']}',
      predicate: '${m['predicate']}',
      object: '${m['object'] ?? ''}',
      surface: '${m['surface'] ?? ''}',
      subjectSurface: '${m['subjectSurface'] ?? ''}',
      target: '${m['target'] ?? ''}',
      location: '${m['location'] ?? ''}',
      kind: '${m['kind'] ?? 'event'}',
      chapter: '${m['chapter'] ?? ''}',
      epistemic: '${m['epistemic'] ?? 'asserted'}',
      negative: m['negative'] == true,
      universal: m['universal'] == true,
      links: List<String>.from(m['links'] as List? ?? []),
      resolution: '${m['resolution'] ?? 'explicit'}');
  String describe() {
    if (kind == 'cause') return '$subject → motivazione esplicita → $object';
    final verb = surface.isEmpty ? predicate : surface;
    return '${universal ? 'Ogni ' : ''}${pretty350(subject)} ${negative ? 'non ' : ''}$verb'
        '${object.isEmpty ? '' : ' $object'}${target.isEmpty ? '' : ' a $target'}'
        '${location.isEmpty ? '' : ' $location'}.';
  }
}

class CompiledUnit350 {
  final String hash;
  final int ordinal, characters, sentences;
  final List<Event350> events;
  final UsageDelta350 language;
  final Map<String, int> issues;
  final Map<String, dynamic> discourse;
  const CompiledUnit350(this.hash, this.ordinal, this.characters,
      this.sentences, this.events, this.language, this.issues, this.discourse);
  Map<String, dynamic> toJson() => {
        'hash': hash,
        'ordinal': ordinal,
        'characters': characters,
        'sentences': sentences,
        'events': events.map((e) => e.toJson()).toList(),
        'language': language.toJson(),
        'issues': issues,
        'discourse': discourse
      };
}

/// A deliberately conservative finite bootstrap parser; not a pretrained POS model.
/// Learned usage is separate. Unsupported speech/conditions are not silently facts.
class NarrativeCompiler350 {
  String chapter = '', lastSubject = '', lastObject = '', lastObjectGender = '';
  String lastSubjectSurface = '';
  int nextOrdinal = 0;
  final Map<String, int> _recentSubjects = {};
  final Map<String, int> _entityMentions = {};
  final Map<String, int> _entityFirst = {};
  final Map<String, int> _entityLast = {};
  bool ambiguousPerson = false;
  NarrativeCompiler350([Map<String, dynamic>? state]) {
    if (state != null) {
      chapter = '${state['chapter'] ?? ''}';
      ambiguousPerson = state['ambiguousPerson'] == true;
      lastSubject = '${state['lastSubject'] ?? ''}';
      lastSubjectSurface = '${state['lastSubjectSurface'] ?? ''}';
      lastObject = '${state['lastObject'] ?? ''}';
      lastObjectGender = '${state['lastObjectGender'] ?? ''}';
      nextOrdinal = (state['nextOrdinal'] as num? ?? 0).toInt();
      for (final e in (state['recentSubjects'] as Map? ?? {}).entries) {
        _recentSubjects['${e.key}'] = (e.value as num).toInt();
      }
      for (final e in (state['entityMentions'] as Map? ?? {}).entries) {
        _entityMentions['${e.key}'] = (e.value as num).toInt();
      }
      for (final e in (state['entityFirst'] as Map? ?? {}).entries) {
        _entityFirst['${e.key}'] = (e.value as num).toInt();
      }
      for (final e in (state['entityLast'] as Map? ?? {}).entries) {
        _entityLast['${e.key}'] = (e.value as num).toInt();
      }
    }
  }
  Map<String, dynamic> state() => {
        'chapter': chapter,
        'lastSubject': lastSubject,
        'lastSubjectSurface': lastSubjectSurface,
        'lastObject': lastObject,
        'lastObjectGender': lastObjectGender,
        'nextOrdinal': nextOrdinal,
        'recentSubjects': _recentSubjects,
        'entityMentions': _entityMentions,
        'entityFirst': _entityFirst,
        'entityLast': _entityLast,
        'ambiguousPerson': ambiguousPerson
      };
  static const _verbGroups = <String, List<String>>{
    'prestare': ['presta', 'prestò', 'prestava', 'prestano', 'ha prestato'],
    'consegnare': [
      'consegna',
      'consegnò',
      'consegnava',
      'consegnano',
      'ha consegnato'
    ],
    'nascondere': [
      'nasconde',
      'nascose',
      'nascondeva',
      'nascondono',
      'ha nascosto'
    ],
    'riporre': ['ripone', 'ripose', 'riponeva', 'ripongono', 'ha riposto'],
    'mettere': ['mette', 'mise', 'metteva', 'mettono', 'ha messo'],
    'spostare': ['sposta', 'spostò', 'spostava', 'spostano', 'ha spostato'],
    'prendere': ['prende', 'prese', 'prendeva', 'prendono', 'ha preso'],
    'aprire': ['apre', 'aprì', 'apriva', 'aprono', 'ha aperto'],
    'chiudere': ['chiude', 'chiuse', 'chiudeva', 'chiudono', 'ha chiuso'],
    'trovare': ['trova', 'trovò', 'trovava', 'trovano', 'ha trovato'],
    'indicare': ['indica', 'indicò', 'indicava', 'indicano', 'ha indicato'],
    'tornare': [
      'torna',
      'tornò',
      'tornava',
      'tornano',
      'è tornato',
      'è tornata'
    ],
    'andare': ['va', 'andò', 'andava', 'vanno', 'è andato', 'è andata'],
    'partire': [
      'parte',
      'partì',
      'partiva',
      'partono',
      'è partito',
      'è partita'
    ],
    'arrivare': [
      'arriva',
      'arrivò',
      'arrivava',
      'arrivano',
      'è arrivato',
      'è arrivata'
    ],
    'leggere': ['legge', 'lesse', 'leggeva', 'leggono', 'ha letto'],
    'vedere': ['vede', 'vide', 'vedeva', 'vedono', 'ha visto'],
    'guardare': ['guarda', 'guardò', 'guardava', 'guardano', 'ha guardato'],
    'lasciare': ['lascia', 'lasciò', 'lasciava', 'lasciano', 'ha lasciato'],
    'portare': ['porta', 'portò', 'portava', 'portano', 'ha portato'],
    'possiede': ['possiede', 'possedeva', 'possedevano', 'possiedono'],
    'stato': ['è', 'era', 'sono', 'erano'],
  };
  static final verbMap = <String, String>{
    for (final e in _verbGroups.entries)
      for (final s in e.value) s: e.key,
    ...BookEngine342.verbs,
    for (final surface in _verbGroups['stato']!) surface: 'stato',
    for (final surface in _verbGroups['possiede']!) surface: 'possiede',
  };
  static final _verbs = (verbMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))
      .map(RegExp.escape)
      .join('|');
  static final _verb = RegExp('(?:^|\\s)($_verbs)(?=\\s|\$)');
  static final _unsafe = RegExp(
      r'\b(?:se|qualora|forse|potrebbe|potrebbero|può|possono|sembra|secondo|disse|dice|dicono|afferma|affermò|pensa|pensò|crede|credeva|sognò|sogna|finge|mentì|nonostante|ma|oppure|alcuni|alcune|nessuno|soltanto|tranne|eccetto|probabilmente|dovrebbe|vorrebbe|quasi|sempre|talvolta|raramente|solo)\b|[«»“”:]');
  static final _location = RegExp(
      r'\s+(sotto|sopra|dentro|fuori|vicino a|in|nel|nella|nello|nei|nelle|sul|sulla|sullo|su)\s+(.+)$');
  static String lemma(String surface) =>
      verbMap[norm350(surface)] ?? norm350(surface);
  static String gender(String surface) {
    final s = norm350(surface);
    if (RegExp(r'^(?:una|la)\s').hasMatch(s)) return 'f';
    if (RegExp(r'^(?:un|uno|il|lo)\s').hasMatch(s)) return 'm';
    if (RegExp(r'^(?:le)\s').hasMatch(s)) return 'fp';
    if (RegExp(r'^(?:i|gli)\s').hasMatch(s)) return 'mp';
    return '';
  }

  static final _properName = RegExp(
      r"\b(?:[A-ZÀÈÉÌÒÙ][a-zàèéìòù]+(?:['’][A-ZÀÈÉÌÒÙ]?[a-zàèéìòù]+)?)(?:\s+[A-ZÀÈÉÌÒÙ][a-zàèéìòù]+(?:['’][A-ZÀÈÉÌÒÙ]?[a-zàèéìòù]+)?){0,2}\b");
  static const _nameStop = {
    'Questo', 'Questa', 'Questi', 'Queste', 'Quando', 'Dopo', 'Prima', 'Ora',
    'Poi', 'Ma', 'E', 'Ed', 'Se', 'Perché', 'Perche', 'Come', 'Dunque', 'Allora',
    'Intanto', 'Infine', 'Finalmente', 'Capitolo', 'Parte'
  };

  void _observeEntities(String original, int position) {
    final seen = <String>{};
    for (final m in _properName.allMatches(original)) {
      final raw = m[0]!.trim();
      final rawTokens = tokens350(raw);
      if (_nameStop.contains(raw) ||
          rawTokens.isEmpty ||
          rawTokens.every(CompetenceLanguage350.functionWords.contains)) {
        continue;
      }
      final key = entity350(raw);
      final keyTokens = tokens350(key);
      // Capitalization at sentence start is not evidence of a named entity:
      // reject grammatical/function words (e.g. “Non”) generically.
      if (key.length < 2 ||
          keyTokens.length > 3 ||
          keyTokens.every(CompetenceLanguage350.functionWords.contains)) {
        continue;
      }
      // Keep each entity at most once per sentence to prevent a single sentence
      // from dominating the story model through repetition.
      if (!seen.add(key)) continue;
      _entityMentions[key] = (_entityMentions[key] ?? 0) + 1;
      _entityFirst.putIfAbsent(key, () => position);
      _entityLast[key] = position;
    }
  }

  void clearDiscourse() {
    lastSubject = '';
    lastSubjectSurface = '';
    lastObject = '';
    lastObjectGender = '';
    _recentSubjects.clear();
    ambiguousPerson = false;
  }

  CompiledUnit350 compile(String text,
      {required int unitOrdinal, String? unitId}) {
    final id = unitId ?? digest350(text),
        result = <Event350>[],
        delta = UsageDelta350(),
        issues = <String, int>{};
    void issue(String reason) => issues[reason] = (issues[reason] ?? 0) + 1;
    final units = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    var sentencePosition = nextOrdinal;
    for (final original in units) {
      _observeEntities(original, sentencePosition++);
      var s = original.trim();
      if (RegExp(r'^(?:capitolo|chapter|parte)\s+[0-9ivxlc]+\b',
                  caseSensitive: false)
              .hasMatch(s) &&
          s.length < 160) {
        chapter = s;
        clearDiscourse();
        issue('chapter_heading');
        continue;
      }
      final ts = tokens350(s);
      if (ts.length > 256 || s.length > 1800) {
        issue('overlong_unit');
        _merge(delta, CompetenceLanguage350.observeFragment(s));
        clearDiscourse();
        continue;
      }
      if (s.endsWith('?') || _unsafe.hasMatch(norm350(s))) {
        issue('unsupported_scope_or_speech');
        clearDiscourse();
        final d = CompetenceLanguage350.observe(s);
        _merge(delta, d);
        continue;
      }
      final additions = <Event350>[];
      if (norm350(s).startsWith('quando ') && s.contains(',')) {
        final comma = s.indexOf(',');
        final first = s.substring(7, comma),
            second = s.substring(comma + 1).trim();
        final a = _parse(first, id), b = _parse(second, id);
        if (a != null && b != null) {
          additions.addAll([a, b]);
        } else {
          issue('temporal_clause_unresolved');
          clearDiscourse();
        }
      } else {
        final cause = RegExp(r'\s+(?:perché|poiché)\s+', caseSensitive: false)
            .firstMatch(s);
        if (cause != null) {
          final a = _parse(s.substring(0, cause.start), id);
          final b = _parse(s.substring(cause.end), id);
          if (a != null && b != null) {
            additions.addAll([
              a,
              b,
              Event350(
                  id: '$id:${nextOrdinal++}',
                  unit: id,
                  ordinal: nextOrdinal,
                  subject: a.id,
                  predicate: 'causa_esplicita',
                  object: b.id,
                  kind: 'cause',
                  chapter: chapter,
                  links: [a.id, b.id])
            ]);
          } else {
            issue('cause_unresolved');
            clearDiscourse();
          }
        } else {
          final e = _parse(s, id);
          if (e != null) {
            additions.add(e);
          } else {
            issue('unparsed_or_ambiguous');
            clearDiscourse();
          }
        }
      }
      result.addAll(additions);
      _merge(
          delta,
          CompetenceLanguage350.observe(s,
              events: additions.map((e) => e.toJson()).toList()));
    }
    return CompiledUnit350(id, unitOrdinal, text.length, units.length, result,
        delta, issues, state());
  }

  static void _merge(UsageDelta350 a, UsageDelta350 b) {
    for (final r in b.counts.entries) {
      for (final e in r.value.entries) {
        a.add(r.key, e.key, e.value);
      }
    }
  }

  Event350? _parse(String input, String unit) {
    var s = norm350(input).replaceAll(RegExp(r'[.!]+$'), '').trim();
    if (s.isEmpty ||
        s.contains(',') ||
        s.contains(';') ||
        RegExp(r'\b(?:mentre|prima|dopo|ieri|domani|intanto)\b').hasMatch(s))
      return null;
    // Strip only sequence markers. Order recorded is narrative order, not proven chronology.
    s = s.replaceFirst(RegExp(r'^(?:poi|quindi|successivamente)\s+'), '');
    var universal = false;
    if (s.startsWith('ogni ')) {
      universal = true;
      s = s.substring(5);
    }
    var resolution = 'explicit', negative = false;
    String subject = '',
        subjectSurface = '',
        object = '',
        target = '',
        location = '',
        surface = '',
        predicate = '';
    // Passive voice reverses roles; no active frame is learned from passive surface.
    final passive = RegExp(
            r'^(.+?)\s+(non\s+)?(?:è|viene|fu|era)\s+(aiutat[oa]|inseguit[oa]|trasportat[oa]|nascost[oa]|consegnat[oa]|apert[oa]|chius[oa])\s+(?:da|dal|dalla)\s+(.+)$')
        .firstMatch(s);
    if (passive != null) {
      final roots = {
        'aiutat': 'aiuta',
        'inseguit': 'insegue',
        'trasportat': 'trasporta',
        'nascost': 'nasconde',
        'consegnat': 'consegna',
        'apert': 'apre',
        'chius': 'chiude'
      };
      surface = roots[passive[3]!.substring(0, passive[3]!.length - 1)]!;
      predicate = lemma(surface);
      subjectSurface = passive[4]!;
      subject = entity350(subjectSurface);
      object = entity350(passive[1]!);
      negative = passive[2] != null;
      resolution = 'passive_roles';
    } else {
      var match = _verb.allMatches(s).where((m) {
        final before = s
            .substring(0, m.start)
            .trim()
            .replaceAll(RegExp(r'\bnon\b'), '')
            .trim();
        return tokens350(before)
            .any((w) => !CompetenceLanguage350.functionWords.contains(w));
      }).firstOrNull;
      // An initial clitic needs discourse. Prefer an explicit subject, so the noun
      // in 'la porta è aperta' is not prematurely read as the verb 'portare'.
      match ??= _verb.firstMatch(s);
      if (match == null) {
        // Limited bootstrap of a new verb from an explicit simple S-V-O frame.
        // Its semantics is NOT guessed or merged with synonyms.
        match = RegExp(
                r'^((?:(?:il|lo|la|un|una)\s+)?[a-zàèéìòù]+)\s+([a-zàèéìòù]{3,}(?:isce|ano|ono|a|e))\s+(.+)$')
            .firstMatch(s);
        if (match == null) return null;
        subjectSurface = match[1]!;
        surface = match[2]!;
        object = match[3]!;
        if (CompetenceLanguage350.functionWords.contains(surface)) return null;
        predicate = surface;
        subject = entity350(subjectSurface);
      } else {
        surface = match[1]!;
        predicate = lemma(surface);
        final before = s.substring(0, match.start).trim();
        object = s.substring(match.end).trim();
        var prefix = before;
        negative = RegExp(r'\bnon\b').hasMatch(prefix);
        prefix = prefix.replaceAll(RegExp(r'\bnon\b'), '').trim();
        final clitic = RegExp(r'(?:^|\s)(la|lo|li|le)$').firstMatch(prefix);
        String? pronoun;
        if (clitic != null) {
          pronoun = clitic[1]!;
          prefix = prefix.substring(0, clitic.start).trim();
        }
        if (prefix.isEmpty) {
          if (lastSubject.isEmpty || pronoun == null) return null;
          subject = lastSubject;
          subjectSurface = lastSubjectSurface;
          resolution = 'local_subject_ellipsis';
        } else {
          subjectSurface = prefix;
          subject = entity350(prefix);
          if ({'lui', 'lei', 'egli', 'ella'}.contains(subject)) {
            final recent = _recentSubjects.entries
                .where((e) => nextOrdinal - e.value <= 3)
                .map((e) => e.key)
                .toSet();
            if (recent.length != 1 || ambiguousPerson) return null;
            subject = recent.single;
            subjectSurface = subject;
            resolution = 'unique_local_subject';
          }
        }
        if (pronoun != null) {
          if (pronoun == 'le' && predicate == 'indicare') {
            // Dative le is ambiguous without known gender: do not guess a person.
            return null;
          }
          final wanted =
              {'la': 'f', 'lo': 'm', 'li': 'mp', 'le': 'fp'}[pronoun];
          if (lastObject.isEmpty || wanted != lastObjectGender) return null;
          object = '$lastObject${object.isEmpty ? '' : ' $object'}';
          resolution = 'local_object_clitic';
        }
      }
      if (predicate == 'stato') {
        final nominal =
            RegExp(r"^(?:(?:un|uno|una|il|lo|la)\s|l')").hasMatch(object);
        predicate = nominal ? 'tipo' : 'stato';
      }
      final loc = _location.firstMatch(' $object');
      if (loc != null) {
        location = '${loc[1]} ${loc[2]}';
        object = (' $object').substring(0, loc.start).trim();
      }
      if ({'prestare', 'consegnare', 'indicare', 'portare'}
          .contains(predicate)) {
        final to = RegExp(r'\s+(?:a|al|alla)\s+(.+)$').firstMatch(' $object');
        if (to != null) {
          target = entity350(to[1]!);
          object = (' $object').substring(0, to.start).trim();
        }
      }
      if ({'andare', 'tornare', 'arrivare', 'partire'}.contains(predicate) &&
          object.startsWith('a ')) {
        location = object;
        object = '';
      }
      if (predicate == 'luogo') {
        location = object;
        object = '';
      }
      if (predicate == 'stato' && object.isEmpty && location.isNotEmpty)
        predicate = 'luogo';
    }
    if (subject.isEmpty ||
        tokens350(subject).length > 8 ||
        subject.length > 120 ||
        RegExp(r'\b(?:che|chi|cosa|quale|se|ogni|non)\b').hasMatch(subject))
      return null;
    if (tokens350(object).length > 12 ||
        tokens350(target).length > 6 ||
        tokens350(location).length > 10) return null;
    if (RegExp(r'\b(?:e|o|che|non|se|mentre|perché|quando|per)\b')
        .hasMatch('$object $location $target')) return null;
    if (object.isEmpty &&
        location.isEmpty &&
        !{'tornare', 'partire', 'arrivare'}.contains(predicate)) return null;
    final rawObject = object;
    object = entity350(object);
    final ordinal = nextOrdinal++;
    final event = Event350(
        id: '$unit:$ordinal',
        unit: unit,
        ordinal: ordinal,
        subject: subject,
        subjectSurface: subjectSurface,
        predicate: predicate,
        object: object,
        surface: surface,
        target: target,
        location: location,
        negative: negative,
        universal: universal,
        chapter: chapter,
        kind: universal
            ? 'rule'
            : {'tipo', 'stato', 'luogo', 'possedere', 'possiede'}
                    .contains(predicate)
                ? 'fact'
                : 'event',
        resolution: resolution);
    if (!universal && !negative) {
      lastSubject = subject;
      lastSubjectSurface = subjectSurface;
      _recentSubjects[subject] = ordinal;
      _recentSubjects.removeWhere((_, p) => ordinal - p > 3);
      final mentions = RegExp(r'\b[A-ZÀÈÉÌÒÙ][a-zàèéìòù]+\b')
          .allMatches(input)
          .map((m) => entity350(m[0]!))
          .where((x) =>
              x != subject &&
              x != 'il' &&
              x != 'la' &&
              x != 'una' &&
              x != 'un' &&
              x != 'quando' &&
              x != 'poi')
          .toSet();
      if (mentions.any((x) => object.contains(x) || target.contains(x)))
        ambiguousPerson = true;
      if (object.isNotEmpty) {
        if (resolution != 'local_object_clitic') {
          lastObject = object;
          lastObjectGender = gender(rawObject);
        }
      }
    }
    return event;
  }
}


class ClosedBookEngine350 {
  final List<Event350> events;
  final Map<String, dynamic> metadata;
  late final BookEngine342 facts;
  final Map<String, List<Event350>> bySubject = {},
      byObject = {},
      byPredicate = {};
  final Map<String, Event350> byId = {};
  final Map<String, String> surfaces = {};
  final Map<String, Event350> lastLocation = {};
  ClosedBookEngine350(List<Event350> input, [Map<String, dynamic>? meta])
      : events = List.unmodifiable(List<Event350>.of(input)
          ..sort((a, b) => a.ordinal.compareTo(b.ordinal))),
        metadata = Map.unmodifiable(meta ?? {}) {
    final fs = <BookFact342>[], provenance = <String, Map<String, dynamic>>{};
    for (final e in events) {
      byId[e.id] = e;
      if (e.kind == 'cause' || e.epistemic != 'asserted') continue;
      bySubject.putIfAbsent(e.subject, () => []).add(e);
      if (e.object.isNotEmpty) byObject.putIfAbsent(e.object, () => []).add(e);
      byPredicate.putIfAbsent(e.predicate, () => []).add(e);
      surfaces[e.surface] = e.predicate;
      provenance[e.id] = {
        'id': e.id,
        'text': e.describe(),
        'title': 'Memoria strutturata: ${metadata['title'] ?? ''}',
        'url': 'memory350://${metadata['id'] ?? ''}/${e.unit}',
        'reconstructed': true
      };
      fs.add(BookFact342(
          e.subject, e.predicate, e.object, e.negative, e.universal, [e.id]));
      if (!e.universal && !e.negative) {
        if ({
              'prendere',
              'prestare',
              'consegnare',
              'portare',
              'spostare',
              'mettere',
              'riporre',
              'nascondere',
              'lasciare'
            }.contains(e.predicate) &&
            e.object.isNotEmpty) {
          lastLocation.remove(e.object);
        }
        if ({'andare', 'partire', 'arrivare', 'tornare'}.contains(e.predicate))
          lastLocation.remove(e.subject);
      }
      if (!e.universal && e.negative && e.location.isNotEmpty) {
        final key = e.object.isEmpty ? e.subject : e.object;
        if (lastLocation[key]?.location == e.location) lastLocation.remove(key);
      }
      if (!e.universal && !e.negative && e.location.isNotEmpty) {
        if (!{
          'nascondere',
          'riporre',
          'mettere',
          'spostare',
          'lasciare',
          'portare',
          'andare',
          'tornare',
          'partire',
          'arrivare',
          'luogo'
        }.contains(e.predicate)) continue;
        final located = {
                  'nascondere',
                  'riporre',
                  'mettere',
                  'spostare',
                  'lasciare',
                  'portare'
                }.contains(e.predicate) &&
                e.object.isNotEmpty
            ? e.object
            : e.subject;
        lastLocation[located] = e;
      }
    }
    // Do not keep mutually obsolete last-location facts in the timeless inference engine.
    facts = BookEngine342.fromKnowledge(fs, provenance);
  }
  Map<String, dynamic> answer(String question, {String assumptions = ''}) {
    final watch = Stopwatch()..start();
    Map<String, dynamic> result(
            String status, String answer, List<Event350> support, String why) =>
        {
          'status': status,
          'answer': answer,
          'reason': why,
          'evidence': support.map((e) => e.toJson()).toList(),
          'rawPassagesRead': 0,
          'mode': 'closed_book',
          'micros': watch.elapsedMicroseconds
        };
    if (question.length > 4096 || assumptions.length > 8192)
      return {
        ...result('unknown', 'Domanda oltre il budget di lavoro.', [],
            'Usa una domanda breve e ipotesi esplicite.'),
        'budgetReached': true
      };
    final q = norm350(question).replaceAll(RegExp(r'[?!.]+$'), '').trim();
    if (q.isEmpty) return result('unknown', 'Scrivi una domanda.', [], '');
    if (RegExp(
            r'^(?:riassumi|riassunto|cosa è successo|che cosa è successo|racconta)')
        .hasMatch(q)) {
      final selected = events.where((e) => e.kind != 'cause').toList();
      return result(
          selected.isEmpty ? 'unknown' : 'summary',
          summary(),
          selected.take(100).toList(),
          'Ricostruzione degli eventi riconosciuti, non citazione del libro. Ordine di lettura; non ricostruisce flashback non risolti.');
    }
    if (assumptions.isNotEmpty) {
      final r = facts.answer(question, assumptions: assumptions);
      return {
        ...r.toJson(),
        'rawPassagesRead': 0,
        'mode': 'closed_book',
        'reconstructedEvidence': true
      };
    }
    final definition = RegExp(
            r"^(?:che cos'è|che cosa è|cos'è|cosa è|che cosa significa|cosa significa|definisci)\s+(.+)$")
        .firstMatch(q);
    if (definition != null) {
      final name = entity350(definition[1]!);
      final definitions = (bySubject[name] ?? [])
          .where(
              (e) => {'tipo', 'significa'}.contains(e.predicate) && !e.negative)
          .toList();
      if (definitions.isNotEmpty) {
        if (definitions.any((e) => (bySubject[name] ?? []).any((n) =>
            n.negative && n.predicate == e.predicate && n.object == e.object)))
          return result('conflict', 'Definizioni incompatibili.', definitions,
              'Sono conservate affermazioni opposte.');
        return result(
            'direct',
            definitions.map((e) => e.object).toSet().join('; '),
            definitions,
            'Descrizione nominale conservata in questo libro, non definizione universale verificata.');
      }
      return result('unknown', 'Non conservo una definizione riconosciuta.', [],
          'Le sole co-occorrenze non bastano a definire una parola.');
    }
    final where = RegExp(
            r'^(?:dove|in quale luogo)\s+(?:si trova|si trovava|è|era|sta)\s+(.+)$')
        .firstMatch(q);
    if (where != null) {
      final who = entity350(where[1]!), e = lastLocation[who];
      if (e == null)
        return result(
            'unknown',
            'Non conservo una posizione determinabile.',
            [],
            'Assenza di una posizione non significa che l’oggetto non esista.');
      return result('direct', e.location, [e],
          'Ultima posizione esplicita riconosciuta nell’ordine di lettura.');
    }
    final color =
        RegExp(r'^di che colore (?:è|era|sono|erano) (.+)$').firstMatch(q);
    if (color != null) {
      final candidates = (bySubject[entity350(color[1]!)] ?? [])
          .where((e) => e.predicate == 'stato' && !e.negative)
          .toList();
      const colors = {
        'rosso',
        'rossa',
        'rossi',
        'rosse',
        'blu',
        'verde',
        'verdi',
        'giallo',
        'gialla',
        'nero',
        'nera',
        'bianco',
        'bianca',
        'grigio',
        'grigia',
        'viola',
        'arancione'
      };
      final c = candidates.where((e) => colors.contains(e.object)).toList();
      if (c.isNotEmpty)
        return result('direct', c.last.object, [c.last],
            'Proprietà cromatica conservata.');
      return result('unknown', 'Non conservo il colore.', [],
          'Non viene ricostruito per plausibilità.');
    }
    var why = false;
    var base = q;
    if (base.startsWith('perché ') || base.startsWith('perche ')) {
      why = true;
      base = base.substring(7);
    }
    final verbs = {...NarrativeCompiler350.verbMap, ...surfaces}.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = verbs.map(RegExp.escape).join('|');
    final who = RegExp('^chi (?:ha )?($pattern) (.+)\$').firstMatch(base);
    final what =
        RegExp('^(?:che cosa|cosa) (?:ha )?($pattern) (.+)\$').firstMatch(base);
    final recipient =
        RegExp('^a chi (.+?) (?:ha )?($pattern) (.+)\$').firstMatch(base);
    final recipientAlt =
        RegExp('^a chi (?:ha )?($pattern) (.+?) (?:il|lo|la|un|una) (.+)\$')
            .firstMatch(base);
    String pred(String s) => surfaces[s] ?? NarrativeCompiler350.lemma(s);
    List<Event350> matches = [];
    String slot = '';
    if (who != null) {
      matches = (byPredicate[pred(who[1]!)] ?? [])
          .where((e) => e.object == entity350(who[2]!) && !e.universal)
          .toList();
      slot = 'subject';
    } else if (what != null) {
      matches = (bySubject[entity350(what[2]!)] ?? [])
          .where((e) => e.predicate == pred(what[1]!) && !e.universal)
          .toList();
      slot = 'object';
    } else if (recipient != null) {
      matches = (bySubject[entity350(recipient[1]!)] ?? [])
          .where((e) =>
              e.predicate == pred(recipient[2]!) &&
              e.object == entity350(recipient[3]!))
          .toList();
      slot = 'target';
    } else if (recipientAlt != null) {
      matches = (bySubject[entity350(recipientAlt[2]!)] ?? [])
          .where((e) =>
              e.predicate == pred(recipientAlt[1]!) &&
              e.object == entity350(recipientAlt[3]!))
          .toList();
      slot = 'target';
    }
    if (why) {
      final probe = NarrativeCompiler350().compile(base, unitOrdinal: 0).events;
      if (probe.isNotEmpty) {
        final p = probe.first;
        matches = (bySubject[p.subject] ?? [])
            .where((e) =>
                e.predicate == p.predicate &&
                e.object == p.object &&
                e.negative == p.negative)
            .toList();
      }
      final links = events
          .where(
              (e) => e.kind == 'cause' && matches.any((a) => a.id == e.subject))
          .toList();
      if (links.isNotEmpty) {
        final causes =
            links.map((e) => byId[e.object]).whereType<Event350>().toList();
        return result(
            'direct',
            causes.map((e) => e.describe()).join(' '),
            [...matches, ...causes, ...links],
            'Motivazione esplicita registrata, non motivo inventato.');
      }
      return result('unknown', 'Non conservo una motivazione esplicita.', [],
          'Un evento precedente non è automaticamente la causa.');
    }
    if (slot.isNotEmpty && matches.isNotEmpty) {
      final positive = matches.where((e) => !e.negative).toList();
      if (positive.any((e) => matches.any((n) =>
          n.negative && n.subject == e.subject && n.object == e.object))) {
        return result('conflict', 'Affermazioni incompatibili nella memoria.',
            matches, 'La negazione non viene ignorata.');
      }
      final values = positive
          .map((e) => slot == 'subject'
              ? e.subject
              : slot == 'object'
                  ? e.object
                  : e.target)
          .where((v) => v.isNotEmpty)
          .toSet();
      if (values.isNotEmpty)
        return result('direct', values.join('; '), positive,
            'Ruoli ricostruiti dalla memoria degli eventi.');
    }
    final r = facts.answer(question);
    return {
      ...r.toJson(),
      'rawPassagesRead': 0,
      'mode': 'closed_book',
      'reconstructedEvidence': true
    };
  }

  String summary({String? entity, int maxEvents = 120}) {
    final selected = events
        .where((e) =>
            e.kind != 'cause' &&
            (entity == null ||
                e.subject == entity ||
                e.object == entity ||
                e.target == entity))
        .toList();
    if (selected.isEmpty)
      return 'Non ci sono eventi riconosciuti da riassumere.';
    final out = <String>[];
    String current = '';
    for (final e in selected.take(maxEvents)) {
      if (e.chapter != current) {
        current = e.chapter;
        if (current.isNotEmpty) out.add('\n$current');
      }
      out.add(e.describe());
    }
    if (selected.length > maxEvents)
      out.add(
          '… ${selected.length - maxEvents} altri eventi: apri le pagine della mappa.');
    final missing = (metadata['unparsed'] as num? ?? 0).toInt();
    if (missing > 0)
      out.add(
          '\nSintesi parziale: $missing unità non interpretate. Non sono state inventate per completare la trama.');
    return out.join('\n');
  }

}
