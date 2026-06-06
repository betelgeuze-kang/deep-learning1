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
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_coverage_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_placeholder_fixture.csv"
BAD_METRIC_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_metric_fixture.csv"
BAD_DELTA_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_delta_fixture.csv"
BAD_BINDING_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_binding_fixture.csv"
BAD_INDEPENDENT_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_independent_declaration_fixture.csv"
BAD_LIVE_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_live_declaration_fixture.csv"
BAD_RECONCILIATION_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_reconciliation_declaration_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-aq summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-aq summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

write_confirmation_header() {
  echo "benchmark_family,live_execution_audit_id,independent_rerun_id,independent_observer_id,v08ap_audit_bound,independent_runner_declared,independent_environment_declared,live_network_rerun_declared,external_dataset_refetch_declared,evaluator_reinvoked_declared,audit_receipt_reconciled_declared,metric_recomputed_declared,third_party_confirmation_declared,fixture_or_synthetic_declared,query_rows_rerun,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,metric_delta_abs,rerun_manifest_uri,rerun_manifest_hash,independent_command_receipt_uri,independent_command_receipt_hash,rerun_stdout_uri,rerun_stdout_hash,rerun_stderr_uri,rerun_stderr_hash,independent_network_trace_uri,independent_network_trace_hash,dataset_refetch_receipt_uri,dataset_refetch_receipt_hash,evaluator_reinvocation_log_uri,evaluator_reinvocation_log_hash,rerun_evaluator_output_uri,rerun_evaluator_output_hash,metric_recompute_diff_uri,metric_recompute_diff_hash,audit_receipt_reconciliation_uri,audit_receipt_reconciliation_hash,environment_reproduction_attestation_uri,environment_reproduction_attestation_hash,observer_identity_uri,observer_identity_hash,third_party_confirmation_report_uri,third_party_confirmation_report_hash,timestamp_authority_uri,timestamp_authority_hash,public_rerun_registry_entry_uri,public_rerun_registry_entry_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_confirmation_row() {
  local csv="$1"
  local family="$2"
  local wrong_answer_rate="${3:-0.010000}"
  local host="${4:-rerun.routebench.dev}"
  local v08ap_bound="${5:-1}"
  local independent_declared="${6:-1}"
  local live_declared="${7:-1}"
  local reconciliation_declared="${8:-1}"
  local metric_delta_abs="${9:-0.005000}"
  local active_jump="${10:-0.000000}"
  local audit_id="live-execution-audit-${family}-20260603"
  local rerun_id="independent-rerun-${family}-20260603"
  local observer_id="independent-observer-${family}-20260603"
  local base="https://${host}/benchmarks/${family}/${rerun_id}"

  local fields=(
    "$family" \
    "$audit_id" \
    "$rerun_id" \
    "$observer_id" \
    "$v08ap_bound" \
    "$independent_declared" \
    "1" \
    "$live_declared" \
    "1" \
    "1" \
    "$reconciliation_declared" \
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
    "$base/rerun_manifest.json" \
    "$(hash_for "$family-rerun-manifest")" \
    "$base/independent_command_receipt.json" \
    "$(hash_for "$family-independent-command-receipt")" \
    "$base/rerun_stdout.txt" \
    "$(hash_for "$family-rerun-stdout")" \
    "$base/rerun_stderr.txt" \
    "$(hash_for "$family-rerun-stderr")" \
    "$base/independent_network_trace.jsonl" \
    "$(hash_for "$family-independent-network-trace")" \
    "$base/dataset_refetch_receipt.json" \
    "$(hash_for "$family-dataset-refetch-receipt")" \
    "$base/evaluator_reinvocation.log" \
    "$(hash_for "$family-evaluator-reinvocation")" \
    "$base/rerun_evaluator_output.jsonl" \
    "$(hash_for "$family-rerun-evaluator-output")" \
    "$base/metric_recompute_diff.json" \
    "$(hash_for "$family-metric-recompute-diff")" \
    "$base/audit_receipt_reconciliation.json" \
    "$(hash_for "$family-audit-receipt-reconciliation")" \
    "$base/environment_reproduction_attestation.json" \
    "$(hash_for "$family-environment-reproduction-attestation")" \
    "$base/observer_identity.json" \
    "$(hash_for "$family-observer-identity")" \
    "$base/third_party_confirmation_report.json" \
    "$(hash_for "$family-third-party-confirmation-report")" \
    "$base/timestamp_authority.json" \
    "$(hash_for "$family-timestamp-authority")" \
    "$base/public_rerun_registry_entry.json" \
    "$(hash_for "$family-public-rerun-registry-entry")" \
    "2026-06-03T00:00:00Z" \
    "0.000000" \
    "$active_jump"
  )
  (IFS=,; printf '%s\n' "${fields[*]}") >>"$csv"
}

write_good_confirmation_csv() {
  local csv="$1"

  write_confirmation_header >"$csv"
  append_confirmation_row "$csv" "RULER"
  append_confirmation_row "$csv" "LongBench"
  append_confirmation_row "$csv" "codebase-retrieval"
  append_confirmation_row "$csv" "real-document-qa"
}

run_v08aq_with_upstream() {
  local rerun_csv="$1"

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
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_LIVE_RERUN_CONFIRMATION_CSV="$rerun_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_live_rerun_confirmation.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_independent_live_rerun_confirmation.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "confirmation_source" "pending-csv" "default v08-aq source"
expect_summary_value "$SUMMARY_CSV" "upstream_runner_owned_live_execution_audit_ready" "0" "default v08-aq upstream should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "default v08-aq should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-aq must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-runner-owned-live-execution-audit-not-ready" "default v08-aq action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_runner_owned_live_execution_audit.sh" >/dev/null
write_good_confirmation_csv "$RERUN_CSV"
run_v08aq_with_upstream "$RERUN_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "confirmation_source" "provided-csv" "v08-aq confirmation source"
expect_summary_value "$SUMMARY_CSV" "upstream_runner_owned_live_execution_audit_ready" "1" "v08-aq upstream audit"
expect_summary_value "$SUMMARY_CSV" "confirmation_rows" "4" "v08-aq confirmation rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-aq expected family rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-aq duplicate rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-aq family coverage"
expect_summary_value "$SUMMARY_CSV" "required_live_rerun_confirmation_uri_fields" "60" "v08-aq required URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_live_rerun_confirmation_uri_fields" "60" "v08-aq nonlocal URI fields"
expect_summary_value "$SUMMARY_CSV" "local_live_rerun_confirmation_uri_fields" "0" "v08-aq local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_live_rerun_confirmation_uri_fields" "60" "v08-aq non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_live_rerun_confirmation_hash_fields" "60" "v08-aq required hash fields"
expect_summary_value "$SUMMARY_CSV" "live_rerun_confirmation_hash_attested_fields" "60" "v08-aq hash attestations"
expect_summary_value "$SUMMARY_CSV" "total_rerun_query_rows" "256" "v08-aq total query rows"
expect_summary_value "$SUMMARY_CSV" "min_rerun_query_rows_pass_rows" "4" "v08-aq query volume"
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "4" "v08-aq metric thresholds"
expect_summary_value "$SUMMARY_CSV" "metric_delta_pass_rows" "4" "v08-aq metric deltas"
expect_summary_value "$SUMMARY_CSV" "v08ap_audit_bound_rows" "4" "v08-aq v08-ap binding"
expect_summary_value "$SUMMARY_CSV" "independent_runner_declared_rows" "4" "v08-aq independent runner declaration"
expect_summary_value "$SUMMARY_CSV" "independent_environment_declared_rows" "4" "v08-aq independent environment declaration"
expect_summary_value "$SUMMARY_CSV" "live_network_rerun_declared_rows" "4" "v08-aq network declaration"
expect_summary_value "$SUMMARY_CSV" "external_dataset_refetch_declared_rows" "4" "v08-aq dataset refetch declaration"
expect_summary_value "$SUMMARY_CSV" "evaluator_reinvoked_declared_rows" "4" "v08-aq evaluator declaration"
expect_summary_value "$SUMMARY_CSV" "audit_receipt_reconciled_declared_rows" "4" "v08-aq reconciliation declaration"
expect_summary_value "$SUMMARY_CSV" "metric_recomputed_declared_rows" "4" "v08-aq recompute declaration"
expect_summary_value "$SUMMARY_CSV" "third_party_confirmation_declared_rows" "4" "v08-aq third-party declaration"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-aq fixture-free rows"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-aq timestamp rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "1" "v08-aq live rerun confirmation ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-aq supplied mechanics must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "independent-live-rerun-confirmation-ready-await-real-nonfixture-benchmark-run-package" "v08-aq good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-aq routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-aq jump should stay zero"

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
    if ($idx["gate"] == "upstream-runner-owned-live-execution-audit" && $idx["status"] != "pass") die("v08-aq upstream should pass", 20)
    if ($idx["gate"] == "independent-live-rerun-confirmation-coverage" && $idx["status"] != "pass") die("v08-aq coverage should pass", 21)
    if ($idx["gate"] == "independent-live-rerun-confirmation-artifacts" && $idx["status"] != "pass") die("v08-aq artifacts should pass", 22)
    if ($idx["gate"] == "independent-live-rerun-confirmation-query-volume" && $idx["status"] != "pass") die("v08-aq query volume should pass", 23)
    if ($idx["gate"] == "independent-live-rerun-confirmation-metric-thresholds" && $idx["status"] != "pass") die("v08-aq metrics should pass", 24)
    if ($idx["gate"] == "independent-live-rerun-confirmation-metric-delta" && $idx["status"] != "pass") die("v08-aq metric deltas should pass", 25)
    if ($idx["gate"] == "independent-live-rerun-confirmation-bindings" && $idx["status"] != "pass") die("v08-aq bindings should pass", 26)
    if ($idx["gate"] == "independent-runner-declarations" && $idx["status"] != "pass") die("v08-aq independent declarations should pass", 27)
    if ($idx["gate"] == "live-rerun-declarations" && $idx["status"] != "pass") die("v08-aq live declarations should pass", 28)
    if ($idx["gate"] == "rerun-reconciliation-declarations" && $idx["status"] != "pass") die("v08-aq reconciliation declarations should pass", 29)
    if ($idx["gate"] == "fixture-declarations" && $idx["status"] != "pass") die("v08-aq fixture declarations should pass", 30)
    if ($idx["gate"] == "external-benchmark-independent-live-rerun-confirmation" && $idx["status"] != "pass") die("v08-aq confirmation should pass", 31)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-aq real benchmark should remain blocked", 32)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-aq jump guardrail should pass", 33)
  }
  END {
    if (rows != 14) die("expected v08-aq decision rows", 34)
  }
' "$DECISION_CSV"

write_confirmation_header >"$BAD_COVERAGE_CSV"
append_confirmation_row "$BAD_COVERAGE_CSV" "RULER"
append_confirmation_row "$BAD_COVERAGE_CSV" "LongBench"
append_confirmation_row "$BAD_COVERAGE_CSV" "codebase-retrieval"
run_v08aq_with_upstream "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "confirmation_rows" "3" "v08-aq bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "3" "v08-aq bad coverage family count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-coverage-incomplete" "v08-aq bad coverage action"

write_good_confirmation_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $50 = "https://rerun.example.org/public_rerun_registry_entry.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08aq_with_upstream "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_live_rerun_confirmation_uri_fields" "59" "v08-aq bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-placeholder-artifact-uri" "v08-aq bad placeholder action"

write_good_confirmation_csv "$BAD_METRIC_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $20 = "0.500000" } { print }' \
  "$BAD_METRIC_CSV" >"$BAD_METRIC_CSV.tmp"
mv "$BAD_METRIC_CSV.tmp" "$BAD_METRIC_CSV"
run_v08aq_with_upstream "$BAD_METRIC_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "3" "v08-aq bad metric count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad metric should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-quality-threshold-missing" "v08-aq bad metric action"

write_good_confirmation_csv "$BAD_DELTA_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $21 = "0.200000" } { print }' \
  "$BAD_DELTA_CSV" >"$BAD_DELTA_CSV.tmp"
mv "$BAD_DELTA_CSV.tmp" "$BAD_DELTA_CSV"
run_v08aq_with_upstream "$BAD_DELTA_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_delta_pass_rows" "3" "v08-aq bad delta count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad delta should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-metric-delta-too-large" "v08-aq bad delta action"

write_good_confirmation_csv "$BAD_BINDING_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $5 = "0" } { print }' \
  "$BAD_BINDING_CSV" >"$BAD_BINDING_CSV.tmp"
mv "$BAD_BINDING_CSV.tmp" "$BAD_BINDING_CSV"
run_v08aq_with_upstream "$BAD_BINDING_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "v08ap_audit_bound_rows" "3" "v08-aq bad binding count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad binding should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-binding-missing" "v08-aq bad binding action"

write_good_confirmation_csv "$BAD_INDEPENDENT_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $6 = "0" } { print }' \
  "$BAD_INDEPENDENT_DECLARATION_CSV" >"$BAD_INDEPENDENT_DECLARATION_CSV.tmp"
mv "$BAD_INDEPENDENT_DECLARATION_CSV.tmp" "$BAD_INDEPENDENT_DECLARATION_CSV"
run_v08aq_with_upstream "$BAD_INDEPENDENT_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "independent_runner_declared_rows" "3" "v08-aq bad independent declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad independent declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-independent-declaration-missing" "v08-aq bad independent declaration action"

write_good_confirmation_csv "$BAD_LIVE_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $8 = "0" } { print }' \
  "$BAD_LIVE_DECLARATION_CSV" >"$BAD_LIVE_DECLARATION_CSV.tmp"
mv "$BAD_LIVE_DECLARATION_CSV.tmp" "$BAD_LIVE_DECLARATION_CSV"
run_v08aq_with_upstream "$BAD_LIVE_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_network_rerun_declared_rows" "3" "v08-aq bad live declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad live declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-live-rerun-declaration-missing" "v08-aq bad live declaration action"

write_good_confirmation_csv "$BAD_RECONCILIATION_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $11 = "0" } { print }' \
  "$BAD_RECONCILIATION_DECLARATION_CSV" >"$BAD_RECONCILIATION_DECLARATION_CSV.tmp"
mv "$BAD_RECONCILIATION_DECLARATION_CSV.tmp" "$BAD_RECONCILIATION_DECLARATION_CSV"
run_v08aq_with_upstream "$BAD_RECONCILIATION_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "audit_receipt_reconciled_declared_rows" "3" "v08-aq bad reconciliation declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad reconciliation declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-reconciliation-declaration-missing" "v08-aq bad reconciliation declaration action"

write_good_confirmation_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $54 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08aq_with_upstream "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-aq bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready" "0" "v08-aq bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-live-rerun-confirmation-jump-guardrail-violated" "v08-aq bad jump action"

run_v08aq_with_upstream "$RERUN_CSV" >/dev/null

echo "v08 external benchmark independent live rerun confirmation smoke passed"
