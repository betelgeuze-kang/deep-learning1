#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_fallback_channel_adaptive_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel_adaptive.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_fallback_channel_strength_mode route_fallback_hi_margin_alpha route_fallback_lo_margin_alpha route_fallback_hi_lambda_max route_fallback_lo_lambda_max fixture_query_byte_acc route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean route_fallback_hi_local_margin_against_route_mean route_fallback_lo_local_margin_against_route_mean", required, " ")
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
    mode = $idx["route_fallback_channel_strength_mode"]
    hi_alpha = $idx["route_fallback_hi_margin_alpha"] + 0
    lo_alpha = $idx["route_fallback_lo_margin_alpha"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_hi_strength = $idx["route_fallback_hi_effective_strength_mean"] + 0
    fallback_lo_strength = $idx["route_fallback_lo_effective_strength_mean"] + 0
    fallback_hi_margin = $idx["route_fallback_hi_local_margin_against_route_mean"] + 0
    fallback_lo_margin = $idx["route_fallback_lo_local_margin_against_route_mean"] + 0

    if (fallback_used <= 0.0 || fallback_recall < 0.99 || fallback_success < 0.99 ||
        fallback_qacc <= 0.0 || fallback_hi_strength <= 0.0 || fallback_lo_strength <= 0.0) {
      printf "expected populated fallback channel-adaptive diagnostics in %s\n", scenario > "/dev/stderr"
      exit 3
    }
    if (fallback_lo_margin <= fallback_hi_margin) {
      printf "expected low-channel local margin to exceed high-channel margin in %s: hi=%f lo=%f\n",
        scenario, fallback_hi_margin, fallback_lo_margin > "/dev/stderr"
      exit 4
    }

    if (scenario == "fixed-lo-boost") {
      fixed_seen = 1
      if (mode != "fixed") {
        printf "unexpected fixed mode: %s\n", mode > "/dev/stderr"
        exit 5
      }
      fixed_qacc = fallback_qacc
    } else if (scenario == "margin-balanced") {
      balanced_seen = 1
      if (mode != "margin" || hi_alpha < 5.99 || hi_alpha > 6.01 || lo_alpha < 5.99 || lo_alpha > 6.01) {
        printf "unexpected margin-balanced mode/alphas: %s %f %f\n", mode, hi_alpha, lo_alpha > "/dev/stderr"
        exit 6
      }
      balanced_hi_strength = fallback_hi_strength
      balanced_lo_strength = fallback_lo_strength
      balanced_qacc = fallback_qacc
    } else if (scenario == "margin-lo-biased") {
      lo_seen = 1
      if (mode != "margin" || hi_alpha < 5.99 || hi_alpha > 6.01 || lo_alpha < 9.99 || lo_alpha > 10.01) {
        printf "unexpected margin-lo-biased mode/alphas: %s %f %f\n", mode, hi_alpha, lo_alpha > "/dev/stderr"
        exit 7
      }
      lo_hi_strength = fallback_hi_strength
      lo_lo_strength = fallback_lo_strength
      lo_qacc = fallback_qacc
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 8
    }
  }
  END {
    if (row_count != 3 || !fixed_seen || !balanced_seen || !lo_seen) {
      printf "expected three fallback channel-adaptive rows, got %d\n", row_count > "/dev/stderr"
      exit 9
    }
    if (lo_lo_strength <= balanced_lo_strength || lo_hi_strength < balanced_hi_strength * 0.95) {
      printf "expected lo-biased margin to raise low-channel strength while preserving high-channel strength: balanced hi/lo=%f/%f lo hi/lo=%f/%f\n",
        balanced_hi_strength, balanced_lo_strength, lo_hi_strength, lo_lo_strength > "/dev/stderr"
      exit 10
    }
    if (lo_qacc < balanced_qacc) {
      printf "expected lo-biased margin not to regress fallback qacc: balanced=%f lo=%f\n",
        balanced_qacc, lo_qacc > "/dev/stderr"
      exit 11
    }
    if (balanced_qacc < 0.0 || lo_qacc < 0.0 || fixed_qacc < 0.0) {
      printf "expected valid qacc values\n" > "/dev/stderr"
      exit 12
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code fallback channel-adaptive smoke passed"
