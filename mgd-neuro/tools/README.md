# LLM → MGD distillation

This bridge reuses knowledge from an **open-weight** language model without freezing MGD into that model.

It extracts two kinds of priors:

1. **Explicit relational facts** from teacher generations.
2. **Latent semantic geometry** from the model's hidden states, converted to similarity links.

Those priors are deliberately imported weakly. MGD can reinforce, contradict, reorganize or forget them through later experience.

## Generate a pack

```bash
pip install torch transformers accelerate numpy

python mgd-neuro/tools/distill_llm_to_mgd.py \
  --model <hugging-face-model-or-local-path> \
  --concepts concepts.txt \
  --corpus dictionary.txt \
  --output teacher_pack.json
```

The model should preferably be an instruct-capable open-weight causal LM. Larger models generally produce cleaner relational triples but require more RAM/VRAM.

## Import on Android

Open **Mondo → Distillazione LLM → MGD → Importa knowledge pack** and select the generated JSON.

This is not literal reverse engineering of each transformer parameter. Individual weights are distributed and do not map one-to-one to human concepts. The bridge instead transfers:
- factual structure learned by the teacher, and
- geometry present in its hidden representations.

That is the practical approximation to “sucking the training” while preserving MGD's continual plasticity.
