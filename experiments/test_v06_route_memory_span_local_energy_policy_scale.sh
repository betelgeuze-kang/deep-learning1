#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_policy_scale.sh" --smoke

POLICY_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_policy_scale_smoke_policy.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_policy_scale_smoke_aggregate.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("key_count seed objective selected_scenario qacc span_exact qacc_delta_vs_weak span_exact_delta_vs_weak qacc_delta_vs_local_energy span_exact_delta_vs_local_energy", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy policy-scale policy column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  {
    rows++
    objective = $idx["objective"]
    selected[objective] = $idx["selected_scenario"]
    qacc[objective] = $idx["qacc"] + 0
    span_exact[objective] = $idx["span_exact"] + 0
  }
  END {
    if (rows < 3 || !("byte-qacc" in selected) ||
        !("span-exact" in selected) || !("balanced" in selected)) {
      printf "expected byte-qacc/span-exact/balanced policy-scale rows\n" > "/dev/stderr"
      exit 3
    }
    if (selected["byte-qacc"] != "local-energy") {
      printf "expected smoke byte-qacc policy to select local-energy, got %s\n",
        selected["byte-qacc"] > "/dev/stderr"
      exit 4
    }
    if (selected["span-exact"] != "local-energy-hybrid") {
      printf "expected smoke span policy to select local-energy-hybrid, got %s\n",
        selected["span-exact"] > "/dev/stderr"
      exit 5
    }
    if (span_exact["span-exact"] <= span_exact["byte-qacc"]) {
      printf "expected span objective to improve span exact-match in smoke\n" > "/dev/stderr"
      exit 6
    }
    if (qacc["span-exact"] >= qacc["byte-qacc"]) {
      printf "expected span objective to trade off qacc in smoke\n" > "/dev/stderr"
      exit 7
    }
  }
' "$POLICY_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows groups objectives_differ_rate qacc_policy_local_energy_rate span_policy_hybrid_rate balanced_policy_hybrid_rate span_policy_qacc_delta_vs_qacc_policy_mean span_policy_span_exact_delta_vs_qacc_policy_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy policy-scale aggregate column: %s\n", required[i] > "/dev/stderr"
        exit 8
      }
    }
    next
  }
  {
    if (($idx["groups"] + 0) < 1) {
      printf "expected at least one policy-scale group\n" > "/dev/stderr"
      exit 9
    }
    if (($idx["objectives_differ_rate"] + 0) < 0.99) {
      printf "expected qacc/span objectives to differ in smoke\n" > "/dev/stderr"
      exit 10
    }
    if (($idx["span_policy_span_exact_delta_vs_qacc_policy_mean"] + 0) <= 0.0) {
      printf "expected span policy to improve span exact-match in smoke\n" > "/dev/stderr"
      exit 11
    }
    if (($idx["span_policy_qacc_delta_vs_qacc_policy_mean"] + 0) >= 0.0) {
      printf "expected span policy to trade off qacc in smoke\n" > "/dev/stderr"
      exit 12
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      printf "jump-neighbor route path should remain inactive\n" > "/dev/stderr"
      exit 13
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span local-energy policy-scale smoke passed"
