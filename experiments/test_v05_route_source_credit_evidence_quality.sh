#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_source_credit_evidence_quality_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_source_credit_evidence_quality.sh" --smoke

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
    split("scenario arm prior_mode retry_tiebreak retry_priorities key_count seed qacc fallback_recall fallback_qacc source_gap noisy_slashed source_retry_used source_retry_success retry_raw_selected retry_keyshape_selected retry_noisy_selected retry_raw_mean retry_keyshape_mean retry_noisy_mean retry_raw_rewarded retry_keyshape_rewarded retry_noisy_slashed lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
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
    prior_mode = $idx["prior_mode"]
    retry_tiebreak = $idx["retry_tiebreak"]
    qacc = metric("qacc")
    fallback_recall = metric("fallback_recall")
    fallback_qacc = metric("fallback_qacc")
    source_gap = metric("source_gap")
    noisy_slashed = metric("noisy_slashed")
    retry_used = metric("source_retry_used")
    retry_success = metric("source_retry_success")
    retry_raw = metric("retry_raw_selected")
    retry_shape = metric("retry_keyshape_selected")
    retry_noisy = metric("retry_noisy_selected")
    raw_mean = metric("retry_raw_mean")
    shape_mean = metric("retry_keyshape_mean")
    retry_noisy_mean = metric("retry_noisy_mean")
    raw_rewarded = metric("retry_raw_rewarded")
    shape_rewarded = metric("retry_keyshape_rewarded")
    retry_noisy_slashed = metric("retry_noisy_slashed")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if (qacc < 0 || qacc > 1 || fallback_recall < 0 || fallback_recall > 1 ||
        fallback_qacc < 0 || fallback_qacc > 1 || retry_used < 0 ||
        retry_used > 1 || retry_success < 0 || retry_success > 1 ||
        retry_raw < 0 || retry_raw > 1 || retry_shape < 0 ||
        retry_shape > 1 || retry_noisy < 0 || retry_noisy > 1 ||
        raw_rewarded < 0 || raw_rewarded > 1 ||
        shape_rewarded < 0 || shape_rewarded > 1 ||
        retry_noisy_slashed < 0 || retry_noisy_slashed > 1) {
      die("metric out of range: " arm, 4)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-bearing route path should remain populated: " arm, 5)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("evidence-quality diagnostics must not activate jump-neighbor routing: " arm, 6)
    }
    if (retry_noisy > 0.05) {
      die("evidence-quality diagnostics should avoid noisy retry selection: " arm, 7)
    }

    rows++
    if (arm == "source-order") {
      source_order_seen = 1
      source_order_qacc = qacc
      if (prior_mode != "none" || retry_tiebreak != "source-order" ||
          fallback_recall <= 0 || retry_raw <= 0 || retry_success <= 0) {
        die("source-order baseline should recover through raw-key retry", 8)
      }
    } else if (arm == "static-keyshape-prior") {
      static_seen = 1
      if (prior_mode != "static" || retry_tiebreak != "source-prior" ||
          fallback_recall <= 0 || retry_shape <= 0 || retry_success <= 0) {
        die("static prior should recover through key-shape retry", 9)
      }
    } else if (arm == "warmup-keyshape-prior") {
      warmup_seen = 1
      if (prior_mode != "warmup" || retry_tiebreak != "source-prior" ||
          fallback_recall <= 0 || retry_shape <= 0 || retry_success <= 0) {
        die("warmup prior should recover through key-shape retry", 10)
      }
    } else if (arm == "raw-quality-evidence") {
      raw_quality_seen = 1
      raw_quality_qacc = qacc
      raw_quality_raw_mean = raw_mean
      raw_quality_shape_mean = shape_mean
      raw_quality_raw_rewarded = raw_rewarded
      if (prior_mode != "none" || retry_tiebreak != "source-order" ||
          fallback_recall <= 0 || retry_raw <= 0 || retry_success <= 0 ||
          raw_mean <= shape_mean || raw_rewarded <= shape_rewarded ||
          raw_mean <= 0) {
        die("raw-quality evidence should separate raw-key above key-shape", 11)
      }
    } else if (arm == "keyshape-quality-evidence") {
      shape_quality_seen = 1
      shape_quality_qacc = qacc
      shape_quality_raw_mean = raw_mean
      shape_quality_shape_mean = shape_mean
      shape_quality_shape_rewarded = shape_rewarded
      if (prior_mode != "none" || retry_tiebreak != "source-order" ||
          fallback_recall <= 0 || retry_shape <= 0 || retry_success <= 0 ||
          shape_mean <= raw_mean || shape_rewarded <= raw_rewarded ||
          shape_mean <= 0) {
        die("keyshape-quality evidence should separate key-shape above raw-key", 12)
      }
    } else {
      die("unexpected arm: " arm, 13)
    }
    if (arm ~ /quality-evidence/ && !(source_gap != 0 && noisy_slashed > 0 &&
        retry_noisy_mean <= raw_mean && retry_noisy_slashed >= 0)) {
      die("quality evidence rows should keep source/noisy diagnostics populated: " arm, 14)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 15)
    }
    if (!(source_order_seen && static_seen && warmup_seen &&
          raw_quality_seen && shape_quality_seen)) {
      die("missing one or more evidence-quality arms", 16)
    }
    if (raw_quality_qacc + 1.0e-6 < source_order_qacc ||
        shape_quality_qacc + 1.0e-6 < source_order_qacc) {
      die("quality evidence rows should preserve source-order value path", 17)
    }
    if (raw_quality_raw_mean <= raw_quality_shape_mean ||
        shape_quality_shape_mean <= shape_quality_raw_mean) {
      die("raw/key-shape evidence must separate in opposite directions", 18)
    }
  }
' "$SUMMARY_CSV"

echo "route source credit evidence-quality smoke passed"
