#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_CSV="$ROOT_DIR/results/v05_route_candidate_quality_logdet_smoke_summary.csv"

"$ROOT_DIR/experiments/run_v05_route_candidate_quality_logdet.sh" --smoke

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
    required_count = split("scenario arm quality_enabled quality_feature_set quality_apply key_count seed qacc route_quality_logdet_mean route_quality_logdet_norm_mean route_quality_condition_mean route_quality_score_mean route_quality_score_correct_mean route_quality_score_wrong_mean route_quality_score_gap route_channel_tension_det_mean route_channel_tension_trace_mean route_channel_tension_offdiag_mean route_channel_hi_margin_mean route_channel_lo_margin_mean route_channel_margin_imbalance_mean lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing summary column: " required[i], 2)
      }
    }
    next
  }
  {
    arm = $idx["arm"]
    qacc = metric("qacc")
    logdet = metric("route_quality_logdet_mean")
    logdet_norm = metric("route_quality_logdet_norm_mean")
    condition = metric("route_quality_condition_mean")
    score = metric("route_quality_score_mean")
    det = metric("route_channel_tension_det_mean")
    trace = metric("route_channel_tension_trace_mean")
    offdiag = metric("route_channel_tension_offdiag_mean")
    lookup_count = metric("lookup_count")
    read_distance = metric("read_distance")
    routing_trigger = metric("routing_trigger_rate")
    active_jump = metric("active_jump_rate")

    if (metric("key_count") != 128 || metric("seed") != 1) {
      die("smoke should run key_count=128 seed=1", 3)
    }
    if ($idx["quality_apply"] != "none") {
      die("h5-u must use route_quality_apply=none: " arm, 4)
    }
    if ($idx["quality_feature_set"] != "value-only") {
      die("h5-u smoke must use value-only feature diagnostics: " arm, 4)
    }
    if (qacc < 0 || qacc > 1 || condition < 0) {
      die("metric out of range: " arm, 5)
    }
    if (lookup_count <= 0 || read_distance <= 0) {
      die("value-bearing route path should remain populated: " arm, 6)
    }
    if (routing_trigger != 0 || active_jump != 0) {
      die("candidate-quality diagnostics must not activate jump-neighbor routing: " arm, 7)
    }
    if (arm ~ /^quality-on/ || arm ~ /^quality-off/) {
      if (!(logdet == logdet && logdet_norm == logdet_norm &&
            condition == condition && score == score &&
            det == det && trace == trace && offdiag == offdiag)) {
        die("quality metrics must be finite: " arm, 8)
      }
    }
    rows++
    if (arm == "quality-off-source-order") {
      off_seen = 1
      off_qacc = qacc
    } else if (arm == "quality-on-source-order") {
      on_seen = 1
      on_qacc = qacc
    } else if (arm == "quality-on-keyshape-prior") {
      keyshape_seen = 1
      keyshape_logdet = logdet
      keyshape_score = score
    } else if (arm == "quality-on-fixed-raw") {
      fixed_raw_seen = 1
      raw_logdet = logdet
      raw_score = score
    } else if (arm == "quality-on-fixed-keyshape") {
      fixed_shape_seen = 1
      fixed_shape_logdet = logdet
      fixed_shape_score = score
    } else {
      die("unexpected arm: " arm, 9)
    }
  }
  END {
    if (rows != expected_rows) {
      die("expected " expected_rows " rows, found " rows, 10)
    }
    if (!(off_seen && on_seen && keyshape_seen && fixed_raw_seen && fixed_shape_seen)) {
      die("missing one or more candidate-quality arms", 11)
    }
    if (on_qacc > off_qacc + 1.0e-6 || on_qacc + 1.0e-6 < off_qacc) {
      die("quality-on source-order should not change qacc with apply=none", 12)
    }
    if (!(raw_logdet != fixed_shape_logdet || raw_score != fixed_shape_score ||
          keyshape_logdet != raw_logdet || keyshape_score != raw_score)) {
      die("quality diagnostics should separate at least one raw/key-shape signal", 13)
    }
  }
' "$SUMMARY_CSV"

echo "route candidate-quality logdet smoke passed"
