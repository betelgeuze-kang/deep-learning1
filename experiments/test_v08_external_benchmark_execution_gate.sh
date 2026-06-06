#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_execution_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_execution_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_execution_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families evidence_source authenticity_source execution_source benchmark_authenticity_verified execution_rows matched_family_rows output_artifact_rows local_output_artifact_rows nonlocal_output_artifact_rows run_log_artifact_rows local_run_log_artifact_rows nonlocal_run_log_artifact_rows output_hash_verified_rows run_log_hash_verified_rows execution_ready_rows metric_output_rows evaluator_execution_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 execution summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08i" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["evidence_source"] != "pending-fixture" ||
        $idx["authenticity_source"] != "pending-fixture" ||
        $idx["execution_source"] != "pending-fixture" ||
        ($idx["benchmark_authenticity_verified"] + 0) != 0 ||
        ($idx["execution_rows"] + 0) != 4 ||
        ($idx["matched_family_rows"] + 0) != 4 ||
        ($idx["output_artifact_rows"] + 0) != 0 ||
        ($idx["local_output_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_output_artifact_rows"] + 0) != 0 ||
        ($idx["run_log_artifact_rows"] + 0) != 0 ||
        ($idx["local_run_log_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_run_log_artifact_rows"] + 0) != 0 ||
        ($idx["output_hash_verified_rows"] + 0) != 0 ||
        ($idx["run_log_hash_verified_rows"] + 0) != 0 ||
        ($idx["execution_ready_rows"] + 0) != 0 ||
        ($idx["metric_output_rows"] + 0) != 0 ||
        ($idx["evaluator_execution_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "benchmark-authenticity-missing") {
      die("default v08 execution gate should remain blocked before authenticity", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 execution gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 execution summary row", 5)
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
    if ($idx["gate"] == "benchmark-authenticity" && $idx["status"] != "blocked") die("benchmark authenticity should block by default", 20)
    if ($idx["gate"] == "local-execution-artifacts" && $idx["status"] != "blocked") die("local execution artifacts should block by default", 21)
    if ($idx["gate"] == "nonlocal-execution-artifacts" && $idx["status"] != "blocked") die("nonlocal execution artifacts should block by default", 22)
    if ($idx["gate"] == "evaluator-execution" && $idx["status"] != "blocked") die("evaluator execution should block by default", 21)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block by default", 22)
  }
  END {
    if (rows != 8) die("expected v08 execution decision rows", 23)
  }
' "$DECISION_CSV"

echo "v08 external benchmark execution gate smoke passed"
