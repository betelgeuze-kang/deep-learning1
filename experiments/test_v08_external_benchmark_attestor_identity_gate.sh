#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_attestor_identity_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families attestor_identity_source evaluator_execution_verified independent_attestation_verified identity_rows matched_attestation_rows identity_artifact_rows local_identity_artifact_rows nonlocal_identity_artifact_rows identity_hash_verified_rows registry_artifact_rows local_registry_artifact_rows nonlocal_registry_artifact_rows registry_hash_verified_rows conflict_disclosure_rows local_conflict_disclosure_rows nonlocal_conflict_disclosure_rows conflict_disclosure_hash_verified_rows independence_basis_rows no_declared_conflict_rows attestor_identity_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 attestor identity summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08k" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["attestor_identity_source"] != "pending-fixture" ||
        ($idx["evaluator_execution_verified"] + 0) != 0 ||
        ($idx["independent_attestation_verified"] + 0) != 0 ||
        ($idx["identity_rows"] + 0) != 4 ||
        ($idx["matched_attestation_rows"] + 0) != 0 ||
        ($idx["identity_artifact_rows"] + 0) != 0 ||
        ($idx["local_identity_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_identity_artifact_rows"] + 0) != 0 ||
        ($idx["identity_hash_verified_rows"] + 0) != 0 ||
        ($idx["registry_artifact_rows"] + 0) != 0 ||
        ($idx["local_registry_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_registry_artifact_rows"] + 0) != 0 ||
        ($idx["registry_hash_verified_rows"] + 0) != 0 ||
        ($idx["conflict_disclosure_rows"] + 0) != 0 ||
        ($idx["local_conflict_disclosure_rows"] + 0) != 0 ||
        ($idx["nonlocal_conflict_disclosure_rows"] + 0) != 0 ||
        ($idx["conflict_disclosure_hash_verified_rows"] + 0) != 0 ||
        ($idx["independence_basis_rows"] + 0) != 0 ||
        ($idx["no_declared_conflict_rows"] + 0) != 0 ||
        ($idx["attestor_identity_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-independent-attestation-missing") {
      die("default v08 attestor identity gate should remain blocked before independent attestation", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 attestor identity gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 attestor identity summary row", 5)
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
    if ($idx["gate"] == "prior-independent-attestation" && $idx["status"] != "blocked") die("prior independent attestation should block", 20)
    if ($idx["gate"] == "local-identity-artifacts" && $idx["status"] != "blocked") die("local identity artifacts should block by default", 21)
    if ($idx["gate"] == "nonlocal-identity-artifacts" && $idx["status"] != "blocked") die("nonlocal identity artifacts should block by default", 22)
    if ($idx["gate"] == "attestor-identity" && $idx["status"] != "blocked") die("attestor identity should block", 21)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block", 22)
  }
  END {
    if (rows != 10) die("expected v08 attestor identity decision rows", 23)
  }
' "$DECISION_CSV"

echo "v08 external benchmark attestor identity gate smoke passed"
