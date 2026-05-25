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

PREFIX="v10_source_verified_learned_chunk_scorer_gate"
COLLECTION_PREFIX="v10_teacher_label_collection_harness"
SOURCE_PREFIX="v10_teacher_external_label_source_verifier"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_source_verified_learned_chunk_scorer_gate_smoke"
  COLLECTION_PREFIX="v10_teacher_label_collection_harness_smoke"
  SOURCE_PREFIX="v10_teacher_external_label_source_verifier_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi
SCORER_PREFIX="${PREFIX}_scorer"

FEATURE_LABELS_CSV="${V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV:-}"
FEATURE_CSV_PROVIDED=0
if [[ -n "$FEATURE_LABELS_CSV" ]]; then
  FEATURE_CSV_PROVIDED=1
  if [[ ! -s "$FEATURE_LABELS_CSV" ]]; then
    echo "V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  FEATURE_LABELS_CSV="$RESULTS_DIR/${COLLECTION_PREFIX}_labels.csv"
  if [[ ! -s "$FEATURE_LABELS_CSV" ]]; then
    "$ROOT_DIR/experiments/run_v10_teacher_label_collection_harness.sh" "${RUN_ARGS[@]}" >/dev/null
  fi
fi

if [[ "$FEATURE_CSV_PROVIDED" == "1" ]]; then
  V10_LEARNED_CHUNK_QUALITY_OUTPUT_PREFIX="$SCORER_PREFIX" \
  V10_LEARNED_CHUNK_QUALITY_LABELS_CSV="$FEATURE_LABELS_CSV" \
    "$ROOT_DIR/experiments/run_v10_learned_chunk_quality_scorer.sh" "${RUN_ARGS[@]}" >/dev/null
else
  V10_LEARNED_CHUNK_QUALITY_OUTPUT_PREFIX="$SCORER_PREFIX" \
    "$ROOT_DIR/experiments/run_v10_learned_chunk_quality_scorer.sh" "${RUN_ARGS[@]}" >/dev/null
fi
"$ROOT_DIR/experiments/run_v10_teacher_external_label_source_verifier.sh" "${RUN_ARGS[@]}" >/dev/null

SCORER_SUMMARY_CSV="$RESULTS_DIR/${SCORER_PREFIX}_summary.csv"
SOURCE_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
SOURCE_EVIDENCE_CSV="${V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV:-$RESULTS_DIR/${SOURCE_PREFIX}_source.csv}"
EXTERNAL_LABELS_CSV="${V10_TEACHER_EXTERNAL_LABEL_CSV:-}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
if [[ -n "$EXTERNAL_LABELS_CSV" && ! -s "$EXTERNAL_LABELS_CSV" ]]; then
  echo "V10_TEACHER_EXTERNAL_LABEL_CSV must point to a non-empty CSV" >&2
  exit 10
fi

AWK_INPUTS=("$FEATURE_LABELS_CSV" "$SOURCE_EVIDENCE_CSV" "$SCORER_SUMMARY_CSV" "$SOURCE_SUMMARY_CSV")
if [[ -n "$EXTERNAL_LABELS_CSV" ]]; then
  AWK_INPUTS+=("$EXTERNAL_LABELS_CSV")
fi

awk -F, -v feature_csv="$FEATURE_LABELS_CSV" -v source_evidence_csv="$SOURCE_EVIDENCE_CSV" -v scorer_csv="$SCORER_SUMMARY_CSV" -v source_summary_csv="$SOURCE_SUMMARY_CSV" -v external_labels_csv="$EXTERNAL_LABELS_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" -v feature_csv_provided="$FEATURE_CSV_PROVIDED" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  FILENAME == feature_csv && FNR == 1 {
    feature_header_fields = NF
    for (i = 1; i <= NF; i++) fidx[$i] = i
    required_count = split("label_id label_source teacher_id query_key candidate_key teacher_label routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in fidx)) die("missing h10 source-verified feature label column: " required[i], 2)
    }
    feature_has_binding_fields = ("source_uri" in fidx && "provenance_hash" in fidx)
    next
  }
  FILENAME == feature_csv {
    if (NF != feature_header_fields) die("h10 source-verified feature label row has wrong column count", 20)
    feature_rows++
    label_source = $fidx["label_source"]
    teacher_id = $fidx["teacher_id"]
    if (label_source == "" || teacher_id == "") die("h10 source-verified feature labels need source and teacher id", 3)
    if (feature_rows == 1) {
      feature_label_source = label_source
    } else if (feature_label_source != label_source) {
      die("h10 source-verified feature labels must use a single label_source", 4)
    }
    if (!(teacher_id in feature_teacher_seen)) {
      feature_teacher_seen[teacher_id] = 1
      feature_teacher_rows++
    }
    if (feature_has_binding_fields &&
        $fidx["source_uri"] != "" &&
        $fidx["provenance_hash"] != "") {
      feature_bound_rows++
      bind_key = teacher_id SUBSEP $fidx["query_key"] SUBSEP $fidx["candidate_key"] SUBSEP $fidx["teacher_label"] SUBSEP $fidx["source_uri"] SUBSEP $fidx["provenance_hash"]
      feature_bind_seen[bind_key] = 1
    }
    feature_routing += $fidx["routing_trigger_rate"] + 0
    feature_jump += $fidx["active_jump_rate"] + 0
    next
  }
  FILENAME == source_evidence_csv && FNR == 1 {
    source_evidence_header_fields = NF
    for (i = 1; i <= NF; i++) evidx[$i] = i
    if (!("teacher_id" in evidx)) die("missing h10 source evidence teacher_id column", 5)
    next
  }
  FILENAME == source_evidence_csv {
    if (NF != source_evidence_header_fields) die("h10 source evidence row has wrong column count", 21)
    source_evidence_rows++
    source_teacher_seen[$evidx["teacher_id"]] = 1
    next
  }
  FILENAME == scorer_csv && FNR == 1 {
    scorer_header_fields = NF
    for (i = 1; i <= NF; i++) qidx[$i] = i
    required_count = split("learned_chunk_scorer_ready learned_score_gap coherent_wrong_negative_rate correct_reward_rate negative_action_rate learner_id label_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in qidx)) die("missing h10 source-verified scorer column: " required[i], 6)
    }
    next
  }
  FILENAME == scorer_csv {
    if (NF != scorer_header_fields) die("h10 source-verified scorer row has wrong column count", 22)
    scorer_rows++
    learned_chunk_scorer_ready = $qidx["learned_chunk_scorer_ready"] + 0
    learned_score_gap = $qidx["learned_score_gap"] + 0
    coherent_wrong_negative_rate = $qidx["coherent_wrong_negative_rate"] + 0
    correct_reward_rate = $qidx["correct_reward_rate"] + 0
    negative_action_rate = $qidx["negative_action_rate"] + 0
    learner_id = $qidx["learner_id"]
    scorer_label_source = $qidx["label_source"]
    scorer_routing = $qidx["routing_trigger_rate"] + 0
    scorer_jump = $qidx["active_jump_rate"] + 0
    next
  }
  FILENAME == source_summary_csv && FNR == 1 {
    source_summary_header_fields = NF
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("external_schema_ready external_label_source_ready teacher_external_labels_ready teacher_source_source teacher_source_chain_verified real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) die("missing h10 source-verified source summary column: " required[i], 7)
    }
    next
  }
  FILENAME == source_summary_csv {
    if (NF != source_summary_header_fields) die("h10 source verifier summary row has wrong column count", 23)
    source_summary_rows++
    external_schema_ready = $sidx["external_schema_ready"] + 0
    external_label_source_ready = $sidx["external_label_source_ready"] + 0
    teacher_external_labels_ready = $sidx["teacher_external_labels_ready"] + 0
    teacher_source_source = $sidx["teacher_source_source"]
    teacher_source_chain_verified = $sidx["teacher_source_chain_verified"] + 0
    real_teacher_source_verified = $sidx["real_teacher_source_verified"] + 0
    teacher_source_action = $sidx["action"]
    source_routing = $sidx["routing_trigger_rate"] + 0
    source_jump = $sidx["active_jump_rate"] + 0
    next
  }
  external_labels_csv != "" && FILENAME == external_labels_csv && FNR == 1 {
    external_header_fields = NF
    for (i = 1; i <= NF; i++) xidx[$i] = i
    required_count = split("teacher_id source_uri query_key candidate_key teacher_label provenance_hash routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in xidx)) die("missing h10 source-verified external label column: " required[i], 24)
    }
    next
  }
  external_labels_csv != "" && FILENAME == external_labels_csv {
    if (NF != external_header_fields) die("h10 source-verified external label row has wrong column count", 25)
    external_label_rows++
    external_bind_key = $xidx["teacher_id"] SUBSEP $xidx["query_key"] SUBSEP $xidx["candidate_key"] SUBSEP $xidx["teacher_label"] SUBSEP $xidx["source_uri"] SUBSEP $xidx["provenance_hash"]
    external_bind_seen[external_bind_key] = 1
    external_routing += $xidx["routing_trigger_rate"] + 0
    external_jump += $xidx["active_jump_rate"] + 0
    next
  }
  END {
    if (feature_rows <= 0) die("expected h10 source-verified feature labels", 8)
    if (scorer_rows != 1) die("expected one h10 source-verified scorer row", 9)
    if (source_summary_rows != 1) die("expected one h10 source verifier summary row", 10)

    matched_feature_teacher_rows = 0
    for (teacher_id in feature_teacher_seen) {
      if (teacher_id in source_teacher_seen) matched_feature_teacher_rows++
    }
    matched_feature_label_rows = 0
    for (bind_key in feature_bind_seen) {
      if (bind_key in external_bind_seen) matched_feature_label_rows++
    }
    feature_external_label_link_ready = 0
    if (feature_has_binding_fields &&
        external_label_rows > 0 &&
        feature_bound_rows == feature_rows &&
        matched_feature_label_rows == feature_bound_rows &&
        external_routing == 0.0 &&
        external_jump == 0.0) {
      feature_external_label_link_ready = 1
    }

    feature_label_source_nonlocal = 0
    if (feature_label_source != "local-teacher-harness" &&
        feature_label_source != "contract-oracle" &&
        feature_label_source != "") {
      feature_label_source_nonlocal = 1
    }

    feature_source_link_ready = 0
    if (feature_csv_provided == 1 &&
        feature_label_source_nonlocal &&
        feature_teacher_rows > 0 &&
        matched_feature_teacher_rows == feature_teacher_rows &&
        feature_external_label_link_ready &&
        feature_routing == 0.0 &&
        feature_jump == 0.0) {
      feature_source_link_ready = 1
    }

    source_verified_feature_labels_ready = 0
    if (feature_source_link_ready && learned_chunk_scorer_ready) {
      source_verified_feature_labels_ready = 1
    }

    source_verified_learned_chunk_scorer_ready = 0
    if (source_verified_feature_labels_ready &&
        external_schema_ready &&
        external_label_source_ready &&
        teacher_external_labels_ready &&
        teacher_source_chain_verified &&
        real_teacher_source_verified &&
        scorer_routing == 0.0 &&
        scorer_jump == 0.0 &&
        source_routing == 0.0 &&
        source_jump == 0.0) {
      source_verified_learned_chunk_scorer_ready = 1
    }

    default_promotion = 0
    status = source_verified_learned_chunk_scorer_ready ? "source-verified-scorer-candidate" : "diagnostic-only"
    reason = "all-gates-ready"
    if (!learned_chunk_scorer_ready) {
      reason = "learned-chunk-scorer-missing"
    } else if (feature_csv_provided == 0 || !feature_source_link_ready) {
      reason = "source-verified-feature-labels-missing"
    } else if (!external_label_source_ready || !teacher_external_labels_ready) {
      reason = "teacher-external-label-source-missing"
    } else if (!teacher_source_chain_verified) {
      reason = "teacher-source-chain-missing"
    } else if (!real_teacher_source_verified) {
      reason = "teacher-real-external-label-source-missing"
    }

    total_routing = feature_routing + external_routing + scorer_routing + source_routing
    total_jump = feature_jump + external_jump + scorer_jump + source_jump

    print "feature_csv_provided,feature_rows,feature_teacher_rows,matched_feature_teacher_rows,feature_has_binding_fields,feature_bound_rows,matched_feature_label_rows,external_label_rows,feature_external_label_link_ready,feature_label_source,feature_label_source_nonlocal,feature_source_link_ready,learned_chunk_scorer_ready,learned_score_gap,coherent_wrong_negative_rate,correct_reward_rate,negative_action_rate,learner_id,scorer_label_source,source_verified_feature_labels_ready,external_schema_ready,external_label_source_ready,teacher_external_labels_ready,teacher_source_source,teacher_source_chain_verified,real_teacher_source_verified,teacher_source_action,source_verified_learned_chunk_scorer_ready,default_promotion,status,reason,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%s,%s,%d,%d,%d,%d,%s,%d,%d,%s,%d,%d,%s,%s,%.6f,%.6f\n",
      feature_csv_provided,
      feature_rows,
      feature_teacher_rows,
      matched_feature_teacher_rows,
      feature_has_binding_fields,
      feature_bound_rows,
      matched_feature_label_rows,
      external_label_rows,
      feature_external_label_link_ready,
      feature_label_source,
      feature_label_source_nonlocal,
      feature_source_link_ready,
      learned_chunk_scorer_ready,
      learned_score_gap,
      coherent_wrong_negative_rate,
      correct_reward_rate,
      negative_action_rate,
      learner_id,
      scorer_label_source,
      source_verified_feature_labels_ready,
      external_schema_ready,
      external_label_source_ready,
      teacher_external_labels_ready,
      teacher_source_source,
      teacher_source_chain_verified,
      real_teacher_source_verified,
      teacher_source_action,
      source_verified_learned_chunk_scorer_ready,
      default_promotion,
      status,
      reason,
      total_routing,
      total_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "learned-chunk-scorer,%s,ready=%d gap=%.6f\n",
      learned_chunk_scorer_ready ? "pass" : "blocked",
      learned_chunk_scorer_ready,
      learned_score_gap >> decision_csv
    printf "source-feature-link,%s,provided=%d matched_teachers=%d/%d matched_labels=%d/%d binding_fields=%d label_source=%s\n",
      feature_source_link_ready ? "pass" : "blocked",
      feature_csv_provided,
      matched_feature_teacher_rows,
      feature_teacher_rows,
      matched_feature_label_rows,
      feature_bound_rows,
      feature_has_binding_fields,
      feature_label_source >> decision_csv
    printf "teacher-source-chain,%s,chain_verified=%d evidence=%s\n",
      teacher_source_chain_verified ? "pass" : "blocked",
      teacher_source_chain_verified,
      teacher_source_source >> decision_csv
    printf "real-teacher-source,%s,real_verified=%d action=%s\n",
      real_teacher_source_verified ? "pass" : "blocked",
      real_teacher_source_verified,
      teacher_source_action >> decision_csv
    printf "source-verified-learned-scorer,%s,ready=%d reason=%s\n",
      source_verified_learned_chunk_scorer_ready ? "pass" : "blocked",
      source_verified_learned_chunk_scorer_ready,
      reason >> decision_csv
    printf "default-promotion,%s,default_promotion=%d\n",
      default_promotion ? "pass" : "blocked",
      default_promotion >> decision_csv
  }
' "${AWK_INPUTS[@]}"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
