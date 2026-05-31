#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_evidence_fixture.csv"
AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_authenticity_fixture.csv"
EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_execution_fixture.csv"
ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_attestation_fixture.csv"
IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_attestor_identity_fixture.csv"
LOCAL_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_fixture.csv"
BYPASS_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_real_declared_local_fixture.csv"

"$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_import.sh" >/dev/null

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("real_benchmark_source_declared fixture_or_synthetic_declared", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 final review real-source guard column: " required[i] > "/dev/stderr"
        exit 2
      }
    }
    print
    next
  }
  {
    $idx["real_benchmark_source_declared"] = 1
    $idx["fixture_or_synthetic_declared"] = 0
    print
  }
' "$LOCAL_REVIEW_CSV" >"$BYPASS_REVIEW_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV="$BYPASS_REVIEW_CSV" \
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
    required_count = split("final_review_source review_rows review_hash_verified_rows local_final_review_artifact_rows nonlocal_final_review_artifact_rows local_reviewer_identity_rows nonlocal_reviewer_identity_rows local_reviewer_conflict_rows nonlocal_reviewer_conflict_rows local_upstream_artifact_rows real_source_declared_rows non_fixture_declared_rows final_review_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 final review real-source guard summary column: " required[i], 3)
    }
    next
  }
  {
    rows++
    if ($idx["final_review_source"] != "provided-csv" ||
        ($idx["review_rows"] + 0) != 4 ||
        ($idx["review_hash_verified_rows"] + 0) != 4 ||
        ($idx["local_final_review_artifact_rows"] + 0) != 4 ||
        ($idx["nonlocal_final_review_artifact_rows"] + 0) != 0 ||
        ($idx["local_reviewer_identity_rows"] + 0) != 4 ||
        ($idx["nonlocal_reviewer_identity_rows"] + 0) != 0 ||
        ($idx["local_reviewer_conflict_rows"] + 0) != 4 ||
        ($idx["nonlocal_reviewer_conflict_rows"] + 0) != 0 ||
        ($idx["local_upstream_artifact_rows"] + 0) != 32 ||
        ($idx["real_source_declared_rows"] + 0) != 4 ||
        ($idx["non_fixture_declared_rows"] + 0) != 4 ||
        ($idx["final_review_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-local-final-review-artifact") {
      die("local final-review artifacts must not become real external benchmark evidence by flag rewrite", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 final review real-source guard", 5)
    }
  }
  END {
    if (rows != 1) die("expected one v08 final review real-source guard summary row", 6)
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
    if ($idx["gate"] == "real-source-declaration" && $idx["status"] != "pass") die("real-source declaration should pass after flag rewrite", 20)
    if ($idx["gate"] == "local-final-review-artifact" && $idx["status"] != "blocked") die("local final-review artifact guard should block", 21)
    if ($idx["gate"] == "nonlocal-final-review-artifact" && $idx["status"] != "blocked") die("nonlocal final-review artifact row should block for local fixture", 22)
    if ($idx["gate"] == "local-upstream-artifact" && $idx["status"] != "blocked") die("local upstream artifact guard should block for local fixture", 23)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should remain blocked", 24)
  }
  END {
    if (rows != 13) die("expected v08 final review real-source guard decision rows", 25)
  }
' "$DECISION_CSV"

echo "v08 external benchmark final review real-source guard smoke passed"
