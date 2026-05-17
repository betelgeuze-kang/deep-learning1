#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

SOURCE_MODE="--promotion"
SOURCE_PREFIX="v05_route_quality_candidate_hybrid_promotion"
PREFIX="v05_route_quality_candidate_basis_policy"
if [[ "$MODE" == "smoke" ]]; then
  SOURCE_MODE="--promotion-smoke"
  SOURCE_PREFIX="v05_route_quality_candidate_hybrid_promotion_smoke"
  PREFIX="v05_route_quality_candidate_basis_policy_smoke"
elif [[ "$MODE" == "full" ]]; then
  SOURCE_MODE="--promotion"
fi

SOURCE_SUMMARY="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
POLICY_CSV="$RESULTS_DIR/${PREFIX}_by_key_noise_policy.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"
QACC_TOLERANCE="${QACC_TOLERANCE:-0.001}"

if [[ "${RUN_SOURCE:-1}" != "0" ]]; then
  "$ROOT_DIR/experiments/run_v05_route_quality_candidate_hybrid_guardrail.sh" "$SOURCE_MODE"
fi

if [[ ! -f "$SOURCE_SUMMARY" ]]; then
  echo "missing source summary: $SOURCE_SUMMARY" >&2
  exit 3
fi

awk -F, -v qtol="$QACC_TOLERANCE" '
  function require(name) {
    if (!(name in idx)) {
      printf "missing source column: %s\n", name > "/dev/stderr"
      exit 4
    }
  }
  function mean(key, arm, metric) {
    if (count[key, arm] == 0) return 0
    return sum[key, arm, metric] / count[key, arm]
  }
  function recommendation(base_q, hybrid_q, base_gap, hybrid_gap, rec) {
    rec = "base-default"
    if (hybrid_q > base_q + qtol && hybrid_gap <= base_gap) {
      rec = "hybrid-m0p25-qacc"
    } else if (hybrid_q + qtol >= base_q && hybrid_gap < base_gap) {
      rec = "hybrid-m0p25-safe"
    }
    return rec
  }
  BEGIN {
    print "key_count,noisy_source_rate,rows,base_qacc_mean,hybrid_qacc_mean,qacc_delta,base_factor_gap_mean,hybrid_factor_gap_mean,factor_gap_delta,base_factor_max_mean,hybrid_factor_max_mean,factor_max_delta,base_wrong_strength_mean,hybrid_wrong_strength_mean,wrong_strength_delta,base_selected_noisy_rate_mean,hybrid_selected_noisy_rate_mean,lookup_count_mean,read_distance_mean,routing_trigger_rate_mean,active_jump_rate_mean,recommendation"
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    require("arm")
    require("key_count")
    require("noisy_source_rate")
    require("qacc")
    require("route_quality_candidate_weight_factor_gap")
    require("route_quality_candidate_weight_factor_max")
    require("route_quality_selected_noisy_rate")
    require("route_wrong_hint_strength_mean")
    require("lookup_count")
    require("read_distance")
    require("routing_trigger_rate")
    require("active_jump_rate")
    next
  }
  {
    arm = $idx["arm"]
    if (arm != "base-default" && arm != "hybrid-m0p25") next
    key = $idx["key_count"] "," $idx["noisy_source_rate"]
    if (!(key in seen_key)) {
      seen_key[key] = 1
      keys[++key_count_seen] = key
    }
    count[key, arm]++
    sum[key, arm, "qacc"] += $idx["qacc"] + 0
    sum[key, arm, "factor_gap"] += $idx["route_quality_candidate_weight_factor_gap"] + 0
    sum[key, arm, "factor_max"] += $idx["route_quality_candidate_weight_factor_max"] + 0
    sum[key, arm, "wrong_strength"] += $idx["route_wrong_hint_strength_mean"] + 0
    sum[key, arm, "selected_noisy"] += $idx["route_quality_selected_noisy_rate"] + 0
    sum[key, arm, "lookup"] += $idx["lookup_count"] + 0
    sum[key, arm, "read_distance"] += $idx["read_distance"] + 0
    sum[key, arm, "routing_trigger"] += $idx["routing_trigger_rate"] + 0
    sum[key, arm, "active_jump"] += $idx["active_jump_rate"] + 0
  }
  END {
    for (k = 1; k <= key_count_seen; k++) {
      key = keys[k]
      if (count[key, "base-default"] == 0 || count[key, "hybrid-m0p25"] == 0) {
        printf "missing base/hybrid pair for key/noise: %s\n", key > "/dev/stderr"
        exit 5
      }
      split(key, parts, ",")
      base_q = mean(key, "base-default", "qacc")
      hybrid_q = mean(key, "hybrid-m0p25", "qacc")
      base_gap = mean(key, "base-default", "factor_gap")
      hybrid_gap = mean(key, "hybrid-m0p25", "factor_gap")
      base_fmax = mean(key, "base-default", "factor_max")
      hybrid_fmax = mean(key, "hybrid-m0p25", "factor_max")
      base_wrong = mean(key, "base-default", "wrong_strength")
      hybrid_wrong = mean(key, "hybrid-m0p25", "wrong_strength")
      base_noisy = mean(key, "base-default", "selected_noisy")
      hybrid_noisy = mean(key, "hybrid-m0p25", "selected_noisy")
      lookup = (mean(key, "base-default", "lookup") + mean(key, "hybrid-m0p25", "lookup")) / 2.0
      read_distance = (mean(key, "base-default", "read_distance") + mean(key, "hybrid-m0p25", "read_distance")) / 2.0
      routing_trigger = (mean(key, "base-default", "routing_trigger") + mean(key, "hybrid-m0p25", "routing_trigger")) / 2.0
      active_jump = (mean(key, "base-default", "active_jump") + mean(key, "hybrid-m0p25", "active_jump")) / 2.0
      rec = recommendation(base_q, hybrid_q, base_gap, hybrid_gap)
      printf "%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s\n",
        parts[1], parts[2], count[key, "base-default"],
        base_q, hybrid_q, hybrid_q - base_q,
        base_gap, hybrid_gap, hybrid_gap - base_gap,
        base_fmax, hybrid_fmax, hybrid_fmax - base_fmax,
        base_wrong, hybrid_wrong, hybrid_wrong - base_wrong,
        base_noisy, hybrid_noisy, lookup, read_distance,
        routing_trigger, active_jump, rec
    }
  }
' "$SOURCE_SUMMARY" >"$POLICY_CSV"

awk -F, '
  function require(name) {
    if (!(name in idx)) {
      printf "missing policy column: %s\n", name > "/dev/stderr"
      exit 6
    }
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    require("base_qacc_mean")
    require("hybrid_qacc_mean")
    require("qacc_delta")
    require("base_factor_gap_mean")
    require("hybrid_factor_gap_mean")
    require("factor_gap_delta")
    require("base_wrong_strength_mean")
    require("hybrid_wrong_strength_mean")
    require("wrong_strength_delta")
    require("active_jump_rate_mean")
    require("recommendation")
    print "rows,base_qacc_mean,hybrid_qacc_mean,qacc_delta_mean,base_factor_gap_mean,hybrid_factor_gap_mean,factor_gap_delta_mean,base_wrong_strength_mean,hybrid_wrong_strength_mean,wrong_strength_delta_mean,hybrid_recommended_rate,active_jump_rate_mean"
    next
  }
  {
    rows++
    base_q += $idx["base_qacc_mean"] + 0
    hybrid_q += $idx["hybrid_qacc_mean"] + 0
    delta_q += $idx["qacc_delta"] + 0
    base_gap += $idx["base_factor_gap_mean"] + 0
    hybrid_gap += $idx["hybrid_factor_gap_mean"] + 0
    delta_gap += $idx["factor_gap_delta"] + 0
    base_wrong += $idx["base_wrong_strength_mean"] + 0
    hybrid_wrong += $idx["hybrid_wrong_strength_mean"] + 0
    delta_wrong += $idx["wrong_strength_delta"] + 0
    active_jump += $idx["active_jump_rate_mean"] + 0
    if ($idx["recommendation"] ~ /^hybrid/) hybrid_recommended++
  }
  END {
    if (rows < 1) {
      printf "no policy rows found\n" > "/dev/stderr"
      exit 7
    }
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows, base_q / rows, hybrid_q / rows, delta_q / rows,
      base_gap / rows, hybrid_gap / rows, delta_gap / rows,
      base_wrong / rows, hybrid_wrong / rows, delta_wrong / rows,
      hybrid_recommended / rows, active_jump / rows
  }
' "$POLICY_CSV" >"$AGG_CSV"

echo "wrote $POLICY_CSV"
echo "wrote $AGG_CSV"
