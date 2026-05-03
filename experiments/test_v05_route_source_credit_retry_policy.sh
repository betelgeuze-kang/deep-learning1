#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_retry_policy_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_retry_policy.sh" --smoke

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
    split("scenario arm fallback_source retry_source retry_policy retry_candidates source_filter_mode key_count seed qacc fallback_recall fallback_qacc source_gap noisy_mean noisy_slashed noisy_selected source_filter_abstain source_retry_used source_retry_success retry_raw_selected retry_keyshape_selected retry_noisy_selected lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    retry_policy = $idx["retry_policy"]
    retry_candidates = $idx["retry_candidates"]
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
    abstain = metric("source_filter_abstain")
    retry_used = metric("source_retry_used")
    retry_success = metric("source_retry_success")
    retry_raw_selected = metric("retry_raw_selected")
    retry_keyshape_selected = metric("retry_keyshape_selected")
    retry_noisy_selected = metric("retry_noisy_selected")
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
        abstain < 0 || abstain > 1 || retry_used < 0 || retry_used > 1 ||
        retry_success < 0 || retry_success > 1 || retry_raw_selected < 0 ||
        retry_raw_selected > 1 || retry_keyshape_selected < 0 ||
        retry_keyshape_selected > 1 || retry_noisy_selected < 0 ||
        retry_noisy_selected > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-bearing route path should remain populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("retry policy must not activate jump-neighbor routing: " scenario, 6)
    }

    rows++
    if (arm == "noisy-filter") {
      noisy_filter_seen = 1
      noisy_filter_qacc = qacc
      noisy_filter_recall = fallback_recall
      noisy_filter_abstain = abstain
      if (source != "noisy-route-code" || retry_source != "off" ||
          retry_policy != "fixed" || filter_mode != "negative-credit") {
        die("noisy-filter configuration mismatch: " scenario, 7)
      }
      if (source_gap >= 0 || noisy_mean >= 0 || noisy_slashed <= 0 ||
          fallback_recall != 0 || retry_used != 0 || abstain <= 0) {
        die("baseline noisy filter should abstain without retry recovery: " scenario, 8)
      }
    } else if (arm == "fixed-raw") {
      fixed_raw_seen = 1
      if (retry_policy != "fixed" || retry_source != "raw-key") {
        die("fixed-raw configuration mismatch: " scenario, 9)
      }
      if (fallback_recall <= noisy_filter_recall || qacc <= noisy_filter_qacc ||
          retry_used <= 0 || retry_success <= 0 || retry_raw_selected <= 0) {
        die("fixed raw retry should recover baseline: " scenario, 10)
      }
    } else if (arm == "fixed-keyshape") {
      fixed_keyshape_seen = 1
      fixed_keyshape_qacc = qacc
      if (retry_policy != "fixed" || retry_source != "key-shape") {
        die("fixed-keyshape configuration mismatch: " scenario, 11)
      }
      if (fallback_recall <= noisy_filter_recall || qacc <= noisy_filter_qacc ||
          retry_used <= 0 || retry_success <= 0 || retry_keyshape_selected <= 0) {
        die("fixed key-shape retry should recover baseline: " scenario, 12)
      }
    } else if (arm == "policy-mixed") {
      policy_mixed_seen = 1
      if (retry_policy != "source-credit" ||
          retry_candidates != "raw-key+key-shape+noisy-route-code") {
        die("policy-mixed configuration mismatch: " scenario, 13)
      }
      if (fallback_recall <= noisy_filter_recall || qacc <= noisy_filter_qacc ||
          retry_used <= 0 || retry_success <= 0 ||
          retry_raw_selected + retry_keyshape_selected <= 0 ||
          retry_noisy_selected > 0.05) {
        die("source-credit retry policy should recover while avoiding noisy selection: " scenario, 14)
      }
    } else if (arm == "policy-raw-noisy") {
      policy_raw_noisy_seen = 1
      if (retry_policy != "source-credit" ||
          retry_candidates != "raw-key+noisy-route-code") {
        die("policy-raw-noisy configuration mismatch: " scenario, 15)
      }
      if (fallback_recall <= noisy_filter_recall || qacc <= noisy_filter_qacc ||
          retry_used <= 0 || retry_success <= 0 ||
          retry_raw_selected <= 0 || retry_noisy_selected > 0.05) {
        die("source-credit retry policy should prefer raw over noisy retry: " scenario, 16)
      }
    } else {
      die("unexpected arm: " arm, 17)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 18)
    }
    if (!(noisy_filter_seen && fixed_raw_seen && fixed_keyshape_seen &&
          policy_mixed_seen && policy_raw_noisy_seen)) {
      die("missing one or more retry policy arms", 19)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit retry-policy smoke passed"
