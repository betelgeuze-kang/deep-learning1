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

PREFIX="v12_paper_release_claim_audit"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v12_paper_release_claim_audit_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v12_paper_release_claim_audit_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v11_nvme_route_memory_store.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v07_route_memory_promotion_review_gate.sh" "${RUN_ARGS[@]}" >/dev/null

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

H7C_SUMMARY_CSV="$(summary_path "v07_route_memory_promotion_review_gate")"
H10R_SUMMARY_CSV="$(summary_path "v10_real_teacher_source_import_review")"
H10S_SUMMARY_CSV="$(summary_path "v10_source_verified_learned_chunk_scorer_eval_gate")"
V08AB_SUMMARY_CSV="$(summary_path "v08_external_benchmark_codebase_mini")"
H11C_SUMMARY_CSV="$(summary_path "v11_nvme_route_memory_store")"
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
        print "missing v12 audit column: " column > "/dev/stderr"
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
        print "missing v12 audit row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

float_sum7() {
  awk -v a="$1" -v b="$2" -v c="$3" -v d="$4" -v e="$5" -v f="$6" -v g="$7" 'BEGIN {
    printf "%.6f", (a + 0) + (b + 0) + (c + 0) + (d + 0) + (e + 0) + (f + 0) + (g + 0)
  }'
}

h7c_promotion_review_contract_ready="$(csv_value "$H7C_SUMMARY_CSV" "promotion_review_contract_ready")"
h7c_real_evidence_complete="$(csv_value "$H7C_SUMMARY_CSV" "real_evidence_complete")"
h7c_promotion_review_ready="$(csv_value "$H7C_SUMMARY_CSV" "promotion_review_ready")"
h7c_default_promotion="$(csv_value "$H7C_SUMMARY_CSV" "default_promotion")"
h7c_action="$(csv_value "$H7C_SUMMARY_CSV" "action")"
h7c_routing="$(csv_value "$H7C_SUMMARY_CSV" "routing_trigger_rate")"
h7c_jump="$(csv_value "$H7C_SUMMARY_CSV" "active_jump_rate")"

h10r_real_teacher_source_verified="$(csv_value "$H10R_SUMMARY_CSV" "real_teacher_source_verified")"
h10r_import_review_ready="$(csv_value "$H10R_SUMMARY_CSV" "real_teacher_source_import_review_ready")"
h10r_routing="$(csv_value "$H10R_SUMMARY_CSV" "routing_trigger_rate")"
h10r_jump="$(csv_value "$H10R_SUMMARY_CSV" "active_jump_rate")"

h10s_source_verified_eval_ready="$(csv_value "$H10S_SUMMARY_CSV" "source_verified_learned_chunk_scorer_eval_ready")"
h10s_student_eval_ready="$(csv_value "$H10S_SUMMARY_CSV" "student_only_eval_ready")"
h10s_metric_improvement_ready="$(csv_value "$H10S_SUMMARY_CSV" "metric_improvement_ready")"
h10s_routing="$(csv_value "$H10S_SUMMARY_CSV" "routing_trigger_rate")"
h10s_jump="$(csv_value "$H10S_SUMMARY_CSV" "active_jump_rate")"

v08ab_codebase_mini_source_ready="$(csv_value "$V08AB_SUMMARY_CSV" "codebase_mini_source_ready")"
v08ab_benchmark_result_artifact_verified="$(csv_value "$V08AB_SUMMARY_CSV" "benchmark_result_artifact_verified")"
v08ab_baseline_comparison_ready="$(csv_value "$V08AB_SUMMARY_CSV" "baseline_comparison_ready")"
v08ab_real_external_benchmark_verified="$(csv_value "$V08AB_SUMMARY_CSV" "real_external_benchmark_verified")"
v08ab_span_exact="$(csv_value "$V08AB_SUMMARY_CSV" "span_exact")"
v08ab_chunk_exact="$(csv_value "$V08AB_SUMMARY_CSV" "chunk_exact")"
v08ab_missing_abstain="$(csv_value "$V08AB_SUMMARY_CSV" "missing_abstain")"
v08ab_wrong_answer_rate="$(csv_value "$V08AB_SUMMARY_CSV" "wrong_answer_rate")"
v08ab_routing="$(csv_value "$V08AB_SUMMARY_CSV" "routing_trigger_rate")"
v08ab_jump="$(csv_value "$V08AB_SUMMARY_CSV" "active_jump_rate")"

h11c_route_memory_artifact_chain_verified="$(csv_value "$H11C_SUMMARY_CSV" "route_memory_artifact_chain_verified")"
h11c_route_lookup_works="$(csv_value "$H11C_SUMMARY_CSV" "route_lookup_works")"
h11c_candidate_span_read_works="$(csv_value "$H11C_SUMMARY_CSV" "candidate_span_read_works")"
h11c_real_pc_routelm_artifact_verified="$(csv_value "$H11C_SUMMARY_CSV" "real_pc_routelm_artifact_verified")"
h11c_routing="$(csv_value "$H11C_SUMMARY_CSV" "routing_trigger_rate")"
h11c_jump="$(csv_value "$H11C_SUMMARY_CSV" "active_jump_rate")"

h11d_pc_routelm_nlg_smoke_ready="$(csv_value "$H11D_SUMMARY_CSV" "pc_routelm_nlg_smoke_ready")"
h11d_real_pc_routelm_nlg_verified="$(csv_value "$H11D_SUMMARY_CSV" "real_pc_routelm_nlg_verified")"
h11d_teacher_off_inference="$(csv_value "$H11D_SUMMARY_CSV" "teacher_off_inference")"
h11d_retrieved_evidence_used="$(csv_value "$H11D_SUMMARY_CSV" "retrieved_evidence_used")"
h11d_wrong_answer_rate="$(csv_value "$H11D_SUMMARY_CSV" "wrong_answer_rate")"
h11d_routing="$(csv_value "$H11D_SUMMARY_CSV" "routing_trigger_rate")"
h11d_jump="$(csv_value "$H11D_SUMMARY_CSV" "active_jump_rate")"

h9h_diagnostic_workload_speed_ready="$(csv_value "$H9H_SUMMARY_CSV" "diagnostic_workload_speed_ready")"
h9h_real_workload_speed_evidence_ready="$(csv_value "$H9H_SUMMARY_CSV" "real_workload_speed_evidence_ready")"
h9h_gpu_speedup_claim="$(csv_value "$H9H_SUMMARY_CSV" "gpu_speedup_claim")"
h9h_routing="$(csv_value "$H9H_SUMMARY_CSV" "routing_trigger_rate")"
h9h_jump="$(csv_value "$H9H_SUMMARY_CSV" "active_jump_rate")"

routing_trigger_rate="$(float_sum7 "$h7c_routing" "$h10r_routing" "$h10s_routing" "$v08ab_routing" "$h11c_routing" "$h11d_routing" "$h9h_routing")"
active_jump_rate="$(float_sum7 "$h7c_jump" "$h10r_jump" "$h10s_jump" "$v08ab_jump" "$h11c_jump" "$h11d_jump" "$h9h_jump")"

diagnostic_release_package_ready=0
if [[ "$h7c_promotion_review_contract_ready" == "1" &&
      "$h11c_route_memory_artifact_chain_verified" == "1" &&
      "$h11c_route_lookup_works" == "1" &&
      "$h11c_candidate_span_read_works" == "1" &&
      "$v08ab_codebase_mini_source_ready" == "1" &&
      "$v08ab_benchmark_result_artifact_verified" == "1" &&
      "$v08ab_baseline_comparison_ready" == "1" &&
      "$h11d_pc_routelm_nlg_smoke_ready" == "1" &&
      "$h11d_teacher_off_inference" == "1" &&
      "$h11d_retrieved_evidence_used" == "1" &&
      "$h9h_diagnostic_workload_speed_ready" == "1" &&
      "$routing_trigger_rate" == "0.000000" &&
      "$active_jump_rate" == "0.000000" ]]; then
  diagnostic_release_package_ready=1
fi

real_release_package_ready=0
if [[ "$diagnostic_release_package_ready" == "1" &&
      "$h10r_real_teacher_source_verified" == "1" &&
      "$h10s_source_verified_eval_ready" == "1" &&
      "$v08ab_real_external_benchmark_verified" == "1" &&
      "$h11c_real_pc_routelm_artifact_verified" == "1" &&
      "$h11d_real_pc_routelm_nlg_verified" == "1" &&
      "$h9h_real_workload_speed_evidence_ready" == "1" &&
      "$h7c_real_evidence_complete" == "1" &&
      "$h7c_promotion_review_ready" == "1" &&
      "$h7c_default_promotion" == "1" ]]; then
  real_release_package_ready=1
fi

diagnostic_claim_level=0
if [[ "$h11c_route_memory_artifact_chain_verified" == "1" ]]; then
  diagnostic_claim_level=1
fi
if [[ "$v08ab_codebase_mini_source_ready" == "1" &&
      "$v08ab_benchmark_result_artifact_verified" == "1" ]]; then
  diagnostic_claim_level=2
fi
if [[ "$h10s_metric_improvement_ready" == "1" &&
      "$h10s_student_eval_ready" == "1" ]]; then
  diagnostic_claim_level=3
fi
if [[ "$h11d_pc_routelm_nlg_smoke_ready" == "1" &&
      "$h9h_diagnostic_workload_speed_ready" == "1" ]]; then
  diagnostic_claim_level=4
fi
if [[ "$h7c_promotion_review_ready" == "1" ]]; then
  diagnostic_claim_level=5
fi

publishable_claim_level=0
if [[ "$real_release_package_ready" == "1" ]]; then
  publishable_claim_level=5
fi

release_claim="diagnostic-artifact-package-only"
action="release-package-real-evidence-missing"
if [[ "$diagnostic_release_package_ready" != "1" ]]; then
  release_claim="incomplete-diagnostic-package"
  action="release-package-diagnostic-evidence-missing"
elif [[ "$real_release_package_ready" == "1" ]]; then
  release_claim="publishable-route-memory-candidate"
  action="release-package-ready"
fi

forbidden_transformer_replacement_claim="blocked"
forbidden_frontier_pc_llm_claim="blocked"
forbidden_long_context_solved_claim="blocked"
forbidden_learned_sparse_routing_claim="blocked"
forbidden_gpu_acceleration_claim="blocked"
if [[ "$real_release_package_ready" == "1" &&
      "$h9h_gpu_speedup_claim" != "deferred" ]]; then
  forbidden_gpu_acceleration_claim="review-required"
fi

{
  echo "release_audit_scope,review_source,diagnostic_release_package_ready,real_release_package_ready,diagnostic_claim_level,publishable_claim_level,release_claim,h7c_promotion_review_contract_ready,h7c_real_evidence_complete,h7c_promotion_review_ready,h7c_default_promotion,h7c_action,h10r_real_teacher_source_verified,h10r_import_review_ready,h10s_source_verified_eval_ready,h10s_student_eval_ready,h10s_metric_improvement_ready,v08ab_codebase_mini_source_ready,v08ab_benchmark_result_artifact_verified,v08ab_baseline_comparison_ready,v08ab_real_external_benchmark_verified,v08ab_span_exact,v08ab_chunk_exact,v08ab_missing_abstain,v08ab_wrong_answer_rate,h11c_route_memory_artifact_chain_verified,h11c_real_pc_routelm_artifact_verified,h11d_pc_routelm_nlg_smoke_ready,h11d_real_pc_routelm_nlg_verified,h11d_wrong_answer_rate,h9h_diagnostic_workload_speed_ready,h9h_real_workload_speed_evidence_ready,h9h_gpu_speedup_claim,forbidden_transformer_replacement_claim,forbidden_frontier_pc_llm_claim,forbidden_long_context_solved_claim,forbidden_learned_sparse_routing_claim,forbidden_gpu_acceleration_claim,action,routing_trigger_rate,active_jump_rate"
  printf "v12-paper-release-claim-audit,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%.6f,%d,%d,%s,%s,%s,%s,%s,%s,%s,%.6f,%.6f\n" \
    "$MODE" \
    "$diagnostic_release_package_ready" \
    "$real_release_package_ready" \
    "$diagnostic_claim_level" \
    "$publishable_claim_level" \
    "$release_claim" \
    "$h7c_promotion_review_contract_ready" \
    "$h7c_real_evidence_complete" \
    "$h7c_promotion_review_ready" \
    "$h7c_default_promotion" \
    "$h7c_action" \
    "$h10r_real_teacher_source_verified" \
    "$h10r_import_review_ready" \
    "$h10s_source_verified_eval_ready" \
    "$h10s_student_eval_ready" \
    "$h10s_metric_improvement_ready" \
    "$v08ab_codebase_mini_source_ready" \
    "$v08ab_benchmark_result_artifact_verified" \
    "$v08ab_baseline_comparison_ready" \
    "$v08ab_real_external_benchmark_verified" \
    "$v08ab_span_exact" \
    "$v08ab_chunk_exact" \
    "$v08ab_missing_abstain" \
    "$v08ab_wrong_answer_rate" \
    "$h11c_route_memory_artifact_chain_verified" \
    "$h11c_real_pc_routelm_artifact_verified" \
    "$h11d_pc_routelm_nlg_smoke_ready" \
    "$h11d_real_pc_routelm_nlg_verified" \
    "$h11d_wrong_answer_rate" \
    "$h9h_diagnostic_workload_speed_ready" \
    "$h9h_real_workload_speed_evidence_ready" \
    "$h9h_gpu_speedup_claim" \
    "$forbidden_transformer_replacement_claim" \
    "$forbidden_frontier_pc_llm_claim" \
    "$forbidden_long_context_solved_claim" \
    "$forbidden_learned_sparse_routing_claim" \
    "$forbidden_gpu_acceleration_claim" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "nvme-route-memory-artifact,%s,chain=%d route_lookup=%d span_read=%d\n" \
    "$([[ "$h11c_route_memory_artifact_chain_verified" == "1" && "$h11c_route_lookup_works" == "1" && "$h11c_candidate_span_read_works" == "1" ]] && echo pass || echo blocked)" \
    "$h11c_route_memory_artifact_chain_verified" \
    "$h11c_route_lookup_works" \
    "$h11c_candidate_span_read_works"
  printf "codebase-mini-instrumentation,%s,source=%d result=%d baseline=%d real=%d\n" \
    "$([[ "$v08ab_codebase_mini_source_ready" == "1" && "$v08ab_benchmark_result_artifact_verified" == "1" && "$v08ab_baseline_comparison_ready" == "1" ]] && echo pass || echo blocked)" \
    "$v08ab_codebase_mini_source_ready" \
    "$v08ab_benchmark_result_artifact_verified" \
    "$v08ab_baseline_comparison_ready" \
    "$v08ab_real_external_benchmark_verified"
  printf "teacher-source-real,%s,real=%d import_review=%d\n" \
    "$([[ "$h10r_real_teacher_source_verified" == "1" ]] && echo pass || echo blocked)" \
    "$h10r_real_teacher_source_verified" \
    "$h10r_import_review_ready"
  printf "source-verified-scorer-real,%s,eval_ready=%d student_eval=%d metric=%d\n" \
    "$([[ "$h10s_source_verified_eval_ready" == "1" ]] && echo pass || echo blocked)" \
    "$h10s_source_verified_eval_ready" \
    "$h10s_student_eval_ready" \
    "$h10s_metric_improvement_ready"
  printf "pc-routelm-nlg-real,%s,smoke=%d real=%d\n" \
    "$([[ "$h11d_real_pc_routelm_nlg_verified" == "1" ]] && echo pass || echo blocked)" \
    "$h11d_pc_routelm_nlg_smoke_ready" \
    "$h11d_real_pc_routelm_nlg_verified"
  printf "workload-speed-real,%s,diagnostic=%d real=%d claim=%s\n" \
    "$([[ "$h9h_real_workload_speed_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$h9h_diagnostic_workload_speed_ready" \
    "$h9h_real_workload_speed_evidence_ready" \
    "$h9h_gpu_speedup_claim"
  printf "promotion-review,%s,contract=%d ready=%d default=%d action=%s\n" \
    "$([[ "$h7c_promotion_review_ready" == "1" && "$h7c_default_promotion" == "1" ]] && echo pass || echo blocked)" \
    "$h7c_promotion_review_contract_ready" \
    "$h7c_promotion_review_ready" \
    "$h7c_default_promotion" \
    "$h7c_action"
  printf "diagnostic-release-package,%s,diagnostic_level=%d release_claim=%s\n" \
    "$([[ "$diagnostic_release_package_ready" == "1" ]] && echo pass || echo blocked)" \
    "$diagnostic_claim_level" \
    "$release_claim"
  printf "publishable-release-package,%s,publishable_level=%d real_ready=%d action=%s\n" \
    "$([[ "$real_release_package_ready" == "1" ]] && echo pass || echo blocked)" \
    "$publishable_claim_level" \
    "$real_release_package_ready" \
    "$action"
  printf "forbidden-claims,%s,transformer=%s frontier_pc_llm=%s long_context=%s learned_sparse=%s gpu=%s\n" \
    "$([[ "$forbidden_transformer_replacement_claim" == "blocked" && "$forbidden_frontier_pc_llm_claim" == "blocked" && "$forbidden_long_context_solved_claim" == "blocked" && "$forbidden_learned_sparse_routing_claim" == "blocked" && "$forbidden_gpu_acceleration_claim" == "blocked" ]] && echo pass || echo review-required)" \
    "$forbidden_transformer_replacement_claim" \
    "$forbidden_frontier_pc_llm_claim" \
    "$forbidden_long_context_solved_claim" \
    "$forbidden_learned_sparse_routing_claim" \
    "$forbidden_gpu_acceleration_claim"
  printf "jump-guardrail,%s,routing=%.6f active_jump=%.6f\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
