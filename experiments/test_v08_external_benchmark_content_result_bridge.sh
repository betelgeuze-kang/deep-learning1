#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_fixture"
ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_content_fixture.csv"
BRIDGE_CSV="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_bridge_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_bad_hash_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_content_result_bridge_smoke_decision.csv"
AA_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_content_verifier_smoke_summary.csv"
AB_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_codebase_mini_smoke_summary.csv"

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
      if (!(field in idx)) die("missing v08-ac summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ac summary row", 4)
    }
  ' "$summary_csv"
}

csv_value() {
  local file="$1"
  local field="$2"
  awk -F, -v field="$field" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) {
        print "missing test field: " field > "/dev/stderr"
        exit 5
      }
      next
    }
    NR == 2 {
      print $idx[field]
      found = 1
      exit
    }
    END {
      if (!found) {
        print "missing test row in " FILENAME > "/dev/stderr"
        exit 6
      }
    }
  ' "$file"
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

  printf '{"family":"%s","artifact":"%s","fixture":"v08-ac-content-cache"}\n' "$family" "$artifact" >"$path"
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

make_bridge_csv() {
  local artifact_dir
  local content_summary_uri
  local content_summary_hash
  local result_artifact_uri
  local baseline_artifact_uri
  local dataset_uri
  local run_manifest_uri
  local evaluator_output_uri

  artifact_dir="$(csv_value "$AB_SUMMARY_CSV" "artifact_dir")"
  content_summary_uri="file://$AA_SUMMARY_CSV"
  content_summary_hash="$(sha_file_uri "$AA_SUMMARY_CSV")"
  result_artifact_uri="file://$artifact_dir/results/summary_metrics.csv"
  baseline_artifact_uri="file://$artifact_dir/baselines/route_memory_student.csv"
  dataset_uri="file://$artifact_dir/dataset.jsonl"
  run_manifest_uri="file://$artifact_dir/source_manifest.json"
  evaluator_output_uri="file://$artifact_dir/results/route_memory_results.jsonl"

  {
    echo "benchmark_family,acquisition_id,content_summary_uri,content_summary_hash,codebase_artifact_dir,result_artifact_uri,result_artifact_hash,baseline_artifact_uri,baseline_artifact_hash,dataset_uri,dataset_hash,run_manifest_uri,run_manifest_hash,evaluator_output_uri,evaluator_output_hash,source_content_bound,result_artifact_bound,baseline_bound,dataset_bound,independent_bridge_review,real_bridge_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    printf "codebase-retrieval,acquisition-codebase-retrieval,%s,%s,file://%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,1,1,1,1,1,0,0,0\n" \
      "$content_summary_uri" \
      "$content_summary_hash" \
      "$artifact_dir" \
      "$result_artifact_uri" \
      "$(sha_file_uri "$artifact_dir/results/summary_metrics.csv")" \
      "$baseline_artifact_uri" \
      "$(sha_file_uri "$artifact_dir/baselines/route_memory_student.csv")" \
      "$dataset_uri" \
      "$(sha_file_uri "$artifact_dir/dataset.jsonl")" \
      "$run_manifest_uri" \
      "$(sha_file_uri "$artifact_dir/source_manifest.json")" \
      "$evaluator_output_uri" \
      "$(sha_file_uri "$artifact_dir/results/route_memory_results.jsonl")"
  } >"$BRIDGE_CSV"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_content_result_bridge.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "source_content_ready" "0" "default v08-ac source content should block"
expect_summary_value "$SUMMARY_CSV" "codebase_content_result_bridge_ready" "0" "default v08-ac bridge should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ac must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-content-not-ready" "default v08-ac action"

make_acquisition_and_content_csvs

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_content_result_bridge.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_content_ready" "1" "v08-ac source content fixture should pass"
expect_summary_value "$SUMMARY_CSV" "bridge_rows" "0" "v08-ac missing bridge should have zero rows"
expect_summary_value "$SUMMARY_CSV" "codebase_content_result_bridge_ready" "0" "v08-ac should block before bridge"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-content-result-bridge-missing" "v08-ac missing bridge action"

make_bridge_csv

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_CONTENT_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_content_result_bridge.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "bridge_source" "provided-csv" "v08-ac bridge should be provided"
expect_summary_value "$SUMMARY_CSV" "source_content_ready" "1" "v08-ac source content should remain ready"
expect_summary_value "$SUMMARY_CSV" "codebase_mini_source_ready" "1" "v08-ac codebase source should be ready"
expect_summary_value "$SUMMARY_CSV" "codebase_result_artifact_verified" "1" "v08-ac codebase result should be verified"
expect_summary_value "$SUMMARY_CSV" "bridge_rows" "1" "v08-ac bridge should have one row"
expect_summary_value "$SUMMARY_CSV" "matched_codebase_family_rows" "1" "v08-ac bridge should match codebase family"
expect_summary_value "$SUMMARY_CSV" "acquisition_id_match_rows" "1" "v08-ac bridge should match acquisition ID"
expect_summary_value "$SUMMARY_CSV" "bridge_hash_verified_fields" "5" "v08-ac bridge should verify five artifact hashes"
expect_summary_value "$SUMMARY_CSV" "codebase_content_result_bridge_ready" "1" "v08-ac codebase bridge should pass"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_bridge_ready" "0" "v08-ac should still need all external families"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ac must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "bridge_family_coverage" "1" "v08-ac bridge should cover only codebase family"
expect_summary_value "$SUMMARY_CSV" "expected_external_families" "4" "v08-ac should require four families"
expect_summary_value "$SUMMARY_CSV" "local_artifact_uri_fields" "5" "v08-ac bridge should expose local codebase artifacts"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-content-result-bridge-ready-await-external-family-results" "v08-ac good bridge action"

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
    if ($idx["gate"] == "source-acquisition-content" && $idx["status"] != "pass") die("v08-ac source content should pass", 20)
    if ($idx["gate"] == "codebase-mini-result" && $idx["status"] != "pass") die("v08-ac codebase result should pass", 21)
    if ($idx["gate"] == "content-result-bridge" && $idx["status"] != "pass") die("v08-ac content-result bridge should pass", 22)
    if ($idx["gate"] == "bridge-review" && $idx["status"] != "pass") die("v08-ac bridge review should pass", 23)
    if ($idx["gate"] == "external-family-coverage" && $idx["status"] != "blocked") die("v08-ac external family coverage should block", 24)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ac real external benchmark should block", 25)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ac jump guardrail should pass", 26)
  }
  END {
    if (rows != 7) die("expected seven v08-ac decision rows", 27)
  }
' "$DECISION_CSV"

{
  head -n 1 "$BRIDGE_CSV"
  sed -n '2,$p' "$BRIDGE_CSV" | awk -F, 'BEGIN { OFS="," } { $7 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"; print }'
} >"$BAD_HASH_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_CONTENT_RESULT_BRIDGE_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_content_result_bridge.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "codebase_content_result_bridge_ready" "0" "v08-ac bad hash should block bridge readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-content-result-bridge-hash-mismatch" "v08-ac bad hash action"

{
  head -n 1 "$BRIDGE_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$BRIDGE_CSV")"
} >"$MALFORMED_CSV"

if V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
   V08_EXTERNAL_BENCHMARK_CONTENT_RESULT_BRIDGE_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_content_result_bridge.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-ac should reject malformed bridge CSV row widths" >&2
  exit 40
fi

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_CONTENT_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_content_result_bridge.sh" --smoke >/dev/null

echo "v08 external benchmark content/result bridge smoke passed"
