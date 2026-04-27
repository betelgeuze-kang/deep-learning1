#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_agreement_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_agreement.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_strength_confidence route_confidence_power fixture_query_byte_acc damage_vs_clean route_candidate_corrupt_rate route_agreement_conf_correct_mean route_agreement_conf_wrong_mean route_agreement_conf_gap route_agreement_top_correct_rate route_wrong_hint_strength_mean route_correct_hint_strength_mean", required, " ")
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
    conf = $idx["route_strength_confidence"]
    power = $idx["route_confidence_power"] + 0
    if (scenario == "corrupt-unscaled") {
      unscaled_seen = 1
      unscaled_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      unscaled_corrupt = $idx["route_candidate_corrupt_rate"] + 0
    } else if (scenario == "corrupt-valueconf") {
      valueconf_seen = 1
    } else if (scenario == "corrupt-agreement" && conf == "agreement" && power == 1.0) {
      agreement_seen = 1
      agreement_wrong_strength = $idx["route_wrong_hint_strength_mean"] + 0
      agreement_correct_strength = $idx["route_correct_hint_strength_mean"] + 0
      agreement_gap = $idx["route_agreement_conf_gap"] + 0
      agreement_top_correct = $idx["route_agreement_top_correct_rate"] + 0
    } else if (scenario == "corrupt-agreement-p2" && conf == "agreement" && power == 2.0) {
      agreement_p2_seen = 1
    }
  }
  END {
    if (row_count != 5 || !unscaled_seen || !valueconf_seen || !agreement_seen || !agreement_p2_seen) {
      printf "expected clean/unscaled/valueconf/agreement/agreement-p2 rows, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    if (unscaled_corrupt < 0.20) {
      printf "expected visible corruption, got %f\n", unscaled_corrupt > "/dev/stderr"
      exit 4
    }
    if (agreement_gap <= 0.0) {
      printf "expected agreement confidence gap > 0, got %f\n", agreement_gap > "/dev/stderr"
      exit 5
    }
    if (agreement_top_correct >= 0.99) {
      printf "expected imperfect agreement top correctness under corruption, got %f\n",
        agreement_top_correct > "/dev/stderr"
      exit 6
    }
    if (agreement_wrong_strength >= unscaled_wrong_strength) {
      printf "expected agreement confidence to reduce wrong strength, unscaled=%f agreement=%f\n",
        unscaled_wrong_strength, agreement_wrong_strength > "/dev/stderr"
      exit 7
    }
    if (agreement_correct_strength <= agreement_wrong_strength) {
      printf "expected agreement correct strength > wrong strength, correct=%f wrong=%f\n",
        agreement_correct_strength, agreement_wrong_strength > "/dev/stderr"
      exit 8
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code agreement confidence smoke passed"
