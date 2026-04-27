#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

summarize_csv() {
  local label="$1"
  local csv_path="$2"
  tail -n 10 "$csv_path" | awk -F, -v label="$label" '
    {
      byte += $3
      field += $4
      joint += $19
      trig += $21
      gap_pass += $27
      gap_mean += $28
      gap_max += $29
      gate += $30
      stress += $31
      conf += $32
      confmax += $33
      cand += $22
      hit += $23
      active += $24
      jumpn += $25
      jumpd += $26
      n += 1
    }
    END {
      printf "%-13s byte=%.6f field=%.6f joint=%.6f trig=%.6f gap_pass=%.6f gap_mean=%.6f gap_max=%.6f gate=%.6f stress=%.6f conf=%.6f conf_max=%.6f cand=%.6f hit=%.6f active=%.6f jump_n=%.6f jump_d=%.6f\n",
        label, byte/n, field/n, joint/n, trig/n, gap_pass/n, gap_mean/n, gap_max/n, gate/n, stress/n, conf/n, confmax/n, cand/n, hit/n, active/n, jumpn/n, jumpd/n
    }'
}

echo "v03 static routing slice summary (last-10 means)"
summarize_csv repeat-off "$RESULTS_DIR/v03_static_repeat_off.csv"
summarize_csv repeat-probe "$RESULTS_DIR/v03_static_repeat_probe.csv"
summarize_csv repeat-jump "$RESULTS_DIR/v03_static_repeat_jump.csv"
summarize_csv fixture-off "$RESULTS_DIR/v03_static_fixture_off.csv"
summarize_csv fixture-probe "$RESULTS_DIR/v03_static_fixture_probe.csv"
summarize_csv fixture-jump "$RESULTS_DIR/v03_static_fixture_jump.csv"
