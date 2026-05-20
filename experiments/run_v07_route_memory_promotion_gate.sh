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

PREFIX="v07_route_memory_promotion_gate"
SCALE_PREFIX="v06_route_memory_span_adaptive_guardrail_scale"
ROBUST_PREFIX="v06_route_memory_wrong_candidate_robustness"
ABSTAIN_PREFIX="v06_route_memory_abstain_retry_guardrail"
LOCAL_PREFIX="v06_route_memory_chunk_local_energy_prefix"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v07_route_memory_promotion_gate_smoke"
  SCALE_PREFIX="v06_route_memory_span_adaptive_guardrail_scale_smoke"
  ROBUST_PREFIX="v06_route_memory_wrong_candidate_robustness_smoke"
  ABSTAIN_PREFIX="v06_route_memory_abstain_retry_guardrail_smoke"
  LOCAL_PREFIX="v06_route_memory_chunk_local_energy_prefix_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

SCALE_AGG_CSV="$RESULTS_DIR/${SCALE_PREFIX}_aggregate.csv"
ROBUST_SUMMARY_CSV="$RESULTS_DIR/${ROBUST_PREFIX}_summary.csv"
ABSTAIN_POLICY_CSV="$RESULTS_DIR/${ABSTAIN_PREFIX}_policy.csv"
LOCAL_AGG_CSV="$RESULTS_DIR/${LOCAL_PREFIX}_aggregate.csv"

if [[ ! -s "$SCALE_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_span_adaptive_guardrail_scale.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$ROBUST_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_wrong_candidate_robustness.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$ABSTAIN_POLICY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_abstain_retry_guardrail.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$LOCAL_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_chunk_local_energy_prefix.sh" "${RUN_ARGS[@]}" >/dev/null
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  FILENAME == ARGV[1] {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) sidx[$i] = i
      next
    }
    if ($sidx["degradation"] == "all" && $sidx["policy"] == "utility-w0p75") {
      scale_seen = 1
      scale_groups = $sidx["groups"] + 0
      scale_accept = $sidx["span_accept_rate"] + 0
      scale_sane = $sidx["sane_accept_rate"] + 0
      scale_bad = $sidx["bad_accept_rate"] + 0
      scale_routing = $sidx["routing_trigger_rate_mean"] + 0
      scale_jump = $sidx["active_jump_rate_mean"] + 0
    }
    next
  }
  FILENAME == ARGV[2] {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) ridx[$i] = i
      next
    }
    robust_seen = 1
    chunk_ready = $ridx["chunk_ready"] + 0
    source_safe = $ridx["source_safe"] + 0
    fallback_not_keyshape_only = $ridx["fallback_not_keyshape_only"] + 0
    combined_ready = $ridx["combined_ready"] + 0
    robust_recommendation = $ridx["recommendation"]
    robust_routing = $ridx["routing_trigger_rate"] + 0
    robust_jump = $ridx["active_jump_rate"] + 0
    next
  }
  FILENAME == ARGV[3] {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) aidx[$i] = i
      next
    }
    abstain_seen = 1
    abstain_action = $aidx["guardrail_action"]
    abstain_default_promotion = $aidx["default_promotion"] + 0
    abstain_diagnostic_only = $aidx["diagnostic_only"] + 0
    weak_hint_or_abstain = $aidx["weak_hint_or_abstain"] + 0
    abstain_routing = $aidx["routing_trigger_rate"] + 0
    abstain_jump = $aidx["active_jump_rate"] + 0
    next
  }
  FILENAME == ARGV[4] {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) lidx[$i] = i
      next
    }
    local_seen = 1
    chunk_local_best_scorer = $lidx["best_non_keyshape_scorer"]
    chunk_local_chunk_delta = $lidx["best_chunk_delta_vs_local_energy"] + 0
    chunk_local_qacc_delta = $lidx["best_qacc_delta_vs_local_energy"] + 0
    chunk_local_wrong_delta = $lidx["best_wrong_delta_vs_local_energy"] + 0
    local_routing = $lidx["routing_trigger_rate_mean"] + 0
    local_jump = $lidx["active_jump_rate_mean"] + 0
    next
  }
  END {
    if (!scale_seen || !robust_seen || !abstain_seen || !local_seen) {
      print "missing promotion gate input" > "/dev/stderr"
      exit 2
    }
    adaptive_scale_safe = scale_bad == 0.0 &&
      scale_routing == 0.0 &&
      scale_jump == 0.0 ? 1 : 0
    chunk_local_safe = chunk_local_best_scorer != "" &&
      chunk_local_chunk_delta >= -0.000001 &&
      chunk_local_qacc_delta >= -0.020001 &&
      chunk_local_wrong_delta <= 0.000001 &&
      local_routing == 0.0 &&
      local_jump == 0.0 ? 1 : 0
    no_jump = scale_routing == 0.0 && scale_jump == 0.0 &&
      robust_routing == 0.0 && robust_jump == 0.0 &&
      abstain_routing == 0.0 && abstain_jump == 0.0 &&
      local_routing == 0.0 && local_jump == 0.0 ? 1 : 0
    default_promotion = adaptive_scale_safe &&
      chunk_local_safe &&
      chunk_ready &&
      source_safe &&
      fallback_not_keyshape_only &&
      combined_ready &&
      abstain_default_promotion &&
      no_jump ? 1 : 0
    status = default_promotion ? "promotion-candidate" : "diagnostic-only"

    print "scale_groups,adaptive_scale_safe,scale_accept_rate,scale_sane_accept_rate,scale_bad_accept_rate,chunk_local_safe,chunk_local_best_scorer,chunk_local_chunk_delta,chunk_local_qacc_delta,chunk_local_wrong_delta,chunk_ready,source_safe,fallback_not_keyshape_only,combined_ready,abstain_action,weak_hint_or_abstain,default_promotion,status,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%d,%d,%.6f,%.6f,%.6f,%d,%s,%.6f,%.6f,%.6f,%d,%d,%d,%d,%s,%d,%d,%s,%.6f,%.6f\n",
      scale_groups,
      adaptive_scale_safe,
      scale_accept,
      scale_sane,
      scale_bad,
      chunk_local_safe,
      chunk_local_best_scorer,
      chunk_local_chunk_delta,
      chunk_local_qacc_delta,
      chunk_local_wrong_delta,
      chunk_ready,
      source_safe,
      fallback_not_keyshape_only,
      combined_ready,
      abstain_action,
      weak_hint_or_abstain,
      default_promotion,
      status,
      scale_routing + robust_routing + abstain_routing + local_routing,
      scale_jump + robust_jump + abstain_jump + local_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "adaptive-scale,%s,bad_accept_rate=%.6f\n",
      adaptive_scale_safe ? "pass" : "blocked",
      scale_bad >> decision_csv
    printf "chunk-quality,%s,chunk_ready=%d\n",
      chunk_ready ? "pass" : "diagnostic-only",
      chunk_ready >> decision_csv
    printf "chunk-local-scorer,%s,best=%s chunk_delta=%.6f wrong_delta=%.6f\n",
      chunk_local_safe ? "pass" : "blocked",
      chunk_local_best_scorer,
      chunk_local_chunk_delta,
      chunk_local_wrong_delta >> decision_csv
    printf "source-credit,%s,source_safe=%d fallback_not_keyshape_only=%d\n",
      source_safe && fallback_not_keyshape_only ? "pass" : "blocked",
      source_safe,
      fallback_not_keyshape_only >> decision_csv
    printf "abstain-retry,%s,action=%s\n",
      abstain_default_promotion ? "pass" : "diagnostic-only",
      abstain_action >> decision_csv
    printf "default-promotion,%s,status=%s\n",
      default_promotion ? "pass" : "blocked",
      status >> decision_csv
  }
' "$SCALE_AGG_CSV" "$ROBUST_SUMMARY_CSV" "$ABSTAIN_POLICY_CSV" "$LOCAL_AGG_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
