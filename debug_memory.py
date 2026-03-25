from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.memory.memory_index import MemoryIndex, _cosine_sim

enc = TextEncoder(n_input_mgd=512)
mem = MemoryIndex()

all_records = mem.records.all()
print(f"Totale record nel DB: {len(all_records)}")
for r in all_records:
    has_emb = r.get("embedding") is not None
    print(f"  - [{r['type']}] {r['summary']} | has_embedding={has_emb}")

print()

# Simula query "ti ricordi come mi chiamo?" vs ogni embedding salvato
q_vec = enc.encode_text("CIAO TI RICORDI COME MI CHIAMO?")
q_list = q_vec.tolist()

print("Cosine similarity con query 'CIAO TI RICORDI COME MI CHIAMO?':")
for r in all_records:
    emb = r.get("embedding")
    if emb:
        sim = _cosine_sim(q_list, emb)
        print(f"  [{r['type']}] sim={sim:.4f} | '{r['summary']}'")
    else:
        print(f"  [{r['type']}] NESSUN EMBEDDING | '{r['summary']}'")
