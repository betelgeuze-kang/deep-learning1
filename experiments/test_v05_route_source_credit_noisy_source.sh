#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_noisy_source_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_noisy_source.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function approx(value, target) {
    return value >= target - 1.0e-6 && value <= target + 1.0e-6
  }
  BEGIN { expected_rows = 8 }
  NR == 1 {
    split("scenario route_hash_source route_fallback_source route_noisy_source_rate route_source_credit_learning route_source_credit_apply_mode route_plasticity_ledger route_corrupt_candidate_rate route_corrupt_preserve_correct fixture_query_byte_acc route_plasticity_ledger_size route_plasticity_ledger_mean_abs_credit route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_noisy_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_source_credit_noisy_slashed_rate route_noisy_source_used_rate route_noisy_source_selected_rate route_source_credit_apply_active route_source_credit_override_rate route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate", required, " ")
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
    hash_source = $idx["route_hash_source"]
    fallback_source = $idx["route_fallback_source"]
    noisy_rate = $idx["route_noisy_source_rate"] + 0
    learning = $idx["route_source_credit_learning"] + 0
    mode = $idx["route_source_credit_apply_mode"]
    ledger = $idx["route_plasticity_ledger"] + 0
    corrupt_rate = $idx["route_corrupt_candidate_rate"] + 0
    preserve_correct = $idx["route_corrupt_preserve_correct"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    ledger_size = $idx["route_plasticity_ledger_size"] + 0
    ledger_abs = $idx["route_plasticity_ledger_mean_abs_credit"] + 0
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
    override_rate = $idx["route_source_credit_override_rate"] + 0
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
        fallback_success < 0 || fallback_success > 1 || override_rate < 0 ||
        override_rate > 1 || selected_fallback < 0 || selected_fallback > 1 ||
        noisy_slashed < 0 || noisy_slashed > 1 || noisy_used < 0 ||
        noisy_used > 1 || noisy_selected < 0 || noisy_selected > 1) {
      die("metric out of range: " scenario, 3)
    }
    if (!approx(corrupt_rate, 0.25) || preserve_correct != 0) {
      die("expected remove-correct corruption at 0.25: " scenario, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("expected value-position lookup/read path to be populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("noisy source smoke must not activate jump-neighbor routing: " scenario, 6)
    }

    if (scenario ~ /^joint-source-/) {
      if (hash_source != "joint-code-key" || fallback_source != "key-shape" ||
          noisy_rate != 0 || noisy_used != 0 || noisy_selected != 0 ||
          noisy_slashed != 0 || noisy_mean != 0) {
        die("joint rows should use weak joint primary with clean key-shape fallback", 7)
      }
    }
    if (scenario ~ /^noisy-source-/) {
      if (hash_source != "route-code-key" || fallback_source != "noisy-route-code" ||
          noisy_rate < 0.999 || !(noisy_used > 0 && noisy_mean < 0 &&
          noisy_slashed > 0)) {
        die("noisy rows should expose a slashed noisy source", 8)
      }
    }

    if (scenario == "joint-source-off-remove") {
      if (learning != 0 || mode != "off" || ledger != 0 ||
          size != 0 || gap != 0 || apply_active != 0 || selected_fallback != 0 ||
          strength_mean != 0 || ledger_size != 0 || ledger_abs != 0 ||
          primary_mean != 0 || fallback_mean != 0 || primary_slashed != 0 ||
          fallback_rewarded != 0) {
        die("joint source-off row should stay neutral", 9)
      }
      seen_joint_off = 1
    } else if (scenario == "joint-source-learn-only-remove") {
      if (learning != 1 || mode != "off" || ledger != 0 ||
          !(size > 0 && gap > 0) || apply_active != 0 ||
          selected_fallback != 0 || strength_mean != 0 ||
          !(fallback_mean > primary_mean) || !(primary_slashed > 0) ||
          !(fallback_rewarded > 0) || ledger_size != 0 || ledger_abs != 0) {
        die("joint learn-only row should accumulate fallback source credit without applying it", 10)
      }
      seen_joint_learn_only = 1
    } else if (scenario == "joint-source-ranking-remove") {
      if (learning != 1 || mode != "ranking" || ledger != 0 ||
          !(size > 0 && gap > 0) || apply_active != 1 ||
          !(selected_fallback > 0) || strength_mean > 1.000001 ||
          !(fallback_mean > primary_mean) || !(primary_slashed > 0) ||
          !(fallback_rewarded > 0) || ledger_size != 0 || ledger_abs != 0) {
        die("joint ranking row should apply source credit and prefer key-shape fallback", 11)
      }
      seen_joint_ranking = 1
    } else if (scenario == "joint-source-ranking-strength-remove") {
      if (learning != 1 || mode != "ranking-strength" || ledger != 0 ||
          !(size > 0 && gap > 0) || apply_active != 1 ||
          !(selected_fallback > 0) || !(strength_mean > 1.0) ||
          !(fallback_mean > primary_mean) || !(primary_slashed > 0) ||
          !(fallback_rewarded > 0) || ledger_size != 0 || ledger_abs != 0) {
        die("joint ranking-strength row should add source weighting without touching the ledger", 12)
      }
      seen_joint_ranking_strength = 1
    } else if (scenario == "joint-source-ledger-ranking-strength-remove") {
      if (learning != 1 || mode != "ranking-strength" || ledger != 1 ||
          !(size > 0 && gap > 0) || apply_active != 1 ||
          !(selected_fallback > 0) || !(strength_mean > 1.0) ||
          !(ledger_size > 0) || !(ledger_abs > 0) ||
          !(fallback_mean > primary_mean) || !(primary_slashed > 0) ||
          !(fallback_rewarded > 0)) {
        die("joint ledger row should combine source credit with persistent state", 13)
      }
      seen_joint_ledger = 1
    } else if (scenario == "noisy-source-learn-only-remove") {
      if (learning != 1 || mode != "off" || ledger != 0 ||
          !(size > 0 && gap < 0) || apply_active != 0 ||
          selected_fallback != 0 || strength_mean != 0 ||
          !(fallback_mean < primary_mean) || fallback_rewarded != 0 ||
          ledger_size != 0 || ledger_abs != 0) {
        die("noisy learn-only row should learn a negative noisy source gap without applying it", 14)
      }
      noisy_learn_qacc = qacc
      seen_noisy_learn = 1
    } else if (scenario == "noisy-source-ranking-remove") {
      if (learning != 1 || mode != "ranking" || ledger != 0 ||
          !(size > 0 && gap < 0) || apply_active != 1 ||
          selected_fallback != 0 || strength_mean > 1.000001 ||
          !(fallback_mean < primary_mean) || fallback_rewarded != 0 ||
          ledger_size != 0 || ledger_abs != 0) {
        die("noisy ranking row should apply a negative noisy source signal", 15)
      }
      if (qacc + 0.000001 < noisy_learn_qacc) {
        die("noisy ranking row should not regress below learn-only smoke", 16)
      }
      seen_noisy_ranking = 1
    } else if (scenario == "noisy-source-ledger-ranking-strength-remove") {
      if (learning != 1 || mode != "ranking-strength" || ledger != 1 ||
          !(size > 0 && gap < 0) || apply_active != 1 ||
          selected_fallback != 0 || strength_mean < 1.0 ||
          !(ledger_size > 0) || !(ledger_abs > 0) ||
          !(fallback_mean < primary_mean) || fallback_rewarded != 0) {
        die("noisy ledger row should combine negative source credit with persistent state", 17)
      }
      seen_noisy_ledger = 1
    } else {
      die("unexpected scenario: " scenario, 18)
    }
    ++rows
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 19)
    }
    if (!(seen_joint_off && seen_joint_learn_only && seen_joint_ranking &&
          seen_joint_ranking_strength && seen_joint_ledger &&
          seen_noisy_learn && seen_noisy_ranking && seen_noisy_ledger)) {
      die("missing one or more noisy-source scenarios", 20)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit noisy-source smoke passed"
