#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_official_authority_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_official_authority_gate_smoke_decision.csv"
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
REAL_VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_official_authority_real_verification_fixture.csv"
OFFICIAL_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_official_authority_fixture.csv"
BAD_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_official_authority_fixture.csv"
BAD_DOMAIN_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_domain_official_authority_fixture.csv"
MALFORMED_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_malformed_official_authority_fixture.csv"

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
      if (!(field in idx)) die("missing v08-w summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-w summary row", 4)
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
          if (!(required[i] in idx)) die("missing v08-w verification fixture source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-w verification fixture source row has wrong column count", 3)
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
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,1,0,1,1,0,1,0,0\n" \
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
        "$registry_entry_cache_hash"
    done
  } >"$verification_csv"
}

make_authority_csv() {
  local verification_csv="$1"
  local authority_csv="$2"
  local domain="$3"
  local fixture_declared="$4"

  {
    echo "benchmark_family,source_import_id,network_proof_id,verification_record_id,official_authority_id,official_authority_domain,official_authority_registry_uri,official_authority_record_uri,official_authority_record_hash,benchmark_source_uri,benchmark_source_hash,benchmark_license_uri,benchmark_license_hash,authority_operator_identity_uri,authority_operator_identity_hash,authority_review_uri,authority_review_hash,verified_verification_report_hash,canonical_benchmark_declared,official_trust_root_declared,independent_authority_review,live_authority_observed,real_source_import_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
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
        required_count = split("benchmark_family source_import_id network_proof_id verification_record_id verification_report_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08-w authority fixture source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-w authority fixture source row has wrong column count", 3)
        printf "%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["network_proof_id"],
          $idx["verification_record_id"],
          $idx["verification_report_hash"],
          slugify($idx["benchmark_family"])
      }
    ' "$verification_csv" |
    while IFS=$'\t' read -r benchmark_family source_import_id network_proof_id verification_record_id verification_report_hash family_slug; do
      official_authority_id="official-source-import-authority-${family_slug}"
      official_authority_registry_uri="https://${domain}/v08/source-import/official-authority/${family_slug}.json"
      official_authority_record_uri="https://${domain}/v08/source-import/official-authority-record/${family_slug}.json"
      benchmark_source_uri="https://${domain}/v08/source-import/source/${family_slug}.json"
      benchmark_license_uri="https://${domain}/v08/source-import/license/${family_slug}.json"
      authority_operator_identity_uri="https://${domain}/v08/source-import/operator/${family_slug}-identity.json"
      authority_review_uri="https://${domain}/v08/source-import/authority-review/${family_slug}.json"
      official_authority_record_hash="$(sha_text_uri "authority-record|${benchmark_family}|${source_import_id}|${verification_record_id}")"
      benchmark_source_hash="$(sha_text_uri "benchmark-source|${benchmark_family}|${source_import_id}")"
      benchmark_license_hash="$(sha_text_uri "benchmark-license|${benchmark_family}")"
      authority_operator_identity_hash="$(sha_text_uri "authority-operator|${benchmark_family}|${domain}")"
      authority_review_hash="$(sha_text_uri "authority-review|${benchmark_family}|${network_proof_id}")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,1,1,1,1,%d,1,0,0\n" \
        "$benchmark_family" \
        "$source_import_id" \
        "$network_proof_id" \
        "$verification_record_id" \
        "$official_authority_id" \
        "$domain" \
        "$official_authority_registry_uri" \
        "$official_authority_record_uri" \
        "$official_authority_record_hash" \
        "$benchmark_source_uri" \
        "$benchmark_source_hash" \
        "$benchmark_license_uri" \
        "$benchmark_license_hash" \
        "$authority_operator_identity_uri" \
        "$authority_operator_identity_hash" \
        "$authority_review_uri" \
        "$authority_review_hash" \
        "$verification_report_hash" \
        "$fixture_declared"
    done
  } >"$authority_csv"
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
  V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV="$REAL_VERIFICATION_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV="${1:-}" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_official_authority_gate.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_official_authority_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08w" "default v08-w scope"
expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "0" "default v08-w should block before real verification"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_review_ready" "0" "default v08-w should not have authority review"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_ready" "0" "default v08-w should not verify authority"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-w must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-w must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-w action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_registry_network_proof.sh" >/dev/null
make_real_verification_csv "$NETWORK_PROOF_CSV" "$REAL_VERIFICATION_CSV" "authority-benchmarks.org"

run_with_upstream_fixtures ""

expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "1" "v08-w should see non-placeholder real verification"
expect_summary_value "$SUMMARY_CSV" "official_authority_rows" "0" "v08-w should have no authority rows before evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_review_ready" "0" "v08-w should block before authority review"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_ready" "0" "v08-w should block before official authority"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-w must override v08-v source import readiness until authority is verified"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-official-authority-missing" "v08-w should ask for official authority evidence"

make_authority_csv "$REAL_VERIFICATION_CSV" "$OFFICIAL_AUTHORITY_CSV" "authority-benchmarks.org" 1

run_with_upstream_fixtures "$OFFICIAL_AUTHORITY_CSV"

expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_source" "provided-csv" "v08-w authority should be provided"
expect_summary_value "$SUMMARY_CSV" "official_authority_rows" "4" "v08-w authority fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_verification_rows" "4" "v08-w authority should match verification rows"
expect_summary_value "$SUMMARY_CSV" "verification_report_hash_match_rows" "4" "v08-w authority should bind verification report hashes"
expect_summary_value "$SUMMARY_CSV" "authority_artifact_rows" "4" "v08-w authority fixture should have metadata"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_authority_artifact_rows" "4" "v08-w authority fixture should use non-placeholder authority URIs"
expect_summary_value "$SUMMARY_CSV" "authority_hash_attestation_rows" "4" "v08-w authority fixture should have hash attestations"
expect_summary_value "$SUMMARY_CSV" "authority_domain_match_rows" "4" "v08-w authority fixture should match verification domains"
expect_summary_value "$SUMMARY_CSV" "canonical_benchmark_rows" "4" "v08-w fixture can exercise canonical benchmark flags"
expect_summary_value "$SUMMARY_CSV" "official_trust_root_rows" "4" "v08-w fixture can exercise trust-root flags"
expect_summary_value "$SUMMARY_CSV" "independent_authority_review_rows" "4" "v08-w fixture can exercise independent review flags"
expect_summary_value "$SUMMARY_CSV" "live_authority_observed_rows" "4" "v08-w fixture can exercise live-observed flags"
expect_summary_value "$SUMMARY_CSV" "declared_real_source_rows" "4" "v08-w fixture can exercise real declaration flags"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "0" "v08-w fixture must not count as non-fixture"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_review_ready" "1" "v08-w fixture should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_ready" "0" "v08-w fixture must not satisfy real authority"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-w fixture must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-w fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-official-authority-fixture-only" "v08-w fixture should block at fixture-only"

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
    if ($idx["gate"] == "source-import-real-verification" && $idx["status"] != "pass") die("v08-w real verification should pass", 20)
    if ($idx["gate"] == "official-authority-rows" && $idx["status"] != "pass") die("v08-w authority rows should pass", 21)
    if ($idx["gate"] == "official-authority-hash" && $idx["status"] != "pass") die("v08-w authority hash should pass", 22)
    if ($idx["gate"] == "official-authority-artifacts" && $idx["status"] != "pass") die("v08-w authority artifacts should pass", 23)
    if ($idx["gate"] == "official-authority-trust-root" && $idx["status"] != "blocked") die("v08-w fixture trust-root should block at non-fixture", 24)
    if ($idx["gate"] == "source-import-official-authority" && $idx["status"] != "blocked") die("v08-w official authority should block", 25)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-w source import should block", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-w real benchmark should block", 27)
  }
  END {
    if (rows != 8) die("expected eight v08-w decision rows", 28)
  }
' "$DECISION_CSV"

make_authority_csv "$REAL_VERIFICATION_CSV" "$BAD_DOMAIN_AUTHORITY_CSV" "wrong-authority-benchmarks.org" 1

run_with_upstream_fixtures "$BAD_DOMAIN_AUTHORITY_CSV"

expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "1" "v08-w bad-domain authority should preserve real verification readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_review_ready" "0" "v08-w bad-domain authority should block review readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_ready" "0" "v08-w bad-domain authority should block official authority"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-official-authority-domain-mismatch" "v08-w bad-domain authority should block at domain mismatch"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["verified_verification_report_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$OFFICIAL_AUTHORITY_CSV" >"$BAD_AUTHORITY_CSV"

run_with_upstream_fixtures "$BAD_AUTHORITY_CSV"

expect_summary_value "$SUMMARY_CSV" "source_import_real_verification_ready" "1" "v08-w bad authority should preserve real verification readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_review_ready" "0" "v08-w bad authority should block review readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_official_authority_ready" "0" "v08-w bad authority should block official authority"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-official-authority-hash-mismatch" "v08-w bad authority should block at hash mismatch"

{
  head -n 1 "$OFFICIAL_AUTHORITY_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$OFFICIAL_AUTHORITY_CSV")"
} >"$MALFORMED_AUTHORITY_CSV"

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
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV="$REAL_VERIFICATION_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV="$MALFORMED_AUTHORITY_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_official_authority_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-w should reject malformed official authority CSV row widths" >&2
  exit 40
fi

echo "v08 external benchmark source import official authority smoke passed"
