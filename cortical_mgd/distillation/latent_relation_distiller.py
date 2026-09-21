from __future__ import annotations

import hashlib
import math
from dataclasses import dataclass
from typing import Dict, Iterable, List, Mapping, Sequence, Tuple

import torch


@dataclass(frozen=True)
class RelationSeed:
    relation: str
    source: str
    target: str


class LatentRelationDistiller:
    """Convert teacher hidden states into a conservative, plastic MGD prior graph.

    Raw cosine similarity from a causal LLM is not treated as knowledge. Modern
    transformer spaces are anisotropic: many unrelated concepts can have high
    cosine similarity. The distiller therefore combines multi-view hidden
    states, deterministic projection, mutual-kNN/local-z semantic filtering and
    relation-vector prototypes learned from seed pairs.

    Exported weights are priors, never hard facts, and are deliberately capped
    so later online evidence can override them.
    """

    def __init__(
        self,
        projection_dim: int = 64,
        mutual_k: int = 5,
        local_z_threshold: float = 1.0,
        cosine_floor: float = 0.25,
        relation_score_threshold: float = 0.55,
        max_prior_strength: float = 0.45,
        seed: int = 1337,
    ) -> None:
        if projection_dim <= 0:
            raise ValueError("projection_dim must be > 0")
        if mutual_k <= 0:
            raise ValueError("mutual_k must be > 0")
        self.projection_dim = projection_dim
        self.mutual_k = mutual_k
        self.local_z_threshold = local_z_threshold
        self.cosine_floor = cosine_floor
        self.relation_score_threshold = relation_score_threshold
        self.max_prior_strength = max_prior_strength
        self.seed = seed

    @staticmethod
    def _normalize(x: torch.Tensor) -> torch.Tensor:
        return x / x.norm(dim=-1, keepdim=True).clamp_min(1e-8)

    @staticmethod
    def _mean_views(value: torch.Tensor | Sequence[torch.Tensor]) -> torch.Tensor:
        if isinstance(value, torch.Tensor):
            x = value
            if x.ndim == 1:
                return x.float()
            if x.ndim == 2:
                return x.float().mean(dim=0)
            raise ValueError("embedding tensor must be 1D or 2D")
        views = [v.float().reshape(-1) for v in value]
        if not views:
            raise ValueError("empty embedding view list")
        dim = views[0].numel()
        if any(v.numel() != dim for v in views):
            raise ValueError("all embedding views must have the same dimensionality")
        return torch.stack(views, dim=0).mean(dim=0)

    def _projection_matrix(self, input_dim: int, device: torch.device) -> torch.Tensor:
        key = f"{self.seed}:{input_dim}:{self.projection_dim}".encode("utf-8")
        digest = hashlib.sha256(key).digest()
        generator_seed = int.from_bytes(digest[:8], "big") % (2**63 - 1)
        generator = torch.Generator(device="cpu")
        generator.manual_seed(generator_seed)
        matrix = torch.randn(input_dim, self.projection_dim, generator=generator)
        matrix = matrix / math.sqrt(float(self.projection_dim))
        return matrix.to(device=device)

    def prepare_embeddings(
        self,
        embeddings: Mapping[str, torch.Tensor | Sequence[torch.Tensor]],
    ) -> Tuple[List[str], torch.Tensor, torch.Tensor]:
        if len(embeddings) < 2:
            raise ValueError("at least two concepts are required")
        names = list(embeddings.keys())
        rows = [self._mean_views(embeddings[name]) for name in names]
        input_dim = rows[0].numel()
        if any(row.numel() != input_dim for row in rows):
            raise ValueError("all concepts must share the same embedding dimension")

        # Do not normalize coordinates before relation arithmetic. Independent
        # normalization bends target-source displacement vectors. Semantic
        # cosine normalization is applied only inside semantic_links.
        raw = torch.stack(rows, dim=0)
        projected = raw @ self._projection_matrix(input_dim, raw.device)
        return names, raw, projected

    @staticmethod
    def _local_stats(sim: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        n = sim.shape[0]
        mask = ~torch.eye(n, dtype=torch.bool, device=sim.device)
        values = sim.masked_select(mask).reshape(n, n - 1)
        return (
            values.mean(dim=1),
            values.std(dim=1, unbiased=False).clamp_min(1e-6),
        )

    def semantic_links(self, names: Sequence[str], projected: torch.Tensor) -> List[dict]:
        semantic = self._normalize(projected)
        sim = semantic @ semantic.T
        n = sim.shape[0]
        mean, std = self._local_stats(sim)
        k = min(self.mutual_k, n - 1)

        nearest: List[set[int]] = []
        for i in range(n):
            row = sim[i].clone()
            row[i] = -float("inf")
            nearest.append(set(torch.topk(row, k=k).indices.tolist()))

        edges: List[dict] = []
        for i in range(n):
            for j in range(i + 1, n):
                if j not in nearest[i] or i not in nearest[j]:
                    continue
                score = float(sim[i, j].item())
                zi = float(((sim[i, j] - mean[i]) / std[i]).item())
                zj = float(((sim[i, j] - mean[j]) / std[j]).item())
                local_z = min(zi, zj)
                if score < self.cosine_floor or local_z < self.local_z_threshold:
                    continue

                z_component = torch.sigmoid(
                    torch.tensor(local_z - self.local_z_threshold)
                ).item()
                confidence = min(
                    self.max_prior_strength,
                    0.15 + 0.30 * z_component,
                )
                edges.append(
                    {
                        "source": names[i],
                        "relation": "semantic_neighbor",
                        "target": names[j],
                        "teacher_similarity": round(score, 6),
                        "local_z": round(local_z, 6),
                        "prior_strength": round(float(confidence), 6),
                        "plastic": True,
                        "evidence": "mutual_knn_local_z",
                    }
                )
        return edges

    def _relation_prototypes(
        self,
        names: Sequence[str],
        projected: torch.Tensor,
        seeds: Iterable[RelationSeed],
    ) -> Dict[str, torch.Tensor]:
        index = {name: i for i, name in enumerate(names)}
        grouped: Dict[str, List[torch.Tensor]] = {}
        for seed in seeds:
            if seed.source not in index or seed.target not in index:
                continue
            delta = projected[index[seed.target]] - projected[index[seed.source]]
            if float(delta.norm().item()) < 1e-8:
                continue
            grouped.setdefault(seed.relation, []).append(
                self._normalize(delta.unsqueeze(0))[0]
            )

        prototypes: Dict[str, torch.Tensor] = {}
        for relation, vectors in grouped.items():
            prototype = torch.stack(vectors, dim=0).mean(dim=0)
            prototypes[relation] = self._normalize(prototype.unsqueeze(0))[0]
        return prototypes

    def typed_relations(
        self,
        names: Sequence[str],
        projected: torch.Tensor,
        seeds: Iterable[RelationSeed],
        top_per_source: int = 1,
    ) -> List[dict]:
        seeds = list(seeds)
        prototypes = self._relation_prototypes(names, projected, seeds)
        if not prototypes:
            return []

        index = {name: i for i, name in enumerate(names)}
        seed_triples = {(s.relation, s.source, s.target) for s in seeds}
        results: List[dict] = []

        for relation, prototype in prototypes.items():
            for source in names:
                i = index[source]
                candidates: List[Tuple[float, str]] = []
                for target in names:
                    if target == source:
                        continue
                    j = index[target]
                    delta = projected[j] - projected[i]
                    if float(delta.norm().item()) < 1e-8:
                        continue
                    direction = self._normalize(delta.unsqueeze(0))[0]
                    score = float(torch.dot(direction, prototype).item())
                    if score >= self.relation_score_threshold:
                        candidates.append((score, target))

                candidates.sort(key=lambda item: item[0], reverse=True)
                for score, target in candidates[:top_per_source]:
                    is_seed = (relation, source, target) in seed_triples
                    base = 0.32 if is_seed else 0.20
                    confidence = min(
                        self.max_prior_strength,
                        base
                        + 0.13
                        * max(
                            0.0,
                            (score - self.relation_score_threshold)
                            / max(1e-6, 1.0 - self.relation_score_threshold),
                        ),
                    )
                    results.append(
                        {
                            "source": source,
                            "relation": relation,
                            "target": target,
                            "relation_score": round(score, 6),
                            "prior_strength": round(float(confidence), 6),
                            "plastic": True,
                            "evidence": (
                                "relation_vector_seed"
                                if is_seed
                                else "relation_vector_inference"
                            ),
                        }
                    )
        return results

    def build_pack(
        self,
        teacher_model: str,
        embeddings: Mapping[str, torch.Tensor | Sequence[torch.Tensor]],
        relation_seeds: Iterable[RelationSeed] = (),
        metadata: Mapping[str, object] | None = None,
    ) -> dict:
        names, raw, projected = self.prepare_embeddings(embeddings)
        seeds = list(relation_seeds)
        semantic = self.semantic_links(names, projected)
        typed = self.typed_relations(names, projected, seeds)

        concept_codes = {
            name: [round(float(v), 7) for v in projected[i].tolist()]
            for i, name in enumerate(names)
        }
        return {
            "format": "mgd-teacher-pack-v2",
            "teacher": {
                "model": teacher_model,
                "source": "multi_view_hidden_state_distillation",
                "input_dim": int(raw.shape[1]),
                "projection_dim": int(projected.shape[1]),
                "projection_seed": self.seed,
                "concepts": len(names),
                "max_prior_strength": self.max_prior_strength,
            },
            "policy": {
                "hard_facts": False,
                "teacher_is_prior_only": True,
                "online_evidence_can_override": True,
                "semantic_filter": "mutual_knn+local_z",
                "typed_relation_filter": "relation_vector",
            },
            "concept_codes": concept_codes,
            "relations": semantic + typed,
            "relation_seeds": [
                {
                    "relation": seed.relation,
                    "source": seed.source,
                    "target": seed.target,
                }
                for seed in seeds
            ],
            "metadata": dict(metadata or {}),
        }
