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
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_bad_coverage_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_bad_placeholder_fixture.csv"
BAD_METRIC_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_bad_metric_fixture.csv"
BAD_BINDING_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_bad_binding_fixture.csv"
BAD_REPLAY_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_bad_replay_declaration_fixture.csv"
BAD_REVIEW_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_bad_review_declaration_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-an summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-an summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

write_replay_header() {
  echo "benchmark_family,external_run_id,live_replay_id,final_review_id,v08am_evidence_bound,all_queries_replayed,metrics_recomputed,live_replay_declared,runner_owned_replay_declared,network_observed_declared,final_review_approved,independent_final_reviewer_declared,public_registry_bound,non_fixture_declared,fixture_or_synthetic_declared,replayed_query_rows,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,replay_manifest_uri,replay_manifest_hash,replay_run_log_uri,replay_run_log_hash,replay_evaluator_output_uri,replay_evaluator_output_hash,replay_metric_report_uri,replay_metric_report_hash,replay_network_receipt_uri,replay_network_receipt_hash,final_review_report_uri,final_review_report_hash,final_reviewer_identity_uri,final_reviewer_identity_hash,final_review_registry_uri,final_review_registry_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_replay_row() {
  local csv="$1"
  local family="$2"
  local wrong_answer_rate="${3:-0.010000}"
  local host="${4:-evidence.routebench.dev}"
  local v08am_bound="${5:-1}"
  local live_declared="${6:-1}"
  local final_approved="${7:-1}"
  local active_jump="${8:-0.000000}"
  local run_id="run-${family}-20260603"
  local replay_id="live-replay-${family}-20260603"
  local review_id="final-review-${family}-20260603"
  local base="https://${host}/benchmarks/${family}/${run_id}"

  local fields=(
    "$family" \
    "$run_id" \
    "$replay_id" \
    "$review_id" \
    "$v08am_bound" \
    "1" \
    "1" \
    "$live_declared" \
    "1" \
    "1" \
    "$final_approved" \
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
    "$base/live_replay_manifest.json" \
    "$(hash_for "$family-live-replay-manifest")" \
    "$base/live_replay_run.log" \
    "$(hash_for "$family-live-replay-run-log")" \
    "$base/live_replay_evaluator_output.jsonl" \
    "$(hash_for "$family-live-replay-evaluator-output")" \
    "$base/live_replay_metric_report.json" \
    "$(hash_for "$family-live-replay-metric-report")" \
    "$base/live_replay_network_receipt.json" \
    "$(hash_for "$family-live-replay-network-receipt")" \
    "$base/final_review_report.json" \
    "$(hash_for "$family-final-review-report")" \
    "$base/final_reviewer_identity.json" \
    "$(hash_for "$family-final-reviewer-identity")" \
    "$base/final_review_registry.json" \
    "$(hash_for "$family-final-review-registry")" \
    "2026-06-03T00:00:00Z" \
    "0.000000" \
    "$active_jump"
  )
  (IFS=,; printf '%s\n' "${fields[*]}") >>"$csv"
}

write_good_replay_csv() {
  local csv="$1"

  write_replay_header >"$csv"
  append_replay_row "$csv" "RULER"
  append_replay_row "$csv" "LongBench"
  append_replay_row "$csv" "codebase-retrieval"
  append_replay_row "$csv" "real-document-qa"
}

run_v08an_with_upstream() {
  local replay_csv="$1"

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
  V08_EXTERNAL_BENCHMARK_LIVE_REPLAY_FINAL_REVIEW_CSV="$replay_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_live_replay_final_review.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_replay_final_review.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "replay_source" "pending-csv" "default v08-an replay source"
expect_summary_value "$SUMMARY_CSV" "upstream_independent_run_evaluator_evidence_ready" "0" "default v08-an upstream should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "default v08-an should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-an must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-run-evaluator-evidence-not-ready" "default v08-an action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_independent_run_evaluator_evidence.sh" >/dev/null
write_good_replay_csv "$REPLAY_CSV"
run_v08an_with_upstream "$REPLAY_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "replay_source" "provided-csv" "v08-an replay source"
expect_summary_value "$SUMMARY_CSV" "upstream_independent_run_evaluator_evidence_ready" "1" "v08-an upstream independent evidence"
expect_summary_value "$SUMMARY_CSV" "review_rows" "4" "v08-an review rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-an expected family rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-an duplicate family rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-an family coverage"
expect_summary_value "$SUMMARY_CSV" "expected_external_families" "4" "v08-an expected external families"
expect_summary_value "$SUMMARY_CSV" "required_replay_review_uri_fields" "32" "v08-an required URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_replay_review_uri_fields" "32" "v08-an nonlocal URI fields"
expect_summary_value "$SUMMARY_CSV" "local_replay_review_uri_fields" "0" "v08-an local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_replay_review_uri_fields" "32" "v08-an non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_replay_review_hash_fields" "32" "v08-an required hash fields"
expect_summary_value "$SUMMARY_CSV" "replay_review_hash_attested_fields" "32" "v08-an attested hash fields"
expect_summary_value "$SUMMARY_CSV" "total_replayed_query_rows" "256" "v08-an total replayed query rows"
expect_summary_value "$SUMMARY_CSV" "min_replayed_query_rows_pass_rows" "4" "v08-an query rows pass"
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "4" "v08-an metric thresholds pass"
expect_summary_value "$SUMMARY_CSV" "v08am_evidence_bound_rows" "4" "v08-an v08-am binding"
expect_summary_value "$SUMMARY_CSV" "all_queries_replayed_rows" "4" "v08-an query replay binding"
expect_summary_value "$SUMMARY_CSV" "metrics_recomputed_rows" "4" "v08-an metrics recomputed"
expect_summary_value "$SUMMARY_CSV" "live_replay_declared_rows" "4" "v08-an live replay declarations"
expect_summary_value "$SUMMARY_CSV" "runner_owned_replay_declared_rows" "4" "v08-an runner-owned declarations"
expect_summary_value "$SUMMARY_CSV" "network_observed_declared_rows" "4" "v08-an network declarations"
expect_summary_value "$SUMMARY_CSV" "final_review_approved_rows" "4" "v08-an final approval"
expect_summary_value "$SUMMARY_CSV" "independent_final_reviewer_declared_rows" "4" "v08-an independent reviewer"
expect_summary_value "$SUMMARY_CSV" "public_registry_bound_rows" "4" "v08-an public registry"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-an non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-an fixture-free declarations"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-an timestamps"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "1" "v08-an live replay/final review ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-an supplied mechanics must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "live-replay-final-review-ready-await-public-nonfixture-verification" "v08-an good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-an routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-an jump should stay zero"

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
    if ($idx["gate"] == "upstream-independent-run-evaluator-evidence" && $idx["status"] != "pass") die("v08-an upstream should pass", 20)
    if ($idx["gate"] == "live-replay-final-review-coverage" && $idx["status"] != "pass") die("v08-an coverage should pass", 21)
    if ($idx["gate"] == "live-replay-final-review-artifacts" && $idx["status"] != "pass") die("v08-an artifacts should pass", 22)
    if ($idx["gate"] == "live-replay-final-review-query-volume" && $idx["status"] != "pass") die("v08-an query volume should pass", 23)
    if ($idx["gate"] == "live-replay-final-review-metric-thresholds" && $idx["status"] != "pass") die("v08-an metrics should pass", 24)
    if ($idx["gate"] == "live-replay-final-review-bindings" && $idx["status"] != "pass") die("v08-an bindings should pass", 25)
    if ($idx["gate"] == "live-replay-declarations" && $idx["status"] != "pass") die("v08-an replay declarations should pass", 26)
    if ($idx["gate"] == "final-review-declarations" && $idx["status"] != "pass") die("v08-an review declarations should pass", 27)
    if ($idx["gate"] == "fixture-declarations" && $idx["status"] != "pass") die("v08-an fixture declarations should pass", 28)
    if ($idx["gate"] == "external-benchmark-live-replay-final-review" && $idx["status"] != "pass") die("v08-an live replay/final review should pass", 29)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-an real benchmark should remain blocked", 30)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-an jump guardrail should pass", 31)
  }
  END {
    if (rows != 12) die("expected v08-an decision rows", 32)
  }
' "$DECISION_CSV"

write_replay_header >"$BAD_COVERAGE_CSV"
append_replay_row "$BAD_COVERAGE_CSV" "RULER"
append_replay_row "$BAD_COVERAGE_CSV" "LongBench"
append_replay_row "$BAD_COVERAGE_CSV" "codebase-retrieval"
run_v08an_with_upstream "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "review_rows" "3" "v08-an bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "3" "v08-an bad coverage family count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "v08-an bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-coverage-incomplete" "v08-an bad coverage action"

write_good_replay_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $34 = "https://review.example.org/reviewer.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08an_with_upstream "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_replay_review_uri_fields" "31" "v08-an bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "v08-an bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-placeholder-artifact-uri" "v08-an bad placeholder action"

write_good_replay_csv "$BAD_METRIC_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $21 = "0.500000" } { print }' \
  "$BAD_METRIC_CSV" >"$BAD_METRIC_CSV.tmp"
mv "$BAD_METRIC_CSV.tmp" "$BAD_METRIC_CSV"
run_v08an_with_upstream "$BAD_METRIC_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "3" "v08-an bad metric count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "v08-an bad metric should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-quality-threshold-missing" "v08-an bad metric action"

write_good_replay_csv "$BAD_BINDING_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $5 = "0" } { print }' \
  "$BAD_BINDING_CSV" >"$BAD_BINDING_CSV.tmp"
mv "$BAD_BINDING_CSV.tmp" "$BAD_BINDING_CSV"
run_v08an_with_upstream "$BAD_BINDING_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "v08am_evidence_bound_rows" "3" "v08-an bad binding count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "v08-an bad binding should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-binding-missing" "v08-an bad binding action"

write_good_replay_csv "$BAD_REPLAY_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $8 = "0" } { print }' \
  "$BAD_REPLAY_DECLARATION_CSV" >"$BAD_REPLAY_DECLARATION_CSV.tmp"
mv "$BAD_REPLAY_DECLARATION_CSV.tmp" "$BAD_REPLAY_DECLARATION_CSV"
run_v08an_with_upstream "$BAD_REPLAY_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_replay_declared_rows" "3" "v08-an bad replay declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "v08-an bad replay declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-replay-declaration-missing" "v08-an bad replay declaration action"

write_good_replay_csv "$BAD_REVIEW_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $11 = "0" } { print }' \
  "$BAD_REVIEW_DECLARATION_CSV" >"$BAD_REVIEW_DECLARATION_CSV.tmp"
mv "$BAD_REVIEW_DECLARATION_CSV.tmp" "$BAD_REVIEW_DECLARATION_CSV"
run_v08an_with_upstream "$BAD_REVIEW_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "final_review_approved_rows" "3" "v08-an bad review declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "v08-an bad review declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-review-declaration-missing" "v08-an bad review declaration action"

write_good_replay_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $40 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08an_with_upstream "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-an bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready" "0" "v08-an bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-replay-final-review-jump-guardrail-violated" "v08-an bad jump action"

run_v08an_with_upstream "$REPLAY_CSV" >/dev/null

echo "v08 external benchmark live replay/final review smoke passed"
