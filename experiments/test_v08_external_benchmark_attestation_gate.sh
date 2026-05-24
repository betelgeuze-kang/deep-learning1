#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_attestation_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_attestation_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families evidence_source authenticity_source execution_source attestation_source benchmark_authenticity_verified evaluator_execution_verified attestation_rows matched_family_rows attestation_artifact_rows attestation_hash_verified_rows independent_attestor_rows execution_hash_attested_rows metric_attested_rows independent_attestation_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 attestation summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08j" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["evidence_source"] != "pending-fixture" ||
        $idx["authenticity_source"] != "pending-fixture" ||
        $idx["execution_source"] != "pending-fixture" ||
        $idx["attestation_source"] != "pending-fixture" ||
        ($idx["benchmark_authenticity_verified"] + 0) != 0 ||
        ($idx["evaluator_execution_verified"] + 0) != 0 ||
        ($idx["attestation_rows"] + 0) != 4 ||
        ($idx["matched_family_rows"] + 0) != 4 ||
        ($idx["attestation_artifact_rows"] + 0) != 0 ||
        ($idx["attestation_hash_verified_rows"] + 0) != 0 ||
        ($idx["independent_attestor_rows"] + 0) != 0 ||
        ($idx["execution_hash_attested_rows"] + 0) != 0 ||
        ($idx["metric_attested_rows"] + 0) != 0 ||
        ($idx["independent_attestation_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "benchmark-execution-missing") {
      die("default v08 attestation gate should remain blocked before execution", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 attestation gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 attestation summary row", 5)
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
    if ($idx["gate"] == "evaluator-execution" && $idx["status"] != "blocked") die("evaluator execution should block by default", 20)
    if ($idx["gate"] == "attestation-rows" && $idx["status"] != "pass") die("attestation rows should exist by default", 21)
    if ($idx["gate"] == "execution-id-match" && $idx["status"] != "blocked") die("execution ids should block by default", 22)
    if ($idx["gate"] == "attestation-ready" && $idx["status"] != "blocked") die("attestation readiness should block by default", 23)
    if ($idx["gate"] == "independent-attestor" && $idx["status"] != "blocked") die("independent attestor should block by default", 24)
    if ($idx["gate"] == "execution-attested" && $idx["status"] != "blocked") die("execution attestation should block by default", 25)
    if ($idx["gate"] == "independent-attestation" && $idx["status"] != "blocked") die("independent attestation should block by default", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block by default", 27)
  }
  END {
    if (rows != 9) die("expected v08 attestation decision rows", 28)
  }
' "$DECISION_CSV"

echo "v08 external benchmark attestation gate smoke passed"
