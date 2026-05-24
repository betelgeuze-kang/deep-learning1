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
FALLBACK_PREFIX="v10_chunk_credit_fallback_retry_exercise"
CONTRACT_PREFIX="v10_teacher_label_contract"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_chunk_credit_distillation_gate_smoke"
  POLICY_PREFIX="v10_chunk_credit_abstain_policy_smoke"
  JOINT_PREFIX="v10_chunk_credit_source_robustness_smoke"
  FALLBACK_PREFIX="v10_chunk_credit_fallback_retry_exercise_smoke"
  CONTRACT_PREFIX="v10_teacher_label_contract_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

POLICY_CSV="$RESULTS_DIR/${POLICY_PREFIX}_policy.csv"
JOINT_AGG_CSV="$RESULTS_DIR/${JOINT_PREFIX}_aggregate.csv"
FALLBACK_AGG_CSV="$RESULTS_DIR/${FALLBACK_PREFIX}_aggregate.csv"
CONTRACT_SUMMARY_CSV="$RESULTS_DIR/${CONTRACT_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ ! -s "$POLICY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_chunk_credit_abstain_policy.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$JOINT_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_chunk_credit_source_robustness.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$FALLBACK_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_chunk_credit_fallback_retry_exercise.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$CONTRACT_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_teacher_label_contract.sh" "${RUN_ARGS[@]}" >/dev/null
fi

awk -F, -v policy_csv="$POLICY_CSV" -v joint_csv="$JOINT_AGG_CSV" -v fallback_csv="$FALLBACK_AGG_CSV" -v contract_csv="$CONTRACT_SUMMARY_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
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
  FILENAME == joint_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) jidx[$i] = i
    required_count = split("best_joint_arm chunk_ready source_safe fallback_not_keyshape_only fallback_retry_exercised joint_chunk_source_ready noisy_used noisy_selected retry_noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in jidx)) die("missing h10 distillation joint column: " required[i], 3)
    }
    next
  }
  FILENAME == joint_csv {
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
  FILENAME == fallback_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) fidx[$i] = i
    required_count = split("best_arm baseline_qacc best_qacc best_qacc_delta_vs_corrupt fallback_retry_exercised fallback_not_keyshape_only fallback_ready source_retry_used source_retry_success retry_raw_selected retry_noisy_selected noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in fidx)) die("missing h10 distillation fallback column: " required[i], 6)
    }
    next
  }
  FILENAME == fallback_csv {
    fallback_rows++
    fallback_exercise_arm = $fidx["best_arm"]
    fallback_baseline_qacc = $fidx["baseline_qacc"] + 0
    fallback_best_qacc = $fidx["best_qacc"] + 0
    fallback_qacc_delta = $fidx["best_qacc_delta_vs_corrupt"] + 0
    fallback_retry_exercised = $fidx["fallback_retry_exercised"] + 0
    fallback_not_keyshape_only_exercise = $fidx["fallback_not_keyshape_only"] + 0
    fallback_ready = $fidx["fallback_ready"] + 0
    fallback_retry_used = $fidx["source_retry_used"] + 0
    fallback_retry_success = $fidx["source_retry_success"] + 0
    fallback_retry_raw = $fidx["retry_raw_selected"] + 0
    fallback_retry_noisy = $fidx["retry_noisy_selected"] + 0
    fallback_noisy_selected = $fidx["noisy_selected"] + 0
    fallback_routing = $fidx["routing_trigger_rate"] + 0
    fallback_jump = $fidx["active_jump_rate"] + 0
    next
  }
  FILENAME == contract_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) cidx[$i] = i
    required_count = split("correct_labels wrong_labels near_miss_labels missing_query_labels abstain_labels grounded_span_coverage teacher_label_contract_ready teacher_label_collection_ready teacher_external_labels_ready distillation_training_ready label_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in cidx)) die("missing h10 distillation teacher contract column: " required[i], 8)
    }
    next
  }
  FILENAME == contract_csv {
    contract_rows++
    teacher_correct_labels = $cidx["correct_labels"] + 0
    teacher_wrong_labels = $cidx["wrong_labels"] + 0
    teacher_near_miss_labels = $cidx["near_miss_labels"] + 0
    teacher_missing_query_labels = $cidx["missing_query_labels"] + 0
    teacher_abstain_labels = $cidx["abstain_labels"] + 0
    teacher_grounded_span_coverage = $cidx["grounded_span_coverage"] + 0
    teacher_label_contract_ready = $cidx["teacher_label_contract_ready"] + 0
    teacher_label_collection_ready = $cidx["teacher_label_collection_ready"] + 0
    teacher_external_labels_ready = $cidx["teacher_external_labels_ready"] + 0
    teacher_distillation_training_ready = $cidx["distillation_training_ready"] + 0
    teacher_label_source = $cidx["label_source"]
    teacher_routing = $cidx["routing_trigger_rate"] + 0
    teacher_jump = $cidx["active_jump_rate"] + 0
    next
  }
  END {
    if (policy_rows != 1) die("expected one h10 distillation policy row", 4)
    if (joint_rows != 1) die("expected one h10 distillation joint row", 5)
    if (fallback_rows != 1) die("expected one h10 distillation fallback row", 7)
    if (contract_rows != 1) die("expected one h10 distillation teacher contract row", 9)

    noisy_clean = 0
    if (noisy_selection_clean &&
        joint_noisy_used > 0.0 &&
        joint_noisy_selected == 0.0 &&
        joint_retry_noisy_selected == 0.0) {
      noisy_clean = 1
    }

    fallback_non_keyshape = 0
    if (fallback_not_keyshape_only &&
        joint_fallback_not_keyshape_only &&
        fallback_not_keyshape_only_exercise) {
      fallback_non_keyshape = 1
    }

    fallback_gate = 0
    if (fallback_ready &&
        fallback_retry_exercised &&
        fallback_non_keyshape &&
        fallback_retry_used > 0.0 &&
        fallback_retry_success > 0.0 &&
        fallback_retry_raw > 0.0 &&
        fallback_retry_noisy == 0.0 &&
        fallback_noisy_selected == 0.0 &&
        fallback_qacc_delta > 0.05 &&
        fallback_routing == 0.0 &&
        fallback_jump == 0.0) {
      fallback_gate = 1
    }

    distillation_ready = 0
    if (chunk_credit_ready &&
        source_safe &&
        joint_chunk_ready &&
        joint_source_safe &&
        noisy_clean &&
        fallback_gate &&
        teacher_label_contract_ready &&
        teacher_label_collection_ready &&
        teacher_external_labels_ready &&
        teacher_distillation_training_ready &&
        teacher_grounded_span_coverage == 1.0 &&
        policy_routing == 0.0 &&
        policy_jump == 0.0 &&
        joint_routing == 0.0 &&
        joint_jump == 0.0 &&
        fallback_routing == 0.0 &&
        fallback_jump == 0.0 &&
        teacher_routing == 0.0 &&
        teacher_jump == 0.0) {
      distillation_ready = 1
    }
    status = distillation_ready ? "distillation-candidate" : "diagnostic-only"
    reason = "all-gates-ready"
    if (!fallback_gate) {
      reason = "fallback-retry-unexercised"
    } else if (!teacher_label_contract_ready) {
      reason = "teacher-label-contract-missing"
    } else if (!teacher_label_collection_ready || !teacher_external_labels_ready) {
      reason = "teacher-label-collection-missing"
    } else if (!teacher_distillation_training_ready) {
      reason = "teacher-distillation-training-missing"
    }

    print "best_joint_arm,fallback_exercise_arm,guardrail_action,chunk_credit_ready,joint_chunk_ready,source_safe,joint_source_safe,noisy_clean,fallback_not_keyshape_only,fallback_retry_exercised,fallback_exercise_ready,fallback_baseline_qacc,fallback_best_qacc,fallback_qacc_delta_vs_corrupt,fallback_retry_used,fallback_retry_success,fallback_retry_raw_selected,fallback_retry_noisy_selected,fallback_noisy_selected,joint_chunk_source_ready,teacher_label_contract_ready,teacher_label_collection_ready,teacher_external_labels_ready,teacher_distillation_training_ready,teacher_grounded_span_coverage,teacher_label_source,teacher_correct_labels,teacher_wrong_labels,teacher_near_miss_labels,teacher_missing_query_labels,teacher_abstain_labels,policy_distillation_ready,combined_ready,distillation_ready,default_promotion,diagnostic_only,weak_hint_or_abstain,status,reason,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%d,%.6f,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%.6f,%.6f\n",
      best_joint_arm,
      fallback_exercise_arm,
      guardrail_action,
      chunk_credit_ready,
      joint_chunk_ready,
      source_safe,
      joint_source_safe,
      noisy_clean,
      fallback_non_keyshape,
      fallback_retry_exercised,
      fallback_ready,
      fallback_baseline_qacc,
      fallback_best_qacc,
      fallback_qacc_delta,
      fallback_retry_used,
      fallback_retry_success,
      fallback_retry_raw,
      fallback_retry_noisy,
      fallback_noisy_selected,
      joint_chunk_source_ready,
      teacher_label_contract_ready,
      teacher_label_collection_ready,
      teacher_external_labels_ready,
      teacher_distillation_training_ready,
      teacher_grounded_span_coverage,
      teacher_label_source,
      teacher_correct_labels,
      teacher_wrong_labels,
      teacher_near_miss_labels,
      teacher_missing_query_labels,
      teacher_abstain_labels,
      policy_distillation_ready,
      policy_combined_ready,
      distillation_ready,
      default_promotion,
      diagnostic_only,
      weak_hint_or_abstain,
      status,
      reason,
      policy_routing + joint_routing + fallback_routing + teacher_routing,
      policy_jump + joint_jump + fallback_jump + teacher_jump >> summary_csv

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
      fallback_retry_exercised,
      fallback_non_keyshape >> decision_csv
    printf "teacher-label-contract,%s,required=correct_wrong_near_miss_missing_abstain_grounded_span\n",
      teacher_label_contract_ready ? "pass" : "blocked" >> decision_csv
    printf "teacher-label-collection,%s,source=%s external_ready=%d\n",
      teacher_label_collection_ready && teacher_external_labels_ready ? "pass" : "blocked",
      teacher_label_source,
      teacher_external_labels_ready >> decision_csv
    printf "teacher-distillation-training,%s,learner_ready=%d\n",
      teacher_distillation_training_ready ? "pass" : "blocked",
      teacher_distillation_training_ready >> decision_csv
    printf "distillation,%s,status=%s reason=%s\n",
      distillation_ready ? "pass" : "blocked",
      status,
      reason >> decision_csv
  }
' "$POLICY_CSV" "$JOINT_AGG_CSV" "$FALLBACK_AGG_CSV" "$CONTRACT_SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
