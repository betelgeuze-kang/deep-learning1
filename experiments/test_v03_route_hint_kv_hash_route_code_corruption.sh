#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_corruption_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_corruption.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_corrupt_candidate_rate route_corrupt_confidence fixture_query_byte_acc clean_reference_qacc damage_vs_clean route_candidate_corrupt_rate route_correct_candidate_rate route_wrong_hint_applied_rate route_wrong_hint_strength_mean route_correct_hint_strength_mean route_strength_mean", required, " ")
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        printf "missing column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  {
    row_count++
    scenario = $idx["scenario"]
    if (scenario == "clean-adaptive") {
      clean_qacc = $idx["fixture_query_byte_acc"] + 0
      clean_seen = 1
    } else if (scenario == "corrupt-keep") {
      keep_qacc = $idx["fixture_query_byte_acc"] + 0
      keep_damage = $idx["damage_vs_clean"] + 0
      keep_corrupt = $idx["route_candidate_corrupt_rate"] + 0
      keep_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      keep_correct_strength = $idx["route_correct_hint_strength_mean"] + 0
      keep_seen = 1
    } else if (scenario == "corrupt-lowconf") {
      guard_qacc = $idx["fixture_query_byte_acc"] + 0
      guard_damage = $idx["damage_vs_clean"] + 0
      guard_corrupt = $idx["route_candidate_corrupt_rate"] + 0
      guard_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      guard_correct_strength = $idx["route_correct_hint_strength_mean"] + 0
      guard_seen = 1
    }
  }
  END {
    if (row_count != 3 || !clean_seen || !keep_seen || !guard_seen) {
      printf "expected clean-adaptive/corrupt-keep/corrupt-lowconf rows, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    if (clean_qacc < 0.99) {
      printf "expected clean adaptive solved, qacc=%f\n", clean_qacc > "/dev/stderr"
      exit 4
    }
    if (keep_corrupt < 0.20 || guard_corrupt < 0.20) {
      printf "expected visible corruption, keep=%f guard=%f\n", keep_corrupt, guard_corrupt > "/dev/stderr"
      exit 5
    }
    if (keep_damage <= 0.05) {
      printf "expected keep-confidence corruption to cause damage, damage=%f\n", keep_damage > "/dev/stderr"
      exit 6
    }
    if (guard_damage >= keep_damage) {
      printf "expected low-confidence guard to reduce damage, keep=%f guard=%f\n",
        keep_damage, guard_damage > "/dev/stderr"
      exit 7
    }
    if (guard_wrong_strength >= keep_wrong_strength * 0.50) {
      printf "expected guard wrong strength to be suppressed, keep=%f guard=%f\n",
        keep_wrong_strength, guard_wrong_strength > "/dev/stderr"
      exit 8
    }
    if (guard_correct_strength <= guard_wrong_strength) {
      printf "expected correct hints stronger than wrong hints under guard, correct=%f wrong=%f\n",
        guard_correct_strength, guard_wrong_strength > "/dev/stderr"
      exit 9
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code corruption smoke passed"
