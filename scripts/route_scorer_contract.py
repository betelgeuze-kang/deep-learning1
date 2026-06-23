from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Iterable, Sequence


@dataclass(frozen=True)
class RouteDecision:
    selected_candidate: str | None
    abstained: bool
    reason: str
    margin: float


@dataclass(frozen=True)
class AbstentionThresholds:
    margin_threshold: float
    evidence_threshold: float
    total_cost: float
    wrong_count: int
    unnecessary_abstain_count: int
    correct_abstain_count: int


@dataclass(frozen=True)
class CalibrationExample:
    example_id: str
    candidates: tuple[tuple[str, float], ...]
    evidence_probability: float
    provenance_valid: bool
    correct_candidate: str | None
    should_answer: bool


@dataclass(frozen=True)
class PromotionReadiness:
    promotion_ready: bool
    reason: str


def score_features(weights: Sequence[float], features: Sequence[float], bias: float = 0.0) -> float:
    if len(weights) != len(features):
        raise ValueError(f"feature dimension mismatch: {len(features)} features for {len(weights)} weights")
    return bias + sum(weight * feature for weight, feature in zip(weights, features))


def pairwise_ranking_loss(
    positive_score: float,
    negative_score: float,
    *,
    weights: Iterable[float] = (),
    l2_weight: float = 1e-4,
) -> float:
    if l2_weight < 0:
        raise ValueError("l2_weight must be non-negative")
    gap = positive_score - negative_score
    pairwise = math.log1p(math.exp(-abs(gap))) + max(-gap, 0.0)
    l2 = sum(weight * weight for weight in weights)
    return pairwise + l2_weight * l2


def decide_route(
    candidates: Sequence[tuple[str, float]],
    evidence_probability: float,
    provenance_valid: bool,
    margin_threshold: float,
    evidence_threshold: float,
) -> RouteDecision:
    if margin_threshold < 0:
        raise ValueError("margin_threshold must be non-negative")
    if not 0 <= evidence_threshold <= 1:
        raise ValueError("evidence_threshold must be in [0, 1]")
    if not 0 <= evidence_probability <= 1:
        raise ValueError("evidence_probability must be in [0, 1]")

    ordered = sorted(candidates, key=lambda item: item[1], reverse=True)

    if not provenance_valid:
        return RouteDecision(None, True, "invalid-provenance", 0.0)

    if not ordered:
        return RouteDecision(None, True, "no-candidate", 0.0)

    top_score = ordered[0][1]
    second_score = ordered[1][1] if len(ordered) > 1 else 0.0
    margin = top_score - second_score

    if evidence_probability < evidence_threshold:
        return RouteDecision(None, True, "weak-evidence", margin)

    if margin < margin_threshold:
        return RouteDecision(None, True, "ambiguous-route", margin)

    return RouteDecision(ordered[0][0], False, "selected", margin)


def calibrate_abstention_thresholds(
    examples: Sequence[CalibrationExample],
    *,
    wrong_cost: float,
    abstain_cost: float,
) -> AbstentionThresholds:
    if not examples:
        raise ValueError("calibration examples are required")
    if not wrong_cost > abstain_cost > 0:
        raise ValueError("wrong_cost must be greater than positive abstain_cost")

    margins = {0.0}
    evidence_values = {0.0}
    for example in examples:
        decision = decide_route(example.candidates, example.evidence_probability, example.provenance_valid, 0.0, 0.0)
        margins.add(decision.margin)
        margins.add(math.nextafter(decision.margin, math.inf))
        evidence_values.add(example.evidence_probability)
        evidence_values.add(math.nextafter(example.evidence_probability, math.inf))
    evidence_values.add(1.0)

    best: AbstentionThresholds | None = None
    for margin_threshold in sorted(margins):
        for evidence_threshold in sorted(evidence_values):
            total_cost = 0.0
            wrong_count = 0
            unnecessary_abstain_count = 0
            correct_abstain_count = 0
            for example in examples:
                decision = decide_route(
                    example.candidates,
                    example.evidence_probability,
                    example.provenance_valid,
                    margin_threshold,
                    evidence_threshold,
                )
                selected_is_correct = decision.selected_candidate == example.correct_candidate
                if decision.abstained:
                    if example.should_answer and example.provenance_valid:
                        unnecessary_abstain_count += 1
                        total_cost += abstain_cost
                    else:
                        correct_abstain_count += 1
                    continue
                if (not example.should_answer) or (not selected_is_correct):
                    wrong_count += 1
                    total_cost += wrong_cost

            candidate = AbstentionThresholds(
                margin_threshold=margin_threshold,
                evidence_threshold=evidence_threshold,
                total_cost=total_cost,
                wrong_count=wrong_count,
                unnecessary_abstain_count=unnecessary_abstain_count,
                correct_abstain_count=correct_abstain_count,
            )
            if best is None or _threshold_sort_key(candidate) < _threshold_sort_key(best):
                best = candidate

    assert best is not None
    return best


def promotion_readiness(
    *,
    external_label_source_ready: bool,
    source_provenance_ready: bool,
    heldout_metric_ready: bool,
) -> PromotionReadiness:
    missing = []
    if not external_label_source_ready:
        missing.append("external-label-source")
    if not source_provenance_ready:
        missing.append("source-provenance")
    if not heldout_metric_ready:
        missing.append("heldout-metric")
    if missing:
        return PromotionReadiness(False, "missing-" + ",".join(missing))
    return PromotionReadiness(True, "promotion-evidence-complete")


def _threshold_sort_key(thresholds: AbstentionThresholds) -> tuple[float, int, int, float, float]:
    return (
        thresholds.total_cost,
        thresholds.wrong_count,
        thresholds.unnecessary_abstain_count,
        -thresholds.margin_threshold,
        -thresholds.evidence_threshold,
    )
