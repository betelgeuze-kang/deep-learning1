#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_learned_source_scale_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_learned_source_scale.sh" --smoke

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
    split("scenario arm key_count seed route_fallback_source route_source_credit_apply_mode route_plasticity_ledger route_code_key_region_keep_prob route_code_aux_noise_rate fixture_query_byte_acc key_region_route_decode_acc route_key_unique_count route_signature_collision_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", required, " ")
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
    key_count = metric("key_count")
    seed = metric("seed")
    fallback_source = $idx["route_fallback_source"]
    apply_mode = $idx["route_source_credit_apply_mode"]
    ledger = metric("route_plasticity_ledger")
    keep_prob = metric("route_code_key_region_keep_prob")
    aux_noise = metric("route_code_aux_noise_rate")
    qacc = metric("fixture_query_byte_acc")
    decode = metric("key_region_route_decode_acc")
    unique_count = metric("route_key_unique_count")
    collision = metric("route_signature_collision_rate")
    primary_recall = metric("route_primary_recall")
    fallback_used = metric("route_fallback_used_rate")
    fallback_recall = metric("route_fallback_recall")
    fallback_qacc = metric("route_fallback_qacc")
    fallback_success = metric("route_fallback_success_rate")
    credit_size = metric("route_source_credit_size")
    gap = metric("route_source_credit_gap")
    primary_slashed = metric("route_source_credit_primary_slashed_rate")
    fallback_rewarded = metric("route_source_credit_fallback_rewarded_rate")
    selected_fallback = metric("route_source_credit_selected_fallback_rate")
    strength_mean = metric("route_source_credit_strength_mean")
    lookup_count = metric("route_hint_candidate_lookup_count")
    read_distance = metric("route_hint_value_read_distance_mean")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (qacc < 0 || qacc > 1 || decode < 0 || decode > 1 ||
        collision < 0 || collision > 1 || primary_recall < 0 ||
        primary_recall > 1 || fallback_used < 0 || fallback_used > 1 ||
        fallback_recall < 0 || fallback_recall > 1 || fallback_qacc < 0 ||
        fallback_qacc > 1 || fallback_success < 0 || fallback_success > 1 ||
        selected_fallback < 0 || selected_fallback > 1 ||
        primary_slashed < 0 || primary_slashed > 1 ||
        fallback_rewarded < 0 || fallback_rewarded > 1) {
      die("metric out of range: " scenario, 3)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-position lookup/read path should stay populated: " scenario, 4)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("h5-g must not revive jump-neighbor routing: " scenario, 5)
    }

    pair = key_count ":" seed
    keys[key_count] = 1
    seeds[seed] = 1
    rows++

    if (arm == "clean-off") {
      if (fallback_source != "off" || apply_mode != "off" || ledger != 0 ||
          !approx(keep_prob, 1.0) || !approx(aux_noise, 0.0)) {
        die("clean-off arm shape mismatch: " scenario, 6)
      }
      if (decode < 0.95 || primary_recall < 0.95 || qacc < 0.95 ||
          fallback_used != 0) {
        die("clean-off should keep route-code source strong without fallback: " scenario, 7)
      }
      clean_seen[pair] = 1
      clean_decode[pair] = decode
      clean_recall[pair] = primary_recall
      clean_qacc[pair] = qacc
    } else if (arm == "mid-off") {
      if (fallback_source != "off" || apply_mode != "off" || ledger != 0 ||
          !approx(keep_prob, 0.5) || !approx(aux_noise, 0.25)) {
        die("mid-off arm shape mismatch: " scenario, 8)
      }
      mid_seen[pair] = 1
      mid_decode[pair] = decode
      mid_recall[pair] = primary_recall
      mid_qacc[pair] = qacc
    } else if (arm == "weak-off") {
      if (fallback_source != "off" || apply_mode != "off" || ledger != 0 ||
          !approx(keep_prob, 0.25) || !approx(aux_noise, 0.75)) {
        die("weak-off arm shape mismatch: " scenario, 9)
      }
      weak_off_seen[pair] = 1
      weak_decode[pair] = decode
      weak_recall[pair] = primary_recall
      weak_qacc[pair] = qacc
    } else if (arm == "weak-fallback-ledger") {
      if (fallback_source != "key-shape" || apply_mode != "ranking-strength" ||
          ledger != 1 || !approx(keep_prob, 0.25) || !approx(aux_noise, 0.75)) {
        die("weak-fallback-ledger arm shape mismatch: " scenario, 10)
      }
      if (!(credit_size > 0 && gap > 0 && primary_slashed > 0 &&
            fallback_rewarded > 0 && selected_fallback > 0 &&
            fallback_used > 0 && fallback_recall > 0 && strength_mean >= 1.0)) {
        die("weak fallback arm should expose source-credit/fallback response: " scenario, 11)
      }
      weak_fb_seen[pair] = 1
      weak_fb_qacc[pair] = qacc
      weak_fb_recall[pair] = primary_recall
    } else {
      die("unexpected arm: " arm, 12)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 13)
    }
    if (!(keys[64] && keys[128] && seeds[1] && seeds[2])) {
      die("expected key counts 64/128 and seeds 1/2", 14)
    }
    for (pair in clean_seen) {
      if (!(pair in mid_seen) || !(pair in weak_off_seen) || !(pair in weak_fb_seen)) {
        die("missing one or more arms for " pair, 15)
      }
      if (!(mid_decode[pair] <= clean_decode[pair] + 1.0e-6 &&
            weak_decode[pair] <= mid_decode[pair] + 1.0e-6)) {
        die("route-code decode should decline along clean -> mid -> weak for " pair, 16)
      }
      if (!(mid_recall[pair] <= clean_recall[pair] + 1.0e-6 &&
            weak_recall[pair] <= mid_recall[pair] + 1.0e-6)) {
        die("primary recall should decline along clean -> mid -> weak for " pair, 17)
      }
      if (!(weak_fb_qacc[pair] >= weak_qacc[pair] - 1.0e-6)) {
        die("fallback/source-credit arm should not underperform weak fallback-off for " pair, 18)
      }
    }
  }
' "$SUMMARY_CSV"

echo "route source credit learned-source scale smoke passed"
