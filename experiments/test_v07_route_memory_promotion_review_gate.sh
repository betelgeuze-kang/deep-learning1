#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v07_route_memory_promotion_review_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v07_route_memory_promotion_review_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v07_route_memory_promotion_review_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("promotion_review_contract_ready h7_default_promotion real_teacher_source_verified real_teacher_source_import_review_ready source_verified_learned_chunk_scorer_eval_ready student_only_eval_ready metric_improvement_ready real_external_benchmark_verified codebase_mini_source_ready benchmark_result_artifact_verified baseline_comparison_ready external_span_exact external_chunk_exact external_missing_abstain external_wrong_answer_rate real_pc_routelm_nlg_verified pc_routelm_nlg_smoke_ready teacher_off_inference answer_grounded_rate span_citation_accuracy nlg_wrong_answer_rate real_workload_speed_evidence_ready diagnostic_workload_speed_ready gpu_speedup_claim wrong_answer_threshold_met external_thresholds_met nlg_thresholds_met real_evidence_complete promotion_review_ready default_promotion promotion_decision action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h7-c promotion review column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h7-c promotion review row has wrong column count", 3)
    if (($idx["promotion_review_contract_ready"] + 0) != 1 ||
        ($idx["h7_default_promotion"] + 0) != 0 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        ($idx["real_teacher_source_import_review_ready"] + 0) != 0 ||
        ($idx["source_verified_learned_chunk_scorer_eval_ready"] + 0) != 0 ||
        ($idx["student_only_eval_ready"] + 0) != 0 ||
        ($idx["metric_improvement_ready"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        ($idx["codebase_mini_source_ready"] + 0) != 1 ||
        ($idx["benchmark_result_artifact_verified"] + 0) != 1 ||
        ($idx["baseline_comparison_ready"] + 0) != 1 ||
        ($idx["external_span_exact"] + 0) < 0.85 ||
        ($idx["external_chunk_exact"] + 0) < 0.75 ||
        ($idx["external_missing_abstain"] + 0) < 0.90 ||
        ($idx["external_wrong_answer_rate"] + 0) > 0.05 ||
        ($idx["real_pc_routelm_nlg_verified"] + 0) != 0 ||
        ($idx["pc_routelm_nlg_smoke_ready"] + 0) != 1 ||
        ($idx["teacher_off_inference"] + 0) != 1 ||
        ($idx["answer_grounded_rate"] + 0) < 0.80 ||
        ($idx["span_citation_accuracy"] + 0) < 0.80 ||
        ($idx["nlg_wrong_answer_rate"] + 0) > 0.05 ||
        ($idx["real_workload_speed_evidence_ready"] + 0) != 0 ||
        ($idx["diagnostic_workload_speed_ready"] + 0) != 1 ||
        $idx["gpu_speedup_claim"] != "deferred" ||
        ($idx["wrong_answer_threshold_met"] + 0) != 1 ||
        ($idx["external_thresholds_met"] + 0) != 1 ||
        ($idx["nlg_thresholds_met"] + 0) != 1 ||
        ($idx["real_evidence_complete"] + 0) != 0 ||
        ($idx["promotion_review_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["promotion_decision"] != "blocked" ||
        $idx["action"] != "promotion-review-real-evidence-missing") {
      die("h7-c should pass review contract but block promotion on missing real evidence", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h7-c promotion review", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h7-c promotion review summary row", 6)
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
    if ($idx["gate"] == "thresholds" && $idx["status"] != "pass") die("h7-c thresholds should pass for diagnostic fixtures", 20)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("h7-c jump guardrail should pass", 21)
    if ($idx["gate"] == "teacher-source" && $idx["status"] != "blocked") die("h7-c teacher source should block", 22)
    if ($idx["gate"] == "source-verified-scorer" && $idx["status"] != "blocked") die("h7-c scorer should block", 23)
    if ($idx["gate"] == "external-benchmark" && $idx["status"] != "blocked") die("h7-c external benchmark should block as non-real", 24)
    if ($idx["gate"] == "pc-routelm-nlg" && $idx["status"] != "blocked") die("h7-c PC RouteLM NLG should block as non-real", 25)
    if ($idx["gate"] == "workload-speed" && $idx["status"] != "blocked") die("h7-c workload speed should block as non-real", 26)
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") die("h7-c default promotion should block", 27)
  }
  END {
    if (rows != 9) die("expected h7-c decision rows", 28)
  }
' "$DECISION_CSV"

echo "v07 route-memory promotion review gate smoke passed"
