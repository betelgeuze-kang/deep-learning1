#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_real_verification_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_real_verification_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_fixture.csv"
PUBLIC_REGISTRY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_public_registry_fixture.csv"
LIVE_REGISTRY_QUERY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_query_fixture.csv"
LIVE_REGISTRY_FETCH_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_fetch_fixture.csv"
NETWORK_PROOF_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_network_proof_fixture.csv"
REAL_VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_real_verification_fixture.csv"
BAD_REAL_VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_real_verification_fixture.csv"
MALFORMED_REAL_VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_malformed_real_verification_fixture.csv"

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
      if (!(field in idx)) die("missing v08-v summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-v summary row", 4)
    }
  ' "$summary_csv"
}

sha_text_uri() {
  local text="$1"
  printf 'sha256:%s\n' "$(printf '%s' "$text" | sha256sum | awk '{print $1}')"
}

make_real_verification_csv() {
  local proof_csv="$1"
  local verification_csv="$2"
  local domain="$3"
  local official="$4"
  local independent="$5"
  local replayed="$6"
  local live="$7"
  local real_declared="$8"
  local fixture_declared="$9"

  {
    echo "benchmark_family,source_import_id,network_proof_id,verification_record_id,verification_registry_uri,verification_record_uri,verification_report_uri,verification_report_hash,verifier_identity_uri,verifier_identity_hash,proof_transcript_uri,proof_transcript_hash,verified_registry_cache_hash,verified_registry_entry_cache_hash,official_external_registry,independent_verifier,network_proof_replayed,live_network_observed,real_source_import_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
    awk -F, '
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
        header_fields = NF
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("benchmark_family source_import_id network_proof_id registry_cache_hash registry_entry_cache_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08-v verification fixture source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-v verification fixture source row has wrong column count", 3)
        printf "%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["network_proof_id"],
          $idx["registry_cache_hash"],
          $idx["registry_entry_cache_hash"],
          slugify($idx["benchmark_family"])
      }
    ' "$proof_csv" |
    while IFS=$'\t' read -r benchmark_family source_import_id network_proof_id registry_cache_hash registry_entry_cache_hash family_slug; do
      verification_record_id="real-source-import-verification-${family_slug}"
      verification_registry_uri="https://${domain}/v08/source-import/verification-registry/${family_slug}.json"
      verification_record_uri="https://${domain}/v08/source-import/verification-record/${family_slug}.json"
      verification_report_uri="https://${domain}/v08/source-import/verification-report/${family_slug}.json"
      verifier_identity_uri="https://${domain}/v08/source-import/verifier/${family_slug}-identity.json"
      proof_transcript_uri="https://${domain}/v08/source-import/network-proof/${family_slug}-transcript.json"
      verification_report_hash="$(sha_text_uri "report|${benchmark_family}|${source_import_id}|${network_proof_id}")"
      verifier_identity_hash="$(sha_text_uri "identity|${benchmark_family}|${source_import_id}")"
      proof_transcript_hash="$(sha_text_uri "transcript|${benchmark_family}|${network_proof_id}")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,1,0,0\n" \
        "$benchmark_family" \
        "$source_import_id" \
        "$network_proof_id" \
        "$verification_record_id" \
        "$verification_registry_uri" \
        "$verification_record_uri" \
        "$verification_report_uri" \
        "$verification_report_hash" \
        "$verifier_identity_uri" \
        "$verifier_identity_hash" \
        "$proof_transcript_uri" \
        "$proof_transcript_hash" \
        "$registry_cache_hash" \
        "$registry_entry_cache_hash" \
        "$official" \
        "$independent" \
        "$replayed" \
        "$live" \
        "$real_declared" \
        "$fixture_declared"
    done
  } >"$verification_csv"
}

run_with_upstream_fixtures() {
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
  V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$LIVE_REGISTRY_QUERY_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$NETWORK_PROOF_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV="${1:-}" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_real_verification_gate.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_real_verification_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08v" "default v08-v scope"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "0" "default v08-v should block before network proof"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_review_ready" "0" "default v08-v should not have real verification review"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "0" "default v08-v should not verify real source import"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-v must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-v must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-v action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_registry_network_proof.sh" >/dev/null

run_with_upstream_fixtures ""

expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "1" "v08-v should see network proof readiness"
expect_summary_value "$SUMMARY_CSV" "real_verification_rows" "0" "v08-v should have no real verification rows before evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_review_ready" "0" "v08-v should block before real verification review"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "0" "v08-v should block before real verification"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-real-verification-missing" "v08-v should ask for real verification evidence"

make_real_verification_csv "$NETWORK_PROOF_CSV" "$REAL_VERIFICATION_CSV" "benchmarks.example.invalid" 1 1 0 1 1 0

run_with_upstream_fixtures "$REAL_VERIFICATION_CSV"

expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_source" "provided-csv" "v08-v real verification should be provided"
expect_summary_value "$SUMMARY_CSV" "real_verification_rows" "4" "v08-v real verification fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_proof_rows" "4" "v08-v real verification should match proof rows"
expect_summary_value "$SUMMARY_CSV" "hash_match_rows" "4" "v08-v real verification should bind proof hashes"
expect_summary_value "$SUMMARY_CSV" "artifact_metadata_rows" "4" "v08-v real verification fixture should have metadata"
expect_summary_value "$SUMMARY_CSV" "hash_attestation_rows" "4" "v08-v real verification fixture should have hash attestations"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_artifact_rows" "0" "v08-v example.invalid verification must not count as non-placeholder"
expect_summary_value "$SUMMARY_CSV" "official_external_registry_rows" "4" "v08-v fixture can exercise official registry flags"
expect_summary_value "$SUMMARY_CSV" "independent_verifier_rows" "4" "v08-v fixture can exercise independent verifier flags"
expect_summary_value "$SUMMARY_CSV" "live_network_observed_rows" "4" "v08-v fixture can exercise live-observed flags"
expect_summary_value "$SUMMARY_CSV" "declared_real_source_rows" "4" "v08-v fixture can exercise real declaration flags"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-v fixture can exercise non-fixture flags"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_review_ready" "1" "v08-v fixture should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "0" "v08-v placeholder domain must not satisfy real verification"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-v placeholder verification must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-v placeholder verification must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-real-verification-placeholder-domain" "v08-v placeholder verification should block at placeholder domain"

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
    if ($idx["gate"] == "source-import-live-registry-network-proof" && $idx["status"] != "pass") die("v08-v network proof should pass", 20)
    if ($idx["gate"] == "real-verification-rows" && $idx["status"] != "pass") die("v08-v verification rows should pass", 21)
    if ($idx["gate"] == "real-verification-hash" && $idx["status"] != "pass") die("v08-v verification hash should pass", 22)
    if ($idx["gate"] == "real-verification-artifacts" && $idx["status"] != "blocked") die("v08-v placeholder artifacts should block", 23)
    if ($idx["gate"] == "real-verification-authority" && $idx["status"] != "pass") die("v08-v authority flags should pass", 24)
    if ($idx["gate"] == "source-import-real-verification" && $idx["status"] != "blocked") die("v08-v real verification should block", 25)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-v source import verification should block", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-v real benchmark should block", 27)
  }
  END {
    if (rows != 8) die("expected eight v08-v decision rows", 28)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["verified_registry_cache_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$REAL_VERIFICATION_CSV" >"$BAD_REAL_VERIFICATION_CSV"

run_with_upstream_fixtures "$BAD_REAL_VERIFICATION_CSV"

expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "1" "v08-v bad verification should preserve network proof readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_review_ready" "0" "v08-v bad verification should block review readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "0" "v08-v bad verification should block real verification"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-real-verification-hash-mismatch" "v08-v bad verification should block at hash mismatch"

{
  head -n 1 "$REAL_VERIFICATION_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$REAL_VERIFICATION_CSV")"
} >"$MALFORMED_REAL_VERIFICATION_CSV"

if V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
   V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
   V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
   V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
   V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$LIVE_REGISTRY_QUERY_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$NETWORK_PROOF_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV="$MALFORMED_REAL_VERIFICATION_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_real_verification_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-v should reject malformed real verification CSV row widths" >&2
  exit 40
fi

echo "v08 external benchmark source import real verification smoke passed"
