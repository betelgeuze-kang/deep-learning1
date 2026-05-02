#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_policy_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_policy.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  BEGIN { expected_rows = 6 }
  NR == 1 {
    split("scenario route_source_credit_learning route_source_credit_apply_mode route_plasticity_ledger fixture_query_byte_acc route_plasticity_ledger_size route_plasticity_ledger_mean_abs_credit route_source_credit_size route_source_credit_gap route_source_credit_apply_active route_source_credit_override_rate route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate route_fallback_used_rate route_fallback_qacc", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) die("missing summary column: " required[i], 2)
    }
    next
  }
  {
    scenario = $idx["scenario"]
    learning = $idx["route_source_credit_learning"] + 0
    mode = $idx["route_source_credit_apply_mode"]
    ledger = $idx["route_plasticity_ledger"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    ledger_size = $idx["route_plasticity_ledger_size"] + 0
    ledger_mean_abs = $idx["route_plasticity_ledger_mean_abs_credit"] + 0
    size = $idx["route_source_credit_size"] + 0
    gap = $idx["route_source_credit_gap"] + 0
    apply_active = $idx["route_source_credit_apply_active"] + 0
    override_rate = $idx["route_source_credit_override_rate"] + 0
    selected_fallback = $idx["route_source_credit_selected_fallback_rate"] + 0
    strength_mean = $idx["route_source_credit_strength_mean"] + 0
    lookup_count = $idx["route_hint_candidate_lookup_count"] + 0
    read_distance = $idx["route_hint_value_read_distance_mean"] + 0
    routing_trigger = $idx["routing_trigger_rate"] + 0
    active_jump = $idx["active_jump_rate"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0

    if (qacc < 0 || qacc > 1 || fallback_used < 0 || fallback_used > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 || apply_active < 0 ||
        apply_active > 1 || override_rate < 0 || override_rate > 1 ||
        selected_fallback < 0 || selected_fallback > 1) {
      die("metric out of range: " scenario, 3)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("expected value-position lookup/read path to be populated: " scenario, 4)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("source-credit policy smoke must not activate jump-neighbor routing: " scenario, 5)
    }

    if (scenario == "source-off-remove") {
      if (learning != 0 || mode != "off" || size != 0 || gap != 0 || apply_active != 0) {
        die("source-off row should keep source credit neutral", 6)
      }
      off_qacc = qacc
      seen_off = 1
    } else if (scenario == "source-learn-only-remove") {
      if (learning != 1 || mode != "off" || !(size > 0 && gap > 0)) {
        die("learn-only row should learn source responsibility without applying it", 7)
      }
      if (apply_active != 0 || override_rate != 0 || strength_mean != 0) {
        die("learn-only row should not apply source credit", 8)
      }
      seen_learn_only = 1
    } else if (scenario == "source-ranking-remove") {
      if (learning != 1 || mode != "ranking" || !(gap > 0 && apply_active > 0)) {
        die("ranking row should apply source credit to candidate ranking", 9)
      }
      if (!(override_rate > 0 || selected_fallback > 0)) {
        die("ranking row should expose a source-credit ranking decision signal", 10)
      }
      ranking_qacc = qacc
      seen_ranking = 1
    } else if (scenario == "source-ranking-strength-remove") {
      if (learning != 1 || mode != "ranking-strength" ||
          !(gap > 0 && apply_active > 0 && strength_mean > 1.0)) {
        die("ranking-strength row should apply source credit to ranking and strength", 11)
      }
      if (qacc + 0.000001 < off_qacc) {
        die("ranking-strength row should not regress below source-off smoke", 12)
      }
      seen_ranking_strength = 1
    } else if (scenario == "source-ledger-ranking-strength-remove") {
      if (learning != 1 || mode != "ranking-strength" || ledger != 1 ||
          !(gap > 0 && apply_active > 0 && strength_mean > 1.0 &&
            ledger_size > 0 && ledger_mean_abs > 0)) {
        die("ledger ranking-strength row should combine source credit and persistent ledger", 13)
      }
      seen_ledger = 1
    } else if (scenario == "source-ranking-preserve") {
      if (learning != 1 || mode != "ranking" || fallback_used > 0.05) {
        die("preserve row should remain a no-fallback guard", 14)
      }
      seen_preserve = 1
    } else {
      die("unexpected scenario: " scenario, 15)
    }
    ++rows
  }
  END {
    if (rows != expected_rows) die("expected " expected_rows " rows, found " rows, 16)
    if (!(seen_off && seen_learn_only && seen_ranking && seen_ranking_strength &&
          seen_ledger && seen_preserve)) {
      die("missing one or more source-credit policy scenarios", 17)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit policy smoke passed"
