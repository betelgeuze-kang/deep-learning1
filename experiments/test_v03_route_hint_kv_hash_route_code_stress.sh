#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_stress_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_stress.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("scenario key_count hash_bits K_route eta_route_code key_region_only filler fixture_query_byte_acc route_candidate_recall_rate route_candidate_top1_rate key_region_route_decode_acc route_key_unique_count route_signature_collision_rate route_vs_raw_candidate_overlap_rate", required, " ")
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
      printf "expected one smoke summary row, got %d\n", row_count > "/dev/stderr"
      exit 3
    }
    split(last, row, FS)
    if (row[idx["scenario"]] != "smoke") {
      printf "expected smoke scenario, got %s\n", row[idx["scenario"]] > "/dev/stderr"
      exit 4
    }
    if (row[idx["fixture_query_byte_acc"]] + 0 < 0.99 ||
        row[idx["route_candidate_recall_rate"]] + 0 < 0.99 ||
        row[idx["route_candidate_top1_rate"]] + 0 < 0.99) {
      printf "expected solved smoke, qacc=%s recall=%s top1=%s\n",
        row[idx["fixture_query_byte_acc"]],
        row[idx["route_candidate_recall_rate"]],
        row[idx["route_candidate_top1_rate"]] > "/dev/stderr"
      exit 5
    }
    if (row[idx["key_region_route_decode_acc"]] + 0 < 0.99) {
      printf "expected route decode near one, got %s\n",
        row[idx["key_region_route_decode_acc"]] > "/dev/stderr"
      exit 6
    }
    if (row[idx["route_signature_collision_rate"]] + 0 > 0.01) {
      printf "expected route collision near zero, got %s\n",
        row[idx["route_signature_collision_rate"]] > "/dev/stderr"
      exit 7
    }
    if (row[idx["route_vs_raw_candidate_overlap_rate"]] + 0 < 0.99) {
      printf "expected route/raw overlap near one, got %s\n",
        row[idx["route_vs_raw_candidate_overlap_rate"]] > "/dev/stderr"
      exit 8
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code stress smoke passed"
