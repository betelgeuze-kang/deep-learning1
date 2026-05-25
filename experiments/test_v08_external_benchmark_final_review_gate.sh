#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_final_review_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families final_review_source evaluator_execution_verified independent_attestation_verified attestor_identity_verified review_rows matched_attestation_rows review_artifact_rows review_hash_verified_rows reviewer_identity_rows reviewer_identity_hash_verified_rows reviewer_conflict_rows reviewer_conflict_hash_verified_rows critical_hash_match_rows metric_match_rows review_ready_rows review_approved_rows real_source_declared_rows non_fixture_declared_rows final_review_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 final review summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08l" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["final_review_source"] != "pending-fixture" ||
        ($idx["evaluator_execution_verified"] + 0) != 0 ||
        ($idx["independent_attestation_verified"] + 0) != 0 ||
        ($idx["attestor_identity_verified"] + 0) != 0 ||
        ($idx["review_rows"] + 0) != 4 ||
        ($idx["matched_attestation_rows"] + 0) != 0 ||
        ($idx["review_artifact_rows"] + 0) != 0 ||
        ($idx["review_hash_verified_rows"] + 0) != 0 ||
        ($idx["reviewer_identity_rows"] + 0) != 0 ||
        ($idx["reviewer_identity_hash_verified_rows"] + 0) != 0 ||
        ($idx["reviewer_conflict_rows"] + 0) != 0 ||
        ($idx["reviewer_conflict_hash_verified_rows"] + 0) != 0 ||
        ($idx["critical_hash_match_rows"] + 0) != 0 ||
        ($idx["metric_match_rows"] + 0) != 0 ||
        ($idx["review_ready_rows"] + 0) != 0 ||
        ($idx["review_approved_rows"] + 0) != 0 ||
        ($idx["real_source_declared_rows"] + 0) != 0 ||
        ($idx["non_fixture_declared_rows"] + 0) != 0 ||
        ($idx["final_review_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-attestor-identity-missing") {
      die("default v08 final review gate should remain blocked before attestor identity", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 final review gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 final review summary row", 5)
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
    if ($idx["gate"] == "prior-attestor-identity" && $idx["status"] != "blocked") die("prior attestor identity should block", 20)
    if ($idx["gate"] == "review-approval" && $idx["status"] != "blocked") die("review approval should block", 21)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block", 22)
  }
  END {
    if (rows != 10) die("expected v08 final review decision rows", 23)
  }
' "$DECISION_CSV"

echo "v08 external benchmark final review gate smoke passed"
