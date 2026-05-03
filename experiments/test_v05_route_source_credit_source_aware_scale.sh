#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_source_aware_scale_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_source_aware_scale.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  function key_of(key_count, seed, arm) {
    return key_count ":" seed ":" arm
  }
  BEGIN { expected_rows = 24 }
  NR == 1 {
    split("scenario arm fallback_source route_hint_agg source_credit_apply_mode key_count seed qacc decode primary_recall fallback_used fallback_recall fallback_qacc fallback_success correct_vote_share vote_entropy source_gap noisy_mean noisy_slashed noisy_selected selected_fallback strength_mean lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    agg = $idx["route_hint_agg"]
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
    correct_vote_share = metric("correct_vote_share")
    vote_entropy = metric("vote_entropy")
    source_gap = metric("source_gap")
    noisy_mean = metric("noisy_mean")
    noisy_slashed = metric("noisy_slashed")
    noisy_selected = metric("noisy_selected")
    selected_fallback = metric("selected_fallback")
    strength_mean = metric("strength_mean")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (qacc < 0 || qacc > 1 || decode < 0 || decode > 1 ||
        primary_recall < 0 || primary_recall > 1 ||
        fallback_used < 0 || fallback_used > 1 ||
        fallback_recall < 0 || fallback_recall > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 ||
        fallback_success < 0 || fallback_success > 1 ||
        correct_vote_share < 0 || correct_vote_share > 1 ||
        noisy_slashed < 0 || noisy_slashed > 1 ||
        noisy_selected < 0 || noisy_selected > 1 ||
        selected_fallback < 0 || selected_fallback > 1) {
      die("metric out of range: " scenario, 3)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("candidate value_pos/value byte read path should stay populated: " scenario, 4)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("source-aware scale diagnostics must not activate jump-neighbor routing: " scenario, 5)
    }
    if (decode > 0.75) {
      die("weak route-code source should remain weak in scale smoke: " scenario, 6)
    }

    seen_key[key_count] = 1
    seen_seed[seed] = 1
    combo = key_of(key_count, seed, arm)
    rows++

    if (arm == "raw-vote") {
      if (source != "raw-key" || agg != "vote" || apply_mode != "off") {
        die("raw-vote configuration mismatch: " scenario, 7)
      }
      raw_vote_qacc[key_count ":" seed] = qacc
      raw_vote_share[key_count ":" seed] = correct_vote_share
      raw_vote_entropy[key_count ":" seed] = vote_entropy
      raw_vote_seen[key_count ":" seed] = 1
    } else if (arm == "raw-source-aware") {
      if (source != "raw-key" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("raw-source-aware configuration mismatch: " scenario, 8)
      }
      raw_aware_qacc[key_count ":" seed] = qacc
      raw_aware_share[key_count ":" seed] = correct_vote_share
      raw_aware_entropy[key_count ":" seed] = vote_entropy
      raw_aware_gap[key_count ":" seed] = source_gap
      raw_aware_seen[key_count ":" seed] = 1
    } else if (arm == "keyshape-vote") {
      if (source != "key-shape" || agg != "vote" || apply_mode != "off") {
        die("keyshape-vote configuration mismatch: " scenario, 9)
      }
      shape_vote_qacc[key_count ":" seed] = qacc
      shape_vote_share[key_count ":" seed] = correct_vote_share
      shape_vote_entropy[key_count ":" seed] = vote_entropy
      shape_vote_seen[key_count ":" seed] = 1
    } else if (arm == "keyshape-source-aware") {
      if (source != "key-shape" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("keyshape-source-aware configuration mismatch: " scenario, 10)
      }
      shape_aware_qacc[key_count ":" seed] = qacc
      shape_aware_share[key_count ":" seed] = correct_vote_share
      shape_aware_entropy[key_count ":" seed] = vote_entropy
      shape_aware_gap[key_count ":" seed] = source_gap
      shape_aware_seen[key_count ":" seed] = 1
    } else if (arm == "noisy-vote") {
      if (source != "noisy-route-code" || agg != "vote" || apply_mode != "off") {
        die("noisy-vote configuration mismatch: " scenario, 11)
      }
      noisy_vote_qacc[key_count ":" seed] = qacc
      noisy_vote_seen[key_count ":" seed] = 1
    } else if (arm == "noisy-source-aware") {
      if (source != "noisy-route-code" || agg != "weighted-vote" || apply_mode != "ranking-strength") {
        die("noisy-source-aware configuration mismatch: " scenario, 12)
      }
      if (fallback_recall != 0 || source_gap >= 0 || noisy_mean >= 0 ||
          noisy_slashed <= 0 || noisy_selected != 0 || strength_mean > 1.000001) {
        die("noisy source-aware policy should keep bad fallback down-signaled: " scenario, 13)
      }
      noisy_aware_qacc[key_count ":" seed] = qacc
      noisy_aware_seen[key_count ":" seed] = 1
    } else {
      die("unexpected arm: " arm, 14)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 15)
    }
    if (!(seen_key[64] && seen_key[128] && seen_seed[1] && seen_seed[2])) {
      die("expected key_count 64/128 and seed 1/2 in smoke", 16)
    }
    for (key_count_i in seen_key) {
      for (seed_i in seen_seed) {
        k = key_count_i ":" seed_i
        if (!(raw_vote_seen[k] && raw_aware_seen[k] &&
              shape_vote_seen[k] && shape_aware_seen[k] &&
              noisy_vote_seen[k] && noisy_aware_seen[k])) {
          die("missing arm set for key/seed " k, 17)
        }
        if (raw_aware_qacc[k] <= raw_vote_qacc[k] + 0.20 ||
            shape_aware_qacc[k] <= shape_vote_qacc[k] + 0.20) {
          die("source-aware weighted policy should repeatedly improve symbolic fallback vote: " k, 18)
        }
        if (raw_aware_share[k] <= raw_vote_share[k] ||
            shape_aware_share[k] <= shape_vote_share[k] ||
            raw_aware_entropy[k] >= raw_vote_entropy[k] ||
            shape_aware_entropy[k] >= shape_vote_entropy[k]) {
          die("source-aware weighted policy should repeatedly improve support/entropy: " k, 19)
        }
        if (raw_aware_gap[k] <= 0 || shape_aware_gap[k] <= 0) {
          die("symbolic source-aware policy should keep positive source gap: " k, 20)
        }
        if (noisy_aware_qacc[k] > raw_aware_qacc[k] ||
            noisy_aware_qacc[k] > shape_aware_qacc[k]) {
          die("noisy source-aware policy should not masquerade as solved symbolic fallback: " k, 21)
        }
      }
    }
  }
' "$SUMMARY_CSV"

echo "route source credit source-aware scale smoke passed"
