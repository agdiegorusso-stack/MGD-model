from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.memory.memory_index import MemoryIndex, _cosine_sim
enc = TextEncoder(n_input_mgd=512)
mem = MemoryIndex()
q = enc.encode_text("CIAO TI RICORDI COME MI CHIAMO?").tolist()
for r in mem.records.all():
    emb = r.get("embedding")
    if emb:
        sim = _cosine_sim(q, emb)
        print(f"sim={sim:.4f} [{r['type']}] {r['summary'][:60]}")
    else:
        print(f"NO_EMB [{r['type']}] {r['summary'][:60]}")
results = mem.find_similar("x", top_k=5, query_embedding=q)
print(f"find_similar results con nuova soglia 0.15: {len(results)}")
for r in results:
    print(" ->", r["summary"][:60])
