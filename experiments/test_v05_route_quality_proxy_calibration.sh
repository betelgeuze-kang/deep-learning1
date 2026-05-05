#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_quality_proxy_calibration_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_quality_proxy_calibration.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 6 }
  NR == 1 {
    required_count = split("scenario arm quality_beta logdet_weight entropy_weight vote_margin_weight top_share_weight channel_weight key_count seed qacc route_quality_source_ranking_delta_mean route_quality_selected_raw_rate route_quality_selected_keyshape_rate route_quality_selected_noisy_rate route_quality_retry_raw_proxy_mean route_quality_retry_keyshape_proxy_mean route_quality_retry_noisy_proxy_mean route_quality_retry_raw_delta_mean route_quality_retry_keyshape_delta_mean route_quality_retry_noisy_delta_mean route_quality_selected_raw_qacc route_quality_selected_keyshape_qacc route_quality_selected_noisy_qacc lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing proxy calibration column: " required[i], 2)
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
    delta = metric("route_quality_source_ranking_delta_mean")

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
      die("proxy calibration must not activate jump-neighbor routing: " arm, 6)
    }
    if (!(raw_proxy == raw_proxy && keyshape_proxy == keyshape_proxy &&
          noisy_proxy == noisy_proxy && delta == delta)) {
      die("proxy and delta metrics should be finite: " arm, 7)
    }
    if (selected_noisy > 0.25) {
      die("proxy calibration selected noisy source too often: " arm, 8)
    }

    rows++
    if (arm == "proxy-default") {
      default_seen = 1
      default_qacc = qacc
      default_raw_proxy = raw_proxy
      default_keyshape_proxy = keyshape_proxy
      default_logdet = metric("logdet_weight")
      default_entropy = metric("entropy_weight")
      default_margin = metric("vote_margin_weight")
      default_top = metric("top_share_weight")
      default_channel = metric("channel_weight")
    } else if (arm == "logdet-sign-flip") {
      logdet_seen = (metric("logdet_weight") < 0)
    } else if (arm == "entropy-sign-flip") {
      entropy_seen = (metric("entropy_weight") < 0)
    } else if (arm == "vote-margin-sign-flip") {
      margin_seen = (metric("vote_margin_weight") < 0)
    } else if (arm == "top-share-sign-flip") {
      top_seen = (metric("top_share_weight") < 0)
    } else if (arm == "channel-sign-flip") {
      channel_seen = (metric("channel_weight") < 0)
    } else {
      die("unexpected arm: " arm, 9)
    }
    if (qacc > best_qacc) {
      best_qacc = qacc
      best_arm = arm
    }
    if (arm != "proxy-default" && raw_proxy != default_raw_proxy) {
      proxy_variation_seen = 1
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 10)
    }
    if (!(default_seen && logdet_seen && entropy_seen && margin_seen &&
          top_seen && channel_seen)) {
      die("missing one or more proxy sign-calibration arms", 11)
    }
    if (default_logdet != 0.1 || default_entropy != 0.5 ||
        default_margin != 1.0 || default_top != 1.0 ||
        default_channel != 0.1) {
      die("default proxy weights changed unexpectedly", 12)
    }
    if (default_raw_proxy == default_keyshape_proxy) {
      die("default proxy should expose source separation", 13)
    }
    if (!proxy_variation_seen) {
      die("proxy calibration sweep should change at least one proxy", 14)
    }
    if (best_qacc + 0.10 < default_qacc) {
      die("all calibrated arms regressed too far below default", 15)
    }
  }
' "$SUMMARY_CSV"

echo "route quality proxy calibration smoke passed"
