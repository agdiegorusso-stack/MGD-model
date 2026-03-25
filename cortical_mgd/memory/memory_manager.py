import logging
from typing import Dict, Any, List, Optional

from cortical_mgd.memory.memory_index import MemoryIndex
from cortical_mgd.distillation.llm_interface import TextLLMInterface

logger = logging.getLogger(__name__)

# Hardcoded list of trivial turns to skip even before calling LLM
# (single salutations that carry zero new info)
_TRIVIAL_TURNS = {"ciao", "ok", "grazie", "prego", "va bene", "perfetto", "bene", "no", "si", "sì"}

MIN_QUESTION_LEN = 4  # skip only if user typed < 4 chars (e.g. empty, punctuation)

# Mapping from action+type to dopamine delta
DA_POLICY = {
    ("STORE",  "API_DEF"):   1.0,
    ("UPDATE", "API_DEF"):   1.0,
    ("STORE",  "USER_INFO"): 1.0,
    ("UPDATE", "USER_INFO"): 1.0,
    ("STORE",  "PATTERN"):   0.3,
    ("UPDATE", "PATTERN"):   0.3,
    ("STORE",  "EPISODE"):   0.1,
    ("UPDATE", "EPISODE"):   0.0,
    ("IGNORE", "API_DEF"):   0.0,
    ("IGNORE", "USER_INFO"): 0.0,
    ("IGNORE", "PATTERN"):   0.0,
    ("IGNORE", "EPISODE"):   0.0,
}


def _build_meta_prompt(question: str, answer: str, existing_memories: List[Dict], mgd_id: str) -> str:
    existing_block = ""
    if existing_memories:
        for m in existing_memories:
            existing_block += f"- id={m['id']}, type={m['type']}, tags={m['tags']}\n  summary: {m['summary']}\n"
    else:
        existing_block = "(nessuna memoria precedente per questo contesto)"

    return f"""Hai appena parlato con un utente. Ecco lo scambio:

[UTENTE]: {question}
[ASSISTENTE]: {answer}

---
Memorie già salvate su questo contesto:
{existing_block}

---
Decidi se è opportuno memorizzare qualcosa di questo scambio per le sessioni future.
Usa il tuo giudizio: considera cosa potrebbe essere utile ricordare e cosa no.

Formato risposta - SOLO JSON, nessun altro testo:
{{
  "action": "STORE" | "UPDATE" | "IGNORE",
  "type": "API_DEF" | "PATTERN" | "USER_INFO" | "EPISODE",
  "summary": "(breve riassunto - max 40 parole, vuoto se IGNORE)",
  "tags": [],
  "target_memory_id": null
}}"""


class MemoryManager:
    def __init__(self, memory_index: MemoryIndex, llm: TextLLMInterface, mgd_brain=None, encoder=None):
        self.memory_index = memory_index
        self.llm = llm
        self.mgd_brain = mgd_brain  # Optional MGDTextBrain for dopamine feedback
        self.encoder = encoder       # Optional TextEncoder for semantic retrieval
        
    def build_episode(
        self,
        mgd_id: str,
        question: str,
        answer: str,
        used_memory_ids: List[str],
        new_knowledge_text: str = ""
    ) -> Dict[str, Any]:
        """Step 1: Constructs an EpisodeRecord dict."""
        return {
            "mgd_id": mgd_id,
            "question": question,
            "answer": answer,
            "used_memory_ids": used_memory_ids,
            "new_knowledge_text": new_knowledge_text
        }

    def process_episode(self, episode: Dict[str, Any]) -> Optional[Dict]:
        """
        Reflection step: chiede al LLM cosa ricordare da questa conversazione.
        Salta solo se la domanda è completamente vuota o un saluto banale.
        Il LLM decide tutto il resto via IGNORE.
        """
        question = episode.get("question", "").strip()
        answer = episode.get("answer", "").strip()
        mgd_id = episode.get("mgd_id", "")

        # Salta solo se input è vuoto o un saluto monosillabico
        if not question or len(question) < MIN_QUESTION_LEN or question.lower() in _TRIVIAL_TURNS:
            logger.info(f"[MemoryManager] Turno banale saltato: '{question}'")
            return None

        # Lookup existing memories — con embedding semantico 384-dim se disponibile
        query_emb = None
        if self.encoder is not None:
            try:
                query_emb = self.encoder.encode_for_memory(question).tolist()
            except Exception:
                pass
        existing_memories = self.memory_index.find_similar(
            mgd_id_q=mgd_id,
            top_k=5,
            query_embedding=query_emb
        )

        # Build reflection prompt + query LLM
        meta_prompt = _build_meta_prompt(question, answer, existing_memories, mgd_id)
        policy = self.llm.query_memory_policy(meta_prompt)
        
        action = policy.get("action", "IGNORE")
        m_type = policy.get("type", "EPISODE")
        summary = policy.get("summary", "")
        tags = policy.get("tags", [])
        target_id = policy.get("target_memory_id", None)

        # Log decision
        logger.info(f"[MemoryManager] Policy → action={action}, type={m_type}, tags={tags}")

        # Apply decision to index
        if action == "STORE":
            # Calcola embedding 384-dim del summary per ricerca semantica futura
            summary_emb = None
            if self.encoder is not None and summary:
                try:
                    summary_emb = self.encoder.encode_for_memory(summary).tolist()
                except Exception:
                    pass

            new_id = self.memory_index.add_memory(
                mgd_id=mgd_id,
                m_type=m_type,
                summary=summary,
                tags=tags,
                embedding=summary_emb
            )
            logger.info(f"[MemoryManager] STORE → created memory id={new_id} type={m_type}")
        elif action == "UPDATE" and target_id:
            # LTD sul vecchio pattern sinaptico: indebolisce le sinapsi del fatto che
            # stiamo sovrascrivendo, cosi future query non ritornano piu il vecchio valore.
            # Questo e il mecanismo fondamentale che distingue MGD da RAG:
            # RAG non puo dimenticare (accumula), MGD sovrascrive selettivamente.
            old_memory = self.memory_index.get_by_id(target_id)
            if old_memory and self.mgd_brain is not None and self.encoder is not None:
                old_text = old_memory.get("summary", "")
                if old_text:
                    self.mgd_brain.encode_text_sequence(old_text, self.encoder)
                    self.mgd_brain.apply_dopamine(-0.5)

            summary_emb = None
            if self.encoder is not None and summary:
                try:
                    summary_emb = self.encoder.encode_for_memory(summary).tolist()
                except Exception:
                    pass
            self.memory_index.update_memory(target_id, {
                "summary": summary,
                "tags": tags,
                "mgd_id": mgd_id,
                "embedding": summary_emb,
            })
            logger.info(f"[MemoryManager] UPDATE → updated memory id={target_id} type={m_type}")

        # Also persist episode
        self.memory_index.add_episode(
            mgd_id=mgd_id,
            question=question,
            answer=answer,
            used_memory_ids=episode.get("used_memory_ids", []),
            new_knowledge_text=f"{question} {answer}"
        )

        # Dopamine feedback
        delta_da = DA_POLICY.get((action, m_type), 0.0)
        if delta_da > 0 and self.mgd_brain is not None:
            self.mgd_brain.apply_dopamine(delta_da)
            logger.info(f"[MemoryManager] DA spike: delta={delta_da} (action={action}, type={m_type})")

        return policy

    # ------------------------------------------------------------------
    # Step C — Memory Compaction
    # ------------------------------------------------------------------

    def compact_episodes(self, max_episodes_per_cluster: int = 10):
        """
        Compatta episodi accumulati in un cluster in un PATTERN consolidato.

        Per ogni mgd_id che ha più di `max_episodes_per_cluster` record di tipo EPISODE:
          1. Raccoglie i summary degli EPISODE
          2. Chiede al LLM di sintetizzarli in un unico PATTERN (una frase breve)
          3. Salva il PATTERN come nuovo MemoryRecord
          4. Cancella gli EPISODE originali

        Non tocca mai API_DEF e USER_INFO.
        """
        from collections import defaultdict
        from tinydb import Query

        all_records = self.memory_index.records.all()

        # Raggruppa EPISODE per mgd_id
        cluster_episodes: dict = defaultdict(list)
        for r in all_records:
            if r.get("type") == "EPISODE":
                cluster_episodes[r.get("mgd_id", "unknown")].append(r)

        compacted = 0
        for mgd_id, episodes in cluster_episodes.items():
            if len(episodes) <= max_episodes_per_cluster:
                continue

            # Costruisci prompt per il LLM
            summaries_text = "\n".join(
                f"- {ep.get('summary', '')}" for ep in episodes[:20]
            )
            prompt = (
                f"Hai {len(episodes)} episodi di memoria associati allo stesso cluster cognitivo.\n"
                f"Sintetizzali in UN SOLO pattern generale (max 30 parole) che cattura il tema comune.\n"
                f"Rispondi SOLO con il testo del pattern, senza prefissi.\n\n"
                f"Episodi:\n{summaries_text}"
            )

            try:
                pattern_text = self.llm._post(prompt, format_json=True)
                pattern_text = pattern_text.strip()
                if not pattern_text:
                    continue
            except Exception as e:
                logger.warning(f"[MemoryManager] compact_episodes LLM error: {e}")
                continue

            # Calcola embedding del pattern
            pattern_emb = None
            if self.encoder is not None:
                try:
                    pattern_emb = self.encoder.encode_for_memory(pattern_text).tolist()
                except Exception:
                    pass

            # Salva il PATTERN consolidato
            self.memory_index.add_memory(
                mgd_id=mgd_id,
                mem_type="PATTERN",
                summary=pattern_text,
                tags=["compacted"],
                embedding=pattern_emb
            )

            # Cancella gli EPISODE originali
            Record = Query()
            ids_to_delete = [ep["id"] for ep in episodes]
            for rec_id in ids_to_delete:
                self.memory_index.records.remove(Record.id == rec_id)

            compacted += len(episodes)
            logger.info(
                f"[MemoryManager] Compacted {len(episodes)} EPISODE → 1 PATTERN "
                f"in cluster {mgd_id}: '{pattern_text[:50]}'"
            )

        if compacted == 0:
            logger.info("[MemoryManager] compact_episodes: nessun cluster da compattare.")
        return compacted
