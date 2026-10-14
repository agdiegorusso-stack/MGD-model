part of 'axiom_store.dart';

extension AxiomTeaching0432 on AxiomStore {
  Future<void> teachCompact0432(String text, J world, int rounds) =>
      guarded('Controllo conoscenze e prerequisiti…', () async {
    if (text.trim().isEmpty) throw const FormatException('Scrivi una frase da insegnare.');
    final observed = await job('parse', extra: {'text': text, 'world': world});
    if (stopped || _disposed) return;
    if (const ['applied', 'event_denied_no_update', 'preconditions_false'].contains(observed['status'])) {
      result = {...observed, 'already_known': true};
      status = 'Il discepolo comprende già la frase. Nessuna lezione duplicata e nessuna chiamata a Gemma.';
      return;
    }
    if (observed['status'] == 'needs_context' || observed['status'] == 'search_limit') {
      result = observed;
      status = observed['status'] == 'needs_context'
          ? 'Mancano fatti contestuali: ${observed['missing_facts']}. Non nuovi assiomi.'
          : 'Limite di ricerca: non dimostra che manchino assiomi.';
      return;
    }
    final revision = student.revision;
    final candidates = await compute(_compactInventory0432, {'model': state['model'], 'request': text});
    if (stopped || _disposed) return;
    if (candidates.isEmpty) {
      result = {'accepted': false, 'reason': 'Nessuna composizione nota permette un collegamento lessicale sicuro. '
          'Serve una nuova costruzione o composizione, non un sinonimo inventato.'};
      status = result!['reason'] as String;
      await _teacherRecord0431({'kind': 'teaching', 'protocol': '0432', 'request': text,
          'outcome': 'extension_needed', 'reason': status, 'revision_before': revision});
      return;
    }
    final runtime = await AxiomStore.channel.invokeMapMethod<String, dynamic>('status');
    if (stopped || _disposed) return;
    if (runtime == null || (runtime['loaded']?.toString() ?? '').isEmpty) {
      result = {'accepted': false, 'reason': 'Nessun insegnante caricato. Apri Scarica / carica Gemma 4.'};
      status = result!['reason'] as String;
      return;
    }
    result = null;
    signal();
    String? feedback;
    final limit = rounds.clamp(1, 3);
    for (var cycle = 1; cycle <= limit && !stopped && !_disposed; cycle++) {
      final prompt = compactPrompt0432(text, candidates, feedback: feedback);
      if (prompt.length + compactTeacherSystem0432.length > 8000) {
        throw const FormatException('Richiesta compatta troppo ampia: nessun inventario dichiarato completo.');
      }
      final watch = Stopwatch()..start();
      void progress() {
        if (stopped || _disposed) return;
        status = 'Ciclo $cycle/$limit · Gemma sceglie un significato · ${watch.elapsed.inSeconds} s. '
            'Risposta breve; lezioni e prove vengono costruite dal codice.';
        signal();
      }
      progress();
      final ticker = Timer.periodic(const Duration(seconds: 1), (_) => progress());
      String? raw;
      Object? failure;
      try {
        raw = await AxiomStore.channel.invokeMethod<String>('generate', {
          'system': compactTeacherSystem0432, 'prompt': prompt,
          'json_schema': jsonEncode(compactSchema0432(candidates)),
          'max_output_tokens': 64, 'timeout_seconds': 60, 'protocol': '0432'
        });
      } catch (e) { failure = e; }
      finally { ticker.cancel(); watch.stop(); }
      final record = <String, dynamic>{
        'kind': 'teaching', 'protocol': '0432', 'cycle': cycle, 'request': text,
        'revision_before': revision, 'runtime': {
          'loaded': runtime['loaded'], 'backend': runtime['backend'],
          'model_sha256': runtime['loadedSha256'], 'model_name': runtime['loadedName']
        }, 'duration_ms': watch.elapsedMilliseconds,
        'prompt_characters': prompt.length + compactTeacherSystem0432.length,
        'max_output_tokens': 64, 'constrained_decoding': true,
        'raw_response': raw == null ? null : raw.substring(0, raw.length.clamp(0, 1200)),
        'raw_characters': raw?.length ?? 0, 'raw_sha256': raw == null ? null : axHash(raw),
        'candidates': candidates,
        'scope': 'Equivalenza lessicale proposta da LLM; regressioni e trasferimento nel simulatore.'
      };
      if (stopped || _disposed || revision != student.revision) {
        await _teacherRecord0431({...record, 'outcome': 'cancelled'});
        return;
      }
      if (failure != null || raw == null) {
        final reason = 'Il runtime non ha completato la risposta breve: ${failure ?? 'risposta assente'}. '
            'Nessuna conoscenza modificata. Il registro conserva modello, backend e durata.';
        result = {'accepted': false, 'reason': reason};
        await _teacherRecord0431({...record, 'outcome': 'runtime_error', 'reason': reason});
        status = reason;
        return;
      }
      String choice;
      try { choice = compactChoice0432(raw, candidates); }
      catch (e) {
        feedback = 'Serve {"choice":"CODICE"} con un codice offerto oppure UNKNOWN. $e';
        result = {'accepted': false, 'reason': feedback};
        await _teacherRecord0431({...record, 'outcome': 'invalid_compact_response', 'reason': '$e'});
        continue;
      }
      if (choice == 'UNKNOWN') {
        result = {'accepted': false, 'reason': 'Gemma non conferma un’equivalenza con le composizioni note. '
            'Non viene forzata una risposta né aggiunto un falso assioma.'};
        await _teacherRecord0431({...record, 'outcome': 'no_semantic_equivalence'});
        status = result!['reason'] as String;
        return;
      }
      final selected = candidates.singleWhere((c) => c['id'] == choice);
      status = 'Gemma ha scelto il significato. Ora il discepolo verifica trasferimento, negazioni e memoria.';
      signal();
      J compiled;
      try {
        compiled = await compute(_compactAssess0432, {
          'model': state['model'], 'request': text, 'world': world,
          'candidate': selected, 'regression': probes
        });
      } catch (e) {
        result = {'accepted': false, 'reason': 'Proposta non verificabile: $e'};
        await _teacherRecord0431({...record, 'outcome': 'verification_error', 'reason': '$e'});
        status = result!['reason'] as String;
        return;
      }
      if (stopped || _disposed || revision != student.revision) {
        await _teacherRecord0431({...record, 'outcome': 'cancelled'});
        return;
      }
      final assessment = copyJ(compiled['assessment'] as Map);
      final proposal = copyJ(compiled['proposal'] as Map);
      final report = copyJ(assessment)..remove('model');
      if (assessment['accepted'] != true) {
        result = {...report, 'reason': teachingReason0431(report)};
        await _teacherRecord0431({...record, 'outcome': 'rejected', 'assessment': report});
        status = result!['reason'] as String;
        return;
      }
      final next = copyJ(state);
      next['model'] = assessment['model'];
      next['audits'] = {};
      final existing = (next['probes'] as List).map(canonical).toSet();
      for (final q in [...(assessment['new_probes'] as List), proposal['task']]) {
        if (existing.add(canonical(q))) (next['probes'] as List).add(q);
      }
      if ((next['probes'] as List).length > 1000) {
        throw StateError('Limite prove persistenti: non scarto protezioni precedenti.');
      }
      final events = next['events'] as List;
      events.add({...record, 'at': DateTime.now().toUtc().toIso8601String(),
        'outcome': 'accepted', 'proposal': proposal, 'assessment': report,
        'independent_semantic_truth_proven': false});
      while (events.length > 200) { events.removeAt(0); }
      await _commit(next, 'Equivalenza lessicale verificata 0432');
      final learned = await job('parse', extra: {'text': text, 'world': world});
      result = {...report, ...learned, 'request_retested': true,
        'learned_surface': (selected['surface'] as List).join(' '),
        'teacher_reference': selected['reference'], 'teacher_duration_ms': watch.elapsedMilliseconds};
      status = 'Appreso «${result!['learned_surface']}». Richiesta rieseguita dal discepolo: ${learned['status']}. '
          '${assessment['transfer_tested']} verifiche formative; ${assessment['protected_tested']} casi precedenti conservati.';
      return;
    }
    if (!stopped && !_disposed) {
      status = 'Risposta compatta non valida. Nessuna conoscenza modificata; dettagli nel registro.';
    }
  });
}

List<J> _compactInventory0432(J q) => compactCandidates0432(
    AxiomStudent(q['model'] as Map), q['request'] as String);
J _compactAssess0432(J q) {
  final original = AxiomStudent(q['model'] as Map);
  final regression = (q['regression'] as List).cast<Map>();
  final proposal = compactPackage0432(original, q['request'] as String,
      copyJ(q['world'] as Map), copyJ(q['candidate'] as Map), regression);
  return {'proposal': proposal, 'assessment': validateTeaching(original, proposal, regression)};
}
