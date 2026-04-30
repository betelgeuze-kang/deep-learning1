#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_fallback_low_grid_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_fallback_low_grid.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_fallback_hi_strength_mult route_fallback_lo_strength_mult fixture_query_byte_acc route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean", required, " ")
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
    hi_mult = $idx["route_fallback_hi_strength_mult"] + 0
    lo_mult = $idx["route_fallback_lo_strength_mult"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_hi_acc = $idx["route_fallback_hi_acc"] + 0
    fallback_lo_acc = $idx["route_fallback_lo_acc"] + 0
    hi_strength = $idx["route_fallback_hi_effective_strength_mean"] + 0
    lo_strength = $idx["route_fallback_lo_effective_strength_mean"] + 0

    if (hi_mult < 4.99 || hi_mult > 5.01) {
      printf "expected fixed hi multiplier 5.0 in %s, got %f\n", scenario, hi_mult > "/dev/stderr"
      exit 3
    }
    if (fallback_used <= 0.0 || fallback_recall < 0.99 || fallback_success < 0.99 ||
        fallback_qacc <= 0.0 || fallback_hi_acc <= 0.0 || fallback_lo_acc <= 0.0) {
      printf "expected populated fallback grid diagnostics in %s\n", scenario > "/dev/stderr"
      exit 4
    }

    if (scenario == "lo5") {
      lo5_seen = 1
      lo5_strength = lo_strength
      lo5_qacc = fallback_qacc
    } else if (scenario == "lo7p5") {
      lo75_seen = 1
      lo75_strength = lo_strength
    } else if (scenario == "lo10") {
      lo10_seen = 1
      lo10_strength = lo_strength
      lo10_qacc = fallback_qacc
    } else if (scenario == "lo15") {
      lo15_seen = 1
      lo15_strength = lo_strength
      lo15_qacc = fallback_qacc
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 5
    }
  }
  END {
    if (row_count != 4 || !lo5_seen || !lo75_seen || !lo10_seen || !lo15_seen) {
      printf "expected four low-grid rows, got %d\n", row_count > "/dev/stderr"
      exit 6
    }
    if (!(lo5_strength < lo75_strength && lo75_strength < lo10_strength && lo10_strength < lo15_strength)) {
      printf "expected low-channel effective strength to increase monotonically: %f %f %f %f\n",
        lo5_strength, lo75_strength, lo10_strength, lo15_strength > "/dev/stderr"
      exit 7
    }
    if (lo10_qacc < lo5_qacc - 0.05 && lo15_qacc < lo5_qacc - 0.05) {
      printf "expected at least one stronger low-grid point not to catastrophically regress: lo5=%f lo10=%f lo15=%f\n",
        lo5_qacc, lo10_qacc, lo15_qacc > "/dev/stderr"
      exit 8
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code fallback low-grid smoke passed"
