#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_gate_smoke_decision.csv"
ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_source_acquisition_fixture.csv"
REAL_ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_real_source_acquisition_fixture.csv"
PLACEHOLDER_ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_placeholder_source_acquisition_fixture.csv"
LOCAL_ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_local_source_acquisition_fixture.csv"
MALFORMED_ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_malformed_source_acquisition_fixture.csv"

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
      if (!(field in idx)) die("missing v08-z summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-z summary row", 4)
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

make_acquisition_csv() {
  local output_csv="$1"
  local fixture_declared="$2"
  local domain_mode="${3:-real}"
  local uri_mode="${4:-remote}"

  {
    echo "benchmark_family,acquisition_id,official_benchmark_domain,source_landing_uri,source_landing_hash,dataset_artifact_uri,dataset_artifact_hash,benchmark_card_uri,benchmark_card_hash,split_manifest_uri,split_manifest_hash,license_uri,license_hash,metric_spec_uri,metric_spec_hash,acquisition_method,retrieval_tool,content_hash_algorithm,live_acquisition_observed,independent_source_review,real_external_source_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
    for family in RULER LongBench codebase-retrieval real-document-qa; do
      family_slug="$(slugify "$family")"
      domain="$(domain_for_family "$family")"
      if [[ "$domain_mode" == "placeholder" ]]; then
        domain="benchmarks.example.invalid"
      fi

      if [[ "$uri_mode" == "local" ]]; then
        source_landing_uri="file://${RESULTS_DIR}/${family_slug}_landing.json"
        dataset_artifact_uri="file://${RESULTS_DIR}/${family_slug}_dataset.jsonl"
        benchmark_card_uri="file://${RESULTS_DIR}/${family_slug}_card.json"
        split_manifest_uri="file://${RESULTS_DIR}/${family_slug}_split.json"
        license_uri="file://${RESULTS_DIR}/${family_slug}_license.json"
        metric_spec_uri="file://${RESULTS_DIR}/${family_slug}_metric.json"
        acquisition_method="local"
        retrieval_tool="fixture"
      else
        source_landing_uri="https://${domain}/v08/source/${family_slug}/landing.json"
        dataset_artifact_uri="https://${domain}/v08/source/${family_slug}/dataset.jsonl"
        benchmark_card_uri="https://${domain}/v08/source/${family_slug}/card.json"
        split_manifest_uri="https://${domain}/v08/source/${family_slug}/split.json"
        license_uri="https://${domain}/v08/source/${family_slug}/license.json"
        metric_spec_uri="https://${domain}/v08/source/${family_slug}/metric.json"
        acquisition_method="https-live-fetch"
        retrieval_tool="runner-owned-fetcher"
      fi

      source_landing_hash="$(sha_text_uri "landing|${family}")"
      dataset_artifact_hash="$(sha_text_uri "dataset|${family}")"
      benchmark_card_hash="$(sha_text_uri "card|${family}")"
      split_manifest_hash="$(sha_text_uri "split|${family}")"
      license_hash="$(sha_text_uri "license|${family}")"
      metric_spec_hash="$(sha_text_uri "metric|${family}")"

      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,sha256,1,1,1,%d,1,0,0\n" \
        "$family" \
        "acquisition-${family_slug}" \
        "$domain" \
        "$source_landing_uri" \
        "$source_landing_hash" \
        "$dataset_artifact_uri" \
        "$dataset_artifact_hash" \
        "$benchmark_card_uri" \
        "$benchmark_card_hash" \
        "$split_manifest_uri" \
        "$split_manifest_hash" \
        "$license_uri" \
        "$license_hash" \
        "$metric_spec_uri" \
        "$metric_spec_hash" \
        "$acquisition_method" \
        "$retrieval_tool" \
        "$fixture_declared"
    done
  } >"$output_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_gate.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08z" "default v08-z scope"
expect_summary_value "$SUMMARY_CSV" "acquisition_rows" "0" "default v08-z should have no acquisition rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_review_ready" "0" "default v08-z should not review"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_ready" "0" "default v08-z should not acquire"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-z must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-missing" "default v08-z action"

make_acquisition_csv "$ACQUISITION_CSV" 1
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_source" "provided-csv" "v08-z source should be provided"
expect_summary_value "$SUMMARY_CSV" "acquisition_rows" "4" "v08-z fixture should have acquisition rows"
expect_summary_value "$SUMMARY_CSV" "matched_adapter_rows" "4" "v08-z fixture should match adapter families"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_domain_rows" "4" "v08-z fixture should use non-placeholder domains"
expect_summary_value "$SUMMARY_CSV" "remote_uri_rows" "4" "v08-z fixture should use remote HTTPS URIs"
expect_summary_value "$SUMMARY_CSV" "hash_attestation_rows" "4" "v08-z fixture should have hash attestations"
expect_summary_value "$SUMMARY_CSV" "acquisition_method_rows" "4" "v08-z fixture should have acquisition methods"
expect_summary_value "$SUMMARY_CSV" "live_acquisition_observed_rows" "4" "v08-z fixture should have live observation flags"
expect_summary_value "$SUMMARY_CSV" "independent_source_review_rows" "4" "v08-z fixture should have independent review"
expect_summary_value "$SUMMARY_CSV" "declared_real_source_rows" "4" "v08-z fixture should declare real source"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "0" "v08-z fixture should remain fixture-declared"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_review_ready" "1" "v08-z fixture should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_ready" "0" "v08-z fixture must not satisfy acquisition readiness"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-z fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-fixture-only" "v08-z fixture action"

make_acquisition_csv "$REAL_ACQUISITION_CSV" 0
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$REAL_ACQUISITION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_review_ready" "1" "v08-z non-fixture package should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_ready" "1" "v08-z non-fixture package should be acquisition-ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-z acquisition alone must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-ready-await-import" "v08-z non-fixture action"

make_acquisition_csv "$PLACEHOLDER_ACQUISITION_CSV" 0 placeholder
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$PLACEHOLDER_ACQUISITION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_gate.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "placeholder_uri_rows" "4" "v08-z placeholder package should count placeholder rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_review_ready" "0" "v08-z placeholder package should block review"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-placeholder-domain" "v08-z placeholder action"

make_acquisition_csv "$LOCAL_ACQUISITION_CSV" 0 real local
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$LOCAL_ACQUISITION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_gate.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "local_uri_rows" "4" "v08-z local package should count local rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_source_acquisition_review_ready" "0" "v08-z local package should block review"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-acquisition-local-artifact" "v08-z local action"

{
  head -n 1 "$REAL_ACQUISITION_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$REAL_ACQUISITION_CSV")"
} >"$MALFORMED_ACQUISITION_CSV"

if V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$MALFORMED_ACQUISITION_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "malformed v08-z source acquisition CSV unexpectedly passed" >&2
  exit 50
fi

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    if ($idx["gate"] == "external-benchmark-source-acquisition" && $idx["status"] != "blocked") {
      print "v08-z local acquisition should remain blocked in final decision" > "/dev/stderr"
      exit 60
    }
  }
  END {
    if (rows != 6) {
      print "expected v08-z decision rows" > "/dev/stderr"
      exit 61
    }
  }
' "$DECISION_CSV"

echo "v08 external benchmark source acquisition smoke passed"
