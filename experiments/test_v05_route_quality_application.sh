#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_application_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_application.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 5 }
  NR == 1 {
    required_count = split("scenario arm quality_apply quality_beta key_count seed qacc route_quality_apply_active route_quality_source_ranking_beta route_quality_source_ranking_delta_mean route_quality_selected_raw_rate route_quality_selected_keyshape_rate route_quality_selected_noisy_rate route_source_retry_raw_selected_rate route_source_retry_keyshape_selected_rate route_source_retry_noisy_selected_rate route_quality_logdet_mean route_quality_score_mean lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing summary column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    apply_active = metric("route_quality_apply_active")
    beta = metric("route_quality_source_ranking_beta")
    delta = metric("route_quality_source_ranking_delta_mean")
    selected_noisy = metric("route_quality_selected_noisy_rate")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (qacc < 0 || qacc > 1) {
      die("qacc out of range: " arm, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-bearing route path should remain populated: " arm, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("quality application must not activate jump-neighbor routing: " arm, 6)
    }
    if (arm == "apply-none-source-order" || arm == "fixed-keyshape-none") {
      if ($idx["quality_apply"] != "none" || apply_active != 0) {
        die("none arms should keep quality apply inactive: " arm, 7)
      }
    } else if (arm ~ /^source-ranking/) {
      if ($idx["quality_apply"] != "source-ranking" || apply_active != 1) {
        die("source-ranking arm should activate quality apply: " arm, 8)
      }
      if (beta <= 0 || !(delta == delta)) {
        die("source-ranking beta/delta should be finite and active: " arm, 9)
      }
      if (selected_noisy > 0.001) {
        die("source-ranking should not select noisy retry in smoke: " arm, 10)
      }
    } else {
      die("unexpected arm: " arm, 11)
    }

    rows++
    if (arm == "apply-none-source-order") {
      none_seen = 1
      none_qacc = qacc
    } else if (arm == "source-ranking-b0p10") {
      b010_seen = 1
      b010_qacc = qacc
      b010_delta = delta
    } else if (arm == "source-ranking-b0p25") {
      b025_seen = 1
      b025_qacc = qacc
      b025_delta = delta
    } else if (arm == "source-ranking-keyshape-prior") {
      prior_seen = 1
      prior_qacc = qacc
      prior_delta = delta
    } else if (arm == "fixed-keyshape-none") {
      fixed_seen = 1
      fixed_qacc = qacc
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 12)
    }
    if (!(none_seen && b010_seen && b025_seen && prior_seen && fixed_seen)) {
      die("missing one or more quality application arms", 13)
    }
    if (b010_qacc + 0.10 < none_qacc || b025_qacc + 0.10 < none_qacc) {
      die("source-ranking quality apply regressed qacc beyond smoke tolerance", 14)
    }
    if (prior_qacc + 0.10 < none_qacc) {
      die("source-ranking keyshape-prior regressed qacc beyond smoke tolerance", 15)
    }
    if (b010_delta == 0 && b025_delta == 0 && prior_delta == 0) {
      die("source-ranking delta should be observable", 15)
    }
    if (b025_delta <= b010_delta && b010_delta < 0.249) {
      die("source-ranking beta sweep should increase delta unless already capped", 17)
    }
    if (prior_delta == 0) {
      die("source-ranking keyshape-prior delta should be observable", 18)
    }
    if (fixed_qacc < 0 || prior_qacc < 0) {
      die("reference qacc should be populated", 19)
    }
  }
' "$SUMMARY_CSV"

echo "route quality application smoke passed"
