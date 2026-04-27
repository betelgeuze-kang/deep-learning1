#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_confidence_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_confidence.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_strength_confidence fixture_query_byte_acc damage_vs_clean route_candidate_corrupt_rate route_candidate_conf_correct_mean route_candidate_conf_wrong_mean route_candidate_conf_gap route_value_top_correct_rate route_value_conf_correct_mean route_value_conf_wrong_mean route_value_conf_gap route_wrong_hint_strength_mean route_correct_hint_strength_mean", required, " ")
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
    if (scenario == "corrupt-unscaled") {
      unscaled_seen = 1
      unscaled_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      unscaled_damage = $idx["damage_vs_clean"] + 0
      unscaled_corrupt = $idx["route_candidate_corrupt_rate"] + 0
      value_gap = $idx["route_value_conf_gap"] + 0
      top_value_correct = $idx["route_value_top_correct_rate"] + 0
    } else if (scenario == "corrupt-valueconf") {
      valueconf_seen = 1
      valueconf_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      valueconf_damage = $idx["damage_vs_clean"] + 0
      valueconf_correct_strength = $idx["route_correct_hint_strength_mean"] + 0
    }
  }
  END {
    if (row_count != 3 || !unscaled_seen || !valueconf_seen) {
      printf "expected corrupt-unscaled/corrupt-valueconf rows, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    if (unscaled_corrupt < 0.20) {
      printf "expected visible corruption, got %f\n", unscaled_corrupt > "/dev/stderr"
      exit 4
    }
    if (top_value_correct >= 0.99) {
      printf "expected imperfect top-value correctness under corruption, got %f\n",
        top_value_correct > "/dev/stderr"
      exit 5
    }
    if (value_gap <= 0.0) {
      printf "expected value confidence to distinguish wrong hints in smoke, gap=%f\n",
        value_gap > "/dev/stderr"
      exit 6
    }
    if (valueconf_wrong_strength >= unscaled_wrong_strength) {
      printf "expected value confidence to reduce wrong strength, unscaled=%f valueconf=%f\n",
        unscaled_wrong_strength, valueconf_wrong_strength > "/dev/stderr"
      exit 7
    }
    if (valueconf_correct_strength <= valueconf_wrong_strength) {
      printf "expected correct hints stronger than wrong hints, correct=%f wrong=%f\n",
        valueconf_correct_strength, valueconf_wrong_strength > "/dev/stderr"
      exit 8
    }
    if (valueconf_damage > unscaled_damage + 0.10) {
      printf "expected value confidence not to catastrophically increase damage, unscaled=%f valueconf=%f\n",
        unscaled_damage, valueconf_damage > "/dev/stderr"
      exit 9
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code confidence smoke passed"
