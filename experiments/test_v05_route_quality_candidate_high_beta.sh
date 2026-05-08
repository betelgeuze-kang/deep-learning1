#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_high_beta_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_high_beta_smoke_aggregate.csv"
BY_KEY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_high_beta_smoke_by_key_noise.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_high_beta.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 3 }
  NR == 1 {
    required_count = split("scenario arm candidate_beta candidate_min candidate_max key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_correct_mean route_quality_candidate_weight_factor_wrong_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_p90 route_quality_candidate_weight_factor_max route_quality_candidate_weight_entropy_mean route_quality_candidate_weight_top_share_mean route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_noisy_rate route_quality_selected_raw_qacc route_wrong_hint_strength_mean route_correct_hint_strength_mean lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-high-beta column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    cap = metric("candidate_max")
    factor = metric("route_quality_candidate_weight_factor_mean")
    factor_p90 = metric("route_quality_candidate_weight_factor_p90")
    factor_max = metric("route_quality_candidate_weight_factor_max")
    entropy = metric("route_quality_candidate_weight_entropy_mean")
    top_share = metric("route_quality_candidate_weight_top_share_mean")

    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (metric("route_quality_apply_active") != 1 ||
        metric("route_quality_candidate_weight_beta") < 3.0) {
      die("candidate-high-beta should keep high-beta candidate-weight active: " arm, 4)
    }
    if (qacc < 0 || qacc > 1 || factor < 0.5 || factor > cap ||
        factor_p90 < 0.5 || factor_p90 > cap ||
        factor_max < 0.5 || factor_max > cap) {
      die("candidate-high-beta factor/qacc out of range: " arm, 5)
    }
    if (entropy < 0 || top_share < 0 || top_share > 1) {
      die("candidate-high-beta concentration metric out of range: " arm, 6)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 7)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("candidate-high-beta must not activate jump-neighbor routing: " arm, 8)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("candidate-high-beta selected noisy source too often: " arm, 9)
    }
    if (metric("route_quality_candidate_weight_factor_gap") <= 0) {
      die("candidate-high-beta should preserve positive factor gap: " arm, 10)
    }

    rows++
    seen[arm] = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 11)
    }
    required_arms_count = split("candidate-b3p00-cap3p0 candidate-b4p00-cap4p0 candidate-b5p00-cap6p0", required_arms, " ")
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
    required_count = split("arm rows qacc_mean qacc_std route_quality_candidate_weight_beta_mean route_quality_candidate_weight_factor_p90_mean route_quality_candidate_weight_factor_max_mean route_quality_candidate_weight_entropy_mean_mean route_quality_candidate_weight_top_share_mean_mean route_wrong_hint_strength_mean_mean route_correct_hint_strength_mean_mean route_quality_selected_noisy_rate_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate candidate-high-beta column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (($idx["rows"] + 0) < 1) {
      die("aggregate row should include at least one sample", 21)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 22)
    }
  }
  END {
    if (rows != 3) {
      die("expected 3 aggregate rows, found " rows, 23)
    }
  }
' "$AGG_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    required_count = split("arm key_count noisy_source_rate rows qacc_mean qacc_std top_share_mean entropy_mean factor_max_mean wrong_strength_mean selected_noisy_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing by-key candidate-high-beta column: " required[i], 30)
      }
    }
    next
  }
  {
    rows++
    if (($idx["active_jump_rate_mean"] + 0) != 0) {
      die("by-key aggregate should preserve jump-neighbor inactivity", 31)
    }
  }
  END {
    if (rows != 3) {
      die("expected 3 by-key rows, found " rows, 32)
    }
  }
' "$BY_KEY_CSV"

echo "route quality candidate-high-beta smoke passed"
