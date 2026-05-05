#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_apply_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_apply_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_apply.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 5 }
  NR == 1 {
    required_count = split("scenario arm quality_apply source_beta candidate_beta candidate_min candidate_max key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_correct_mean route_quality_candidate_weight_factor_wrong_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_raw_rate route_quality_selected_noisy_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-apply column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    factor = metric("route_quality_candidate_weight_factor_mean")

    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (qacc < 0 || qacc > 1 || factor < 0.5 || factor > 2.0) {
      die("candidate-apply metric out of expected range: " arm, 4)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 5)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("candidate-apply must not activate jump-neighbor routing: " arm, 6)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("candidate-apply selected noisy source too often: " arm, 7)
    }
    if (arm ~ /^candidate-/) {
      if (metric("route_quality_apply_active") != 1) {
        die("candidate arm should activate quality apply: " arm, 8)
      }
      if (metric("route_quality_candidate_weight_beta") <= 0) {
        die("candidate arm should report positive beta: " arm, 9)
      }
    }
    rows++
    if (arm == "proxy-off") off_seen = 1
    if (arm == "source-ranking") source_seen = 1
    if (arm == "candidate-b0p10") b010_seen = 1
    if (arm == "candidate-b0p25") b025_seen = 1
    if (arm == "candidate-b0p50") b050_seen = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 10)
    }
    if (!(off_seen && source_seen && b010_seen && b025_seen && b050_seen)) {
      die("missing one or more candidate-apply arms", 11)
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("route_quality_candidate_weight_factor_mean_mean" in idx)) {
      die("missing aggregate candidate factor metric", 12)
    }
    next
  }
  { rows++ }
  END {
    if (rows != 5) {
      die("expected 5 aggregate rows, found " rows, 13)
    }
  }
' "$AGG_CSV"

echo "route quality candidate-apply smoke passed"
