#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_source_norm_smoke_summary.csv"
AGG_CSV="$ROOT_DIR/results/v05_route_quality_source_norm_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_source_norm.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  BEGIN { expected_rows = 4 }
  NR == 1 {
    required_count = split("scenario arm quality_apply quality_beta channel_weight normalization key_count seed noisy_source_rate qacc route_quality_apply_active route_quality_source_normalization_active route_quality_source_ranking_delta_mean route_quality_selected_raw_rate route_quality_selected_keyshape_rate route_quality_selected_noisy_rate route_quality_retry_raw_proxy_mean route_quality_retry_keyshape_proxy_mean route_quality_retry_noisy_proxy_mean route_quality_retry_raw_norm_proxy_mean route_quality_retry_keyshape_norm_proxy_mean route_quality_retry_noisy_norm_proxy_mean route_quality_retry_raw_delta_mean route_quality_retry_keyshape_delta_mean route_quality_retry_noisy_delta_mean route_quality_selected_raw_qacc route_quality_selected_keyshape_qacc route_quality_selected_noisy_qacc lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing source-norm column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    norm = $idx["normalization"]
    qacc = metric("qacc")
    raw_proxy = metric("route_quality_retry_raw_proxy_mean")
    raw_norm_proxy = metric("route_quality_retry_raw_norm_proxy_mean")
    keyshape_norm_proxy = metric("route_quality_retry_keyshape_norm_proxy_mean")
    noisy_norm_proxy = metric("route_quality_retry_noisy_norm_proxy_mean")

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
      die("source normalization must not activate jump-neighbor routing: " arm, 6)
    }
    if (metric("route_quality_selected_noisy_rate") > 0.25) {
      die("source normalization selected noisy source too often: " arm, 7)
    }
    if (!(raw_proxy == raw_proxy && raw_norm_proxy == raw_norm_proxy &&
          keyshape_norm_proxy == keyshape_norm_proxy &&
          noisy_norm_proxy == noisy_norm_proxy)) {
      die("source norm proxy metrics should be finite: " arm, 8)
    }

    rows++
    if (arm == "proxy-off") {
      off_seen = 1
      if ($idx["quality_apply"] != "none" ||
          metric("route_quality_apply_active") != 0 ||
          metric("route_quality_source_normalization_active") != 0) {
        die("proxy-off should keep apply and normalization inactive", 9)
      }
    } else if (arm == "channel-sign-none") {
      none_seen = 1
      none_qacc = qacc
      if (norm != "none" ||
          metric("route_quality_source_normalization_active") != 0) {
        die("channel-sign-none should not normalize", 10)
      }
    } else if (arm == "channel-sign-center") {
      center_seen = 1
      if (norm != "center" ||
          metric("route_quality_source_normalization_active") != 1) {
        die("channel-sign-center should activate centering", 11)
      }
      if (raw_norm_proxy == raw_proxy) {
        die("centering should change raw normalized proxy", 12)
      }
    } else if (arm == "channel-sign-zscore") {
      zscore_seen = 1
      zscore_qacc = qacc
      if (norm != "zscore" ||
          metric("route_quality_source_normalization_active") != 1) {
        die("channel-sign-zscore should activate zscore", 13)
      }
      if (raw_norm_proxy == raw_proxy) {
        die("zscore should change raw normalized proxy", 14)
      }
    } else {
      die("unexpected arm: " arm, 15)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 16)
    }
    if (!(off_seen && none_seen && center_seen && zscore_seen)) {
      die("missing one or more source-normalization arms", 17)
    }
    if (zscore_qacc + 0.30 < none_qacc) {
      die("zscore normalized arm regressed too far below unnormalized channel-sign", 18)
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    required_count = split("arm rows qacc_mean route_quality_source_normalization_active_mean route_quality_selected_noisy_rate_mean route_quality_retry_raw_norm_proxy_mean_mean lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate source-norm column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if ($idx["arm"] == "proxy-off") off_seen = 1
    if ($idx["arm"] == "channel-sign-none") none_seen = 1
    if ($idx["arm"] == "channel-sign-center") center_seen = 1
    if ($idx["arm"] == "channel-sign-zscore") zscore_seen = 1
    if (($idx["rows"] + 0) < 1) {
      die("aggregate row should include at least one sample", 21)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0) {
      die("aggregate should preserve jump-neighbor inactivity", 22)
    }
  }
  END {
    if (rows != 4 || !(off_seen && none_seen && center_seen && zscore_seen)) {
      die("aggregate should contain the four source-normalization arms", 23)
    }
  }
' "$AGG_CSV"

echo "route quality source-normalization smoke passed"
