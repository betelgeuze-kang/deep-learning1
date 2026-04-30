#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_fallback_channel_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_fallback_channel.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_fallback_strength_mult route_fallback_hi_strength_mult route_fallback_lo_strength_mult fixture_query_byte_acc route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean", required, " ")
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
    fallback_strength = $idx["route_fallback_effective_strength_mean"] + 0
    fallback_hi_strength = $idx["route_fallback_hi_effective_strength_mean"] + 0
    fallback_lo_strength = $idx["route_fallback_lo_effective_strength_mean"] + 0

    if (fallback_used <= 0.0 || fallback_recall < 0.99 || fallback_success < 0.99 ||
        fallback_qacc <= 0.0 || fallback_strength <= 0.0) {
      printf "expected populated fallback diagnostics in %s\n", scenario > "/dev/stderr"
      exit 3
    }
    if (scenario == "balanced-m5") {
      balanced_seen = 1
      balanced_hi_strength = fallback_hi_strength
      balanced_lo_strength = fallback_lo_strength
      balanced_hi_acc = fallback_hi_acc
      balanced_lo_acc = fallback_lo_acc
      if (hi_mult < 0.99 || hi_mult > 1.01 || lo_mult < 0.99 || lo_mult > 1.01) {
        printf "unexpected balanced multipliers hi=%f lo=%f\n", hi_mult, lo_mult > "/dev/stderr"
        exit 4
      }
    } else if (scenario == "lo-boost-m5") {
      lo_seen = 1
      lo_hi_strength = fallback_hi_strength
      lo_lo_strength = fallback_lo_strength
      lo_boost_lo_acc = fallback_lo_acc
      if (lo_mult < 1.99 || lo_mult > 2.01 || hi_mult < 0.99 || hi_mult > 1.01) {
        printf "unexpected lo-boost multipliers hi=%f lo=%f\n", hi_mult, lo_mult > "/dev/stderr"
        exit 5
      }
    } else if (scenario == "hi-boost-m5") {
      hi_seen = 1
      hi_hi_strength = fallback_hi_strength
      hi_lo_strength = fallback_lo_strength
      if (hi_mult < 1.99 || hi_mult > 2.01 || lo_mult < 0.99 || lo_mult > 1.01) {
        printf "unexpected hi-boost multipliers hi=%f lo=%f\n", hi_mult, lo_mult > "/dev/stderr"
        exit 6
      }
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 7
    }
  }
  END {
    if (row_count != 3 || !balanced_seen || !lo_seen || !hi_seen) {
      printf "expected three fallback channel rows, got %d\n", row_count > "/dev/stderr"
      exit 8
    }
    if (lo_lo_strength <= balanced_lo_strength || lo_hi_strength < balanced_hi_strength * 0.95) {
      printf "expected lo boost to raise only low-channel effective strength: balanced hi/lo=%f/%f lo hi/lo=%f/%f\n",
        balanced_hi_strength, balanced_lo_strength, lo_hi_strength, lo_lo_strength > "/dev/stderr"
      exit 9
    }
    if (hi_hi_strength <= balanced_hi_strength || hi_lo_strength < balanced_lo_strength * 0.95) {
      printf "expected hi boost to raise only high-channel effective strength: balanced hi/lo=%f/%f hi hi/lo=%f/%f\n",
        balanced_hi_strength, balanced_lo_strength, hi_hi_strength, hi_lo_strength > "/dev/stderr"
      exit 10
    }
    if (balanced_hi_acc <= 0.0 || balanced_lo_acc <= 0.0 || lo_boost_lo_acc <= 0.0) {
      printf "expected non-empty channel accuracy diagnostics\n" > "/dev/stderr"
      exit 11
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code fallback channel smoke passed"
