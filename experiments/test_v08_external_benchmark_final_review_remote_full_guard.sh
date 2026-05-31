#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
LOCAL_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_fixture.csv"
REMOTE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_remote_full_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_fixture.csv"
PUBLIC_REGISTRY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_public_registry_fixture.csv"
LIVE_REGISTRY_QUERY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_query_fixture.csv"

"$ROOT_DIR/experiments/test_v08_external_benchmark_lower_chain_remote_artifacts.sh" >/dev/null
"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_remote_contract.sh" >/dev/null
"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_registry_query_gate.sh" >/dev/null
"$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_import.sh" >/dev/null

awk -F, -v OFS=, '
  function slugify(value, out) {
    out = tolower(value)
    gsub(/[^a-z0-9]+/, "-", out)
    gsub(/^-|-$/, "", out)
    return out
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family review_report_uri reviewer_identity_uri reviewer_conflict_disclosure_uri real_benchmark_source_declared fixture_or_synthetic_declared", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        print "missing v08 final review remote-full guard column: " required[i] > "/dev/stderr"
        exit 2
      }
    }
    print $0, "review_report_hash_attested", "reviewer_identity_hash_attested", "reviewer_conflict_disclosure_hash_attested"
    next
  }
  {
    family_slug = slugify($idx["benchmark_family"])
    $idx["review_report_uri"] = "https://benchmarks.example.invalid/v08/final-review/" family_slug ".json"
    $idx["reviewer_identity_uri"] = "https://benchmarks.example.invalid/v08/reviewer/" family_slug "-identity.json"
    $idx["reviewer_conflict_disclosure_uri"] = "https://benchmarks.example.invalid/v08/reviewer/" family_slug "-conflict.json"
    $idx["real_benchmark_source_declared"] = 1
    $idx["fixture_or_synthetic_declared"] = 0
    print $0, 1, 1, 1
  }
' "$LOCAL_REVIEW_CSV" >"$REMOTE_REVIEW_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV="$REMOTE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$LIVE_REGISTRY_QUERY_CSV" \
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
    required_count = split("final_review_source review_rows review_artifact_rows review_hash_verified_rows local_final_review_artifact_rows nonlocal_final_review_artifact_rows local_reviewer_identity_rows nonlocal_reviewer_identity_rows local_reviewer_conflict_rows nonlocal_reviewer_conflict_rows local_upstream_evidence_artifact_rows local_upstream_execution_artifact_rows local_upstream_attestation_artifact_rows local_upstream_identity_artifact_rows local_upstream_artifact_rows real_source_declared_rows non_fixture_declared_rows source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_verified final_review_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 final review remote-full summary column: " required[i], 3)
    }
    next
  }
  {
    rows++
    if ($idx["final_review_source"] != "provided-csv" ||
        ($idx["review_rows"] + 0) != 4 ||
        ($idx["review_artifact_rows"] + 0) != 4 ||
        ($idx["review_hash_verified_rows"] + 0) != 4 ||
        ($idx["local_final_review_artifact_rows"] + 0) != 0 ||
        ($idx["nonlocal_final_review_artifact_rows"] + 0) != 4 ||
        ($idx["local_reviewer_identity_rows"] + 0) != 0 ||
        ($idx["nonlocal_reviewer_identity_rows"] + 0) != 4 ||
        ($idx["local_reviewer_conflict_rows"] + 0) != 0 ||
        ($idx["nonlocal_reviewer_conflict_rows"] + 0) != 4 ||
        ($idx["local_upstream_evidence_artifact_rows"] + 0) != 0 ||
        ($idx["local_upstream_execution_artifact_rows"] + 0) != 0 ||
        ($idx["local_upstream_attestation_artifact_rows"] + 0) != 0 ||
        ($idx["local_upstream_identity_artifact_rows"] + 0) != 0 ||
        ($idx["local_upstream_artifact_rows"] + 0) != 0 ||
        ($idx["real_source_declared_rows"] + 0) != 4 ||
        ($idx["non_fixture_declared_rows"] + 0) != 4 ||
        ($idx["source_import_independent_live_review_ready"] + 0) != 1 ||
        ($idx["source_import_authoritative_review_ready"] + 0) != 1 ||
        ($idx["source_import_public_registry_ready"] + 0) != 1 ||
        ($idx["source_import_live_registry_query_ready"] + 0) != 1 ||
        ($idx["source_import_verified"] + 0) != 0 ||
        ($idx["final_review_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "external-benchmark-source-import-live-registry-query-fixture-only") {
      die("fully remote-style benchmark artifacts must still block while live registry query is fixture-only", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08 final review remote-full guard", 5)
    }
  }
  END {
    if (rows != 1) die("expected one v08 final review remote-full summary row", 6)
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
    if ($idx["gate"] == "review-artifact-hash" && $idx["status"] != "pass") die("nonlocal hash-attested review artifacts should pass", 20)
    if ($idx["gate"] == "real-source-declaration" && $idx["status"] != "pass") die("real-source declaration should pass for remote-full fixture", 21)
    if ($idx["gate"] == "local-final-review-artifact" && $idx["status"] != "pass") die("local final-review artifact guard should pass", 22)
    if ($idx["gate"] == "nonlocal-final-review-artifact" && $idx["status"] != "pass") die("nonlocal final-review artifact guard should pass", 23)
    if ($idx["gate"] == "local-upstream-artifact" && $idx["status"] != "pass") die("local upstream artifact guard should pass", 24)
    if ($idx["gate"] == "source-import" && ($idx["status"] != "blocked" || $idx["reason"] !~ /contract_ready=1/ || $idx["reason"] !~ /auth_review_ready=1/ || $idx["reason"] !~ /public_registry_ready=1/ || $idx["reason"] !~ /live_registry_query_ready=1/)) die("source import should block after live registry query readiness while evidence is fixture-only", 25)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should remain blocked", 26)
  }
  END {
    if (rows != 14) die("expected v08 final review remote-full decision rows", 27)
  }
' "$DECISION_CSV"

echo "v08 external benchmark final review remote-full guard smoke passed"
