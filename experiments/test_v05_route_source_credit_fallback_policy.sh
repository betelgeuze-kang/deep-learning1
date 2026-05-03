#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_fallback_policy_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_fallback_policy.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 32 }
  NR == 1 {
    split("scenario arm fallback_source source_credit_apply_mode source_credit_learning plasticity_ledger key_count seed qacc decode primary_recall fallback_used fallback_recall fallback_qacc fallback_success source_size primary_mean fallback_mean noisy_mean source_gap primary_slashed fallback_rewarded noisy_slashed noisy_used noisy_selected apply_active override_rate selected_fallback strength_mean ledger_size ledger_mean_abs lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    source_learning = metric("source_credit_learning")
    ledger = metric("plasticity_ledger")
    key_count = metric("key_count")
    seed = metric("seed")
    qacc = metric("qacc")
    decode = metric("decode")
    primary_recall = metric("primary_recall")
    fallback_used = metric("fallback_used")
    fallback_recall = metric("fallback_recall")
    fallback_qacc = metric("fallback_qacc")
    fallback_success = metric("fallback_success")
    source_size = metric("source_size")
    primary_mean = metric("primary_mean")
    fallback_mean = metric("fallback_mean")
    noisy_mean = metric("noisy_mean")
    source_gap = metric("source_gap")
    primary_slashed = metric("primary_slashed")
    fallback_rewarded = metric("fallback_rewarded")
    noisy_slashed = metric("noisy_slashed")
    noisy_used = metric("noisy_used")
    noisy_selected = metric("noisy_selected")
    apply_active = metric("apply_active")
    override_rate = metric("override_rate")
    selected_fallback = metric("selected_fallback")
    strength_mean = metric("strength_mean")
    ledger_size = metric("ledger_size")
    ledger_mean_abs = metric("ledger_mean_abs")
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
        noisy_slashed < 0 || noisy_slashed > 1 ||
        noisy_used < 0 || noisy_used > 1 ||
        noisy_selected < 0 || noisy_selected > 1 ||
        apply_active < 0 || apply_active > 1 ||
        override_rate < 0 || override_rate > 1 ||
        selected_fallback < 0 || selected_fallback > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("candidate value_pos/value byte read path should stay populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("fallback policy smoke must not activate jump-neighbor routing: " scenario, 6)
    }
    if (decode > 0.75) {
      die("weak route-code source should remain weak: " scenario, 7)
    }

    pair = key_count ":" seed
    rows++

    if (arm == "off-control") {
      if (fallback_source != "off" || apply_mode != "off" ||
          source_learning != 0 || ledger != 0 || fallback_used != 0 ||
          source_size != 0 || source_gap != 0 || apply_active != 0 ||
          selected_fallback != 0 || ledger_size != 0 || ledger_mean_abs != 0) {
        die("off-control should keep fallback/source-credit metrics neutral: " scenario, 8)
      }
      off_seen[pair] = 1
      off_recall[pair] = fallback_recall
      off_success[pair] = fallback_success
      off_qacc[pair] = qacc
      off_primary[pair] = primary_recall
    } else if (arm == "raw-key-ceiling") {
      if (fallback_source != "raw-key" || apply_mode != "off" ||
          source_learning != 0 || ledger != 0) {
        die("raw-key-ceiling configuration mismatch: " scenario, 9)
      }
      if (!(fallback_used > 0 && fallback_recall > 0 && fallback_success > 0)) {
        die("raw-key-ceiling should recover symbolic fallback candidates: " scenario, 10)
      }
      raw_off_seen[pair] = 1
      raw_off_recall[pair] = fallback_recall
      raw_off_success[pair] = fallback_success
      raw_off_qacc[pair] = qacc
      raw_primary[pair] = primary_recall
    } else if (arm == "key-shape-learn-only") {
      if (fallback_source != "key-shape" || apply_mode != "off" ||
          source_learning != 1 || ledger != 0) {
        die("key-shape-learn-only configuration mismatch: " scenario, 11)
      }
      if (!(source_size > 0 && source_gap > 0 && primary_slashed > 0 &&
            fallback_rewarded > 0 && fallback_used > 0 && fallback_recall > 0 &&
            apply_active == 0 && selected_fallback == 0 &&
            ledger_size == 0 && ledger_mean_abs == 0)) {
        die("key-shape-learn-only should learn source-credit diagnostics without applying them: " scenario, 12)
      }
      shape_learn_seen[pair] = 1
      shape_learn_qacc[pair] = qacc
      shape_learn_primary[pair] = primary_recall
    } else if (arm == "key-shape-ranking") {
      if (fallback_source != "key-shape" || apply_mode != "ranking" ||
          source_learning != 1 || ledger != 0) {
        die("key-shape-ranking configuration mismatch: " scenario, 13)
      }
      if (!(source_size > 0 && source_gap > 0 && primary_slashed > 0 &&
            fallback_rewarded > 0 && selected_fallback > 0 &&
            apply_active > 0 && ledger_size == 0 && ledger_mean_abs == 0)) {
        die("key-shape-ranking should expose ranking policy diagnostics: " scenario, 14)
      }
      shape_ranking_seen[pair] = 1
      shape_ranking_qacc[pair] = qacc
      shape_ranking_primary[pair] = primary_recall
    } else if (arm == "key-shape-strength") {
      if (fallback_source != "key-shape" || apply_mode != "strength" ||
          source_learning != 1 || ledger != 0) {
        die("key-shape-strength configuration mismatch: " scenario, 15)
      }
      if (!(source_size > 0 && source_gap > 0 && primary_slashed > 0 &&
            fallback_rewarded > 0 && selected_fallback == 0 &&
            apply_active > 0 && strength_mean > 1.0 &&
            ledger_size == 0 && ledger_mean_abs == 0)) {
        die("key-shape-strength should expose strength-only policy diagnostics: " scenario, 16)
      }
      shape_strength_seen[pair] = 1
      shape_strength_qacc[pair] = qacc
      shape_strength_primary[pair] = primary_recall
    } else if (arm == "key-shape-ranking-strength") {
      if (fallback_source != "key-shape" || apply_mode != "ranking-strength" ||
          source_learning != 1 || ledger != 0) {
        die("key-shape-ranking-strength configuration mismatch: " scenario, 17)
      }
      if (!(source_size > 0 && source_gap > 0 && primary_slashed > 0 &&
            fallback_rewarded > 0 && selected_fallback > 0 &&
            apply_active > 0 && strength_mean > 1.0 &&
            ledger_size == 0 && ledger_mean_abs == 0)) {
        die("key-shape-ranking-strength should expose ranking plus strength diagnostics: " scenario, 18)
      }
      shape_policy_seen[pair] = 1
      shape_policy_qacc[pair] = qacc
      shape_policy_primary[pair] = primary_recall
    } else if (arm == "noisy-learn-only") {
      if (fallback_source != "noisy-route-code" || apply_mode != "off" ||
          source_learning != 1 || ledger != 0) {
        die("noisy-learn-only configuration mismatch: " scenario, 19)
      }
      if (!(source_size > 0 && source_gap < 0 && noisy_mean < 0 &&
            noisy_slashed > 0 && noisy_used > 0 && apply_active == 0 &&
            selected_fallback == 0 && fallback_rewarded == 0)) {
        die("noisy-learn-only should learn a negative noisy fallback signal without applying it: " scenario, 20)
      }
      noisy_off_seen[pair] = 1
      noisy_off_qacc[pair] = qacc
      noisy_off_primary[pair] = primary_recall
    } else if (arm == "noisy-ranking-strength") {
      if (fallback_source != "noisy-route-code" || apply_mode != "ranking-strength" ||
          source_learning != 1 || ledger != 0) {
        die("noisy-ranking-strength configuration mismatch: " scenario, 21)
      }
      if (!(source_size > 0 && source_gap < 0 && noisy_mean < 0 &&
            noisy_slashed > 0 && noisy_used > 0 && noisy_selected == 0 &&
            apply_active > 0 &&
            strength_mean <= 1.000001 && ledger_size == 0 && ledger_mean_abs == 0)) {
        die("noisy-ranking-strength should expose a slashed noisy source without masquerading as solved: " scenario, 22)
      }
      noisy_policy_seen[pair] = 1
      noisy_policy_qacc[pair] = qacc
      noisy_policy_primary[pair] = primary_recall
    } else {
      die("unexpected arm: " arm, 23)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 24)
    }
    for (pair in off_seen) {
      if (!(pair in raw_off_seen) || !(pair in shape_learn_seen) ||
          !(pair in shape_ranking_seen) || !(pair in shape_strength_seen) ||
          !(pair in shape_policy_seen) ||
          !(pair in noisy_off_seen) || !(pair in noisy_policy_seen)) {
        die("missing one or more fallback policy arms for " pair, 25)
      }
      if (raw_off_recall[pair] <= off_recall[pair] ||
          raw_off_success[pair] <= off_success[pair]) {
        die("raw-key symbolic fallback should recover recall/success relative to fallback-off for " pair, 26)
      }
      if (raw_off_qacc[pair] + 1.0e-6 < off_qacc[pair] ||
          shape_learn_qacc[pair] + 1.0e-6 < off_qacc[pair] ||
          shape_ranking_qacc[pair] + 1.0e-6 < off_qacc[pair] ||
          shape_strength_qacc[pair] + 1.0e-6 < off_qacc[pair] ||
          shape_policy_qacc[pair] + 1.0e-6 < off_qacc[pair]) {
        die("symbolic fallback arms should preserve fallback-off qacc caveats for " pair, 27)
      }
      if (noisy_policy_qacc[pair] > raw_off_qacc[pair] + 1.0e-6 ||
          noisy_policy_qacc[pair] > shape_policy_qacc[pair] + 1.0e-6) {
        die("noisy fallback policy should not masquerade as solved for " pair, 28)
      }
      if (raw_primary[pair] != off_primary[pair] ||
          shape_learn_primary[pair] != off_primary[pair] ||
          shape_ranking_primary[pair] != off_primary[pair] ||
          shape_strength_primary[pair] != off_primary[pair] ||
          shape_policy_primary[pair] != off_primary[pair] ||
          noisy_off_primary[pair] != off_primary[pair] ||
          noisy_policy_primary[pair] != off_primary[pair]) {
        die("fallback policy arms should not change primary source recall for " pair, 29)
      }
    }
  }
' "$SUMMARY_CSV"

echo "route source credit fallback policy smoke passed"
