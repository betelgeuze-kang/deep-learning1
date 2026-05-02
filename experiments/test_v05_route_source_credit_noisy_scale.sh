#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_noisy_scale_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_noisy_scale.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  BEGIN { expected_rows = 12 }
  NR == 1 {
    split("scenario branch key_count seed route_noisy_source_rate route_hash_source route_fallback_source route_source_credit_apply_mode route_plasticity_ledger fixture_query_byte_acc route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_noisy_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_source_credit_noisy_slashed_rate route_noisy_source_used_rate route_noisy_source_selected_rate route_source_credit_apply_active route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) die("missing summary column: " required[i], 2)
    }
    next
  }
  {
    scenario = $idx["scenario"]
    branch = $idx["branch"]
    key_count = $idx["key_count"] + 0
    seed = $idx["seed"] + 0
    noisy_rate = $idx["route_noisy_source_rate"] + 0
    hash_source = $idx["route_hash_source"]
    fallback_source = $idx["route_fallback_source"]
    apply_mode = $idx["route_source_credit_apply_mode"]
    ledger = $idx["route_plasticity_ledger"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    size = $idx["route_source_credit_size"] + 0
    primary_mean = $idx["route_source_credit_primary_mean"] + 0
    fallback_mean = $idx["route_source_credit_fallback_mean"] + 0
    noisy_mean = $idx["route_source_credit_noisy_mean"] + 0
    gap = $idx["route_source_credit_gap"] + 0
    primary_slashed = $idx["route_source_credit_primary_slashed_rate"] + 0
    fallback_rewarded = $idx["route_source_credit_fallback_rewarded_rate"] + 0
    noisy_slashed = $idx["route_source_credit_noisy_slashed_rate"] + 0
    noisy_used = $idx["route_noisy_source_used_rate"] + 0
    noisy_selected = $idx["route_noisy_source_selected_rate"] + 0
    apply_active = $idx["route_source_credit_apply_active"] + 0
    selected_fallback = $idx["route_source_credit_selected_fallback_rate"] + 0
    strength_mean = $idx["route_source_credit_strength_mean"] + 0
    lookup_count = $idx["route_hint_candidate_lookup_count"] + 0
    read_distance = $idx["route_hint_value_read_distance_mean"] + 0
    routing_trigger = $idx["routing_trigger_rate"] + 0
    active_jump = $idx["active_jump_rate"] + 0
    primary_recall = $idx["route_primary_recall"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0

    if (qacc < 0 || qacc > 1 || primary_recall < 0 || primary_recall > 1 ||
        fallback_used < 0 || fallback_used > 1 || fallback_recall < 0 ||
        fallback_recall > 1 || fallback_qacc < 0 || fallback_qacc > 1 ||
        fallback_success < 0 || fallback_success > 1 || selected_fallback < 0 ||
        selected_fallback > 1 || noisy_slashed < 0 || noisy_slashed > 1 ||
        noisy_used < 0 || noisy_used > 1 || noisy_selected < 0 ||
        noisy_selected > 1) {
      die("metric out of range: " scenario, 3)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("expected value-position lookup/read path to be populated: " scenario, 4)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("scale smoke must not activate jump-neighbor routing: " scenario, 5)
    }
    if (apply_mode != "ranking-strength" || ledger != 0 || apply_active <= 0 ||
        strength_mean < 1.0 || size <= 0) {
      die("expected active ranking-strength source-credit policy: " scenario, 6)
    }

    seen_key[key_count] = 1
    seen_seed[seed] = 1

    if (branch == "joint-good") {
      if (hash_source != "joint-code-key" || fallback_source != "key-shape" ||
          noisy_rate != 0 || noisy_used != 0 || noisy_selected != 0 ||
          noisy_slashed != 0 || noisy_mean != 0) {
        die("joint-good rows should use weak joint primary with clean key-shape fallback", 7)
      }
      if (!(gap > 0 && fallback_mean > primary_mean && primary_slashed > 0 &&
            fallback_rewarded > 0 && selected_fallback > 0 &&
            fallback_recall > 0)) {
        die("joint-good source separation should remain positive across scale/seed", 8)
      }
      joint_rows += 1
      joint_gap_sum += gap
    } else if (branch == "noisy-bad") {
      if (hash_source != "route-code-key" || fallback_source != "noisy-route-code" ||
          noisy_rate <= 0 || noisy_used <= 0) {
        die("noisy-bad rows should use explicit noisy route-code source", 9)
      }
      if (!(noisy_mean < 0 && noisy_slashed > 0)) {
        die("noisy-bad source separation should remain negative across scale/seed", 10)
      }
      if (noisy_rate > 0.999 &&
          !(gap < 0 && fallback_mean < primary_mean && fallback_rewarded == 0)) {
        die("fully noisy source should have negative source gap across scale/seed", 11)
      }
      noisy_rows += 1
      noisy_gap_sum += gap
      noisy_slashed_sum += noisy_slashed
      if (noisy_rate > 0.999) {
        high_noise_gap_sum += gap
        high_noise_rows += 1
      }
      seen_noise[noisy_rate] = 1
    } else {
      die("unexpected branch: " branch, 12)
    }
    ++rows
  }
  END {
    if (rows != expected_rows) die("expected " expected_rows " rows, found " rows, 13)
    if (!(seen_key[32] && seen_key[64] && seen_seed[1] && seen_seed[2])) {
      die("expected both smoke key counts and seeds", 14)
    }
    if (!(seen_noise[0.5] && seen_noise[1])) {
      die("expected both noisy-source rates", 15)
    }
    if (joint_rows != 4 || noisy_rows != 8) {
      die("unexpected branch counts", 16)
    }
    if (!(joint_gap_sum / joint_rows > 0 && high_noise_gap_sum / high_noise_rows < 0 &&
          noisy_slashed_sum / noisy_rows > 0)) {
      die("source-quality separation means have wrong sign", 17)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit noisy-scale smoke passed"
