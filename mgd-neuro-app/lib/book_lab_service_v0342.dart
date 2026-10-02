import 'dart:async';
import 'dart:isolate';
import 'book_understanding_v0342.dart';
import 'web_knowledge_explorer_v11.dart';

/// One source index per worker, not a copy of the entire brain for every question.
/// A closed screen terminates its worker. No question or answer is ingested.
class BookWorker342 {
  final ReceivePort _receive = ReceivePort();
  final Map<int,Completer<dynamic>> _pending = {};
  final Completer<void> _ready = Completer<void>();
  Isolate? _isolate;
  SendPort? _commands;
  int _next = 0;
  bool _closed = false;
  Map<String,dynamic> metadata = {};
  BookWorker342._();
  static Future<BookWorker342> open(List<Map<String,dynamic>> rows) async {
    final w=BookWorker342._();
    w._receive.listen(w._event);
    try {
      w._isolate=await Isolate.spawn(_bookWorker342,[w._receive.sendPort,rows],
        onError:w._receive.sendPort,onExit:w._receive.sendPort,errorsAreFatal:true);
      await w._ready.future.timeout(const Duration(seconds:90));
      return w;
    } catch(e) {w.close();rethrow;}
  }
  void _event(dynamic event) {
    if(_closed) return;
    if(event is Map && event['ready']==true) {
      _commands=event['port'] as SendPort;
      metadata=Map<String,dynamic>.from(event['stats'] as Map);
      if(!_ready.isCompleted) _ready.complete();
    } else if(event is Map && event['id'] is int) {
      final c=_pending.remove(event['id']);
      if(c==null) return;
      if(event.containsKey('error')) {c.completeError(StateError('${event['error']}'));}
      else {c.complete(event['value']);}
    } else {
      final error=StateError('Lettore del libro terminato: $event');
      if(!_ready.isCompleted) _ready.completeError(error);
      for(final c in _pending.values) {if(!c.isCompleted)c.completeError(error);}
      _pending.clear(); close();
    }
  }
  Future<dynamic> call(String operation,[Map<String,dynamic> data=const {}]) async {
    if(_closed||_commands==null) throw StateError('Lettore non disponibile.');
    final id=++_next,c=Completer<dynamic>(); _pending[id]=c;
    _commands!.send({'id':id,'operation':operation,...data});
    try {return await c.future.timeout(const Duration(seconds:90));}
    finally {_pending.remove(id);}
  }
  void close() {
    if(_closed)return; _closed=true;
    _isolate?.kill(priority:Isolate.immediate);_receive.close();
    for(final c in _pending.values) {if(!c.isCompleted)c.completeError(StateError('Lettore chiuso.'));}
    _pending.clear();
  }
}
void _bookWorker342(List<dynamic> init) async {
  final send=init[0] as SendPort;
  final rows=(init[1] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
  final engine=BookEngine342(rows), receive=ReceivePort();
  send.send({'ready':true,'port':receive.sendPort,'stats':engine.stats()});
  await for(final raw in receive) {
    final m=Map<String,dynamic>.from(raw as Map);
    try {
      dynamic value;
      switch(m['operation']) {
        case 'ask':
          value=engine.answer('${m['question']}',assumptions:'${m['assumptions']??''}').toJson();
          break;
        case 'probes': value=engine.probes(); break;
        case 'exam':
          final cases=BookExam342.validate(m['cases']);
          value=BookExam342.run(engine,cases);
          break;
        case 'emptyControl':
          value=BookExam342.run(BookEngine342([]),BookExam342.validate(m['cases']));
          break;
        default: throw ArgumentError('Operazione non supportata.');
      }
      send.send({'id':m['id'],'value':value});
    } catch(e,st) {send.send({'id':m['id'],'error':'$e\n$st'});}
  }
}

class BookLab342 {
  static Map<String,dynamic> state(ResearchMemory11 memory) {
    final old=memory.state317['bookLab342'];
    if(old is Map<String,dynamic>)return old;
    final s=Map<String,dynamic>.from(old as Map? ?? {});memory.state317['bookLab342']=s;return s;
  }
  static List<Map<String,dynamic>> rows(ResearchMemory11 memory) => SourceMemory323.rows(memory);
  static List<Map<String,dynamic>> scopes(List<Map<String,dynamic>> rows) {
    final out=<String,Map<String,dynamic>>{};
    for(final r in rows) {
      final key=bookScope342(r), entry=out.putIfAbsent(key,()=>{'key':key,'title':'${r['title']}',
        'count':0,'legacy':key.startsWith('legacy:')});
      entry['count']=(entry['count'] as int)+1;
    }
    return out.values.toList()..sort((a,b)=>'${a['title']}'.compareTo('${b['title']}'));
  }
  static List<Map<String,dynamic>> cases(ResearchMemory11 memory,String scope) {
    final all=state(memory)['cases'] as Map? ?? {};
    return (all[scope] as List? ?? []).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
  }
  static void setCases(ResearchMemory11 memory,String scope,List<Map<String,dynamic>> cases) {
    final s=state(memory), all=Map<String,dynamic>.from(s['cases'] as Map? ?? {});
    all[scope]=BookExam342.validate(cases);s['cases']=all;
  }
  static List<Map<String,dynamic>> reports(ResearchMemory11 memory,String scope) =>
    (state(memory)['reports'] as List? ?? []).whereType<Map>().where((r)=>r['scope']==scope)
      .map((r)=>Map<String,dynamic>.from(r)).toList();
  static void retainReport(ResearchMemory11 memory,String scope,Map<String,dynamic> report) {
    final s=state(memory), old=List<dynamic>.from(s['reports'] as List? ?? []);
    old.add({...report,'scope':scope});s['reports']=old;
  }
  static BookWorker342? _chat;
  static ResearchMemory11? _memory;
  static String? _scope;
  static int? _revision;
  static Future<String?> chat(ResearchMemory11 memory,String input) async {
    final prefix=RegExp(r'^\s*libro\s*:\s*',caseSensitive:false);
    if(!prefix.hasMatch(input))return null;
    final q=input.replaceFirst(prefix,'').trim();
    if(q.isEmpty)return 'Scrivi Libro: seguito dalla domanda.';
    final scope=state(memory)['activeScope'] as String?;
    if(scope==null)return 'Apri MGD Language → Verifica del libro e seleziona prima il materiale da interrogare.';
    final revision=((memory.state317['sourceMemory323'] as Map?)?['revision'] as num? ?? 0).toInt();
    if(_chat==null||!identical(_memory,memory)||scope!=_scope||revision!=_revision) {
      _chat?.close();_chat=null;
      final source=rows(memory).where((r)=>bookScope342(r)==scope).toList();
      if(source.isEmpty)return 'Il materiale selezionato non è disponibile. Seleziona nuovamente il libro.';
      _chat=await BookWorker342.open(source);_memory=memory;_scope=scope;_revision=revision;
    }
    final r=Map<String,dynamic>.from(await _chat!.call('ask',{'question':q}) as Map);
    return BookResult342('${r['status']}','${r['answer']}','${r['reason']}',
      (r['evidence'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList(),
      (r['related'] as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList(),
      (r['micros'] as num).toInt(),budgetReached:r['budgetReached']==true).render();
  }
  static void closeChat() {_chat?.close();_chat=null;_memory=null;_scope=null;_revision=null;}
}
