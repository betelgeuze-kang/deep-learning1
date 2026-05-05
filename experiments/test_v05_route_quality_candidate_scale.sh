#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_scale_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_scale_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_scale.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 4 }
  NR == 1 {
    required_count = split("scenario arm quality_apply candidate_beta key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_correct_mean route_quality_candidate_weight_factor_wrong_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_noisy_rate route_quality_selected_raw_qacc lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-scale column: " required[i], 2)
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
      die("candidate-scale metric out of expected range: " arm, 4)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 5)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("candidate-scale must not activate jump-neighbor routing: " arm, 6)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("candidate-scale selected noisy source too often: " arm, 7)
    }
    if (arm == "proxy-off") {
      off_seen = 1
      if ($idx["quality_apply"] != "none" ||
          metric("route_quality_apply_active") != 0 ||
          metric("route_quality_candidate_weight_beta") != 0) {
        die("proxy-off should keep candidate quality apply inactive", 8)
      }
    } else if (arm ~ /^candidate-/) {
      if (metric("route_quality_apply_active") != 1) {
        die("candidate arm should activate quality apply: " arm, 9)
      }
      if (metric("route_quality_candidate_weight_beta") <= 0) {
        die("candidate arm should report positive beta: " arm, 10)
      }
      if (metric("route_quality_candidate_weight_factor_gap") <= 0) {
        die("candidate arm should preserve positive correct/wrong factor gap: " arm, 11)
      }
    } else {
      die("unexpected arm: " arm, 12)
    }

    rows++
    seen[arm] = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 13)
    }
    required_arms_count = split("proxy-off candidate-b0p25 candidate-b0p50 candidate-b0p75", required_arms, " ")
    for (i = 1; i <= required_arms_count; i++) {
      if (!seen[required_arms[i]]) {
        die("missing arm: " required_arms[i], 14)
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
    required_count = split("arm rows qacc_mean route_quality_apply_active_mean route_quality_candidate_weight_beta_mean route_quality_candidate_weight_factor_gap_mean route_quality_candidate_weight_gap_mean route_quality_candidate_best_correct_rate_mean route_quality_selected_noisy_rate_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate candidate-scale column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    arm = $idx["arm"]
    if (arm == "proxy-off") off_seen = 1
    if (arm == "candidate-b0p25") b025_seen = 1
    if (arm == "candidate-b0p50") b050_seen = 1
    if (arm == "candidate-b0p75") b075_seen = 1
    if (($idx["rows"] + 0) < 1) {
      die("aggregate row should include at least one sample", 21)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 22)
    }
  }
  END {
    if (rows != 4 || !(off_seen && b025_seen && b050_seen && b075_seen)) {
      die("aggregate should contain the four candidate-scale arms", 23)
    }
  }
' "$AGG_CSV"

echo "route quality candidate-scale smoke passed"
