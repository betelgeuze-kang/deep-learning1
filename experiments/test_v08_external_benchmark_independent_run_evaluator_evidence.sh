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
EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_fixture.csv"
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_bad_coverage_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_bad_placeholder_fixture.csv"
BAD_METRIC_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_bad_metric_fixture.csv"
BAD_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_bad_declaration_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_smoke_decision.csv"

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
      if (!(field in idx)) die("missing v08-am summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-am summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

write_evidence_header() {
  echo "benchmark_family,external_run_id,trace_manifest_uri,trace_manifest_hash,run_log_uri,run_log_hash,evaluator_output_uri,evaluator_output_hash,metric_report_uri,metric_report_hash,query_trace_uri,query_trace_hash,observer_identity_uri,observer_identity_hash,authority_packet_uri,authority_packet_hash,query_rows,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,trace_bound,evaluator_bound,metrics_bound,authority_bound,independent_evaluator_declared,official_metric_declared,all_queries_bound_declared,non_fixture_declared,fixture_or_synthetic_declared,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_evidence_row() {
  local csv="$1"
  local family="$2"
  local wrong_answer_rate="${3:-0.010000}"
  local observer_host="${4:-evidence.routebench.dev}"
  local independent_declared="${5:-1}"
  local active_jump="${6:-0.000000}"
  local run_id="run-${family}-20260603"
  local base="https://${observer_host}/benchmarks/${family}/${run_id}"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,64,0.900000,0.820000,0.920000,0.010000,%s,1,1,1,1,%s,1,1,1,0,2026-06-03T00:00:00Z,0.000000,%s\n' \
    "$family" \
    "$run_id" \
    "$base/trace_manifest.json" \
    "$(hash_for "$family-trace-manifest")" \
    "$base/run.log" \
    "$(hash_for "$family-run-log")" \
    "$base/evaluator_output.jsonl" \
    "$(hash_for "$family-evaluator-output")" \
    "$base/metric_report.json" \
    "$(hash_for "$family-metric-report")" \
    "$base/query_trace.jsonl" \
    "$(hash_for "$family-query-trace")" \
    "$base/observer_identity.json" \
    "$(hash_for "$family-observer-identity")" \
    "$base/authority_packet.json" \
    "$(hash_for "$family-authority-packet")" \
    "$wrong_answer_rate" \
    "$independent_declared" \
    "$active_jump" >>"$csv"
}

write_good_evidence_csv() {
  local csv="$1"

  write_evidence_header >"$csv"
  append_evidence_row "$csv" "RULER"
  append_evidence_row "$csv" "LongBench"
  append_evidence_row "$csv" "codebase-retrieval"
  append_evidence_row "$csv" "real-document-qa"
}

run_v08am_with_authority() {
  local evidence_csv="$1"

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
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_RUN_EVALUATOR_EVIDENCE_CSV="$evidence_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_independent_run_evaluator_evidence.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_independent_run_evaluator_evidence.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "evidence_source" "pending-csv" "default v08-am evidence source"
expect_summary_value "$SUMMARY_CSV" "upstream_codebase_run_evaluator_trace_ready" "1" "default v08-am upstream trace should pass"
expect_summary_value "$SUMMARY_CSV" "upstream_authority_promotion_evidence_ready" "0" "default v08-am authority should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready" "0" "default v08-am independent evidence should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-am must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-authority-promotion-evidence-not-ready" "default v08-am action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_authority_promotion_evidence.sh" >/dev/null
write_good_evidence_csv "$EVIDENCE_CSV"
run_v08am_with_authority "$EVIDENCE_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "evidence_source" "provided-csv" "v08-am evidence source"
expect_summary_value "$SUMMARY_CSV" "upstream_codebase_run_evaluator_trace_ready" "1" "v08-am upstream trace should pass"
expect_summary_value "$SUMMARY_CSV" "upstream_authority_promotion_evidence_ready" "1" "v08-am upstream authority should pass"
expect_summary_value "$SUMMARY_CSV" "evidence_rows" "4" "v08-am evidence rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "4" "v08-am expected family rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_family_rows" "0" "v08-am duplicate families"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-am family coverage"
expect_summary_value "$SUMMARY_CSV" "expected_external_families" "4" "v08-am expected families"
expect_summary_value "$SUMMARY_CSV" "required_evidence_uri_fields" "28" "v08-am required URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_evidence_uri_fields" "28" "v08-am HTTPS URI fields"
expect_summary_value "$SUMMARY_CSV" "local_evidence_uri_fields" "0" "v08-am local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_evidence_uri_fields" "28" "v08-am non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_evidence_hash_fields" "28" "v08-am required hash fields"
expect_summary_value "$SUMMARY_CSV" "evidence_hash_attested_fields" "28" "v08-am attested hash fields"
expect_summary_value "$SUMMARY_CSV" "total_query_rows" "256" "v08-am total query rows"
expect_summary_value "$SUMMARY_CSV" "min_query_rows_pass_rows" "4" "v08-am query rows pass"
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "4" "v08-am metric thresholds pass"
expect_summary_value "$SUMMARY_CSV" "trace_bound_rows" "4" "v08-am trace bindings"
expect_summary_value "$SUMMARY_CSV" "evaluator_bound_rows" "4" "v08-am evaluator bindings"
expect_summary_value "$SUMMARY_CSV" "metrics_bound_rows" "4" "v08-am metric bindings"
expect_summary_value "$SUMMARY_CSV" "authority_bound_rows" "4" "v08-am authority bindings"
expect_summary_value "$SUMMARY_CSV" "independent_evaluator_declared_rows" "4" "v08-am independent declarations"
expect_summary_value "$SUMMARY_CSV" "official_metric_declared_rows" "4" "v08-am official metric declarations"
expect_summary_value "$SUMMARY_CSV" "all_queries_bound_declared_rows" "4" "v08-am all-query declarations"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-am non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "4" "v08-am fixture-free declarations"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "4" "v08-am timestamps"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready" "1" "v08-am independent evidence should pass"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-am supplied mechanics must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "independent-run-evaluator-evidence-ready-await-live-replay-or-final-review" "v08-am good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-am routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-am jump should stay zero"

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
    if ($idx["gate"] == "upstream-run-evaluator-trace" && $idx["status"] != "pass") die("v08-am upstream trace should pass", 20)
    if ($idx["gate"] == "upstream-authority-promotion-evidence" && $idx["status"] != "pass") die("v08-am upstream authority should pass", 21)
    if ($idx["gate"] == "independent-family-coverage" && $idx["status"] != "pass") die("v08-am family coverage should pass", 22)
    if ($idx["gate"] == "independent-evidence-artifacts" && $idx["status"] != "pass") die("v08-am evidence artifacts should pass", 23)
    if ($idx["gate"] == "independent-query-volume" && $idx["status"] != "pass") die("v08-am query volume should pass", 24)
    if ($idx["gate"] == "independent-metric-thresholds" && $idx["status"] != "pass") die("v08-am metric thresholds should pass", 25)
    if ($idx["gate"] == "independent-proof-bindings" && $idx["status"] != "pass") die("v08-am proof bindings should pass", 26)
    if ($idx["gate"] == "independent-declarations" && $idx["status"] != "pass") die("v08-am declarations should pass", 27)
    if ($idx["gate"] == "external-benchmark-independent-run-evaluator-evidence" && $idx["status"] != "pass") die("v08-am independent evidence should pass", 28)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-am real external benchmark should remain blocked", 29)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-am jump guardrail should pass", 30)
  }
  END {
    if (rows != 11) die("expected v08-am decision rows", 31)
  }
' "$DECISION_CSV"

write_evidence_header >"$BAD_COVERAGE_CSV"
append_evidence_row "$BAD_COVERAGE_CSV" "RULER"
append_evidence_row "$BAD_COVERAGE_CSV" "LongBench"
append_evidence_row "$BAD_COVERAGE_CSV" "codebase-retrieval"
run_v08am_with_authority "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "evidence_rows" "3" "v08-am bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "3" "v08-am bad coverage family count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready" "0" "v08-am bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-run-evaluator-evidence-coverage-incomplete" "v08-am bad coverage action"

write_good_evidence_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $13 = "https://metrics.example.org/observer.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08am_with_authority "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_evidence_uri_fields" "27" "v08-am bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready" "0" "v08-am bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-run-evaluator-evidence-placeholder-artifact-uri" "v08-am bad placeholder action"

write_good_evidence_csv "$BAD_METRIC_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $22 = "0.500000" } { print }' \
  "$BAD_METRIC_CSV" >"$BAD_METRIC_CSV.tmp"
mv "$BAD_METRIC_CSV.tmp" "$BAD_METRIC_CSV"
run_v08am_with_authority "$BAD_METRIC_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "metric_threshold_pass_rows" "3" "v08-am bad metric count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready" "0" "v08-am bad metric should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-run-evaluator-evidence-quality-threshold-missing" "v08-am bad metric action"

write_good_evidence_csv "$BAD_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $27 = "0" } { print }' \
  "$BAD_DECLARATION_CSV" >"$BAD_DECLARATION_CSV.tmp"
mv "$BAD_DECLARATION_CSV.tmp" "$BAD_DECLARATION_CSV"
run_v08am_with_authority "$BAD_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "independent_evaluator_declared_rows" "3" "v08-am bad declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready" "0" "v08-am bad declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-run-evaluator-evidence-declaration-missing" "v08-am bad declaration action"

write_good_evidence_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $34 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08am_with_authority "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-am bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready" "0" "v08-am bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-independent-run-evaluator-evidence-jump-guardrail-violated" "v08-am bad jump action"

run_v08am_with_authority "$EVIDENCE_CSV" >/dev/null

echo "v08 external benchmark independent run/evaluator evidence smoke passed"
