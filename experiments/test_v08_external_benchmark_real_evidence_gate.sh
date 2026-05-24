#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_evidence_ingestion.sh" --smoke
"$ROOT_DIR/experiments/run_v08_external_benchmark_real_evidence_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_real_evidence_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_real_evidence_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families evidence_source benchmark_evidence_schema_ready external_benchmark_ready ready_rows real_dataset_uri_rows real_result_uri_rows source_hash_rows provenance_hash_rows real_evidence_format_ready real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 real evidence summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08f" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["evidence_source"] != "pending-fixture" ||
        ($idx["benchmark_evidence_schema_ready"] + 0) != 1 ||
        ($idx["external_benchmark_ready"] + 0) != 0 ||
        ($idx["ready_rows"] + 0) != 0 ||
        ($idx["real_dataset_uri_rows"] + 0) != 0 ||
        ($idx["real_result_uri_rows"] + 0) != 0 ||
        ($idx["source_hash_rows"] + 0) != 0 ||
        ($idx["provenance_hash_rows"] + 0) != 0 ||
        ($idx["real_evidence_format_ready"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-real-evidence-missing") {
      die("default v08 real evidence gate should remain real-evidence blocked", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 real evidence gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 real evidence summary row", 5)
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
    if ($idx["gate"] == "evidence-schema" && $idx["status"] != "pass") die("evidence schema should pass", 20)
    if ($idx["gate"] == "supplied-evidence" && $idx["status"] != "blocked") die("supplied evidence should block by default", 21)
    if ($idx["gate"] == "real-evidence-format" && $idx["status"] != "blocked") die("real evidence format should block by default", 22)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real benchmark should block by default", 23)
  }
  END {
    if (rows < 6) die("expected v08 real evidence decision rows", 24)
  }
' "$DECISION_CSV"

echo "v08 external benchmark real evidence gate smoke passed"
