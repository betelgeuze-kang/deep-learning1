#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_public_codebase_routeqa_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_public_codebase_routeqa_smoke_decision.csv"
RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_runs/run_001"
ROUTEQA_PACKET_DIR="$RESULTS_DIR/v13_public_codebase_routeqa_smoke_packet/run_001"
BAD_HASH_RUN_DIR="$RESULTS_DIR/v13_public_codebase_routeqa_bad_hash_run"
BAD_EVAL_RUN_DIR="$RESULTS_DIR/v13_public_codebase_routeqa_bad_eval_run"

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
      if (!(field in idx)) die("missing v13-e summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-e summary row", 4)
    }
  ' "$summary_csv"
}

expect_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing expected v13-e file: $path" >&2
    exit 10
  fi
}

rewrite_hash_manifest() {
  local dir="$1"
  (
    cd "$dir"
    find . -type f ! -path './sha256sums.txt' -print | sort | while IFS= read -r file; do
      sha256sum "${file#./}"
    done
  ) >"$dir/sha256sums.txt"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_public_codebase_routeqa.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_source" "generated-diagnostic-run" "v13-e source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-e run hash"
expect_summary_value "$SUMMARY_CSV" "trace_hash_manifest_ready" "1" "v13-e trace hash"
expect_summary_value "$SUMMARY_CSV" "trace_required_found" "6" "v13-e trace files"
expect_summary_value "$SUMMARY_CSV" "package_hash_manifest_ready" "1" "v13-e package hash"
expect_summary_value "$SUMMARY_CSV" "package_required_found" "10" "v13-e package files"
expect_summary_value "$SUMMARY_CSV" "dataset_hash_match" "1" "v13-e dataset hash"
expect_summary_value "$SUMMARY_CSV" "result_hash_match" "1" "v13-e result hash"
expect_summary_value "$SUMMARY_CSV" "source_file_rows" "4" "v13-e source rows"
expect_summary_value "$SUMMARY_CSV" "source_hash_verified_rows" "4" "v13-e source hashes"
expect_summary_value "$SUMMARY_CSV" "local_source_rows" "4" "v13-e local source rows"
expect_summary_value "$SUMMARY_CSV" "external_source_rows" "0" "v13-e external source rows"
expect_summary_value "$SUMMARY_CSV" "dataset_rows" "7" "v13-e dataset rows"
expect_summary_value "$SUMMARY_CSV" "result_rows" "7" "v13-e result rows"
expect_summary_value "$SUMMARY_CSV" "query_trace_rows" "7" "v13-e query trace rows"
expect_summary_value "$SUMMARY_CSV" "evaluator_output_rows" "7" "v13-e evaluator rows"
expect_summary_value "$SUMMARY_CSV" "routeqa_rows" "7" "v13-e routeqa rows"
expect_summary_value "$SUMMARY_CSV" "query_id_matches" "1" "v13-e query IDs"
expect_summary_value "$SUMMARY_CSV" "routeqa_bound_rows" "7" "v13-e bound rows"
expect_summary_value "$SUMMARY_CSV" "present_like_rows" "5" "v13-e present-like rows"
expect_summary_value "$SUMMARY_CSV" "missing_rows" "1" "v13-e missing rows"
expect_summary_value "$SUMMARY_CSV" "near_miss_rows" "1" "v13-e near-miss rows"
expect_summary_value "$SUMMARY_CSV" "multi_hop_rows" "1" "v13-e multi-hop rows"
expect_summary_value "$SUMMARY_CSV" "dataset_bound_rows" "7" "v13-e dataset bound"
expect_summary_value "$SUMMARY_CSV" "result_bound_rows" "7" "v13-e result bound"
expect_summary_value "$SUMMARY_CSV" "runner_owned_evaluator_rows" "7" "v13-e runner evaluator"
expect_summary_value "$SUMMARY_CSV" "independent_evaluator_rows" "0" "v13-e independent evaluator"
expect_summary_value "$SUMMARY_CSV" "metric_rows" "5" "v13-e metric rows"
expect_summary_value "$SUMMARY_CSV" "metrics_match_rows" "5" "v13-e metric matches"
expect_summary_value "$SUMMARY_CSV" "package_metrics_match_rows" "5" "v13-e package metric matches"
expect_summary_value "$SUMMARY_CSV" "span_exact" "1.000000" "v13-e span exact"
expect_summary_value "$SUMMARY_CSV" "chunk_exact" "1.000000" "v13-e chunk exact"
expect_summary_value "$SUMMARY_CSV" "missing_abstain" "1.000000" "v13-e missing abstain"
expect_summary_value "$SUMMARY_CSV" "near_miss_false_positive" "0.000000" "v13-e near miss"
expect_summary_value "$SUMMARY_CSV" "wrong_answer_rate" "0.000000" "v13-e wrong answer"
expect_summary_value "$SUMMARY_CSV" "v08_codebase_trace_ready" "1" "v13-e v08 trace"
expect_summary_value "$SUMMARY_CSV" "v13_real_nlg_transcript_ready" "1" "v13-e v13-d chain"
expect_summary_value "$SUMMARY_CSV" "routeqa_packet_hash_ready" "1" "v13-e packet hash"
expect_summary_value "$SUMMARY_CSV" "public_codebase_routeqa_ready" "1" "v13-e ready"
expect_summary_value "$SUMMARY_CSV" "actual_nonfixture_run_verified" "0" "v13-e nonfixture"
expect_summary_value "$SUMMARY_CSV" "independent_external_routeqa_verified" "0" "v13-e independent external"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v13-e real external"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-e real release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-public-codebase-routeqa-ready-await-nonfixture-public-source" "v13-e action"

expect_file "$ROUTEQA_PACKET_DIR/routeqa_rows.csv"
expect_file "$ROUTEQA_PACKET_DIR/routeqa_manifest.json"
expect_file "$ROUTEQA_PACKET_DIR/sha256sums.txt"

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
    if ($idx["routeqa_bound"] != "1") die("v13-e routeqa row should bind", 20)
    if ($idx["runner_owned_evaluator"] != "1") die("v13-e runner evaluator should bind", 21)
    if ($idx["independent_evaluator"] != "0") die("v13-e independent evaluator should stay blocked", 22)
  }
  END {
    if (rows != 7) die("expected seven v13-e routeqa rows", 23)
  }
' "$ROUTEQA_PACKET_DIR/routeqa_rows.csv"

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
    if ($idx["gate"] == "run-hash-manifest" && $idx["status"] != "pass") die("v13-e run hash should pass", 30)
    if ($idx["gate"] == "trace-hash-manifest" && $idx["status"] != "pass") die("v13-e trace hash should pass", 31)
    if ($idx["gate"] == "package-hash-manifest" && $idx["status"] != "pass") die("v13-e package hash should pass", 32)
    if ($idx["gate"] == "source-binding" && $idx["status"] != "pass") die("v13-e source binding should pass", 33)
    if ($idx["gate"] == "query-id-binding" && $idx["status"] != "pass") die("v13-e query binding should pass", 34)
    if ($idx["gate"] == "evaluator-binding" && $idx["status"] != "pass") die("v13-e evaluator binding should pass", 35)
    if ($idx["gate"] == "metric-recompute" && $idx["status"] != "pass") die("v13-e metric recompute should pass", 36)
    if ($idx["gate"] == "independent-external-routeqa" && $idx["status"] != "blocked") die("v13-e independent external should block", 37)
    if ($idx["gate"] == "v13-public-codebase-routeqa" && $idx["status"] != "pass") die("v13-e final gate should pass", 38)
  }
  END {
    if (rows != 13) die("expected v13-e decision rows", 39)
  }
' "$DECISION_CSV"

rm -rf "$BAD_HASH_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_HASH_RUN_DIR"
printf '\nq_bad,present,1,1,1,0\n' >>"$BAD_HASH_RUN_DIR/benchmark/query_trace.csv"
V13_PUBLIC_CODEBASE_ROUTEQA_RUN_DIR="$BAD_HASH_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_public_codebase_routeqa.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-e bad-hash source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "0" "v13-e bad run hash"
expect_summary_value "$SUMMARY_CSV" "public_codebase_routeqa_ready" "0" "v13-e bad hash should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-public-codebase-routeqa-run-hash-mismatch" "v13-e bad hash action"

rm -rf "$BAD_EVAL_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_EVAL_RUN_DIR"
awk -F, 'BEGIN { OFS = "," }
  NR == 1 { print; next }
  NR == 2 { $8 = 1 }
  { print }
' "$BAD_EVAL_RUN_DIR/benchmark/evaluator_output.csv" >"$BAD_EVAL_RUN_DIR/benchmark/evaluator_output.tmp"
mv "$BAD_EVAL_RUN_DIR/benchmark/evaluator_output.tmp" "$BAD_EVAL_RUN_DIR/benchmark/evaluator_output.csv"
rewrite_hash_manifest "$BAD_EVAL_RUN_DIR/benchmark"
rewrite_hash_manifest "$BAD_EVAL_RUN_DIR"
V13_PUBLIC_CODEBASE_ROUTEQA_RUN_DIR="$BAD_EVAL_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_public_codebase_routeqa.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-e bad-eval source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-e bad-eval run hash"
expect_summary_value "$SUMMARY_CSV" "trace_hash_manifest_ready" "1" "v13-e bad-eval trace hash"
expect_summary_value "$SUMMARY_CSV" "routeqa_bound_rows" "6" "v13-e bad-eval bound rows"
expect_summary_value "$SUMMARY_CSV" "wrong_answer_rate" "0.142857" "v13-e bad-eval wrong rate"
expect_summary_value "$SUMMARY_CSV" "metrics_match_rows" "4" "v13-e bad-eval metric mismatch"
expect_summary_value "$SUMMARY_CSV" "public_codebase_routeqa_ready" "0" "v13-e bad-eval should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-public-codebase-routeqa-evaluator-mismatch" "v13-e bad-eval action"

"$ROOT_DIR/experiments/run_v13_public_codebase_routeqa.sh" --smoke >/dev/null

echo "v13 public codebase RouteQA smoke passed"
