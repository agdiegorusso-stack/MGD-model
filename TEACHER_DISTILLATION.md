# LLM -> MGD plastic knowledge transfer

This pipeline transfers a compact relational prior from a pretrained causal LLM
into MGD without making the LLM part of the runtime system.

## Why v2 exists

Raw cosine similarity between hidden states is not treated as knowledge.
Transformer latent spaces are anisotropic, so unrelated concepts can all look
artificially close. The v2 pack therefore uses:

1. multiple prompts per concept;
2. a deterministic compact projection;
3. mutual-kNN plus per-concept local z-score filtering for semantic neighbors;
4. typed relation directions learned from example source/target pairs;
5. a hard cap on teacher prior strength.

Every imported edge is marked plastic. The teacher is a starting bias, not a
source of immutable truth.

## Export a pack

Create a text file with one concept per line. Optionally provide relation seeds
as JSON:

```json
[
  {"relation": "located_in_country", "source": "Paris", "target": "France"},
  {"relation": "located_in_country", "source": "Madrid", "target": "Spain"}
]
```

Then run:

```bash
python export_teacher_latent_pack.py \
  --model HuggingFaceTB/SmolLM2-360M-Instruct \
  --concepts concepts.txt \
  --relation-seeds relation_seeds.json \
  --out teacher-pack-v2.json
```

The Hugging Face/transformers dependency is needed only while exporting the
teacher pack. It is not required by MGD at runtime.

## Load into BioMGDBrain

```python
import json
from cortical_mgd.architecture.bio_mgd_brain import BioMGDBrain

brain = BioMGDBrain(device="cpu")
with open("teacher-pack-v2.json", encoding="utf-8") as handle:
    brain.load_teacher_prior_pack(json.load(handle))

brain.observe_relation(
    "Rome",
    "located_in_country",
    "Italy",
    supported=True,
)
brain.observe_relation(
    "bad_teacher_edge",
    "is_a",
    "wrong_target",
    supported=False,
)

candidates = brain.recall_relation("Rome", "located_in_country")
```

Repeated online observations update the posterior. Contradictory experience can
drive an imported teacher relation below 0.5 and therefore overturn it.

## Important limitation

A transformer weight does not have a one-to-one human-readable meaning that can
be copied directly into a symbolic edge. This code transfers *structure* from
hidden-state geometry and typed displacement patterns instead. The original
v1 JSON pack cannot be losslessly upgraded if its source hidden states were not
saved; it should be regenerated from the teacher model with the v2 exporter.
