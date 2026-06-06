#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v12_paper_release_claim_audit.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v12_paper_release_claim_audit_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v12_paper_release_claim_audit_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("diagnostic_release_package_ready real_release_package_ready diagnostic_claim_level publishable_claim_level release_claim h7c_promotion_review_contract_ready h7c_real_evidence_complete h7c_promotion_review_ready h7c_default_promotion h10r_real_teacher_source_verified h10r_import_review_ready h10s_source_verified_eval_ready h10s_student_eval_ready h10s_metric_improvement_ready v08ab_codebase_mini_source_ready v08ab_benchmark_result_artifact_verified v08ab_baseline_comparison_ready v08ab_real_external_benchmark_verified h11c_route_memory_artifact_chain_verified h11c_real_pc_routelm_artifact_verified h11d_pc_routelm_nlg_smoke_ready h11d_real_pc_routelm_nlg_verified h9h_diagnostic_workload_speed_ready h9h_real_workload_speed_evidence_ready h9h_gpu_speedup_claim forbidden_transformer_replacement_claim forbidden_frontier_pc_llm_claim forbidden_long_context_solved_claim forbidden_learned_sparse_routing_claim forbidden_gpu_acceleration_claim action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v12 audit summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("v12 audit summary row has wrong column count", 3)
    if (($idx["diagnostic_release_package_ready"] + 0) != 1 ||
        ($idx["real_release_package_ready"] + 0) != 0 ||
        ($idx["diagnostic_claim_level"] + 0) != 4 ||
        ($idx["publishable_claim_level"] + 0) != 0 ||
        $idx["release_claim"] != "diagnostic-artifact-package-only" ||
        ($idx["h7c_promotion_review_contract_ready"] + 0) != 1 ||
        ($idx["h7c_real_evidence_complete"] + 0) != 0 ||
        ($idx["h7c_promotion_review_ready"] + 0) != 0 ||
        ($idx["h7c_default_promotion"] + 0) != 0 ||
        ($idx["h10r_real_teacher_source_verified"] + 0) != 0 ||
        ($idx["h10r_import_review_ready"] + 0) != 0 ||
        ($idx["h10s_source_verified_eval_ready"] + 0) != 0 ||
        ($idx["h10s_student_eval_ready"] + 0) != 0 ||
        ($idx["h10s_metric_improvement_ready"] + 0) != 0 ||
        ($idx["v08ab_codebase_mini_source_ready"] + 0) != 1 ||
        ($idx["v08ab_benchmark_result_artifact_verified"] + 0) != 1 ||
        ($idx["v08ab_baseline_comparison_ready"] + 0) != 1 ||
        ($idx["v08ab_real_external_benchmark_verified"] + 0) != 0 ||
        ($idx["h11c_route_memory_artifact_chain_verified"] + 0) != 1 ||
        ($idx["h11c_real_pc_routelm_artifact_verified"] + 0) != 0 ||
        ($idx["h11d_pc_routelm_nlg_smoke_ready"] + 0) != 1 ||
        ($idx["h11d_real_pc_routelm_nlg_verified"] + 0) != 0 ||
        ($idx["h9h_diagnostic_workload_speed_ready"] + 0) != 1 ||
        ($idx["h9h_real_workload_speed_evidence_ready"] + 0) != 0 ||
        $idx["h9h_gpu_speedup_claim"] != "deferred" ||
        $idx["forbidden_transformer_replacement_claim"] != "blocked" ||
        $idx["forbidden_frontier_pc_llm_claim"] != "blocked" ||
        $idx["forbidden_long_context_solved_claim"] != "blocked" ||
        $idx["forbidden_learned_sparse_routing_claim"] != "blocked" ||
        $idx["forbidden_gpu_acceleration_claim"] != "blocked" ||
        $idx["action"] != "release-package-real-evidence-missing") {
      die("v12 should expose a diagnostic package while blocking publishable claims", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v12 audit", 5)
    }
  }
  END {
    if (rows != 1) die("expected one v12 audit summary row", 6)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    if ($idx["gate"] == "nvme-route-memory-artifact" && $idx["status"] != "pass") die("v12 NVMe artifact should pass", 20)
    if ($idx["gate"] == "codebase-mini-instrumentation" && $idx["status"] != "pass") die("v12 codebase-mini instrumentation should pass", 21)
    if ($idx["gate"] == "diagnostic-release-package" && $idx["status"] != "pass") die("v12 diagnostic release package should pass", 22)
    if ($idx["gate"] == "forbidden-claims" && $idx["status"] != "pass") die("v12 forbidden claims should be blocked", 23)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v12 jump guardrail should pass", 24)
    if ($idx["gate"] == "teacher-source-real" && $idx["status"] != "blocked") die("v12 teacher source should block", 25)
    if ($idx["gate"] == "source-verified-scorer-real" && $idx["status"] != "blocked") die("v12 source-verified scorer should block", 26)
    if ($idx["gate"] == "pc-routelm-nlg-real" && $idx["status"] != "blocked") die("v12 real NLG should block", 27)
    if ($idx["gate"] == "workload-speed-real" && $idx["status"] != "blocked") die("v12 real workload speed should block", 28)
    if ($idx["gate"] == "promotion-review" && $idx["status"] != "blocked") die("v12 promotion review should block", 29)
    if ($idx["gate"] == "publishable-release-package" && $idx["status"] != "blocked") die("v12 publishable release should block", 30)
  }
  END {
    if (rows != 11) die("expected v12 decision rows", 31)
  }
' "$DECISION_CSV"

echo "v12 paper/release claim audit smoke passed"
