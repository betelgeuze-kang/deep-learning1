#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_feature_calibration_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_candidate_feature_calibration_smoke_aggregate.csv"
BY_KEY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_feature_calibration_smoke_by_key_noise.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_feature_calibration.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 5 }
  NR == 1 {
    required_count = split("scenario arm candidate_basis vote_margin_weight top_share_weight entropy_weight logdet_weight channel_weight source_credit_weight edge_credit_weight key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_p90 route_quality_candidate_weight_factor_max route_quality_candidate_weight_entropy_mean route_quality_candidate_weight_top_share_mean route_quality_score_mean route_quality_score_gap route_quality_selected_noisy_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-feature-calibration column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    basis = $idx["candidate_basis"]
    qacc = metric("qacc")
    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (qacc < 0 || qacc > 1) {
      die("qacc out of range: " arm, 4)
    }
    if (metric("route_quality_apply_active") != 1 ||
        metric("route_quality_candidate_weight_beta") != 8.0) {
      die("feature calibration should keep candidate-weight beta=8 active: " arm, 5)
    }
    if (basis != "base" && basis != "quality-score") {
      die("unexpected candidate basis: " basis, 6)
    }
    if (metric("route_quality_candidate_weight_factor_p90") < 0.5 ||
        metric("route_quality_candidate_weight_factor_max") > 8.0) {
      die("candidate feature factor out of clamp bounds: " arm, 7)
    }
    if (metric("route_quality_candidate_weight_entropy_mean") < 0 ||
        metric("route_quality_candidate_weight_top_share_mean") < 0 ||
        metric("route_quality_candidate_weight_top_share_mean") > 1) {
      die("candidate feature concentration metric out of range: " arm, 8)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 9)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("candidate feature calibration must not activate jump-neighbor routing: " arm, 10)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("candidate feature calibration selected noisy source too often: " arm, 11)
    }
    rows++
    seen[arm] = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 12)
    }
    required_arms_count = split("base-default feature-default feature-value feature-share feature-margin", required_arms, " ")
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
    required_count = split("arm candidate_basis rows qacc_mean qacc_std route_quality_candidate_weight_factor_gap_mean route_quality_candidate_weight_factor_max_mean route_quality_score_gap_mean route_quality_selected_noisy_rate_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate candidate-feature-calibration column: " required[i], 20)
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
    if (rows != 5) {
      die("expected 5 aggregate rows, found " rows, 23)
    }
  }
' "$AGG_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    required_count = split("arm candidate_basis key_count noisy_source_rate rows qacc_mean qacc_std factor_gap_mean factor_max_mean top_share_mean entropy_mean quality_score_gap_mean wrong_strength_mean selected_noisy_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing by-key candidate-feature-calibration column: " required[i], 30)
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
    if (rows != 5) {
      die("expected 5 by-key rows, found " rows, 32)
    }
  }
' "$BY_KEY_CSV"

echo "route quality candidate-feature-calibration smoke passed"
