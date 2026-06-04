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
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_smoke_decision.csv"
GOOD_TRACE_DIR="$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_smoke_artifacts/run-evaluator-trace"
BAD_HASH_TRACE_DIR="$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_bad_hash_artifacts/run-evaluator-trace"
BAD_QUERY_TRACE_DIR="$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_bad_query_artifacts/run-evaluator-trace"
BAD_METRIC_TRACE_DIR="$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_bad_metric_artifacts/run-evaluator-trace"

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
      if (!(field in idx)) die("missing v08-al summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-al summary row", 4)
    }
  ' "$summary_csv"
}

run_v08al_with_authority() {
  local trace_dir="${1:-}"

  if [[ -n "$trace_dir" ]]; then
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
    V08_EXTERNAL_BENCHMARK_RUN_EVALUATOR_TRACE_DIR="$trace_dir" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_run_evaluator_trace.sh" --smoke
  else
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
      "$ROOT_DIR/experiments/run_v08_external_benchmark_run_evaluator_trace.sh" --smoke
  fi
}

rewrite_trace_hashes() {
  local trace_dir="$1"
  local file

  : >"$trace_dir/sha256sums.txt"
  for file in runner_manifest.json evaluator_manifest.json query_trace.csv evaluator_output.csv metrics_recomputed.csv command_receipt.txt; do
    sha256sum "$trace_dir/$file" | awk -v f="$file" '{print $1 "  " f}' >>"$trace_dir/sha256sums.txt"
  done
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_run_evaluator_trace.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "trace_source" "generated-local-codebase-run" "default v08-al trace source"
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "0" "default v08-al authority should block"
expect_summary_value "$SUMMARY_CSV" "codebase_run_evaluator_trace_ready" "1" "default v08-al codebase trace should still build"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_run_evaluator_trace_ready" "0" "default v08-al all-family run evidence should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-al must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-not-ready" "default v08-al action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_authority_promotion_evidence.sh" >/dev/null
run_v08al_with_authority

expect_summary_value "$SUMMARY_CSV" "trace_source" "generated-local-codebase-run" "v08-al trace source"
expect_summary_value "$SUMMARY_CSV" "authority_promotion_evidence_ready" "1" "v08-al authority should pass"
expect_summary_value "$SUMMARY_CSV" "authority_real_external" "0" "v08-al authority remains non-real"
expect_summary_value "$SUMMARY_CSV" "codebase_mini_source_ready" "1" "v08-al codebase source should pass"
expect_summary_value "$SUMMARY_CSV" "benchmark_result_artifact_verified" "1" "v08-al codebase result should pass"
expect_summary_value "$SUMMARY_CSV" "baseline_comparison_ready" "1" "v08-al baseline comparison should pass"
expect_summary_value "$SUMMARY_CSV" "trace_artifact_files" "6" "v08-al should create six trace artifacts"
expect_summary_value "$SUMMARY_CSV" "trace_hash_manifest_entries" "6" "v08-al should hash six trace artifacts"
expect_summary_value "$SUMMARY_CSV" "trace_hash_verified_files" "6" "v08-al should verify six trace artifacts"
expect_summary_value "$SUMMARY_CSV" "dataset_rows" "7" "v08-al dataset rows"
expect_summary_value "$SUMMARY_CSV" "result_rows" "7" "v08-al result rows"
expect_summary_value "$SUMMARY_CSV" "query_trace_rows" "7" "v08-al query trace rows"
expect_summary_value "$SUMMARY_CSV" "evaluator_output_rows" "7" "v08-al evaluator output rows"
expect_summary_value "$SUMMARY_CSV" "matched_query_rows" "7" "v08-al matched query rows"
expect_summary_value "$SUMMARY_CSV" "dataset_bound_rows" "7" "v08-al dataset bindings"
expect_summary_value "$SUMMARY_CSV" "result_bound_rows" "7" "v08-al result bindings"
expect_summary_value "$SUMMARY_CSV" "runner_owned_evaluator_rows" "7" "v08-al runner-owned evaluator rows"
expect_summary_value "$SUMMARY_CSV" "independent_evaluator_rows" "0" "v08-al should not invent independent evaluator rows"
expect_summary_value "$SUMMARY_CSV" "metric_rows" "5" "v08-al metric rows"
expect_summary_value "$SUMMARY_CSV" "span_exact" "1.000000" "v08-al span exact"
expect_summary_value "$SUMMARY_CSV" "chunk_exact" "1.000000" "v08-al chunk exact"
expect_summary_value "$SUMMARY_CSV" "missing_abstain" "1.000000" "v08-al missing abstain"
expect_summary_value "$SUMMARY_CSV" "near_miss_false_positive" "0.000000" "v08-al near miss false positive"
expect_summary_value "$SUMMARY_CSV" "wrong_answer_rate" "0.000000" "v08-al wrong answer rate"
expect_summary_value "$SUMMARY_CSV" "metrics_match_rows" "5" "v08-al metrics should match v08-ab"
expect_summary_value "$SUMMARY_CSV" "codebase_run_evaluator_trace_ready" "1" "v08-al codebase trace should pass"
expect_summary_value "$SUMMARY_CSV" "external_family_coverage" "1" "v08-al should cover one family"
expect_summary_value "$SUMMARY_CSV" "expected_external_families" "4" "v08-al should require four families"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_run_evaluator_trace_ready" "0" "v08-al should block all-family run evidence"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-al must not verify real external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "codebase-run-evaluator-trace-ready-await-independent-all-family-run-evidence" "v08-al good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-al routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-al jump should stay zero"

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
    if ($idx["gate"] == "authority-promotion-evidence" && $idx["status"] != "pass") die("v08-al authority should pass", 20)
    if ($idx["gate"] == "codebase-mini-result" && $idx["status"] != "pass") die("v08-al codebase result should pass", 21)
    if ($idx["gate"] == "run-evaluator-trace-artifacts" && $idx["status"] != "pass") die("v08-al trace artifacts should pass", 22)
    if ($idx["gate"] == "run-evaluator-query-binding" && $idx["status"] != "pass") die("v08-al query binding should pass", 23)
    if ($idx["gate"] == "run-evaluator-metrics" && $idx["status"] != "pass") die("v08-al metrics should pass", 24)
    if ($idx["gate"] == "codebase-run-evaluator-trace" && $idx["status"] != "pass") die("v08-al codebase trace should pass", 25)
    if ($idx["gate"] == "external-family-run-evaluator-coverage" && $idx["status"] != "blocked") die("v08-al all-family coverage should block", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-al real external benchmark should block", 27)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-al jump guardrail should pass", 28)
  }
  END {
    if (rows != 9) die("expected v08-al decision rows", 29)
  }
' "$DECISION_CSV"

rm -rf "$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_bad_hash_artifacts"
mkdir -p "$(dirname "$BAD_HASH_TRACE_DIR")"
cp -R "$GOOD_TRACE_DIR" "$BAD_HASH_TRACE_DIR"
printf '\nq_corrupt,present,CORRUPT,0,0,0,1,1\n' >>"$BAD_HASH_TRACE_DIR/evaluator_output.csv"

run_v08al_with_authority "$BAD_HASH_TRACE_DIR" >/dev/null
expect_summary_value "$SUMMARY_CSV" "trace_source" "provided-dir" "v08-al bad hash source"
expect_summary_value "$SUMMARY_CSV" "trace_hash_verified_files" "5" "v08-al bad hash should leave five verified trace hashes"
expect_summary_value "$SUMMARY_CSV" "codebase_run_evaluator_trace_ready" "0" "v08-al bad hash should block codebase trace"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-al bad hash must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-run-evaluator-trace-hash-mismatch" "v08-al bad hash action"

rm -rf "$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_bad_query_artifacts"
mkdir -p "$(dirname "$BAD_QUERY_TRACE_DIR")"
cp -R "$GOOD_TRACE_DIR" "$BAD_QUERY_TRACE_DIR"
awk 'NR != 2' "$BAD_QUERY_TRACE_DIR/evaluator_output.csv" >"$BAD_QUERY_TRACE_DIR/evaluator_output.tmp"
mv "$BAD_QUERY_TRACE_DIR/evaluator_output.tmp" "$BAD_QUERY_TRACE_DIR/evaluator_output.csv"
rewrite_trace_hashes "$BAD_QUERY_TRACE_DIR"

run_v08al_with_authority "$BAD_QUERY_TRACE_DIR" >/dev/null
expect_summary_value "$SUMMARY_CSV" "trace_hash_verified_files" "6" "v08-al bad query should have valid hashes"
expect_summary_value "$SUMMARY_CSV" "evaluator_output_rows" "6" "v08-al bad query should remove one output row"
expect_summary_value "$SUMMARY_CSV" "matched_query_rows" "0" "v08-al bad query should break matched rows"
expect_summary_value "$SUMMARY_CSV" "codebase_run_evaluator_trace_ready" "0" "v08-al bad query should block codebase trace"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-run-evaluator-trace-query-binding-mismatch" "v08-al bad query action"

rm -rf "$RESULTS_DIR/v08_external_benchmark_run_evaluator_trace_bad_metric_artifacts"
mkdir -p "$(dirname "$BAD_METRIC_TRACE_DIR")"
cp -R "$GOOD_TRACE_DIR" "$BAD_METRIC_TRACE_DIR"
awk -F, 'BEGIN { OFS="," } $1 == "span_exact" { $2 = "0.500000" } { print }' \
  "$BAD_METRIC_TRACE_DIR/metrics_recomputed.csv" >"$BAD_METRIC_TRACE_DIR/metrics_recomputed.tmp"
mv "$BAD_METRIC_TRACE_DIR/metrics_recomputed.tmp" "$BAD_METRIC_TRACE_DIR/metrics_recomputed.csv"
rewrite_trace_hashes "$BAD_METRIC_TRACE_DIR"

run_v08al_with_authority "$BAD_METRIC_TRACE_DIR" >/dev/null
expect_summary_value "$SUMMARY_CSV" "trace_hash_verified_files" "6" "v08-al bad metric should have valid hashes"
expect_summary_value "$SUMMARY_CSV" "matched_query_rows" "7" "v08-al bad metric should keep query rows"
expect_summary_value "$SUMMARY_CSV" "metrics_match_rows" "4" "v08-al bad metric should mismatch one metric"
expect_summary_value "$SUMMARY_CSV" "codebase_run_evaluator_trace_ready" "0" "v08-al bad metric should block codebase trace"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-run-evaluator-trace-metric-mismatch" "v08-al bad metric action"

run_v08al_with_authority >/dev/null

echo "v08 external benchmark run/evaluator trace smoke passed"
