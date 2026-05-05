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
    required_count = split("scenario arm qacc route_quality_apply_active route_quality_retry_raw_proxy_mean route_quality_retry_keyshape_proxy_mean route_quality_retry_noisy_proxy_mean route_quality_retry_raw_delta_mean route_quality_retry_keyshape_delta_mean route_quality_retry_noisy_delta_mean route_quality_selected_raw_qacc route_quality_selected_keyshape_qacc route_quality_selected_noisy_qacc route_quality_selected_noisy_rate lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing source calibration column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    raw_proxy = metric("route_quality_retry_raw_proxy_mean")
    keyshape_proxy = metric("route_quality_retry_keyshape_proxy_mean")
    noisy_proxy = metric("route_quality_retry_noisy_proxy_mean")
    raw_delta = metric("route_quality_retry_raw_delta_mean")
    keyshape_delta = metric("route_quality_retry_keyshape_delta_mean")
    noisy_delta = metric("route_quality_retry_noisy_delta_mean")
    raw_qacc = metric("route_quality_selected_raw_qacc")
    keyshape_qacc = metric("route_quality_selected_keyshape_qacc")
    noisy_qacc = metric("route_quality_selected_noisy_qacc")
    selected_noisy = metric("route_quality_selected_noisy_rate")

    if (qacc < 0 || qacc > 1) {
      die("qacc out of range: " arm, 3)
    }
    if (metric("lookup_count") <= 0 || metric("read_distance") <= 0) {
      die("value-bearing route path should remain populated: " arm, 4)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("quality source calibration must not activate jump-neighbor routing: " arm, 5)
    }
    if (selected_noisy > 0.001) {
      die("quality source calibration smoke should avoid noisy selected source: " arm, 6)
    }
    if (raw_qacc < 0 || raw_qacc > 1 || keyshape_qacc < 0 ||
        keyshape_qacc > 1 || noisy_qacc < 0 || noisy_qacc > 1) {
      die("selected-source qacc out of range: " arm, 7)
    }

    if (arm == "apply-none-source-order") {
      none_seen = 1
      none_proxy_signal += (raw_proxy != 0 || keyshape_proxy != 0 || noisy_proxy != 0)
    } else if (arm == "source-ranking-b0p10") {
      b010_seen = 1
      b010_delta_signal += (raw_delta != 0 || keyshape_delta != 0 || noisy_delta != 0)
      b010_raw_proxy = raw_proxy
      b010_keyshape_proxy = keyshape_proxy
      b010_noisy_proxy = noisy_proxy
      b010_raw_delta = raw_delta
      b010_keyshape_delta = keyshape_delta
      b010_noisy_delta = noisy_delta
    } else if (arm == "source-ranking-b0p25") {
      b025_seen = 1
      b025_delta_signal += (raw_delta != 0 || keyshape_delta != 0 || noisy_delta != 0)
      b025_raw_delta = raw_delta
      b025_keyshape_delta = keyshape_delta
      b025_noisy_delta = noisy_delta
    } else if (arm == "fixed-keyshape-none") {
      fixed_seen = 1
      fixed_keyshape_proxy = keyshape_proxy
    }
    rows++
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 8)
    }
    if (!(none_seen && b010_seen && b025_seen && fixed_seen)) {
      die("missing one or more source calibration arms", 9)
    }
    if (none_proxy_signal == 0) {
      die("apply-none should still expose diagnostic source proxies", 10)
    }
    if (b010_delta_signal == 0 || b025_delta_signal == 0) {
      die("source-ranking should expose per-source quality deltas", 11)
    }
    if (b025_raw_delta < b010_raw_delta && b010_raw_delta < 0.249) {
      die("beta=0.25 raw delta should reflect a stronger or capped source proxy", 12)
    }
    if (fixed_keyshape_proxy == 0 && b010_keyshape_proxy == 0) {
      die("key-shape source proxy should be observable", 13)
    }
  }
' "$SUMMARY_CSV"

echo "route quality source calibration smoke passed"
