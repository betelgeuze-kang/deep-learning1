#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_fixture"
ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_content_fixture.csv"
BRIDGE_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_bridge_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_bad_hash_fixture.csv"
LOCAL_RESULT_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_local_result_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_smoke_decision.csv"
AA_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_verifier_smoke_summary.csv"

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
      if (!(field in idx)) die("missing v08-ad summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ad summary row", 4)
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

write_content_file() {
  local family="$1"
  local artifact="$2"
  local path="$3"

  printf '{"family":"%s","artifact":"%s","fixture":"v08-ad-content-cache"}\n' "$family" "$artifact" >"$path"
}

write_result_file() {
  local family="$1"
  local artifact="$2"
  local path="$3"

  printf '{"family":"%s","artifact":"%s","fixture":"v08-ad-result-bridge"}\n' "$family" "$artifact" >"$path"
}

make_fixture_files() {
  local family="$1"
  local family_slug="$2"
  local artifact

  mkdir -p "$FIXTURE_DIR/source/$family_slug" "$FIXTURE_DIR/results/$family_slug"
  for artifact in landing dataset card split license metric; do
    write_content_file "$family" "$artifact" "$FIXTURE_DIR/source/$family_slug/${artifact}.json"
  done
  for artifact in result baseline dataset run evaluator authority publication; do
    write_result_file "$family" "$artifact" "$FIXTURE_DIR/results/$family_slug/${artifact}.json"
  done
}

make_acquisition_and_content_csvs() {
  local family
  local family_slug
  local domain
  local landing_hash
  local dataset_hash
  local card_hash
  local split_hash
  local license_hash
  local metric_hash

  {
    echo "benchmark_family,acquisition_id,official_benchmark_domain,source_landing_uri,source_landing_hash,dataset_artifact_uri,dataset_artifact_hash,benchmark_card_uri,benchmark_card_hash,split_manifest_uri,split_manifest_hash,license_uri,license_hash,metric_spec_uri,metric_spec_hash,acquisition_method,retrieval_tool,content_hash_algorithm,live_acquisition_observed,independent_source_review,real_external_source_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
    for family in RULER LongBench codebase-retrieval real-document-qa; do
      family_slug="$(slugify "$family")"
      domain="$(domain_for_family "$family")"
      make_fixture_files "$family" "$family_slug"

      landing_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/landing.json")"
      dataset_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/dataset.json")"
      card_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/card.json")"
      split_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/split.json")"
      license_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/license.json")"
      metric_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/metric.json")"

      printf "%s,%s,%s,https://%s/v08/source/%s/landing.json,%s,https://%s/v08/source/%s/dataset.jsonl,%s,https://%s/v08/source/%s/card.json,%s,https://%s/v08/source/%s/split.json,%s,https://%s/v08/source/%s/license.json,%s,https://%s/v08/source/%s/metric.json,%s,https-live-fetch,runner-owned-fetcher,sha256,1,1,1,0,1,0,0\n" \
        "$family" \
        "acquisition-$family_slug" \
        "$domain" \
        "$domain" "$family_slug" "$landing_hash" \
        "$domain" "$family_slug" "$dataset_hash" \
        "$domain" "$family_slug" "$card_hash" \
        "$domain" "$family_slug" "$split_hash" \
        "$domain" "$family_slug" "$license_hash" \
        "$domain" "$family_slug" "$metric_hash"
    done
  } >"$ACQUISITION_CSV"

  {
    echo "benchmark_family,acquisition_id,source_landing_uri,source_landing_cache_uri,source_landing_hash,dataset_artifact_uri,dataset_artifact_cache_uri,dataset_artifact_hash,benchmark_card_uri,benchmark_card_cache_uri,benchmark_card_hash,split_manifest_uri,split_manifest_cache_uri,split_manifest_hash,license_uri,license_cache_uri,license_hash,metric_spec_uri,metric_spec_cache_uri,metric_spec_hash,fetch_tool,content_hash_algorithm,fetch_manifest_ready,content_cache_ready,independent_content_review,real_content_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    for family in RULER LongBench codebase-retrieval real-document-qa; do
      family_slug="$(slugify "$family")"
      domain="$(domain_for_family "$family")"

      landing_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/landing.json")"
      dataset_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/dataset.json")"
      card_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/card.json")"
      split_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/split.json")"
      license_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/license.json")"
      metric_hash="$(sha_file_uri "$FIXTURE_DIR/source/$family_slug/metric.json")"

      printf "%s,%s,https://%s/v08/source/%s/landing.json,file://%s,%s,https://%s/v08/source/%s/dataset.jsonl,file://%s,%s,https://%s/v08/source/%s/card.json,file://%s,%s,https://%s/v08/source/%s/split.json,file://%s,%s,https://%s/v08/source/%s/license.json,file://%s,%s,https://%s/v08/source/%s/metric.json,file://%s,%s,runner-owned-fetcher,sha256,1,1,1,1,0,0,0\n" \
        "$family" \
        "acquisition-$family_slug" \
        "$domain" "$family_slug" "$FIXTURE_DIR/source/$family_slug/landing.json" "$landing_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/source/$family_slug/dataset.json" "$dataset_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/source/$family_slug/card.json" "$card_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/source/$family_slug/split.json" "$split_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/source/$family_slug/license.json" "$license_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/source/$family_slug/metric.json" "$metric_hash"
    done
  } >"$CONTENT_CSV"
}

make_bridge_csv() {
  local content_summary_uri
  local content_summary_hash
  local family
  local family_slug
  local domain

  content_summary_uri="file://$AA_SUMMARY_CSV"
  content_summary_hash="$(sha_file_uri "$AA_SUMMARY_CSV")"

  {
    echo "benchmark_family,acquisition_id,content_summary_uri,content_summary_hash,result_artifact_uri,result_artifact_hash,baseline_artifact_uri,baseline_artifact_hash,dataset_uri,dataset_hash,run_manifest_uri,run_manifest_hash,evaluator_output_uri,evaluator_output_hash,result_authority_uri,result_authority_hash,publication_package_uri,publication_package_hash,source_content_bound,result_artifact_bound,baseline_bound,dataset_bound,result_authority_bound,publication_bound,independent_bridge_review,real_bridge_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    for family in RULER LongBench codebase-retrieval real-document-qa; do
      family_slug="$(slugify "$family")"
      domain="$(domain_for_family "$family")"
      printf "%s,%s,%s,%s,https://%s/v08/results/%s/result.json,%s,https://%s/v08/results/%s/baseline.json,%s,https://%s/v08/results/%s/dataset.json,%s,https://%s/v08/results/%s/run.json,%s,https://%s/v08/results/%s/evaluator.json,%s,https://%s/v08/results/%s/authority.json,%s,https://%s/v08/results/%s/publication.json,%s,1,1,1,1,1,1,1,1,0,0,0\n" \
        "$family" \
        "acquisition-$family_slug" \
        "$content_summary_uri" \
        "$content_summary_hash" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/results/$family_slug/result.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/results/$family_slug/baseline.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/results/$family_slug/dataset.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/results/$family_slug/run.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/results/$family_slug/evaluator.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/results/$family_slug/authority.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/results/$family_slug/publication.json")"
    done
  } >"$BRIDGE_CSV"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "source_content_ready" "0" "default v08-ad source content should block"
expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "0" "default v08-ad bridge should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ad must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-content-not-ready" "default v08-ad action"

make_acquisition_and_content_csvs

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_content_ready" "1" "v08-ad source content fixture should pass"
expect_summary_value "$SUMMARY_CSV" "source_content_family_rows" "4" "v08-ad should see four content families"
expect_summary_value "$SUMMARY_CSV" "bridge_rows" "0" "v08-ad missing bridge should have zero rows"
expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "0" "v08-ad should block before bridge"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-family-result-bridge-missing" "v08-ad missing bridge action"

make_bridge_csv

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "bridge_source" "provided-csv" "v08-ad bridge should be provided"
expect_summary_value "$SUMMARY_CSV" "source_content_ready" "1" "v08-ad source content should remain ready"
expect_summary_value "$SUMMARY_CSV" "bridge_rows" "4" "v08-ad bridge should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ad bridge should match all expected families"
expect_summary_value "$SUMMARY_CSV" "bridge_family_coverage" "4" "v08-ad bridge should cover four families"
expect_summary_value "$SUMMARY_CSV" "expected_external_families" "4" "v08-ad should require four families"
expect_summary_value "$SUMMARY_CSV" "acquisition_id_match_rows" "4" "v08-ad bridge should match acquisition IDs"
expect_summary_value "$SUMMARY_CSV" "content_summary_hash_verified_rows" "4" "v08-ad bridge should verify content summary hashes"
expect_summary_value "$SUMMARY_CSV" "required_result_hash_fields" "28" "v08-ad should require 28 result hash fields"
expect_summary_value "$SUMMARY_CSV" "result_hash_attested_fields" "28" "v08-ad should attest 28 result hashes"
expect_summary_value "$SUMMARY_CSV" "nonlocal_result_uri_fields" "28" "v08-ad should require HTTPS result artifacts"
expect_summary_value "$SUMMARY_CSV" "local_result_uri_fields" "0" "v08-ad should reject local result artifacts"
expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "1" "v08-ad family bridge should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_bridge_ready" "1" "v08-ad result bridge mechanics should be ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ad must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-family-result-bridge-ready-await-independent-reproduction" "v08-ad good bridge action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ad routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ad active jump should stay zero"

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
    if ($idx["gate"] == "source-acquisition-content" && $idx["status"] != "pass") die("v08-ad source content should pass", 20)
    if ($idx["gate"] == "family-coverage" && $idx["status"] != "pass") die("v08-ad family coverage should pass", 21)
    if ($idx["gate"] == "source-content-binding" && $idx["status"] != "pass") die("v08-ad source-content binding should pass", 22)
    if ($idx["gate"] == "result-hash-attestation" && $idx["status"] != "pass") die("v08-ad result hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-result-artifacts" && $idx["status"] != "pass") die("v08-ad nonlocal result artifacts should pass", 24)
    if ($idx["gate"] == "bridge-bindings" && $idx["status"] != "pass") die("v08-ad bridge bindings should pass", 25)
    if ($idx["gate"] == "bridge-review" && $idx["status"] != "pass") die("v08-ad bridge review should pass", 26)
    if ($idx["gate"] == "external-result-bridge" && $idx["status"] != "pass") die("v08-ad external result bridge should pass", 27)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ad real external benchmark should block", 28)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ad jump guardrail should pass", 29)
  }
  END {
    if (rows != 10) die("expected ten v08-ad decision rows", 30)
  }
' "$DECISION_CSV"

{
  head -n 1 "$BRIDGE_CSV"
  sed -n '2,$p' "$BRIDGE_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $6 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "0" "v08-ad bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-family-result-bridge-hash-attestation-missing" "v08-ad bad hash action"

{
  head -n 1 "$BRIDGE_CSV"
  sed -n '2,$p' "$BRIDGE_CSV" | awk -F, -v local_uri="file://$FIXTURE_DIR/results/ruler/result.json" 'BEGIN { OFS="," } NR == 1 { $5 = local_uri } { print }'
} >"$LOCAL_RESULT_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$LOCAL_RESULT_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "0" "v08-ad local result URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_result_uri_fields" "1" "v08-ad should count local result URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-family-result-bridge-local-result-artifact-uri" "v08-ad local result URI action"

{
  head -n 1 "$BRIDGE_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$BRIDGE_CSV")"
} >"$MALFORMED_CSV"

if V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
   V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-ad should reject malformed bridge CSV row widths" >&2
  exit 40
fi

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" --smoke >/dev/null

echo "v08 external benchmark family result bridge smoke passed"
