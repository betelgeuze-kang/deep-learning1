"""Reference learnable route scorer (untrained reference scaffold).

This adds a deterministic SGD training loop on top of the pairwise-ranking
primitives in ``route_scorer_contract``. It is a reference implementation of
the linear scorer ``s_theta(q, c) = theta . phi(q, c)``; it is NOT promotion
evidence:

- it trains only on caller-supplied fixture pairs held in memory,
- it never reads external labels, heldout splits, or real model output,
- it produces no ``results/`` artifacts and flips no readiness flag,
- promotion stays gated by ``route_scorer_contract.promotion_readiness``; this
  module deliberately leaves ``external_label_source_ready`` and
  ``heldout_metric_ready`` false.

Loss (matching ``route_scorer_contract.pairwise_ranking_loss``)::

    L = softplus(-(s_pos - s_neg)) + l2_weight * ||theta||^2

Gradient w.r.t. ``theta``::

    dL/dtheta = -sigmoid(-(s_pos - s_neg)) * (phi_pos - phi_neg)
                + 2 * l2_weight * theta

The bias cancels in the pairwise gap and is therefore not trainable from
ranking pairs alone; it stays fixed at 0.0.
"""
from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Sequence

from route_scorer_contract import pairwise_ranking_loss, score_features


def feature_vector(
    candidate_score: float,
    evidence_probability: float,
    provenance_valid: bool,
    candidate_count: int,
) -> tuple[float, ...]:
    """Deterministic ``phi(q, c)`` from selection-time candidate fields.

    Uses only fields that are allowed at selection time: no oracle/expected
    answer, no raw source span, and no source locator.
    """
    if candidate_count < 1:
        raise ValueError("candidate_count must be >= 1")
    if not 0.0 <= evidence_probability <= 1.0:
        raise ValueError("evidence_probability must be in [0, 1]")
    return (
        float(candidate_score),
        float(evidence_probability),
        1.0 if provenance_valid else 0.0,
        1.0 / float(candidate_count),
    )


@dataclass(frozen=True)
class PairwiseTrainingResult:
    weights: tuple[float, ...]
    bias: float
    loss_history: tuple[float, ...]
    final_loss: float
    epochs: int


def _sigmoid(x: float) -> float:
    if x >= 0.0:
        z = math.exp(-x)
        return 1.0 / (1.0 + z)
    z = math.exp(x)
    return z / (1.0 + z)


def train_pairwise_scorer(
    pairs: Sequence[tuple[Sequence[float], Sequence[float]]],
    *,
    dim: int | None = None,
    learning_rate: float = 0.1,
    epochs: int = 200,
    l2_weight: float = 1e-4,
) -> PairwiseTrainingResult:
    """Fit ``theta`` by deterministic full-batch gradient descent.

    Each pair is ``(phi_positive, phi_negative)``: the positive candidate
    should score higher than the negative one. Weights init to zeros for
    determinism, so repeated runs on the same fixture produce identical output.
    """
    if not pairs:
        raise ValueError("at least one (positive, negative) feature pair is required")
    if learning_rate <= 0.0:
        raise ValueError("learning_rate must be positive")
    if epochs < 1:
        raise ValueError("epochs must be >= 1")
    if l2_weight < 0.0:
        raise ValueError("l2_weight must be non-negative")

    inferred_dim = len(pairs[0][0])
    if dim is None:
        dim = inferred_dim
    for positive, negative in pairs:
        if len(positive) != dim or len(negative) != dim:
            raise ValueError("all feature vectors must share the same dimension")

    weights = [0.0] * dim
    n = len(pairs)
    loss_history: list[float] = []

    for _ in range(epochs):
        grad = [0.0] * dim
        data_loss = 0.0
        for positive, negative in pairs:
            pos_score = score_features(weights, positive)
            neg_score = score_features(weights, negative)
            data_loss += pairwise_ranking_loss(pos_score, neg_score, l2_weight=0.0)
            gap = pos_score - neg_score
            coeff = -_sigmoid(-gap)
            for i in range(dim):
                grad[i] += coeff * (positive[i] - negative[i])
        l2_term = l2_weight * sum(weight * weight for weight in weights)
        loss_history.append(data_loss / n + l2_term)
        for i in range(dim):
            full_grad = grad[i] / n + 2.0 * l2_weight * weights[i]
            weights[i] -= learning_rate * full_grad

    return PairwiseTrainingResult(
        weights=tuple(weights),
        bias=0.0,
        loss_history=tuple(loss_history),
        final_loss=loss_history[-1],
        epochs=epochs,
    )


def score(weights: Sequence[float], features: Sequence[float], bias: float = 0.0) -> float:
    """Convenience wrapper around ``route_scorer_contract.score_features``."""
    return score_features(weights, features, bias)
