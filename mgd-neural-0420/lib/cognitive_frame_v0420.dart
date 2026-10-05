String norm420(String x) =>
    x.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r'\s+'), ' ').trim();

class CognitiveFrame420 {
  final String subject, predicate, object, location;
  final bool negative;
  final List<String> concepts;
  const CognitiveFrame420({
    required this.subject,
    required this.predicate,
    required this.object,
    required this.location,
    required this.negative,
    required this.concepts,
  });
  bool get valid => subject.isNotEmpty && predicate.isNotEmpty;
  String get signature =>
      '$subject|$predicate|$object|$location|${negative ? 1 : 0}';
  Map<String, dynamic> toJson() => {
    'subject': subject,
    'predicate': predicate,
    'object': object,
    'location': location,
    'negative': negative,
    'concepts': concepts,
  };
}
