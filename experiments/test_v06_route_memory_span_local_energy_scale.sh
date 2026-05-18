#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_scale.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_scale_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_scale_smoke_aggregate.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("scenario key_count seed qacc span_exact span_all_recall span_all_top1 correct_key_share key_entropy coherent_wrong_top_key routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy scale summary column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    if (scenario == "weak") {
      saw_weak = 1
      weak_recall = $idx["span_all_recall"] + 0
      weak_qacc = $idx["qacc"] + 0
    }
    if (scenario == "span-local-energy") {
      saw_local_energy = 1
      local_energy_recall = $idx["span_all_recall"] + 0
      local_energy_qacc = $idx["qacc"] + 0
    }
    if (scenario == "keyshape") {
      saw_keyshape = 1
      keyshape_qacc = $idx["qacc"] + 0
    }
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 3 || saw_weak != 1 || saw_local_energy != 1 || saw_keyshape != 1) {
      printf "expected weak/local-energy/keyshape rows, got rows=%d weak=%d local=%d keyshape=%d\n",
        rows, saw_weak, saw_local_energy, saw_keyshape > "/dev/stderr"
      exit 3
    }
    if (weak_recall < 0.99 || local_energy_recall < 0.99) {
      printf "expected weak and local-energy all-span recall to stay restored: weak=%.6f local=%.6f\n",
        weak_recall, local_energy_recall > "/dev/stderr"
      exit 4
    }
    if (local_energy_qacc + 1e-9 < weak_qacc) {
      printf "expected local-energy qacc not below weak in smoke: %.6f < %.6f\n",
        local_energy_qacc, weak_qacc > "/dev/stderr"
      exit 5
    }
    if (keyshape_qacc + 1e-9 < local_energy_qacc) {
      printf "expected symbolic key-shape upper bound not below local-energy: %.6f < %.6f\n",
        keyshape_qacc, local_energy_qacc > "/dev/stderr"
      exit 6
    }
    if (routing != 0.0 || jump != 0.0) {
      printf "jump-neighbor route path should remain inactive: routing=%.6f jump=%.6f\n",
        routing, jump > "/dev/stderr"
      exit 7
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows groups weak_qacc_mean local_energy_qacc_mean keyshape_qacc_mean local_energy_qacc_delta_mean weak_span_exact_mean local_energy_span_exact_mean local_energy_span_exact_delta_mean weak_all_recall_mean local_energy_all_recall_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy scale aggregate column: %s\n", required[i] > "/dev/stderr"
        exit 8
      }
    }
    next
  }
  {
    if (($idx["groups"] + 0) < 1) {
      printf "invalid aggregate group count\n" > "/dev/stderr"
      exit 9
    }
    if (($idx["local_energy_qacc_delta_mean"] + 0) < -0.000001) {
      printf "expected non-negative local-energy qacc delta in smoke\n" > "/dev/stderr"
      exit 10
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span local-energy scale smoke passed"
