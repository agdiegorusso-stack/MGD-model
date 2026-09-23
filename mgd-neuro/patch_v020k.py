from pathlib import Path
import sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
p=root/'lib'/'mgd_language_v020.dart'
s=p.read_text()

# An empty manual-input action must never overwrite a successful corpus result.
old_empty="if(raw.isEmpty){if(mounted)setState(()=>status=sourceName==null?'Il riquadro è vuoto. Incolla del testo oppure usa Importa libro/corpus.':'Il corpus selezionato non contiene testo decodificabile.');return;}"
new_empty="if(raw.isEmpty){if(sourceName!=null && mounted)setState(()=>status='Il corpus selezionato non contiene testo decodificabile.');return;}"
if old_empty not in s: raise SystemExit('empty train guard anchor missing')
s=s.replace(old_empty,new_empty,1)

# Make the pasted-text action visibly separate from one-click corpus import.
old_field="TextField(controller:text,minLines:6,maxLines:14,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Incolla qui italiano grezzo: dialoghi, libri, articoli, trascrizioni…'))"
new_field="TextField(controller:text,minLines:6,maxLines:14,onChanged:(_)=>setState((){}),decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Incolla qui italiano grezzo: dialoghi, libri, articoli, trascrizioni…'))"
if old_field not in s: raise SystemExit('text field anchor missing')
s=s.replace(old_field,new_field,1)

old_buttons="Wrap(spacing:8,children:[FilledButton.icon(onPressed:busy?null:()=>train(text.text),icon:const Icon(Icons.psychology),label:const Text('Impara il testo')),OutlinedButton.icon(onPressed:busy?null:pick,icon:const Icon(Icons.file_open),label:const Text('Importa libro/corpus .txt/.md'))])"
new_buttons="""Wrap(spacing:8,runSpacing:8,children:[
  FilledButton.icon(
    onPressed:busy||text.text.trim().isEmpty?null:()=>train(text.text),
    icon:const Icon(Icons.psychology),
    label:const Text('Impara testo incollato'),
  ),
  OutlinedButton.icon(
    onPressed:busy?null:pick,
    icon:const Icon(Icons.file_open),
    label:const Text('Importa e impara libro/corpus'),
  )
])"""
if old_buttons not in s: raise SystemExit('button row anchor missing')
s=s.replace(old_buttons,new_buttons,1)

# Add an explicit explanation so importing a file is clearly a one-step action.
old_after_buttons="]),if(status.isNotEmpty)...[const SizedBox(height:10),Text(status)],const SizedBox(height:18)"
new_after_buttons="""						
]),const SizedBox(height:6),const Text(
  'Importa e impara libro/corpus è un’azione completa: dopo aver scelto il file MGD lo legge, lo incorpora e lo salva automaticamente. Non serve premere il pulsante del testo incollato.',
  style:TextStyle(fontSize:12),
),if(status.isNotEmpty)...[const SizedBox(height:10),Text(status)],const SizedBox(height:18)"""
# The generated source is minified around the UI; use an exact short anchor instead.
if "]),if(status.isNotEmpty)...[const SizedBox(height:10),Text(status)],const SizedBox(height:18)" not in s:
    raise SystemExit('post-button status anchor missing')
s=s.replace("]),if(status.isNotEmpty)...[const SizedBox(height:10),Text(status)],const SizedBox(height:18)",new_after_buttons,1)

p.write_text(s)

pub=root/'pubspec.yaml'
ps=pub.read_text()
ps=ps.replace('version: 0.20.4+31','version: 0.20.5+32')
pub.write_text(ps)
