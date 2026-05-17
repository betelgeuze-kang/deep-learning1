#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_preset_regression_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_preset_regression_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_preset_regression.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  function abs(x) { return x < 0 ? -x : x }
  BEGIN { expected_rows = 2 }
  NR == 1 {
    required_count = split("scenario key_count seed noisy_source_rate basis explicit_qacc preset_qacc qacc_delta explicit_apply_active preset_apply_active explicit_beta preset_beta explicit_factor_gap preset_factor_gap factor_gap_delta explicit_factor_max preset_factor_max factor_max_delta explicit_quality_score_gap preset_quality_score_gap quality_score_gap_delta explicit_selected_noisy_rate preset_selected_noisy_rate explicit_wrong_strength preset_wrong_strength wrong_strength_delta lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean equivalent", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing preset-regression column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    if (metric("key_count") != 64 || metric("seed") != 1) {
      die("preset-regression smoke should run key_count=64 seed=1", 3)
    }
    if (metric("explicit_apply_active") != 1 ||
        metric("preset_apply_active") != 1 ||
        metric("explicit_beta") != 8 ||
        metric("preset_beta") != 8) {
      die("preset-regression should keep candidate-weight beta=8 active", 4)
    }
    if (metric("equivalent") != 1) {
      die("preset row is not equivalent to explicit row", 5)
    }
    if (abs(metric("qacc_delta")) > 0.000002 ||
        abs(metric("factor_gap_delta")) > 0.000002 ||
        abs(metric("factor_max_delta")) > 0.000002 ||
        abs(metric("wrong_strength_delta")) > 0.000002) {
      die("preset-regression metric delta should be zero", 6)
    }
    if (metric("lookup_count_mean") <= 0 || metric("read_distance_mean") <= 0) {
      die("value-bearing route path should remain populated", 7)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("preset-regression must not activate jump-neighbor routing", 8)
    }
    seen[$idx["basis"]] = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " preset-regression rows, found " rows, 9)
    }
    if (!seen["base"] || !seen["hybrid"]) {
      die("preset-regression smoke missing base or hybrid row", 10)
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("rows equivalent_rate qacc_delta_mean factor_gap_delta_mean factor_max_delta_mean quality_score_gap_delta_mean wrong_strength_delta_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate preset-regression column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 2 || metric("equivalent_rate") != 1) {
      die("preset-regression aggregate should show full equivalence", 21)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 22)
    }
  }
  END {
    if (rows != 1) {
      die("expected one aggregate preset-regression row, found " rows, 23)
    }
  }
' "$AGG_CSV"

echo "route quality candidate preset-regression smoke passed"
