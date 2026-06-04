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
INDEPENDENT_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_fixture.csv"
REPLAY_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_fixture.csv"
VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_fixture.csv"
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_bad_coverage_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_bad_placeholder_fixture.csv"
BAD_METRIC_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_bad_metric_fixture.csv"
BAD_BINDING_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_bad_binding_fixture.csv"
BAD_PUBLIC_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_bad_public_declaration_fixture.csv"
BAD_DIRECT_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_bad_direct_declaration_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-ao summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ao summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

write_verification_header() {
  echo "benchmark_family,external_run_id,live_replay_id,final_review_id,public_verification_id,direct_run_id,v08an_review_bound,public_nonfixture_verification_declared,public_artifact_registry_declared,direct_runner_owned_run_declared,direct_external_dataset_declared,direct_evaluator_execution_declared,live_network_fetch_declared,third_party_reviewer_declared,fixture_or_synthetic_declared,query_rows_verified,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,public_verification_report_uri,public_verification_report_hash,public_run_manifest_uri,public_run_manifest_hash,public_dataset_snapshot_uri,public_dataset_snapshot_hash,public_evaluator_output_uri,public_evaluator_output_hash,public_metric_report_uri,public_metric_report_hash,direct_run_log_uri,direct_run_log_hash,direct_network_receipt_uri,direct_network_receipt_hash,direct_runner_identity_uri,direct_runner_identity_hash,public_registry_entry_uri,public_registry_entry_hash,reviewer_attestation_uri,reviewer_attestation_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_verification_row() {
  local csv="$1"
  local family="$2"
  local wrong_answer_rate="${3:-0.010000}"
  local host="${4:-evidence.routebench.dev}"
  local v08an_bound="${5:-1}"
  local public_declared="${6:-1}"
  local direct_declared="${7:-1}"
  local active_jump="${8:-0.000000}"
  local run_id="run-${family}-20260603"
  local replay_id="live-replay-${family}-20260603"
  local review_id="final-review-${family}-20260603"
  local verification_id="public-verification-${family}-20260603"
  local direct_run_id="direct-run-${family}-20260603"
  local base="https://${host}/benchmarks/${family}/${direct_run_id}"

  local fields=(
    "$family" \
    "$run_id" \
    "$replay_id" \
    "$review_id" \
    "$verification_id" \
    "$direct_run_id" \
    "$v08an_bound" \
    "$public_declared" \
    "1" \
    "$direct_declared" \
    "1" \
    "1" \
    "1" \
    "1" \
    "0" \
    "64" \
    "0.900000" \
    "0.820000" \
    "0.920000" \
    "0.010000" \
    "$wrong_answer_rate" \
    "$base/public_verification_report.json" \
    "$(hash_for "$family-public-verification-report")" \
    "$base/public_run_manifest.json" \
    "$(hash_for "$family-public-run-manifest")" \
    "$base/public_dataset_snapshot.json" \
    "$(hash_for "$family-public-dataset-snapshot")" \
    "$base/public_evaluator_output.jsonl" \
    "$(hash_for "$family-public-evaluator-output")" \
    "$base/public_metric_report.json" \
    "$(hash_for "$family-public-metric-report")" \
    "$base/direct_run.log" \
    "$(hash_for "$family-direct-run-log")" \
    "$base/direct_network_receipt.json" \
    "$(hash_for "$family-direct-network-receipt")" \
    "$base/direct_runner_identity.json" \
    "$(hash_for "$family-direct-runner-identity")" \
    "$base/public_registry_entry.json" \
    "$(hash_for "$family-public-registry-entry")" \
    "$base/reviewer_attestation.json" \
    "$(hash_for "$family-reviewer-attestation")" \
    "2026-06-03T00:00:00Z" \
    "0.000000" \
    "$active_jump"
  )
  (IFS=,; printf '%s\n' "${fields[*]}") >>"$csv"
}

write_good_verification_csv() {
  local csv="$1"

  write_verification_header >"$csv"
  append_verification_row "$csv" "RULER"
  append_verification_row "$csv" "LongBench"
  append_verification_row "$csv" "codebase-retrieval"
  append_verification_row "$csv" "real-document-qa"
}

run_v08ao_with_upstream() {
  local verification_csv="$1"

  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
  V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_CSV" \
  V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$REVIEW_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV="$INGESTION_CSV" \
  V08_EXTERNAL_BENCHMARK_AUTHORITY_PROMOTION_EVIDENCE_CSV="$AUTHORITY_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_RUN_EVALUATOR_EVIDENCE_CSV="$INDEPENDENT_EVIDENCE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_REPLAY_FINAL_REVIEW_CSV="$REPLAY_CSV" \
  V08_EXTERNAL_BENCHMARK_PUBLIC_NONFIXTURE_VERIFICATION_CSV="$verification_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_public_nonfixture_verification.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_public_nonfixture_verification.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "verification_source" "pending-csv" "default v08-ao source"
expect_summary_value "$SUMMARY_CSV" "upstream_live_replay_final_review_ready" "0" "default v08-ao upstream should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "default v08-ao should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ao must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-not-ready" "default v08-ao action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_live_replay_final_review.sh" >/dev/null
write_good_verification_csv "$VERIFICATION_CSV"
run_v08ao_with_upstream "$VERIFICATION_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "verification_source" "provided-csv" "v08-ao verification source"
expect_summary_value "$SUMMARY_CSV" "upstream_live_replay_final_review_ready" "1" "v08-ao upstream live replay"
expect_summary_value "$SUMMARY_CSV" "verification_rows" "4" "v08-ao verification rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ao expected family rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-ao duplicate rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-ao family coverage"
expect_summary_value "$SUMMARY_CSV" "required_public_verification_uri_fields" "40" "v08-ao required URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_public_verification_uri_fields" "40" "v08-ao nonlocal URI fields"
expect_summary_value "$SUMMARY_CSV" "local_public_verification_uri_fields" "0" "v08-ao local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_public_verification_uri_fields" "40" "v08-ao non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_public_verification_hash_fields" "40" "v08-ao required hash fields"
expect_summary_value "$SUMMARY_CSV" "public_verification_hash_attested_fields" "40" "v08-ao hash attestations"
expect_summary_value "$SUMMARY_CSV" "total_verified_query_rows" "256" "v08-ao total query rows"
expect_summary_value "$SUMMARY_CSV" "min_verified_query_rows_pass_rows" "4" "v08-ao query volume"
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "4" "v08-ao metric thresholds"
expect_summary_value "$SUMMARY_CSV" "v08an_review_bound_rows" "4" "v08-ao v08-an binding"
expect_summary_value "$SUMMARY_CSV" "public_nonfixture_verification_declared_rows" "4" "v08-ao public declaration"
expect_summary_value "$SUMMARY_CSV" "public_artifact_registry_declared_rows" "4" "v08-ao registry declaration"
expect_summary_value "$SUMMARY_CSV" "direct_runner_owned_run_declared_rows" "4" "v08-ao direct runner declaration"
expect_summary_value "$SUMMARY_CSV" "direct_external_dataset_declared_rows" "4" "v08-ao dataset declaration"
expect_summary_value "$SUMMARY_CSV" "direct_evaluator_execution_declared_rows" "4" "v08-ao evaluator declaration"
expect_summary_value "$SUMMARY_CSV" "live_network_fetch_declared_rows" "4" "v08-ao network declaration"
expect_summary_value "$SUMMARY_CSV" "third_party_reviewer_declared_rows" "4" "v08-ao reviewer declaration"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-ao fixture-free rows"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-ao timestamp rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "1" "v08-ao public non-fixture verification ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ao supplied mechanics must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "public-nonfixture-verification-ready-await-runner-owned-live-execution-audit" "v08-ao good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ao routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ao jump should stay zero"

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
    if ($idx["gate"] == "upstream-live-replay-final-review" && $idx["status"] != "pass") die("v08-ao upstream should pass", 20)
    if ($idx["gate"] == "public-nonfixture-verification-coverage" && $idx["status"] != "pass") die("v08-ao coverage should pass", 21)
    if ($idx["gate"] == "public-nonfixture-verification-artifacts" && $idx["status"] != "pass") die("v08-ao artifacts should pass", 22)
    if ($idx["gate"] == "public-nonfixture-verification-query-volume" && $idx["status"] != "pass") die("v08-ao query volume should pass", 23)
    if ($idx["gate"] == "public-nonfixture-verification-metric-thresholds" && $idx["status"] != "pass") die("v08-ao metrics should pass", 24)
    if ($idx["gate"] == "public-nonfixture-verification-bindings" && $idx["status"] != "pass") die("v08-ao bindings should pass", 25)
    if ($idx["gate"] == "public-nonfixture-declarations" && $idx["status"] != "pass") die("v08-ao public declarations should pass", 26)
    if ($idx["gate"] == "direct-run-declarations" && $idx["status"] != "pass") die("v08-ao direct declarations should pass", 27)
    if ($idx["gate"] == "fixture-declarations" && $idx["status"] != "pass") die("v08-ao fixture declarations should pass", 28)
    if ($idx["gate"] == "external-benchmark-public-nonfixture-verification" && $idx["status"] != "pass") die("v08-ao verification should pass", 29)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ao real benchmark should remain blocked", 30)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ao jump guardrail should pass", 31)
  }
  END {
    if (rows != 12) die("expected v08-ao decision rows", 32)
  }
' "$DECISION_CSV"

write_verification_header >"$BAD_COVERAGE_CSV"
append_verification_row "$BAD_COVERAGE_CSV" "RULER"
append_verification_row "$BAD_COVERAGE_CSV" "LongBench"
append_verification_row "$BAD_COVERAGE_CSV" "codebase-retrieval"
run_v08ao_with_upstream "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "verification_rows" "3" "v08-ao bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "3" "v08-ao bad coverage family count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "v08-ao bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-coverage-incomplete" "v08-ao bad coverage action"

write_good_verification_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $38 = "https://registry.example.org/entry.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08ao_with_upstream "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_public_verification_uri_fields" "39" "v08-ao bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "v08-ao bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-placeholder-artifact-uri" "v08-ao bad placeholder action"

write_good_verification_csv "$BAD_METRIC_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $21 = "0.500000" } { print }' \
  "$BAD_METRIC_CSV" >"$BAD_METRIC_CSV.tmp"
mv "$BAD_METRIC_CSV.tmp" "$BAD_METRIC_CSV"
run_v08ao_with_upstream "$BAD_METRIC_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "3" "v08-ao bad metric count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "v08-ao bad metric should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-quality-threshold-missing" "v08-ao bad metric action"

write_good_verification_csv "$BAD_BINDING_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $7 = "0" } { print }' \
  "$BAD_BINDING_CSV" >"$BAD_BINDING_CSV.tmp"
mv "$BAD_BINDING_CSV.tmp" "$BAD_BINDING_CSV"
run_v08ao_with_upstream "$BAD_BINDING_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "v08an_review_bound_rows" "3" "v08-ao bad binding count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "v08-ao bad binding should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-binding-missing" "v08-ao bad binding action"

write_good_verification_csv "$BAD_PUBLIC_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $8 = "0" } { print }' \
  "$BAD_PUBLIC_DECLARATION_CSV" >"$BAD_PUBLIC_DECLARATION_CSV.tmp"
mv "$BAD_PUBLIC_DECLARATION_CSV.tmp" "$BAD_PUBLIC_DECLARATION_CSV"
run_v08ao_with_upstream "$BAD_PUBLIC_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "public_nonfixture_verification_declared_rows" "3" "v08-ao bad public declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "v08-ao bad public declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-public-declaration-missing" "v08-ao bad public declaration action"

write_good_verification_csv "$BAD_DIRECT_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $10 = "0" } { print }' \
  "$BAD_DIRECT_DECLARATION_CSV" >"$BAD_DIRECT_DECLARATION_CSV.tmp"
mv "$BAD_DIRECT_DECLARATION_CSV.tmp" "$BAD_DIRECT_DECLARATION_CSV"
run_v08ao_with_upstream "$BAD_DIRECT_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "direct_runner_owned_run_declared_rows" "3" "v08-ao bad direct declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "v08-ao bad direct declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-direct-run-declaration-missing" "v08-ao bad direct declaration action"

write_good_verification_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $44 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08ao_with_upstream "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-ao bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready" "0" "v08-ao bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-jump-guardrail-violated" "v08-ao bad jump action"

run_v08ao_with_upstream "$VERIFICATION_CSV" >/dev/null

echo "v08 external benchmark public non-fixture verification smoke passed"
