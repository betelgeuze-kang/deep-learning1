#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_learned_source_stress_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_learned_source_stress.sh" --smoke

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
  BEGIN { expected_rows = 8 }
  NR == 1 {
    split("scenario branch key_count seed route_hash_source route_fallback_source route_code_key_region_keep_prob route_code_aux_noise_rate eta_route_code lambda_route_code_id route_noisy_source_rate fixture_query_byte_acc key_region_route_decode_acc route_key_unique_count route_signature_collision_rate route_bucket_collision_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", required, " ")
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
    branch = $idx["branch"]
    key_count = metric("key_count")
    seed = metric("seed")
    hash_source = $idx["route_hash_source"]
    fallback_source = $idx["route_fallback_source"]
    keep_prob = metric("route_code_key_region_keep_prob")
    aux_noise_rate = metric("route_code_aux_noise_rate")
    noisy_rate = metric("route_noisy_source_rate")
    qacc = metric("fixture_query_byte_acc")
    decode = metric("key_region_route_decode_acc")
    unique_count = metric("route_key_unique_count")
    collision = metric("route_signature_collision_rate")
    bucket_collision = metric("route_bucket_collision_rate")
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
        collision < 0 || collision > 1 || bucket_collision < 0 ||
        bucket_collision > 1 || primary_recall < 0 || primary_recall > 1 ||
        fallback_used < 0 || fallback_used > 1 || fallback_recall < 0 ||
        fallback_recall > 1 || fallback_qacc < 0 || fallback_qacc > 1 ||
        fallback_success < 0 || fallback_success > 1 ||
        selected_fallback < 0 || selected_fallback > 1 ||
        primary_slashed < 0 || primary_slashed > 1 ||
        fallback_rewarded < 0 || fallback_rewarded > 1) {
      die("metric out of range: " scenario, 3)
    }
    if (hash_source != "route-code-key" || fallback_source != "key-shape" ||
        noisy_rate != 0.0) {
      die("h5-f smoke should isolate weakened route-code-key with key-shape fallback: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-position lookup/read path should stay populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("h5-f must not revive jump-neighbor routing: " scenario, 6)
    }
    if (credit_size <= 0 || strength_mean < 1.0) {
      die("source-credit policy should be active: " scenario, 7)
    }

    pair = key_count ":" seed
    if (branch == "clean") {
      if (!approx(keep_prob, 1.0) || !approx(aux_noise_rate, 0.0)) {
        die("clean branch should keep full route-code identity supervision: " scenario, 8)
      }
      clean_seen[pair] = 1
      clean_decode[pair] = decode
      clean_unique[pair] = unique_count
      clean_collision[pair] = collision
      clean_primary[pair] = primary_recall
      clean_qacc[pair] = qacc
      if (decode < 0.95 || primary_recall < 0.95 || qacc < 0.95) {
        die("clean route-code branch should remain a strong reference: " scenario, 9)
      }
    } else if (branch == "weak") {
      if (!approx(keep_prob, 0.25) || !approx(aux_noise_rate, 0.75)) {
        die("weak branch should reduce keep probability and add aux noise: " scenario, 10)
      }
      weak_seen[pair] = 1
      weak_decode[pair] = decode
      weak_unique[pair] = unique_count
      weak_collision[pair] = collision
      weak_primary[pair] = primary_recall
      weak_gap[pair] = gap
      weak_primary_slashed[pair] = primary_slashed
      weak_fallback_rewarded[pair] = fallback_rewarded
      weak_selected_fallback[pair] = selected_fallback
      if (!(gap > 0 && primary_slashed > 0 && fallback_rewarded > 0 &&
            selected_fallback > 0 && fallback_used > 0)) {
        die("weak branch should expose fallback/source-credit detection: " scenario, 11)
      }
    } else {
      die("unexpected branch: " branch, 12)
    }
    keys[key_count] = 1
    seeds[seed] = 1
    rows++
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 13)
    }
    if (!(keys[32] && keys[64] && seeds[1] && seeds[2])) {
      die("expected key counts 32/64 and seeds 1/2", 14)
    }
    for (pair in clean_seen) {
      if (!(pair in weak_seen)) {
        die("missing weak pair for " pair, 15)
      }
      if (!(weak_decode[pair] < clean_decode[pair] ||
            weak_unique[pair] < clean_unique[pair] ||
            weak_collision[pair] > clean_collision[pair] ||
            weak_primary[pair] < clean_primary[pair])) {
        die("weak branch should degrade route-code source quality for " pair, 16)
      }
    }
  }
' "$SUMMARY_CSV"

echo "route source credit learned-source stress smoke passed"
