#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_public_registry_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_public_registry_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_fixture.csv"
PUBLIC_REGISTRY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_public_registry_fixture.csv"
BAD_PUBLIC_REGISTRY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_public_registry_fixture.csv"

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
      if (!(field in idx)) die("missing v08-r summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-r summary row", 4)
    }
  ' "$summary_csv"
}

make_public_registry_csv() {
  local authority_csv="$1"
  local public_registry_csv="$2"

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
      required_count = split("benchmark_family source_import_id verifier_run_id live_review_id authority_review_id authority_review_report_hash authority_reviewer_identity_hash authority_reviewer_registry_hash authority_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-r public registry fixture source column: " required[i], 2)
      }
      print "benchmark_family,source_import_id,verifier_run_id,live_review_id,authority_review_id,registry_entry_id,public_registry_uri,public_registry_hash,registry_entry_uri,registry_entry_hash,registry_operator_identity_uri,registry_operator_identity_hash,registry_provenance_uri,registry_provenance_hash,reviewed_authority_review_report_hash,reviewed_authority_reviewer_identity_hash,reviewed_authority_reviewer_registry_hash,reviewed_authority_reviewer_conflict_disclosure_hash,reviewed_verifier_binary_hash,reviewed_verifier_stdout_hash,reviewed_verifier_stderr_hash,registry_name,registry_operator,registry_jurisdiction,registry_record_type,registry_protocol_version,official_public_registry,source_import_recorded,authority_review_recorded,artifact_hash_review_ready,source_import_binding_review_ready,registry_entry_approved,real_public_registry_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,public_registry_hash_attested,registry_entry_hash_attested,registry_operator_identity_hash_attested,registry_provenance_hash_attested"
      next
    }
    {
      family_slug = slugify($idx["benchmark_family"])
      public_registry_hash = "sha256:8888888888888888888888888888888888888888888888888888888888888888"
      registry_entry_hash = "sha256:9999999999999999999999999999999999999999999999999999999999999999"
      operator_identity_hash = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      registry_provenance_hash = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      print \
        $idx["benchmark_family"], \
        $idx["source_import_id"], \
        $idx["verifier_run_id"], \
        $idx["live_review_id"], \
        $idx["authority_review_id"], \
        "public-registry-entry-" family_slug, \
        "https://benchmarks.example.invalid/v08/source-import/public-registry/" family_slug ".json", \
        public_registry_hash, \
        "https://benchmarks.example.invalid/v08/source-import/public-registry-entry/" family_slug ".json", \
        registry_entry_hash, \
        "https://benchmarks.example.invalid/v08/source-import/public-registry-operator/" family_slug "-identity.json", \
        operator_identity_hash, \
        "https://benchmarks.example.invalid/v08/source-import/public-registry-provenance/" family_slug ".json", \
        registry_provenance_hash, \
        $idx["authority_review_report_hash"], \
        $idx["authority_reviewer_identity_hash"], \
        $idx["authority_reviewer_registry_hash"], \
        $idx["authority_reviewer_conflict_disclosure_hash"], \
        $idx["reviewed_verifier_binary_hash"], \
        $idx["reviewed_verifier_stdout_hash"], \
        $idx["reviewed_verifier_stderr_hash"], \
        "Public Benchmark Source Import Registry", \
        "Public Benchmark Authority", \
        "global-public-fixture", \
        "source-import-authority-record", \
        "v08-source-import-public-registry-v1", \
        1, \
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
  ' "$authority_csv" >"$public_registry_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_public_registry_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08r" "default v08-r scope"
expect_summary_value "$SUMMARY_CSV" "source_import_authoritative_review_ready" "0" "default v08-r should block before authority review"
expect_summary_value "$SUMMARY_CSV" "source_import_public_registry_ready" "0" "default v08-r should not have registry evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-r must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-r must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-r action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_authoritative_review_gate.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_public_registry_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_authoritative_review_ready" "1" "v08-r should see authority review readiness"
expect_summary_value "$SUMMARY_CSV" "public_registry_rows" "0" "v08-r should have no registry rows before registry import"
expect_summary_value "$SUMMARY_CSV" "source_import_public_registry_ready" "0" "v08-r should block before public registry"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-public-registry-missing" "v08-r should ask for public registry evidence"

make_public_registry_csv "$AUTHORITY_REVIEW_CSV" "$PUBLIC_REGISTRY_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_public_registry_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "public_registry_source" "provided-csv" "v08-r public registry should be provided"
expect_summary_value "$SUMMARY_CSV" "public_registry_rows" "4" "v08-r public registry fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_authority_review_rows" "4" "v08-r registry should bind authority review rows"
expect_summary_value "$SUMMARY_CSV" "authority_review_hash_match_rows" "4" "v08-r registry should bind authority review hashes"
expect_summary_value "$SUMMARY_CSV" "verifier_hash_match_rows" "4" "v08-r registry should bind verifier hashes"
expect_summary_value "$SUMMARY_CSV" "local_registry_artifact_rows" "0" "v08-r registry should be nonlocal"
expect_summary_value "$SUMMARY_CSV" "nonlocal_registry_artifact_rows" "16" "v08-r registry should expose nonlocal registry artifacts"
expect_summary_value "$SUMMARY_CSV" "source_import_public_registry_ready" "1" "v08-r registry fixture should satisfy registry mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-r registry fixture must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-r registry fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-query-missing" "v08-r should still require live registry query evidence"

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
    if ($idx["gate"] == "source-import-authoritative-review" && $idx["status"] != "pass") die("v08-r authoritative review should pass", 20)
    if ($idx["gate"] == "public-registry-rows" && $idx["status"] != "pass") die("v08-r public registry rows should pass", 21)
    if ($idx["gate"] == "public-registry-chain" && $idx["status"] != "pass") die("v08-r public registry chain should pass", 22)
    if ($idx["gate"] == "public-registry-artifacts" && $idx["status"] != "pass") die("v08-r public registry artifacts should pass", 23)
    if ($idx["gate"] == "public-registry-approval" && $idx["status"] != "pass") die("v08-r public registry approval should pass", 24)
    if ($idx["gate"] == "source-import-public-registry" && $idx["status"] != "pass") die("v08-r public registry should pass", 25)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-r source import verification should still block", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-r real benchmark should block", 27)
  }
  END {
    if (rows != 8) die("expected eight v08-r decision rows", 28)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["reviewed_authority_review_report_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$PUBLIC_REGISTRY_CSV" >"$BAD_PUBLIC_REGISTRY_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$BAD_PUBLIC_REGISTRY_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_public_registry_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_authoritative_review_ready" "1" "v08-r bad registry should preserve authority readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_public_registry_ready" "0" "v08-r bad registry should block public registry readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-public-registry-chain-mismatch" "v08-r bad registry should block at chain mismatch"

echo "v08 external benchmark source import public registry gate smoke passed"
