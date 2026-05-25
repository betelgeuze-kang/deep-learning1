#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

MODE="quick"
if [[ "${1:-}" == "--extended" ]]; then
  MODE="extended"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--extended]" >&2
  exit 2
fi

echo "goal: shell-syntax"
bash -n "$ROOT_DIR"/experiments/*.sh

echo "goal: build-dmv02"
cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2

echo "goal: h5-route-quality-closure"
if [[ "$MODE" == "extended" ]]; then
  bash "$ROOT_DIR/experiments/test_v05_route_quality_closure.sh" --extended
else
  bash "$ROOT_DIR/experiments/test_v05_route_quality_closure.sh"
fi

echo "goal: h6-span-boundary"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_boundary.sh"

echo "goal: h6-exact-span"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_exact.sh"

echo "goal: h6-exact-span-scale"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_exact_scale.sh"

echo "goal: h6-hash-span"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_hash.sh"

echo "goal: h6-hash-span-scale"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_hash_scale.sh"

echo "goal: h6-span-ambiguity"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_ambiguity.sh"

echo "goal: h6-span-learned-source"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_learned_source.sh"

echo "goal: h6-span-quality"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_quality_diagnostics.sh"

echo "goal: h6-span-candidate-quality-gap"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_candidate_quality_gap.sh"

echo "goal: h6-span-prefix-ranking"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_prefix_ranking.sh"

echo "goal: h6-span-key-support-ranking"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_key_support_ranking.sh"

echo "goal: h6-span-local-energy-ranking"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_local_energy_ranking.sh"

echo "goal: h6-span-local-energy-scale"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_local_energy_scale.sh"

echo "goal: h6-span-local-energy-composition"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_local_energy_composition.sh"

echo "goal: h6-span-local-energy-policy"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_local_energy_policy.sh"

echo "goal: h6-span-local-energy-policy-scale"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_local_energy_policy_scale.sh"

echo "goal: h6-span-first-guardrail"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_first_guardrail.sh"

echo "goal: h6-span-first-guardrail-degradation"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_first_guardrail_degradation.sh"

echo "goal: h6-span-adaptive-guardrail"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_adaptive_guardrail.sh"

echo "goal: h6-span-adaptive-guardrail-scale"
bash "$ROOT_DIR/experiments/test_v06_route_memory_span_adaptive_guardrail_scale.sh"

echo "goal: h6-chunk-quality"
bash "$ROOT_DIR/experiments/test_v06_route_memory_chunk_quality_diagnostics.sh"

echo "goal: h6-chunk-local-scorers"
bash "$ROOT_DIR/experiments/test_v06_route_memory_chunk_local_scorers.sh"

echo "goal: h6-chunk-code-similarity"
bash "$ROOT_DIR/experiments/test_v06_route_memory_chunk_code_similarity.sh"

echo "goal: h10-teacher-free-chunk-ranker"
bash "$ROOT_DIR/experiments/test_v10_teacher_free_chunk_ranker.sh"

echo "goal: h10-chunk-credit-source-robustness"
bash "$ROOT_DIR/experiments/test_v10_chunk_credit_source_robustness.sh"

echo "goal: h10-chunk-credit-fallback-retry-exercise"
bash "$ROOT_DIR/experiments/test_v10_chunk_credit_fallback_retry_exercise.sh"

echo "goal: h10-chunk-credit-abstain-policy"
bash "$ROOT_DIR/experiments/test_v10_chunk_credit_abstain_policy.sh"

echo "goal: h10-teacher-label-contract"
bash "$ROOT_DIR/experiments/test_v10_teacher_label_contract.sh"

echo "goal: h10-teacher-label-collection-harness"
bash "$ROOT_DIR/experiments/test_v10_teacher_label_collection_harness.sh"

echo "goal: h10-teacher-distillation-learner"
bash "$ROOT_DIR/experiments/test_v10_teacher_distillation_learner.sh"

echo "goal: h10-learned-chunk-quality-scorer"
bash "$ROOT_DIR/experiments/test_v10_learned_chunk_quality_scorer.sh"

echo "goal: h10-teacher-external-label-ingestion"
bash "$ROOT_DIR/experiments/test_v10_teacher_external_label_ingestion.sh"

echo "goal: h10-teacher-external-label-import"
bash "$ROOT_DIR/experiments/test_v10_teacher_external_label_import.sh"

echo "goal: h10-teacher-external-label-source-verifier"
bash "$ROOT_DIR/experiments/test_v10_teacher_external_label_source_verifier.sh"

echo "goal: h10-teacher-external-label-source-import"
bash "$ROOT_DIR/experiments/test_v10_teacher_external_label_source_import.sh"

echo "goal: h10-chunk-credit-distillation-gate"
bash "$ROOT_DIR/experiments/test_v10_chunk_credit_distillation_gate.sh"

echo "goal: h6-wrong-candidate-robustness"
bash "$ROOT_DIR/experiments/test_v06_route_memory_wrong_candidate_robustness.sh"

echo "goal: h6-abstain-retry-guardrail"
bash "$ROOT_DIR/experiments/test_v06_route_memory_abstain_retry_guardrail.sh"

echo "goal: h7-promotion-gate"
bash "$ROOT_DIR/experiments/test_v07_route_memory_promotion_gate.sh"

if [[ "$MODE" == "extended" ]]; then
  echo "goal: h6-exact-span-scale-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_exact_scale.sh" >/dev/null

  echo "goal: h6-hash-span-scale-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_hash_scale.sh" >/dev/null

  echo "goal: h6-span-ambiguity-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_ambiguity.sh" >/dev/null

  echo "goal: h6-span-learned-source-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_learned_source.sh" >/dev/null

  echo "goal: h6-span-quality-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_quality_diagnostics.sh" >/dev/null

  echo "goal: h6-span-candidate-quality-gap-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_candidate_quality_gap.sh" >/dev/null

  echo "goal: h6-span-prefix-ranking-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_prefix_ranking.sh" >/dev/null

  echo "goal: h6-span-key-support-ranking-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_key_support_ranking.sh" >/dev/null

  echo "goal: h6-span-local-energy-ranking-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_ranking.sh" >/dev/null

  echo "goal: h6-span-local-energy-scale-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_scale.sh" >/dev/null

  echo "goal: h6-span-local-energy-composition-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_composition.sh" >/dev/null

  echo "goal: h6-span-local-energy-policy-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_policy.sh" >/dev/null

  echo "goal: h6-span-local-energy-policy-scale-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_policy_scale.sh" >/dev/null

  echo "goal: h6-span-first-guardrail-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_first_guardrail.sh" >/dev/null

  echo "goal: h6-span-first-guardrail-degradation-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_first_guardrail_degradation.sh" >/dev/null

  echo "goal: h6-span-adaptive-guardrail-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_adaptive_guardrail.sh" >/dev/null

  echo "goal: h6-span-adaptive-guardrail-scale-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_span_adaptive_guardrail_scale.sh" >/dev/null

  echo "goal: h6-chunk-quality-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_chunk_quality_diagnostics.sh" >/dev/null

  echo "goal: h6-chunk-local-scorers-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_chunk_local_energy_prefix.sh" >/dev/null

  echo "goal: h6-chunk-code-similarity-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_chunk_code_similarity.sh" >/dev/null

  echo "goal: h10-teacher-free-chunk-ranker-standard"
  bash "$ROOT_DIR/experiments/test_v10_teacher_free_chunk_ranker_scale.sh" >/dev/null

  echo "goal: h10-chunk-credit-source-robustness-standard"
  bash "$ROOT_DIR/experiments/run_v10_chunk_credit_source_robustness.sh" >/dev/null

  echo "goal: h10-chunk-credit-fallback-retry-exercise-standard"
  bash "$ROOT_DIR/experiments/run_v10_chunk_credit_fallback_retry_exercise.sh" >/dev/null

  echo "goal: h10-chunk-credit-abstain-policy-standard"
  bash "$ROOT_DIR/experiments/run_v10_chunk_credit_abstain_policy.sh" >/dev/null

  echo "goal: h10-teacher-label-contract-standard"
  bash "$ROOT_DIR/experiments/run_v10_teacher_label_contract.sh" >/dev/null

  echo "goal: h10-teacher-label-collection-harness-standard"
  bash "$ROOT_DIR/experiments/run_v10_teacher_label_collection_harness.sh" >/dev/null

  echo "goal: h10-teacher-distillation-learner-standard"
  bash "$ROOT_DIR/experiments/run_v10_teacher_distillation_learner.sh" >/dev/null

  echo "goal: h10-teacher-external-label-ingestion-standard"
  bash "$ROOT_DIR/experiments/run_v10_teacher_external_label_ingestion.sh" >/dev/null

  echo "goal: h10-chunk-credit-distillation-gate-standard"
  bash "$ROOT_DIR/experiments/run_v10_chunk_credit_distillation_gate.sh" >/dev/null

  echo "goal: h6-wrong-candidate-robustness-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_wrong_candidate_robustness.sh" >/dev/null

  echo "goal: h6-abstain-retry-guardrail-standard"
  bash "$ROOT_DIR/experiments/run_v06_route_memory_abstain_retry_guardrail.sh" >/dev/null

  echo "goal: h7-promotion-gate-standard"
  bash "$ROOT_DIR/experiments/run_v07_route_memory_promotion_gate.sh" >/dev/null
fi

echo "v07 goal route-memory closure passed"
