#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_artifact_verifier.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_artifact_verifier_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_artifact_verifier_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families evidence_source real_evidence_format_ready evidence_rows dataset_artifact_rows local_dataset_uri_rows nonlocal_dataset_uri_rows result_artifact_rows local_result_uri_rows nonlocal_result_uri_rows source_hash_verified_rows provenance_hash_verified_rows artifact_verifier_ready real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 artifact verifier summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08g" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["evidence_source"] != "pending-fixture" ||
        ($idx["real_evidence_format_ready"] + 0) != 0 ||
        ($idx["evidence_rows"] + 0) != 4 ||
        ($idx["dataset_artifact_rows"] + 0) != 0 ||
        ($idx["local_dataset_uri_rows"] + 0) != 0 ||
        ($idx["nonlocal_dataset_uri_rows"] + 0) != 0 ||
        ($idx["result_artifact_rows"] + 0) != 0 ||
        ($idx["local_result_uri_rows"] + 0) != 0 ||
        ($idx["nonlocal_result_uri_rows"] + 0) != 0 ||
        ($idx["source_hash_verified_rows"] + 0) != 0 ||
        ($idx["provenance_hash_verified_rows"] + 0) != 0 ||
        ($idx["artifact_verifier_ready"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "real-evidence-format-missing") {
      die("default v08 artifact verifier should remain blocked before real evidence format", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 artifact verifier", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 artifact verifier summary row", 5)
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
    if ($idx["gate"] == "real-evidence-format" && $idx["status"] != "blocked") die("real evidence format should block by default", 20)
    if ($idx["gate"] == "artifact-presence" && $idx["status"] != "blocked") die("artifact presence should block by default", 21)
    if ($idx["gate"] == "nonlocal-artifacts" && $idx["status"] != "blocked") die("nonlocal artifacts should block by default", 22)
    if ($idx["gate"] == "artifact-verifier" && $idx["status"] != "blocked") die("artifact verifier should block by default", 21)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block by default", 22)
  }
  END {
    if (rows != 8) die("expected v08 artifact verifier decision rows", 23)
  }
' "$DECISION_CSV"

echo "v08 external benchmark artifact verifier smoke passed"
