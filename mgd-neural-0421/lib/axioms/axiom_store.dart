import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'axiom_core.dart';
import 'axiom_seed.dart';

class AxiomStore extends ChangeNotifier {
  static const channel = MethodChannel('mgd.axioms/teacher');
  Database? _db;
  J state = {
    'model': axiomSeed(),
    'probes': <dynamic>[],
    'events': <dynamic>[],
    'audits': <String, dynamic>{}
  };
  bool busy = false, stopped = false, ready = false;
  String status = 'Apertura della memoria degli assiomi…';
  J? result;
  List<J> nodes = [];
  AxiomStudent get student => AxiomStudent(state['model'] as Map);
  List<Map> get probes =>
      [...axiomRegression(), ...(state['probes'] as List).cast<Map>()];
  bool _disposed = false;
  void signal() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open({String? databasePath}) async {
    _db = await openDatabase(
        databasePath ?? '${await getDatabasesPath()}/mgd_axioms_0430.db',
        version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE current (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE history (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT NOT NULL, reason TEXT NOT NULL, at TEXT NOT NULL)');
    });
    final rows = await _db!.query('current', columns: ['id'], where: 'id=1');
    if (rows.isNotEmpty) {
      state = copyJ(jsonDecode(await _readPayload0430('current', 1)) as Map);
    }
    student.validateModel();
    nodes = student.graph();
    ready = true;
    status =
        'Memoria pronta. Il grafo rappresenta il discepolo simbolico, non i pesi del vecchio lettore.';
    signal();
  }

  /// Read bounded slices rather than an entire multi-megabyte CursorWindow row.
  Future<String> _readPayload0430(String table, int id) async {
    if (!const ['current', 'history'].contains(table))
      throw ArgumentError('Tabella non ammessa.');
    final sizes = await _db!
        .rawQuery('SELECT length(payload) AS n FROM $table WHERE id=?', [id]);
    if (sizes.isEmpty)
      throw StateError('Revisione assente. Nessuna memoria sostituita.');
    final length = (sizes.single['n'] as num).toInt();
    if (length < 2 || length > 8000000)
      throw const FormatException('Snapshot fuori limite.');
    final out = StringBuffer();
    for (var offset = 1; offset <= length; offset += 131072) {
      final rows = await _db!.rawQuery(
          'SELECT substr(payload, ?, 131072) AS part FROM $table WHERE id=?',
          [offset, id]);
      if (rows.isEmpty || rows.single['part'] is! String)
        throw StateError('Snapshot incompleto.');
      out.write(rows.single['part'] as String);
    }
    return out.toString();
  }

  Future<void> closeStorage() async {
    final database = _db;
    _db = null;
    await database?.close();
  }

  Future<void> _commit(J next, String reason) async {
    if (_db == null) throw StateError('Memoria non aperta.');
    AxiomStudent(next['model'] as Map);
    final old = jsonEncode(state), payload = jsonEncode(next);
    if (utf8.encode(payload).length > 8000000)
      throw const FormatException(
          'Snapshot oltre il limite di 8 MB: esportare prima di proseguire.');
    final knowledgeChanged0430 =
        axHash(state['model']) != axHash(next['model']);
    await _db!.transaction((tx) async {
      if (knowledgeChanged0430) {
        await tx.insert('history', {
          'payload': old,
          'reason': reason,
          'at': DateTime.now().toUtc().toIso8601String()
        });
      }
      await tx.insert('current', {'id': 1, 'payload': payload},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.execute(
          'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY id DESC LIMIT 20)');
    });
    state = next;
    nodes = student.graph();
    signal();
  }

  Future<J> job(String kind, {J extra = const {}}) => compute(axiomJob,
      {'job': kind, 'model': state['model'], 'probes': probes, ...extra});
  Future<void> guarded(String message, Future<void> Function() fn) async {
    if (busy || !ready) return;
    busy = true;
    stopped = false;
    status = message;
    signal();
    try {
      await fn();
    } catch (e) {
      status = 'Operazione non completata: $e';
    } finally {
      busy = false;
      signal();
    }
  }

  Future<void> inspect(String text, J world) =>
      guarded('Il discepolo interpreta ed esegue…', () async {
        result = await job('parse', extra: {'text': text, 'world': world});
        status = result!['status'] == 'needs_context'
            ? 'Mancano fatti del contesto, non nuovi assiomi.'
            : 'Discepolo: ${result!['status']}';
      });
  Future<void> testAll() =>
      guarded('Verifica delle interpretazioni e degli effetti nel simulatore…',
          () async {
        result = await job('tests');
        status =
            'Regressioni note: ${result!['passed']}/${result!['total']}. Non è una prova di comprensione generale.';
        final next = copyJ(state);
        (next['events'] as List).add({
          'kind': 'tests',
          'at': DateTime.now().toUtc().toIso8601String(),
          'passed': result!['passed'],
          'total': result!['total'],
          'revision': result!['revision']
        });
        await _commit(next, 'Test di regressione');
      });
  Future<void> auditAll() =>
      guarded('Ricerca dei componenti superflui su copie della memoria…',
          () async {
        final revision = student.revision;
        final pending = nodes
            .where((n) =>
                const ['lexeme', 'frame', 'rule', 'program', 'guard', 'write']
                    .contains(n['type']) &&
                (state['audits'] as Map)[n['id']]?['revision'] != revision)
            .take(100)
            .toList();
        final next = copyJ(state);
        var checked = 0, necessary = 0;
        for (final n in pending) {
          if (stopped) break;
          status =
              'Audit ${checked + 1}/${pending.length}: ${n['label']}. Nessuna cancellazione automatica.';
          signal();
          final report = await job('ablate', extra: {'node': n['id']});
          next['audits'][n['id']] = report;
          checked++;
          if ((report['regressions'] as int) > 0) necessary++;
        }
        (next['events'] as List).add({
          'kind': 'batch_audit',
          'at': DateTime.now().toUtc().toIso8601String(),
          'checked': checked,
          'necessary_on_tests': necessary,
          'no_regression_observed': checked - necessary,
          'revision': revision
        });
        result = {
          'tested': checked,
          'necessary_on_tests': necessary,
          'no_regression_observed': checked - necessary,
          'absolute_minimality': false,
          'automatically_deleted': 0
        };
        await _commit(next, 'Audit multiplo senza modificare conoscenze');
        status =
            'Audit: $checked componenti; $necessary con controesempi. Nessun nodo cancellato. Le prove completate restano salvate.';
      });
  Future<void> audit(String id) =>
      guarded('Rimuovo il componente solo da una copia e cerco controesempi…',
          () async {
        result = await job('ablate', extra: {'node': id});
        final next = copyJ(state);
        next['audits'][id] = result;
        await _commit(next, 'Audit $id');
        status = result!['regressions'] == 0
            ? 'Nessuna regressione osservata: non equivale a inutilità dimostrata.'
            : 'Componente necessario in ${result!['regressions']} casi; controesempi disponibili.';
      });
  Future<void> archive(String id) =>
      guarded('Ricontrollo e disattivo in modo reversibile…', () async {
        final a = await job('ablate', extra: {'node': id});
        if (a['tested'] == 0 || a['regressions'] != 0)
          throw StateError(
              'Disattivazione bloccata: dati insufficienti o regressioni.');
        final revised = student.without(id);
        revised.validateModel();
        final next = copyJ(state);
        next['model'] = revised.model;
        next['audits'] = {};
        (next['events'] as List).add({
          'kind': 'archive',
          'node': id,
          'audit': a,
          'at': DateTime.now().toUtc().toIso8601String()
        });
        await _commit(next, 'Disattivazione sperimentale $id');
        status =
            'Disattivato solo nella memoria degli assiomi. Puoi ripristinare la revisione precedente.';
      });
  Future<void> undo() =>
      guarded('Ripristino della revisione precedente…', () async {
        final rows = await _db!
            .query('history', columns: ['id'], orderBy: 'id DESC', limit: 1);
        if (rows.isEmpty) throw StateError('Nessuna revisione precedente.');
        final prior = copyJ(jsonDecode(
                await _readPayload0430('history', rows.single['id'] as int))
            as Map);
        await _commit(prior, 'Ripristino');
        status = 'Revisione precedente ripristinata.';
      });
  String export() => const JsonEncoder.withIndent('  ').convert({
        'format': 'mgd-axioms-0430',
        'state': state,
        'revision': student.revision
      });
  Future<void> import(String text) =>
      guarded('Validazione del backup…', () async {
        if (utf8.encode(text).length > 8000000)
          throw const FormatException('Backup oltre 8 MB.');
        final root = jsonDecode(text) as Map;
        if (root['format'] != 'mgd-axioms-0430')
          throw const FormatException(
              'Formato diverso. La memoria neurale precedente non è un backup di assiomi.');
        final next = copyJ(root['state'] as Map);
        AxiomStudent(next['model'] as Map);
        if (next['probes'] is! List ||
            (next['probes'] as List).length > 1000 ||
            next['events'] is! List ||
            next['audits'] is! Map)
          throw const FormatException('Backup incompleto o oltre limite.');
        if (root['revision'] != axHash(next['model']))
          throw const FormatException('Checksum del modello non valido.');
        await compute(axiomJob,
            {'job': 'tests', 'model': next['model'], 'probes': next['probes']});
        await _commit(next, 'Importazione backup');
        status = 'Backup importato. La memoria precedente è nella cronologia.';
      });
  Future<void> stop() async {
    stopped = true;
    status =
        'Interruzione richiesta; nessuna proposta successiva sarà applicata.';
    signal();
    try {
      await channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  Future<void> teach(String text, J world, int rounds) =>
      guarded('Il tutor locale esamina conoscenze e lacune…', () async {
        if (text.trim().isEmpty)
          throw const FormatException(
              'Scrivi una frase o una difficoltà da insegnare.');
        final observed =
            await job('parse', extra: {'text': text, 'world': world});
        if (observed['status'] == 'needs_context') {
          result = observed;
          status =
              'Servono dati contestuali: ${(observed['missing_facts'] as List).join(', ')}. Non creo assiomi per sostituirli.';
          return;
        }
        if (observed['status'] == 'search_limit') {
          result = observed;
          status =
              'Limite di ricerca raggiunto: non è una prova che manchino assiomi.';
          return;
        }
        var feedback = <String, dynamic>{'initial_diagnosis': observed};
        for (var i = 0; i < rounds.clamp(1, 5) && !stopped; i++) {
          final expectedRevision = student.revision;
          status =
              'Ciclo ${i + 1}: inventario → diagnosi → lezione → prove. Il modello è in esecuzione sul dispositivo.';
          signal();
          final inventory = copyJ(state['model'] as Map)..remove('lesson_ids');
          final prompt = jsonEncode({
            'request': text,
            'context': world,
            'inventory': inventory,
            'feedback': feedback
          });
          if (prompt.length > 28000)
            throw StateError(
                'Inventario oltre il contesto del tutor locale: nessuna porzione nascosta sarà dichiarata assente. Esporta per un audit più ampio.');
          final raw = await channel.invokeMethod<String>(
              'generate', {'system': axiomTeacherContract, 'prompt': prompt});
          if (stopped) return;
          if (raw == null || raw.length > 120000)
            throw const FormatException(
                'Risposta del tutor assente o troppo grande.');
          var cleaned = raw.trim();
          if (cleaned.startsWith('```')) {
            cleaned = cleaned
                .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
                .replaceFirst(RegExp(r'\s*```$'), '');
          }
          J proposal;
          try {
            proposal = copyJ(jsonDecode(cleaned) as Map);
          } catch (_) {
            feedback = {
              'invalid_output':
                  'Restituisci un oggetto JSON completo conforme al contratto, non una spiegazione.'
            };
            status =
                'JSON non valido: il ciclo successivo chiederà una correzione.';
            continue;
          }
          // Bind the taught target to the actual user request, not a substitute chosen by the LLM.
          final task = proposal['task'];
          if (task is! Map ||
              canonical(axTokens(task['text']?.toString() ?? '')) !=
                  canonical(axTokens(text))) {
            feedback = {
              'invalid_target':
                  'Aggiungi task con text IDENTICO alla richiesta, intent, args, negated e, se serve, before/expected_after/expected_status. Le probes devono essere diverse dal task e dalle lezioni.'
            };
            continue;
          }
          if (world.isNotEmpty) task['before'] = copyJ(world);
          final assessment = await job('teach', extra: {'proposal': proposal});
          if (stopped || expectedRevision != student.revision) return;
          result = assessment;
          final next = copyJ(state),
              record = copyJ(assessment)..remove('model');
          (next['events'] as List).add({
            'kind': 'teaching',
            'at': DateTime.now().toUtc().toIso8601String(),
            'request': text,
            'diagnosis': proposal['diagnosis'],
            'proposal': proposal,
            'assessment': record
          });
          if ((next['events'] as List).length > 200)
            (next['events'] as List).removeAt(0);
          if (assessment['accepted'] == true) {
            next['model'] = assessment['model'];
            next['audits'] = {};
            final existing =
                (next['probes'] as List).map((q) => canonical(q)).toSet();
            for (final q in [...(assessment['new_probes'] as List), task]) {
              if (existing.add(canonical(q))) (next['probes'] as List).add(q);
            }
            if ((next['probes'] as List).length > 1000)
              throw StateError(
                  'Limite delle prove persistenti raggiunto: non scarto protezioni precedenti.');
            await _commit(next, 'Lezione verificata sul dominio');
            status =
                'Lezione accettata nelle prove formative: ${assessment['transfer_tested']} casi nuovi e ${assessment['protected_tested']} regressioni. Minimalità assoluta non certificata.';
            return;
          }
          await _commit(next, 'Proposta respinta senza cambiare modello');
          feedback = record;
          final attempts = feedback['attempts'] as List?;
          if (attempts != null && attempts.length > 3)
            feedback['attempts'] = attempts.take(3).toList();
          status = 'Proposta respinta: ${assessment['reason']}';
          signal();
        }
        if (!stopped)
          status =
              'Ciclo concluso senza lezione accettata. La lacuna resta aperta; consulta il registro.';
      });
  @override
  void dispose() {
    _disposed = true;
    stopped = true;
    channel.invokeMethod<void>('cancel').catchError((_) {});
    _db?.close();
    super.dispose();
  }
}
