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
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_bad_hash_fixture.csv"
LOCAL_URI_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_local_uri_fixture.csv"
MISMATCH_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_mismatch_fixture.csv"
FIXTURE_ONLY_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_fixture_only_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-ag summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ag summary row", 4)
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

make_live_csv() {
  local family
  local reproduction_id
  local release_id
  local official_uri
  local official_hash
  local archive_uri
  local archive_hash
  local dataset_uri
  local dataset_hash
  local authority_uri
  local authority_hash
  local slug

  {
    echo "benchmark_family,reproduction_id,release_id,official_release_record_uri,official_release_record_hash,public_archive_record_uri,public_archive_record_hash,dataset_version_record_uri,dataset_version_record_hash,release_authority_uri,release_authority_hash,live_verification_report_uri,live_verification_report_hash,network_observation_uri,network_observation_hash,verifier_identity_uri,verifier_identity_hash,verified_at_utc,official_release_bound,public_archive_bound,dataset_version_bound,release_authority_bound,live_verification_report_bound,network_observation_bound,verifier_identity_bound,live_network_observed,independent_verifier_declared,stable_release_observed,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
          $idx["official_release_record_uri"],
          $idx["official_release_record_hash"],
          $idx["public_archive_record_uri"],
          $idx["public_archive_record_hash"],
          $idx["dataset_version_record_uri"],
          $idx["dataset_version_record_hash"],
          $idx["release_authority_uri"],
          $idx["release_authority_hash"]
      }
    ' "$RELEASE_CSV" | while IFS=$'\t' read -r family reproduction_id release_id official_uri official_hash archive_uri archive_hash dataset_uri dataset_hash authority_uri authority_hash; do
      slug="$(slugify "$family")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,https://live-verifier.example.org/v08/%s/report.json,%s,https://live-verifier.example.org/v08/%s/network-trace.json,%s,https://live-verifier.example.org/v08/%s/verifier-identity.json,%s,2026-06-03T00:00:00Z,1,1,1,1,1,1,1,1,1,1,1,0,0,0\n" \
        "$family" \
        "$reproduction_id" \
        "$release_id" \
        "$official_uri" \
        "$official_hash" \
        "$archive_uri" \
        "$archive_hash" \
        "$dataset_uri" \
        "$dataset_hash" \
        "$authority_uri" \
        "$authority_hash" \
        "$slug" \
        "$(sha_text_uri "live-report|$family|$release_id|$official_hash")" \
        "$slug" \
        "$(sha_text_uri "network-trace|$family|$release_id|$archive_hash")" \
        "$slug" \
        "$(sha_text_uri "verifier|$family|$release_id|independent")"
    done
  } >"$LIVE_CSV"
}

run_v08ag_with_live() {
  local live_csv="$1"

  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$live_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_live_release_verification.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_release_verification.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "0" "default v08-ag official release evidence should block"
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "0" "default v08-ag live verification should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ag must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-release-evidence-not-ready" "default v08-ag action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_official_release_evidence.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_live_release_verification.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "1" "v08-ag upstream v08-af should pass"
expect_summary_value "$SUMMARY_CSV" "live_rows" "0" "v08-ag missing live rows should have zero rows"
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "0" "v08-ag should block before live verification rows"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-release-verification-missing" "v08-ag missing live verification action"

make_live_csv
run_v08ag_with_live "$LIVE_CSV"

expect_summary_value "$SUMMARY_CSV" "live_source" "provided-csv" "v08-ag live source should be provided"
expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "1" "v08-ag upstream official release should pass"
expect_summary_value "$SUMMARY_CSV" "release_family_rows" "4" "v08-ag should see four release families"
expect_summary_value "$SUMMARY_CSV" "live_rows" "4" "v08-ag live verification should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ag live verification should match all families"
expect_summary_value "$SUMMARY_CSV" "matched_release_family_rows" "4" "v08-ag should bind all release families"
expect_summary_value "$SUMMARY_CSV" "reproduction_id_match_rows" "4" "v08-ag reproduction IDs should match"
expect_summary_value "$SUMMARY_CSV" "release_id_match_rows" "4" "v08-ag release IDs should match"
expect_summary_value "$SUMMARY_CSV" "official_release_match_rows" "4" "v08-ag official release artifacts should match"
expect_summary_value "$SUMMARY_CSV" "public_archive_match_rows" "4" "v08-ag public archive artifacts should match"
expect_summary_value "$SUMMARY_CSV" "dataset_version_match_rows" "4" "v08-ag dataset version artifacts should match"
expect_summary_value "$SUMMARY_CSV" "release_authority_match_rows" "4" "v08-ag release authority artifacts should match"
expect_summary_value "$SUMMARY_CSV" "required_live_hash_fields" "28" "v08-ag should require 28 live hash fields"
expect_summary_value "$SUMMARY_CSV" "live_hash_attested_fields" "28" "v08-ag should attest 28 live hashes"
expect_summary_value "$SUMMARY_CSV" "required_live_uri_fields" "28" "v08-ag should require 28 live URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_live_uri_fields" "28" "v08-ag should require HTTPS live artifacts"
expect_summary_value "$SUMMARY_CSV" "local_live_uri_fields" "0" "v08-ag should reject local live artifacts"
expect_summary_value "$SUMMARY_CSV" "live_network_observed_rows" "4" "v08-ag should require live network observations"
expect_summary_value "$SUMMARY_CSV" "independent_verifier_declared_rows" "4" "v08-ag should require independent verifiers"
expect_summary_value "$SUMMARY_CSV" "stable_release_observed_rows" "4" "v08-ag should require stable releases"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-ag should require non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-ag should require fixture-free declarations"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-ag should require timestamps"
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "1" "v08-ag live verification should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ag must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-release-verification-ready-await-canonical-online-confirmation" "v08-ag good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ag routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ag active jump should stay zero"

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
    if ($idx["gate"] == "official-release-evidence" && $idx["status"] != "pass") die("v08-ag official release evidence should pass", 20)
    if ($idx["gate"] == "live-release-coverage" && $idx["status"] != "pass") die("v08-ag live release coverage should pass", 21)
    if ($idx["gate"] == "live-release-binding" && $idx["status"] != "pass") die("v08-ag live release binding should pass", 22)
    if ($idx["gate"] == "live-release-hash-attestation" && $idx["status"] != "pass") die("v08-ag live release hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-live-release-artifacts" && $idx["status"] != "pass") die("v08-ag nonlocal artifacts should pass", 24)
    if ($idx["gate"] == "live-release-proof-bindings" && $idx["status"] != "pass") die("v08-ag proof bindings should pass", 25)
    if ($idx["gate"] == "live-release-declarations" && $idx["status"] != "pass") die("v08-ag declarations should pass", 26)
    if ($idx["gate"] == "official-release-live-verification" && $idx["status"] != "pass") die("v08-ag live verification should pass", 27)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ag real benchmark should block", 28)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ag jump guardrail should pass", 29)
  }
  END {
    if (rows != 10) die("expected ten v08-ag decision rows", 30)
  }
' "$DECISION_CSV"

{
  head -n 1 "$LIVE_CSV"
  sed -n '2,$p' "$LIVE_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $13 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

run_v08ag_with_live "$BAD_HASH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "0" "v08-ag bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-release-hash-attestation-missing" "v08-ag bad hash action"

{
  head -n 1 "$LIVE_CSV"
  sed -n '2,$p' "$LIVE_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $12 = "file:///tmp/live-report.json" } { print }'
} >"$LOCAL_URI_CSV"

run_v08ag_with_live "$LOCAL_URI_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "0" "v08-ag local URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_live_uri_fields" "1" "v08-ag should count local live URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-release-local-artifact-uri" "v08-ag local URI action"

{
  head -n 1 "$LIVE_CSV"
  sed -n '2,$p' "$LIVE_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $3 = "wrong-release-id" } { print }'
} >"$MISMATCH_CSV"

run_v08ag_with_live "$MISMATCH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "0" "v08-ag release mismatch should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-release-binding-mismatch" "v08-ag release mismatch action"

{
  head -n 1 "$LIVE_CSV"
  sed -n '2,$p' "$LIVE_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $29 = 0; $30 = 1 } { print }'
} >"$FIXTURE_ONLY_CSV"

run_v08ag_with_live "$FIXTURE_ONLY_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "official_release_live_verification_ready" "0" "v08-ag fixture declaration should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-release-declaration-missing" "v08-ag fixture-only action"

{
  head -n 1 "$LIVE_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$LIVE_CSV")"
} >"$MALFORMED_CSV"

if run_v08ag_with_live "$MALFORMED_CSV" >/dev/null 2>/dev/null; then
  echo "v08-ag should reject malformed live release verification CSV row widths" >&2
  exit 40
fi

run_v08ag_with_live "$LIVE_CSV" >/dev/null

echo "v08 external benchmark live release verification smoke passed"
