#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_retry_source_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_retry_source.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 4 }
  NR == 1 {
    split("scenario arm fallback_source retry_source source_filter_mode key_count seed qacc fallback_recall fallback_qacc source_gap noisy_mean noisy_slashed noisy_selected selected_fallback strength_mean source_filter_filtered source_filter_abstain source_retry_used source_retry_success lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        die("missing summary column: " required[i], 2)
      }
    }
    next
  }
  {
    scenario = $idx["scenario"]
    arm = $idx["arm"]
    source = $idx["fallback_source"]
    retry_source = $idx["retry_source"]
    filter_mode = $idx["source_filter_mode"]
    key_count = metric("key_count")
    seed = metric("seed")
    qacc = metric("qacc")
    fallback_recall = metric("fallback_recall")
    fallback_qacc = metric("fallback_qacc")
    source_gap = metric("source_gap")
    noisy_mean = metric("noisy_mean")
    noisy_slashed = metric("noisy_slashed")
    noisy_selected = metric("noisy_selected")
    selected_fallback = metric("selected_fallback")
    strength_mean = metric("strength_mean")
    filtered = metric("source_filter_filtered")
    abstain = metric("source_filter_abstain")
    retry_used = metric("source_retry_used")
    retry_success = metric("source_retry_success")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (key_count != 128 || seed != 1) {
      die("smoke should run key_count=128 seed=1: " scenario, 3)
    }
    if (qacc < 0 || qacc > 1 || fallback_recall < 0 || fallback_recall > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 || noisy_slashed < 0 ||
        noisy_slashed > 1 || noisy_selected < 0 || noisy_selected > 1 ||
        selected_fallback < 0 || selected_fallback > 1 || filtered < 0 ||
        filtered > 1 || abstain < 0 || abstain > 1 || retry_used < 0 ||
        retry_used > 1 || retry_success < 0 || retry_success > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-bearing route path should remain populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("retry-source policy must not activate jump-neighbor routing: " scenario, 6)
    }

    rows++
    if (arm == "noisy-filter") {
      noisy_filter_seen = 1
      if (source != "noisy-route-code" || retry_source != "off" ||
          filter_mode != "negative-credit") {
        die("noisy-filter configuration mismatch: " scenario, 7)
      }
      noisy_filter_qacc = qacc
      noisy_filter_recall = fallback_recall
      noisy_filter_abstain = abstain
      if (source_gap >= 0 || noisy_mean >= 0 || noisy_slashed <= 0 ||
          fallback_recall != 0 || filtered <= 0 || abstain <= 0 ||
          retry_used != 0) {
        die("baseline noisy filter should abstain without recovery: " scenario, 8)
      }
    } else if (arm == "retry-raw") {
      retry_raw_seen = 1
      if (source != "noisy-route-code" || retry_source != "raw-key" ||
          filter_mode != "negative-credit") {
        die("retry-raw configuration mismatch: " scenario, 9)
      }
      retry_raw_qacc = qacc
      retry_raw_recall = fallback_recall
      retry_raw_abstain = abstain
      if (retry_used <= 0 || retry_success <= 0 || fallback_recall <= noisy_filter_recall ||
          qacc <= noisy_filter_qacc || abstain >= noisy_filter_abstain) {
        die("raw retry should recover after noisy-source filtering: " scenario, 10)
      }
    } else if (arm == "retry-keyshape") {
      retry_shape_seen = 1
      if (source != "noisy-route-code" || retry_source != "key-shape" ||
          filter_mode != "negative-credit") {
        die("retry-keyshape configuration mismatch: " scenario, 11)
      }
      if (retry_used <= 0 || retry_success <= 0 || fallback_recall <= noisy_filter_recall ||
          qacc <= noisy_filter_qacc || abstain >= noisy_filter_abstain) {
        die("key-shape retry should recover after noisy-source filtering: " scenario, 12)
      }
    } else if (arm == "retry-unfiltered") {
      retry_unfiltered_seen = 1
      if (source != "noisy-route-code" || retry_source != "raw-key" ||
          filter_mode != "off") {
        die("retry-unfiltered configuration mismatch: " scenario, 13)
      }
      if (retry_used <= 0 || retry_success <= 0 || filtered != 0 || abstain != 0) {
        die("unfiltered retry should add a secondary source without filter counters", 14)
      }
    } else {
      die("unexpected arm: " arm, 15)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 16)
    }
    if (!(noisy_filter_seen && retry_raw_seen && retry_shape_seen && retry_unfiltered_seen)) {
      die("missing one or more retry-source arms", 17)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit retry-source smoke passed"
