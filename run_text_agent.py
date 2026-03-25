#!/usr/bin/env python3
"""
run_text_agent.py - Text-Only MGD + LLM Agent REPL

Flusso per ogni turno:
  1. Input utente → encode → MGD → mgd_id
  2. Recupero memorie rilevanti da MemoryIndex
  3. Costruzione prompt con [MEMORIE_RILEVANTI] e invio a LLM → risposta
  4. Reflection step: il LLM meta-memoria decide cosa ricordare
"""

import logging
import threading
import queue
import argparse

from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.text.mgd_wrapper import MGDTextBrain
from cortical_mgd.memory.memory_index import MemoryIndex
from cortical_mgd.memory.memory_manager import MemoryManager
from cortical_mgd.memory.cluster_tracker import log_cluster_assignment
from cortical_mgd.distillation.llm_interface import TextLLMInterface

logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    level=logging.INFO
)
logger = logging.getLogger("TextAgent")


def _format_memories_block(memories: list) -> str:
    if not memories:
        return "[MEMORIE_RILEVANTI]\nNessuna memoria disponibile per questo contesto."
    
    lines = ["[MEMORIE_RILEVANTI]"]
    for i, m in enumerate(memories, start=1):
        tags_str = ", ".join(m.get("tags", []))
        summary = m.get("summary", "(nessun riassunto)")
        m_type = m.get("type", "?")
        lines.append(f"{i}) id={m['id']}, type={m_type}, tags=[{tags_str}]")
        lines.append(f"   summary: {summary}")
    lines.append("\nUsa queste memorie per mantenere coerenza con il modo di lavorare dell'utente.")
    lines.append("Non menzionare esplicitamente questi ID nella risposta.")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="MGD-LLM Text Agent")
    parser.add_argument("--model", default=None, help="Modello Ollama da usare (es. qwen2.5:14b, gpt-oss, gemma3:27b)")
    args = parser.parse_args()

    print("=" * 50)
    print("  MGD-LLM Text Agent @ Ollama")
    print("  digitare 'quit' o 'exit' per uscire")
    print("  digitare '!doc <testo>' per ingestire conoscenza")
    print("=" * 50)

    encoder = TextEncoder(n_input_mgd=512)
    brain = MGDTextBrain(n_input_mgd=512)
    memory_index = MemoryIndex()
    llm = TextLLMInterface(model_name=args.model) if args.model else TextLLMInterface()
    manager = MemoryManager(memory_index, llm, mgd_brain=brain, encoder=encoder)

    active_model = args.model or llm.model_name
    print(f"  Modello: {active_model}")
    print("=" * 50)

    # Background queue per meta-memoria non bloccante
    episode_queue = queue.Queue()

    def episode_worker():
        while True:
            ep = episode_queue.get()
            if ep is None:
                break
            try:
                manager.process_episode(ep)
            except Exception as e:
                logger.error(f"[EpisodeWorker] Errore: {e}")
            finally:
                episode_queue.task_done()

    worker_thread = threading.Thread(target=episode_worker, daemon=True)
    worker_thread.start()

    while True:
        try:
            user_input = input("\nTU: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nUscita...")
            break

        if not user_input:
            continue

        if user_input.lower() in ("quit", "exit"):
            print("A presto!")
            break

        # Check for explicit knowledge ingestion command
        new_knowledge_text = ""
        if user_input.startswith("!doc "):
            new_knowledge_text = user_input[5:].strip()
            user_input = f"Ho ingerito una nuova documentazione: {new_knowledge_text[:80]}..."
            print(f"[Agente] Ingestione documentazione in corso...")

        # 1. Encode input: 384-dim (Cosine) e MGD Space spaziale
        raw_emb = encoder.encode_for_memory(user_input)         # 384-dim, sentence-transformers
        # Elaborazione testuale nativa MGD (Spikes spaziotemporali discreti)
        mgd_id = brain.encode_text_sequence(user_input, encoder)
        logger.info(f"[REPL] mgd_id={mgd_id}")

        # Log cluster assignment per stability tracker
        log_cluster_assignment(user_input, mgd_id, source_type="EPISODE")
        logger.info(f"[MGD_CLUSTER] '{user_input[:30]}' → {mgd_id}")

        # 2. Retrieve relevant memories — tri-layer: MGD cluster prima, poi cosine
        query_emb = raw_emb.tolist()
        memories = memory_index.find_similar(mgd_id, top_k=5, query_embedding=query_emb)
        logger.info(f"[REPL] Memorie trovate: {len(memories)} (cluster={sum(1 for m in memories if m.get('mgd_id')==mgd_id)}, cosine={sum(1 for m in memories if m.get('mgd_id')!=mgd_id)})")

        # 3. Build prompt + query LLM
        memories_block = _format_memories_block(memories)
        answer = llm.query_dialogue(user_input, memories_block)
        print(f"\nAGENTE: {answer}")

        # 4. Ogni turno va al reflection step: il LLM decide cosa ricordare
        used_ids = [m["id"] for m in memories]
        ep = manager.build_episode(
            mgd_id=mgd_id,
            question=user_input,
            answer=answer,
            used_memory_ids=used_ids
        )
        episode_queue.put(ep)

    # Graceful shutdown
    episode_queue.put(None)
    worker_thread.join(timeout=5)

    # Salva i pesi MGD — la plasticità R-STDP sopravvive alla sessione
    brain.save_weights()
    logger.info("[REPL] Pesi MGD salvati in data/mgd_weights.pt")


if __name__ == "__main__":
    main()
