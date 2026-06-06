#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_key_support_ranking.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_key_support_ranking_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_key_support_ranking_smoke_aggregate.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("scenario qacc span_exact span_all_recall span_all_top1 correct_key_share unique_key_count key_entropy top_key_consistency top_key_correct coherent_wrong_top_key route_decode route_signature_collision routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span key-support summary column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    if (scenario == "weak-span-key-support") {
      saw_key_support = 1
      key_support_recall = $idx["span_all_recall"] + 0
    }
    if (scenario == "weak-k16") {
      weak_recall = $idx["span_all_recall"] + 0
      weak_top1 = $idx["span_all_top1"] + 0
      weak_exact = $idx["span_exact"] + 0
    }
    if (scenario == "weak-keyshape") {
      keyshape_top1 = $idx["span_all_top1"] + 0
      keyshape_exact = $idx["span_exact"] + 0
    }
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 6) {
      printf "expected at least 6 span key-support rows, got %d\n", rows > "/dev/stderr"
      exit 3
    }
    if (saw_key_support != 1) {
      printf "missing weak-span-key-support row\n" > "/dev/stderr"
      exit 4
    }
    if (weak_recall < 0.99) {
      printf "expected weak-k16 all-span recall to be restored, got %.6f\n", weak_recall > "/dev/stderr"
      exit 5
    }
    if (key_support_recall < 0.99) {
      printf "expected span-key-support all-span recall to stay restored, got %.6f\n", key_support_recall > "/dev/stderr"
      exit 6
    }
    if (keyshape_top1 + 1e-9 < weak_top1) {
      printf "expected key-shape all-span top1 not below weak-k16: %.6f < %.6f\n", keyshape_top1, weak_top1 > "/dev/stderr"
      exit 7
    }
    if (keyshape_exact + 1e-9 < weak_exact) {
      printf "expected key-shape span exact not below weak-k16: %.6f < %.6f\n", keyshape_exact, weak_exact > "/dev/stderr"
      exit 8
    }
    if (routing != 0.0 || jump != 0.0) {
      printf "jump-neighbor route path should remain inactive: routing=%.6f jump=%.6f\n", routing, jump > "/dev/stderr"
      exit 9
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows weak_all_recall weak_all_top1 span_key_support_all_top1 keyshape_all_top1 span_key_support_qacc_delta span_key_support_span_exact_delta keyshape_span_exact_delta routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span key-support aggregate column: %s\n", required[i] > "/dev/stderr"
        exit 10
      }
    }
    next
  }
  {
    if (($idx["rows"] + 0) < 6) {
      printf "invalid aggregate rows\n" > "/dev/stderr"
      exit 11
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span key-support ranking smoke passed"
