"""
Simulation test: dimostra se MGD accumula R-STDP utile dopo N iterazioni.

Simula 50 turni su 3 topic distinti con varianti lessicali diverse.
Misura se frasi dello stesso topic convergono sullo stesso cluster MGD.
"""
import torch
import numpy as np
from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.text.mgd_wrapper import MGDTextBrain

enc = TextEncoder()
brain = MGDTextBrain()  # carica pesi salvati se esistono

# 3 topic con varianti lessicali diverse (lo stesso concetto, parole diverse)
TOPICS = {
    "fisica": [
        "la fisica quantistica è affascinante",
        "meccanica quantistica e onde",
        "principio di indeterminazione di heisenberg",
        "l'elettrone si comporta come un'onda",
        "entropia e termodinamica",
        "spazio-tempo emergente dal caos",
        "dimensioni emergenti dalla fisica",
        "particelle subatomiche e quanti",
        "relatività e spaziotempo",
        "gravità quantistica e stringhe",
    ],
    "nome": [
        "mi chiamo Diego",
        "il mio nome è Diego",
        "sono Diego",
        "chiamami Diego",
        "Diego è il mio nome",
        "voglio che tu ricordi il mio nome",
        "il mio nome di battesimo è Diego",
        "Diego Russo",
        "puoi chiamarmi Diego",
        "il nome dell'utente è Diego",
    ],
    "poesia": [
        "le rose son rosse le viole son blu",
        "una poesia romantica",
        "versi poetici sull'amore",
        "la più bella sei tu",
        "rime e versi",
        "sonetto shakespeariano",
        "haiku e forma poetica",
        "poesia lirica italiana",
        "canzone dei poeti",
        "metafore e figure retoriche",
    ],
}

# Three-Factor R-STDP contrastivo:
# Ogni cluster IMPARA solo sul suo topic (+DA) e viene FRENATO dagli altri (-DA_neg).
# Questo è il segnale discriminativo che crea la separazione topologica.
DA_POS = 0.8   # reward per il topic "giusto"
DA_NEG = -0.3  # punizione per topic "sbagliato" nello stesso contesto
TOPIC_LIST = list(TOPICS.keys())

print("=" * 60)
print(f"FASE 1: Prima degli aggiornamenti R-STDP")
print("=" * 60)

def get_clusters(brain, enc, topics):
    result = {}
    for topic, phrases in topics.items():
        clusters = []
        for phrase in phrases:
            mgd_id = brain.encode_text_sequence(phrase, enc)
            clusters.append(mgd_id)
        result[topic] = clusters
    return result

before = get_clusters(brain, enc, TOPICS)
for topic, clusters in before.items():
    from collections import Counter
    c = Counter(clusters)
    dominant, cnt = c.most_common(1)[0]
    pct = cnt / len(clusters) * 100
    print(f"  [{topic:8}] dominant={dominant} ({pct:.0f}%) | all={dict(c)}")

print()
print("=" * 60)
print("FASE 2: Simulazione 5 cicli di 30 turni con R-STDP...")
print("=" * 60)

all_phrases = [(topic, p) for topic, phrases in TOPICS.items() for p in phrases]
np.random.seed(99)

for cycle in range(50):
    np.random.shuffle(all_phrases)
    for topic, phrase in all_phrases:
        # 1. Elabora la frase e cattura l'attivazione corrente
        brain.encode_text_sequence(phrase, enc)
        # 2. Reward contrastivo: +DA per il topic corrente, -DA per tutti gli altri
        # Questo è il cuore della separazione topologica: le sinapsi attive per "fisica"
        # vengono rinforzate SOLO quando arriva una frase di fisica,
        # e vengono INDEBOLITE quando arrivauna frase di nome o poesia.
        brain.apply_dopamine(DA_POS)  # Rafforza il cluster attivo per questo topic
        for other_topic in TOPIC_LIST:
            if other_topic != topic:
                # Elabora una frase dell'altro topic per attivare il cluster concorrente
                other_phrase = TOPICS[other_topic][cycle % len(TOPICS[other_topic])]
                brain.encode_text_sequence(other_phrase, enc)
                brain.apply_dopamine(DA_NEG)  # Penalizza sovrappositione inter-topic
    print(f"  Ciclo {cycle+1}/50 completato ({len(all_phrases)} turni)")

# Salva pesi aggiornati
brain.save_weights()
print("  Pesi salvati in data/mgd_weights.pt")

print("DEBUG WTA FREQ:", brain.brain.L3.wta_freq.max().item())
print("DEBUG MAX W L3:", brain.brain.L3.W.max().item())

print()
print("=" * 60)
print("FASE 3: Cluster dopo R-STDP")
print("=" * 60)

after = get_clusters(brain, enc, TOPICS)
for topic, clusters in after.items():
    from collections import Counter
    c = Counter(clusters)
    dominant, cnt = c.most_common(1)[0]
    pct = cnt / len(clusters) * 100
    print(f"  [{topic:8}] dominant={dominant} ({pct:.0f}%) | all={dict(c)}")

print()
print("=" * 60)
print("ANALISI: MGD crea separazione tra topic?")
print("=" * 60)

before_dominants = {t: Counter(c).most_common(1)[0][0] for t, c in before.items()}
after_dominants  = {t: Counter(c).most_common(1)[0][0] for t, c in after.items()}

# Stabilità: stesso cluster per lo stesso topic?
after_stabilities = {}
for topic, clusters in after.items():
    c = Counter(clusters)
    dominant, cnt = c.most_common(1)[0]
    after_stabilities[topic] = cnt / len(clusters)

# Separazione: topic diversi hanno cluster diversi?
dominant_clusters = list(after_dominants.values())
n_unique = len(set(dominant_clusters))
total_topics = len(dominant_clusters)

print(f"  Stabilità intra-topic (% stesso cluster):")
for topic, stab in after_stabilities.items():
    improved = "↑" if stab > (Counter(before[topic]).most_common(1)[0][1] / len(before[topic])) else "="
    print(f"    [{topic:8}] {stab*100:.0f}% {improved}")

print(f"\n  Separazione inter-topic: {n_unique}/{total_topics} cluster dominanti distinti")
if n_unique == total_topics:
    print("  ✅ VANTAGGIO MGD CONFERMATO: ogni topic ha il suo cluster dominante")
elif n_unique >= 2:
    print("  ⚠️  PARZIALE: alcuni topic condividono un cluster")
else:
    print("  ❌ NESSUNA SEPARAZIONE: tutti i topic nello stesso cluster")

print()
print("CONCLUSIONE:")
for topic in TOPICS:
    print(f"  Prima: [{topic}] → {before_dominants[topic]}")
    print(f"  Dopo:  [{topic}] → {after_dominants[topic]}")
    changed = "✅ cambio" if before_dominants[topic] != after_dominants[topic] else "= stabile"
    print(f"         {changed}")
    print()
