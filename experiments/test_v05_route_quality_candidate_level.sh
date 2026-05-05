#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_candidate_level_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_candidate_level.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 4 }
  NR == 1 {
    required_count = split("scenario arm quality_apply quality_beta channel_weight normalization key_count seed noisy_source_rate qacc candidate_weight_correct candidate_weight_wrong candidate_weight_gap candidate_best_correct_rate selected_raw_rate selected_keyshape_rate selected_noisy_rate selected_raw_qacc lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing candidate-level column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    correct_weight = metric("candidate_weight_correct")
    wrong_weight = metric("candidate_weight_wrong")
    best_correct = metric("candidate_best_correct_rate")

    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (qacc < 0 || qacc > 1 || best_correct < 0 || best_correct > 1) {
      die("candidate-level metric out of range: " arm, 4)
    }
    if (!(correct_weight == correct_weight && wrong_weight == wrong_weight)) {
      die("candidate-level weights should be finite: " arm, 5)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 6)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("candidate-level diagnostics must not activate jump-neighbor routing: " arm, 7)
    }
    if (metric("selected_noisy_rate") > 0.25) {
      die("candidate-level diagnostics selected noisy source too often: " arm, 8)
    }
    rows++
    if (arm == "proxy-off") off_seen = 1
    if (arm == "channel-sign-none") none_seen = 1
    if (arm == "channel-sign-center") center_seen = 1
    if (arm == "channel-sign-zscore") zscore_seen = 1
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 9)
    }
    if (!(off_seen && none_seen && center_seen && zscore_seen)) {
      die("missing one or more candidate-level arms", 10)
    }
  }
' "$SUMMARY_CSV"

echo "route quality candidate-level smoke passed"
