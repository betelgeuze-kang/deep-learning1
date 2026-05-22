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

PREFIX="v10_chunk_credit_distillation_gate"
POLICY_PREFIX="v10_chunk_credit_abstain_policy"
JOINT_PREFIX="v10_chunk_credit_source_robustness"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_chunk_credit_distillation_gate_smoke"
  POLICY_PREFIX="v10_chunk_credit_abstain_policy_smoke"
  JOINT_PREFIX="v10_chunk_credit_source_robustness_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

POLICY_CSV="$RESULTS_DIR/${POLICY_PREFIX}_policy.csv"
JOINT_AGG_CSV="$RESULTS_DIR/${JOINT_PREFIX}_aggregate.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ ! -s "$POLICY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_chunk_credit_abstain_policy.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$JOINT_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_chunk_credit_source_robustness.sh" "${RUN_ARGS[@]}" >/dev/null
fi

awk -F, -v policy_csv="$POLICY_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  FILENAME == policy_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) pidx[$i] = i
    required_count = split("guardrail_action default_promotion diagnostic_only weak_hint_or_abstain chunk_credit_ready source_safe fallback_not_keyshape_only joint_chunk_source_ready distillation_ready combined_ready noisy_selection_clean joint_noisy_used joint_fallback_retry_exercised routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in pidx)) die("missing h10 distillation policy column: " required[i], 2)
    }
    next
  }
  FILENAME == policy_csv {
    policy_rows++
    guardrail_action = $pidx["guardrail_action"]
    default_promotion = $pidx["default_promotion"] + 0
    diagnostic_only = $pidx["diagnostic_only"] + 0
    weak_hint_or_abstain = $pidx["weak_hint_or_abstain"] + 0
    chunk_credit_ready = $pidx["chunk_credit_ready"] + 0
    source_safe = $pidx["source_safe"] + 0
    fallback_not_keyshape_only = $pidx["fallback_not_keyshape_only"] + 0
    policy_joint_ready = $pidx["joint_chunk_source_ready"] + 0
    policy_distillation_ready = $pidx["distillation_ready"] + 0
    policy_combined_ready = $pidx["combined_ready"] + 0
    noisy_selection_clean = $pidx["noisy_selection_clean"] + 0
    policy_joint_noisy_used = $pidx["joint_noisy_used"] + 0
    policy_fallback_retry_exercised = $pidx["joint_fallback_retry_exercised"] + 0
    policy_routing = $pidx["routing_trigger_rate"] + 0
    policy_jump = $pidx["active_jump_rate"] + 0
    next
  }
  FILENAME != policy_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) jidx[$i] = i
    required_count = split("best_joint_arm chunk_ready source_safe fallback_not_keyshape_only fallback_retry_exercised joint_chunk_source_ready noisy_used noisy_selected retry_noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in jidx)) die("missing h10 distillation joint column: " required[i], 3)
    }
    next
  }
  FILENAME != policy_csv {
    joint_rows++
    best_joint_arm = $jidx["best_joint_arm"]
    joint_chunk_ready = $jidx["chunk_ready"] + 0
    joint_source_safe = $jidx["source_safe"] + 0
    joint_fallback_not_keyshape_only = $jidx["fallback_not_keyshape_only"] + 0
    joint_fallback_retry_exercised = $jidx["fallback_retry_exercised"] + 0
    joint_chunk_source_ready = $jidx["joint_chunk_source_ready"] + 0
    joint_noisy_used = $jidx["noisy_used"] + 0
    joint_noisy_selected = $jidx["noisy_selected"] + 0
    joint_retry_noisy_selected = $jidx["retry_noisy_selected"] + 0
    joint_routing = $jidx["routing_trigger_rate"] + 0
    joint_jump = $jidx["active_jump_rate"] + 0
    next
  }
  END {
    if (policy_rows != 1) die("expected one h10 distillation policy row", 4)
    if (joint_rows != 1) die("expected one h10 distillation joint row", 5)

    noisy_clean = noisy_selection_clean &&
      joint_noisy_used > 0.0 &&
      joint_noisy_selected == 0.0 &&
      joint_retry_noisy_selected == 0.0 ? 1 : 0
    fallback_gate = joint_fallback_retry_exercised &&
      joint_fallback_not_keyshape_only &&
      fallback_not_keyshape_only ? 1 : 0
    distillation_ready = chunk_credit_ready &&
      source_safe &&
      joint_chunk_ready &&
      joint_source_safe &&
      noisy_clean &&
      fallback_gate &&
      joint_chunk_source_ready &&
      policy_joint_ready &&
      policy_distillation_ready &&
      policy_combined_ready &&
      policy_routing == 0.0 &&
      policy_jump == 0.0 &&
      joint_routing == 0.0 &&
      joint_jump == 0.0 ? 1 : 0
    status = distillation_ready ? "distillation-candidate" : "diagnostic-only"
    reason = fallback_gate ? "all-gates-ready" : "fallback-retry-unexercised"

    print "best_joint_arm,guardrail_action,chunk_credit_ready,joint_chunk_ready,source_safe,joint_source_safe,noisy_clean,fallback_not_keyshape_only,fallback_retry_exercised,joint_chunk_source_ready,policy_distillation_ready,combined_ready,distillation_ready,default_promotion,diagnostic_only,weak_hint_or_abstain,status,reason,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%.6f,%.6f\n",
      best_joint_arm,
      guardrail_action,
      chunk_credit_ready,
      joint_chunk_ready,
      source_safe,
      joint_source_safe,
      noisy_clean,
      fallback_not_keyshape_only && joint_fallback_not_keyshape_only ? 1 : 0,
      joint_fallback_retry_exercised,
      joint_chunk_source_ready,
      policy_distillation_ready,
      policy_combined_ready,
      distillation_ready,
      default_promotion,
      diagnostic_only,
      weak_hint_or_abstain,
      status,
      reason,
      policy_routing + joint_routing,
      policy_jump + joint_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "chunk-credit,%s,chunk_credit_ready=%d joint_chunk_ready=%d\n",
      chunk_credit_ready && joint_chunk_ready ? "pass" : "blocked",
      chunk_credit_ready,
      joint_chunk_ready >> decision_csv
    printf "noisy-wrong-candidate,%s,noisy_used=%.6f noisy_selected=%.6f retry_noisy=%.6f\n",
      noisy_clean ? "pass" : "blocked",
      joint_noisy_used,
      joint_noisy_selected,
      joint_retry_noisy_selected >> decision_csv
    printf "fallback-retry,%s,fallback_retry_exercised=%d fallback_not_keyshape_only=%d\n",
      fallback_gate ? "pass" : "blocked",
      joint_fallback_retry_exercised,
      fallback_not_keyshape_only && joint_fallback_not_keyshape_only ? 1 : 0 >> decision_csv
    printf "distillation,%s,status=%s reason=%s\n",
      distillation_ready ? "pass" : "blocked",
      status,
      reason >> decision_csv
  }
' "$POLICY_CSV" "$JOINT_AGG_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
