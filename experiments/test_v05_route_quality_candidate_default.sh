#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_default_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_default_smoke_aggregate.csv"
BY_KEY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_default_smoke_by_key_noise.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_default.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 3 }
  NR == 1 {
    required_count = split("scenario arm quality_apply source_beta candidate_beta candidate_min candidate_max key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_source_ranking_beta route_quality_source_ranking_delta_mean route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_p90 route_quality_candidate_weight_factor_max route_quality_candidate_weight_entropy_mean route_quality_candidate_weight_top_share_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_raw_rate route_quality_selected_keyshape_rate route_quality_selected_noisy_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-default column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    apply = $idx["quality_apply"]
    beta = metric("candidate_beta")
    cap = metric("candidate_max")

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
      die("candidate default must not activate jump-neighbor routing: " arm, 6)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("candidate default selected noisy source too often: " arm, 7)
    }
    if (arm == "proxy-off") {
      if (metric("route_quality_apply_active") != 0 || apply != "none") {
        die("proxy-off should keep quality application inactive", 8)
      }
    } else {
      if (metric("route_quality_apply_active") != 1 || beta != 8.0 || cap != 8.0) {
        die("apply arms should use beta=8 cap=8: " arm, 9)
      }
      if (metric("route_quality_candidate_weight_factor_gap") <= 0 ||
          metric("route_quality_candidate_weight_factor_p90") < 0.5 ||
          metric("route_quality_candidate_weight_factor_p90") > cap ||
          metric("route_quality_candidate_weight_factor_max") < 0.5 ||
          metric("route_quality_candidate_weight_factor_max") > cap) {
        die("candidate default factor guard failed: " arm, 10)
      }
    }
    if (arm == "source-candidate-default" &&
        metric("route_quality_source_ranking_delta_mean") == 0) {
      die("source-candidate should also apply source ranking", 11)
    }

    rows++
    seen[arm] = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 12)
    }
    required_arms_count = split("proxy-off candidate-default source-candidate-default", required_arms, " ")
    for (i = 1; i <= required_arms_count; i++) {
      if (!seen[required_arms[i]]) {
        die("missing arm: " required_arms[i], 13)
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
    required_count = split("arm rows qacc_mean qacc_std route_quality_apply_active_mean route_quality_source_ranking_delta_mean_mean route_quality_candidate_weight_factor_gap_mean route_quality_candidate_weight_factor_max_mean route_quality_selected_noisy_rate_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate candidate-default column: " required[i], 20)
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
    required_count = split("arm key_count noisy_source_rate rows qacc_mean qacc_std factor_gap_mean factor_p90_mean factor_max_mean top_share_mean entropy_mean wrong_strength_mean selected_noisy_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing by-key candidate-default column: " required[i], 30)
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

echo "route quality candidate-default smoke passed"
