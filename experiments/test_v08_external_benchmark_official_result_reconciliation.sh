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
FETCH_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_fixture.csv"
RECONCILIATION_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_fixture.csv"
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_coverage_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_hash_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_placeholder_fixture.csv"
BAD_PACKAGE_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_package_fixture.csv"
BAD_ARTIFACT_BINDING_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_artifact_binding_fixture.csv"
BAD_ARTIFACT_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_artifact_identity_fixture.csv"
BAD_METRIC_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_metric_fixture.csv"
BAD_QUERY_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_query_fixture.csv"
BAD_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_declaration_fixture.csv"
BAD_OFFICIAL_SOURCE_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_official_source_fixture.csv"
BAD_RUNNER_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_runner_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_official_result_reconciliation_smoke_decision.csv"
FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")

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
      if (!(field in idx)) die("missing v08-at summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-at summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

csv_lookup() {
  local csv="$1"
  local family="$2"
  local artifact_type="$3"
  local column="$4"

  awk -F, -v family="$family" -v artifact_type="$artifact_type" -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!("benchmark_family" in idx) || !("artifact_type" in idx) || !(column in idx)) exit 2
      next
    }
    $idx["benchmark_family"] == family && $idx["artifact_type"] == artifact_type {
      print $idx[column]
      found = 1
      exit
    }
    END {
      if (!found) exit 3
    }
  ' "$csv"
}

metric_value_for() {
  local family="$1"

  case "$family" in
    RULER) printf '0.812000\n' ;;
    LongBench) printf '0.676000\n' ;;
    codebase-retrieval) printf '0.742000\n' ;;
    real-document-qa) printf '0.693000\n' ;;
    *) printf '0.000000\n' ;;
  esac
}

query_count_for() {
  local family="$1"

  case "$family" in
    RULER) printf '1024\n' ;;
    LongBench) printf '800\n' ;;
    codebase-retrieval) printf '512\n' ;;
    real-document-qa) printf '640\n' ;;
    *) printf '0\n' ;;
  esac
}

write_reconciliation_header() {
  echo "benchmark_family,real_run_package_id,official_result_reconciliation_id,v08as_live_fetch_authority_bound,official_leaderboard_entry_bound,metric_report_bound,submission_receipt_bound,evaluator_config_bound,raw_prediction_output_bound,package_registry_entry_bound,official_result_uri,official_result_hash,official_leaderboard_uri,official_leaderboard_hash,reconciled_metric_report_uri,reconciled_metric_report_hash,reconciled_submission_receipt_uri,reconciled_submission_receipt_hash,reconciled_evaluator_config_uri,reconciled_evaluator_config_hash,reconciled_raw_prediction_output_uri,reconciled_raw_prediction_output_hash,reconciled_package_registry_uri,reconciled_package_registry_hash,metric_name,reported_metric_value,official_metric_value,metric_delta,metric_tolerance,query_count,official_query_count,query_count_match_declared,evaluator_identity_match_declared,result_digest_match_declared,official_source_observed_declared,public_leaderboard_observed_declared,runner_owned_reconciliation_declared,fixture_or_replay_declared,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_reconciliation_row() {
  local csv="$1"
  local family="$2"
  local package_id
  local official_result_uri
  local metric_value
  local query_count

  package_id="$(csv_lookup "$FETCH_CSV" "$family" official_leaderboard_entry real_run_package_id)"
  official_result_uri="https://results.routebench.dev/benchmarks/${family}/${package_id}/official-result.json"
  metric_value="$(metric_value_for "$family")"
  query_count="$(query_count_for "$family")"

  local fields=(
    "$family" \
    "$package_id" \
    "official-result-reconciliation-${family}-20260603" \
    "1" \
    "1" \
    "1" \
    "1" \
    "1" \
    "1" \
    "1" \
    "$official_result_uri" \
    "$(hash_for "$family-$package_id-official-result")" \
    "$(csv_lookup "$FETCH_CSV" "$family" official_leaderboard_entry fetched_artifact_uri)" \
    "$(csv_lookup "$FETCH_CSV" "$family" official_leaderboard_entry fetched_artifact_hash)" \
    "$(csv_lookup "$FETCH_CSV" "$family" metric_report fetched_artifact_uri)" \
    "$(csv_lookup "$FETCH_CSV" "$family" metric_report fetched_artifact_hash)" \
    "$(csv_lookup "$FETCH_CSV" "$family" submission_receipt fetched_artifact_uri)" \
    "$(csv_lookup "$FETCH_CSV" "$family" submission_receipt fetched_artifact_hash)" \
    "$(csv_lookup "$FETCH_CSV" "$family" evaluator_config fetched_artifact_uri)" \
    "$(csv_lookup "$FETCH_CSV" "$family" evaluator_config fetched_artifact_hash)" \
    "$(csv_lookup "$FETCH_CSV" "$family" raw_prediction_output fetched_artifact_uri)" \
    "$(csv_lookup "$FETCH_CSV" "$family" raw_prediction_output fetched_artifact_hash)" \
    "$(csv_lookup "$FETCH_CSV" "$family" package_registry_entry fetched_artifact_uri)" \
    "$(csv_lookup "$FETCH_CSV" "$family" package_registry_entry fetched_artifact_hash)" \
    "primary_score" \
    "$metric_value" \
    "$metric_value" \
    "0.000000" \
    "0.000001" \
    "$query_count" \
    "$query_count" \
    "1" \
    "1" \
    "1" \
    "1" \
    "1" \
    "1" \
    "0" \
    "2026-06-03T00:00:00Z" \
    "0.000000" \
    "0.000000"
  )
  (IFS=,; printf '%s\n' "${fields[*]}") >>"$csv"
}

write_good_reconciliation_csv() {
  local csv="$1"
  local family

  write_reconciliation_header >"$csv"
  for family in "${FAMILIES[@]}"; do
    append_reconciliation_row "$csv" "$family"
  done
}

write_bad_coverage_csv() {
  local csv="$1"
  local family

  write_reconciliation_header >"$csv"
  for family in "${FAMILIES[@]}"; do
    [[ "$family" == "real-document-qa" ]] && continue
    append_reconciliation_row "$csv" "$family"
  done
}

run_v08at_with_upstream() {
  local reconciliation_csv="$1"

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
  V08_EXTERNAL_BENCHMARK_REAL_NONFIXTURE_RUN_PACKAGE_CSV="$PACKAGE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_PACKAGE_ARTIFACT_FETCH_AUTHORITY_CSV="$FETCH_CSV" \
  V08_EXTERNAL_BENCHMARK_OFFICIAL_RESULT_RECONCILIATION_CSV="$reconciliation_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_official_result_reconciliation.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_official_result_reconciliation.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "reconciliation_source" "pending-csv" "default v08-at source"
expect_summary_value "$SUMMARY_CSV" "upstream_live_package_artifact_fetch_authority_ready" "0" "default v08-at upstream should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "default v08-at should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-at must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-authority-not-ready" "default v08-at action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_live_package_artifact_fetch_authority.sh" >/dev/null
write_good_reconciliation_csv "$RECONCILIATION_CSV"
run_v08at_with_upstream "$RECONCILIATION_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "reconciliation_source" "provided-csv" "v08-at source"
expect_summary_value "$SUMMARY_CSV" "upstream_live_package_artifact_fetch_authority_ready" "1" "v08-at upstream"
expect_summary_value "$SUMMARY_CSV" "fetch_artifact_rows_seen" "24" "v08-at selected fetch artifact rows"
expect_summary_value "$SUMMARY_CSV" "reconciliation_rows" "4" "v08-at rows"
expect_summary_value "$SUMMARY_CSV" "expected_reconciliation_rows" "4" "v08-at expected rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-at expected family rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-at duplicate family rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-at family coverage"
expect_summary_value "$SUMMARY_CSV" "required_reconciliation_uri_fields" "28" "v08-at URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_reconciliation_uri_fields" "28" "v08-at nonlocal URI fields"
expect_summary_value "$SUMMARY_CSV" "local_reconciliation_uri_fields" "0" "v08-at local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_reconciliation_uri_fields" "28" "v08-at non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_reconciliation_hash_fields" "28" "v08-at hash fields"
expect_summary_value "$SUMMARY_CSV" "reconciliation_hash_attested_fields" "28" "v08-at hash attestations"
expect_summary_value "$SUMMARY_CSV" "v08as_live_fetch_authority_bound_rows" "4" "v08-at v08-as binding"
expect_summary_value "$SUMMARY_CSV" "package_identity_match_rows" "4" "v08-at package identity"
expect_summary_value "$SUMMARY_CSV" "artifact_binding_declared_rows" "4" "v08-at artifact bindings"
expect_summary_value "$SUMMARY_CSV" "fetch_artifact_identity_match_rows" "4" "v08-at artifact identity"
expect_summary_value "$SUMMARY_CSV" "metric_delta_within_tolerance_rows" "4" "v08-at metric rows"
expect_summary_value "$SUMMARY_CSV" "query_count_exact_match_rows" "4" "v08-at query rows"
expect_summary_value "$SUMMARY_CSV" "query_count_match_declared_rows" "4" "v08-at query declarations"
expect_summary_value "$SUMMARY_CSV" "evaluator_identity_match_declared_rows" "4" "v08-at evaluator declarations"
expect_summary_value "$SUMMARY_CSV" "result_digest_match_declared_rows" "4" "v08-at digest declarations"
expect_summary_value "$SUMMARY_CSV" "official_source_observed_declared_rows" "4" "v08-at official source declarations"
expect_summary_value "$SUMMARY_CSV" "public_leaderboard_observed_declared_rows" "4" "v08-at leaderboard declarations"
expect_summary_value "$SUMMARY_CSV" "runner_owned_reconciliation_declared_rows" "4" "v08-at runner declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-at fixture-free rows"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-at timestamp rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "1" "v08-at ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-at supplied reconciliation must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "official-result-reconciliation-ready-await-public-real-external-claim" "v08-at good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-at routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-at jump should stay zero"

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
    if ($idx["gate"] == "upstream-live-package-artifact-fetch-authority" && $idx["status"] != "pass") die("v08-at upstream should pass", 20)
    if ($idx["gate"] == "official-result-reconciliation-coverage" && $idx["status"] != "pass") die("v08-at coverage should pass", 21)
    if ($idx["gate"] == "official-result-reconciliation-artifacts" && $idx["status"] != "pass") die("v08-at artifacts should pass", 22)
    if ($idx["gate"] == "official-result-reconciliation-bindings" && $idx["status"] != "pass") die("v08-at bindings should pass", 23)
    if ($idx["gate"] == "official-result-reconciliation-artifact-identity" && $idx["status"] != "pass") die("v08-at artifact identity should pass", 24)
    if ($idx["gate"] == "official-result-reconciliation-metrics" && $idx["status"] != "pass") die("v08-at metrics should pass", 25)
    if ($idx["gate"] == "official-result-reconciliation-query-count" && $idx["status"] != "pass") die("v08-at query count should pass", 26)
    if ($idx["gate"] == "official-result-reconciliation-declarations" && $idx["status"] != "pass") die("v08-at declarations should pass", 27)
    if ($idx["gate"] == "fixture-declarations" && $idx["status"] != "pass") die("v08-at fixture declaration should pass", 28)
    if ($idx["gate"] == "external-benchmark-official-result-reconciliation" && $idx["status"] != "pass") die("v08-at ready should pass", 29)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-at real benchmark should remain blocked", 30)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-at jump guardrail should pass", 31)
  }
  END {
    if (rows != 12) die("expected v08-at decision rows", 32)
  }
' "$DECISION_CSV"

write_bad_coverage_csv "$BAD_COVERAGE_CSV"
run_v08at_with_upstream "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "reconciliation_rows" "3" "v08-at bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-coverage-incomplete" "v08-at bad coverage action"

write_good_reconciliation_csv "$BAD_HASH_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $12 = "sha256:not-a-valid-hash" } { print }' \
  "$BAD_HASH_CSV" >"$BAD_HASH_CSV.tmp"
mv "$BAD_HASH_CSV.tmp" "$BAD_HASH_CSV"
run_v08at_with_upstream "$BAD_HASH_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "reconciliation_hash_attested_fields" "27" "v08-at bad hash count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad hash should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-hash-attestation-missing" "v08-at bad hash action"

write_good_reconciliation_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $11 = "https://results.example.org/official-result.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08at_with_upstream "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_reconciliation_uri_fields" "27" "v08-at bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-placeholder-artifact-uri" "v08-at bad placeholder action"

write_good_reconciliation_csv "$BAD_PACKAGE_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $2 = "wrong-package-id" } { print }' \
  "$BAD_PACKAGE_CSV" >"$BAD_PACKAGE_CSV.tmp"
mv "$BAD_PACKAGE_CSV.tmp" "$BAD_PACKAGE_CSV"
run_v08at_with_upstream "$BAD_PACKAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "package_identity_match_rows" "3" "v08-at bad package count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad package should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-package-identity-mismatch" "v08-at bad package action"

write_good_reconciliation_csv "$BAD_ARTIFACT_BINDING_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $5 = "0" } { print }' \
  "$BAD_ARTIFACT_BINDING_CSV" >"$BAD_ARTIFACT_BINDING_CSV.tmp"
mv "$BAD_ARTIFACT_BINDING_CSV.tmp" "$BAD_ARTIFACT_BINDING_CSV"
run_v08at_with_upstream "$BAD_ARTIFACT_BINDING_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "artifact_binding_declared_rows" "3" "v08-at bad artifact binding count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad artifact binding should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-artifact-binding-missing" "v08-at bad artifact binding action"

write_good_reconciliation_csv "$BAD_ARTIFACT_IDENTITY_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $13 = "https://results.routebench.dev/mismatch/leaderboard.json" } { print }' \
  "$BAD_ARTIFACT_IDENTITY_CSV" >"$BAD_ARTIFACT_IDENTITY_CSV.tmp"
mv "$BAD_ARTIFACT_IDENTITY_CSV.tmp" "$BAD_ARTIFACT_IDENTITY_CSV"
run_v08at_with_upstream "$BAD_ARTIFACT_IDENTITY_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "fetch_artifact_identity_match_rows" "3" "v08-at bad artifact identity count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad artifact identity should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-artifact-identity-mismatch" "v08-at bad artifact identity action"

write_good_reconciliation_csv "$BAD_METRIC_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $27 = "0.100000"; $28 = "0.500000" } { print }' \
  "$BAD_METRIC_CSV" >"$BAD_METRIC_CSV.tmp"
mv "$BAD_METRIC_CSV.tmp" "$BAD_METRIC_CSV"
run_v08at_with_upstream "$BAD_METRIC_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_delta_within_tolerance_rows" "3" "v08-at bad metric count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad metric should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-metric-mismatch" "v08-at bad metric action"

write_good_reconciliation_csv "$BAD_QUERY_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $31 = "999" } { print }' \
  "$BAD_QUERY_CSV" >"$BAD_QUERY_CSV.tmp"
mv "$BAD_QUERY_CSV.tmp" "$BAD_QUERY_CSV"
run_v08at_with_upstream "$BAD_QUERY_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "query_count_exact_match_rows" "3" "v08-at bad query count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad query should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-query-count-mismatch" "v08-at bad query action"

write_good_reconciliation_csv "$BAD_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $33 = "0" } { print }' \
  "$BAD_DECLARATION_CSV" >"$BAD_DECLARATION_CSV.tmp"
mv "$BAD_DECLARATION_CSV.tmp" "$BAD_DECLARATION_CSV"
run_v08at_with_upstream "$BAD_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "evaluator_identity_match_declared_rows" "3" "v08-at bad evaluator declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-evaluator-or-digest-declaration-missing" "v08-at bad declaration action"

write_good_reconciliation_csv "$BAD_OFFICIAL_SOURCE_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $35 = "0" } { print }' \
  "$BAD_OFFICIAL_SOURCE_CSV" >"$BAD_OFFICIAL_SOURCE_CSV.tmp"
mv "$BAD_OFFICIAL_SOURCE_CSV.tmp" "$BAD_OFFICIAL_SOURCE_CSV"
run_v08at_with_upstream "$BAD_OFFICIAL_SOURCE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "official_source_observed_declared_rows" "3" "v08-at bad official source count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad official source should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-official-source-missing" "v08-at bad official source action"

write_good_reconciliation_csv "$BAD_RUNNER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $37 = "0" } { print }' \
  "$BAD_RUNNER_CSV" >"$BAD_RUNNER_CSV.tmp"
mv "$BAD_RUNNER_CSV.tmp" "$BAD_RUNNER_CSV"
run_v08at_with_upstream "$BAD_RUNNER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "runner_owned_reconciliation_declared_rows" "3" "v08-at bad runner count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad runner should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-runner-declaration-missing" "v08-at bad runner action"

write_good_reconciliation_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $41 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08at_with_upstream "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-at bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_result_reconciliation_ready" "0" "v08-at bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-official-result-reconciliation-jump-guardrail-violated" "v08-at bad jump action"

run_v08at_with_upstream "$RECONCILIATION_CSV" >/dev/null

echo "v08 external benchmark official result reconciliation smoke passed"
