#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_auto_trigger_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_auto_trigger_smoke_aggregate.csv"
BY_KEY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_auto_trigger_smoke_by_key_noise.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh" --auto-trigger-smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  function close_enough(a, b) { return (a - b < 0.000002 && b - a < 0.000002) }
  BEGIN { expected_rows = 6 }
  NR == 1 {
    required_count = split("scenario arm candidate_basis basis_mix auto_factor_max auto_top_share auto_trigger_mode key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_max route_quality_candidate_weight_auto_hybrid_rate route_quality_candidate_weight_auto_factor_trigger_rate route_quality_candidate_weight_auto_top_share_trigger_rate route_quality_candidate_weight_auto_factor_max_probe_mean route_quality_candidate_weight_auto_top_share_probe_mean route_quality_selected_noisy_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-auto-trigger column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    basis = $idx["candidate_basis"]
    mode = $idx["auto_trigger_mode"]
    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("auto-trigger smoke should run key_count=128 seed=1", 3)
    }
    if (mode != "any" && mode != "factor" && mode != "top-share") {
      die("unexpected auto trigger mode: " mode, 4)
    }
    if (metric("qacc") < 0 || metric("qacc") > 1) {
      die("qacc out of range: " arm, 5)
    }
    if (metric("route_quality_apply_active") != 1 ||
        metric("route_quality_candidate_weight_beta") != 8.0) {
      die("auto-trigger smoke should keep candidate-weight beta=8 active: " arm, 6)
    }
    if (metric("route_quality_candidate_weight_factor_max") > 8.0) {
      die("auto-trigger smoke factor max exceeded clamp: " arm, 7)
    }
    if (basis == "auto" && mode == "factor" &&
        !close_enough(metric("route_quality_candidate_weight_auto_hybrid_rate"),
                      metric("route_quality_candidate_weight_auto_factor_trigger_rate"))) {
      die("factor mode should hybrid-switch exactly on factor trigger", 8)
    }
    if (basis == "auto" && mode == "top-share" &&
        !close_enough(metric("route_quality_candidate_weight_auto_hybrid_rate"),
                      metric("route_quality_candidate_weight_auto_top_share_trigger_rate"))) {
      die("top-share mode should hybrid-switch exactly on top-share trigger", 9)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 10)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("auto-trigger basis must not activate jump-neighbor routing: " arm, 11)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("auto-trigger selected noisy source too often: " arm, 12)
    }
    rows++
    seen[arm] = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 13)
    }
    if (!seen["base-default"] || !seen["hybrid-m0p25"] ||
        !seen["auto-any-f6p0-t0p72"] || !seen["auto-factor-f6p0"] ||
        !seen["auto-top-t0p72"] || !seen["auto-any-f6p4-t0p76"]) {
      die("auto-trigger smoke missing required arm", 14)
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    required_count = split("arm candidate_basis basis_mix auto_factor_max auto_top_share auto_trigger_mode rows qacc_mean qacc_std route_quality_candidate_weight_factor_gap_mean route_quality_candidate_weight_factor_max_mean route_quality_candidate_weight_auto_hybrid_rate_mean route_quality_candidate_weight_auto_factor_trigger_rate_mean route_quality_candidate_weight_auto_top_share_trigger_rate_mean route_quality_candidate_weight_auto_factor_max_probe_mean_mean route_quality_candidate_weight_auto_top_share_probe_mean_mean route_quality_selected_noisy_rate_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate candidate-auto-trigger column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (($idx["routing_trigger_rate_mean"] + 0) != 0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 21)
    }
  }
  END {
    if (rows != 6) {
      die("expected 6 aggregate rows, found " rows, 22)
    }
  }
' "$AGG_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    required_count = split("arm candidate_basis basis_mix auto_factor_max auto_top_share auto_trigger_mode key_count noisy_source_rate rows qacc_mean qacc_std factor_gap_mean factor_max_mean top_share_mean entropy_mean auto_hybrid_rate_mean auto_factor_trigger_rate_mean auto_top_share_trigger_rate_mean auto_factor_max_probe_mean auto_top_share_probe_mean wrong_strength_mean selected_noisy_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing by-key candidate-auto-trigger column: " required[i], 30)
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
    if (rows != 6) {
      die("expected 6 by-key rows, found " rows, 32)
    }
  }
' "$BY_KEY_CSV"

echo "route quality candidate-auto-trigger smoke passed"
