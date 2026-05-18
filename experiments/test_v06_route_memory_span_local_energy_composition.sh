#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_local_energy_composition.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_composition_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_local_energy_composition_smoke_aggregate.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("scenario qacc span_exact span_all_recall span_all_top1 correct_key_share key_entropy factor_mean factor_max routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy composition summary column: %s\n", required[i] > "/dev/stderr"
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
      weak_qacc = $idx["qacc"] + 0
      weak_recall = $idx["span_all_recall"] + 0
    }
    if (scenario == "local-energy") {
      saw_local = 1
      local_qacc = $idx["qacc"] + 0
      local_recall = $idx["span_all_recall"] + 0
    }
    if (scenario == "local-energy-base") {
      saw_base = 1
      base_recall = $idx["span_all_recall"] + 0
    }
    if (scenario == "local-energy-hybrid") {
      saw_hybrid = 1
      hybrid_recall = $idx["span_all_recall"] + 0
    }
    if (scenario == "keyshape") {
      saw_keyshape = 1
      keyshape_qacc = $idx["qacc"] + 0
    }
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 5 || saw_weak != 1 || saw_local != 1 ||
        saw_base != 1 || saw_hybrid != 1 || saw_keyshape != 1) {
      printf "expected weak/local/base/hybrid/keyshape rows\n" > "/dev/stderr"
      exit 3
    }
    if (weak_recall < 0.99 || local_recall < 0.99 ||
        base_recall < 0.99 || hybrid_recall < 0.99) {
      printf "expected all composition arms to keep all-span recall restored\n" > "/dev/stderr"
      exit 4
    }
    if (local_qacc + 1e-9 < weak_qacc) {
      printf "expected local-energy qacc not below weak in smoke: %.6f < %.6f\n",
        local_qacc, weak_qacc > "/dev/stderr"
      exit 5
    }
    if (keyshape_qacc + 1e-9 < local_qacc) {
      printf "expected symbolic key-shape upper bound not below local-energy\n" > "/dev/stderr"
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
    required_count = split("rows weak_qacc local_energy_qacc local_energy_base_qacc local_energy_hybrid_qacc keyshape_qacc local_energy_delta local_energy_base_delta local_energy_hybrid_delta routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        printf "missing span local-energy composition aggregate column: %s\n", required[i] > "/dev/stderr"
        exit 8
      }
    }
    next
  }
  {
    if (($idx["rows"] + 0) < 5) {
      printf "invalid aggregate rows\n" > "/dev/stderr"
      exit 9
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span local-energy composition smoke passed"
