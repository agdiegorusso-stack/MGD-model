"""
Patch: aggiorna i record con embedding 512-dim a 384-dim.
Cancella i vecchi embedding (salvati con proiezione random) e li ricalcola
con encode_for_memory (384-dim, no proiezione, compatibile con il retrieval attuale).
"""
from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.memory.memory_index import MemoryIndex, _cosine_sim
from tinydb import Query

enc = TextEncoder(n_input_mgd=512)
mem = MemoryIndex()
Record = Query()

updated = 0
for r in mem.records.all():
    emb = r.get("embedding")
    if emb is not None and len(emb) != 384:
        # Vecchio embedding con dimensione sbagliata — ricalcola
        summary = r.get("summary", "")
        new_emb = enc.encode_for_memory(summary).tolist()
        mem.records.update({"embedding": new_emb}, Record.id == r["id"])
        print(f"AGGIORNATO [{r['type']}] {summary[:50]} ({len(emb)}-dim → 384-dim)")
        updated += 1
    elif emb is None:
        # Nessun embedding salvato — calcolalo ora
        summary = r.get("summary", "")
        if summary:
            new_emb = enc.encode_for_memory(summary).tolist()
            mem.records.update({"embedding": new_emb}, Record.id == r["id"])
            print(f"AGGIUNTO embedding a [{r['type']}] {summary[:50]}")
            updated += 1

print(f"\nRecord aggiornati: {updated}")

# Verifica finale
print("\nVerifica cosine similarity:")
q = enc.encode_for_memory("CIAO TI RICORDI COME MI CHIAMO?").tolist()
for r in mem.records.all():
    emb = r.get("embedding")
    if emb:
        sim = _cosine_sim(q, emb)
        print(f"  sim={sim:.4f} [{r['type']}] {r['summary'][:60]}")

results = mem.find_similar("x", top_k=5, query_embedding=q)
print(f"\nfind_similar results: {len(results)}")
for r in results:
    print(f"  -> {r['summary'][:60]}")
