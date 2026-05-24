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

PREFIX="v10_teacher_label_collection_harness"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_teacher_label_collection_harness_smoke"
fi

LABELS_CSV="$RESULTS_DIR/${PREFIX}_labels.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

printf 'label_id,run_id,seed,key_count,query_key,query_present,query_value,candidate_key,candidate_rank,candidate_source,candidate_present,grounded_span_present,grounded_span_start,grounded_span_len,candidate_value,chunk_score,chunk_gap,chunk_top1,fallback_used,retry_used,retry_source,noisy_source,teacher_label,expected_action,span_overlap,near_miss_distance,coherent_wrong_key,abstain_reason,label_source,teacher_id,collection_mode,collection_timestamp,contract_version,routing_trigger_rate,active_jump_rate\n' >"$LABELS_CSV"
printf '1,h10f-smoke,1,16,80000,1,HELLO,80000,1,chunk-credit,1,1,128,5,HELLO,1.000000,1.200000,1,0,0,none,0,correct,reward,5,0,0,none,local-teacher-harness,deterministic-span-v1,offline-fixture,static,1,0,0\n' >>"$LABELS_CSV"
printf '2,h10f-smoke,1,16,80000,1,HELLO,80017,1,chunk-credit,1,1,256,5,WORLD,0.050000,-0.900000,0,0,0,none,0,wrong,slash,0,5,1,none,local-teacher-harness,deterministic-span-v1,offline-fixture,static,1,0,0\n' >>"$LABELS_CSV"
printf '3,h10f-smoke,1,16,80000,1,HELLO,80034,2,chunk-credit,1,1,384,5,HELL0,0.400000,-0.250000,0,0,0,none,0,near-miss,weak-negative,4,1,0,none,local-teacher-harness,deterministic-span-v1,offline-fixture,static,1,0,0\n' >>"$LABELS_CSV"
printf '4,h10f-smoke,1,16,89999,0,NA,NA,0,none,0,0,-1,0,NA,0.000000,0.000000,0,0,0,none,0,missing-query,abstain,0,-1,0,missing-query,local-teacher-harness,deterministic-span-v1,offline-fixture,static,1,0,0\n' >>"$LABELS_CSV"
printf '5,h10f-smoke,1,16,80000,1,HELLO,80051,3,noisy-route-code,1,1,512,5,HXLLO,0.150000,-0.500000,0,0,0,none,1,abstain,abstain,3,2,1,low-confidence-coherent-risk,local-teacher-harness,deterministic-span-v1,offline-fixture,static,1,0,0\n' >>"$LABELS_CSV"
printf '6,h10f-smoke,1,16,80068,1,ROUTE,80068,1,raw-key,1,1,640,5,ROUTE,0.920000,0.800000,1,1,1,raw-key,0,correct,reward,5,0,0,forced-fallback-retry,local-teacher-harness,deterministic-span-v1,offline-fixture,static,1,0,0\n' >>"$LABELS_CSV"

awk -F, -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function valid_label(label) {
    return label == "correct" || label == "wrong" || label == "near-miss" || label == "missing-query" || label == "abstain"
  }
  function valid_action(action) {
    return action == "reward" || action == "slash" || action == "weak-negative" || action == "abstain"
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("label_id run_id seed key_count query_key query_present query_value candidate_key candidate_rank candidate_source candidate_present grounded_span_present grounded_span_start grounded_span_len candidate_value chunk_score chunk_gap chunk_top1 fallback_used retry_used retry_source noisy_source teacher_label expected_action span_overlap near_miss_distance coherent_wrong_key abstain_reason label_source teacher_id collection_mode collection_timestamp contract_version routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher label collection column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 teacher label collection row has wrong column count", 3)

    label = $idx["teacher_label"]
    action = $idx["expected_action"]
    if (!valid_label(label)) die("invalid teacher label: " label, 4)
    if (!valid_action(action)) die("invalid expected action: " action, 5)

    label_counts[label]++
    action_counts[action]++
    label_source_value = $idx["label_source"]
    teacher_id_value = $idx["teacher_id"]
    collection_mode_value = $idx["collection_mode"]
    contract_version_value = $idx["contract_version"]

    query_present = $idx["query_present"] + 0
    candidate_present = $idx["candidate_present"] + 0
    grounded_span_present = $idx["grounded_span_present"] + 0
    fallback_used = $idx["fallback_used"] + 0
    retry_used = $idx["retry_used"] + 0
    noisy_source = $idx["noisy_source"] + 0
    coherent_wrong = $idx["coherent_wrong_key"] + 0

    if (candidate_present == 1) {
      candidate_rows++
      if (grounded_span_present == 1) grounded_candidate_rows++
    }
    if (label == "missing-query") {
      missing_rows++
      if (query_present == 0 && candidate_present == 0 && grounded_span_present == 0) missing_valid_rows++
    }
    if (label == "abstain" && noisy_source == 1 && coherent_wrong == 1) noisy_case_rows++
    if (fallback_used == 1 && retry_used == 1 && $idx["retry_source"] == "raw-key") fallback_case_rows++
    if (label_source_value != "contract-oracle") non_contract_source_rows++
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 6) die("expected at least six h10 teacher label collection rows", 6)

    schema_valid = 1
    coverage_ready = 0
    if (label_counts["correct"] > 0 && label_counts["wrong"] > 0 && label_counts["near-miss"] > 0 && label_counts["missing-query"] > 0 && label_counts["abstain"] > 0) coverage_ready = 1
    grounding_ready = 0
    if (candidate_rows > 0 && grounded_candidate_rows == candidate_rows) grounding_ready = 1
    missing_query_valid = 0
    if (missing_rows > 0 && missing_valid_rows == missing_rows) missing_query_valid = 1
    source_ready = 0
    if (non_contract_source_rows == rows && label_source_value != "contract-oracle") source_ready = 1
    balance_ready = 0
    if (label_counts["correct"] >= 2 && label_counts["wrong"] >= 1 && label_counts["near-miss"] >= 1 && label_counts["abstain"] >= 1) balance_ready = 1
    noisy_case_covered = 0
    if (noisy_case_rows > 0) noisy_case_covered = 1
    fallback_case_covered = 0
    if (fallback_case_rows > 0) fallback_case_covered = 1
    teacher_label_contract_ready = 0
    if (schema_valid && coverage_ready && grounding_ready && missing_query_valid) teacher_label_contract_ready = 1
    teacher_label_collection_ready = 0
    if (teacher_label_contract_ready && source_ready && balance_ready && noisy_case_covered && fallback_case_covered && routing == 0.0 && jump == 0.0) teacher_label_collection_ready = 1
    teacher_external_labels_ready = 0
    distillation_training_ready = 0
    promotion_ready = 0

    print "rows,schema_valid,coverage_ready,grounding_ready,missing_query_valid,source_ready,balance_ready,noisy_case_covered,fallback_case_covered,correct_labels,wrong_labels,near_miss_labels,missing_query_labels,abstain_labels,candidate_label_rows,grounded_candidate_rows,teacher_label_contract_ready,teacher_label_collection_ready,teacher_external_labels_ready,distillation_training_ready,default_promotion,label_source,teacher_id,collection_mode,contract_version,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%.6f,%.6f\n",
      rows,
      schema_valid,
      coverage_ready,
      grounding_ready,
      missing_query_valid,
      source_ready,
      balance_ready,
      noisy_case_covered,
      fallback_case_covered,
      label_counts["correct"],
      label_counts["wrong"],
      label_counts["near-miss"],
      label_counts["missing-query"],
      label_counts["abstain"],
      candidate_rows,
      grounded_candidate_rows,
      teacher_label_contract_ready,
      teacher_label_collection_ready,
      teacher_external_labels_ready,
      distillation_training_ready,
      promotion_ready,
      label_source_value,
      teacher_id_value,
      collection_mode_value,
      contract_version_value,
      routing,
      jump >> summary_csv

    schema_status = "blocked"
    if (schema_valid) schema_status = "pass"
    collection_status = "blocked"
    if (teacher_label_collection_ready) collection_status = "pass"
    training_status = "blocked"
    if (distillation_training_ready) training_status = "pass"
    promotion_status = "blocked"
    if (promotion_ready) promotion_status = "pass"

    print "gate,status,reason" > decision_csv
    printf "schema,%s,required_columns=%d\n", schema_status, required_count >> decision_csv
    printf "coverage,%s,correct=%d wrong=%d near_miss=%d missing=%d abstain=%d\n",
      coverage_ready ? "pass" : "blocked",
      label_counts["correct"],
      label_counts["wrong"],
      label_counts["near-miss"],
      label_counts["missing-query"],
      label_counts["abstain"] >> decision_csv
    printf "source,%s,label_source=%s\n",
      source_ready ? "pass" : "blocked",
      label_source_value >> decision_csv
    printf "case-coverage,%s,noisy=%d fallback=%d grounding=%d missing_valid=%d\n",
      noisy_case_covered && fallback_case_covered && grounding_ready && missing_query_valid ? "pass" : "blocked",
      noisy_case_covered,
      fallback_case_covered,
      grounding_ready,
      missing_query_valid >> decision_csv
    printf "teacher-label-collection,%s,collection_ready=%d\n",
      collection_status,
      teacher_label_collection_ready >> decision_csv
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
