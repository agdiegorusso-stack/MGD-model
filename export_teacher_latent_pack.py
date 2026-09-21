from __future__ import annotations

import argparse
import json
from pathlib import Path

from cortical_mgd.distillation.hf_latent_teacher import HuggingFaceLatentTeacher
from cortical_mgd.distillation.latent_relation_distiller import (
    LatentRelationDistiller,
    RelationSeed,
)


def load_concepts(path: Path) -> list[str]:
    concepts = []
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if value and not value.startswith("#"):
            concepts.append(value)
    if len(concepts) < 2:
        raise ValueError("concept file must contain at least two concepts")
    return concepts


def load_seeds(path: Path | None) -> list[RelationSeed]:
    if path is None:
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data.get("relations", data.get("seeds", []))
    return [
        RelationSeed(
            str(item["relation"]),
            str(item["source"]),
            str(item["target"]),
        )
        for item in data
    ]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Distill LLM hidden states into a plastic MGD relation prior"
    )
    parser.add_argument(
        "--model",
        default="HuggingFaceTB/SmolLM2-360M-Instruct",
    )
    parser.add_argument("--concepts", required=True, type=Path)
    parser.add_argument("--relation-seeds", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--projection-dim", type=int, default=64)
    parser.add_argument("--mutual-k", type=int, default=5)
    parser.add_argument("--local-z", type=float, default=1.0)
    parser.add_argument("--relation-threshold", type=float, default=0.55)
    parser.add_argument("--layer", type=int, default=-1)
    args = parser.parse_args()

    concepts = load_concepts(args.concepts)
    seeds = load_seeds(args.relation_seeds)
    teacher = HuggingFaceLatentTeacher(args.model)
    embeddings = teacher.embed_concepts(concepts, layer=args.layer)

    distiller = LatentRelationDistiller(
        projection_dim=args.projection_dim,
        mutual_k=args.mutual_k,
        local_z_threshold=args.local_z,
        relation_score_threshold=args.relation_threshold,
    )
    pack = distiller.build_pack(
        teacher_model=args.model,
        embeddings=embeddings,
        relation_seeds=seeds,
        metadata={
            "layer": args.layer,
            "views_per_concept": len(teacher.DEFAULT_TEMPLATES),
        },
    )
    args.out.write_text(
        json.dumps(pack, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(
        f"Wrote {args.out} with {len(pack['relations'])} plastic relations"
    )


if __name__ == "__main__":
    main()
