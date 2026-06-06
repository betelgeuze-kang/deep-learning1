#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_content_fixture.csv"
BRIDGE_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_bridge_fixture.csv"
REPRODUCTION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_fixture.csv"
RELEASE_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_fixture.csv"
LIVE_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_fixture.csv"
CONFIRMATION_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_fixture.csv"
REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_fixture.csv"
INGESTION_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_bad_hash_fixture.csv"
LOCAL_URI_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_local_uri_fixture.csv"
PLACEHOLDER_URI_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_placeholder_uri_fixture.csv"
MISMATCH_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_mismatch_fixture.csv"
FIXTURE_ONLY_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_fixture_only_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_smoke_decision.csv"

mkdir -p "$RESULTS_DIR"

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
      if (!(field in idx)) die("missing v08-aj summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-aj summary row", 4)
    }
  ' "$summary_csv"
}

sha_text_uri() {
  local text="$1"
  printf 'sha256:%s\n' "$(printf '%s' "$text" | sha256sum | awk '{print $1}')"
}

slugify() {
  local value="$1"
  printf '%s\n' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-//; s/-$//'
}

make_ingestion_csv() {
  local family
  local reproduction_id
  local release_id
  local publication_review_uri
  local publication_review_hash
  local result_review_uri
  local result_review_hash
  local publication_record_uri
  local publication_record_hash
  local result_record_uri
  local result_record_hash
  local slug
  local domain="live-benchmark-ingestion.org"
  local live_publication_record_uri
  local live_result_record_uri
  local publication_ingest_transcript_uri
  local result_ingest_transcript_uri
  local publication_response_header_uri
  local result_response_header_uri
  local publication_content_digest_uri
  local result_content_digest_uri
  local publication_tls_certificate_chain_uri
  local result_tls_certificate_chain_uri

  {
    echo "benchmark_family,reproduction_id,release_id,publication_review_uri,publication_review_hash,result_review_uri,result_review_hash,publication_record_uri,publication_record_hash,result_record_uri,result_record_hash,live_publication_record_uri,live_publication_record_hash,live_result_record_uri,live_result_record_hash,publication_ingest_transcript_uri,publication_ingest_transcript_hash,result_ingest_transcript_uri,result_ingest_transcript_hash,publication_response_header_uri,publication_response_header_hash,result_response_header_uri,result_response_header_hash,publication_content_digest_uri,publication_content_digest_hash,result_content_digest_uri,result_content_digest_hash,publication_tls_certificate_chain_uri,publication_tls_certificate_chain_hash,result_tls_certificate_chain_uri,result_tls_certificate_chain_hash,ingested_at_utc,publication_review_bound,result_review_bound,publication_record_bound,result_record_bound,live_publication_record_bound,live_result_record_bound,publication_ingest_transcript_bound,result_ingest_transcript_bound,publication_response_header_bound,result_response_header_bound,publication_content_digest_bound,result_content_digest_bound,publication_tls_certificate_chain_bound,result_tls_certificate_chain_bound,runner_owned_ingestion_declared,live_network_ingestion_declared,publication_record_digest_match_declared,result_record_digest_match_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    awk -F, '
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        next
      }
      {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["reproduction_id"],
          $idx["release_id"],
          $idx["publication_review_uri"],
          $idx["publication_review_hash"],
          $idx["result_review_uri"],
          $idx["result_review_hash"],
          $idx["publication_record_uri"],
          $idx["publication_record_hash"],
          $idx["result_record_uri"],
          $idx["result_record_hash"]
      }
    ' "$REVIEW_CSV" | while IFS=$'\t' read -r family reproduction_id release_id publication_review_uri publication_review_hash result_review_uri result_review_hash publication_record_uri publication_record_hash result_record_uri result_record_hash; do
      slug="$(slugify "$family")"
      live_publication_record_uri="https://${domain}/v08/${slug}/live-publication-record.json"
      live_result_record_uri="https://${domain}/v08/${slug}/live-result-record.json"
      publication_ingest_transcript_uri="https://${domain}/v08/${slug}/publication-ingest-transcript.json"
      result_ingest_transcript_uri="https://${domain}/v08/${slug}/result-ingest-transcript.json"
      publication_response_header_uri="https://${domain}/v08/${slug}/publication-response-header.json"
      result_response_header_uri="https://${domain}/v08/${slug}/result-response-header.json"
      publication_content_digest_uri="https://${domain}/v08/${slug}/publication-content-digest.json"
      result_content_digest_uri="https://${domain}/v08/${slug}/result-content-digest.json"
      publication_tls_certificate_chain_uri="https://${domain}/v08/${slug}/publication-tls-certificate-chain.pem"
      result_tls_certificate_chain_uri="https://${domain}/v08/${slug}/result-tls-certificate-chain.pem"

      row=(
        "$family"
        "$reproduction_id"
        "$release_id"
        "$publication_review_uri"
        "$publication_review_hash"
        "$result_review_uri"
        "$result_review_hash"
        "$publication_record_uri"
        "$publication_record_hash"
        "$result_record_uri"
        "$result_record_hash"
        "$live_publication_record_uri"
        "$(sha_text_uri "live-publication-record|$family|$release_id|$publication_record_hash")"
        "$live_result_record_uri"
        "$(sha_text_uri "live-result-record|$family|$release_id|$result_record_hash")"
        "$publication_ingest_transcript_uri"
        "$(sha_text_uri "publication-ingest-transcript|$family|$release_id")"
        "$result_ingest_transcript_uri"
        "$(sha_text_uri "result-ingest-transcript|$family|$release_id")"
        "$publication_response_header_uri"
        "$(sha_text_uri "publication-response-header|$family|$release_id")"
        "$result_response_header_uri"
        "$(sha_text_uri "result-response-header|$family|$release_id")"
        "$publication_content_digest_uri"
        "$(sha_text_uri "publication-content-digest|$family|$release_id")"
        "$result_content_digest_uri"
        "$(sha_text_uri "result-content-digest|$family|$release_id")"
        "$publication_tls_certificate_chain_uri"
        "$(sha_text_uri "publication-tls-certificate-chain|$family|$release_id")"
        "$result_tls_certificate_chain_uri"
        "$(sha_text_uri "result-tls-certificate-chain|$family|$release_id")"
        "2026-06-03T00:00:00Z"
        1 1 1 1
        1 1 1 1
        1 1 1 1
        1 1
        1 1 1 1 1 0
        0 0
      )
      (IFS=,; echo "${row[*]}")
    done
  } >"$INGESTION_CSV"
}

run_v08aj_with_ingestion() {
  local ingestion_csv="${1:-}"

  if [[ -n "$ingestion_csv" ]]; then
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
    V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
    V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
    V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
    V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_CSV" \
    V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV="$ingestion_csv" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_live_publication_result_ingestion.sh" --smoke
  else
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
    V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
    V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
    V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
    V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_CSV" \
    V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$REVIEW_CSV" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_live_publication_result_ingestion.sh" --smoke
  fi
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_publication_result_ingestion.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "default v08-aj publication/result review should block"
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "default v08-aj ingestion should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-aj must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-not-ready" "default v08-aj action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_publication_result_review.sh" >/dev/null

run_v08aj_with_ingestion
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "1" "v08-aj upstream publication/result review should pass"
expect_summary_value "$SUMMARY_CSV" "ingestion_rows" "0" "v08-aj missing ingestion should have zero rows"
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "v08-aj should block before ingestion rows"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-missing" "v08-aj missing ingestion action"

make_ingestion_csv
run_v08aj_with_ingestion "$INGESTION_CSV"

expect_summary_value "$SUMMARY_CSV" "ingestion_source" "provided-csv" "v08-aj ingestion source should be provided"
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "1" "v08-aj upstream review should pass"
expect_summary_value "$SUMMARY_CSV" "review_family_rows" "4" "v08-aj should see four review families"
expect_summary_value "$SUMMARY_CSV" "ingestion_rows" "4" "v08-aj ingestion should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-aj ingestion should match all families"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-aj should reject duplicate families"
expect_summary_value "$SUMMARY_CSV" "matched_review_family_rows" "4" "v08-aj should bind all review families"
expect_summary_value "$SUMMARY_CSV" "reproduction_id_match_rows" "4" "v08-aj reproduction IDs should match"
expect_summary_value "$SUMMARY_CSV" "release_id_match_rows" "4" "v08-aj release IDs should match"
expect_summary_value "$SUMMARY_CSV" "publication_review_match_rows" "4" "v08-aj publication review artifacts should match"
expect_summary_value "$SUMMARY_CSV" "result_review_match_rows" "4" "v08-aj result review artifacts should match"
expect_summary_value "$SUMMARY_CSV" "publication_record_match_rows" "4" "v08-aj publication record artifacts should match"
expect_summary_value "$SUMMARY_CSV" "result_record_match_rows" "4" "v08-aj result record artifacts should match"
expect_summary_value "$SUMMARY_CSV" "required_ingestion_hash_fields" "56" "v08-aj should require 56 ingestion hash fields"
expect_summary_value "$SUMMARY_CSV" "ingestion_hash_attested_fields" "56" "v08-aj should attest 56 ingestion hashes"
expect_summary_value "$SUMMARY_CSV" "required_ingestion_uri_fields" "56" "v08-aj should require 56 ingestion URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_ingestion_uri_fields" "56" "v08-aj should require HTTPS ingestion artifacts"
expect_summary_value "$SUMMARY_CSV" "local_ingestion_uri_fields" "0" "v08-aj should reject local ingestion artifacts"
expect_summary_value "$SUMMARY_CSV" "required_new_ingestion_uri_fields" "40" "v08-aj should require 40 new ingestion artifact URIs"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_new_ingestion_uri_fields" "40" "v08-aj should require non-placeholder ingestion artifacts"
expect_summary_value "$SUMMARY_CSV" "placeholder_new_ingestion_uri_fields" "0" "v08-aj should reject placeholder ingestion artifacts"
expect_summary_value "$SUMMARY_CSV" "publication_review_bound_rows" "4" "v08-aj should require publication review binding"
expect_summary_value "$SUMMARY_CSV" "result_review_bound_rows" "4" "v08-aj should require result review binding"
expect_summary_value "$SUMMARY_CSV" "publication_record_bound_rows" "4" "v08-aj should require publication record binding"
expect_summary_value "$SUMMARY_CSV" "result_record_bound_rows" "4" "v08-aj should require result record binding"
expect_summary_value "$SUMMARY_CSV" "live_publication_record_bound_rows" "4" "v08-aj should require live publication record binding"
expect_summary_value "$SUMMARY_CSV" "live_result_record_bound_rows" "4" "v08-aj should require live result record binding"
expect_summary_value "$SUMMARY_CSV" "publication_ingest_transcript_bound_rows" "4" "v08-aj should require publication ingest transcript binding"
expect_summary_value "$SUMMARY_CSV" "result_ingest_transcript_bound_rows" "4" "v08-aj should require result ingest transcript binding"
expect_summary_value "$SUMMARY_CSV" "publication_response_header_bound_rows" "4" "v08-aj should require publication response header binding"
expect_summary_value "$SUMMARY_CSV" "result_response_header_bound_rows" "4" "v08-aj should require result response header binding"
expect_summary_value "$SUMMARY_CSV" "publication_content_digest_bound_rows" "4" "v08-aj should require publication content digest binding"
expect_summary_value "$SUMMARY_CSV" "result_content_digest_bound_rows" "4" "v08-aj should require result content digest binding"
expect_summary_value "$SUMMARY_CSV" "publication_tls_certificate_chain_bound_rows" "4" "v08-aj should require publication TLS binding"
expect_summary_value "$SUMMARY_CSV" "result_tls_certificate_chain_bound_rows" "4" "v08-aj should require result TLS binding"
expect_summary_value "$SUMMARY_CSV" "runner_owned_ingestion_declared_rows" "4" "v08-aj should require runner-owned ingestion declarations"
expect_summary_value "$SUMMARY_CSV" "live_network_ingestion_declared_rows" "4" "v08-aj should require live-network ingestion declarations"
expect_summary_value "$SUMMARY_CSV" "publication_record_digest_match_declared_rows" "4" "v08-aj should require publication digest match declarations"
expect_summary_value "$SUMMARY_CSV" "result_record_digest_match_declared_rows" "4" "v08-aj should require result digest match declarations"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-aj should require non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-aj should require fixture-free declarations"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-aj should require timestamps"
expect_summary_value "$SUMMARY_CSV" "ingestion_family_coverage" "4" "v08-aj should cover all families"
expect_summary_value "$SUMMARY_CSV" "expected_external_families" "4" "v08-aj should expect four families"
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "1" "v08-aj live ingestion should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-aj must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-ready-await-promotion-authority-evidence" "v08-aj good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-aj routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-aj active jump should stay zero"

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
    if ($idx["gate"] == "publication-result-review" && $idx["status"] != "pass") die("v08-aj upstream review should pass", 20)
    if ($idx["gate"] == "live-publication-result-ingestion-coverage" && $idx["status"] != "pass") die("v08-aj coverage should pass", 21)
    if ($idx["gate"] == "live-publication-result-ingestion-binding" && $idx["status"] != "pass") die("v08-aj binding should pass", 22)
    if ($idx["gate"] == "live-publication-result-ingestion-hash-attestation" && $idx["status"] != "pass") die("v08-aj hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-live-publication-result-ingestion-artifacts" && $idx["status"] != "pass") die("v08-aj nonlocal artifacts should pass", 24)
    if ($idx["gate"] == "nonplaceholder-live-publication-result-ingestion-artifacts" && $idx["status"] != "pass") die("v08-aj nonplaceholder artifacts should pass", 25)
    if ($idx["gate"] == "live-publication-result-ingestion-proof-bindings" && $idx["status"] != "pass") die("v08-aj proof bindings should pass", 26)
    if ($idx["gate"] == "live-publication-result-ingestion-declarations" && $idx["status"] != "pass") die("v08-aj declarations should pass", 27)
    if ($idx["gate"] == "live-publication-result-ingestion" && $idx["status"] != "pass") die("v08-aj live ingestion should pass", 28)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-aj real benchmark should block", 29)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-aj jump guardrail should pass", 30)
  }
  END {
    if (rows != 11) die("expected eleven v08-aj decision rows", 31)
  }
' "$DECISION_CSV"

{
  head -n 1 "$INGESTION_CSV"
  sed -n '2,$p' "$INGESTION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $13 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

run_v08aj_with_ingestion "$BAD_HASH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "v08-aj bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-hash-attestation-missing" "v08-aj bad hash action"

{
  head -n 1 "$INGESTION_CSV"
  sed -n '2,$p' "$INGESTION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $12 = "file:///tmp/live-publication-record.json" } { print }'
} >"$LOCAL_URI_CSV"

run_v08aj_with_ingestion "$LOCAL_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "v08-aj local URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_ingestion_uri_fields" "1" "v08-aj should count local ingestion URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-local-artifact-uri" "v08-aj local URI action"

{
  head -n 1 "$INGESTION_CSV"
  sed -n '2,$p' "$INGESTION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $12 = "https://ingest.example.org/v08/live-publication-record.json" } { print }'
} >"$PLACEHOLDER_URI_CSV"

run_v08aj_with_ingestion "$PLACEHOLDER_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "v08-aj placeholder URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "placeholder_new_ingestion_uri_fields" "1" "v08-aj should count placeholder ingestion URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-placeholder-artifact-uri" "v08-aj placeholder URI action"

{
  head -n 1 "$INGESTION_CSV"
  sed -n '2,$p' "$INGESTION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $3 = "wrong-release-id" } { print }'
} >"$MISMATCH_CSV"

run_v08aj_with_ingestion "$MISMATCH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "v08-aj release mismatch should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-binding-mismatch" "v08-aj release mismatch action"

{
  head -n 1 "$INGESTION_CSV"
  sed -n '2,$p' "$INGESTION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $51 = 0; $52 = 1 } { print }'
} >"$FIXTURE_ONLY_CSV"

run_v08aj_with_ingestion "$FIXTURE_ONLY_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "v08-aj fixture declaration should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-declaration-missing" "v08-aj fixture-only action"

{
  head -n 1 "$INGESTION_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$INGESTION_CSV")"
} >"$MALFORMED_CSV"

if run_v08aj_with_ingestion "$MALFORMED_CSV" >/dev/null 2>/dev/null; then
  echo "v08-aj should reject malformed live publication/result ingestion CSV row widths" >&2
  exit 40
fi

run_v08aj_with_ingestion "$INGESTION_CSV" >/dev/null

echo "v08 external benchmark live publication/result ingestion smoke passed"
