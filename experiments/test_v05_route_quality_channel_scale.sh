#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_channel_scale_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_channel_scale_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_channel_scale.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 3 }
  NR == 1 {
    required_count = split("scenario arm quality_apply quality_beta channel_weight key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_source_ranking_delta_mean route_quality_selected_raw_rate route_quality_selected_keyshape_rate route_quality_selected_noisy_rate route_quality_retry_raw_proxy_mean route_quality_retry_keyshape_proxy_mean route_quality_retry_noisy_proxy_mean route_quality_retry_raw_delta_mean route_quality_retry_keyshape_delta_mean route_quality_retry_noisy_delta_mean route_quality_selected_raw_qacc route_quality_selected_keyshape_qacc route_quality_selected_noisy_qacc lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing channel-scale column: " required[i], 2)
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
    selected_noisy = metric("route_quality_selected_noisy_rate")
    channel_weight = metric("channel_weight")
    apply_active = metric("route_quality_apply_active")

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
      die("channel-scale calibration must not activate jump-neighbor routing: " arm, 6)
    }
    if (!(raw_proxy == raw_proxy && keyshape_proxy == keyshape_proxy &&
          noisy_proxy == noisy_proxy)) {
      die("proxy metrics should be finite: " arm, 7)
    }
    if (selected_noisy > 0.25) {
      die("channel-scale calibration selected noisy source too often: " arm, 8)
    }

    rows++
    if (arm == "proxy-off") {
      off_seen = 1
      if ($idx["quality_apply"] != "none" || apply_active != 0) {
        die("proxy-off should keep quality apply disabled", 9)
      }
    } else if (arm == "proxy-default") {
      default_seen = 1
      if ($idx["quality_apply"] != "source-ranking" || channel_weight <= 0) {
        die("proxy-default should use positive channel source-ranking", 10)
      }
      default_qacc = qacc
    } else if (arm == "proxy-channel-sign") {
      channel_seen = 1
      if ($idx["quality_apply"] != "source-ranking" || channel_weight >= 0) {
        die("proxy-channel-sign should use negative channel source-ranking", 11)
      }
      channel_qacc = qacc
    } else {
      die("unexpected arm: " arm, 12)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 13)
    }
    if (!(off_seen && default_seen && channel_seen)) {
      die("missing one or more channel-scale arms", 14)
    }
    if (channel_qacc + 0.25 < default_qacc) {
      die("channel-sign arm regressed too far below default in smoke", 15)
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    required_count = split("arm rows qacc_mean qacc_std route_quality_selected_noisy_rate_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if ($idx["arm"] == "proxy-off") off_seen = 1
    if ($idx["arm"] == "proxy-default") default_seen = 1
    if ($idx["arm"] == "proxy-channel-sign") channel_seen = 1
    if (($idx["rows"] + 0) < 1) {
      die("aggregate row should include at least one sample", 21)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 22)
    }
  }
  END {
    if (rows != 3 || !(off_seen && default_seen && channel_seen)) {
      die("aggregate should contain the three channel-scale arms", 23)
    }
  }
' "$AGG_CSV"

echo "route quality channel-scale smoke passed"
