#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_dynamics_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_dynamics.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario key_count lambda_route cycles_per_epoch proposal_count route_target_proposals fixture_query_byte_acc fixture_query_hi_acc fixture_query_lo_acc route_candidate_recall_rate route_candidate_top1_rate key_region_route_decode_acc query_route_hint_margin_mean query_local_margin_against_route_mean query_effective_route_margin_mean route_hint_applied_rate route_hint_strength_mean", required, " ")
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        printf "missing column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  { row_count++; last = $0 }
  END {
    if (row_count != 1) {
      printf "expected one dynamics smoke row, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    split(last, row, FS)
    if (row[idx["scenario"]] != "smoke") {
      printf "expected smoke scenario, got %s\n", row[idx["scenario"]] > "/dev/stderr"
      exit 4
    }
    if (row[idx["route_candidate_recall_rate"]] + 0 < 0.99 ||
        row[idx["route_candidate_top1_rate"]] + 0 < 0.99 ||
        row[idx["key_region_route_decode_acc"]] + 0 < 0.99) {
      printf "expected solved retrieval plumbing, recall=%s top1=%s route_decode=%s\n",
        row[idx["route_candidate_recall_rate"]],
        row[idx["route_candidate_top1_rate"]],
        row[idx["key_region_route_decode_acc"]] > "/dev/stderr"
      exit 5
    }
    if (row[idx["fixture_query_hi_acc"]] + 0 < 0.99 ||
        row[idx["fixture_query_lo_acc"]] + 0 < 0.99 ||
        row[idx["fixture_query_byte_acc"]] + 0 < 0.99) {
      printf "expected solved dynamics smoke, qacc=%s hi=%s lo=%s\n",
        row[idx["fixture_query_byte_acc"]],
        row[idx["fixture_query_hi_acc"]],
        row[idx["fixture_query_lo_acc"]] > "/dev/stderr"
      exit 6
    }
    if (row[idx["route_hint_applied_rate"]] + 0 < 0.99 ||
        row[idx["query_route_hint_margin_mean"]] + 0 <= 0.0) {
      printf "expected applied positive route margin, applied=%s margin=%s\n",
        row[idx["route_hint_applied_rate"]],
        row[idx["query_route_hint_margin_mean"]] > "/dev/stderr"
      exit 7
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code dynamics smoke passed"
