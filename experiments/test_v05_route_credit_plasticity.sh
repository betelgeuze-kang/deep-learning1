#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_credit_plasticity_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_credit_plasticity.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  BEGIN { expected_rows = 4 }
  NR == 1 {
    split("scenario route_credit_learning route_credit_mode route_plasticity_ledger route_credit_learn_after_epoch route_credit_apply_after_epoch fixture_query_byte_acc route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_qacc route_credit_learn_active route_credit_apply_active route_plasticity_ledger_size route_plasticity_ledger_mean_abs_credit route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate route_fallback_used_rate route_fallback_qacc", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) die("missing summary column: " required[i], 2)
    }
    next
  }
  {
    scenario = $idx["scenario"]
    learning = $idx["route_credit_learning"] + 0
    mode = $idx["route_credit_mode"]
    ledger = $idx["route_plasticity_ledger"] + 0
    learn_after = $idx["route_credit_learn_after_epoch"] + 0
    apply_after = $idx["route_credit_apply_after_epoch"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    gap = $idx["route_credit_gap"] + 0
    rewarded = $idx["route_credit_rewarded_rate"] + 0
    slashed = $idx["route_credit_slashed_rate"] + 0
    credit_qacc = $idx["route_credit_qacc"] + 0
    learn_active = $idx["route_credit_learn_active"] + 0
    apply_active = $idx["route_credit_apply_active"] + 0
    ledger_size = $idx["route_plasticity_ledger_size"] + 0
    ledger_mean_abs = $idx["route_plasticity_ledger_mean_abs_credit"] + 0
    lookup_count = $idx["route_hint_candidate_lookup_count"] + 0
    read_distance = $idx["route_hint_value_read_distance_mean"] + 0
    routing_trigger = $idx["routing_trigger_rate"] + 0
    active_jump = $idx["active_jump_rate"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0

    if (learning != 1 || mode != "query-value" || ledger != 1) die("unexpected credit config: " scenario, 3)
    if (qacc < 0 || qacc > 1 || credit_qacc < 0 || credit_qacc > 1 ||
        learn_active < 0 || learn_active > 1 || apply_active < 0 || apply_active > 1) {
      die("metric out of range: " scenario, 4)
    }
    if (gap <= 0 || rewarded <= 0 || slashed <= 0) {
      die("expected positive plasticity credit separation: " scenario, 5)
    }
    if (ledger_size <= 0 || ledger_mean_abs <= 0) {
      die("expected populated plasticity ledger: " scenario, 5)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("expected value-position lookup/read path to be populated: " scenario, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("plasticity smoke must not activate jump-neighbor routing: " scenario, 5)
    }
    if (scenario ~ /remove/ && !(fallback_used > 0 && fallback_qacc > 0)) {
      die("expected remove-correct rows to expose fallback diagnostics: " scenario, 6)
    }
    if (scenario == "immediate-remove") {
      if (learn_after != 0 || apply_after != 0 || learn_active < 0.99 || apply_active < 0.99) {
        die("immediate row should learn/apply throughout", 7)
      }
      seen_immediate = 1
    } else if (scenario == "warmup-apply-remove") {
      if (learn_after != 0 || apply_after != 6 || !(learn_active > apply_active && apply_active > 0)) {
        die("warmup apply row should learn before applying", 8)
      }
      seen_warmup = 1
    } else if (scenario == "delayed-learn-remove") {
      if (learn_after != 3 || apply_after != 6 || !(learn_active > apply_active && apply_active > 0)) {
        die("delayed learn row should activate both gates after warmup", 9)
      }
      seen_delayed = 1
    } else if (scenario == "warmup-apply-preserve") {
      if (learn_after != 0 || apply_after != 6 || !(learn_active > apply_active && apply_active > 0)) {
        die("preserve warmup row should learn before applying", 10)
      }
      seen_preserve = 1
    } else {
      die("unexpected scenario: " scenario, 11)
    }
    ++rows
  }
  END {
    if (rows != expected_rows) die("expected " expected_rows " rows, found " rows, 12)
    if (!(seen_immediate && seen_warmup && seen_delayed && seen_preserve)) {
      die("missing one or more plasticity scenarios", 13)
    }
  }
' "$SUMMARY_CSV"

echo "route credit plasticity smoke passed"
