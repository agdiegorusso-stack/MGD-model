from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, List, Tuple


@dataclass
class RelationBelief:
    source: str
    relation: str
    target: str
    support: float = 0.0
    oppose: float = 0.0
    teacher_prior: float = 0.0
    provenance: str = ""

    @property
    def probability(self) -> float:
        # Weak symmetric Beta base prior. Teacher knowledge enters only as a
        # small pseudo-count, so a few direct experiences can overturn it.
        alpha = 1.0 + self.support + self.teacher_prior
        beta = 1.0 + self.oppose
        return alpha / (alpha + beta)

    @property
    def confidence(self) -> float:
        return abs(self.probability - 0.5) * 2.0


class RelationalPriorMemory:
    """Plastic relation memory bridging offline teacher and online MGD learning."""

    def __init__(self, teacher_prior_cap: float = 0.45) -> None:
        self.teacher_prior_cap = teacher_prior_cap
        self._beliefs: Dict[Tuple[str, str, str], RelationBelief] = {}

    @staticmethod
    def _key(source: str, relation: str, target: str) -> Tuple[str, str, str]:
        return source.strip(), relation.strip(), target.strip()

    def _get(self, source: str, relation: str, target: str) -> RelationBelief:
        key = self._key(source, relation, target)
        if key not in self._beliefs:
            self._beliefs[key] = RelationBelief(*key)
        return self._beliefs[key]

    def ingest_teacher_pack(self, pack: dict) -> int:
        if pack.get("format") != "mgd-teacher-pack-v2":
            raise ValueError("expected mgd-teacher-pack-v2")

        imported = 0
        model = str(pack.get("teacher", {}).get("model", "unknown"))
        for item in pack.get("relations", []):
            if not item.get("plastic", True):
                continue
            source = str(item["source"])
            relation = str(item["relation"])
            target = str(item["target"])
            strength = max(
                0.0,
                min(
                    self.teacher_prior_cap,
                    float(item.get("prior_strength", 0.0)),
                ),
            )
            belief = self._get(source, relation, target)
            belief.teacher_prior = max(belief.teacher_prior, strength)
            belief.provenance = (
                f"teacher:{model}:{item.get('evidence', 'unknown')}"
            )
            imported += 1
        return imported

    def observe(
        self,
        source: str,
        relation: str,
        target: str,
        supported: bool = True,
        weight: float = 1.0,
    ) -> RelationBelief:
        if weight <= 0:
            raise ValueError("weight must be > 0")
        belief = self._get(source, relation, target)
        if supported:
            belief.support += float(weight)
        else:
            belief.oppose += float(weight)
        return belief

    def belief(
        self,
        source: str,
        relation: str,
        target: str,
    ) -> RelationBelief | None:
        return self._beliefs.get(self._key(source, relation, target))

    def best_targets(
        self,
        source: str,
        relation: str,
        limit: int = 5,
    ) -> List[RelationBelief]:
        candidates = [
            belief
            for (saved_source, saved_relation, _), belief in self._beliefs.items()
            if saved_source == source.strip()
            and saved_relation == relation.strip()
        ]
        candidates.sort(
            key=lambda belief: (belief.probability, belief.confidence),
            reverse=True,
        )
        return candidates[:limit]

    def export_state(self) -> dict:
        return {
            "format": "mgd-relational-memory-v1",
            "teacher_prior_cap": self.teacher_prior_cap,
            "beliefs": [
                asdict(belief)
                | {
                    "probability": belief.probability,
                    "confidence": belief.confidence,
                }
                for belief in self._beliefs.values()
            ],
        }
