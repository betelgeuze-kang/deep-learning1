#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_CSV="$RESULTS_DIR/v10_teacher_external_label_import_fixture.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_CSV" <<'CSV'
external_label_id,source_uri,teacher_id,query_key,candidate_key,teacher_label,expected_action,confidence,evidence_span_start,evidence_span_len,provenance_hash,license,routing_trigger_rate,active_jump_rate
ext-001,external://teacher/labels/dev,teacher-fixture-v1,Q_ALPHA,C_ALPHA,correct,accept,0.990000,0,5,prov-alpha,permissive,0,0
ext-002,external://teacher/labels/dev,teacher-fixture-v1,Q_BETA,C_GAMMA,wrong,reject,0.940000,5,5,prov-beta,permissive,0,0
ext-003,external://teacher/labels/dev,teacher-fixture-v1,Q_DELTA,C_DELTA_NEAR,near-miss,weak-hint,0.820000,10,5,prov-delta,permissive,0,0
ext-004,external://teacher/labels/dev,teacher-fixture-v1,Q_MISSING,C_NONE,missing-query,abstain,0.910000,15,0,prov-missing,permissive,0,0
ext-005,external://teacher/labels/dev,teacher-fixture-v1,Q_UNCERTAIN,C_UNCERTAIN,abstain,abstain,0.760000,15,5,prov-uncertain,permissive,0,0
CSV

V10_TEACHER_EXTERNAL_LABEL_CSV="$FIXTURE_CSV" \
  "$ROOT_DIR/experiments/run_v10_teacher_external_label_ingestion.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_teacher_external_label_ingestion_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_teacher_external_label_ingestion_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("manifest_fields required_fields external_feed_fields external_schema_ready external_label_source_ready teacher_external_labels_ready teacher_label_collection_ready teacher_distillation_training_ready default_promotion label_source local_label_source learner_id ingestion_mode contract_version routing_trigger_rate active_jump_rate external_label_rows source_uri_rows teacher_id_rows key_rows confidence_rows grounded_rows provenance_rows license_rows correct_labels wrong_labels near_miss_labels missing_query_labels abstain_labels", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 external label import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 external label import summary row has wrong column count", 3)
    if (($idx["manifest_fields"] + 0) < 12 ||
        ($idx["required_fields"] + 0) != ($idx["manifest_fields"] + 0) ||
        ($idx["external_feed_fields"] + 0) < 7 ||
        ($idx["external_schema_ready"] + 0) != 1 ||
        ($idx["external_label_source_ready"] + 0) != 1 ||
        ($idx["teacher_external_labels_ready"] + 0) != 1 ||
        ($idx["teacher_label_collection_ready"] + 0) != 1 ||
        ($idx["teacher_distillation_training_ready"] + 0) != 1 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["label_source"] != "provided-external-csv" ||
        $idx["local_label_source"] != "local-teacher-harness" ||
        $idx["learner_id"] != "distilled-rule-v1" ||
        $idx["ingestion_mode"] != "provided-csv" ||
        ($idx["external_label_rows"] + 0) != 5 ||
        ($idx["source_uri_rows"] + 0) != 5 ||
        ($idx["teacher_id_rows"] + 0) != 5 ||
        ($idx["key_rows"] + 0) != 5 ||
        ($idx["confidence_rows"] + 0) != 5 ||
        ($idx["grounded_rows"] + 0) != 5 ||
        ($idx["provenance_rows"] + 0) != 5 ||
        ($idx["license_rows"] + 0) != 5 ||
        ($idx["correct_labels"] + 0) != 1 ||
        ($idx["wrong_labels"] + 0) != 1 ||
        ($idx["near_miss_labels"] + 0) != 1 ||
        ($idx["missing_query_labels"] + 0) != 1 ||
        ($idx["abstain_labels"] + 0) != 1) {
      die("supplied h10 external teacher labels should satisfy import readiness without promotion", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 external label import", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h10 external label import summary row", 6)
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
      die("missing h10 external label import decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "external-schema" && $idx["status"] != "pass") die("external schema should pass", 21)
    if ($idx["gate"] == "external-label-source" && $idx["status"] != "pass") die("external label source should pass under supplied labels", 22)
    if ($idx["gate"] == "external-label-ingestion" && $idx["status"] != "pass") die("external label ingestion should pass under supplied labels", 23)
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") die("default promotion should remain blocked", 24)
  }
  END {
    if (rows < 4) die("expected h10 external label import decision rows", 25)
  }
' "$DECISION_CSV"

V10_TEACHER_EXTERNAL_LABEL_CSV="$FIXTURE_CSV" \
  "$ROOT_DIR/experiments/run_v10_chunk_credit_distillation_gate.sh" --smoke

DISTILLATION_SUMMARY_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_summary.csv"
DISTILLATION_DECISION_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("teacher_external_label_source_ready teacher_external_labels_ready teacher_external_label_source teacher_source_chain_verified real_teacher_source_verified teacher_source_action distillation_ready default_promotion diagnostic_only weak_hint_or_abstain status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 distillation import summary column: " required[i], 40)
    }
    next
  }
  {
    rows++
    if (($idx["teacher_external_label_source_ready"] + 0) != 1 ||
        ($idx["teacher_external_labels_ready"] + 0) != 1 ||
        $idx["teacher_external_label_source"] != "provided-external-csv" ||
        ($idx["teacher_source_chain_verified"] + 0) != 0 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        $idx["teacher_source_action"] != "teacher-external-source-evidence-missing" ||
        ($idx["distillation_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        ($idx["diagnostic_only"] + 0) != 1 ||
        ($idx["weak_hint_or_abstain"] + 0) != 1 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "teacher-real-external-label-source-missing") {
      die("supplied h10 external labels should import but keep distillation blocked before real source verification", 41)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 distillation import", 42)
    }
  }
  END {
    if (rows != 1) die("expected one h10 distillation import summary row", 43)
  }
' "$DISTILLATION_SUMMARY_CSV"

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
    if ($idx["gate"] == "external-label-source" && $idx["status"] != "pass") die("external label source should pass in distillation import", 50)
    if ($idx["gate"] == "external-label-ingestion" && $idx["status"] != "pass") die("external label ingestion should pass in distillation import", 51)
    if ($idx["gate"] == "real-external-teacher-source" && $idx["status"] != "blocked") die("real teacher source should block in distillation import", 52)
    if ($idx["gate"] == "distillation" && $idx["status"] != "blocked") die("distillation should block before real teacher source verification", 54)
  }
  END {
    if (rows < 11) die("expected h10 distillation import decision rows", 53)
  }
' "$DISTILLATION_DECISION_CSV"

echo "v10 teacher external-label import smoke passed"
