"""
cortical_mgd/memory/cluster_tracker.py

Tiene traccia di ogni assegnazione testo → mgd_id per dimostrare che
R-STDP produce cluster stabili nel tempo (vantaggio MGD su embedding statici).
"""
import os
import json
import hashlib
from datetime import datetime
from typing import Optional

_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'data')
os.makedirs(_DATA_DIR, exist_ok=True)
_HISTORY_PATH = os.path.join(_DATA_DIR, 'cluster_history.json')


def _load_history() -> list:
    if os.path.exists(_HISTORY_PATH):
        try:
            with open(_HISTORY_PATH, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return []
    return []


def _save_history(history: list):
    with open(_HISTORY_PATH, 'w', encoding='utf-8') as f:
        json.dump(history, f, ensure_ascii=False, indent=2)


def log_cluster_assignment(
    text: str,
    mgd_id: str,
    session_id: Optional[str] = None,
    source_type: str = "EPISODE"
):
    """
    Registra ogni assegnazione testo → mgd_id in cluster_history.json.
    
    Schema entry:
    {
        "timestamp": "2026-03-24T01:10:00",
        "session_id": "2026-03-24T01",
        "mgd_id": "L3_cluster_5",
        "text_hash": "sha1 dei primi 200 char del testo",
        "text_preview": "primi 50 char del testo",
        "source_type": "API_DEF | PATTERN | EPISODE | USER_INFO"
    }
    """
    if session_id is None:
        session_id = datetime.now().strftime("%Y-%m-%dT%H")

    text_hash = hashlib.sha1(text[:200].encode('utf-8')).hexdigest()[:12]
    entry = {
        "timestamp": datetime.now().isoformat()[:19],
        "session_id": session_id,
        "mgd_id": mgd_id,
        "text_hash": text_hash,
        "text_preview": text[:50],
        "source_type": source_type
    }

    history = _load_history()
    history.append(entry)
    # Mantieni max 10k entries per non far crescere il file all'infinito
    if len(history) > 10000:
        history = history[-10000:]
    _save_history(history)


def compute_stability_report() -> dict:
    """
    Analizza cluster_history.json e produce:
    - stability: per ogni text_hash, % di volte che finisce nello stesso cluster
    - dominant_cluster_per_hash: il cluster più frequente per ogni hash
    - drift_report: cluster con il maggior numero di source_type diversi
    """
    history = _load_history()
    if not history:
        return {"error": "Nessuna entry in cluster_history.json"}

    # Raggruppa per text_hash
    from collections import defaultdict, Counter
    hash_to_clusters = defaultdict(list)
    for entry in history:
        hash_to_clusters[entry["text_hash"]].append(entry["mgd_id"])

    stability_scores = {}
    for text_hash, clusters in hash_to_clusters.items():
        if len(clusters) < 2:
            continue
        c = Counter(clusters)
        dominant, dominant_count = c.most_common(1)[0]
        stability = dominant_count / len(clusters)
        stability_scores[text_hash] = {
            "dominant_cluster": dominant,
            "stability": round(stability, 3),
            "n_observations": len(clusters),
            "all_clusters": dict(c)
        }

    # Cluster con più tipi di source_type (semantica mista)
    cluster_to_types = defaultdict(set)
    for entry in history:
        cluster_to_types[entry["mgd_id"]].add(entry["source_type"])

    drift_report = {
        k: list(v) for k, v in cluster_to_types.items() if len(v) > 1
    }

    return {
        "total_entries": len(history),
        "unique_text_hashes": len(hash_to_clusters),
        "stability_scores": stability_scores,
        "drift_report": drift_report
    }
