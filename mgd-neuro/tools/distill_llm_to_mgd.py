#!/usr/bin/env python3
"""
Distill an open-weight LLM into an MGD teacher pack.

This does NOT claim that individual transformer weights have human-readable
meanings. It uses two signals from the trained model:

1) explicit teacher knowledge, elicited as subject-relation-object triples;
2) latent geometry, measured from hidden-state representations and converted
   into semantic similarity links.

The mobile MGD brain imports both as weak priors. They remain plastic.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np


@dataclass(frozen=True)
class Fact:
    subject: str
    relation: str
    object: str
    confidence: float


def clean_text(x: str) -> str:
    return re.sub(r"\s+", " ", x).strip()


def load_items(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    items = []
    for raw in re.split(r"\n+|(?<=[.!?])\s+", text):
        x = clean_text(raw)
        if len(x) >= 2:
            items.append(x)
    return items


def json_slice(text: str):
    starts = [i for i, c in enumerate(text) if c in "[{"]
    for start in starts:
        for end in range(len(text), start + 1, -1):
            if text[end - 1] not in "]}":
                continue
            try:
                return json.loads(text[start:end])
            except Exception:
                pass
    return None


def parse_facts(raw, default_confidence: float) -> list[Fact]:
    if isinstance(raw, dict):
        raw = raw.get("facts", raw.get("triples", [raw]))
    if not isinstance(raw, list):
        return []

    out: list[Fact] = []
    for x in raw:
        if not isinstance(x, dict):
            continue
        s = clean_text(str(x.get("subject", x.get("s", ""))))
        r = clean_text(str(x.get("relation", x.get("predicate", x.get("r", "")))))
        o = clean_text(str(x.get("object", x.get("o", ""))))
        if not s or not r or not o:
            continue
        try:
            c = float(x.get("confidence", default_confidence))
        except Exception:
            c = default_confidence
        out.append(Fact(s, r, o, max(0.05, min(0.95, c))))
    return out


def dedupe_facts(facts: Iterable[Fact]) -> list[Fact]:
    best: dict[tuple[str, str, str], Fact] = {}
    for f in facts:
        key = (f.subject.casefold(), f.relation.casefold(), f.object.casefold())
        if key not in best or f.confidence > best[key].confidence:
            best[key] = f
    return list(best.values())


def normalize(v: np.ndarray) -> np.ndarray:
    n = float(np.linalg.norm(v))
    return v if n <= 1e-12 else v / n


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, help="Hugging Face open-weight model id or local directory")
    ap.add_argument("--concepts", type=Path, help="One concept or short sentence per line")
    ap.add_argument("--corpus", type=Path, help="Text/dictionary/Wikipedia-style source to mine")
    ap.add_argument("--output", type=Path, default=Path("mgd_teacher_pack.json"))
    ap.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda", "mps"])
    ap.add_argument("--max-items", type=int, default=300)
    ap.add_argument("--triples-per-item", type=int, default=5)
    ap.add_argument("--top-k-links", type=int, default=6)
    ap.add_argument("--min-similarity", type=float, default=0.56)
    ap.add_argument("--projection-dim", type=int, default=64)
    ap.add_argument("--max-new-tokens", type=int, default=220)
    ap.add_argument("--trust-remote-code", action="store_true")
    args = ap.parse_args()

    try:
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
    except Exception as exc:
        raise SystemExit(
            "Install dependencies first: pip install torch transformers accelerate numpy\n"
            f"Original error: {exc}"
        )

    if args.device == "auto":
        if torch.cuda.is_available():
            device = "cuda"
        elif getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
            device = "mps"
        else:
            device = "cpu"
    else:
        device = args.device

    items: list[str] = []
    if args.concepts:
        items.extend(load_items(args.concepts))
    if args.corpus:
        items.extend(load_items(args.corpus))
    if not items:
        raise SystemExit("Provide --concepts and/or --corpus")

    seen = set()
    ordered = []
    for x in items:
        k = x.casefold()
        if k in seen:
            continue
        seen.add(k)
        ordered.append(x)
        if len(ordered) >= args.max_items:
            break
    items = ordered

    print(f"Loading {args.model} on {device}...")
    tokenizer = AutoTokenizer.from_pretrained(
        args.model,
        trust_remote_code=args.trust_remote_code,
    )
    model = AutoModelForCausalLM.from_pretrained(
        args.model,
        torch_dtype="auto",
        trust_remote_code=args.trust_remote_code,
    )
    model.eval()
    model.to(device)

    hidden_size = int(model.config.hidden_size)
    rng = np.random.default_rng(20260922)
    projection = rng.normal(
        loc=0.0,
        scale=1.0 / math.sqrt(args.projection_dim),
        size=(hidden_size, args.projection_dim),
    ).astype(np.float32)

    all_facts: list[Fact] = []
    vectors: dict[str, np.ndarray] = {}

    for idx, item in enumerate(items, 1):
        print(f"[{idx}/{len(items)}] {item[:100]}")

        # Latent semantic code from the model's trained internal representation.
        inputs = tokenizer(
            item,
            return_tensors="pt",
            truncation=True,
            max_length=256,
        )
        inputs = {k: v.to(device) for k, v in inputs.items()}
        with torch.no_grad():
            out = model(
                **inputs,
                output_hidden_states=True,
                use_cache=False,
            )
        h = out.hidden_states[-2][0]
        mask = inputs.get("attention_mask")
        if mask is not None:
            m = mask[0].to(h.dtype).unsqueeze(-1)
            pooled = (h * m).sum(0) / m.sum().clamp_min(1)
        else:
            pooled = h.mean(0)
        code = pooled.float().cpu().numpy().astype(np.float32) @ projection
        vectors[item] = normalize(code)

        prompt = (
            "You are distilling factual knowledge into a small relational world model.\n"
            "Given the SOURCE below, return ONLY a JSON array of up to "
            + str(args.triples_per_item)
            + " short factual triples.\n"
            "Each item must be: "
            '{"subject":"...","relation":"...","object":"...","confidence":0.0}.\n'
            "Use compact reusable relations such as is_a, part_of, has_property, "
            "used_for, located_in, causes, capable_of, related_to. "
            "Do not invent facts not supported by the SOURCE.\n\n"
            "SOURCE:\n"
            + item
            + "\n"
        )

        enc = tokenizer(
            prompt,
            return_tensors="pt",
            truncation=True,
            max_length=512,
        )
        enc = {k: v.to(device) for k, v in enc.items()}
        with torch.no_grad():
            generated = model.generate(
                **enc,
                max_new_tokens=args.max_new_tokens,
                do_sample=False,
                pad_token_id=tokenizer.eos_token_id,
            )
        new_tokens = generated[0, enc["input_ids"].shape[1] :]
        text = tokenizer.decode(new_tokens, skip_special_tokens=True)
        parsed = json_slice(text)
        all_facts.extend(parse_facts(parsed, default_confidence=0.62))

    facts = dedupe_facts(all_facts)

    # Include explicit entity labels from distilled triples in the latent space
    # when a source item matches them exactly. Otherwise the app still creates
    # their graph nodes from the triples.
    labels = list(vectors.keys())
    links = []
    if labels:
        matrix = np.stack([vectors[x] for x in labels], axis=0)
        sims = matrix @ matrix.T
        for i, a in enumerate(labels):
            order = np.argsort(-sims[i])
            emitted = 0
            for j in order:
                if i == j:
                    continue
                sim = float(sims[i, j])
                if sim < args.min_similarity:
                    break
                links.append(
                    {
                        "a": a,
                        "b": labels[j],
                        "similarity": round(sim, 6),
                        "confidence": 0.60,
                    }
                )
                emitted += 1
                if emitted >= args.top_k_links:
                    break

    # Deduplicate undirected links.
    link_best = {}
    for l in links:
        key = tuple(sorted((l["a"].casefold(), l["b"].casefold())))
        if key not in link_best or l["similarity"] > link_best[key]["similarity"]:
            link_best[key] = l

    pack = {
        "format": "mgd-teacher-pack-v1",
        "teacher": {
            "model": args.model,
            "source": "hidden-state+generated-triples",
            "projection_dim": args.projection_dim,
            "items": len(items),
        },
        "facts": [
            {
                "subject": f.subject,
                "relation": f.relation,
                "object": f.object,
                "confidence": round(f.confidence, 4),
            }
            for f in facts
        ],
        "links": list(link_best.values()),
    }

    args.output.write_text(
        json.dumps(pack, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(
        f"Wrote {args.output}: {len(pack['facts'])} facts, "
        f"{len(pack['links'])} latent links."
    )


if __name__ == "__main__":
    main()
