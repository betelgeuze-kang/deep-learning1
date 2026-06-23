from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Mapping, Sequence


MODEL_VISIBLE_FIELDS = {"sanitized_question", "opaque_routehint"}
FORBIDDEN_MODEL_VISIBLE_FIELDS = {
    "expected_answer",
    "expected_label",
    "source_path",
    "source_line_start",
    "source_line_end",
    "source_span_id",
    "repository_id",
    "evaluator_score",
    "raw_source_span",
    "retrieved_text",
}
SOURCE_LOCATOR_PATTERN = re.compile(r"\b[A-Za-z0-9_.~+/@-]+:[0-9]+\b")


@dataclass(frozen=True)
class RouteState:
    route_id: str
    output_token_ids: tuple[int, ...]
    citation_handle: str
    provenance_valid: bool
    evidence_probability: float


@dataclass(frozen=True)
class DecoderHidden:
    position: int
    previous_token_id: int


@dataclass(frozen=True)
class DecodeStep:
    position: int
    input_token_id: int
    output_token_id: int
    output_token: str
    teacher_forcing_used: bool


@dataclass(frozen=True)
class DecodeResult:
    token_ids: tuple[int, ...]
    tokens: tuple[str, ...]
    steps: tuple[DecodeStep, ...]
    stopped_on_eos: bool


class TinyRouteStateDecoder:
    def __init__(self, vocab: Sequence[str], *, bos_token: str = "<bos>", eos_token: str = "<eos>") -> None:
        if len(vocab) != len(set(vocab)):
            raise ValueError("vocab tokens must be unique")
        if bos_token not in vocab or eos_token not in vocab:
            raise ValueError("vocab must contain bos/eos tokens")
        self.vocab = tuple(vocab)
        self.token_to_id = {token: idx for idx, token in enumerate(self.vocab)}
        self.bos_token_id = self.token_to_id[bos_token]
        self.eos_token_id = self.token_to_id[eos_token]
        self.attention_blocks = 0
        self.transformer_blocks = 0

    def step(self, token_id: int, route_state: RouteState, hidden: DecoderHidden | None) -> tuple[list[float], DecoderHidden]:
        if token_id < 0 or token_id >= len(self.vocab):
            raise ValueError("token_id outside vocab")
        if not route_state.provenance_valid or route_state.evidence_probability <= 0:
            next_token = self.eos_token_id
            position = 0 if hidden is None else hidden.position
        else:
            position = 0 if hidden is None else hidden.position
            next_token = (
                route_state.output_token_ids[position]
                if position < len(route_state.output_token_ids)
                else self.eos_token_id
            )
        logits = [-1_000_000.0] * len(self.vocab)
        logits[next_token] = 0.0
        return logits, DecoderHidden(position=position + 1, previous_token_id=token_id)


def build_model_visible_generator_input(row: Mapping[str, object]) -> dict[str, object]:
    leaked = FORBIDDEN_MODEL_VISIBLE_FIELDS.intersection(row)
    if leaked:
        raise ValueError(f"evaluator-only field leaked: {sorted(leaked)}")
    payload = {key: row[key] for key in MODEL_VISIBLE_FIELDS if key in row}
    rendered = " ".join(str(value) for value in payload.values())
    if SOURCE_LOCATOR_PATTERN.search(rendered):
        raise ValueError("model-visible input contains source locator")
    return payload


def greedy_decode(
    model: TinyRouteStateDecoder,
    initial_token_id: int,
    route_state: RouteState,
    max_tokens: int,
) -> DecodeResult:
    if max_tokens <= 0:
        raise ValueError("max_tokens must be positive")
    token_id = initial_token_id
    hidden: DecoderHidden | None = None
    output_ids: list[int] = []
    output_tokens: list[str] = []
    steps: list[DecodeStep] = []
    stopped_on_eos = False
    for position in range(max_tokens):
        input_token_id = token_id
        logits, hidden = model.step(input_token_id, route_state, hidden)
        token_id = max(range(len(logits)), key=lambda idx: logits[idx])
        token = model.vocab[token_id]
        output_ids.append(token_id)
        output_tokens.append(token)
        steps.append(
            DecodeStep(
                position=position,
                input_token_id=input_token_id,
                output_token_id=token_id,
                output_token=token,
                teacher_forcing_used=False,
            )
        )
        if token_id == model.eos_token_id:
            stopped_on_eos = True
            break
    return DecodeResult(tuple(output_ids), tuple(output_tokens), tuple(steps), stopped_on_eos)


def detokenize(tokens: Sequence[str], *, eos_token: str = "<eos>") -> str:
    return " ".join(token for token in tokens if token != eos_token)
