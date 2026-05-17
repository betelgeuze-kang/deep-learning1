#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_basis_policy_by_key_noise_policy.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_basis_policy_aggregate.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_basis_policy.sh"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 9 }
  NR == 1 {
    required_count = split("key_count noisy_source_rate rows base_qacc_mean hybrid_qacc_mean qacc_delta base_factor_gap_mean hybrid_factor_gap_mean factor_gap_delta base_factor_max_mean hybrid_factor_max_mean factor_max_delta base_wrong_strength_mean hybrid_wrong_strength_mean wrong_strength_delta lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean recommendation", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing scale candidate-basis-policy column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    if (metric("lookup_count_mean") <= 0 || metric("read_distance_mean") <= 0) {
      die("value-bearing route path should remain populated", 3)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("basis policy scale must not activate jump-neighbor routing", 4)
    }
    if (metric("hybrid_factor_gap_mean") > metric("base_factor_gap_mean")) {
      die("hybrid should not increase factor gap in scale diagnostic", 5)
    }
    if ($idx["recommendation"] == "") {
      die("missing scale recommendation", 6)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " scale policy rows, found " rows, 7)
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
    required_count = split("rows base_qacc_mean hybrid_qacc_mean qacc_delta_mean base_factor_gap_mean hybrid_factor_gap_mean factor_gap_delta_mean base_wrong_strength_mean hybrid_wrong_strength_mean wrong_strength_delta_mean hybrid_recommended_rate active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate scale candidate-basis-policy column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 9) {
      die("scale aggregate should summarize nine key/noise cells", 21)
    }
    if (metric("hybrid_recommended_rate") < 0.5) {
      die("hybrid should be recommended in at least half the scale cells", 22)
    }
    if (metric("factor_gap_delta_mean") > 0) {
      die("hybrid should lower mean factor gap", 23)
    }
    if (metric("active_jump_rate_mean") != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 24)
    }
  }
  END {
    if (rows != 1) {
      die("expected one scale aggregate row, found " rows, 25)
    }
  }
' "$AGG_CSV"

echo "route quality candidate-basis-policy scale passed"
