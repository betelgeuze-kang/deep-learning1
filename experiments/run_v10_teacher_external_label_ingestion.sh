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

PREFIX="v10_teacher_external_label_ingestion"
COLLECTION_PREFIX="v10_teacher_label_collection_harness"
TRAINING_PREFIX="v10_teacher_distillation_learner"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_teacher_external_label_ingestion_smoke"
  COLLECTION_PREFIX="v10_teacher_label_collection_harness_smoke"
  TRAINING_PREFIX="v10_teacher_distillation_learner_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

COLLECTION_SUMMARY_CSV="$RESULTS_DIR/${COLLECTION_PREFIX}_summary.csv"
TRAINING_SUMMARY_CSV="$RESULTS_DIR/${TRAINING_PREFIX}_summary.csv"
MANIFEST_CSV="$RESULTS_DIR/${PREFIX}_manifest.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXTERNAL_LABEL_CSV="${V10_TEACHER_EXTERNAL_LABEL_CSV:-}"

if [[ ! -s "$COLLECTION_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_teacher_label_collection_harness.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$TRAINING_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_teacher_distillation_learner.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ -n "$EXTERNAL_LABEL_CSV" && ! -s "$EXTERNAL_LABEL_CSV" ]]; then
  echo "V10_TEACHER_EXTERNAL_LABEL_CSV is set but not readable/non-empty: $EXTERNAL_LABEL_CSV" >&2
  exit 2
fi

cat >"$MANIFEST_CSV" <<'CSV'
field,required,source_mapping
external_label_id,1,external-teacher-feed
source_uri,1,external-teacher-feed
teacher_id,1,external-teacher-feed
query_key,1,h10f-labels
candidate_key,1,h10f-labels
teacher_label,1,external-teacher-feed
expected_action,1,external-teacher-feed
confidence,1,external-teacher-feed
evidence_span_start,1,h10f-labels
evidence_span_len,1,h10f-labels
provenance_hash,1,external-teacher-feed
license,1,external-teacher-feed
CSV

AWK_INPUTS=("$MANIFEST_CSV" "$COLLECTION_SUMMARY_CSV" "$TRAINING_SUMMARY_CSV")
if [[ -n "$EXTERNAL_LABEL_CSV" ]]; then
  AWK_INPUTS+=("$EXTERNAL_LABEL_CSV")
fi

awk -F, -v manifest_csv="$MANIFEST_CSV" -v collection_csv="$COLLECTION_SUMMARY_CSV" -v training_csv="$TRAINING_SUMMARY_CSV" -v external_label_csv="$EXTERNAL_LABEL_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  FILENAME == manifest_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) midx[$i] = i
    if (!("field" in midx) || !("required" in midx) || !("source_mapping" in midx)) {
      die("missing h10 external ingestion manifest columns", 2)
    }
    next
  }
  FILENAME == manifest_csv {
    manifest_rows++
    if ($midx["required"] + 0 == 1) required_fields++
    if ($midx["source_mapping"] == "external-teacher-feed") external_feed_fields++
    next
  }
  FILENAME == collection_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) cidx[$i] = i
    required_count = split("teacher_label_collection_ready label_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in cidx)) die("missing h10 external ingestion collection column: " required[i], 3)
    }
    next
  }
  FILENAME == collection_csv {
    collection_rows++
    teacher_label_collection_ready = $cidx["teacher_label_collection_ready"] + 0
    local_label_source = $cidx["label_source"]
    collection_routing = $cidx["routing_trigger_rate"] + 0
    collection_jump = $cidx["active_jump_rate"] + 0
    next
  }
  FILENAME == training_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) tidx[$i] = i
    required_count = split("teacher_distillation_training_ready learner_id routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in tidx)) die("missing h10 external ingestion training column: " required[i], 4)
    }
    next
  }
  FILENAME == training_csv {
    training_rows++
    teacher_distillation_training_ready = $tidx["teacher_distillation_training_ready"] + 0
    learner_id = $tidx["learner_id"]
    training_routing = $tidx["routing_trigger_rate"] + 0
    training_jump = $tidx["active_jump_rate"] + 0
    next
  }
  external_label_csv != "" && FILENAME == external_label_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) eidx[$i] = i
    required_count = split("external_label_id source_uri teacher_id query_key candidate_key teacher_label expected_action confidence evidence_span_start evidence_span_len provenance_hash license routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in eidx)) die("missing h10 external teacher label column: " required[i], 8)
    }
    next
  }
  external_label_csv != "" && FILENAME == external_label_csv {
    external_label_rows++
    if ($eidx["source_uri"] != "") source_uri_rows++
    if ($eidx["teacher_id"] != "") teacher_id_rows++
    if ($eidx["query_key"] != "" && $eidx["candidate_key"] != "") key_rows++
    label = $eidx["teacher_label"]
    if (label == "correct") correct_labels++
    else if (label == "wrong") wrong_labels++
    else if (label == "near-miss") near_miss_labels++
    else if (label == "missing-query") missing_query_labels++
    else if (label == "abstain") abstain_labels++
    else die("unknown h10 external teacher label: " label, 9)
    confidence = $eidx["confidence"] + 0
    if (confidence >= 0.0 && confidence <= 1.0) confidence_rows++
    if (($eidx["evidence_span_start"] + 0) >= 0 && ($eidx["evidence_span_len"] + 0) >= 0) grounded_rows++
    if ($eidx["provenance_hash"] != "") provenance_rows++
    if ($eidx["license"] != "") license_rows++
    label_routing += $eidx["routing_trigger_rate"] + 0
    label_jump += $eidx["active_jump_rate"] + 0
    next
  }
  END {
    if (manifest_rows < 12) die("expected h10 external ingestion manifest fields", 5)
    if (collection_rows != 1) die("expected one h10 external ingestion collection row", 6)
    if (training_rows != 1) die("expected one h10 external ingestion training row", 7)

    external_schema_ready = 0
    if (manifest_rows == required_fields && external_feed_fields >= 7) external_schema_ready = 1
    external_label_source_ready = 0
    teacher_external_labels_ready = 0
    label_source = "external-teacher-pending"
    ingestion_mode = "schema-only"
    if (external_label_csv != "") {
      label_source = "provided-external-csv"
      ingestion_mode = "provided-csv"
      label_coverage_ready = 0
      if (correct_labels > 0 &&
          wrong_labels > 0 &&
          near_miss_labels > 0 &&
          missing_query_labels > 0 &&
          abstain_labels > 0) {
        label_coverage_ready = 1
      }
      if (external_label_rows > 0 &&
          source_uri_rows == external_label_rows &&
          teacher_id_rows == external_label_rows &&
          key_rows == external_label_rows &&
          confidence_rows == external_label_rows &&
          grounded_rows == external_label_rows &&
          provenance_rows == external_label_rows &&
          license_rows == external_label_rows) {
        external_label_source_ready = 1
      }
      if (external_schema_ready &&
          external_label_source_ready &&
          label_coverage_ready &&
          label_routing == 0.0 &&
          label_jump == 0.0) {
        teacher_external_labels_ready = 1
      }
    }
    default_promotion = 0
    routing = collection_routing + training_routing + label_routing
    jump = collection_jump + training_jump + label_jump

    print "manifest_fields,required_fields,external_feed_fields,external_schema_ready,external_label_source_ready,teacher_external_labels_ready,teacher_label_collection_ready,teacher_distillation_training_ready,default_promotion,label_source,local_label_source,learner_id,ingestion_mode,contract_version,routing_trigger_rate,active_jump_rate,external_label_rows,source_uri_rows,teacher_id_rows,key_rows,confidence_rows,grounded_rows,provenance_rows,license_rows,correct_labels,wrong_labels,near_miss_labels,missing_query_labels,abstain_labels" > summary_csv
    printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,1,%.6f,%.6f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
      manifest_rows,
      required_fields,
      external_feed_fields,
      external_schema_ready,
      external_label_source_ready,
      teacher_external_labels_ready,
      teacher_label_collection_ready,
      teacher_distillation_training_ready,
      default_promotion,
      label_source,
      local_label_source,
      learner_id,
      ingestion_mode,
      routing,
      jump,
      external_label_rows,
      source_uri_rows,
      teacher_id_rows,
      key_rows,
      confidence_rows,
      grounded_rows,
      provenance_rows,
      license_rows,
      correct_labels,
      wrong_labels,
      near_miss_labels,
      missing_query_labels,
      abstain_labels >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "external-schema,%s,manifest_fields=%d external_feed_fields=%d\n",
      external_schema_ready ? "pass" : "blocked",
      manifest_rows,
      external_feed_fields >> decision_csv
    printf "external-label-source,%s,source_ready=%d\n",
      external_label_source_ready ? "pass" : "blocked",
      external_label_source_ready >> decision_csv
    printf "external-label-ingestion,%s,external_ready=%d\n",
      teacher_external_labels_ready ? "pass" : "blocked",
      teacher_external_labels_ready >> decision_csv
    printf "default-promotion,%s,default_promotion=%d\n",
      default_promotion ? "pass" : "blocked",
      default_promotion >> decision_csv
  }
' "${AWK_INPUTS[@]}"

echo "manifest: $MANIFEST_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
