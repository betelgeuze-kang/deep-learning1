#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_fixture"
ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_content_fixture.csv"
BRIDGE_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_bridge_fixture.csv"
REPRODUCTION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_bad_hash_fixture.csv"
LOCAL_REPRODUCTION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_local_uri_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_malformed_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_smoke_decision.csv"
AD_SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_smoke_summary.csv"

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
      if (!(field in idx)) die("missing v08-ae summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ae summary row", 4)
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

write_reproduction_artifact() {
  local family="$1"
  local artifact="$2"
  local path="$3"

  printf '{"family":"%s","artifact":"%s","fixture":"v08-ae-independent-reproduction"}\n' "$family" "$artifact" >"$path"
}

make_reproduction_csv() {
  local summary_uri
  local summary_hash
  local bridge_rows_tsv
  local family
  local acquisition_id
  local result_artifact_uri
  local result_artifact_hash
  local family_slug
  local domain
  local artifact

  summary_uri="file://$AD_SUMMARY_CSV"
  summary_hash="$(sha_file_uri "$AD_SUMMARY_CSV")"
  bridge_rows_tsv="$FIXTURE_DIR/bridge_rows.tsv"

  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    {
      printf "%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["acquisition_id"],
        $idx["result_artifact_uri"],
        $idx["result_artifact_hash"]
    }
  ' "$BRIDGE_CSV" >"$bridge_rows_tsv"

  {
    echo "benchmark_family,acquisition_id,reproduction_id,result_bridge_summary_uri,result_bridge_summary_hash,result_artifact_uri,result_artifact_hash,reproduction_report_uri,reproduction_report_hash,reproduction_run_log_uri,reproduction_run_log_hash,reviewer_identity_uri,reviewer_identity_hash,conflict_disclosure_uri,conflict_disclosure_hash,environment_manifest_uri,environment_manifest_hash,metric_recompute_uri,metric_recompute_hash,result_bridge_bound,reproduction_report_bound,run_log_bound,reviewer_identity_bound,conflict_disclosure_bound,environment_bound,metric_recompute_bound,result_match_declared,metric_match_declared,independent_runner_declared,non_author_conflict_clear,official_review_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    while IFS=$'\t' read -r family acquisition_id result_artifact_uri result_artifact_hash; do
      family_slug="$(slugify "$family")"
      domain="$(domain_for_family "$family")"
      mkdir -p "$FIXTURE_DIR/$family_slug"
      for artifact in report run-log reviewer conflict environment metric; do
        write_reproduction_artifact "$family" "$artifact" "$FIXTURE_DIR/$family_slug/${artifact}.json"
      done

      printf "%s,%s,%s,%s,%s,%s,%s,https://%s/v08/reproduction/%s/report.json,%s,https://%s/v08/reproduction/%s/run-log.json,%s,https://%s/v08/reproduction/%s/reviewer.json,%s,https://%s/v08/reproduction/%s/conflict.json,%s,https://%s/v08/reproduction/%s/environment.json,%s,https://%s/v08/reproduction/%s/metric.json,%s,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0\n" \
        "$family" \
        "$acquisition_id" \
        "repro-$family_slug" \
        "$summary_uri" \
        "$summary_hash" \
        "$result_artifact_uri" \
        "$result_artifact_hash" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/report.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/run-log.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/reviewer.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/conflict.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/environment.json")" \
        "$domain" "$family_slug" "$(sha_file_uri "$FIXTURE_DIR/$family_slug/metric.json")"
    done <"$bridge_rows_tsv"
  } >"$REPRODUCTION_CSV"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "0" "default v08-ae bridge should block"
expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "0" "default v08-ae reproduction should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ae must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-family-result-bridge-not-ready" "default v08-ae action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_family_result_bridge.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "1" "v08-ae bridge fixture should pass"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_bridge_ready" "1" "v08-ae external bridge should be ready"
expect_summary_value "$SUMMARY_CSV" "reproduction_rows" "0" "v08-ae missing reproduction should have zero rows"
expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "0" "v08-ae should block before reproduction rows"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-reproduction-missing" "v08-ae missing reproduction action"

make_reproduction_csv

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "reproduction_source" "provided-csv" "v08-ae reproduction should be provided"
expect_summary_value "$SUMMARY_CSV" "family_result_bridge_review_ready" "1" "v08-ae bridge should remain ready"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_bridge_ready" "1" "v08-ae result bridge should remain ready"
expect_summary_value "$SUMMARY_CSV" "bridge_family_rows" "4" "v08-ae should see four bridge families"
expect_summary_value "$SUMMARY_CSV" "reproduction_rows" "4" "v08-ae reproduction should have four rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ae reproduction should match all families"
expect_summary_value "$SUMMARY_CSV" "matched_bridge_family_rows" "4" "v08-ae reproduction should bind all bridge families"
expect_summary_value "$SUMMARY_CSV" "acquisition_id_match_rows" "4" "v08-ae acquisition IDs should match"
expect_summary_value "$SUMMARY_CSV" "result_artifact_match_rows" "4" "v08-ae result artifacts should match bridge rows"
expect_summary_value "$SUMMARY_CSV" "result_bridge_summary_hash_verified_rows" "4" "v08-ae should verify bridge summary hashes"
expect_summary_value "$SUMMARY_CSV" "required_reproduction_hash_fields" "28" "v08-ae should require 28 reproduction hash fields"
expect_summary_value "$SUMMARY_CSV" "reproduction_hash_attested_fields" "28" "v08-ae should attest 28 reproduction hashes"
expect_summary_value "$SUMMARY_CSV" "nonlocal_reproduction_uri_fields" "28" "v08-ae should require HTTPS reproduction artifacts"
expect_summary_value "$SUMMARY_CSV" "local_reproduction_uri_fields" "0" "v08-ae should reject local reproduction artifacts"
expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "1" "v08-ae independent reproduction should pass mechanically"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ae must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-reproduction-ready-await-official-release-evidence" "v08-ae good reproduction action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ae routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ae active jump should stay zero"

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
    if ($idx["gate"] == "family-result-bridge" && $idx["status"] != "pass") die("v08-ae family result bridge should pass", 20)
    if ($idx["gate"] == "reproduction-coverage" && $idx["status"] != "pass") die("v08-ae reproduction coverage should pass", 21)
    if ($idx["gate"] == "bridge-binding" && $idx["status"] != "pass") die("v08-ae bridge binding should pass", 22)
    if ($idx["gate"] == "reproduction-hash-attestation" && $idx["status"] != "pass") die("v08-ae reproduction hash attestation should pass", 23)
    if ($idx["gate"] == "nonlocal-reproduction-artifacts" && $idx["status"] != "pass") die("v08-ae nonlocal reproduction artifacts should pass", 24)
    if ($idx["gate"] == "reproduction-bindings" && $idx["status"] != "pass") die("v08-ae reproduction bindings should pass", 25)
    if ($idx["gate"] == "reproduction-review" && $idx["status"] != "pass") die("v08-ae reproduction review should pass", 26)
    if ($idx["gate"] == "independent-reproduction" && $idx["status"] != "pass") die("v08-ae independent reproduction should pass", 27)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ae real external benchmark should block", 28)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ae jump guardrail should pass", 29)
  }
  END {
    if (rows != 10) die("expected ten v08-ae decision rows", 30)
  }
' "$DECISION_CSV"

{
  head -n 1 "$REPRODUCTION_CSV"
  sed -n '2,$p' "$REPRODUCTION_CSV" | awk -F, 'BEGIN { OFS="," } NR == 1 { $9 = "not-a-sha256" } { print }'
} >"$BAD_HASH_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "0" "v08-ae bad hash should block readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-reproduction-hash-attestation-missing" "v08-ae bad hash action"

{
  head -n 1 "$REPRODUCTION_CSV"
  sed -n '2,$p' "$REPRODUCTION_CSV" | awk -F, -v local_uri="file://$FIXTURE_DIR/ruler/report.json" 'BEGIN { OFS="," } NR == 1 { $8 = local_uri } { print }'
} >"$LOCAL_REPRODUCTION_CSV"

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$LOCAL_REPRODUCTION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "independent_reproduction_review_ready" "0" "v08-ae local reproduction URI should block readiness"
expect_summary_value "$SUMMARY_CSV" "local_reproduction_uri_fields" "1" "v08-ae should count local reproduction URI"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-reproduction-local-artifact-uri" "v08-ae local reproduction URI action"

{
  head -n 1 "$REPRODUCTION_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$REPRODUCTION_CSV")"
} >"$MALFORMED_CSV"

if V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
   V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
   V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-ae should reject malformed reproduction CSV row widths" >&2
  exit 40
fi

V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" --smoke >/dev/null

echo "v08 external benchmark independent reproduction review smoke passed"
