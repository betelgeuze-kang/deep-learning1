#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

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
    required_count = split("manifest_fields required_fields external_feed_fields external_schema_ready external_label_source_ready teacher_external_labels_ready teacher_label_collection_ready teacher_distillation_training_ready default_promotion label_source local_label_source learner_id ingestion_mode contract_version routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 external ingestion summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 external ingestion summary row has wrong column count", 3)
    if (($idx["manifest_fields"] + 0) < 12 ||
        ($idx["required_fields"] + 0) != ($idx["manifest_fields"] + 0) ||
        ($idx["external_feed_fields"] + 0) < 7 ||
        ($idx["external_schema_ready"] + 0) != 1) {
      die("h10 external ingestion schema contract should pass", 4)
    }
    if (($idx["external_label_source_ready"] + 0) != 0 ||
        ($idx["teacher_external_labels_ready"] + 0) != 0 ||
        ($idx["teacher_label_collection_ready"] + 0) != 1 ||
        ($idx["teacher_distillation_training_ready"] + 0) != 1 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["label_source"] != "external-teacher-pending" ||
        $idx["local_label_source"] != "local-teacher-harness" ||
        $idx["learner_id"] != "distilled-rule-v1" ||
        $idx["ingestion_mode"] != "schema-only") {
      die("h10 external ingestion should be schema-ready but source/promotion blocked", 5)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 external ingestion", 6)
    }
  }
  END {
    if (rows != 1) die("expected one h10 external ingestion summary row", 7)
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
      die("missing h10 external ingestion decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "external-schema" && $idx["status"] != "pass") die("external schema should pass", 21)
    if ($idx["gate"] == "external-label-source" && $idx["status"] != "blocked") die("external label source should remain blocked", 22)
    if ($idx["gate"] == "external-label-ingestion" && $idx["status"] != "blocked") die("external label ingestion should remain blocked", 23)
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") die("default promotion should remain blocked", 24)
  }
  END {
    if (rows < 4) die("expected h10 external ingestion decision rows", 25)
  }
' "$DECISION_CSV"

echo "v10 teacher external-label ingestion smoke passed"
