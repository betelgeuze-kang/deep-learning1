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
AUDIT_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_fixture.csv"
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_coverage_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_placeholder_fixture.csv"
BAD_METRIC_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_metric_fixture.csv"
BAD_BINDING_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_binding_fixture.csv"
BAD_RUNNER_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_runner_declaration_fixture.csv"
BAD_LIVE_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_live_declaration_fixture.csv"
BAD_AUDIT_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_audit_declaration_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-ap summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-ap summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

write_audit_header() {
  echo "benchmark_family,public_verification_id,direct_run_id,live_execution_audit_id,runner_execution_id,v08ao_verification_bound,runner_owned_execution_declared,live_network_execution_declared,external_dataset_live_fetch_declared,evaluator_invoked_by_runner_declared,replay_disabled_declared,audit_log_complete_declared,third_party_audit_review_declared,fixture_or_synthetic_declared,query_rows_executed,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,live_execution_manifest_uri,live_execution_manifest_hash,live_command_receipt_uri,live_command_receipt_hash,runner_stdout_uri,runner_stdout_hash,runner_stderr_uri,runner_stderr_hash,live_network_trace_uri,live_network_trace_hash,dataset_fetch_receipt_uri,dataset_fetch_receipt_hash,evaluator_invocation_log_uri,evaluator_invocation_log_hash,evaluator_output_uri,evaluator_output_hash,metric_recompute_report_uri,metric_recompute_report_hash,environment_attestation_uri,environment_attestation_hash,audit_report_uri,audit_report_hash,auditor_identity_uri,auditor_identity_hash,public_receipt_reconciliation_uri,public_receipt_reconciliation_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_audit_row() {
  local csv="$1"
  local family="$2"
  local wrong_answer_rate="${3:-0.010000}"
  local host="${4:-execution.routebench.dev}"
  local v08ao_bound="${5:-1}"
  local runner_declared="${6:-1}"
  local live_declared="${7:-1}"
  local audit_declared="${8:-1}"
  local active_jump="${9:-0.000000}"
  local public_verification_id="public-verification-${family}-20260603"
  local direct_run_id="direct-run-${family}-20260603"
  local audit_id="live-execution-audit-${family}-20260603"
  local runner_execution_id="runner-execution-${family}-20260603"
  local base="https://${host}/benchmarks/${family}/${runner_execution_id}"

  local fields=(
    "$family" \
    "$public_verification_id" \
    "$direct_run_id" \
    "$audit_id" \
    "$runner_execution_id" \
    "$v08ao_bound" \
    "$runner_declared" \
    "$live_declared" \
    "1" \
    "1" \
    "1" \
    "$audit_declared" \
    "1" \
    "0" \
    "64" \
    "0.900000" \
    "0.820000" \
    "0.920000" \
    "0.010000" \
    "$wrong_answer_rate" \
    "$base/live_execution_manifest.json" \
    "$(hash_for "$family-live-execution-manifest")" \
    "$base/live_command_receipt.json" \
    "$(hash_for "$family-live-command-receipt")" \
    "$base/runner_stdout.txt" \
    "$(hash_for "$family-runner-stdout")" \
    "$base/runner_stderr.txt" \
    "$(hash_for "$family-runner-stderr")" \
    "$base/live_network_trace.jsonl" \
    "$(hash_for "$family-live-network-trace")" \
    "$base/dataset_fetch_receipt.json" \
    "$(hash_for "$family-dataset-fetch-receipt")" \
    "$base/evaluator_invocation.log" \
    "$(hash_for "$family-evaluator-invocation")" \
    "$base/evaluator_output.jsonl" \
    "$(hash_for "$family-evaluator-output")" \
    "$base/metric_recompute_report.json" \
    "$(hash_for "$family-metric-recompute-report")" \
    "$base/environment_attestation.json" \
    "$(hash_for "$family-environment-attestation")" \
    "$base/audit_report.json" \
    "$(hash_for "$family-audit-report")" \
    "$base/auditor_identity.json" \
    "$(hash_for "$family-auditor-identity")" \
    "$base/public_receipt_reconciliation.json" \
    "$(hash_for "$family-public-receipt-reconciliation")" \
    "2026-06-03T00:00:00Z" \
    "0.000000" \
    "$active_jump"
  )
  (IFS=,; printf '%s\n' "${fields[*]}") >>"$csv"
}

write_good_audit_csv() {
  local csv="$1"

  write_audit_header >"$csv"
  append_audit_row "$csv" "RULER"
  append_audit_row "$csv" "LongBench"
  append_audit_row "$csv" "codebase-retrieval"
  append_audit_row "$csv" "real-document-qa"
}

run_v08ap_with_upstream() {
  local audit_csv="$1"

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
  V08_EXTERNAL_BENCHMARK_PUBLIC_NONFIXTURE_VERIFICATION_CSV="$VERIFICATION_CSV" \
  V08_EXTERNAL_BENCHMARK_RUNNER_OWNED_LIVE_EXECUTION_AUDIT_CSV="$audit_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_runner_owned_live_execution_audit.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_runner_owned_live_execution_audit.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "audit_source" "pending-csv" "default v08-ap source"
expect_summary_value "$SUMMARY_CSV" "upstream_public_nonfixture_verification_ready" "0" "default v08-ap upstream should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "default v08-ap should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-ap must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-public-nonfixture-verification-not-ready" "default v08-ap action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_public_nonfixture_verification.sh" >/dev/null
write_good_audit_csv "$AUDIT_CSV"
run_v08ap_with_upstream "$AUDIT_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "audit_source" "provided-csv" "v08-ap audit source"
expect_summary_value "$SUMMARY_CSV" "upstream_public_nonfixture_verification_ready" "1" "v08-ap upstream public verification"
expect_summary_value "$SUMMARY_CSV" "audit_rows" "4" "v08-ap audit rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-ap expected family rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-ap duplicate rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-ap family coverage"
expect_summary_value "$SUMMARY_CSV" "required_live_execution_audit_uri_fields" "52" "v08-ap required URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_live_execution_audit_uri_fields" "52" "v08-ap nonlocal URI fields"
expect_summary_value "$SUMMARY_CSV" "local_live_execution_audit_uri_fields" "0" "v08-ap local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_live_execution_audit_uri_fields" "52" "v08-ap non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_live_execution_audit_hash_fields" "52" "v08-ap required hash fields"
expect_summary_value "$SUMMARY_CSV" "live_execution_audit_hash_attested_fields" "52" "v08-ap hash attestations"
expect_summary_value "$SUMMARY_CSV" "total_executed_query_rows" "256" "v08-ap total query rows"
expect_summary_value "$SUMMARY_CSV" "min_executed_query_rows_pass_rows" "4" "v08-ap query volume"
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "4" "v08-ap metric thresholds"
expect_summary_value "$SUMMARY_CSV" "v08ao_verification_bound_rows" "4" "v08-ap v08-ao binding"
expect_summary_value "$SUMMARY_CSV" "runner_owned_execution_declared_rows" "4" "v08-ap runner declaration"
expect_summary_value "$SUMMARY_CSV" "live_network_execution_declared_rows" "4" "v08-ap network declaration"
expect_summary_value "$SUMMARY_CSV" "external_dataset_live_fetch_declared_rows" "4" "v08-ap dataset live fetch declaration"
expect_summary_value "$SUMMARY_CSV" "evaluator_invoked_by_runner_declared_rows" "4" "v08-ap evaluator declaration"
expect_summary_value "$SUMMARY_CSV" "replay_disabled_declared_rows" "4" "v08-ap replay disabled declaration"
expect_summary_value "$SUMMARY_CSV" "audit_log_complete_declared_rows" "4" "v08-ap audit log declaration"
expect_summary_value "$SUMMARY_CSV" "third_party_audit_review_declared_rows" "4" "v08-ap third-party audit declaration"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-ap fixture-free rows"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-ap timestamp rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "1" "v08-ap live execution audit ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-ap supplied mechanics must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "runner-owned-live-execution-audit-ready-await-independent-live-rerun-confirmation" "v08-ap good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-ap routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-ap jump should stay zero"

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
    if ($idx["gate"] == "upstream-public-nonfixture-verification" && $idx["status"] != "pass") die("v08-ap upstream should pass", 20)
    if ($idx["gate"] == "runner-owned-live-execution-audit-coverage" && $idx["status"] != "pass") die("v08-ap coverage should pass", 21)
    if ($idx["gate"] == "runner-owned-live-execution-audit-artifacts" && $idx["status"] != "pass") die("v08-ap artifacts should pass", 22)
    if ($idx["gate"] == "runner-owned-live-execution-audit-query-volume" && $idx["status"] != "pass") die("v08-ap query volume should pass", 23)
    if ($idx["gate"] == "runner-owned-live-execution-audit-metric-thresholds" && $idx["status"] != "pass") die("v08-ap metrics should pass", 24)
    if ($idx["gate"] == "runner-owned-live-execution-audit-bindings" && $idx["status"] != "pass") die("v08-ap bindings should pass", 25)
    if ($idx["gate"] == "runner-execution-declarations" && $idx["status"] != "pass") die("v08-ap runner declarations should pass", 26)
    if ($idx["gate"] == "live-execution-declarations" && $idx["status"] != "pass") die("v08-ap live declarations should pass", 27)
    if ($idx["gate"] == "audit-declarations" && $idx["status"] != "pass") die("v08-ap audit declarations should pass", 28)
    if ($idx["gate"] == "fixture-declarations" && $idx["status"] != "pass") die("v08-ap fixture declarations should pass", 29)
    if ($idx["gate"] == "external-benchmark-runner-owned-live-execution-audit" && $idx["status"] != "pass") die("v08-ap audit should pass", 30)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-ap real benchmark should remain blocked", 31)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-ap jump guardrail should pass", 32)
  }
  END {
    if (rows != 13) die("expected v08-ap decision rows", 33)
  }
' "$DECISION_CSV"

write_audit_header >"$BAD_COVERAGE_CSV"
append_audit_row "$BAD_COVERAGE_CSV" "RULER"
append_audit_row "$BAD_COVERAGE_CSV" "LongBench"
append_audit_row "$BAD_COVERAGE_CSV" "codebase-retrieval"
run_v08ap_with_upstream "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "audit_rows" "3" "v08-ap bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "3" "v08-ap bad coverage family count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-coverage-incomplete" "v08-ap bad coverage action"

write_good_audit_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $45 = "https://audit.example.org/reconciliation.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08ap_with_upstream "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_live_execution_audit_uri_fields" "51" "v08-ap bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-placeholder-artifact-uri" "v08-ap bad placeholder action"

write_good_audit_csv "$BAD_METRIC_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $20 = "0.500000" } { print }' \
  "$BAD_METRIC_CSV" >"$BAD_METRIC_CSV.tmp"
mv "$BAD_METRIC_CSV.tmp" "$BAD_METRIC_CSV"
run_v08ap_with_upstream "$BAD_METRIC_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "3" "v08-ap bad metric count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad metric should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-quality-threshold-missing" "v08-ap bad metric action"

write_good_audit_csv "$BAD_BINDING_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $6 = "0" } { print }' \
  "$BAD_BINDING_CSV" >"$BAD_BINDING_CSV.tmp"
mv "$BAD_BINDING_CSV.tmp" "$BAD_BINDING_CSV"
run_v08ap_with_upstream "$BAD_BINDING_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "v08ao_verification_bound_rows" "3" "v08-ap bad binding count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad binding should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-binding-missing" "v08-ap bad binding action"

write_good_audit_csv "$BAD_RUNNER_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $7 = "0" } { print }' \
  "$BAD_RUNNER_DECLARATION_CSV" >"$BAD_RUNNER_DECLARATION_CSV.tmp"
mv "$BAD_RUNNER_DECLARATION_CSV.tmp" "$BAD_RUNNER_DECLARATION_CSV"
run_v08ap_with_upstream "$BAD_RUNNER_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "runner_owned_execution_declared_rows" "3" "v08-ap bad runner declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad runner declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-runner-declaration-missing" "v08-ap bad runner declaration action"

write_good_audit_csv "$BAD_LIVE_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $8 = "0" } { print }' \
  "$BAD_LIVE_DECLARATION_CSV" >"$BAD_LIVE_DECLARATION_CSV.tmp"
mv "$BAD_LIVE_DECLARATION_CSV.tmp" "$BAD_LIVE_DECLARATION_CSV"
run_v08ap_with_upstream "$BAD_LIVE_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_network_execution_declared_rows" "3" "v08-ap bad live declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad live declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-live-execution-declaration-missing" "v08-ap bad live declaration action"

write_good_audit_csv "$BAD_AUDIT_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $12 = "0" } { print }' \
  "$BAD_AUDIT_DECLARATION_CSV" >"$BAD_AUDIT_DECLARATION_CSV.tmp"
mv "$BAD_AUDIT_DECLARATION_CSV.tmp" "$BAD_AUDIT_DECLARATION_CSV"
run_v08ap_with_upstream "$BAD_AUDIT_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "audit_log_complete_declared_rows" "3" "v08-ap bad audit declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad audit declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-audit-declaration-missing" "v08-ap bad audit declaration action"

write_good_audit_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $49 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08ap_with_upstream "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-ap bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready" "0" "v08-ap bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-jump-guardrail-violated" "v08-ap bad jump action"

run_v08ap_with_upstream "$AUDIT_CSV" >/dev/null

echo "v08 external benchmark runner-owned live execution audit smoke passed"
