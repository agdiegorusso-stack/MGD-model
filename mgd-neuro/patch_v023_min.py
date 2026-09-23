from pathlib import Path
import sys
root=Path(sys.argv[1])

# Epistemic gate: narrative/dialogue remains language, not world-knowledge.
p=root/'lib'/'corpus_semantic_bridge_v022.dart'
s=p.read_text()
anchor="""bool _validObject22(String s){
  if(s.length<2||s.length>180)return false;
  final words=s.split(RegExp(r'\\s+'));
  if(words.length>18)return false;
  final n=_n22(s);
  if(n.isEmpty||{'esso','essa','questo','questa','ciò','cio','che'}.contains(n))return false;
  return true;
}
"""
insert=r'''bool _validObject22(String s){
  if(s.length<2||s.length>180)return false;
  final words=s.split(RegExp(r'\s+'));
  if(words.length>18)return false;
  final n=_n22(s);
  if(n.isEmpty||{'esso','essa','questo','questa','ciò','cio','che'}.contains(n))return false;
  return true;
}

bool _looksNarrative22(String sentence,String subject){
  final raw=sentence.trim();
  final ns=_n22(subject);
  const bad={'naturalmente','ora','cosi','così','senti','rise','disse','rispose','allora','poi','forse','certo'};
  if(bad.contains(ns))return true;
  if(RegExp(r'^(?:e|ma|ora|cos[iì]|se|quando|mentre|perch[eé]|come|poi|allora|naturalmente)\b',caseSensitive:false).hasMatch(subject))return true;
  if(RegExp(r'\b(?:io|tu|mio|mia|miei|mie|tuo|tua|tuoi|tue|noi|nostro|nostra|voi|vostro|vostra)\b',caseSensitive:false).hasMatch(subject))return true;
  if(RegExp(r'\b(?:disse|rispose|grid[oò]|rise|pens[oò]|guard[oò]|sent[iì]|vide|chiese|domand[oò]|esclam[oò]|sussurr[oò])\b',caseSensitive:false).hasMatch(raw))return true;
  if(raw.contains('«')||raw.contains('»')||raw.contains('“')||raw.contains('”')||raw.contains('—')||raw.contains('–'))return true;
  if(raw.startsWith('-')||subject.contains(':')||subject.contains(';')||subject.contains('?')||subject.contains('!'))return true;
  return false;
}
'''
if anchor not in s: raise SystemExit('validObject anchor missing')
s=s.replace(anchor,insert,1)
line="    (re:RegExp(r'^(.{2,90}?)\\s+(?:è|È)\\s+(?:il|lo|la|i|gli|le)\\s+(.+)$'),relation:'tipo di',quality:.88,type:true),\n"
s=s.replace(line,'',1)
old="""      final subject=_cleanSubject22(m.group(1)??'');
      final object=_cleanObject22(m.group(2)??'',type:p.type);
      if(!_validSubject22(subject)||!_validObject22(object))continue;
      if(_n22(subject)==_n22(object))continue;
      out.add({"""
new="""      final subject=_cleanSubject22(m.group(1)??'');
      final object=_cleanObject22(m.group(2)??'',type:p.type);
      if(!_validSubject22(subject)||!_validObject22(object)||_looksNarrative22(clean,subject))continue;
      if(_n22(subject)==_n22(object))continue;
      out.add({"""
if old not in s: raise SystemExit('candidate gate anchor missing')
s=s.replace(old,new,1)
old="""      final sid=brain.entityIdForLabel06(subject)??brain.ensureSemanticEntity06(subject);
      entities++;
      int? oid;
      if(PlasticLanguageBrain04.lexicalTokens(object).length<=8){
        oid=brain.entityIdForLabel06(object)??brain.ensureSemanticEntity06(object);
        entities++;
      }

      final existing=memory.claims[entry.key];"""
new="""      final existing=memory.claims[entry.key];"""
if old not in s: raise SystemExit('premature entities anchor missing')
s=s.replace(old,new,1)
old="""      final alreadyAccepted=existing!=null&&{'accettata','validata_llm','appresa_corpus'}.contains(existing.status);
      final preciseSingle=avgQ>=.94;
      final repeated=xs.length>=2&&avgQ>=.86;
      final corroborated=familyCount>=2&&claim.confidence>=.54;
      final accept=!claim.conflict&&(alreadyAccepted||preciseSingle||repeated||corroborated);

      if(accept){
        final wasKnown=brain.semanticGraph(limit:100000).any((x)=>_n22(x.from)==_n22(subject)&&_n22(x.relation)==_n22(relation)&&_n22(x.to)==_n22(object)&&x.confidence>=.35);
        claim.status='accettata';"""
new="""      final alreadyAccepted=existing!=null&&{'accettata','validata_llm','appresa_corpus'}.contains(existing.status);
      final corroborated=familyCount>=2&&claim.confidence>=.54;
      final accept=!claim.conflict&&(alreadyAccepted||corroborated);

      if(accept){
        final sid=brain.entityIdForLabel06(subject)??brain.ensureSemanticEntity06(subject);
        entities++;
        int? oid;
        if(PlasticLanguageBrain04.lexicalTokens(object).length<=8){
          oid=brain.entityIdForLabel06(object)??brain.ensureSemanticEntity06(object);
          entities++;
        }
        final wasKnown=brain.semanticGraph(limit:100000).any((x)=>_n22(x.from)==_n22(subject)&&_n22(x.relation)==_n22(relation)&&_n22(x.to)==_n22(object)&&x.confidence>=.35);
        claim.status=alreadyAccepted?existing!.status:'appresa_corpus';"""
if old not in s: raise SystemExit('acceptance anchor missing')
s=s.replace(old,new,1)
p.write_text(s)

# Autonomous web curiosity: never promote corpus-only hypotheses into search topics.
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()
old="""    final weak = memory.claims.values.where((c) => c.status == 'dubbia' && c.confidence < 0.60).toList()
      ..sort((a, b) => a.confidence.compareTo(b.confidence));"""
new="""    final weak = memory.claims.values.where((c) {
      if(c.status!='dubbia'||c.confidence>=0.60)return false;
      final corpusOnly=c.sourceFamilies.isNotEmpty&&c.sourceFamilies.every((f)=>f.startsWith('corpus:')||f.startsWith('manuale:'));
      return !corpusOnly;
    }).toList()..sort((a,b)=>a.confidence.compareTo(b.confidence));"""
if old not in s: raise SystemExit('weak research anchor missing')
s=s.replace(old,new,1)
old="""      if (label.length < 3 || oneWordVerb || {'utente', 'self', 'io', 'tu'}.contains(n) || RegExp(r'^\\d+(?:[.,]\\d+)?$').hasMatch(label)) continue;"""
new="""      final sentenceLike=label.split(RegExp(r'\\s+')).length>6 || RegExp(r'^(?:e|ma|ora|cos[iì]|se|quando|mentre|perch[eé]|come|poi|allora|per\\s+lui|per\\s+lei)\\b',caseSensitive:false).hasMatch(label) || label.contains(':') || label.contains(';');
      if (label.length < 3 || sentenceLike || oneWordVerb || {'utente', 'self', 'io', 'tu'}.contains(n) || RegExp(r'^\\d+(?:[.,]\\d+)?$').hasMatch(label)) continue;"""
if old not in s: raise SystemExit('entity topic anchor missing')
s=s.replace(old,new,1)
old="""      final ids = world.pendingCuriosityEntities09;
      final topic = ids.isNotEmpty && ids.first >= 0 && ids.first < brain.entities.length ? brain.entities[ids.first].label : pending.replaceAll('?', '');
      return ResearchGoal11(query: pending.replaceAll('?', ''), topic: topic, reason: 'domanda generata dalla curiosità interna', value: 0.92);"""
new="""      final ids = world.pendingCuriosityEntities09;
      final topic = ids.isNotEmpty && ids.first >= 0 && ids.first < brain.entities.length ? brain.entities[ids.first].label : pending.replaceAll('?', '');
      final sentenceLike=topic.split(RegExp(r'\\s+')).length>6 || RegExp(r'^(?:e|ma|ora|cos[iì]|se|quando|mentre|perch[eé]|come|poi|allora|per\\s+lui|per\\s+lei)\\b',caseSensitive:false).hasMatch(topic) || topic.contains(':') || topic.contains(';');
      if(!sentenceLike){
        return ResearchGoal11(query: pending.replaceAll('?', ''), topic: topic, reason: 'domanda generata dalla curiosità interna', value: 0.92);
      }"""
if old not in s: raise SystemExit('pending curiosity anchor missing')
s=s.replace(old,new,1)
p.write_text(s)

# Knowledge map: consolidated knowledge by default; hypotheses are opt-in.
p=root/'lib'/'navigable_graph_v013.dart'
s=p.read_text()
s=s.replace("""  bool _showRelations = false;
  bool _showNodeLabels = true;""","""  bool _showRelations = false;
  bool _showNodeLabels = true;
  bool _showHypotheses = false;""",1)
old="""    final research=widget.research;
    if(research!=null){
      for(final c in research.claims.values){"""
new="""    final research=widget.research;
    if(_showHypotheses && research!=null){
      for(final c in research.claims.values){"""
if old not in s: raise SystemExit('map research overlay anchor missing')
s=s.replace(old,new,1)
old="""                      FilterChip(
                        label: const Text('Relazioni'),
                        selected: _showRelations,
                        onSelected: (v) {
                          if (v && layout.links.length > 1200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Le etichette delle relazioni vengono limitate sui grafi molto densi.',
                                ),
                              ),
                            );
                          }
                          setState(() => _showRelations = v);
                        },
                      ),"""
new="""                      FilterChip(
                        label: const Text('Relazioni'),
                        selected: _showRelations,
                        onSelected: (v) {
                          if (v && layout.links.length > 1200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Le etichette delle relazioni vengono limitate sui grafi molto densi.',
                                ),
                              ),
                            );
                          }
                          setState(() => _showRelations = v);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Ipotesi'),
                        selected: _showHypotheses,
                        onSelected: (v) {
                          setState(() {
                            _showHypotheses=v;
                            _refreshGraphCache();
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_)=>_fitView());
                        },
                      ),"""
if old not in s: raise SystemExit('map relation chip anchor missing')
s=s.replace(old,new,1)
p.write_text(s)

# Version.
p=root/'pubspec.yaml'
s=p.read_text().replace('version: 0.22.0+35','version: 0.23.0+36')
p.write_text(s)
p=root/'lib'/'main.dart'
s=p.read_text().replace('MGD Neuro 0.22','MGD Neuro 0.23')
p.write_text(s)
