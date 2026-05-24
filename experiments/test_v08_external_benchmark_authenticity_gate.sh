#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_authenticity_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_authenticity_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_authenticity_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families evidence_source authenticity_source artifact_verifier_ready authenticity_rows matched_family_rows canonical_uri_match_rows authenticity_ready_rows evaluator_ready_rows evaluator_hash_rows metric_ready_rows benchmark_authenticity_ready evaluator_contract_ready benchmark_authenticity_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 authenticity summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08h" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["evidence_source"] != "pending-fixture" ||
        $idx["authenticity_source"] != "pending-fixture" ||
        ($idx["artifact_verifier_ready"] + 0) != 0 ||
        ($idx["authenticity_rows"] + 0) != 4 ||
        ($idx["matched_family_rows"] + 0) != 4 ||
        ($idx["canonical_uri_match_rows"] + 0) != 0 ||
        ($idx["authenticity_ready_rows"] + 0) != 0 ||
        ($idx["evaluator_ready_rows"] + 0) != 0 ||
        ($idx["evaluator_hash_rows"] + 0) != 0 ||
        ($idx["metric_ready_rows"] + 0) != 0 ||
        ($idx["benchmark_authenticity_ready"] + 0) != 0 ||
        ($idx["evaluator_contract_ready"] + 0) != 0 ||
        ($idx["benchmark_authenticity_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "artifact-verifier-missing") {
      die("default v08 authenticity gate should remain blocked before artifact verification", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 authenticity gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 authenticity summary row", 5)
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
    if ($idx["gate"] == "artifact-verifier" && $idx["status"] != "blocked") die("artifact verifier should block by default", 20)
    if ($idx["gate"] == "benchmark-authenticity" && $idx["status"] != "blocked") die("benchmark authenticity should block by default", 21)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block by default", 22)
  }
  END {
    if (rows != 6) die("expected v08 authenticity decision rows", 23)
  }
' "$DECISION_CSV"

echo "v08 external benchmark authenticity gate smoke passed"
