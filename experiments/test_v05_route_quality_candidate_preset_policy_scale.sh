#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v05_route_quality_candidate_preset_policy_summary.csv"
POLICY_CSV="$RESULTS_DIR/v05_route_quality_candidate_preset_policy_policy.csv"
AGG_CSV="$RESULTS_DIR/v05_route_quality_candidate_preset_policy_aggregate.csv"

if [[ "${RUN_SOURCE:-1}" != "0" || ! -f "$SUMMARY_CSV" || ! -f "$POLICY_CSV" || ! -f "$AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v05_route_quality_candidate_preset_policy.sh"
fi

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("scenario key_count seed noisy_source_rate arm preset qacc apply_active beta factor_gap factor_max quality_score_gap selected_noisy_rate wrong_strength lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing preset-policy scale summary column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    if (metric("apply_active") != 1 || metric("beta") != 8) {
      die("preset-policy scale should keep candidate-weight beta=8 active", 3)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated", 4)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("preset-policy scale must not activate jump-neighbor routing", 5)
    }
    seen[$idx["arm"]]++
  }
  END {
    if (rows != 16) {
      die("expected 16 preset-policy scale summary rows, found " rows, 6)
    }
    if (seen["base-default"] != 8 || seen["hybrid-safe"] != 8) {
      die("preset-policy scale should contain 8 rows for each preset arm", 7)
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
    required_count = split("scenario key_count seed noisy_source_rate base_qacc hybrid_qacc qacc_delta base_factor_gap hybrid_factor_gap factor_gap_delta base_factor_max hybrid_factor_max factor_max_delta base_wrong_strength hybrid_wrong_strength wrong_strength_delta lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean recommendation", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing preset-policy scale column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("qacc_delta") < -0.001001) {
      die("hybrid-safe qacc regressed beyond tolerance in scale policy", 21)
    }
    if (metric("factor_gap_delta") >= 0) {
      die("hybrid-safe should lower factor gap in every scale cell", 22)
    }
    if (metric("factor_max_delta") > 0) {
      die("hybrid-safe should not raise factor max in any scale cell", 23)
    }
    if (metric("lookup_count_mean") <= 0 || metric("read_distance_mean") <= 0) {
      die("value-bearing route path should remain populated in scale policy", 24)
    }
    if (metric("routing_trigger_rate_mean") != 0 || metric("active_jump_rate_mean") != 0) {
      die("scale policy should preserve jump-neighbor inactivity", 25)
    }
    if ($idx["recommendation"] !~ /^hybrid-safe/) {
      die("preset-policy scale expected hybrid-safe recommendation", 26)
    }
  }
  END {
    if (rows != 8) {
      die("expected 8 preset-policy scale rows, found " rows, 27)
    }
  }
' "$POLICY_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("rows base_qacc_mean hybrid_qacc_mean qacc_delta_mean base_factor_gap_mean hybrid_factor_gap_mean factor_gap_delta_mean base_factor_max_mean hybrid_factor_max_mean factor_max_delta_mean base_wrong_strength_mean hybrid_wrong_strength_mean wrong_strength_delta_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean hybrid_recommended_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate preset-policy scale column: " required[i], 40)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 8) {
      die("aggregate preset-policy scale row count mismatch", 41)
    }
    if (metric("qacc_delta_mean") < -0.001001) {
      die("aggregate hybrid-safe qacc regressed beyond tolerance", 42)
    }
    if (metric("factor_gap_delta_mean") >= 0) {
      die("aggregate hybrid-safe should lower factor gap", 43)
    }
    if (metric("factor_max_delta_mean") > 0) {
      die("aggregate hybrid-safe should not raise factor max", 44)
    }
    if (metric("wrong_strength_delta_mean") > 0.001001) {
      die("aggregate hybrid-safe should not raise wrong strength beyond tolerance", 45)
    }
    if (metric("hybrid_recommended_rate") < 0.999999) {
      die("hybrid-safe should be recommended in all scale cells", 46)
    }
    if (metric("routing_trigger_rate_mean") != 0 || metric("active_jump_rate_mean") != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 47)
    }
  }
  END {
    if (rows != 1) {
      die("expected one aggregate preset-policy scale row, found " rows, 48)
    }
  }
' "$AGG_CSV"

echo "route quality candidate preset-policy scale passed"
