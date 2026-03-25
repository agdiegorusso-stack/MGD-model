"""
Diagnosi: MGD porta vantaggi concreti o no?
Confronta retrieval SOLO-MGD vs SOLO-cosine vs ibrido tri-layer.
"""
from cortical_mgd.memory.memory_index import MemoryIndex, _cosine_sim
from cortical_mgd.memory.cluster_tracker import compute_stability_report
from cortical_mgd.text.text_encoder import TextEncoder
import json

enc = TextEncoder()
mem = MemoryIndex()
all_rec = mem.records.all()

print("=" * 60)
print("DB CONTENTS")
print("=" * 60)
for r in all_rec:
    has_emb = r.get("embedding") is not None
    print(f"[{r['type']:10}] cluster={r.get('mgd_id','?'):15} emb={has_emb} | {r.get('summary','')[:55]}")

print()
print("=" * 60)
print("RETRIEVAL COMPARISON — query: 'dimmi il tuo sviluppatore'")
print("=" * 60)

query = "dimmi il tuo sviluppatore"
q_emb = enc.encode_for_memory(query).tolist()
q_vec = enc._project(enc.encode_for_memory(query))
from cortical_mgd.text.mgd_wrapper import MGDTextBrain
brain = MGDTextBrain()
mgd_id_q = brain.encode_and_forward(q_vec)
print(f"Query mgd_id: {mgd_id_q}")

# SOLO MGD cluster
only_mgd = [r for r in all_rec if r.get("mgd_id") == mgd_id_q]
print(f"\nSOLO MGD ({len(only_mgd)} risultati):")
for r in only_mgd:
    print(f"  [{r['type']}] {r.get('summary','')[:55]}")

# SOLO cosine
scored = []
for r in all_rec:
    emb = r.get("embedding")
    if emb:
        sim = _cosine_sim(q_emb, emb)
        scored.append((sim, r))
scored.sort(reverse=True)
print(f"\nSOLO cosine threshold>=0.15 ({sum(1 for s,_ in scored if s>=0.15)} risultati):")
for sim, r in scored:
    marker = "✓" if sim >= 0.15 else "✗"
    print(f"  {marker} sim={sim:.3f} [{r['type']}] {r.get('summary','')[:50]}")

# TRI-LAYER
tri = mem.find_similar(mgd_id_q, top_k=5, query_embedding=q_emb)
cluster_count = sum(1 for r in tri if r.get("mgd_id") == mgd_id_q)
cosine_count = len(tri) - cluster_count
print(f"\nTRI-LAYER ({len(tri)} risultati: {cluster_count} MGD, {cosine_count} cosine):")
for r in tri:
    src = "MGD" if r.get("mgd_id") == mgd_id_q else "cos"
    print(f"  [{src}] [{r['type']}] {r.get('summary','')[:55]}")

print()
print("=" * 60)
print("CLUSTER STABILITY REPORT")
print("=" * 60)
report = compute_stability_report()
print(f"Totale entry: {report.get('total_entries', 0)}")
print(f"Hash unici: {report.get('unique_text_hashes', 0)}")
scores = report.get("stability_scores", {})
if scores:
    for h, s in list(scores.items())[:5]:
        print(f"  hash={h} | dominant={s['dominant_cluster']} | stability={s['stability']} | n={s['n_observations']}")
else:
    print("  (troppo poche sessioni per misurare stabilità — servono almeno 2 osservazioni dello stesso hash)")

drift = report.get("drift_report", {})
if drift:
    print(f"\nCluster con tipi misti (potenziale deriva): {list(drift.keys())[:3]}")
