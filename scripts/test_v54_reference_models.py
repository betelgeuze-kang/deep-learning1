"""Deterministic smoke test for the v54 reference scorer/generator scaffolds.

Run directly:

    python3 scripts/test_v54_reference_models.py

This is a local reference smoke only. It trains on in-memory fixture pairs and
runs an untrained free-running decode; it produces no results/ artifacts and
asserts no real-generation/promotion readiness.
"""
from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from free_running_generator_contract import build_model_visible_generator_input
from free_running_generator_reference import TinyGRUGenerator, encode_context
from route_scorer_contract import promotion_readiness, score_features
from route_scorer_reference import PairwiseTrainingResult, feature_vector, train_pairwise_scorer


def test_scorer_learns_to_rank() -> None:
    # Positive candidates have higher score + evidence + valid provenance;
    # negatives are weaker. The scorer should learn positive > negative.
    pairs = []
    fixtures = [
        # (pos_score, pos_evp, neg_score, neg_evp)
        (0.9, 0.9, 0.2, 0.3),
        (0.8, 0.7, 0.1, 0.2),
        (0.7, 0.8, 0.3, 0.1),
        (0.95, 0.85, 0.25, 0.25),
    ]
    for pos_score, pos_evp, neg_score, neg_evp in fixtures:
        positive = feature_vector(pos_score, pos_evp, provenance_valid=True, candidate_count=3)
        negative = feature_vector(neg_score, neg_evp, provenance_valid=False, candidate_count=3)
        pairs.append((positive, negative))

    result = train_pairwise_scorer(pairs, learning_rate=0.2, epochs=300, l2_weight=1e-4)
    assert isinstance(result, PairwiseTrainingResult)
    assert result.loss_history[-1] < result.loss_history[0], "loss must decrease"

    # After training, every positive must outrank its negative (loss-order ready).
    for positive, negative in pairs:
        pos_score = score_features(result.weights, positive)
        neg_score = score_features(result.weights, negative)
        assert pos_score > neg_score, "positive candidate must outrank negative"

    # Determinism: identical fixtures + hyperparameters reproduce identical weights.
    again = train_pairwise_scorer(pairs, learning_rate=0.2, epochs=300, l2_weight=1e-4)
    assert again.weights == result.weights, "training must be deterministic"

    # The reference scorer must NOT claim promotion readiness on its own.
    readiness = promotion_readiness(
        external_label_source_ready=False,
        source_provenance_ready=True,
        heldout_metric_ready=False,
    )
    assert readiness.promotion_ready is False
    print("scorer: rank-learning + determinism + promotion-blocked OK")


def test_generator_free_running_decode() -> None:
    vocab = ["<bos>", "<eos>", "alpha", "beta", "gamma", "delta"]
    generator = TinyGRUGenerator(vocab, embed_dim=4, hidden_dim=4, context_dim=4, seed=7)
    assert generator.attention_blocks == 0
    assert generator.transformer_blocks == 0

    row = {
        "generation_id": "gen-0001",
        "sanitized_question": "what does the function return",
        "opaque_routehint": "rh-0x91ac",
    }
    payload = build_model_visible_generator_input(row)
    assert set(payload) == {"sanitized_question", "opaque_routehint"}, "only model-visible fields"
    context = encode_context(payload, dim=4)

    result = generator.free_running_decode(context, max_tokens=8)
    assert len(result.steps) <= 8
    assert all(step.teacher_forcing_used is False for step in result.steps), "no teacher forcing"
    # Each step's input is the previous step's output (free-running feedback).
    for previous, current in zip(result.steps, result.steps[1:]):
        assert current.input_token_id == previous.output_token_id, "output fed back as next input"

    # Determinism: same seed + context reproduces identical token ids.
    again = TinyGRUGenerator(vocab, embed_dim=4, hidden_dim=4, context_dim=4, seed=7)
    again_result = again.free_running_decode(context, max_tokens=8)
    assert again_result.token_ids == result.token_ids, "decode must be deterministic"

    # A leaked evaluator-only field in the model-visible row is rejected (fail-closed).
    try:
        build_model_visible_generator_input(
            {"sanitized_question": "q", "opaque_routehint": "rh", "evaluator_score": 0.9}
        )
    except ValueError:
        pass
    else:  # pragma: no cover
        raise AssertionError("evaluator-only field must be rejected")
    print("generator: free-running + model-visible-only + determinism OK")


def main() -> int:
    test_scorer_learns_to_rank()
    test_generator_free_running_decode()
    print("v54 reference models smoke OK (reference scaffold; not real generation evidence)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
