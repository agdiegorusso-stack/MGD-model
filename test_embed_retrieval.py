from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.memory.memory_index import MemoryIndex

enc = TextEncoder(n_input_mgd=512)
mem = MemoryIndex(db_path='/tmp/test_embed.json')

emb1 = enc.encode_text('mi chiamo Diego').tolist()
mem.add_memory('L3_cluster_9', 'USER_INFO', 'Utente si chiama Diego', tags=['nome'], embedding=emb1)

q_emb = enc.encode_text('qual e il mio nome?').tolist()
results = mem.find_similar('L3_cluster_ALTRO', top_k=5, query_embedding=q_emb)
print(f'Trovate {len(results)} memorie per query semantica')
if results:
    print('Top result:', results[0]['summary'])
    print('find_similar embedding-based funziona!')
else:
    print('Nessun risultato sopra soglia (threshold potrebbe essere troppo alta)')
