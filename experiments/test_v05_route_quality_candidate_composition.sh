#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_composition_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_composition_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_composition.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 6 }
  NR == 1 {
    required_count = split("scenario arm quality_apply source_beta candidate_beta key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_source_ranking_delta_mean route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_raw_rate route_quality_selected_noisy_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-composition column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (qacc < 0 || qacc > 1) {
      die("qacc out of range: " arm, 4)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 5)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("candidate composition must not activate jump-neighbor routing: " arm, 6)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("candidate composition selected noisy source too often: " arm, 7)
    }
    if (arm != "proxy-off" && metric("route_quality_apply_active") != 1) {
      die("apply arm should be active: " arm, 8)
    }
    if (arm ~ /^source-candidate/ &&
        metric("route_quality_source_ranking_delta_mean") == 0) {
      die("source-candidate arm should apply source ranking: " arm, 9)
    }
    if (arm ~ /^source-candidate/ &&
        metric("route_quality_candidate_weight_beta") == 0) {
      die("source-candidate arm should apply candidate weight: " arm, 10)
    }
    rows++
    seen[arm] = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 11)
    }
    required_arms_count = split("proxy-off source-ranking candidate-b0p25 candidate-b0p50 source-candidate-b0p25 source-candidate-b0p50", required_arms, " ")
    for (i = 1; i <= required_arms_count; i++) {
      if (!seen[required_arms[i]]) {
        die("missing arm: " required_arms[i], 12)
      }
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
    if (!("route_quality_candidate_weight_factor_gap_mean" in idx)) {
      die("missing aggregate candidate factor gap", 13)
    }
    next
  }
  { rows++ }
  END {
    if (rows != 6) {
      die("expected 6 aggregate rows, found " rows, 14)
    }
  }
' "$AGG_CSV"

echo "route quality candidate-composition smoke passed"
