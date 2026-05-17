#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
MODE="smoke"

if [[ "${1:-}" == "--scale" ]]; then
  MODE="scale"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--scale]" >&2
  exit 2
fi

if [[ "$MODE" == "scale" ]]; then
  POLICY_CSV="$RESULTS_DIR/v05_route_quality_candidate_basis_policy_by_key_noise_policy.csv"
  AGG_CSV="$RESULTS_DIR/v05_route_quality_candidate_basis_policy_aggregate.csv"
  SOURCE_SUMMARY="$RESULTS_DIR/v05_route_quality_candidate_hybrid_promotion_summary.csv"
  EXPECTED_ROWS=9
  if [[ -f "$SOURCE_SUMMARY" ]]; then
    RUN_SOURCE=0 "$ROOT_DIR/experiments/run_v05_route_quality_candidate_basis_policy.sh"
  else
    "$ROOT_DIR/experiments/run_v05_route_quality_candidate_basis_policy.sh"
  fi
else
  POLICY_CSV="$RESULTS_DIR/v05_route_quality_candidate_basis_policy_smoke_by_key_noise_policy.csv"
  AGG_CSV="$RESULTS_DIR/v05_route_quality_candidate_basis_policy_smoke_aggregate.csv"
  EXPECTED_ROWS=1
  "$ROOT_DIR/experiments/run_v05_route_quality_candidate_basis_policy.sh" --smoke
fi

awk -F, -v expected_rows="$EXPECTED_ROWS" '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("key_count noisy_source_rate rows base_qacc_mean hybrid_qacc_mean qacc_delta base_factor_gap_mean hybrid_factor_gap_mean factor_gap_delta base_factor_max_mean hybrid_factor_max_mean factor_max_delta base_wrong_strength_mean hybrid_wrong_strength_mean wrong_strength_delta lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean recommendation", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-basis guardrail column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    if (metric("qacc_delta") < -0.001001) {
      die("hybrid qacc regressed beyond tolerance", 3)
    }
    if (metric("factor_gap_delta") >= 0) {
      die("hybrid should lower factor gap in every guardrail cell", 4)
    }
    if (metric("factor_max_delta") > 0) {
      die("hybrid should not raise factor max in any guardrail cell", 5)
    }
    if (metric("lookup_count_mean") <= 0 || metric("read_distance_mean") <= 0) {
      die("value-bearing route path should remain populated", 6)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("basis guardrail must not activate jump-neighbor routing", 7)
    }
    if ($idx["recommendation"] !~ /^hybrid-m0p25/) {
      die("guardrail expected hybrid-m0p25 recommendation", 8)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " guardrail rows, found " rows, 9)
    }
  }
' "$POLICY_CSV"

awk -F, -v expected_rows="$EXPECTED_ROWS" '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("rows base_qacc_mean hybrid_qacc_mean qacc_delta_mean base_factor_gap_mean hybrid_factor_gap_mean factor_gap_delta_mean base_wrong_strength_mean hybrid_wrong_strength_mean wrong_strength_delta_mean hybrid_recommended_rate active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate candidate-basis guardrail column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != expected_rows) {
      die("aggregate row count mismatch", 21)
    }
    if (metric("qacc_delta_mean") < -0.001001) {
      die("aggregate hybrid qacc regressed beyond tolerance", 22)
    }
    if (metric("factor_gap_delta_mean") >= 0) {
      die("aggregate hybrid should lower factor gap", 23)
    }
    if (metric("wrong_strength_delta_mean") > 0.001001) {
      die("aggregate hybrid should not raise wrong strength beyond tolerance", 24)
    }
    if (metric("hybrid_recommended_rate") < 0.999999) {
      die("hybrid should be recommended in all guardrail cells", 25)
    }
    if (metric("active_jump_rate_mean") != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 26)
    }
  }
  END {
    if (rows != 1) {
      die("expected one aggregate guardrail row, found " rows, 27)
    }
  }
' "$AGG_CSV"

echo "route quality candidate-basis guardrail ${MODE} passed"
