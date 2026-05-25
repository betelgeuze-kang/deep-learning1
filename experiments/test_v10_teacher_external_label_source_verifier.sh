#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_teacher_external_label_source_verifier.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_teacher_external_label_source_verifier_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_teacher_external_label_source_verifier_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("teacher_source_scope external_schema_ready external_label_source_ready teacher_external_labels_ready label_source teacher_source_source external_label_rows source_rows matched_teacher_rows source_artifact_rows source_hash_verified_rows label_export_rows label_export_hash_verified_rows teacher_identity_rows teacher_identity_hash_verified_rows teacher_policy_rows teacher_policy_hash_verified_rows license_rows license_hash_verified_rows local_fixture_uri_rows teacher_source_chain_verified real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher source verifier summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["teacher_source_scope"] != "route-memory-h10j" ||
        ($idx["external_schema_ready"] + 0) != 1 ||
        ($idx["external_label_source_ready"] + 0) != 0 ||
        ($idx["teacher_external_labels_ready"] + 0) != 0 ||
        $idx["label_source"] != "external-teacher-pending" ||
        $idx["teacher_source_source"] != "pending-fixture" ||
        ($idx["external_label_rows"] + 0) != 0 ||
        ($idx["source_rows"] + 0) != 0 ||
        ($idx["matched_teacher_rows"] + 0) != 0 ||
        ($idx["source_artifact_rows"] + 0) != 0 ||
        ($idx["source_hash_verified_rows"] + 0) != 0 ||
        ($idx["label_export_rows"] + 0) != 0 ||
        ($idx["label_export_hash_verified_rows"] + 0) != 0 ||
        ($idx["teacher_identity_rows"] + 0) != 0 ||
        ($idx["teacher_identity_hash_verified_rows"] + 0) != 0 ||
        ($idx["teacher_policy_rows"] + 0) != 0 ||
        ($idx["teacher_policy_hash_verified_rows"] + 0) != 0 ||
        ($idx["license_rows"] + 0) != 0 ||
        ($idx["license_hash_verified_rows"] + 0) != 0 ||
        ($idx["local_fixture_uri_rows"] + 0) != 0 ||
        ($idx["teacher_source_chain_verified"] + 0) != 0 ||
        ($idx["real_teacher_source_verified"] + 0) != 0 ||
        $idx["action"] != "teacher-external-label-source-missing") {
      die("default h10 teacher source verifier should stay blocked before external labels", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 teacher source verifier", 4)
    }
  }
  END {
    if (rows != 1) die("expected one h10 teacher source verifier summary row", 5)
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
    if ($idx["gate"] == "external-label-ingestion" && $idx["status"] != "blocked") die("external label ingestion should block", 20)
    if ($idx["gate"] == "teacher-source-chain" && $idx["status"] != "blocked") die("teacher source chain should block", 21)
    if ($idx["gate"] == "real-teacher-source" && $idx["status"] != "blocked") die("real teacher source should block", 22)
  }
  END {
    if (rows != 9) die("expected h10 teacher source verifier decision rows", 23)
  }
' "$DECISION_CSV"

echo "v10 teacher external-label source verifier smoke passed"
