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
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_bad_hash_fixture.csv"
LOCAL_URI_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_local_uri_fixture.csv"
PLACEHOLDER_URI_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_placeholder_uri_fixture.csv"
MISMATCH_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_mismatch_fixture.csv"
FIXTURE_ONLY_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_fixture_only_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-ai summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ai summary row", 4)
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

make_review_csv() {
  local family
  local reproduction_id
  local release_id
  local canonical_uri
  local canonical_hash
  local digest_uri
  local digest_hash
  local slug
  local domain="external-benchmark-review.org"
  local publication_review_uri
  local result_review_uri
  local publication_record_uri
  local result_record_uri
  local reviewer_identity_uri
  local publication_authority_uri
  local result_authority_uri

  {
    echo "benchmark_family,reproduction_id,release_id,canonical_confirmation_report_uri,canonical_confirmation_report_hash,content_digest_manifest_uri,content_digest_manifest_hash,publication_review_uri,publication_review_hash,result_review_uri,result_review_hash,publication_record_uri,publication_record_hash,result_record_uri,result_record_hash,reviewer_identity_uri,reviewer_identity_hash,publication_authority_uri,publication_authority_hash,result_authority_uri,result_authority_hash,reviewed_at_utc,canonical_confirmation_bound,content_digest_manifest_bound,publication_review_bound,result_review_bound,publication_record_bound,result_record_bound,reviewer_identity_bound,publication_authority_bound,result_authority_bound,independent_review_declared,publication_observed_declared,result_observed_declared,canonical_result_match_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    awk -F, '
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        next
      }
      {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["reproduction_id"],
          $idx["release_id"],
          $idx["canonical_confirmation_report_uri"],
          $idx["canonical_confirmation_report_hash"],
          $idx["content_digest_manifest_uri"],
          $idx["content_digest_manifest_hash"]
      }
    ' "$CONFIRMATION_CSV" | while IFS=$'\t' read -r family reproduction_id release_id canonical_uri canonical_hash digest_uri digest_hash; do
      slug="$(slugify "$family")"
      publication_review_uri="https://${domain}/v08/${slug}/publication-review.json"
      result_review_uri="https://${domain}/v08/${slug}/result-review.json"
      publication_record_uri="https://${domain}/v08/${slug}/publication-record.json"
      result_record_uri="https://${domain}/v08/${slug}/result-record.json"
      reviewer_identity_uri="https://${domain}/v08/${slug}/reviewer-identity.json"
      publication_authority_uri="https://${domain}/v08/${slug}/publication-authority.json"
      result_authority_uri="https://${domain}/v08/${slug}/result-authority.json"

      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-06-03T00:00:00Z,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0\n" \
        "$family" \
        "$reproduction_id" \
        "$release_id" \
        "$canonical_uri" \
        "$canonical_hash" \
        "$digest_uri" \
        "$digest_hash" \
        "$publication_review_uri" \
        "$(sha_text_uri "publication-review|$family|$release_id|$canonical_hash")" \
        "$result_review_uri" \
        "$(sha_text_uri "result-review|$family|$release_id|$digest_hash")" \
        "$publication_record_uri" \
        "$(sha_text_uri "publication-record|$family|$release_id")" \
        "$result_record_uri" \
        "$(sha_text_uri "result-record|$family|$release_id")" \
        "$reviewer_identity_uri" \
        "$(sha_text_uri "reviewer-identity|$family|$release_id")" \
        "$publication_authority_uri" \
        "$(sha_text_uri "publication-authority|$family|$release_id")" \
        "$result_authority_uri" \
        "$(sha_text_uri "result-authority|$family|$release_id")"
    done
  } >"$REVIEW_CSV"
}

run_v08ai_with_review() {
  local review_csv="${1:-}"

  if [[ -n "$review_csv" ]]; then
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
    V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
    V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
    V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
    V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_CSV" \
    V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$review_csv" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_publication_result_review.sh" --smoke
  else
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
    V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
    V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
    V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
    V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_CSV" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_publication_result_review.sh" --smoke
  fi
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_publication_result_review.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "0" "default v08-ai canonical confirmation should block"
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "default v08-ai review should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ai must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-canonical-online-confirmation-not-ready" "default v08-ai action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_canonical_online_confirmation.sh" >/dev/null

run_v08ai_with_review
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "1" "v08-ai upstream canonical confirmation should pass"
expect_summary_value "$SUMMARY_CSV" "review_rows" "0" "v08-ai missing review should have zero rows"
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "v08-ai should block before review rows"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-missing" "v08-ai missing review action"

make_review_csv
run_v08ai_with_review "$REVIEW_CSV"

expect_summary_value "$SUMMARY_CSV" "review_source" "provided-csv" "v08-ai review source should be provided"
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "1" "v08-ai upstream canonical confirmation should pass"
expect_summary_value "$SUMMARY_CSV" "canonical_family_rows" "4" "v08-ai should see four canonical families"
expect_summary_value "$SUMMARY_CSV" "review_rows" "4" "v08-ai review should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ai review should match all families"
expect_summary_value "$SUMMARY_CSV" "matched_canonical_family_rows" "4" "v08-ai should bind all canonical families"
expect_summary_value "$SUMMARY_CSV" "reproduction_id_match_rows" "4" "v08-ai reproduction IDs should match"
expect_summary_value "$SUMMARY_CSV" "release_id_match_rows" "4" "v08-ai release IDs should match"
expect_summary_value "$SUMMARY_CSV" "canonical_confirmation_match_rows" "4" "v08-ai canonical confirmation artifacts should match"
expect_summary_value "$SUMMARY_CSV" "content_digest_match_rows" "4" "v08-ai content digest artifacts should match"
expect_summary_value "$SUMMARY_CSV" "required_review_hash_fields" "36" "v08-ai should require 36 review hash fields"
expect_summary_value "$SUMMARY_CSV" "review_hash_attested_fields" "36" "v08-ai should attest 36 review hashes"
expect_summary_value "$SUMMARY_CSV" "required_review_uri_fields" "36" "v08-ai should require 36 review URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_review_uri_fields" "36" "v08-ai should require HTTPS review artifacts"
expect_summary_value "$SUMMARY_CSV" "local_review_uri_fields" "0" "v08-ai should reject local review artifacts"
expect_summary_value "$SUMMARY_CSV" "required_new_review_uri_fields" "28" "v08-ai should require 28 new review artifact URIs"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_new_review_uri_fields" "28" "v08-ai should require non-placeholder review artifacts"
expect_summary_value "$SUMMARY_CSV" "placeholder_new_review_uri_fields" "0" "v08-ai should reject placeholder review artifacts"
expect_summary_value "$SUMMARY_CSV" "canonical_confirmation_bound_rows" "4" "v08-ai should require canonical confirmation binding"
expect_summary_value "$SUMMARY_CSV" "content_digest_manifest_bound_rows" "4" "v08-ai should require content digest binding"
expect_summary_value "$SUMMARY_CSV" "publication_review_bound_rows" "4" "v08-ai should require publication review binding"
expect_summary_value "$SUMMARY_CSV" "result_review_bound_rows" "4" "v08-ai should require result review binding"
expect_summary_value "$SUMMARY_CSV" "publication_record_bound_rows" "4" "v08-ai should require publication record binding"
expect_summary_value "$SUMMARY_CSV" "result_record_bound_rows" "4" "v08-ai should require result record binding"
expect_summary_value "$SUMMARY_CSV" "reviewer_identity_bound_rows" "4" "v08-ai should require reviewer identity binding"
expect_summary_value "$SUMMARY_CSV" "publication_authority_bound_rows" "4" "v08-ai should require publication authority binding"
expect_summary_value "$SUMMARY_CSV" "result_authority_bound_rows" "4" "v08-ai should require result authority binding"
expect_summary_value "$SUMMARY_CSV" "independent_review_declared_rows" "4" "v08-ai should require independent review declarations"
expect_summary_value "$SUMMARY_CSV" "publication_observed_declared_rows" "4" "v08-ai should require publication observations"
expect_summary_value "$SUMMARY_CSV" "result_observed_declared_rows" "4" "v08-ai should require result observations"
expect_summary_value "$SUMMARY_CSV" "canonical_result_match_declared_rows" "4" "v08-ai should require canonical result match declarations"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-ai should require non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-ai should require fixture-free declarations"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-ai should require timestamps"
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "1" "v08-ai publication/result review should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ai must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-ready-await-live-ingestion-promotion-evidence" "v08-ai good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ai routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ai active jump should stay zero"

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
    if ($idx["gate"] == "canonical-online-confirmation" && $idx["status"] != "pass") die("v08-ai canonical confirmation should pass", 20)
    if ($idx["gate"] == "publication-result-review-coverage" && $idx["status"] != "pass") die("v08-ai review coverage should pass", 21)
    if ($idx["gate"] == "publication-result-review-binding" && $idx["status"] != "pass") die("v08-ai review binding should pass", 22)
    if ($idx["gate"] == "publication-result-review-hash-attestation" && $idx["status"] != "pass") die("v08-ai hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-publication-result-review-artifacts" && $idx["status"] != "pass") die("v08-ai nonlocal artifacts should pass", 24)
    if ($idx["gate"] == "nonplaceholder-publication-result-review-artifacts" && $idx["status"] != "pass") die("v08-ai nonplaceholder artifacts should pass", 25)
    if ($idx["gate"] == "publication-result-review-proof-bindings" && $idx["status"] != "pass") die("v08-ai proof bindings should pass", 26)
    if ($idx["gate"] == "publication-result-review-declarations" && $idx["status"] != "pass") die("v08-ai declarations should pass", 27)
    if ($idx["gate"] == "publication-result-review" && $idx["status"] != "pass") die("v08-ai publication/result review should pass", 28)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ai real benchmark should block", 29)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ai jump guardrail should pass", 30)
  }
  END {
    if (rows != 11) die("expected eleven v08-ai decision rows", 31)
  }
' "$DECISION_CSV"

{
  head -n 1 "$REVIEW_CSV"
  sed -n '2,$p' "$REVIEW_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $9 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

run_v08ai_with_review "$BAD_HASH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "v08-ai bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-hash-attestation-missing" "v08-ai bad hash action"

{
  head -n 1 "$REVIEW_CSV"
  sed -n '2,$p' "$REVIEW_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $8 = "file:///tmp/publication-review.json" } { print }'
} >"$LOCAL_URI_CSV"

run_v08ai_with_review "$LOCAL_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "v08-ai local URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_review_uri_fields" "1" "v08-ai should count local review URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-local-artifact-uri" "v08-ai local URI action"

{
  head -n 1 "$REVIEW_CSV"
  sed -n '2,$p' "$REVIEW_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $8 = "https://review.example.org/v08/publication-review.json" } { print }'
} >"$PLACEHOLDER_URI_CSV"

run_v08ai_with_review "$PLACEHOLDER_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "v08-ai placeholder URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "placeholder_new_review_uri_fields" "1" "v08-ai should count placeholder review URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-placeholder-artifact-uri" "v08-ai placeholder URI action"

{
  head -n 1 "$REVIEW_CSV"
  sed -n '2,$p' "$REVIEW_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $3 = "wrong-release-id" } { print }'
} >"$MISMATCH_CSV"

run_v08ai_with_review "$MISMATCH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "v08-ai release mismatch should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-binding-mismatch" "v08-ai release mismatch action"

{
  head -n 1 "$REVIEW_CSV"
  sed -n '2,$p' "$REVIEW_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $36 = 0; $37 = 1 } { print }'
} >"$FIXTURE_ONLY_CSV"

run_v08ai_with_review "$FIXTURE_ONLY_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "publication_result_review_ready" "0" "v08-ai fixture declaration should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-result-review-declaration-missing" "v08-ai fixture-only action"

{
  head -n 1 "$REVIEW_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$REVIEW_CSV")"
} >"$MALFORMED_CSV"

if run_v08ai_with_review "$MALFORMED_CSV" >/dev/null 2>/dev/null; then
  echo "v08-ai should reject malformed publication/result review CSV row widths" >&2
  exit 40
fi

run_v08ai_with_review "$REVIEW_CSV" >/dev/null

echo "v08 external benchmark publication/result review smoke passed"
