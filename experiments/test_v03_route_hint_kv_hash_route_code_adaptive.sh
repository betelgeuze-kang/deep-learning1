#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_adaptive_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_adaptive.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario route_strength_mode key_count lambda_route lambda_route_base lambda_route_max route_margin_alpha fixture_query_byte_acc route_candidate_recall_rate route_candidate_top1_rate key_region_route_decode_acc route_strength_mean route_strength_p50 route_strength_p90 route_strength_max query_effective_route_margin_mean", required, " ")
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
    if ($idx["scenario"] == "fixed-low") {
      fixed_low_qacc = $idx["fixture_query_byte_acc"] + 0
    } else if ($idx["scenario"] == "fixed-strong") {
      fixed_strong_qacc = $idx["fixture_query_byte_acc"] + 0
      fixed_strong_strength = $idx["route_strength_mean"] + 0
    } else if ($idx["scenario"] == "adaptive-margin") {
      adaptive_seen = 1
      adaptive_qacc = $idx["fixture_query_byte_acc"] + 0
      adaptive_recall = $idx["route_candidate_recall_rate"] + 0
      adaptive_top1 = $idx["route_candidate_top1_rate"] + 0
      adaptive_decode = $idx["key_region_route_decode_acc"] + 0
      adaptive_strength = $idx["route_strength_mean"] + 0
      adaptive_strength_max = $idx["route_strength_max"] + 0
      adaptive_effective = $idx["query_effective_route_margin_mean"] + 0
    }
  }
  END {
    if (row_count != 3 || !adaptive_seen) {
      printf "expected fixed-low/fixed-strong/adaptive-margin rows, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    if (adaptive_recall < 0.99 || adaptive_top1 < 0.99 || adaptive_decode < 0.99) {
      printf "expected solved adaptive retrieval, recall=%f top1=%f decode=%f\n",
        adaptive_recall, adaptive_top1, adaptive_decode > "/dev/stderr"
      exit 4
    }
    if (adaptive_qacc < fixed_low_qacc + 0.20) {
      printf "expected adaptive qacc to improve over fixed-low, fixed=%f adaptive=%f\n",
        fixed_low_qacc, adaptive_qacc > "/dev/stderr"
      exit 5
    }
    if (adaptive_qacc < 0.90 || fixed_strong_qacc < 0.99) {
      printf "expected adaptive near solved and fixed strong solved, adaptive=%f strong=%f\n",
        adaptive_qacc, fixed_strong_qacc > "/dev/stderr"
      exit 6
    }
    if (adaptive_strength <= 0.50 || adaptive_strength >= fixed_strong_strength) {
      printf "expected adaptive mean strength between fixed low and strong, adaptive=%f strong=%f\n",
        adaptive_strength, fixed_strong_strength > "/dev/stderr"
      exit 7
    }
    if (adaptive_strength_max > 10.000001 || adaptive_effective <= 0.0) {
      printf "expected capped positive adaptive margin, max=%f effective=%f\n",
        adaptive_strength_max, adaptive_effective > "/dev/stderr"
      exit 8
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code adaptive smoke passed"
