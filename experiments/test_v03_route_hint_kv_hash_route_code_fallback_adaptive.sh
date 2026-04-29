#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_fallback_adaptive_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_fallback_adaptive.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_fallback_strength_mode route_fallback_strength_mult route_fallback_lambda_base route_fallback_lambda_max route_fallback_margin_alpha fixture_query_byte_acc clean_reference_qacc damage_vs_clean route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_route_margin_mean route_fallback_effective_strength_mean route_fallback_strength_p50 route_fallback_strength_p90 route_fallback_strength_max route_fallback_local_margin_against_route_mean", required, " ")
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
    mode = $idx["route_fallback_strength_mode"]
    mult = $idx["route_fallback_strength_mult"] + 0
    qacc = $idx["fixture_query_byte_acc"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_success = $idx["route_fallback_success_rate"] + 0
    fallback_strength = $idx["route_fallback_effective_strength_mean"] + 0
    fallback_p50 = $idx["route_fallback_strength_p50"] + 0
    fallback_p90 = $idx["route_fallback_strength_p90"] + 0
    fallback_max = $idx["route_fallback_strength_max"] + 0
    fallback_local_margin = $idx["route_fallback_local_margin_against_route_mean"] + 0

    if (fallback_used <= 0.0 || fallback_recall < 0.99 || fallback_success < 0.99) {
      printf "expected fallback candidate recovery in %s, used=%f recall=%f success=%f\n",
        scenario, fallback_used, fallback_recall, fallback_success > "/dev/stderr"
      exit 3
    }
    if (fallback_strength <= 0.0 || fallback_p50 <= 0.0 || fallback_p90 <= 0.0 ||
        fallback_max <= 0.0 || fallback_local_margin <= 0.0 || fallback_qacc <= 0.0) {
      printf "expected populated fallback strength diagnostics in %s\n", scenario > "/dev/stderr"
      exit 4
    }

    if (scenario == "fixed-m1") {
      fixed_m1_seen = 1
      if (mode != "fixed" || mult < 0.99 || mult > 1.01) {
        printf "unexpected fixed-m1 mode=%s mult=%f\n", mode, mult > "/dev/stderr"
        exit 5
      }
      fixed_m1_qacc = qacc
      fixed_m1_fb_qacc = fallback_qacc
      fixed_m1_strength = fallback_strength
    } else if (scenario == "fixed-m10") {
      fixed_m10_seen = 1
      if (mode != "fixed" || mult < 9.99 || mult > 10.01) {
        printf "unexpected fixed-m10 mode=%s mult=%f\n", mode, mult > "/dev/stderr"
        exit 6
      }
      fixed_m10_qacc = qacc
      fixed_m10_fb_qacc = fallback_qacc
      fixed_m10_strength = fallback_strength
    } else if (scenario == "margin-a6") {
      margin_a6_seen = 1
      if (mode != "margin") {
        printf "unexpected margin-a6 mode=%s\n", mode > "/dev/stderr"
        exit 7
      }
      margin_a6_qacc = qacc
      margin_a6_fb_qacc = fallback_qacc
      margin_a6_strength = fallback_strength
    } else if (scenario == "margin-a8") {
      margin_a8_seen = 1
      if (mode != "margin") {
        printf "unexpected margin-a8 mode=%s\n", mode > "/dev/stderr"
        exit 8
      }
      margin_a8_qacc = qacc
      margin_a8_fb_qacc = fallback_qacc
      margin_a8_strength = fallback_strength
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 9
    }
  }
  END {
    if (row_count != 4 || !fixed_m1_seen || !fixed_m10_seen || !margin_a6_seen || !margin_a8_seen) {
      printf "expected four fallback adaptive rows, got %d\n", row_count > "/dev/stderr"
      exit 10
    }
    if (fixed_m10_strength <= fixed_m1_strength || fixed_m10_fb_qacc <= fixed_m1_fb_qacc) {
      printf "expected fixed strong fallback baseline to improve over fixed weak: strength %f->%f fb_qacc %f->%f\n",
        fixed_m1_strength, fixed_m10_strength, fixed_m1_fb_qacc, fixed_m10_fb_qacc > "/dev/stderr"
      exit 11
    }
    if (margin_a6_strength <= fixed_m1_strength || margin_a8_strength <= fixed_m1_strength) {
      printf "expected fallback margin modes to raise strength above fixed-m1: fixed=%f a6=%f a8=%f\n",
        fixed_m1_strength, margin_a6_strength, margin_a8_strength > "/dev/stderr"
      exit 12
    }
    if (margin_a6_strength >= fixed_m10_strength || margin_a8_strength >= fixed_m10_strength) {
      printf "expected fallback margin modes to remain below fixed-m10 strength: m10=%f a6=%f a8=%f\n",
        fixed_m10_strength, margin_a6_strength, margin_a8_strength > "/dev/stderr"
      exit 13
    }
    if (margin_a6_qacc < fixed_m1_qacc - 0.05 || margin_a8_qacc < fixed_m1_qacc - 0.05) {
      printf "expected fallback margin modes not to regress catastrophically: fixed=%f a6=%f a8=%f\n",
        fixed_m1_qacc, margin_a6_qacc, margin_a8_qacc > "/dev/stderr"
      exit 14
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code fallback adaptive smoke passed"
