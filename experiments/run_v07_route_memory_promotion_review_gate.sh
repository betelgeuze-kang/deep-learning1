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

PREFIX="v07_route_memory_promotion_review_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v07_route_memory_promotion_review_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v07_route_memory_promotion_review_gate_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v07_route_memory_promotion_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v10_real_teacher_source_import_review.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_codebase_mini.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v11_pc_routelm_nlg_smoke.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v09_gpu_backend_real_workload_speed_gate.sh" "${RUN_ARGS[@]}" >/dev/null

summary_path() {
  local base="$1"
  if [[ "$MODE" == "smoke" ]]; then
    printf '%s/%s_smoke_summary.csv\n' "$RESULTS_DIR" "$base"
  elif [[ "$MODE" == "full" ]]; then
    printf '%s/%s_full_summary.csv\n' "$RESULTS_DIR" "$base"
  else
    printf '%s/%s_summary.csv\n' "$RESULTS_DIR" "$base"
  fi
}

H7_SUMMARY_CSV="$(summary_path "v07_route_memory_promotion_gate")"
H10R_SUMMARY_CSV="$(summary_path "v10_real_teacher_source_import_review")"
H10S_SUMMARY_CSV="$(summary_path "v10_source_verified_learned_chunk_scorer_eval_gate")"
V08AB_SUMMARY_CSV="$(summary_path "v08_external_benchmark_codebase_mini")"
H11D_SUMMARY_CSV="$(summary_path "v11_pc_routelm_nlg_smoke")"
H9H_SUMMARY_CSV="$(summary_path "v09_gpu_backend_real_workload_speed_gate")"

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

csv_value() {
  local file="$1"
  local column="$2"
  awk -F, -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(column in idx)) {
        print "missing promotion review column: " column > "/dev/stderr"
        exit 11
      }
      next
    }
    NR == 2 {
      print $idx[column]
      found = 1
      exit
    }
    END {
      if (!found) {
        print "missing promotion review row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

float_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !((a + 0) >= (b + 0)) }'
}

float_le() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !((a + 0) <= (b + 0)) }'
}

float_sum() {
  awk -v a="$1" -v b="$2" -v c="$3" -v d="$4" -v e="$5" -v f="$6" 'BEGIN {
    printf "%.6f", (a + 0) + (b + 0) + (c + 0) + (d + 0) + (e + 0) + (f + 0)
  }'
}

h7_default_promotion="$(csv_value "$H7_SUMMARY_CSV" "default_promotion")"
h7_status="$(csv_value "$H7_SUMMARY_CSV" "status")"
h7_routing="$(csv_value "$H7_SUMMARY_CSV" "routing_trigger_rate")"
h7_jump="$(csv_value "$H7_SUMMARY_CSV" "active_jump_rate")"

real_teacher_source_verified="$(csv_value "$H10R_SUMMARY_CSV" "real_teacher_source_verified")"
real_teacher_source_import_review_ready="$(csv_value "$H10R_SUMMARY_CSV" "real_teacher_source_import_review_ready")"
h10r_action="$(csv_value "$H10R_SUMMARY_CSV" "action")"
h10r_routing="$(csv_value "$H10R_SUMMARY_CSV" "routing_trigger_rate")"
h10r_jump="$(csv_value "$H10R_SUMMARY_CSV" "active_jump_rate")"

source_verified_learned_chunk_scorer_eval_ready="$(csv_value "$H10S_SUMMARY_CSV" "source_verified_learned_chunk_scorer_eval_ready")"
student_only_eval_ready="$(csv_value "$H10S_SUMMARY_CSV" "student_only_eval_ready")"
metric_improvement_ready="$(csv_value "$H10S_SUMMARY_CSV" "metric_improvement_ready")"
h10s_reason="$(csv_value "$H10S_SUMMARY_CSV" "reason")"
h10s_routing="$(csv_value "$H10S_SUMMARY_CSV" "routing_trigger_rate")"
h10s_jump="$(csv_value "$H10S_SUMMARY_CSV" "active_jump_rate")"

real_external_benchmark_verified="$(csv_value "$V08AB_SUMMARY_CSV" "real_external_benchmark_verified")"
codebase_mini_source_ready="$(csv_value "$V08AB_SUMMARY_CSV" "codebase_mini_source_ready")"
benchmark_result_artifact_verified="$(csv_value "$V08AB_SUMMARY_CSV" "benchmark_result_artifact_verified")"
baseline_comparison_ready="$(csv_value "$V08AB_SUMMARY_CSV" "baseline_comparison_ready")"
external_span_exact="$(csv_value "$V08AB_SUMMARY_CSV" "span_exact")"
external_chunk_exact="$(csv_value "$V08AB_SUMMARY_CSV" "chunk_exact")"
external_missing_abstain="$(csv_value "$V08AB_SUMMARY_CSV" "missing_abstain")"
external_wrong_answer_rate="$(csv_value "$V08AB_SUMMARY_CSV" "wrong_answer_rate")"
v08ab_action="$(csv_value "$V08AB_SUMMARY_CSV" "action")"
v08ab_routing="$(csv_value "$V08AB_SUMMARY_CSV" "routing_trigger_rate")"
v08ab_jump="$(csv_value "$V08AB_SUMMARY_CSV" "active_jump_rate")"

real_pc_routelm_nlg_verified="$(csv_value "$H11D_SUMMARY_CSV" "real_pc_routelm_nlg_verified")"
pc_routelm_nlg_smoke_ready="$(csv_value "$H11D_SUMMARY_CSV" "pc_routelm_nlg_smoke_ready")"
teacher_off_inference="$(csv_value "$H11D_SUMMARY_CSV" "teacher_off_inference")"
answer_grounded_rate="$(csv_value "$H11D_SUMMARY_CSV" "answer_grounded_rate")"
span_citation_accuracy="$(csv_value "$H11D_SUMMARY_CSV" "span_citation_accuracy")"
nlg_wrong_answer_rate="$(csv_value "$H11D_SUMMARY_CSV" "wrong_answer_rate")"
h11d_action="$(csv_value "$H11D_SUMMARY_CSV" "action")"
h11d_routing="$(csv_value "$H11D_SUMMARY_CSV" "routing_trigger_rate")"
h11d_jump="$(csv_value "$H11D_SUMMARY_CSV" "active_jump_rate")"

real_workload_speed_evidence_ready="$(csv_value "$H9H_SUMMARY_CSV" "real_workload_speed_evidence_ready")"
diagnostic_workload_speed_ready="$(csv_value "$H9H_SUMMARY_CSV" "diagnostic_workload_speed_ready")"
gpu_speedup_claim="$(csv_value "$H9H_SUMMARY_CSV" "gpu_speedup_claim")"
h9_workload_action="$(csv_value "$H9H_SUMMARY_CSV" "action")"
h9h_routing="$(csv_value "$H9H_SUMMARY_CSV" "routing_trigger_rate")"
h9h_jump="$(csv_value "$H9H_SUMMARY_CSV" "active_jump_rate")"

routing_trigger_rate="$(float_sum "$h7_routing" "$h10r_routing" "$h10s_routing" "$v08ab_routing" "$h11d_routing" "$h9h_routing")"
active_jump_rate="$(float_sum "$h7_jump" "$h10r_jump" "$h10s_jump" "$v08ab_jump" "$h11d_jump" "$h9h_jump")"

promotion_review_contract_ready=0
if [[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]]; then
  promotion_review_contract_ready=1
fi

external_thresholds_met=0
if float_ge "$external_span_exact" "0.850000" &&
   float_ge "$external_chunk_exact" "0.750000" &&
   float_ge "$external_missing_abstain" "0.900000" &&
   float_le "$external_wrong_answer_rate" "0.050000"; then
  external_thresholds_met=1
fi

nlg_thresholds_met=0
if [[ "$teacher_off_inference" == "1" ]] &&
   float_ge "$answer_grounded_rate" "0.800000" &&
   float_ge "$span_citation_accuracy" "0.800000" &&
   float_le "$nlg_wrong_answer_rate" "0.050000"; then
  nlg_thresholds_met=1
fi

wrong_answer_threshold_met=0
if float_le "$external_wrong_answer_rate" "0.050000" &&
   float_le "$nlg_wrong_answer_rate" "0.050000"; then
  wrong_answer_threshold_met=1
fi

real_evidence_complete=0
if [[ "$real_teacher_source_verified" == "1" &&
      "$source_verified_learned_chunk_scorer_eval_ready" == "1" &&
      "$real_external_benchmark_verified" == "1" &&
      "$real_pc_routelm_nlg_verified" == "1" &&
      "$real_workload_speed_evidence_ready" == "1" ]]; then
  real_evidence_complete=1
fi

promotion_review_ready=0
if [[ "$promotion_review_contract_ready" == "1" &&
      "$external_thresholds_met" == "1" &&
      "$nlg_thresholds_met" == "1" &&
      "$wrong_answer_threshold_met" == "1" &&
      "$real_evidence_complete" == "1" ]]; then
  promotion_review_ready=1
fi

default_promotion=0
if [[ "$promotion_review_ready" == "1" && "$h7_default_promotion" == "1" ]]; then
  default_promotion=1
fi

promotion_decision="blocked"
action="promotion-review-real-evidence-missing"
if [[ "$promotion_review_contract_ready" != "1" ]]; then
  action="promotion-review-jump-guardrail-active"
elif [[ "$external_thresholds_met" != "1" ||
        "$nlg_thresholds_met" != "1" ||
        "$wrong_answer_threshold_met" != "1" ]]; then
  action="promotion-review-threshold-missing"
elif [[ "$real_evidence_complete" != "1" ]]; then
  action="promotion-review-real-evidence-missing"
elif [[ "$h7_default_promotion" != "1" ]]; then
  action="promotion-review-internal-promotion-blocked"
elif [[ "$default_promotion" == "1" ]]; then
  promotion_decision="promotion-candidate"
  action="promotion-review-candidate-ready"
fi

{
  echo "promotion_review_scope,review_source,promotion_review_contract_ready,h7_default_promotion,h7_status,real_teacher_source_verified,real_teacher_source_import_review_ready,h10r_action,source_verified_learned_chunk_scorer_eval_ready,student_only_eval_ready,metric_improvement_ready,h10s_reason,real_external_benchmark_verified,codebase_mini_source_ready,benchmark_result_artifact_verified,baseline_comparison_ready,external_span_exact,external_chunk_exact,external_missing_abstain,external_wrong_answer_rate,v08ab_action,real_pc_routelm_nlg_verified,pc_routelm_nlg_smoke_ready,teacher_off_inference,answer_grounded_rate,span_citation_accuracy,nlg_wrong_answer_rate,h11d_action,real_workload_speed_evidence_ready,diagnostic_workload_speed_ready,gpu_speedup_claim,h9_workload_action,wrong_answer_threshold_met,external_thresholds_met,nlg_thresholds_met,real_evidence_complete,promotion_review_ready,default_promotion,promotion_decision,action,routing_trigger_rate,active_jump_rate"
  printf "h7c-promotion-review,%s,%d,%d,%s,%d,%d,%s,%d,%d,%d,%s,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%s,%d,%d,%d,%.6f,%.6f,%.6f,%s,%d,%d,%s,%s,%d,%d,%d,%d,%d,%d,%s,%s,%.6f,%.6f\n" \
    "$MODE" \
    "$promotion_review_contract_ready" \
    "$h7_default_promotion" \
    "$h7_status" \
    "$real_teacher_source_verified" \
    "$real_teacher_source_import_review_ready" \
    "$h10r_action" \
    "$source_verified_learned_chunk_scorer_eval_ready" \
    "$student_only_eval_ready" \
    "$metric_improvement_ready" \
    "$h10s_reason" \
    "$real_external_benchmark_verified" \
    "$codebase_mini_source_ready" \
    "$benchmark_result_artifact_verified" \
    "$baseline_comparison_ready" \
    "$external_span_exact" \
    "$external_chunk_exact" \
    "$external_missing_abstain" \
    "$external_wrong_answer_rate" \
    "$v08ab_action" \
    "$real_pc_routelm_nlg_verified" \
    "$pc_routelm_nlg_smoke_ready" \
    "$teacher_off_inference" \
    "$answer_grounded_rate" \
    "$span_citation_accuracy" \
    "$nlg_wrong_answer_rate" \
    "$h11d_action" \
    "$real_workload_speed_evidence_ready" \
    "$diagnostic_workload_speed_ready" \
    "$gpu_speedup_claim" \
    "$h9_workload_action" \
    "$wrong_answer_threshold_met" \
    "$external_thresholds_met" \
    "$nlg_thresholds_met" \
    "$real_evidence_complete" \
    "$promotion_review_ready" \
    "$default_promotion" \
    "$promotion_decision" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "h7-internal,%s,default_promotion=%d status=%s\n" \
    "$([[ "$h7_default_promotion" == "1" ]] && echo pass || echo blocked)" \
    "$h7_default_promotion" \
    "$h7_status"
  printf "teacher-source,%s,real_teacher_source_verified=%d import_review_ready=%d action=%s\n" \
    "$([[ "$real_teacher_source_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_teacher_source_verified" \
    "$real_teacher_source_import_review_ready" \
    "$h10r_action"
  printf "source-verified-scorer,%s,eval_ready=%d metric_improvement=%d reason=%s\n" \
    "$([[ "$source_verified_learned_chunk_scorer_eval_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_verified_learned_chunk_scorer_eval_ready" \
    "$metric_improvement_ready" \
    "$h10s_reason"
  printf "external-benchmark,%s,real=%d result=%d thresholds=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" && "$external_thresholds_met" == "1" ]] && echo pass || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$benchmark_result_artifact_verified" \
    "$external_thresholds_met" \
    "$v08ab_action"
  printf "pc-routelm-nlg,%s,real=%d smoke=%d thresholds=%d action=%s\n" \
    "$([[ "$real_pc_routelm_nlg_verified" == "1" && "$nlg_thresholds_met" == "1" ]] && echo pass || echo blocked)" \
    "$real_pc_routelm_nlg_verified" \
    "$pc_routelm_nlg_smoke_ready" \
    "$nlg_thresholds_met" \
    "$h11d_action"
  printf "workload-speed,%s,real=%d diagnostic=%d claim=%s action=%s\n" \
    "$([[ "$real_workload_speed_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$real_workload_speed_evidence_ready" \
    "$diagnostic_workload_speed_ready" \
    "$gpu_speedup_claim" \
    "$h9_workload_action"
  printf "thresholds,%s,external=%d nlg=%d wrong=%d\n" \
    "$([[ "$external_thresholds_met" == "1" && "$nlg_thresholds_met" == "1" && "$wrong_answer_threshold_met" == "1" ]] && echo pass || echo blocked)" \
    "$external_thresholds_met" \
    "$nlg_thresholds_met" \
    "$wrong_answer_threshold_met"
  printf "jump-guardrail,%s,routing=%.6f active_jump=%.6f\n" \
    "$([[ "$promotion_review_contract_ready" == "1" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
  printf "default-promotion,%s,review_ready=%d default_promotion=%d action=%s\n" \
    "$([[ "$default_promotion" == "1" ]] && echo pass || echo blocked)" \
    "$promotion_review_ready" \
    "$default_promotion" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
