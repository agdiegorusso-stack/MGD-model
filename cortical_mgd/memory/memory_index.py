import os
import uuid
import numpy as np
from typing import List, Dict, Any, Optional
from datetime import datetime
from tinydb import TinyDB, Query

# Salva fisicamente in /data/memory_index.json
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'data')
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR, exist_ok=True)

DB_PATH = os.path.join(DATA_DIR, 'memory_index.json')


def _cosine_sim(a: List[float], b: List[float]) -> float:
    va = np.array(a, dtype=np.float32)
    vb = np.array(b, dtype=np.float32)
    na, nb = np.linalg.norm(va), np.linalg.norm(vb)
    if na == 0 or nb == 0:
        return 0.0
    return float(np.dot(va, vb) / (na * nb))


class MemoryIndex:
    def __init__(self, db_path: str = DB_PATH):
        self.db = TinyDB(db_path)
        self.records = self.db.table('memory_records')
        self.episodes = self.db.table('episode_records')

    def _now(self) -> str:
        return datetime.utcnow().isoformat() + "Z"

    def add_memory(
        self,
        mgd_id: str,
        m_type: str,
        summary: str,
        tags: List[str] = None,
        source_ref: str = "",
        extra: Dict = None,
        embedding: List[float] = None   # <-- nuovo: vettore semantico del summary
    ) -> str:
        record_id = str(uuid.uuid4())
        record = {
            "id": record_id,
            "mgd_id": mgd_id,
            "type": m_type,
            "summary": summary,
            "tags": tags or [],
            "source_ref": source_ref,
            "extra": extra or {},
            "embedding": embedding,         # None se non fornito
            "created_at": self._now(),
            "updated_at": self._now()
        }
        self.records.insert(record)
        return record_id

    def update_memory(self, record_id: str, changes: Dict[str, Any]) -> bool:
        Record = Query()
        changes['updated_at'] = self._now()
        updated_ids = self.records.update(changes, Record.id == record_id)
        return len(updated_ids) > 0

    def get_by_id(self, record_id: str) -> Optional[Dict[str, Any]]:
        Record = Query()
        res = self.records.search(Record.id == record_id)
        return res[0] if res else None

    def find_similar(
        self,
        mgd_id_q: str,
        top_k: int = 5,
        query_embedding: List[float] = None,
        embedding_threshold: float = 0.15
    ) -> List[Dict[str, Any]]:
        """
        Retrieval tri-layer — MGD cluster è il driver primario:

        Layer 1 (MGD): recupera tutte le memorie con mgd_id == mgd_id_q.
                       Questi vanno SEMPRE in testa — l'R-STDP appreso guida il retrieval.
        Layer 2 (embedding): se i record MGD sono < top_k, riempie gli slot mancanti
                             con cosine similarity ≥ threshold su record con embedding.
                             Backup per concetti nuovi non ancora consolidati in cluster.
        Layer 3 (dedup): unisce i due set senza duplicati, MGD records sempre in testa.

        Nota: record senza embedding vengono recuperati SOLO via Layer 1 (MGD cluster).
        Questo enfatizza il vantaggio dei cluster appresi: sono l'unico modo per
        ritrovare "vecchia" conoscenza senza embedding moderni.
        """
        all_records = self.records.all()

        # --- Layer 1: MGD cluster ---
        mgd_records = [r for r in all_records if r.get("mgd_id") == mgd_id_q]
        mgd_ids = {r["id"] for r in mgd_records}

        results = list(mgd_records)  # MGD records sempre in testa

        # --- Layer 2: cosine similarity per riempire slot mancanti ---
        if len(results) < top_k and query_embedding is not None:
            scored = []
            for r in all_records:
                if r["id"] in mgd_ids:
                    continue  # già incluso
                emb = r.get("embedding")
                if emb is not None:
                    sim = _cosine_sim(query_embedding, emb)
                    if sim >= embedding_threshold:
                        scored.append((sim, r))

            scored.sort(key=lambda x: x[0], reverse=True)
            slots_remaining = top_k - len(results)
            for _, r in scored[:slots_remaining]:
                results.append(r)

        return results[:top_k]

    def add_episode(self, mgd_id: str, question: str, answer: str, used_memory_ids: List[str], new_knowledge_text: str = "") -> str:
        episode_id = str(uuid.uuid4())
        record = {
            "id": episode_id,
            "mgd_id": mgd_id,
            "type": "EPISODE",
            "question": question,
            "answer": answer,
            "used_memory_ids": used_memory_ids,
            "new_knowledge_text": new_knowledge_text,
            "created_at": self._now()
        }
        self.episodes.insert(record)
        return episode_id
