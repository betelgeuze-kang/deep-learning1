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

PREFIX="v10_teacher_label_contract"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_teacher_label_contract_smoke"
fi

LABELS_CSV="$RESULTS_DIR/${PREFIX}_labels.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

printf 'label_id,scenario,query_key,candidate_key,candidate_rank,candidate_source,query_present,candidate_present,grounded_span_present,grounded_span_start,grounded_span_len,query_value,candidate_value,teacher_label,expected_action,chunk_exact,span_overlap,near_miss_distance,coherent_wrong_key,abstain_reason,label_source,routing_trigger_rate,active_jump_rate\n' >"$LABELS_CSV"
printf '1,correct-present,80000,80000,1,chunk-credit,1,1,1,128,5,HELLO,HELLO,correct,reward,1,5,0,0,none,contract-oracle,0,0\n' >>"$LABELS_CSV"
printf '2,wrong-coherent,80000,80017,1,chunk-credit,1,1,1,256,5,HELLO,WORLD,wrong,slash,0,0,5,1,none,contract-oracle,0,0\n' >>"$LABELS_CSV"
printf '3,near-miss,80000,80034,2,chunk-credit,1,1,1,384,5,HELLO,HELL0,near-miss,weak-negative,0,4,1,0,none,contract-oracle,0,0\n' >>"$LABELS_CSV"
printf '4,missing-query,89999,NA,0,none,0,0,0,-1,0,NA,NA,missing-query,abstain,0,0,-1,0,missing-query,contract-oracle,0,0\n' >>"$LABELS_CSV"
printf '5,abstain-low-confidence,80000,80051,3,noisy-route-code,1,1,1,512,5,HELLO,HXLLO,abstain,abstain,0,3,2,1,low-confidence-coherent-risk,contract-oracle,0,0\n' >>"$LABELS_CSV"

awk -F, -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("teacher_label expected_action query_present candidate_present grounded_span_present label_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher label contract column: " required[i], 2)
    }
    next
  }
  {
    rows++
    label = $idx["teacher_label"]
    action = $idx["expected_action"]
    labels[label] = 1
    label_counts[label]++
    action_counts[action]++
    label_source_value = $idx["label_source"]
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0

    if (($idx["candidate_present"] + 0) == 1) {
      candidate_rows++
      if (($idx["grounded_span_present"] + 0) == 1) grounded_candidate_rows++
    }
    if (label == "missing-query") {
      missing_rows++
      if (($idx["query_present"] + 0) == 0 && ($idx["candidate_present"] + 0) == 0 && ($idx["grounded_span_present"] + 0) == 0) {
        missing_span_absent_rows++
      }
    }
  }
  END {
    if (rows < 5) die("expected at least five h10 teacher label rows", 3)
    label_classes = 0
    for (label in labels) label_classes++

    grounded_span_coverage = 0.0
    if (candidate_rows > 0) grounded_span_coverage = grounded_candidate_rows / candidate_rows
    missing_query_span_absent = 0
    if (missing_rows > 0 && missing_span_absent_rows == missing_rows) missing_query_span_absent = 1

    contract_ready = 0
    if (label_counts["correct"] > 0 && label_counts["wrong"] > 0 && label_counts["near-miss"] > 0 && label_counts["missing-query"] > 0 && label_counts["abstain"] > 0 && action_counts["reward"] > 0 && action_counts["slash"] > 0 && action_counts["weak-negative"] > 0 && action_counts["abstain"] > 0 && grounded_span_coverage == 1.0 && missing_query_span_absent && routing == 0.0 && jump == 0.0) {
      contract_ready = 1
    }

    teacher_label_collection_ready = 0
    teacher_external_labels_ready = 0
    distillation_training_ready = 0
    promotion_ready = 0

    print "rows,label_classes,correct_labels,wrong_labels,near_miss_labels,missing_query_labels,abstain_labels,candidate_label_rows,grounded_candidate_rows,grounded_span_coverage,missing_query_span_absent,reward_actions,slash_actions,weak_negative_actions,abstain_actions,teacher_label_contract_ready,teacher_label_collection_ready,teacher_external_labels_ready,distillation_training_ready,default_promotion,label_source,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
      rows,
      label_classes,
      label_counts["correct"],
      label_counts["wrong"],
      label_counts["near-miss"],
      label_counts["missing-query"],
      label_counts["abstain"],
      candidate_rows,
      grounded_candidate_rows,
      grounded_span_coverage,
      missing_query_span_absent,
      action_counts["reward"],
      action_counts["slash"],
      action_counts["weak-negative"],
      action_counts["abstain"],
      contract_ready,
      teacher_label_collection_ready,
      teacher_external_labels_ready,
      distillation_training_ready,
      promotion_ready,
      label_source_value,
      routing,
      jump >> summary_csv

    print "gate,status,reason" > decision_csv
    schema_status = "blocked"
    if (label_classes >= 5) schema_status = "pass"
    contract_status = "blocked"
    if (contract_ready) contract_status = "pass"
    collection_status = "blocked"
    if (teacher_label_collection_ready) collection_status = "pass"
    training_status = "blocked"
    if (distillation_training_ready) training_status = "pass"
    promotion_status = "blocked"
    if (promotion_ready) promotion_status = "pass"

    printf "schema,%s,classes=%d rows=%d\n",
      schema_status,
      label_classes,
      rows >> decision_csv
    printf "teacher-label-contract,%s,correct=%d wrong=%d near_miss=%d missing=%d abstain=%d grounded=%.6f\n",
      contract_status,
      label_counts["correct"],
      label_counts["wrong"],
      label_counts["near-miss"],
      label_counts["missing-query"],
      label_counts["abstain"],
      grounded_span_coverage >> decision_csv
    printf "teacher-label-collection,%s,source=%s external_ready=%d\n",
      collection_status,
      label_source_value,
      teacher_external_labels_ready >> decision_csv
    printf "distillation-training,%s,learner_ready=%d\n",
      training_status,
      distillation_training_ready >> decision_csv
    printf "default-promotion,%s,default_promotion=%d\n",
      promotion_status,
      promotion_ready >> decision_csv
  }
' "$LABELS_CSV"

echo "labels: $LABELS_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
