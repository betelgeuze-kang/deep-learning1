#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_fixture.csv"
BAD_AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_authoritative_review_fixture.csv"

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v08-q summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-q summary row", 4)
    }
  ' "$summary_csv"
}

make_authority_review_csv() {
  local live_review_csv="$1"
  local authority_csv="$2"

  awk -F, -v OFS=, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    function slugify(value, out) {
      out = tolower(value)
      gsub(/[^a-z0-9]+/, "-", out)
      gsub(/^-|-$/, "", out)
      return out
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id verifier_run_id live_review_id live_review_report_hash live_reviewer_identity_hash live_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-q authority fixture source column: " required[i], 2)
      }
      print "benchmark_family,source_import_id,verifier_run_id,live_review_id,authority_review_id,authority_review_report_uri,authority_review_report_hash,authority_reviewer_identity_uri,authority_reviewer_identity_hash,authority_reviewer_registry_uri,authority_reviewer_registry_hash,authority_reviewer_conflict_disclosure_uri,authority_reviewer_conflict_disclosure_hash,reviewed_live_review_report_hash,reviewed_live_reviewer_identity_hash,reviewed_live_reviewer_conflict_disclosure_hash,reviewed_verifier_binary_hash,reviewed_verifier_stdout_hash,reviewed_verifier_stderr_hash,reviewer_name,reviewer_org,reviewer_role,reviewer_independent,authority_registry_id,authority_basis,review_protocol_version,authoritative_source_import_review,live_review_reproduced,artifact_hash_review_ready,source_import_binding_review_ready,review_approved,real_authority_review_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,authority_review_report_hash_attested,authority_reviewer_identity_hash_attested,authority_reviewer_registry_hash_attested,authority_reviewer_conflict_disclosure_hash_attested"
      next
    }
    {
      family_slug = slugify($idx["benchmark_family"])
      report_hash = "sha256:4444444444444444444444444444444444444444444444444444444444444444"
      identity_hash = "sha256:5555555555555555555555555555555555555555555555555555555555555555"
      registry_hash = "sha256:6666666666666666666666666666666666666666666666666666666666666666"
      conflict_hash = "sha256:7777777777777777777777777777777777777777777777777777777777777777"
      print \
        $idx["benchmark_family"], \
        $idx["source_import_id"], \
        $idx["verifier_run_id"], \
        $idx["live_review_id"], \
        "authority-review-" family_slug, \
        "https://benchmarks.example.invalid/v08/source-import/authority-review/" family_slug ".json", \
        report_hash, \
        "https://benchmarks.example.invalid/v08/source-import/authority-reviewer/" family_slug "-identity.json", \
        identity_hash, \
        "https://benchmarks.example.invalid/v08/source-import/authority-registry/" family_slug ".json", \
        registry_hash, \
        "https://benchmarks.example.invalid/v08/source-import/authority-reviewer/" family_slug "-conflict.json", \
        conflict_hash, \
        $idx["live_review_report_hash"], \
        $idx["live_reviewer_identity_hash"], \
        $idx["live_reviewer_conflict_disclosure_hash"], \
        $idx["reviewed_verifier_binary_hash"], \
        $idx["reviewed_verifier_stdout_hash"], \
        $idx["reviewed_verifier_stderr_hash"], \
        "Authoritative Source Import Reviewer", \
        "Public Benchmark Authority", \
        "source-import-authority-reviewer", \
        1, \
        "authority-registry-" family_slug, \
        "public-benchmark-source-import-authority", \
        "v08-source-import-authority-review-v1", \
        1, \
        1, \
        1, \
        1, \
        1, \
        1, \
        0, \
        "0.000000", \
        "0.000000", \
        1, \
        1, \
        1, \
        1
    }
  ' "$live_review_csv" >"$authority_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_authoritative_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08q" "default v08-q scope"
expect_summary_value "$SUMMARY_CSV" "source_import_independent_live_review_ready" "0" "default v08-q should block before live review"
expect_summary_value "$SUMMARY_CSV" "source_import_authoritative_review_ready" "0" "default v08-q should not have authority review"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-q must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-q must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-q action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_review_gate.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_authoritative_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_independent_live_review_ready" "1" "v08-q should see independent live review readiness"
expect_summary_value "$SUMMARY_CSV" "authority_review_rows" "0" "v08-q should have no authority review rows before authority import"
expect_summary_value "$SUMMARY_CSV" "source_import_authoritative_review_ready" "0" "v08-q should block before authority review"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-authoritative-live-review-missing" "v08-q should ask for authority review"

make_authority_review_csv "$LIVE_REVIEW_CSV" "$AUTHORITY_REVIEW_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_authoritative_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "authority_review_source" "provided-csv" "v08-q authority review should be provided"
expect_summary_value "$SUMMARY_CSV" "authority_review_rows" "4" "v08-q authority fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_live_review_rows" "4" "v08-q authority review should bind live review rows"
expect_summary_value "$SUMMARY_CSV" "live_review_hash_match_rows" "4" "v08-q authority review should bind live-review hashes"
expect_summary_value "$SUMMARY_CSV" "verifier_hash_match_rows" "4" "v08-q authority review should bind verifier hashes"
expect_summary_value "$SUMMARY_CSV" "local_authority_artifact_rows" "0" "v08-q authority review should be nonlocal"
expect_summary_value "$SUMMARY_CSV" "nonlocal_authority_artifact_rows" "16" "v08-q authority review should expose nonlocal authority artifacts"
expect_summary_value "$SUMMARY_CSV" "source_import_authoritative_review_ready" "1" "v08-q authority fixture should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-q authority fixture must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-q authority fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-real-public-registry-missing" "v08-q should still require real public registry evidence"

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
    if ($idx["gate"] == "source-import-independent-live-review" && $idx["status"] != "pass") die("v08-q independent live review should pass", 20)
    if ($idx["gate"] == "authority-review-rows" && $idx["status"] != "pass") die("v08-q authority rows should pass", 21)
    if ($idx["gate"] == "authority-review-chain" && $idx["status"] != "pass") die("v08-q authority chain should pass", 22)
    if ($idx["gate"] == "authority-review-artifacts" && $idx["status"] != "pass") die("v08-q authority artifacts should pass", 23)
    if ($idx["gate"] == "authority-review-approval" && $idx["status"] != "pass") die("v08-q authority approval should pass", 24)
    if ($idx["gate"] == "source-import-authoritative-review" && $idx["status"] != "pass") die("v08-q authoritative review should pass", 25)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-q source import verification should still block", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-q real benchmark should block", 27)
  }
  END {
    if (rows != 8) die("expected eight v08-q decision rows", 28)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["reviewed_live_review_report_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$AUTHORITY_REVIEW_CSV" >"$BAD_AUTHORITY_REVIEW_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$BAD_AUTHORITY_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_authoritative_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_independent_live_review_ready" "1" "v08-q bad authority should preserve live review readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_authoritative_review_ready" "0" "v08-q bad authority should block authoritative review"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-authority-review-chain-mismatch" "v08-q bad authority should block at chain mismatch"

echo "v08 external benchmark source import authoritative review gate smoke passed"
