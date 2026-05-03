#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_retry_prior_schedule_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_retry_prior_schedule.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) {
    return $idx[name] + 0
  }
  BEGIN { expected_rows = 5 }
  NR == 1 {
    split("scenario arm prior_mode prior_scale retry_tiebreak retry_priorities key_count seed qacc fallback_recall fallback_qacc source_gap noisy_slashed source_retry_used source_retry_success retry_raw_selected retry_keyshape_selected retry_noisy_selected lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        die("missing summary column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    mode = $idx["prior_mode"]
    scale = metric("prior_scale")
    retry_tiebreak = $idx["retry_tiebreak"]
    qacc = metric("qacc")
    fallback_recall = metric("fallback_recall")
    fallback_qacc = metric("fallback_qacc")
    noisy_slashed = metric("noisy_slashed")
    retry_used = metric("source_retry_used")
    retry_success = metric("source_retry_success")
    retry_raw = metric("retry_raw_selected")
    retry_keyshape = metric("retry_keyshape_selected")
    retry_noisy = metric("retry_noisy_selected")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (qacc < 0 || qacc > 1 || fallback_recall < 0 || fallback_recall > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 || noisy_slashed < 0 ||
        noisy_slashed > 1 || retry_used < 0 || retry_used > 1 ||
        retry_success < 0 || retry_success > 1 || retry_raw < 0 ||
        retry_raw > 1 || retry_keyshape < 0 || retry_keyshape > 1 ||
        retry_noisy < 0 || retry_noisy > 1) {
      die("metric out of range: " arm, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-bearing route path should remain populated: " arm, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("prior schedule must not activate jump-neighbor routing: " arm, 6)
    }

    rows++
    if (arm == "source-order") {
      source_order_seen = 1
      if (mode != "none" || retry_tiebreak != "source-order" || scale != 0 ||
          fallback_recall <= 0 || retry_raw <= 0 || retry_noisy > 0.05) {
        die("source-order baseline should recover through raw-key without noisy retry", 7)
      }
      source_order_qacc = qacc
    } else if (arm == "static-keyshape-prior") {
      static_seen = 1
      if (mode != "static" || retry_tiebreak != "source-prior" || scale <= 0 ||
          fallback_recall <= 0 || retry_keyshape <= 0 || retry_noisy > 0.05) {
        die("static prior should recover through key-shape without noisy retry", 8)
      }
    } else if (arm == "decay-keyshape-prior") {
      decay_seen = 1
      if (mode != "decay" || retry_tiebreak != "source-prior" || scale <= 0 ||
          fallback_recall <= 0 || retry_keyshape <= 0 || retry_noisy > 0.05) {
        die("decay prior should recover through key-shape without noisy retry", 9)
      }
    } else if (arm == "warmup-keyshape-prior") {
      warmup_seen = 1
      warmup_qacc = qacc
      if (mode != "warmup" || retry_tiebreak != "source-prior" || scale <= 0 ||
          fallback_recall <= 0 || retry_keyshape <= 0 || retry_noisy > 0.05) {
        die("warmup prior should recover through key-shape without noisy retry", 10)
      }
    } else if (arm == "fixed-keyshape") {
      fixed_seen = 1
      fixed_qacc = qacc
      if (mode != "none" || retry_tiebreak != "source-order" ||
          fallback_recall <= 0 || retry_keyshape <= 0 || retry_noisy > 0.05) {
        die("fixed key-shape reference should recover through key-shape", 11)
      }
    } else {
      die("unexpected arm: " arm, 12)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 13)
    }
    if (!(source_order_seen && static_seen && decay_seen && warmup_seen && fixed_seen)) {
      die("missing one or more prior-schedule arms", 14)
    }
    if (fixed_qacc > 0 && warmup_qacc < source_order_qacc - 0.05) {
      die("warmup prior should not regress far below source-order baseline", 15)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit retry prior-schedule smoke passed"
