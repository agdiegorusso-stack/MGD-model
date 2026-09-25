"""A descriptive figure from recorded results; no model fitting or selection."""
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).parent
r = json.loads((ROOT / 'results/results.json').read_text())
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10})
fig, ax = plt.subplots(figsize=(10, 5.8), layout='constrained')
series = [('MGD', 'MGD', '#246a9d'),
          ('MGD_no_material_retuned', 'MGD senza materia', '#9dabb6'),
          ('Transformer_mean', 'Transformer (media 3 seed)', '#cc6940'),
          ('EMA', 'Media esponenziale (EMA)', '#359277')]
x = np.arange(4)
width = .18
for i, (key, label, color) in enumerate(series):
    acc = [v['accuracy'] * 100 for v in r['results'][key].values()]
    acc.append(float(np.mean(acc)))
    bars = ax.bar(x + (i - 1.5) * width, acc, width=width, color=color, label=label)
    ax.bar_label(bars, labels=[f'{v:.1f}' for v in acc], padding=3, fontsize=8)
ax.set_ylim(0, 108)
ax.set_yticks([0, 25, 50, 75, 100])
ax.set_ylabel('Accuratezza sul test (%)')
ax.set_xticks(x, ['Stazionario', 'Cambiamenti\nmoderati', 'Cambiamenti\nfrequenti', 'Media\ncriterio primario'])
ax.grid(axis='y', alpha=.2)
ax.set_axisbelow(True)
ax.spines[['top', 'right']].set_visible(False)
ax.legend(loc='upper center', bbox_to_anchor=(.5, 1.20), ncol=2, frameon=False)
fig.suptitle('MGD: beneficio della materia, nessuna vittoria complessiva',
             fontsize=14, fontweight='bold')
fig.supxlabel('768 episodi sintetici indipendenti • 86.016 eventi valutati per modello\n'
              'Compito di memoria chiave-valore; non è un test di linguaggio naturale.', fontsize=9)
fig.savefig(ROOT / 'comparison.png', dpi=180)
print(ROOT / 'comparison.png')
