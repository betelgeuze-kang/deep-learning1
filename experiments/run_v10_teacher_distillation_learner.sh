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

PREFIX="v10_teacher_distillation_learner"
COLLECTION_PREFIX="v10_teacher_label_collection_harness"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_teacher_distillation_learner_smoke"
  COLLECTION_PREFIX="v10_teacher_label_collection_harness_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

LABELS_CSV="$RESULTS_DIR/${COLLECTION_PREFIX}_labels.csv"
PREDICTIONS_CSV="$RESULTS_DIR/${PREFIX}_predictions.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ ! -s "$LABELS_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_teacher_label_collection_harness.sh" "${RUN_ARGS[@]}" >/dev/null
fi

awk -F, -v predictions_csv="$PREDICTIONS_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function predict_action(query_present, candidate_present, grounded_len, chunk_score, noisy_source, span_overlap, near_miss_distance, coherent_wrong) {
    if (query_present == 0 || candidate_present == 0) return "abstain"
    if (noisy_source == 1 && coherent_wrong == 1) return "abstain"
    if (span_overlap == grounded_len && chunk_score >= 0.9) return "reward"
    if (coherent_wrong == 1 && span_overlap == 0) return "slash"
    if (span_overlap > 0 && near_miss_distance > 0) return "weak-negative"
    return "abstain"
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("label_id query_present candidate_present grounded_span_len chunk_score noisy_source teacher_label expected_action span_overlap near_miss_distance coherent_wrong_key label_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher distillation label column: " required[i], 2)
    }
    print "label_id,expected_action,predicted_action,match,teacher_label,label_source,learner_id,training_mode,routing_trigger_rate,active_jump_rate" > predictions_csv
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 teacher distillation row has wrong column count", 3)

    query_present = $idx["query_present"] + 0
    candidate_present = $idx["candidate_present"] + 0
    grounded_len = $idx["grounded_span_len"] + 0
    chunk_score = $idx["chunk_score"] + 0
    noisy_source = $idx["noisy_source"] + 0
    span_overlap = $idx["span_overlap"] + 0
    near_miss_distance = $idx["near_miss_distance"] + 0
    coherent_wrong = $idx["coherent_wrong_key"] + 0
    expected_action = $idx["expected_action"]
    teacher_label = $idx["teacher_label"]
    label_source = $idx["label_source"]

    predicted_action = predict_action(query_present, candidate_present, grounded_len, chunk_score, noisy_source, span_overlap, near_miss_distance, coherent_wrong)
    action_counts[expected_action]++
    if (predicted_action == expected_action) {
      matches++
      matched = 1
    } else {
      matched = 0
    }
    if (expected_action == "reward") reward_rules = 1
    if (expected_action == "slash") slash_rules = 1
    if (expected_action == "weak-negative") weak_negative_rules = 1
    if (expected_action == "abstain") abstain_rules = 1
    if (label_source != "contract-oracle") non_contract_source_rows++
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0

    printf "%s,%s,%s,%d,%s,%s,distilled-rule-v1,local-fixture,%.6f,%.6f\n",
      $idx["label_id"],
      expected_action,
      predicted_action,
      matched,
      teacher_label,
      label_source,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0 >> predictions_csv
  }
  END {
    if (rows < 6) die("expected at least six h10 teacher distillation rows", 4)
    action_classes = 0
    if (action_counts["reward"] > 0) action_classes++
    if (action_counts["slash"] > 0) action_classes++
    if (action_counts["weak-negative"] > 0) action_classes++
    if (action_counts["abstain"] > 0) action_classes++

    learned_rule_count = reward_rules + slash_rules + weak_negative_rules + abstain_rules
    action_accuracy = matches / rows
    training_schema_ready = 0
    if (action_classes == 4 && learned_rule_count == 4) training_schema_ready = 1
    teacher_label_collection_ready = 0
    if (non_contract_source_rows == rows && label_source == "local-teacher-harness") teacher_label_collection_ready = 1
    teacher_external_labels_ready = 0
    teacher_distillation_eval_ready = 0
    if (action_accuracy == 1.0 && routing == 0.0 && jump == 0.0) teacher_distillation_eval_ready = 1
    teacher_distillation_training_ready = 0
    if (training_schema_ready && teacher_label_collection_ready && teacher_distillation_eval_ready) teacher_distillation_training_ready = 1
    default_promotion = 0

    print "rows,train_rows,eval_rows,action_classes,learned_rule_count,reward_rules,slash_rules,weak_negative_rules,abstain_rules,training_schema_ready,teacher_label_collection_ready,teacher_external_labels_ready,teacher_distillation_training_ready,teacher_distillation_eval_ready,default_promotion,label_source,learner_id,training_mode,action_accuracy,exact_action_matches,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,distilled-rule-v1,local-fixture,%.6f,%d,%.6f,%.6f\n",
      rows,
      rows,
      rows,
      action_classes,
      learned_rule_count,
      reward_rules,
      slash_rules,
      weak_negative_rules,
      abstain_rules,
      training_schema_ready,
      teacher_label_collection_ready,
      teacher_external_labels_ready,
      teacher_distillation_training_ready,
      teacher_distillation_eval_ready,
      default_promotion,
      label_source,
      action_accuracy,
      matches,
      routing,
      jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "schema,%s,action_classes=%d learned_rules=%d\n",
      training_schema_ready ? "pass" : "blocked",
      action_classes,
      learned_rule_count >> decision_csv
    printf "teacher-label-collection,%s,source=%s\n",
      teacher_label_collection_ready ? "pass" : "blocked",
      label_source >> decision_csv
    printf "action-fit,%s,accuracy=%.6f matches=%d rows=%d\n",
      teacher_distillation_eval_ready ? "pass" : "blocked",
      action_accuracy,
      matches,
      rows >> decision_csv
    printf "teacher-distillation-training,%s,learner_ready=%d\n",
      teacher_distillation_training_ready ? "pass" : "blocked",
      teacher_distillation_training_ready >> decision_csv
    printf "external-label-ingestion,%s,external_ready=%d\n",
      teacher_external_labels_ready ? "pass" : "blocked",
      teacher_external_labels_ready >> decision_csv
    printf "default-promotion,%s,default_promotion=%d\n",
      default_promotion ? "pass" : "blocked",
      default_promotion >> decision_csv
  }
' "$LABELS_CSV"

echo "predictions: $PREDICTIONS_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
