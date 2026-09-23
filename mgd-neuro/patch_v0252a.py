from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'lib'/'plastic_language_brain_v04.dart'
s=p.read_text()

# Remove the over-broad semantic interception inserted by 0.25.2.
global_block="""    // Semantic/deictic families must win before generic predicate attractors.
    // Without this call the dedicated partner/child/name parser was dead code:
    // "chi è la mia compagna?" could collapse onto USER identity.
    final semantic = _semanticInterpretation(
      surfaces,
      speaker: speaker,
      create: create,
      isQuestion: isQuestion,
    );
    if (semantic != null) return semantic;

"""
if global_block in s:
    s=s.replace(global_block,'',1)

# For answering, only relational-role questions (partner, daughter, son, etc.)
# get the dedicated semantic parser. All other existing attractor behavior stays intact.
old="""    final interpretation = interpret(prompt, speaker: 'user', create: false);
    final report = learnSurface(prompt, reward: 0.20);"""
new="""    final promptSurfaces0252 = lexicalTokens(prompt);
    final roleFamily0252 = _roleFamilyIn(promptSurfaces0252);
    final semanticRole0252 = roleFamily0252 == null
        ? null
        : _semanticInterpretation(
            promptSurfaces0252,
            speaker:'user',
            create:false,
            isQuestion:promptIsQuestion,
          );
    final interpretation = semanticRole0252 ?? interpret(prompt, speaker: 'user', create: false);
    final report = learnSurface(prompt, reward: 0.20);"""
if old not in s: raise SystemExit('respond interpretation anchor missing')
s=s.replace(old,new,1)

# One-shot correction must store the answer in the semantic role slot, not USER/name.
old="""  void teachResponse(String prompt, String answer, {double reward = 1.0}) {
    final interpretation = interpret(prompt, speaker: 'user', create: true);"""
new="""  void teachResponse(String prompt, String answer, {double reward = 1.0}) {
    final teachSurfaces0252 = lexicalTokens(prompt);
    final teachNormalized0252 = teachSurfaces0252.map(normalizeText).toList();
    final teachIsQuestion0252 =
        normalizeText(prompt).endsWith('?') || teachNormalized0252.any(_questionWords.contains);
    final teachRoleFamily0252 = _roleFamilyIn(teachSurfaces0252);
    final semanticTeach0252 = teachRoleFamily0252 == null
        ? null
        : _semanticInterpretation(
            teachSurfaces0252,
            speaker:'user',
            create:true,
            isQuestion:teachIsQuestion0252,
          );
    final interpretation = semanticTeach0252 ?? interpret(prompt, speaker: 'user', create: true);"""
if old not in s: raise SystemExit('teachResponse anchor missing')
s=s.replace(old,new,1)

# Restrict migration of old one-shot corrections to explicit relational-role prompts.
old="""      final surfaces=lexicalTokens(ep.userText);
      if(surfaces.isEmpty)continue;
      final ns=surfaces.map(normalizeText).toList();"""
new="""      final surfaces=lexicalTokens(ep.userText);
      if(surfaces.isEmpty || _roleFamilyIn(surfaces)==null)continue;
      final ns=surfaces.map(normalizeText).toList();"""
if old in s:
    s=s.replace(old,new,1)

p.write_text(s)
