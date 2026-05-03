#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_fallback_ablation_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_fallback_ablation.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function approx(value, target) {
    return value >= target - 1.0e-6 && value <= target + 1.0e-6
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 16 }
  NR == 1 {
    split("scenario arm fallback_source source_credit_apply_mode key_count seed qacc decode primary_recall fallback_used fallback_recall fallback_qacc fallback_success source_gap primary_slashed fallback_rewarded selected_fallback noisy_mean noisy_slashed noisy_used lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    fallback_source = $idx["fallback_source"]
    apply_mode = $idx["source_credit_apply_mode"]
    key_count = metric("key_count")
    seed = metric("seed")
    qacc = metric("qacc")
    decode = metric("decode")
    primary_recall = metric("primary_recall")
    fallback_used = metric("fallback_used")
    fallback_recall = metric("fallback_recall")
    fallback_qacc = metric("fallback_qacc")
    fallback_success = metric("fallback_success")
    source_gap = metric("source_gap")
    primary_slashed = metric("primary_slashed")
    fallback_rewarded = metric("fallback_rewarded")
    selected_fallback = metric("selected_fallback")
    noisy_mean = metric("noisy_mean")
    noisy_slashed = metric("noisy_slashed")
    noisy_used = metric("noisy_used")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if ((key_count != 64 && key_count != 128) || (seed != 1 && seed != 2)) {
      die("smoke should only run key_count=64/128 and seeds 1/2: " scenario, 3)
    }
    if (qacc < 0 || qacc > 1 || decode < 0 || decode > 1 ||
        primary_recall < 0 || primary_recall > 1 ||
        fallback_used < 0 || fallback_used > 1 ||
        fallback_recall < 0 || fallback_recall > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 ||
        fallback_success < 0 || fallback_success > 1 ||
        primary_slashed < 0 || primary_slashed > 1 ||
        fallback_rewarded < 0 || fallback_rewarded > 1 ||
        selected_fallback < 0 || selected_fallback > 1 ||
        noisy_slashed < 0 || noisy_slashed > 1 ||
        noisy_used < 0 || noisy_used > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("candidate value_pos/value byte read path should stay populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("fallback ablation must not activate jump-neighbor routing: " scenario, 6)
    }
    if (decode > 0.75) {
      die("weak route-code source should remain weak: " scenario, 7)
    }

    pair = key_count ":" seed
    rows++

    if (arm == "fallback-off") {
      if (fallback_source != "off") die("fallback-off source mismatch: " scenario, 8)
      if (apply_mode != "off") die("fallback-off apply mode mismatch: " scenario, 9)
      if (fallback_used != 0 || source_gap != 0 || selected_fallback != 0) {
        die("fallback-off should keep fallback/source-credit metrics neutral: " scenario, 10)
      }
      if (noisy_used != 0 || noisy_slashed != 0) {
        die("fallback-off should keep noisy source metrics neutral: " scenario, 10)
      }
      off_seen[pair] = 1
      off_qacc[pair] = qacc
      off_primary[pair] = primary_recall
    } else if (arm == "fallback-raw-key") {
      if (fallback_source != "raw-key") die("raw-key source mismatch: " scenario, 11)
      if (apply_mode != "off") die("raw-key apply mode mismatch: " scenario, 12)
      if (!(fallback_used > 0 && fallback_recall > 0 && fallback_success > 0)) {
        die("raw-key should recover fallback candidates without source credit: " scenario, 13)
      }
      raw_seen[pair] = 1
      raw_qacc[pair] = qacc
      raw_primary[pair] = primary_recall
    } else if (arm == "fallback-key-shape") {
      if (fallback_source != "key-shape") die("key-shape source mismatch: " scenario, 14)
      if (apply_mode != "ranking-strength") die("key-shape apply mode mismatch: " scenario, 15)
      if (!(source_gap > 0 && primary_slashed > 0 && fallback_rewarded > 0 &&
            selected_fallback > 0 && fallback_used > 0)) {
        die("key-shape should populate source-credit and fallback diagnostics: " scenario, 16)
      }
      shape_seen[pair] = 1
      shape_qacc[pair] = qacc
      shape_primary[pair] = primary_recall
    } else if (arm == "fallback-noisy-route-code") {
      if (fallback_source != "noisy-route-code") die("noisy-route-code source mismatch: " scenario, 17)
      if (apply_mode != "ranking-strength") die("noisy-route-code apply mode mismatch: " scenario, 18)
      if (!(source_gap < 0 && primary_slashed > 0 && fallback_used > 0 &&
            noisy_mean < 0 && noisy_slashed > 0 && noisy_used > 0)) {
        die("noisy-route-code should populate source-credit and fallback diagnostics: " scenario, 19)
      }
      noisy_seen[pair] = 1
      noisy_qacc[pair] = qacc
      noisy_primary[pair] = primary_recall
    } else {
      die("unexpected arm: " arm, 20)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 21)
    }
    for (pair in off_seen) {
      if (!(pair in raw_seen) || !(pair in shape_seen) || !(pair in noisy_seen)) {
        die("missing one or more fallback arms for " pair, 22)
      }
      if (raw_primary[pair] != off_primary[pair] ||
          shape_primary[pair] != off_primary[pair] ||
          noisy_primary[pair] != off_primary[pair]) {
        die("fallback source arms should not change primary source recall for " pair, 23)
      }
      if (raw_qacc[pair] < off_qacc[pair] - 1.0e-6) {
        die("raw-key fallback should not underperform fallback-off for " pair, 24)
      }
      if (shape_qacc[pair] < off_qacc[pair] - 1.0e-6) {
        die("key-shape fallback should not underperform fallback-off for " pair, 25)
      }
    }
  }
' "$SUMMARY_CSV"

echo "route source credit fallback ablation smoke passed"
