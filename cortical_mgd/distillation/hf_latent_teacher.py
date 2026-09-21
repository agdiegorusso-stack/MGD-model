from __future__ import annotations

from typing import Dict, Iterable, List, Sequence

import torch


class HuggingFaceLatentTeacher:
    """Lazy Hugging Face hidden-state probe used only during offline transfer."""

    DEFAULT_TEMPLATES = (
        "Concept: {concept}",
        "The meaning of {concept} is",
        "In ordinary language, {concept} refers to",
        "A short factual description of {concept}:",
    )

    def __init__(
        self,
        model_name: str,
        device: str | None = None,
        dtype: torch.dtype | None = None,
        trust_remote_code: bool = False,
    ) -> None:
        try:
            from transformers import AutoModelForCausalLM, AutoTokenizer
        except ImportError as exc:
            raise RuntimeError(
                "transformers is required only for teacher-pack creation; "
                "install it with pip install transformers"
            ) from exc

        self.model_name = model_name
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            trust_remote_code=trust_remote_code,
        )
        kwargs = {
            "output_hidden_states": True,
            "trust_remote_code": trust_remote_code,
        }
        if dtype is not None:
            kwargs["torch_dtype"] = dtype
        self.model = AutoModelForCausalLM.from_pretrained(model_name, **kwargs)
        self.model.to(self.device)
        self.model.eval()

    @torch.inference_mode()
    def embed_text(self, text: str, layer: int = -1) -> torch.Tensor:
        tokens = self.tokenizer(text, return_tensors="pt", truncation=True)
        tokens = {key: value.to(self.device) for key, value in tokens.items()}
        output = self.model(
            **tokens,
            output_hidden_states=True,
            return_dict=True,
        )
        hidden = output.hidden_states[layer][0]
        mask = tokens.get("attention_mask")
        if mask is None:
            pooled = hidden.mean(dim=0)
        else:
            weights = mask[0].to(hidden.dtype).unsqueeze(-1)
            pooled = (hidden * weights).sum(dim=0) / weights.sum().clamp_min(1.0)
        return pooled.detach().float().cpu()

    def embed_concepts(
        self,
        concepts: Iterable[str],
        templates: Sequence[str] | None = None,
        layer: int = -1,
    ) -> Dict[str, List[torch.Tensor]]:
        templates = tuple(templates or self.DEFAULT_TEMPLATES)
        result: Dict[str, List[torch.Tensor]] = {}
        for concept in concepts:
            result[concept] = [
                self.embed_text(template.format(concept=concept), layer=layer)
                for template in templates
            ]
        return result
