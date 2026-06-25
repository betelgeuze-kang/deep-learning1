"""Reference learnable free-running generator (untrained reference scaffold).

Implements a tiny non-attention GRU generator::

    h_t = GRU([e(y_{t-1}); context], h_{t-1})
    p(y_t) = softmax(W_o h_t + b_o)

decoded free-running (each generated token is fed back into the next step; no
teacher forcing), honoring the ``free_running_generator_contract`` constraints:

- no attention / transformer blocks,
- model-visible inputs limited to ``sanitized_question`` + ``opaque_routehint``,
- no raw source span or source locator in the context vector.

This is a reference scaffold, NOT real generation evidence:

- weights are deterministically seeded and UNTRAINED by default, so outputs are
  not meaningful answers; the point is the free-running decode mechanism,
- it produces no ``results/`` artifacts and flips no readiness flag,
- ``real_model_generation_ready`` / ``heldout_metric_ready`` stay false.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import math
import random
from typing import Mapping, Sequence

from free_running_generator_contract import (
    DecodeResult,
    DecodeStep,
    build_model_visible_generator_input,
    detokenize,
)


def hash_token(token: str) -> int:
    """Deterministic, process-stable token hash (not the salted builtin)."""
    return int.from_bytes(hashlib.sha256(token.encode("utf-8")).digest()[:8], "big")


def encode_context(model_visible_payload: Mapping[str, object], dim: int) -> tuple[float, ...]:
    """Hashing-bag encoder over model-visible fields only.

    Deterministic and dependency-free. Callers should pass the mapping returned
    by ``build_model_visible_generator_input`` so that only model-visible fields
    (sanitized question + opaque routehint) can enter the context vector; no raw
    source span or locator can leak in.
    """
    if dim < 1:
        raise ValueError("dim must be >= 1")
    vec = [0.0] * dim
    for value in model_visible_payload.values():
        for token in str(value).split():
            digest = hash_token(token)
            idx = digest % dim
            sign = 1.0 if (digest >> 16) & 1 else -1.0
            vec[idx] += sign
    norm = math.sqrt(sum(component * component for component in vec)) or 1.0
    return tuple(component / norm for component in vec)


def _sigmoid(x: float) -> float:
    if x >= 0.0:
        z = math.exp(-x)
        return 1.0 / (1.0 + z)
    z = math.exp(x)
    return z / (1.0 + z)


def _matvec(matrix: Sequence[Sequence[float]], vector: Sequence[float]) -> list[float]:
    return [sum(w * v for w, v in zip(row, vector)) for row in matrix]


def _add(a: Sequence[float], b: Sequence[float]) -> list[float]:
    return [x + y for x, y in zip(a, b)]


class TinyGRUGenerator:
    """A tiny, deterministically-seeded, non-attention GRU generator."""

    def __init__(
        self,
        vocab: Sequence[str],
        *,
        embed_dim: int = 4,
        hidden_dim: int = 4,
        context_dim: int = 4,
        seed: int = 0,
        bos_token: str = "<bos>",
        eos_token: str = "<eos>",
    ) -> None:
        if len(vocab) != len(set(vocab)):
            raise ValueError("vocab tokens must be unique")
        if bos_token not in vocab or eos_token not in vocab:
            raise ValueError("vocab must contain bos/eos tokens")
        self.vocab = tuple(vocab)
        self.token_to_id = {token: idx for idx, token in enumerate(self.vocab)}
        self.bos_token_id = self.token_to_id[bos_token]
        self.eos_token_id = self.token_to_id[eos_token]
        self.embed_dim = embed_dim
        self.hidden_dim = hidden_dim
        self.context_dim = context_dim
        # Explicitly a non-attention, non-transformer decoder.
        self.attention_blocks = 0
        self.transformer_blocks = 0

        rng = random.Random(seed)
        input_dim = embed_dim + context_dim

        def matrix(rows: int, cols: int) -> list[list[float]]:
            return [[rng.uniform(-0.1, 0.1) for _ in range(cols)] for _ in range(rows)]

        def vector(size: int) -> list[float]:
            return [rng.uniform(-0.1, 0.1) for _ in range(size)]

        self.embedding = matrix(len(self.vocab), embed_dim)
        self.w_z = matrix(hidden_dim, input_dim)
        self.w_r = matrix(hidden_dim, input_dim)
        self.w_h = matrix(hidden_dim, input_dim)
        self.u_z = matrix(hidden_dim, hidden_dim)
        self.u_r = matrix(hidden_dim, hidden_dim)
        self.u_h = matrix(hidden_dim, hidden_dim)
        self.b_z = vector(hidden_dim)
        self.b_r = vector(hidden_dim)
        self.b_h = vector(hidden_dim)
        self.w_o = matrix(len(self.vocab), hidden_dim)
        self.b_o = vector(len(self.vocab))

    def initial_hidden(self) -> tuple[float, ...]:
        return tuple(0.0 for _ in range(self.hidden_dim))

    def step(
        self,
        token_id: int,
        hidden: Sequence[float],
        context: Sequence[float],
    ) -> tuple[list[float], tuple[float, ...]]:
        if token_id < 0 or token_id >= len(self.vocab):
            raise ValueError("token_id outside vocab")
        if len(hidden) != self.hidden_dim:
            raise ValueError("hidden dimension mismatch")
        if len(context) != self.context_dim:
            raise ValueError("context dimension mismatch")

        x = list(self.embedding[token_id]) + list(context)
        wz_x = _add(_matvec(self.w_z, x), _matvec(self.u_z, hidden))
        z = [_sigmoid(value + bias) for value, bias in zip(wz_x, self.b_z)]
        wr_x = _add(_matvec(self.w_r, x), _matvec(self.u_r, hidden))
        r = [_sigmoid(value + bias) for value, bias in zip(wr_x, self.b_r)]
        reset_hidden = [ri * hi for ri, hi in zip(r, hidden)]
        wh_x = _add(_matvec(self.w_h, x), _matvec(self.u_h, reset_hidden))
        h_tilde = [math.tanh(value + bias) for value, bias in zip(wh_x, self.b_h)]
        new_hidden = tuple(
            (1.0 - zi) * hi + zi * hti for zi, hi, hti in zip(z, hidden, h_tilde)
        )
        logits = [value + bias for value, bias in zip(_matvec(self.w_o, new_hidden), self.b_o)]
        return logits, new_hidden

    def free_running_decode(
        self,
        context: Sequence[float],
        max_tokens: int,
        *,
        initial_token_id: int | None = None,
    ) -> DecodeResult:
        """Greedy, free-running decode: each output token is fed back as input.

        ``teacher_forcing_used`` is always False; decoding stops on EOS or after
        ``max_tokens`` steps.
        """
        if max_tokens <= 0:
            raise ValueError("max_tokens must be positive")
        token_id = self.bos_token_id if initial_token_id is None else initial_token_id
        hidden = self.initial_hidden()
        output_ids: list[int] = []
        output_tokens: list[str] = []
        steps: list[DecodeStep] = []
        stopped_on_eos = False
        for position in range(max_tokens):
            input_token_id = token_id
            logits, hidden = self.step(input_token_id, hidden, context)
            token_id = max(range(len(logits)), key=lambda idx: logits[idx])
            token = self.vocab[token_id]
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
            if token_id == self.eos_token_id:
                stopped_on_eos = True
                break
        return DecodeResult(tuple(output_ids), tuple(output_tokens), tuple(steps), stopped_on_eos)


__all__ = [
    "TinyGRUGenerator",
    "encode_context",
    "hash_token",
    "build_model_visible_generator_input",
    "detokenize",
]
