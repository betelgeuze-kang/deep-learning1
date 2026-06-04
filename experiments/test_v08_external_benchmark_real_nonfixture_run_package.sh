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
CONFIRMATION_UPSTREAM_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_fixture.csv"
REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_fixture.csv"
INGESTION_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_fixture.csv"
AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_fixture.csv"
INDEPENDENT_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_fixture.csv"
REPLAY_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_fixture.csv"
VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_fixture.csv"
AUDIT_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_fixture.csv"
RERUN_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_fixture.csv"
PACKAGE_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_fixture.csv"
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_coverage_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_placeholder_fixture.csv"
BAD_METRIC_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_metric_fixture.csv"
BAD_DELTA_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_delta_fixture.csv"
BAD_BINDING_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_binding_fixture.csv"
BAD_PACKAGE_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_package_declaration_fixture.csv"
BAD_REVIEW_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_review_declaration_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-ar summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ar summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

write_package_header() {
  echo "benchmark_family,independent_rerun_id,real_run_package_id,public_package_id,v08aq_confirmation_bound,run_package_nonfixture_declared,official_benchmark_declared,public_archive_declared,raw_query_set_declared,raw_prediction_output_declared,evaluator_container_declared,immutable_archive_declared,license_review_declared,pii_review_declared,third_party_reproducibility_declared,fixture_or_synthetic_declared,query_rows_packaged,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,metric_delta_abs,run_package_manifest_uri,run_package_manifest_hash,raw_query_set_uri,raw_query_set_hash,raw_prediction_output_uri,raw_prediction_output_hash,evaluator_container_digest_uri,evaluator_container_digest_hash,evaluator_config_uri,evaluator_config_hash,metric_report_uri,metric_report_hash,submission_receipt_uri,submission_receipt_hash,public_archive_uri,public_archive_hash,official_leaderboard_entry_uri,official_leaderboard_entry_hash,license_review_uri,license_review_hash,pii_review_uri,pii_review_hash,third_party_repro_report_uri,third_party_repro_report_hash,package_signature_uri,package_signature_hash,timestamp_authority_uri,timestamp_authority_hash,package_registry_entry_uri,package_registry_entry_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_package_row() {
  local csv="$1"
  local family="$2"
  local wrong_answer_rate="${3:-0.010000}"
  local host="${4:-runpkg.routebench.dev}"
  local v08aq_bound="${5:-1}"
  local package_declared="${6:-1}"
  local review_declared="${7:-1}"
  local metric_delta_abs="${8:-0.005000}"
  local active_jump="${9:-0.000000}"
  local rerun_id="independent-rerun-${family}-20260603"
  local package_id="real-nonfixture-run-package-${family}-20260603"
  local public_package_id="public-run-package-${family}-20260603"
  local base="https://${host}/benchmarks/${family}/${package_id}"

  local fields=(
    "$family" \
    "$rerun_id" \
    "$package_id" \
    "$public_package_id" \
    "$v08aq_bound" \
    "$package_declared" \
    "1" \
    "1" \
    "1" \
    "1" \
    "1" \
    "1" \
    "$review_declared" \
    "1" \
    "1" \
    "0" \
    "64" \
    "0.900000" \
    "0.820000" \
    "0.920000" \
    "0.010000" \
    "$wrong_answer_rate" \
    "$metric_delta_abs" \
    "$base/run_package_manifest.json" \
    "$(hash_for "$family-run-package-manifest")" \
    "$base/raw_query_set.jsonl" \
    "$(hash_for "$family-raw-query-set")" \
    "$base/raw_prediction_output.jsonl" \
    "$(hash_for "$family-raw-prediction-output")" \
    "$base/evaluator_container_digest.txt" \
    "$(hash_for "$family-evaluator-container-digest")" \
    "$base/evaluator_config.json" \
    "$(hash_for "$family-evaluator-config")" \
    "$base/metric_report.json" \
    "$(hash_for "$family-metric-report")" \
    "$base/submission_receipt.json" \
    "$(hash_for "$family-submission-receipt")" \
    "$base/public_archive.tar.zst" \
    "$(hash_for "$family-public-archive")" \
    "$base/official_leaderboard_entry.json" \
    "$(hash_for "$family-official-leaderboard-entry")" \
    "$base/license_review.json" \
    "$(hash_for "$family-license-review")" \
    "$base/pii_review.json" \
    "$(hash_for "$family-pii-review")" \
    "$base/third_party_repro_report.json" \
    "$(hash_for "$family-third-party-repro-report")" \
    "$base/package_signature.minisig" \
    "$(hash_for "$family-package-signature")" \
    "$base/timestamp_authority.json" \
    "$(hash_for "$family-timestamp-authority")" \
    "$base/package_registry_entry.json" \
    "$(hash_for "$family-package-registry-entry")" \
    "2026-06-03T00:00:00Z" \
    "0.000000" \
    "$active_jump"
  )
  (IFS=,; printf '%s\n' "${fields[*]}") >>"$csv"
}

write_good_package_csv() {
  local csv="$1"

  write_package_header >"$csv"
  append_package_row "$csv" "RULER"
  append_package_row "$csv" "LongBench"
  append_package_row "$csv" "codebase-retrieval"
  append_package_row "$csv" "real-document-qa"
}

run_v08ar_with_upstream() {
  local package_csv="$1"

  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
  V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_UPSTREAM_CSV" \
  V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$REVIEW_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV="$INGESTION_CSV" \
  V08_EXTERNAL_BENCHMARK_AUTHORITY_PROMOTION_EVIDENCE_CSV="$AUTHORITY_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_RUN_EVALUATOR_EVIDENCE_CSV="$INDEPENDENT_EVIDENCE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_REPLAY_FINAL_REVIEW_CSV="$REPLAY_CSV" \
  V08_EXTERNAL_BENCHMARK_PUBLIC_NONFIXTURE_VERIFICATION_CSV="$VERIFICATION_CSV" \
  V08_EXTERNAL_BENCHMARK_RUNNER_OWNED_LIVE_EXECUTION_AUDIT_CSV="$AUDIT_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_LIVE_RERUN_CONFIRMATION_CSV="$RERUN_CSV" \
  V08_EXTERNAL_BENCHMARK_REAL_NONFIXTURE_RUN_PACKAGE_CSV="$package_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_real_nonfixture_run_package.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_real_nonfixture_run_package.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "package_source" "pending-csv" "default v08-ar source"
expect_summary_value "$SUMMARY_CSV" "upstream_independent_live_rerun_confirmation_ready" "0" "default v08-ar upstream should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "default v08-ar should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ar must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-not-ready" "default v08-ar action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_independent_live_rerun_confirmation.sh" >/dev/null
write_good_package_csv "$PACKAGE_CSV"
run_v08ar_with_upstream "$PACKAGE_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "package_source" "provided-csv" "v08-ar package source"
expect_summary_value "$SUMMARY_CSV" "upstream_independent_live_rerun_confirmation_ready" "1" "v08-ar upstream rerun confirmation"
expect_summary_value "$SUMMARY_CSV" "package_rows" "4" "v08-ar package rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ar expected family rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-ar duplicate rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-ar family coverage"
expect_summary_value "$SUMMARY_CSV" "required_run_package_uri_fields" "60" "v08-ar required URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_run_package_uri_fields" "60" "v08-ar nonlocal URI fields"
expect_summary_value "$SUMMARY_CSV" "local_run_package_uri_fields" "0" "v08-ar local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_run_package_uri_fields" "60" "v08-ar non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_run_package_hash_fields" "60" "v08-ar required hash fields"
expect_summary_value "$SUMMARY_CSV" "run_package_hash_attested_fields" "60" "v08-ar hash attestations"
expect_summary_value "$SUMMARY_CSV" "total_packaged_query_rows" "256" "v08-ar total query rows"
expect_summary_value "$SUMMARY_CSV" "min_packaged_query_rows_pass_rows" "4" "v08-ar query volume"
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "4" "v08-ar metric thresholds"
expect_summary_value "$SUMMARY_CSV" "metric_delta_pass_rows" "4" "v08-ar metric deltas"
expect_summary_value "$SUMMARY_CSV" "v08aq_confirmation_bound_rows" "4" "v08-ar v08-aq binding"
expect_summary_value "$SUMMARY_CSV" "run_package_nonfixture_declared_rows" "4" "v08-ar nonfixture declaration"
expect_summary_value "$SUMMARY_CSV" "official_benchmark_declared_rows" "4" "v08-ar official benchmark declaration"
expect_summary_value "$SUMMARY_CSV" "public_archive_declared_rows" "4" "v08-ar public archive declaration"
expect_summary_value "$SUMMARY_CSV" "raw_query_set_declared_rows" "4" "v08-ar raw query declaration"
expect_summary_value "$SUMMARY_CSV" "raw_prediction_output_declared_rows" "4" "v08-ar raw output declaration"
expect_summary_value "$SUMMARY_CSV" "evaluator_container_declared_rows" "4" "v08-ar evaluator declaration"
expect_summary_value "$SUMMARY_CSV" "immutable_archive_declared_rows" "4" "v08-ar immutable declaration"
expect_summary_value "$SUMMARY_CSV" "license_review_declared_rows" "4" "v08-ar license review declaration"
expect_summary_value "$SUMMARY_CSV" "pii_review_declared_rows" "4" "v08-ar pii review declaration"
expect_summary_value "$SUMMARY_CSV" "third_party_reproducibility_declared_rows" "4" "v08-ar third-party declaration"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-ar fixture-free rows"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-ar timestamp rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "1" "v08-ar package intake ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ar supplied package must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "real-nonfixture-run-package-intake-ready-await-live-package-artifact-fetch" "v08-ar good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ar routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ar jump should stay zero"

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
    if ($idx["gate"] == "upstream-independent-live-rerun-confirmation" && $idx["status"] != "pass") die("v08-ar upstream should pass", 20)
    if ($idx["gate"] == "real-nonfixture-run-package-coverage" && $idx["status"] != "pass") die("v08-ar coverage should pass", 21)
    if ($idx["gate"] == "real-nonfixture-run-package-artifacts" && $idx["status"] != "pass") die("v08-ar artifacts should pass", 22)
    if ($idx["gate"] == "real-nonfixture-run-package-query-volume" && $idx["status"] != "pass") die("v08-ar query volume should pass", 23)
    if ($idx["gate"] == "real-nonfixture-run-package-metric-thresholds" && $idx["status"] != "pass") die("v08-ar metrics should pass", 24)
    if ($idx["gate"] == "real-nonfixture-run-package-metric-delta" && $idx["status"] != "pass") die("v08-ar metric deltas should pass", 25)
    if ($idx["gate"] == "real-nonfixture-run-package-bindings" && $idx["status"] != "pass") die("v08-ar bindings should pass", 26)
    if ($idx["gate"] == "real-nonfixture-run-package-declarations" && $idx["status"] != "pass") die("v08-ar package declarations should pass", 27)
    if ($idx["gate"] == "package-review-declarations" && $idx["status"] != "pass") die("v08-ar review declarations should pass", 28)
    if ($idx["gate"] == "fixture-declarations" && $idx["status"] != "pass") die("v08-ar fixture declarations should pass", 29)
    if ($idx["gate"] == "external-benchmark-real-nonfixture-run-package-intake" && $idx["status"] != "pass") die("v08-ar intake should pass", 30)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ar real benchmark should remain blocked", 31)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ar jump guardrail should pass", 32)
  }
  END {
    if (rows != 13) die("expected v08-ar decision rows", 33)
  }
' "$DECISION_CSV"

write_package_header >"$BAD_COVERAGE_CSV"
append_package_row "$BAD_COVERAGE_CSV" "RULER"
append_package_row "$BAD_COVERAGE_CSV" "LongBench"
append_package_row "$BAD_COVERAGE_CSV" "codebase-retrieval"
run_v08ar_with_upstream "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "package_rows" "3" "v08-ar bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "3" "v08-ar bad coverage family count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-coverage-incomplete" "v08-ar bad coverage action"

write_good_package_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $52 = "https://package.example.org/package_registry_entry.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08ar_with_upstream "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_run_package_uri_fields" "59" "v08-ar bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-placeholder-artifact-uri" "v08-ar bad placeholder action"

write_good_package_csv "$BAD_METRIC_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $22 = "0.500000" } { print }' \
  "$BAD_METRIC_CSV" >"$BAD_METRIC_CSV.tmp"
mv "$BAD_METRIC_CSV.tmp" "$BAD_METRIC_CSV"
run_v08ar_with_upstream "$BAD_METRIC_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "3" "v08-ar bad metric count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad metric should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-quality-threshold-missing" "v08-ar bad metric action"

write_good_package_csv "$BAD_DELTA_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $23 = "0.200000" } { print }' \
  "$BAD_DELTA_CSV" >"$BAD_DELTA_CSV.tmp"
mv "$BAD_DELTA_CSV.tmp" "$BAD_DELTA_CSV"
run_v08ar_with_upstream "$BAD_DELTA_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_delta_pass_rows" "3" "v08-ar bad delta count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad delta should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-metric-delta-too-large" "v08-ar bad delta action"

write_good_package_csv "$BAD_BINDING_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $5 = "0" } { print }' \
  "$BAD_BINDING_CSV" >"$BAD_BINDING_CSV.tmp"
mv "$BAD_BINDING_CSV.tmp" "$BAD_BINDING_CSV"
run_v08ar_with_upstream "$BAD_BINDING_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "v08aq_confirmation_bound_rows" "3" "v08-ar bad binding count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad binding should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-binding-missing" "v08-ar bad binding action"

write_good_package_csv "$BAD_PACKAGE_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $6 = "0" } { print }' \
  "$BAD_PACKAGE_DECLARATION_CSV" >"$BAD_PACKAGE_DECLARATION_CSV.tmp"
mv "$BAD_PACKAGE_DECLARATION_CSV.tmp" "$BAD_PACKAGE_DECLARATION_CSV"
run_v08ar_with_upstream "$BAD_PACKAGE_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_package_nonfixture_declared_rows" "3" "v08-ar bad package declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad package declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-package-declaration-missing" "v08-ar bad package declaration action"

write_good_package_csv "$BAD_REVIEW_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $13 = "0" } { print }' \
  "$BAD_REVIEW_DECLARATION_CSV" >"$BAD_REVIEW_DECLARATION_CSV.tmp"
mv "$BAD_REVIEW_DECLARATION_CSV.tmp" "$BAD_REVIEW_DECLARATION_CSV"
run_v08ar_with_upstream "$BAD_REVIEW_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "license_review_declared_rows" "3" "v08-ar bad review declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad review declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-review-declaration-missing" "v08-ar bad review declaration action"

write_good_package_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $56 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08ar_with_upstream "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-ar bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready" "0" "v08-ar bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-jump-guardrail-violated" "v08-ar bad jump action"

run_v08ar_with_upstream "$PACKAGE_CSV" >/dev/null

echo "v08 external benchmark real nonfixture run package smoke passed"
