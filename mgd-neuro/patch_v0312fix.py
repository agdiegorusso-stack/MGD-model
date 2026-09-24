from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'web_knowledge_explorer_v11.dart'
s=p.read_text()
if 'Future<List<String>> _wikidataLexicalAliases0312(' not in s:
    anchor="  Future<List<WebDocument11>> _europePmc031(String q) async {\n"
    helper="""  Future<List<String>> _wikidataLexicalAliases0312(String term) async {
    final search=await _json(Uri.https('www.wikidata.org','/w/api.php',{
      'action':'wbsearchentities',
      'search':term,
      'language':'it',
      'uselang':'it',
      'limit':'2',
      'format':'json',
      'origin':'*',
    }));
    final rows=(search['search'] as List?)??const [];
    final ids=<String>[];
    for(final x in rows){
      if(x is! Map)continue;
      final id=(x['id']??'').toString();
      if(id.isNotEmpty)ids.add(id);
    }
    if(ids.isEmpty)return const <String>[];
    final data=await _json(Uri.https('www.wikidata.org','/w/api.php',{
      'action':'wbgetentities',
      'ids':ids.join('|'),
      'props':'labels|aliases',
      'languages':'it|en',
      'format':'json',
      'origin':'*',
    }));
    final entities=data['entities'];
    if(entities is! Map)return const <String>[];
    final out=<String>{term.trim()};
    for(final raw in entities.values){
      if(raw is! Map)continue;
      final j=Map<String,dynamic>.from(raw);
      final labels=j['labels'];
      if(labels is Map){
        for(final lang in const ['it','en']){
          final v=labels[lang];
          if(v is Map){
            final x=(v['value']??'').toString().trim();
            if(x.length>=2 && x.split(RegExp(r'\\s+')).length<=6)out.add(x);
          }
        }
      }
      final aliases=j['aliases'];
      if(aliases is Map){
        for(final lang in const ['it','en']){
          final xs=aliases[lang];
          if(xs is List){
            for(final v in xs.take(4)){
              if(v is! Map)continue;
              final x=(v['value']??'').toString().trim();
              if(x.length>=2 && x.split(RegExp(r'\\s+')).length<=6)out.add(x);
            }
          }
        }
      }
    }
    return out.toList();
  }

"""
    if anchor not in s:
        raise SystemExit('0.31.2 alias helper insertion anchor missing')
    s=s.replace(anchor,helper+anchor,1)
p.write_text(s)
print('MGD Neuro 0.31.2 alias helper inserted')
