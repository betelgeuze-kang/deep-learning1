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
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_bad_hash_fixture.csv"
LOCAL_URI_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_local_uri_fixture.csv"
MISMATCH_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_mismatch_fixture.csv"
FIXTURE_ONLY_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_fixture_only_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-ah summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ah summary row", 4)
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

make_confirmation_csv() {
  local family
  local reproduction_id
  local release_id
  local live_report_uri
  local live_report_hash
  local network_uri
  local network_hash
  local verifier_uri
  local verifier_hash
  local slug

  {
    echo "benchmark_family,reproduction_id,release_id,live_verification_report_uri,live_verification_report_hash,network_observation_uri,network_observation_hash,verifier_identity_uri,verifier_identity_hash,canonical_confirmation_report_uri,canonical_confirmation_report_hash,runner_network_transcript_uri,runner_network_transcript_hash,tls_certificate_chain_uri,tls_certificate_chain_hash,dns_resolution_uri,dns_resolution_hash,http_response_header_uri,http_response_header_hash,content_digest_manifest_uri,content_digest_manifest_hash,confirmed_at_utc,live_verification_report_bound,network_observation_bound,verifier_identity_bound,canonical_confirmation_report_bound,runner_network_transcript_bound,tls_certificate_chain_bound,dns_resolution_bound,http_response_header_bound,content_digest_manifest_bound,runner_owned_confirmation_declared,canonical_authority_observed,online_fetch_declared,content_digest_match_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    awk -F, '
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        next
      }
      {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["reproduction_id"],
          $idx["release_id"],
          $idx["live_verification_report_uri"],
          $idx["live_verification_report_hash"],
          $idx["network_observation_uri"],
          $idx["network_observation_hash"],
          $idx["verifier_identity_uri"],
          $idx["verifier_identity_hash"]
      }
    ' "$LIVE_CSV" | while IFS=$'\t' read -r family reproduction_id release_id live_report_uri live_report_hash network_uri network_hash verifier_uri verifier_hash; do
      slug="$(slugify "$family")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,https://canonical-verifier.example.org/v08/%s/confirmation.json,%s,https://canonical-verifier.example.org/v08/%s/network-transcript.json,%s,https://canonical-verifier.example.org/v08/%s/tls-chain.json,%s,https://canonical-verifier.example.org/v08/%s/dns.json,%s,https://canonical-verifier.example.org/v08/%s/headers.json,%s,https://canonical-verifier.example.org/v08/%s/content-digest.json,%s,2026-06-03T00:00:00Z,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0\n" \
        "$family" \
        "$reproduction_id" \
        "$release_id" \
        "$live_report_uri" \
        "$live_report_hash" \
        "$network_uri" \
        "$network_hash" \
        "$verifier_uri" \
        "$verifier_hash" \
        "$slug" \
        "$(sha_text_uri "canonical-confirmation|$family|$release_id|$live_report_hash")" \
        "$slug" \
        "$(sha_text_uri "runner-network-transcript|$family|$release_id|$network_hash")" \
        "$slug" \
        "$(sha_text_uri "tls-chain|$family|$release_id")" \
        "$slug" \
        "$(sha_text_uri "dns|$family|$release_id")" \
        "$slug" \
        "$(sha_text_uri "headers|$family|$release_id")" \
        "$slug" \
        "$(sha_text_uri "content-digest|$family|$release_id|$verifier_hash")"
    done
  } >"$CONFIRMATION_CSV"
}

run_v08ah_with_confirmation() {
  local confirmation_csv="$1"

  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
  V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$confirmation_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_canonical_online_confirmation.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_canonical_online_confirmation.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "0" "default v08-ah live release verification should block"
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "0" "default v08-ah canonical confirmation should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ah must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-release-verification-not-ready" "default v08-ah action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_live_release_verification.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_canonical_online_confirmation.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "1" "v08-ah upstream v08-ag should pass"
expect_summary_value "$SUMMARY_CSV" "confirmation_rows" "0" "v08-ah missing confirmation should have zero rows"
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "0" "v08-ah should block before confirmation rows"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-canonical-online-confirmation-missing" "v08-ah missing confirmation action"

make_confirmation_csv
run_v08ah_with_confirmation "$CONFIRMATION_CSV"

expect_summary_value "$SUMMARY_CSV" "confirmation_source" "provided-csv" "v08-ah confirmation source should be provided"
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "1" "v08-ah upstream live release should pass"
expect_summary_value "$SUMMARY_CSV" "live_family_rows" "4" "v08-ah should see four live families"
expect_summary_value "$SUMMARY_CSV" "confirmation_rows" "4" "v08-ah confirmation should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ah confirmation should match all families"
expect_summary_value "$SUMMARY_CSV" "matched_live_family_rows" "4" "v08-ah should bind all live families"
expect_summary_value "$SUMMARY_CSV" "reproduction_id_match_rows" "4" "v08-ah reproduction IDs should match"
expect_summary_value "$SUMMARY_CSV" "release_id_match_rows" "4" "v08-ah release IDs should match"
expect_summary_value "$SUMMARY_CSV" "live_report_match_rows" "4" "v08-ah live reports should match"
expect_summary_value "$SUMMARY_CSV" "network_observation_match_rows" "4" "v08-ah network observations should match"
expect_summary_value "$SUMMARY_CSV" "verifier_identity_match_rows" "4" "v08-ah verifier identities should match"
expect_summary_value "$SUMMARY_CSV" "required_confirmation_hash_fields" "36" "v08-ah should require 36 confirmation hash fields"
expect_summary_value "$SUMMARY_CSV" "confirmation_hash_attested_fields" "36" "v08-ah should attest 36 confirmation hashes"
expect_summary_value "$SUMMARY_CSV" "required_confirmation_uri_fields" "36" "v08-ah should require 36 confirmation URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_confirmation_uri_fields" "36" "v08-ah should require HTTPS confirmation artifacts"
expect_summary_value "$SUMMARY_CSV" "local_confirmation_uri_fields" "0" "v08-ah should reject local confirmation artifacts"
expect_summary_value "$SUMMARY_CSV" "runner_owned_confirmation_declared_rows" "4" "v08-ah should require runner-owned declarations"
expect_summary_value "$SUMMARY_CSV" "canonical_authority_observed_rows" "4" "v08-ah should require canonical authority observations"
expect_summary_value "$SUMMARY_CSV" "online_fetch_declared_rows" "4" "v08-ah should require online fetch declarations"
expect_summary_value "$SUMMARY_CSV" "content_digest_match_declared_rows" "4" "v08-ah should require content digest matches"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-ah should require non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-ah should require fixture-free declarations"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-ah should require timestamps"
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "1" "v08-ah canonical confirmation should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ah must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-canonical-online-confirmation-ready-await-nonfixture-publication-result-review" "v08-ah good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ah routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ah active jump should stay zero"

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
    if ($idx["gate"] == "live-release-verification" && $idx["status"] != "pass") die("v08-ah live release verification should pass", 20)
    if ($idx["gate"] == "canonical-confirmation-coverage" && $idx["status"] != "pass") die("v08-ah confirmation coverage should pass", 21)
    if ($idx["gate"] == "canonical-confirmation-binding" && $idx["status"] != "pass") die("v08-ah confirmation binding should pass", 22)
    if ($idx["gate"] == "canonical-confirmation-hash-attestation" && $idx["status"] != "pass") die("v08-ah hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-canonical-confirmation-artifacts" && $idx["status"] != "pass") die("v08-ah nonlocal artifacts should pass", 24)
    if ($idx["gate"] == "canonical-confirmation-proof-bindings" && $idx["status"] != "pass") die("v08-ah proof bindings should pass", 25)
    if ($idx["gate"] == "canonical-confirmation-declarations" && $idx["status"] != "pass") die("v08-ah declarations should pass", 26)
    if ($idx["gate"] == "canonical-online-confirmation" && $idx["status"] != "pass") die("v08-ah canonical confirmation should pass", 27)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ah real benchmark should block", 28)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ah jump guardrail should pass", 29)
  }
  END {
    if (rows != 10) die("expected ten v08-ah decision rows", 30)
  }
' "$DECISION_CSV"

{
  head -n 1 "$CONFIRMATION_CSV"
  sed -n '2,$p' "$CONFIRMATION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $11 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

run_v08ah_with_confirmation "$BAD_HASH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "0" "v08-ah bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-canonical-online-confirmation-hash-attestation-missing" "v08-ah bad hash action"

{
  head -n 1 "$CONFIRMATION_CSV"
  sed -n '2,$p' "$CONFIRMATION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $10 = "file:///tmp/canonical-confirmation.json" } { print }'
} >"$LOCAL_URI_CSV"

run_v08ah_with_confirmation "$LOCAL_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "0" "v08-ah local URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_confirmation_uri_fields" "1" "v08-ah should count local confirmation URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-canonical-online-confirmation-local-artifact-uri" "v08-ah local URI action"

{
  head -n 1 "$CONFIRMATION_CSV"
  sed -n '2,$p' "$CONFIRMATION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $3 = "wrong-release-id" } { print }'
} >"$MISMATCH_CSV"

run_v08ah_with_confirmation "$MISMATCH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "0" "v08-ah release mismatch should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-canonical-online-confirmation-binding-mismatch" "v08-ah release mismatch action"

{
  head -n 1 "$CONFIRMATION_CSV"
  sed -n '2,$p' "$CONFIRMATION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $36 = 0; $37 = 1 } { print }'
} >"$FIXTURE_ONLY_CSV"

run_v08ah_with_confirmation "$FIXTURE_ONLY_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "canonical_online_confirmation_ready" "0" "v08-ah fixture declaration should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-canonical-online-confirmation-declaration-missing" "v08-ah fixture-only action"

{
  head -n 1 "$CONFIRMATION_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$CONFIRMATION_CSV")"
} >"$MALFORMED_CSV"

if run_v08ah_with_confirmation "$MALFORMED_CSV" >/dev/null 2>/dev/null; then
  echo "v08-ah should reject malformed canonical online confirmation CSV row widths" >&2
  exit 40
fi

run_v08ah_with_confirmation "$CONFIRMATION_CSV" >/dev/null

echo "v08 external benchmark canonical online confirmation smoke passed"
