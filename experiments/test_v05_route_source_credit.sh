#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  BEGIN { expected_rows = 3 }
  NR == 1 {
    split("scenario route_source_credit_learning fixture_query_byte_acc route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) die("missing summary column: " required[i], 2)
    }
    next
  }
  {
    scenario = $idx["scenario"]
    learning = $idx["route_source_credit_learning"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    size = $idx["route_source_credit_size"] + 0
    primary_mean = $idx["route_source_credit_primary_mean"] + 0
    fallback_mean = $idx["route_source_credit_fallback_mean"] + 0
    gap = $idx["route_source_credit_gap"] + 0
    primary_slashed = $idx["route_source_credit_primary_slashed_rate"] + 0
    fallback_rewarded = $idx["route_source_credit_fallback_rewarded_rate"] + 0
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
        fallback_success < 0 || fallback_success > 1) {
      die("metric out of range: " scenario, 3)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("expected value-position lookup/read path to be populated: " scenario, 4)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("source credit smoke must not activate jump-neighbor routing: " scenario, 5)
    }
    if (scenario == "source-off-remove") {
      if (learning != 0) die("source-off row should disable source credit", 6)
      if (size != 0 || gap != 0 || primary_slashed != 0 || fallback_rewarded != 0) {
        die("source-off row should keep source credit metrics neutral", 7)
      }
      seen_off = 1
    } else if (scenario == "source-on-remove") {
      if (learning != 1) die("source-on-remove should enable source credit", 8)
      if (!(fallback_used > 0 && fallback_recall > 0 && fallback_success > 0)) {
        die("source-on-remove should expose recovered fallback candidates", 9)
      }
      if (!(size > 0 && fallback_mean > primary_mean && gap > 0)) {
        die("expected fallback source credit to exceed primary source credit", 10)
      }
      if (!(primary_slashed > 0 && fallback_rewarded > 0)) {
        die("expected primary slash and fallback reward rates", 11)
      }
      seen_on_remove = 1
    } else if (scenario == "source-on-preserve") {
      if (learning != 1) die("source-on-preserve should enable source credit", 12)
      if (fallback_used > 0.05) {
        die("preserve-correct source row should not rely on fallback source", 13)
      }
      seen_on_preserve = 1
    } else {
      die("unexpected scenario: " scenario, 14)
    }
    ++rows
  }
  END {
    if (rows != expected_rows) die("expected " expected_rows " rows, found " rows, 15)
    if (!(seen_off && seen_on_remove && seen_on_preserve)) {
      die("missing one or more source-credit scenarios", 16)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit smoke passed"
