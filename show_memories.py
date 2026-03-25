from cortical_mgd.memory.memory_index import MemoryIndex
mem = MemoryIndex()
print(f"Totale record: {len(mem.records.all())}\n")
for r in sorted(mem.records.all(), key=lambda x: x.get("created_at",""), reverse=True)[:5]:
    print(f"[{r['type']}] {r.get('created_at','')[:19]}")
    print(f"  summary: {r.get('summary','')}")
    print(f"  tags: {r.get('tags',[])} | has_emb: {r.get('embedding') is not None}\n")
