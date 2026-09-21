import torch

from cortical_mgd.continual.relational_prior_memory import RelationalPriorMemory
from cortical_mgd.distillation.latent_relation_distiller import (
    LatentRelationDistiller,
    RelationSeed,
)


def test_mutual_local_filter_rejects_anisotropic_similarity_explosion():
    common = torch.tensor([10.0, 10.0, 10.0, 10.0])
    embeddings = {
        "dog": common + torch.tensor([0.8, 0.0, 0.0, 0.0]),
        "cat": common + torch.tensor([0.7, 0.1, 0.0, 0.0]),
        "Rome": common + torch.tensor([0.0, 0.0, 0.8, 0.0]),
        "computer": common + torch.tensor([0.0, 0.0, 0.0, 0.8]),
        "water": common + torch.tensor([0.0, 0.7, 0.0, 0.1]),
        "moon": common + torch.tensor([0.0, 0.0, 0.7, 0.1]),
    }
    distiller = LatentRelationDistiller(
        projection_dim=8,
        mutual_k=2,
        local_z_threshold=0.75,
        seed=7,
    )
    names, _, projected = distiller.prepare_embeddings(embeddings)
    links = distiller.semantic_links(names, projected)
    assert len(links) < 8


def test_relation_vector_learns_direction_from_seed_pairs():
    embeddings = {
        "Paris": torch.tensor([1.0, 0.0, 0.0]),
        "France": torch.tensor([1.0, 1.0, 0.0]),
        "Madrid": torch.tensor([2.0, 0.0, 0.0]),
        "Spain": torch.tensor([2.0, 1.0, 0.0]),
        "Rome": torch.tensor([3.0, 0.0, 0.0]),
        "Italy": torch.tensor([3.0, 1.0, 0.0]),
        "dog": torch.tensor([0.0, 0.0, 2.0]),
    }
    distiller = LatentRelationDistiller(
        projection_dim=3,
        relation_score_threshold=0.55,
        max_prior_strength=0.45,
        seed=3,
    )
    names, _, projected = distiller.prepare_embeddings(embeddings)
    seeds = [
        RelationSeed("located_in_country", "Paris", "France"),
        RelationSeed("located_in_country", "Madrid", "Spain"),
    ]
    relations = distiller.typed_relations(
        names,
        projected,
        seeds,
        top_per_source=1,
    )
    assert any(
        item["source"] == "Rome"
        and item["target"] == "Italy"
        and item["relation"] == "located_in_country"
        for item in relations
    )


def test_teacher_prior_is_overridable_by_online_evidence():
    memory = RelationalPriorMemory(teacher_prior_cap=0.45)
    pack = {
        "format": "mgd-teacher-pack-v2",
        "teacher": {"model": "teacher"},
        "relations": [
            {
                "source": "object_x",
                "relation": "is_a",
                "target": "class_y",
                "prior_strength": 0.45,
                "plastic": True,
                "evidence": "relation_vector_inference",
            }
        ],
    }
    memory.ingest_teacher_pack(pack)
    before = memory.belief("object_x", "is_a", "class_y")
    assert before is not None and before.probability > 0.5

    for _ in range(3):
        memory.observe(
            "object_x",
            "is_a",
            "class_y",
            supported=False,
            weight=1.0,
        )
    after = memory.belief("object_x", "is_a", "class_y")
    assert after is not None and after.probability < 0.5


def test_pack_marks_teacher_knowledge_as_plastic_prior():
    embeddings = {
        "a": torch.tensor([1.0, 0.0, 0.0, 0.0]),
        "b": torch.tensor([0.9, 0.1, 0.0, 0.0]),
        "c": torch.tensor([0.0, 0.0, 1.0, 0.0]),
    }
    distiller = LatentRelationDistiller(
        projection_dim=4,
        mutual_k=1,
        local_z_threshold=-1.0,
        seed=1,
    )
    pack = distiller.build_pack("teacher", embeddings)
    assert pack["format"] == "mgd-teacher-pack-v2"
    assert pack["policy"]["teacher_is_prior_only"] is True
    assert pack["policy"]["online_evidence_can_override"] is True
    assert all(item["plastic"] is True for item in pack["relations"])
    assert all(
        item["prior_strength"] <= 0.45
        for item in pack["relations"]
    )
