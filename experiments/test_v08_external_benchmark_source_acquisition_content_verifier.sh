#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_fixture"
ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_cache_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_bad_hash_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_verifier_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_verifier_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-aa summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-aa summary row", 4)
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

  printf '{"family":"%s","artifact":"%s","fixture":"v08-aa-content-cache"}\n' "$family" "$artifact" >"$path"
}

make_fixture_files() {
  local family="$1"
  local family_slug="$2"
  local artifact

  mkdir -p "$FIXTURE_DIR/$family_slug"
  for artifact in landing dataset card split license metric; do
    write_content_file "$family" "$artifact" "$FIXTURE_DIR/$family_slug/${artifact}.json"
  done
}

make_acquisition_and_content_csvs() {
  {
    echo "benchmark_family,acquisition_id,official_benchmark_domain,source_landing_uri,source_landing_hash,dataset_artifact_uri,dataset_artifact_hash,benchmark_card_uri,benchmark_card_hash,split_manifest_uri,split_manifest_hash,license_uri,license_hash,metric_spec_uri,metric_spec_hash,acquisition_method,retrieval_tool,content_hash_algorithm,live_acquisition_observed,independent_source_review,real_external_source_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
    for family in RULER LongBench codebase-retrieval real-document-qa; do
      family_slug="$(slugify "$family")"
      domain="$(domain_for_family "$family")"
      make_fixture_files "$family" "$family_slug"

      landing_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/landing.json")"
      dataset_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/dataset.json")"
      card_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/card.json")"
      split_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/split.json")"
      license_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/license.json")"
      metric_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/metric.json")"

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

      landing_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/landing.json")"
      dataset_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/dataset.json")"
      card_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/card.json")"
      split_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/split.json")"
      license_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/license.json")"
      metric_hash="$(sha_file_uri "$FIXTURE_DIR/$family_slug/metric.json")"

      printf "%s,%s,https://%s/v08/source/%s/landing.json,file://%s,%s,https://%s/v08/source/%s/dataset.jsonl,file://%s,%s,https://%s/v08/source/%s/card.json,file://%s,%s,https://%s/v08/source/%s/split.json,file://%s,%s,https://%s/v08/source/%s/license.json,file://%s,%s,https://%s/v08/source/%s/metric.json,file://%s,%s,runner-owned-fetcher,sha256,1,1,1,1,0,0,0\n" \
        "$family" \
        "acquisition-$family_slug" \
        "$domain" "$family_slug" "$FIXTURE_DIR/$family_slug/landing.json" "$landing_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/$family_slug/dataset.json" "$dataset_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/$family_slug/card.json" "$card_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/$family_slug/split.json" "$split_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/$family_slug/license.json" "$license_hash" \
        "$domain" "$family_slug" "$FIXTURE_DIR/$family_slug/metric.json" "$metric_hash"
    done
  } >"$CONTENT_CSV"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_content_verifier.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08aa" "default v08-aa scope"
expect_summary_value "$SUMMARY_CSV" "source_acquisition_ready" "0" "default v08-aa acquisition should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_content_ready" "0" "default v08-aa content should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-aa must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-not-ready" "default v08-aa action"

make_acquisition_and_content_csvs

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_content_verifier.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_acquisition_ready" "1" "v08-aa acquisition fixture should pass acquisition"
expect_summary_value "$SUMMARY_CSV" "content_rows" "0" "v08-aa without content should have no content rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_content_ready" "0" "v08-aa should block without content"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-content-missing" "v08-aa no-content action"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_content_verifier.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_acquisition_content_source" "provided-csv" "v08-aa content fixture should be provided"
expect_summary_value "$SUMMARY_CSV" "content_rows" "4" "v08-aa content fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_acquisition_rows" "4" "v08-aa content fixture should match acquisition families"
expect_summary_value "$SUMMARY_CSV" "acquisition_id_match_rows" "4" "v08-aa content fixture should match acquisition IDs"
expect_summary_value "$SUMMARY_CSV" "remote_uri_match_rows" "4" "v08-aa content fixture should match remote URIs"
expect_summary_value "$SUMMARY_CSV" "hash_manifest_match_rows" "4" "v08-aa content fixture should match hash manifest"
expect_summary_value "$SUMMARY_CSV" "required_content_fields" "24" "v08-aa content fixture should expose 24 cache fields"
expect_summary_value "$SUMMARY_CSV" "cache_uri_fields" "24" "v08-aa content fixture should use cache URIs"
expect_summary_value "$SUMMARY_CSV" "content_hash_verified_fields" "24" "v08-aa content fixture should verify all cache hashes"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_content_ready" "1" "v08-aa content verifier should pass cache contract"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-aa content cache must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-content-ready-await-import" "v08-aa content-ready action"

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
    if ($idx["gate"] == "source-acquisition" && $idx["status"] != "pass") die("v08-aa acquisition should pass", 20)
    if ($idx["gate"] == "content-manifest" && $idx["status"] != "pass") die("v08-aa content manifest should pass", 21)
    if ($idx["gate"] == "content-cache" && $idx["status"] != "pass") die("v08-aa content cache should pass", 22)
    if ($idx["gate"] == "source-acquisition-content" && $idx["status"] != "pass") die("v08-aa content contract should pass", 23)
    if ($idx["gate"] == "real-external-benchmark-verification" && $idx["status"] != "blocked") die("v08-aa real benchmark verification should still block", 24)
  }
  END {
    if (rows != 7) die("expected seven v08-aa decision rows", 25)
  }
' "$DECISION_CSV"

{
  head -n 1 "$CONTENT_CSV"
  sed -n '2,$p' "$CONTENT_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $5 = "sha256:0000000000000000000000000000000000000000000000000000000000000000" } { print }'
} >"$BAD_HASH_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_content_verifier.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_content_ready" "0" "v08-aa bad hash should block content readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-content-hash-manifest-mismatch" "v08-aa bad hash action"

{
  head -n 1 "$CONTENT_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$CONTENT_CSV")"
} >"$MALFORMED_CSV"

if V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_content_verifier.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-aa should reject malformed content CSV row widths" >&2
  exit 40
fi

echo "v08 external benchmark source acquisition content verifier smoke passed"
