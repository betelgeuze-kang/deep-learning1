#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_codebase_mini.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_codebase_mini_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_codebase_mini_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_family artifact_source source_manifest_ready dataset_ready split_manifest_ready license_ready metric_spec_ready baseline_artifact_rows result_artifact_rows artifact_hash_manifest_entries artifact_hash_verified_files source_file_rows source_hash_verified_rows dataset_rows present_queries missing_queries near_miss_queries multi_hop_queries route_memory_artifact_chain_verified codebase_mini_source_ready benchmark_result_artifact_verified baseline_comparison_ready real_codebase_declared external_source_rows local_source_rows span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate duplicate_latest_rate retrieval_latency_ms query_to_first_token_ms ssd_bytes_per_query ram_used_gb vram_used_gb tokens_per_second_after_retrieval real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ab codebase-mini summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("v08-ab codebase-mini summary row has wrong column count", 3)
    if ($idx["benchmark_scope"] != "route-memory-v08ab" ||
        $idx["benchmark_family"] != "codebase-retrieval" ||
        $idx["artifact_source"] != "generated-local-codebase" ||
        ($idx["source_manifest_ready"] + 0) != 1 ||
        ($idx["dataset_ready"] + 0) != 1 ||
        ($idx["split_manifest_ready"] + 0) != 1 ||
        ($idx["license_ready"] + 0) != 1 ||
        ($idx["metric_spec_ready"] + 0) != 1 ||
        ($idx["baseline_artifact_rows"] + 0) != 3 ||
        ($idx["result_artifact_rows"] + 0) != 2 ||
        ($idx["artifact_hash_manifest_entries"] + 0) != 10 ||
        ($idx["artifact_hash_verified_files"] + 0) != 10 ||
        ($idx["source_file_rows"] + 0) != 4 ||
        ($idx["source_hash_verified_rows"] + 0) != 4 ||
        ($idx["dataset_rows"] + 0) != 7 ||
        ($idx["present_queries"] + 0) != 5 ||
        ($idx["missing_queries"] + 0) != 1 ||
        ($idx["near_miss_queries"] + 0) != 1 ||
        ($idx["multi_hop_queries"] + 0) != 1 ||
        ($idx["route_memory_artifact_chain_verified"] + 0) != 1 ||
        ($idx["codebase_mini_source_ready"] + 0) != 1 ||
        ($idx["benchmark_result_artifact_verified"] + 0) != 1 ||
        ($idx["baseline_comparison_ready"] + 0) != 1 ||
        ($idx["real_codebase_declared"] + 0) != 1 ||
        ($idx["external_source_rows"] + 0) != 0 ||
        ($idx["local_source_rows"] + 0) != 4 ||
        ($idx["span_exact"] + 0.0) != 1.0 ||
        ($idx["chunk_exact"] + 0.0) != 1.0 ||
        ($idx["missing_abstain"] + 0.0) != 1.0 ||
        ($idx["near_miss_false_positive"] + 0.0) != 0.0 ||
        ($idx["wrong_answer_rate"] + 0.0) != 0.0 ||
        ($idx["duplicate_latest_rate"] + 0.0) != 0.0 ||
        ($idx["retrieval_latency_ms"] + 0.0) <= 0.0 ||
        ($idx["query_to_first_token_ms"] + 0.0) != 0.0 ||
        ($idx["ssd_bytes_per_query"] + 0.0) <= 0.0 ||
        ($idx["ram_used_gb"] + 0.0) <= 0.0 ||
        ($idx["vram_used_gb"] + 0.0) != 0.0 ||
        ($idx["tokens_per_second_after_retrieval"] + 0.0) != 0.0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "codebase-mini-result-ready-await-review") {
      die("v08-ab codebase-mini should verify local codebase benchmark instrumentation only", 4)
    }
    if (($idx["routing_trigger_rate"] + 0.0) != 0.0 ||
        ($idx["active_jump_rate"] + 0.0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08-ab codebase-mini", 5)
    }
  }
  END {
    if (rows != 1) die("expected one v08-ab codebase-mini summary row", 6)
  }
' "$SUMMARY_CSV"

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
    if ($idx["gate"] == "route-memory-store" && $idx["status"] != "pass") die("route-memory store should pass", 20)
    if ($idx["gate"] == "artifact-files" && $idx["status"] != "pass") die("artifact files should pass", 21)
    if ($idx["gate"] == "artifact-hashes" && $idx["status"] != "pass") die("artifact hashes should pass", 22)
    if ($idx["gate"] == "codebase-source" && $idx["status"] != "pass") die("codebase source should pass", 23)
    if ($idx["gate"] == "dataset" && $idx["status"] != "pass") die("dataset should pass", 24)
    if ($idx["gate"] == "result-artifacts" && $idx["status"] != "pass") die("result artifacts should pass", 25)
    if ($idx["gate"] == "retrieval-quality" && $idx["status"] != "pass") die("retrieval quality should pass", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should stay blocked", 27)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("jump guardrail should pass", 28)
  }
  END {
    if (rows != 9) die("expected v08-ab codebase-mini decision rows", 29)
  }
' "$DECISION_CSV"

GOOD_DIR="$RESULTS_DIR/v08_external_benchmark_codebase_mini_smoke_artifacts/benchmarks/codebase-mini"
BAD_DIR="$RESULTS_DIR/v08_external_benchmark_codebase_mini_bad_hash_artifacts/benchmarks/codebase-mini"
rm -rf "$RESULTS_DIR/v08_external_benchmark_codebase_mini_bad_hash_artifacts"
mkdir -p "$(dirname "$BAD_DIR")"
cp -R "$GOOD_DIR" "$BAD_DIR"
printf '\n{"corrupt":"dataset-hash"}\n' >>"$BAD_DIR/dataset.jsonl"

V08_CODEBASE_MINI_ARTIFACT_DIR="$BAD_DIR" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_codebase_mini.sh" --smoke >/dev/null

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("artifact_source artifact_hash_manifest_entries artifact_hash_verified_files codebase_mini_source_ready benchmark_result_artifact_verified baseline_comparison_ready real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ab bad-hash summary column: " required[i], 30)
    }
    next
  }
  {
    rows++
    if ($idx["artifact_source"] != "provided-dir" ||
        ($idx["artifact_hash_manifest_entries"] + 0) != 10 ||
        ($idx["artifact_hash_verified_files"] + 0) != 9 ||
        ($idx["codebase_mini_source_ready"] + 0) != 1 ||
        ($idx["benchmark_result_artifact_verified"] + 0) != 0 ||
        ($idx["baseline_comparison_ready"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0 ||
        $idx["action"] != "codebase-mini-artifact-hash-mismatch") {
      die("v08-ab codebase-mini bad hash should block result artifact verification", 31)
    }
    if (($idx["routing_trigger_rate"] + 0.0) != 0.0 ||
        ($idx["active_jump_rate"] + 0.0) != 0.0) {
      die("jump-neighbor path must stay inactive for v08-ab bad hash", 32)
    }
  }
  END {
    if (rows != 1) die("expected one v08-ab bad-hash summary row", 33)
  }
' "$SUMMARY_CSV"

"$ROOT_DIR/experiments/run_v08_external_benchmark_codebase_mini.sh" --smoke >/dev/null

echo "v08 external benchmark codebase-mini smoke passed"
