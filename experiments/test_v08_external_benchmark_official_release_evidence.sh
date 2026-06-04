#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_fixture"
ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_content_fixture.csv"
BRIDGE_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_bridge_fixture.csv"
REPRODUCTION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_fixture.csv"
RELEASE_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_bad_hash_fixture.csv"
LOCAL_RELEASE_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_local_uri_fixture.csv"
MISMATCH_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_reproduction_mismatch_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_smoke_decision.csv"
AE_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_smoke_summary.csv"

mkdir -p "$RESULTS_DIR" "$FIXTURE_DIR"

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
      if (!(field in idx)) die("missing v08-af summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-af summary row", 4)
    }
  ' "$summary_csv"
}

sha_file_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

slugify() {
  local value="$1"
  printf '%s\n' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-//; s/-$//'
}

domain_for_family() {
  local family="$1"
  case "$family" in
    RULER) printf '%s\n' "ruler-benchmark.org" ;;
    LongBench) printf '%s\n' "longbench-benchmark.org" ;;
    codebase-retrieval) printf '%s\n' "codebase-benchmarks.org" ;;
    real-document-qa) printf '%s\n' "docqa-benchmarks.org" ;;
    *) return 1 ;;
  esac
}

write_release_artifact() {
  local family="$1"
  local artifact="$2"
  local path="$3"

  printf '{"family":"%s","artifact":"%s","fixture":"v08-af-official-release-evidence"}\n' "$family" "$artifact" >"$path"
}

make_release_csv() {
  local summary_uri
  local summary_hash
  local reproduction_rows_tsv
  local family
  local reproduction_id
  local family_slug
  local domain
  local artifact

  summary_uri="file://$AE_SUMMARY_CSV"
  summary_hash="$(sha_file_uri "$AE_SUMMARY_CSV")"
  reproduction_rows_tsv="$FIXTURE_DIR/reproduction_rows.tsv"

  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    {
      printf "%s\t%s\n",
        $idx["benchmark_family"],
        $idx["reproduction_id"]
    }
  ' "$REPRODUCTION_CSV" >"$reproduction_rows_tsv"

  {
    echo "benchmark_family,reproduction_id,release_id,independent_reproduction_summary_uri,independent_reproduction_summary_hash,release_package_uri,release_package_hash,release_manifest_uri,release_manifest_hash,official_release_record_uri,official_release_record_hash,public_archive_record_uri,public_archive_record_hash,dataset_version_record_uri,dataset_version_record_hash,license_notice_uri,license_notice_hash,reproducibility_bundle_uri,reproducibility_bundle_hash,review_decision_uri,review_decision_hash,artifact_index_uri,artifact_index_hash,release_authority_uri,release_authority_hash,independent_reproduction_bound,release_package_bound,release_manifest_bound,official_release_bound,public_archive_bound,dataset_version_bound,license_bound,reproducibility_bound,review_decision_bound,artifact_index_bound,release_authority_bound,official_release_declared,public_archive_declared,stable_version_declared,license_compatible_declared,reproducibility_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    while IFS=$'\t' read -r family reproduction_id; do
      family_slug="$(slugify "$family")"
      domain="$(domain_for_family "$family")"
      mkdir -p "$FIXTURE_DIR/$family_slug"
      for artifact in release-package release-manifest official-release public-archive dataset-version license reproducibility review-decision artifact-index release-authority; do
        write_release_artifact "$family" "$artifact" "$FIXTURE_DIR/$family_slug/${artifact}.json"
      done

      printf "%s,%s,%s,%s,%s,https://%s/v08/release/%s/release-package.json,%s,https://%s/v08/release/%s/manifest.json,%s,https://%s/v08/release/%s/official-release.json,%s,https://%s/v08/release/%s/archive.json,%s,https://%s/v08/release/%s/dataset-version.json,%s,https://%s/v08/release/%s/license.json,%s,https://%s/v08/release/%s/reproducibility.json,%s,https://%s/v08/release/%s/review-decision.json,%s,https://%s/v08/release/%s/artifact-index.json,%s,https://%s/v08/release/%s/release-authority.json,%s,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0\n" \
        "$family" \
        "$reproduction_id" \
        "release-$family_slug" \
        "$summary_uri" \
        "$summary_hash" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/release-package.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/release-manifest.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/official-release.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/public-archive.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/dataset-version.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/license.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/reproducibility.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/review-decision.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/artifact-index.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/release-authority.json")"
    done <"$reproduction_rows_tsv"
  } >"$RELEASE_CSV"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "0" "default v08-af independent reproduction should block"
expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "0" "default v08-af release evidence should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-af must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-reproduction-not-ready" "default v08-af action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_independent_reproduction_review.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "1" "v08-af reproduction fixture should pass"
expect_summary_value "$SUMMARY_CSV" "release_rows" "0" "v08-af missing release evidence should have zero rows"
expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "0" "v08-af should block before release rows"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-release-evidence-missing" "v08-af missing release action"

make_release_csv

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "release_source" "provided-csv" "v08-af release should be provided"
expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "1" "v08-af independent reproduction should pass"
expect_summary_value "$SUMMARY_CSV" "reproduction_family_rows" "4" "v08-af should see four reproduction families"
expect_summary_value "$SUMMARY_CSV" "release_rows" "4" "v08-af release should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-af release should match all families"
expect_summary_value "$SUMMARY_CSV" "matched_reproduction_family_rows" "4" "v08-af should bind all reproduction families"
expect_summary_value "$SUMMARY_CSV" "reproduction_id_match_rows" "4" "v08-af reproduction IDs should match"
expect_summary_value "$SUMMARY_CSV" "independent_reproduction_summary_hash_verified_rows" "4" "v08-af should verify reproduction summary hashes"
expect_summary_value "$SUMMARY_CSV" "required_release_hash_fields" "44" "v08-af should require 44 release hash fields"
expect_summary_value "$SUMMARY_CSV" "release_hash_attested_fields" "44" "v08-af should attest 44 release hashes"
expect_summary_value "$SUMMARY_CSV" "required_release_uri_fields" "40" "v08-af should require 40 release artifact URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_release_uri_fields" "40" "v08-af should require HTTPS release artifacts"
expect_summary_value "$SUMMARY_CSV" "local_release_uri_fields" "0" "v08-af should reject local release artifacts"
expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "1" "v08-af official release evidence should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-af must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-release-evidence-ready-await-live-release-verification" "v08-af good release action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-af routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-af active jump should stay zero"

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
    if ($idx["gate"] == "independent-reproduction" && $idx["status"] != "pass") die("v08-af independent reproduction should pass", 20)
    if ($idx["gate"] == "release-coverage" && $idx["status"] != "pass") die("v08-af release coverage should pass", 21)
    if ($idx["gate"] == "reproduction-binding" && $idx["status"] != "pass") die("v08-af reproduction binding should pass", 22)
    if ($idx["gate"] == "release-hash-attestation" && $idx["status"] != "pass") die("v08-af release hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-release-artifacts" && $idx["status"] != "pass") die("v08-af nonlocal release artifacts should pass", 24)
    if ($idx["gate"] == "release-bindings" && $idx["status"] != "pass") die("v08-af release bindings should pass", 25)
    if ($idx["gate"] == "release-declarations" && $idx["status"] != "pass") die("v08-af release declarations should pass", 26)
    if ($idx["gate"] == "official-release-evidence" && $idx["status"] != "pass") die("v08-af official release evidence should pass", 27)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-af real benchmark should block", 28)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-af jump guardrail should pass", 29)
  }
  END {
    if (rows != 10) die("expected ten v08-af decision rows", 30)
  }
' "$DECISION_CSV"

{
  head -n 1 "$RELEASE_CSV"
  sed -n '2,$p' "$RELEASE_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $7 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "0" "v08-af bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-release-hash-attestation-missing" "v08-af bad hash action"

{
  head -n 1 "$RELEASE_CSV"
  sed -n '2,$p' "$RELEASE_CSV" | awk -F, -v local_uri="file://$FIXTURE_DIR/ruler/release-package.json" 'BEGIN { OFS="," } NR == 1 { $6 = local_uri } { print }'
} >"$LOCAL_RELEASE_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$LOCAL_RELEASE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "0" "v08-af local release URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_release_uri_fields" "1" "v08-af should count local release URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-release-local-artifact-uri" "v08-af local release URI action"

{
  head -n 1 "$RELEASE_CSV"
  sed -n '2,$p' "$RELEASE_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $2 = "wrong-reproduction-id" } { print }'
} >"$MISMATCH_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$MISMATCH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "official_release_evidence_ready" "0" "v08-af reproduction mismatch should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-release-reproduction-mismatch" "v08-af reproduction mismatch action"

{
  head -n 1 "$RELEASE_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$RELEASE_CSV")"
} >"$MALFORMED_CSV"

if V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
   V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
   V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
   V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-af should reject malformed official release CSV row widths" >&2
  exit 40
fi

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" --smoke >/dev/null

echo "v08 external benchmark official release evidence smoke passed"
