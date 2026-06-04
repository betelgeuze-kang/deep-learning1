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
AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_bad_hash_fixture.csv"
LOCAL_URI_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_local_uri_fixture.csv"
PLACEHOLDER_URI_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_placeholder_uri_fixture.csv"
MISMATCH_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_mismatch_fixture.csv"
FIXTURE_ONLY_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_fixture_only_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-ak summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ak summary row", 4)
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

make_authority_csv() {
  local family
  local reproduction_id
  local release_id
  local live_publication_record_uri
  local live_publication_record_hash
  local live_result_record_uri
  local live_result_record_hash
  local publication_content_digest_uri
  local publication_content_digest_hash
  local result_content_digest_uri
  local result_content_digest_hash
  local slug
  local domain="benchmark-authority-promotion.org"
  local authority_decision_uri
  local promotion_review_uri
  local benchmark_registry_entry_uri
  local leaderboard_entry_uri
  local reproducibility_package_uri
  local artifact_archive_uri
  local authority_identity_uri
  local authority_conflict_disclosure_uri
  local promotion_trace_uri
  local final_claim_packet_uri

  {
    echo "benchmark_family,reproduction_id,release_id,live_publication_record_uri,live_publication_record_hash,live_result_record_uri,live_result_record_hash,publication_content_digest_uri,publication_content_digest_hash,result_content_digest_uri,result_content_digest_hash,authority_decision_uri,authority_decision_hash,promotion_review_uri,promotion_review_hash,benchmark_registry_entry_uri,benchmark_registry_entry_hash,leaderboard_entry_uri,leaderboard_entry_hash,reproducibility_package_uri,reproducibility_package_hash,artifact_archive_uri,artifact_archive_hash,authority_identity_uri,authority_identity_hash,authority_conflict_disclosure_uri,authority_conflict_disclosure_hash,promotion_trace_uri,promotion_trace_hash,final_claim_packet_uri,final_claim_packet_hash,promoted_at_utc,live_publication_record_bound,live_result_record_bound,publication_content_digest_bound,result_content_digest_bound,authority_decision_bound,promotion_review_bound,benchmark_registry_entry_bound,leaderboard_entry_bound,reproducibility_package_bound,artifact_archive_bound,authority_identity_bound,authority_conflict_disclosure_bound,promotion_trace_bound,final_claim_packet_bound,independent_authority_declared,official_result_authority_declared,benchmark_owner_registry_declared,publication_result_consistent_declared,claim_scope_limited_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
          $idx["live_publication_record_uri"],
          $idx["live_publication_record_hash"],
          $idx["live_result_record_uri"],
          $idx["live_result_record_hash"],
          $idx["publication_content_digest_uri"],
          $idx["publication_content_digest_hash"],
          $idx["result_content_digest_uri"],
          $idx["result_content_digest_hash"]
      }
    ' "$INGESTION_CSV" | while IFS=$'\t' read -r family reproduction_id release_id live_publication_record_uri live_publication_record_hash live_result_record_uri live_result_record_hash publication_content_digest_uri publication_content_digest_hash result_content_digest_uri result_content_digest_hash; do
      slug="$(slugify "$family")"
      authority_decision_uri="https://${domain}/v08/${slug}/authority-decision.json"
      promotion_review_uri="https://${domain}/v08/${slug}/promotion-review.json"
      benchmark_registry_entry_uri="https://${domain}/v08/${slug}/benchmark-registry-entry.json"
      leaderboard_entry_uri="https://${domain}/v08/${slug}/leaderboard-entry.json"
      reproducibility_package_uri="https://${domain}/v08/${slug}/reproducibility-package.json"
      artifact_archive_uri="https://${domain}/v08/${slug}/artifact-archive.json"
      authority_identity_uri="https://${domain}/v08/${slug}/authority-identity.json"
      authority_conflict_disclosure_uri="https://${domain}/v08/${slug}/authority-conflict-disclosure.json"
      promotion_trace_uri="https://${domain}/v08/${slug}/promotion-trace.json"
      final_claim_packet_uri="https://${domain}/v08/${slug}/final-claim-packet.json"

      row=(
        "$family"
        "$reproduction_id"
        "$release_id"
        "$live_publication_record_uri"
        "$live_publication_record_hash"
        "$live_result_record_uri"
        "$live_result_record_hash"
        "$publication_content_digest_uri"
        "$publication_content_digest_hash"
        "$result_content_digest_uri"
        "$result_content_digest_hash"
        "$authority_decision_uri"
        "$(sha_text_uri "authority-decision|$family|$release_id|$live_publication_record_hash")"
        "$promotion_review_uri"
        "$(sha_text_uri "promotion-review|$family|$release_id|$live_result_record_hash")"
        "$benchmark_registry_entry_uri"
        "$(sha_text_uri "benchmark-registry-entry|$family|$release_id")"
        "$leaderboard_entry_uri"
        "$(sha_text_uri "leaderboard-entry|$family|$release_id")"
        "$reproducibility_package_uri"
        "$(sha_text_uri "reproducibility-package|$family|$release_id")"
        "$artifact_archive_uri"
        "$(sha_text_uri "artifact-archive|$family|$release_id")"
        "$authority_identity_uri"
        "$(sha_text_uri "authority-identity|$family|$release_id")"
        "$authority_conflict_disclosure_uri"
        "$(sha_text_uri "authority-conflict-disclosure|$family|$release_id")"
        "$promotion_trace_uri"
        "$(sha_text_uri "promotion-trace|$family|$release_id")"
        "$final_claim_packet_uri"
        "$(sha_text_uri "final-claim-packet|$family|$release_id")"
        "2026-06-03T00:00:00Z"
        1 1 1 1
        1 1 1 1 1 1
        1 1 1 1
        1 1 1 1 1 1 0
        0 0
      )
      (IFS=,; echo "${row[*]}")
    done
  } >"$AUTHORITY_CSV"
}

run_v08ak_with_authority() {
  local authority_csv="${1:-}"

  if [[ -n "$authority_csv" ]]; then
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
    V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
    V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
    V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
    V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_CSV" \
    V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV="$INGESTION_CSV" \
    V08_EXTERNAL_BENCHMARK_AUTHORITY_PROMOTION_EVIDENCE_CSV="$authority_csv" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_authority_promotion_evidence.sh" --smoke
  else
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
    V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
    V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
    V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
    V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_CSV" \
    V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV="$INGESTION_CSV" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_authority_promotion_evidence.sh" --smoke
  fi
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_authority_promotion_evidence.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "0" "default v08-ak live ingestion should block"
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "default v08-ak authority should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ak must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-publication-result-ingestion-not-ready" "default v08-ak action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_live_publication_result_ingestion.sh" >/dev/null

run_v08ak_with_authority
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "1" "v08-ak upstream live ingestion should pass"
expect_summary_value "$SUMMARY_CSV" "authority_rows" "0" "v08-ak missing authority should have zero rows"
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "v08-ak should block before authority rows"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-missing" "v08-ak missing authority action"

make_authority_csv
run_v08ak_with_authority "$AUTHORITY_CSV"

expect_summary_value "$SUMMARY_CSV" "authority_source" "provided-csv" "v08-ak authority source should be provided"
expect_summary_value "$SUMMARY_CSV" "live_publication_result_ingestion_ready" "1" "v08-ak upstream ingestion should pass"
expect_summary_value "$SUMMARY_CSV" "ingestion_family_rows" "4" "v08-ak should see four ingestion families"
expect_summary_value "$SUMMARY_CSV" "authority_rows" "4" "v08-ak authority should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ak authority should match all families"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-ak should reject duplicate families"
expect_summary_value "$SUMMARY_CSV" "matched_ingestion_family_rows" "4" "v08-ak should bind all ingestion families"
expect_summary_value "$SUMMARY_CSV" "reproduction_id_match_rows" "4" "v08-ak reproduction IDs should match"
expect_summary_value "$SUMMARY_CSV" "release_id_match_rows" "4" "v08-ak release IDs should match"
expect_summary_value "$SUMMARY_CSV" "live_publication_record_match_rows" "4" "v08-ak live publication records should match"
expect_summary_value "$SUMMARY_CSV" "live_result_record_match_rows" "4" "v08-ak live result records should match"
expect_summary_value "$SUMMARY_CSV" "publication_content_digest_match_rows" "4" "v08-ak publication digests should match"
expect_summary_value "$SUMMARY_CSV" "result_content_digest_match_rows" "4" "v08-ak result digests should match"
expect_summary_value "$SUMMARY_CSV" "required_authority_hash_fields" "56" "v08-ak should require 56 authority hash fields"
expect_summary_value "$SUMMARY_CSV" "authority_hash_attested_fields" "56" "v08-ak should attest 56 authority hashes"
expect_summary_value "$SUMMARY_CSV" "required_authority_uri_fields" "56" "v08-ak should require 56 authority URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_authority_uri_fields" "56" "v08-ak should require HTTPS authority artifacts"
expect_summary_value "$SUMMARY_CSV" "local_authority_uri_fields" "0" "v08-ak should reject local authority artifacts"
expect_summary_value "$SUMMARY_CSV" "required_new_authority_uri_fields" "40" "v08-ak should require 40 new authority artifact URIs"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_new_authority_uri_fields" "40" "v08-ak should require non-placeholder authority artifacts"
expect_summary_value "$SUMMARY_CSV" "placeholder_new_authority_uri_fields" "0" "v08-ak should reject placeholder authority artifacts"
expect_summary_value "$SUMMARY_CSV" "live_publication_record_bound_rows" "4" "v08-ak should require live publication record binding"
expect_summary_value "$SUMMARY_CSV" "live_result_record_bound_rows" "4" "v08-ak should require live result record binding"
expect_summary_value "$SUMMARY_CSV" "publication_content_digest_bound_rows" "4" "v08-ak should require publication digest binding"
expect_summary_value "$SUMMARY_CSV" "result_content_digest_bound_rows" "4" "v08-ak should require result digest binding"
expect_summary_value "$SUMMARY_CSV" "authority_decision_bound_rows" "4" "v08-ak should require authority decision binding"
expect_summary_value "$SUMMARY_CSV" "promotion_review_bound_rows" "4" "v08-ak should require promotion review binding"
expect_summary_value "$SUMMARY_CSV" "benchmark_registry_entry_bound_rows" "4" "v08-ak should require benchmark registry binding"
expect_summary_value "$SUMMARY_CSV" "leaderboard_entry_bound_rows" "4" "v08-ak should require leaderboard binding"
expect_summary_value "$SUMMARY_CSV" "reproducibility_package_bound_rows" "4" "v08-ak should require reproducibility package binding"
expect_summary_value "$SUMMARY_CSV" "artifact_archive_bound_rows" "4" "v08-ak should require artifact archive binding"
expect_summary_value "$SUMMARY_CSV" "authority_identity_bound_rows" "4" "v08-ak should require authority identity binding"
expect_summary_value "$SUMMARY_CSV" "authority_conflict_disclosure_bound_rows" "4" "v08-ak should require conflict disclosure binding"
expect_summary_value "$SUMMARY_CSV" "promotion_trace_bound_rows" "4" "v08-ak should require promotion trace binding"
expect_summary_value "$SUMMARY_CSV" "final_claim_packet_bound_rows" "4" "v08-ak should require final claim packet binding"
expect_summary_value "$SUMMARY_CSV" "independent_authority_declared_rows" "4" "v08-ak should require independent authority declarations"
expect_summary_value "$SUMMARY_CSV" "official_result_authority_declared_rows" "4" "v08-ak should require official result authority declarations"
expect_summary_value "$SUMMARY_CSV" "benchmark_owner_registry_declared_rows" "4" "v08-ak should require benchmark registry declarations"
expect_summary_value "$SUMMARY_CSV" "publication_result_consistent_declared_rows" "4" "v08-ak should require publication/result consistency declarations"
expect_summary_value "$SUMMARY_CSV" "claim_scope_limited_declared_rows" "4" "v08-ak should require limited claim-scope declarations"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-ak should require non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-ak should require fixture-free declarations"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-ak should require timestamps"
expect_summary_value "$SUMMARY_CSV" "authority_family_coverage" "4" "v08-ak should cover all families"
expect_summary_value "$SUMMARY_CSV" "expected_external_families" "4" "v08-ak should expect four families"
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "1" "v08-ak authority promotion evidence should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ak must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-ready-await-real-external-benchmark-run-evidence" "v08-ak good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ak routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ak active jump should stay zero"

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
    if ($idx["gate"] == "live-publication-result-ingestion" && $idx["status"] != "pass") die("v08-ak upstream live ingestion should pass", 20)
    if ($idx["gate"] == "authority-promotion-evidence-coverage" && $idx["status"] != "pass") die("v08-ak coverage should pass", 21)
    if ($idx["gate"] == "authority-promotion-evidence-binding" && $idx["status"] != "pass") die("v08-ak binding should pass", 22)
    if ($idx["gate"] == "authority-promotion-evidence-hash-attestation" && $idx["status"] != "pass") die("v08-ak hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-authority-promotion-evidence-artifacts" && $idx["status"] != "pass") die("v08-ak nonlocal artifacts should pass", 24)
    if ($idx["gate"] == "nonplaceholder-authority-promotion-evidence-artifacts" && $idx["status"] != "pass") die("v08-ak nonplaceholder artifacts should pass", 25)
    if ($idx["gate"] == "authority-promotion-evidence-proof-bindings" && $idx["status"] != "pass") die("v08-ak proof bindings should pass", 26)
    if ($idx["gate"] == "authority-promotion-evidence-declarations" && $idx["status"] != "pass") die("v08-ak declarations should pass", 27)
    if ($idx["gate"] == "authority-promotion-evidence" && $idx["status"] != "pass") die("v08-ak authority evidence should pass", 28)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ak real benchmark should block", 29)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ak jump guardrail should pass", 30)
  }
  END {
    if (rows != 11) die("expected eleven v08-ak decision rows", 31)
  }
' "$DECISION_CSV"

{
  head -n 1 "$AUTHORITY_CSV"
  sed -n '2,$p' "$AUTHORITY_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $13 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

run_v08ak_with_authority "$BAD_HASH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "v08-ak bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-hash-attestation-missing" "v08-ak bad hash action"

{
  head -n 1 "$AUTHORITY_CSV"
  sed -n '2,$p' "$AUTHORITY_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $12 = "file:///tmp/authority-decision.json" } { print }'
} >"$LOCAL_URI_CSV"

run_v08ak_with_authority "$LOCAL_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "v08-ak local URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_authority_uri_fields" "1" "v08-ak should count local authority URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-local-artifact-uri" "v08-ak local URI action"

{
  head -n 1 "$AUTHORITY_CSV"
  sed -n '2,$p' "$AUTHORITY_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $12 = "https://authority.example.org/v08/authority-decision.json" } { print }'
} >"$PLACEHOLDER_URI_CSV"

run_v08ak_with_authority "$PLACEHOLDER_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "v08-ak placeholder URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "placeholder_new_authority_uri_fields" "1" "v08-ak should count placeholder authority URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-placeholder-artifact-uri" "v08-ak placeholder URI action"

{
  head -n 1 "$AUTHORITY_CSV"
  sed -n '2,$p' "$AUTHORITY_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $3 = "wrong-release-id" } { print }'
} >"$MISMATCH_CSV"

run_v08ak_with_authority "$MISMATCH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "v08-ak release mismatch should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-binding-mismatch" "v08-ak release mismatch action"

{
  head -n 1 "$AUTHORITY_CSV"
  sed -n '2,$p' "$AUTHORITY_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $52 = 0; $53 = 1 } { print }'
} >"$FIXTURE_ONLY_CSV"

run_v08ak_with_authority "$FIXTURE_ONLY_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "v08-ak fixture declaration should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-declaration-missing" "v08-ak fixture-only action"

{
  head -n 1 "$AUTHORITY_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$AUTHORITY_CSV")"
} >"$MALFORMED_CSV"

if run_v08ak_with_authority "$MALFORMED_CSV" >/dev/null 2>/dev/null; then
  echo "v08-ak should reject malformed authority promotion evidence CSV row widths" >&2
  exit 40
fi

run_v08ak_with_authority "$AUTHORITY_CSV" >/dev/null

echo "v08 external benchmark authority/promotion evidence smoke passed"
