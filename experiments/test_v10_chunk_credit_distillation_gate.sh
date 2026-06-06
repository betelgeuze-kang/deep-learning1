#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_chunk_credit_distillation_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("best_joint_arm fallback_exercise_arm guardrail_action chunk_credit_ready joint_chunk_ready source_safe joint_source_safe noisy_clean fallback_not_keyshape_only fallback_retry_exercised fallback_exercise_ready fallback_qacc_delta_vs_corrupt fallback_retry_used fallback_retry_success fallback_retry_raw_selected fallback_retry_noisy_selected fallback_noisy_selected joint_chunk_source_ready teacher_label_contract_ready teacher_label_collection_ready learned_chunk_scorer_ready learned_chunk_score_gap learned_chunk_coherent_wrong_negative_rate learned_chunk_correct_reward_rate learned_chunk_negative_action_rate learned_chunk_scorer_id learned_chunk_scorer_source source_verified_feature_labels_ready source_verified_learned_chunk_scorer_ready source_verified_feature_source_link_ready source_verified_feature_label_source source_verified_feature_csv_provided source_verified_scorer_reason source_verified_learned_chunk_scorer_eval_ready source_verified_student_only_eval_rows source_verified_student_only_eval_ready source_verified_chunk_exact_delta source_verified_near_miss_negative_rate source_verified_missing_abstain_rate source_verified_metric_improvement_ready source_verified_scorer_eval_reason teacher_external_schema_ready teacher_external_label_source_ready teacher_external_labels_ready teacher_external_label_source teacher_external_source_evidence teacher_source_chain_verified real_teacher_source_verified teacher_source_action remote_teacher_source_live_network_import_ready teacher_source_import_review_contract_ready real_teacher_source_import_review_ready teacher_source_import_review_action teacher_distillation_training_ready teacher_distillation_eval_ready teacher_distillation_action_accuracy teacher_learner_id teacher_grounded_span_coverage teacher_label_source teacher_correct_labels teacher_wrong_labels teacher_near_miss_labels teacher_missing_query_labels teacher_abstain_labels policy_distillation_ready combined_ready distillation_ready default_promotion diagnostic_only weak_hint_or_abstain status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 distillation summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 distillation row has wrong column count", 3)
    if ($idx["best_joint_arm"] !~ /^chunk-credit-/) {
      die("h10 distillation should consume chunk-credit joint evidence", 4)
    }
    if ($idx["fallback_exercise_arm"] !~ /retry$/) {
      die("h10 distillation should consume fallback retry exercise evidence", 10)
    }
    if (($idx["chunk_credit_ready"] + 0) != 1 ||
        ($idx["joint_chunk_ready"] + 0) != 1 ||
        ($idx["source_safe"] + 0) != 1 ||
        ($idx["joint_source_safe"] + 0) != 1 ||
        ($idx["noisy_clean"] + 0) != 1) {
      die("h10 distillation should preserve chunk/source/noisy gates", 5)
    }
    if (($idx["fallback_retry_exercised"] + 0) != 1 ||
        ($idx["fallback_exercise_ready"] + 0) != 1 ||
        ($idx["fallback_qacc_delta_vs_corrupt"] + 0) <= 0.05 ||
        ($idx["fallback_retry_used"] + 0) <= 0.0 ||
        ($idx["fallback_retry_success"] + 0) <= 0.0 ||
        ($idx["fallback_retry_raw_selected"] + 0) <= 0.0 ||
        ($idx["fallback_retry_noisy_selected"] + 0) != 0.0 ||
        ($idx["fallback_noisy_selected"] + 0) != 0.0 ||
        ($idx["joint_chunk_source_ready"] + 0) != 0 ||
        ($idx["teacher_label_contract_ready"] + 0) != 1 ||
        ($idx["teacher_label_collection_ready"] + 0) != 1 ||
        ($idx["learned_chunk_scorer_ready"] + 0) != 1 ||
        ($idx["learned_chunk_score_gap"] + 0) <= 0.50 ||
        ($idx["learned_chunk_coherent_wrong_negative_rate"] + 0) != 1.0 ||
        ($idx["learned_chunk_correct_reward_rate"] + 0) != 1.0 ||
        ($idx["learned_chunk_negative_action_rate"] + 0) != 1.0 ||
        $idx["learned_chunk_scorer_id"] != "linear-contrastive-chunk-v1" ||
        $idx["learned_chunk_scorer_source"] != "local-teacher-harness" ||
        ($idx["source_verified_feature_labels_ready"] + 0) != 0 ||
        ($idx["source_verified_learned_chunk_scorer_ready"] + 0) != 0 ||
        ($idx["source_verified_feature_source_link_ready"] + 0) != 0 ||
        $idx["source_verified_feature_label_source"] != "local-teacher-harness" ||
        ($idx["source_verified_feature_csv_provided"] + 0) != 0 ||
        $idx["source_verified_scorer_reason"] != "source-verified-feature-labels-missing" ||
        ($idx["source_verified_learned_chunk_scorer_eval_ready"] + 0) != 0 ||
        ($idx["source_verified_student_only_eval_rows"] + 0) != 0 ||
        ($idx["source_verified_student_only_eval_ready"] + 0) != 0 ||
        ($idx["source_verified_chunk_exact_delta"] + 0) != 0.0 ||
        ($idx["source_verified_near_miss_negative_rate"] + 0) != 0.0 ||
        ($idx["source_verified_missing_abstain_rate"] + 0) != 0.0 ||
        ($idx["source_verified_metric_improvement_ready"] + 0) != 0 ||
        $idx["source_verified_scorer_eval_reason"] != "source-verified-feature-labels-missing" ||
        ($idx["teacher_external_schema_ready"] + 0) != 1 ||
        ($idx["teacher_external_label_source_ready"] + 0) != 0 ||
        ($idx["teacher_external_labels_ready"] + 0) != 0 ||
        $idx["teacher_external_label_source"] != "external-teacher-pending" ||
        $idx["teacher_external_source_evidence"] != "pending-fixture" ||
        ($idx["teacher_source_chain_verified"] + 0) != 0 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        $idx["teacher_source_action"] != "teacher-external-label-source-missing" ||
        ($idx["remote_teacher_source_live_network_import_ready"] + 0) != 0 ||
        ($idx["teacher_source_import_review_contract_ready"] + 0) != 0 ||
        ($idx["real_teacher_source_import_review_ready"] + 0) != 0 ||
        $idx["teacher_source_import_review_action"] != "real-teacher-source-live-network-import-missing" ||
        ($idx["teacher_distillation_training_ready"] + 0) != 1 ||
        ($idx["teacher_distillation_eval_ready"] + 0) != 1 ||
        ($idx["teacher_distillation_action_accuracy"] + 0) != 1.0 ||
        $idx["teacher_learner_id"] != "distilled-rule-v1" ||
        ($idx["teacher_grounded_span_coverage"] + 0) != 1.0 ||
        $idx["teacher_label_source"] != "local-teacher-harness" ||
        ($idx["teacher_correct_labels"] + 0) <= 0 ||
        ($idx["teacher_wrong_labels"] + 0) <= 0 ||
        ($idx["teacher_near_miss_labels"] + 0) <= 0 ||
        ($idx["teacher_missing_query_labels"] + 0) <= 0 ||
        ($idx["teacher_abstain_labels"] + 0) <= 0 ||
        ($idx["policy_distillation_ready"] + 0) != 0 ||
        ($idx["combined_ready"] + 0) != 0 ||
        ($idx["distillation_ready"] + 0) != 0) {
      die("h10 distillation must stay blocked after local teacher distillation until external source exists", 6)
    }
    if (($idx["default_promotion"] + 0) != 0 ||
        ($idx["diagnostic_only"] + 0) != 1 ||
        ($idx["weak_hint_or_abstain"] + 0) != 1 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "teacher-external-label-source-missing") {
      die("h10 distillation should remain weak-hint diagnostic-only", 7)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 distillation", 8)
    }
  }
  END {
    if (rows != 1) die("expected one h10 distillation summary row", 9)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx) || !("reason" in idx)) {
      die("missing h10 distillation decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "fallback-retry" && $idx["status"] != "pass") {
      die("fallback-retry gate should pass after h10-d evidence", 21)
    }
    if ($idx["gate"] == "teacher-label-contract" && $idx["status"] != "pass") {
      die("teacher-label contract should pass after h10-e schema evidence", 24)
    }
    if ($idx["gate"] == "teacher-label-collection" && $idx["status"] != "pass") {
      die("teacher-label collection should pass after h10-f local collection", 25)
    }
    if ($idx["gate"] == "teacher-distillation-training" && $idx["status"] != "pass") {
      die("teacher distillation training should pass after h10-g local learner", 26)
    }
    if ($idx["gate"] == "learned-chunk-scorer" && $idx["status"] != "pass") {
      die("learned chunk scorer should pass after h10-k local scorer training", 31)
    }
    if ($idx["gate"] == "source-verified-learned-chunk-scorer" && $idx["status"] != "blocked") {
      die("source-verified learned chunk scorer should block before real source-linked labels", 32)
    }
    if ($idx["gate"] == "source-verified-learned-chunk-scorer-eval" && $idx["status"] != "blocked") {
      die("source-verified learned chunk scorer eval should block before student-only real eval", 34)
    }
    if ($idx["gate"] == "external-label-schema" && $idx["status"] != "pass") {
      die("external label schema should pass after h10-h contract", 28)
    }
    if ($idx["gate"] == "external-label-source" && $idx["status"] != "blocked") {
      die("external label source should block distillation", 29)
    }
    if ($idx["gate"] == "external-label-ingestion" && $idx["status"] != "blocked") {
      die("external label ingestion should block distillation", 27)
    }
    if ($idx["gate"] == "real-external-teacher-source" && $idx["status"] != "blocked") {
      die("real external teacher source should block distillation", 30)
    }
    if ($idx["gate"] == "real-teacher-source-import-review" && $idx["status"] != "blocked") {
      die("real teacher source import/review should block distillation", 33)
    }
    if ($idx["gate"] == "distillation" && $idx["status"] != "blocked") {
      die("distillation gate should be blocked", 22)
    }
  }
  END {
    if (rows < 13) die("expected h10 distillation decision rows", 23)
  }
' "$DECISION_CSV"

echo "v10 chunk-credit distillation gate smoke passed"
