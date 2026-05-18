#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_policy.sh" --smoke

POLICY_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_policy_smoke_policy.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_policy_smoke_aggregate.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("objective selected_scenario qacc span_exact span_all_top1 correct_key_share key_entropy qacc_delta_vs_weak span_exact_delta_vs_weak qacc_delta_vs_local_energy span_exact_delta_vs_local_energy", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy policy column: %s\n", required[i] > "/dev/stderr"
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
    if (rows < 3 ||
        !("byte-qacc" in selected) ||
        !("span-exact" in selected) ||
        !("balanced" in selected)) {
      printf "expected byte-qacc/span-exact/balanced policy rows\n" > "/dev/stderr"
      exit 3
    }
    if (selected["byte-qacc"] != "local-energy") {
      printf "expected byte-qacc objective to select local-energy, got %s\n",
        selected["byte-qacc"] > "/dev/stderr"
      exit 4
    }
    if (selected["span-exact"] != "local-energy-hybrid") {
      printf "expected span-exact objective to select local-energy-hybrid, got %s\n",
        selected["span-exact"] > "/dev/stderr"
      exit 5
    }
    if (span_exact["span-exact"] <= span_exact["byte-qacc"]) {
      printf "expected span objective to improve span exact-match over byte-qacc objective\n" > "/dev/stderr"
      exit 6
    }
    if (qacc["span-exact"] >= qacc["byte-qacc"]) {
      printf "expected span objective to trade off byte qacc in this smoke\n" > "/dev/stderr"
      exit 7
    }
  }
' "$POLICY_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("candidate_rows qacc_objective_scenario span_objective_scenario balanced_objective_scenario objectives_differ span_objective_qacc_delta_vs_qacc_objective span_objective_span_exact_delta_vs_qacc_objective routing_trigger_rate_sum active_jump_rate_sum", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy policy aggregate column: %s\n", required[i] > "/dev/stderr"
        exit 8
      }
    }
    next
  }
  {
    if (($idx["candidate_rows"] + 0) < 5) {
      printf "expected at least 5 candidate rows\n" > "/dev/stderr"
      exit 9
    }
    if (($idx["objectives_differ"] + 0) != 1) {
      printf "expected qacc/span objectives to differ\n" > "/dev/stderr"
      exit 10
    }
    if (($idx["span_objective_span_exact_delta_vs_qacc_objective"] + 0) <= 0.0) {
      printf "expected positive span-exact delta for span objective\n" > "/dev/stderr"
      exit 11
    }
    if (($idx["span_objective_qacc_delta_vs_qacc_objective"] + 0) >= 0.0) {
      printf "expected negative qacc delta for span objective in this smoke\n" > "/dev/stderr"
      exit 12
    }
    if (($idx["routing_trigger_rate_sum"] + 0) != 0.0 ||
        ($idx["active_jump_rate_sum"] + 0) != 0.0) {
      printf "jump-neighbor route path should remain inactive\n" > "/dev/stderr"
      exit 13
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span local-energy policy smoke passed"
