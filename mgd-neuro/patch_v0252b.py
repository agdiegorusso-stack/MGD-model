from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()

old="""    String? answer;
    if (interpretation.isQuestion) {
      answer = _answerFrameQuery(interpretation);
    }

    if (answer == null) {"""
new="""    String? answer;

    // Explicit relational-role cues have semantic precedence at retrieval time.
    // This does NOT replace the normal attractor interpretation: it only asks
    // the dedicated role slot first when the prompt itself contains a role
    // such as compagna/partner/figlia/figlio/madre/padre.
    final roleSurfaces0252b = lexicalTokens(prompt);
    final roleFamily0252b = _roleFamilyIn(roleSurfaces0252b);
    if(roleFamily0252b == 'partner'){
      final roleNormalized0252b = roleSurfaces0252b.map(normalizeText).toList();
      final roleIsQuestion0252b =
          normalizeText(prompt).endsWith('?') ||
          roleNormalized0252b.any(_questionWords.contains);
      final roleInterpretation0252b = _semanticInterpretation(
        roleSurfaces0252b,
        speaker:'user',
        create:false,
        isQuestion:roleIsQuestion0252b,
      );
      if(roleInterpretation0252b != null &&
          roleInterpretation0252b.isQuestion &&
          roleInterpretation0252b.subjectId != null &&
          roleInterpretation0252b.relationId != null){
        answer = _answerFrameQuery(roleInterpretation0252b);
      }
    }

    if (answer == null && interpretation.isQuestion) {
      answer = _answerFrameQuery(interpretation);
    }

    if (answer == null) {"""
if old not in s: raise SystemExit('respond answer anchor missing')
s=s.replace(old,new,1)
p.write_text(s)

p=root/'test'/'plastic_language_brain_v04_test.dart'
s=p.read_text()
insert="""
  test('partner role wins even after identity attractor is repeatedly reinforced', () {
    final brain = PlasticLanguageBrain04();
    for (var i = 0; i < 12; i++) {
      brain.teachResponse('come mi chiamo?', 'Diego', reward: 1.0);
    }
    brain.teachResponse('chi è la mia compagna?', 'Alessandra', reward: 1.0);
    for (var i = 0; i < 12; i++) {
      brain.teachResponse('io chi sono?', 'Diego', reward: 1.0);
    }
    expect(brain.respond('chi è la mia compagna?').toLowerCase(), contains('alessandra'));
  });
"""
pos=s.rfind('}')
if pos<0: raise SystemExit('test close missing')
s=s[:pos]+insert+s[pos:]
p.write_text(s)
