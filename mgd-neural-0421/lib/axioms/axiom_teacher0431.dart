part of 'axiom_store.dart';

extension AxiomTeaching0431 on AxiomStore {
  Future<void> _teacherRecord0431(J record) async {
    if (_disposed) return;
    final next = copyJ(state);
    final events = next['events'] as List;
    events.add({'at': DateTime.now().toUtc().toIso8601String(), ...record});
    while (events.length > 200) {
      events.removeAt(0);
    }
    await _commit(next, 'Registro insegnante: ${record['outcome']}');
  }

  Future<void> teachWithEvidence0431(String text, J world, int rounds) =>
      guarded('Controllo del discepolo prima della lezione…', () async {
        if (text.trim().isEmpty) {
          throw const FormatException('Scrivi una frase da insegnare.');
        }
        final observed =
            await job('parse', extra: {'text': text, 'world': world});
        if (observed['status'] == 'needs_context' ||
            observed['status'] == 'search_limit') {
          result = observed;
          status = observed['status'] == 'needs_context'
              ? 'Servono dati contestuali: ${(observed['missing_facts'] as List).join(', ')}. Non nuovi assiomi.'
              : 'Limite di ricerca raggiunto: non dimostra che manchino assiomi.';
          return;
        }
        // Do not leave an old "unrecognized" result underneath a running teacher.
        result = null;
        signal();
        final runtime =
            await AxiomStore.channel.invokeMapMethod<String, dynamic>('status');
        if (stopped || _disposed) return;
        if (runtime != null && (runtime['loaded']?.toString() ?? '').isEmpty) {
          result = {
            'accepted': false,
            'reason': 'Nessun insegnante caricato. '
                'Apri Scarica / carica Gemma 4 e carica il modello in memoria.'
          };
          status = 'Lezione non avviata: insegnante non caricato.';
          return;
        }
        var feedback = <String, dynamic>{'initial_diagnosis': observed};
        var lastReason = 'Nessuna proposta ricevuta.';
        final limit = rounds.clamp(1, 5);
        for (var i = 0; i < limit && !stopped && !_disposed; i++) {
          final expectedRevision = student.revision;
          final inventory = copyJ(state['model'] as Map)..remove('lesson_ids');
          final prompt = jsonEncode({
            'request': text,
            'context': world,
            'inventory': inventory,
            'feedback': feedback,
            'output_reminder': 'Oggetto completo: task uguale alla richiesta, '
                '1-4 lessons e 3-24 probes operative. expected_after conserva '
                'TUTTI i campi non modificati di before, non è un delta.'
          });
          if (prompt.length > 28000) {
            throw StateError('Inventario oltre il contesto del tutor locale: '
                'nessuna conoscenza è stata nascosta o dichiarata assente.');
          }
          final watch = Stopwatch()..start();
          void progress() {
            if (stopped || _disposed) return;
            status = 'Ciclo ${i + 1}/$limit · Gemma genera la proposta · '
                '${watch.elapsed.inSeconds} s. La verifica deve ancora avvenire.';
            signal();
          }

          progress();
          final ticker =
              Timer.periodic(const Duration(seconds: 1), (_) => progress());
          String? raw;
          Object? runtimeError;
          try {
            raw = await AxiomStore.channel.invokeMethod<String>('generate',
                {'system': axiomTeacherContract0431, 'prompt': prompt});
          } catch (e) {
            runtimeError = e;
          } finally {
            ticker.cancel();
            watch.stop();
          }
          final record = <String, dynamic>{
            'kind': 'teaching',
            'protocol': '0431',
            'cycle': i + 1,
            'request': text,
            'revision_before': expectedRevision,
            'runtime': runtime == null
                ? null
                : {'loaded': runtime['loaded'], 'backend': runtime['backend']},
            'duration_ms': watch.elapsedMilliseconds,
            'raw_response': raw == null
                ? null
                : raw.substring(0, raw.length.clamp(0, 12000)),
            'raw_characters': raw?.length ?? 0,
            'raw_truncated_in_log': (raw?.length ?? 0) > 12000,
            'raw_sha256': raw == null ? null : axHash(raw)
          };
          if (stopped || _disposed) {
            await _teacherRecord0431({...record, 'outcome': 'cancelled'});
            return;
          }
          if (runtimeError != null || raw == null) {
            lastReason = 'Il runtime non ha completato la risposta: '
                '${runtimeError ?? 'risposta assente'}. Nessuna lezione applicata.';
            result = {'accepted': false, 'reason': lastReason};
            await _teacherRecord0431(
                {...record, 'outcome': 'runtime_error', 'reason': lastReason});
            status = lastReason;
            return;
          }
          J? proposal;
          var errors = <String>[];
          try {
            proposal = decodeTeacher0431(raw);
          } catch (e) {
            errors = ['JSON incompleto o non valido: $e'];
          }
          if (proposal != null) {
            if (proposal['lessons'] is List &&
                (proposal['lessons'] as List).isEmpty) {
              errors = [
                'Nessuna lezione proposta: ${proposal['diagnosis'] ?? 'lacuna non risolta'}.'
              ];
            } else {
              errors = teacherProblems0431(proposal, text, world);
            }
          }
          if (errors.isNotEmpty) {
            lastReason = errors.join('\n');
            feedback = {
              'protocol_errors': errors,
              'previous_response_excerpt':
                  raw.substring(0, raw.length.clamp(0, 4000))
            };
            result = {
              'accepted': false,
              'cycle': i + 1,
              'reason': lastReason,
              'error_category':
                  proposal == null ? 'invalid_json' : 'invalid_schema'
            };
            await _teacherRecord0431({
              ...record,
              'outcome': proposal == null ? 'invalid_json' : 'invalid_schema',
              'diagnosis': proposal?['diagnosis'],
              'errors': errors
            });
            status = 'Ciclo ${i + 1}: proposta non applicata. $lastReason';
            signal();
            continue;
          }
          final validProposal = proposal!;
          final task = validProposal['task'] as Map;
          task['before'] = copyJ(world);
          status =
              'Ciclo ${i + 1}/$limit · Verifica del compito, del trasferimento '
              'e delle conoscenze precedenti. Gemma ha terminato la generazione.';
          signal();
          J assessment;
          try {
            assessment = await job('teach', extra: {'proposal': validProposal});
          } catch (e) {
            assessment = {
              'accepted': false,
              'reason':
                  'Proposta non eseguibile nel linguaggio del discepolo: $e'
            };
          }
          if (stopped || _disposed || expectedRevision != student.revision)
            return;
          final report = copyJ(assessment)..remove('model');
          if (assessment['accepted'] == true) {
            final next = copyJ(state);
            next['model'] = assessment['model'];
            next['audits'] = {};
            final existing = (next['probes'] as List).map(canonical).toSet();
            for (final q in [...(assessment['new_probes'] as List), task]) {
              if (existing.add(canonical(q))) (next['probes'] as List).add(q);
            }
            if ((next['probes'] as List).length > 1000) {
              throw StateError(
                  'Limite prove persistenti: non scarto protezioni precedenti.');
            }
            final events = next['events'] as List;
            events.add({
              ...record,
              'at': DateTime.now().toUtc().toIso8601String(),
              'outcome': 'accepted',
              'diagnosis': validProposal['diagnosis'],
              'proposal': validProposal,
              'assessment': report
            });
            while (events.length > 200) {
              events.removeAt(0);
            }
            await _commit(next, 'Lezione verificata sul dominio');
            // Re-run the actual request using persisted knowledge, not the LLM answer.
            final learned =
                await job('parse', extra: {'text': text, 'world': world});
            result = {...report, ...learned, 'request_retested': true};
            status = 'Lezione salvata e richiesta rieseguita dal discepolo: '
                '${learned['status']}. ${assessment['transfer_tested']} prove formative '
                'e ${assessment['protected_tested']} casi precedenti verificati.';
            return;
          }
          lastReason = teachingReason0431(report);
          result = {...report, 'cycle': i + 1, 'reason': lastReason};
          await _teacherRecord0431({
            ...record,
            'outcome': 'rejected',
            'diagnosis': validProposal['diagnosis'],
            'proposal': validProposal,
            'assessment': report
          });
          feedback = report;
          if (feedback['attempts'] is List &&
              (feedback['attempts'] as List).length > 3) {
            feedback['attempts'] =
                (feedback['attempts'] as List).take(3).toList();
          }
          status = 'Ciclo ${i + 1}: lezione respinta. $lastReason';
          signal();
        }
        if (!stopped && !_disposed) {
          final current =
              await job('parse', extra: {'text': text, 'world': world});
          result = {
            ...current,
            'accepted': false,
            'reason': lastReason,
            'diagnostic_log': 'Prove → Registro delle lezioni e delle verifiche'
          };
          status = 'Nessuna lezione accettata in $limit cicli. '
              'Motivo e risposta del tutor sono salvati nel registro.';
        }
      });
}
