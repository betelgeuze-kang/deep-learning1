#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v03_route_hint_kv_hash_route_code_fallback_persistence_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_hash_route_code_fallback_persistence.sh" --smoke

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    split("scenario route_fallback_lo_strength_mult route_fallback_persist_cycles fixture_query_byte_acc route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_hi_acc route_fallback_lo_acc route_fallback_persist_used_rate route_fallback_persist_cycles_mean", required, " ")
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
    lo_mult = $idx["route_fallback_lo_strength_mult"] + 0
    ttl = $idx["route_fallback_persist_cycles"] + 0
    fallback_used = $idx["route_fallback_used_rate"] + 0
    fallback_recall = $idx["route_fallback_recall"] + 0
    fallback_qacc = $idx["route_fallback_qacc"] + 0
    fallback_hi_acc = $idx["route_fallback_hi_acc"] + 0
    fallback_lo_acc = $idx["route_fallback_lo_acc"] + 0
    persist_used = $idx["route_fallback_persist_used_rate"] + 0
    persist_cycles = $idx["route_fallback_persist_cycles_mean"] + 0

    if (fallback_used <= 0.0 || fallback_recall < 0.99 ||
        fallback_qacc <= 0.0 || fallback_hi_acc <= 0.0 || fallback_lo_acc <= 0.0) {
      printf "expected populated fallback persistence diagnostics in %s\n", scenario > "/dev/stderr"
      exit 3
    }
    if (ttl == 0 && (persist_used != 0.0 || persist_cycles != 0.0)) {
      printf "expected zero persistence metrics for ttl=0 in %s, got used=%f cycles=%f\n",
        scenario, persist_used, persist_cycles > "/dev/stderr"
      exit 4
    }
    if (ttl > 0 && (persist_used <= 0.0 || persist_cycles <= 0.0)) {
      printf "expected positive persistence metrics for ttl=%d in %s, got used=%f cycles=%f\n",
        ttl, scenario, persist_used, persist_cycles > "/dev/stderr"
      exit 5
    }

    if (scenario == "lo7p5_ttl0") {
      lo75_ttl0_seen = 1
      lo75_ttl0_qacc = fallback_qacc
    } else if (scenario == "lo7p5_ttl3") {
      lo75_ttl3_seen = 1
      lo75_ttl3_qacc = fallback_qacc
    } else if (scenario == "lo10_ttl0") {
      lo10_ttl0_seen = 1
      lo10_ttl0_qacc = fallback_qacc
    } else if (scenario == "lo10_ttl3") {
      lo10_ttl3_seen = 1
      lo10_ttl3_qacc = fallback_qacc
    } else {
      printf "unexpected scenario: %s\n", scenario > "/dev/stderr"
      exit 6
    }
  }
  END {
    if (row_count != 4 || !lo75_ttl0_seen || !lo75_ttl3_seen ||
        !lo10_ttl0_seen || !lo10_ttl3_seen) {
      printf "expected four fallback persistence rows, got %d\n", row_count > "/dev/stderr"
      exit 7
    }
    if (lo75_ttl3_qacc < lo75_ttl0_qacc - 0.20 &&
        lo10_ttl3_qacc < lo10_ttl0_qacc - 0.20) {
      printf "expected ttl=3 not to catastrophically regress both low-strength baselines: lo7.5 %f -> %f, lo10 %f -> %f\n",
        lo75_ttl0_qacc, lo75_ttl3_qacc, lo10_ttl0_qacc, lo10_ttl3_qacc > "/dev/stderr"
      exit 8
    }
  }
' "$SUMMARY_CSV"

echo "route hint kv hash route-code fallback persistence smoke passed"
