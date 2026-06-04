#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_evidence_packet_abi_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_evidence_packet_abi_smoke_decision.csv"
RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_runs/run_001"
PACKET_DIR="$RESULTS_DIR/v13_evidence_packet_abi_smoke_packet/run_001"
BAD_HASH_RUN_DIR="$RESULTS_DIR/v13_evidence_packet_abi_bad_hash_run"
BAD_MISSING_RUN_DIR="$RESULTS_DIR/v13_evidence_packet_abi_missing_artifact_run"

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
      if (!(field in idx)) die("missing v13-c summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-c summary row", 4)
    }
  ' "$summary_csv"
}

expect_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing expected v13-c file: $path" >&2
    exit 10
  fi
}

rewrite_run_hash_manifest() {
  local run_dir="$1"
  (
    cd "$run_dir"
    find . -type f ! -path './sha256sums.txt' -print | sort | while IFS= read -r file; do
      sha256sum "${file#./}"
    done
  ) >"$run_dir/sha256sums.txt"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_evidence_packet_abi.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_source" "generated-diagnostic-run" "v13-c source"
expect_summary_value "$SUMMARY_CSV" "required_artifact_rows" "22" "v13-c required rows"
expect_summary_value "$SUMMARY_CSV" "artifact_files_found" "22" "v13-c artifacts found"
expect_summary_value "$SUMMARY_CSV" "artifact_sha_ready" "1" "v13-c artifact sha"
expect_summary_value "$SUMMARY_CSV" "packet_rows" "22" "v13-c packet rows"
expect_summary_value "$SUMMARY_CSV" "claim_rows" "7" "v13-c claim rows"
expect_summary_value "$SUMMARY_CSV" "claim_refs_resolved" "7" "v13-c claim refs"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-c run hash"
expect_summary_value "$SUMMARY_CSV" "store_hash_manifest_ready" "1" "v13-c store hash"
expect_summary_value "$SUMMARY_CSV" "packet_hash_manifest_ready" "1" "v13-c packet hash"
expect_summary_value "$SUMMARY_CSV" "routelm_mmap_reader_ready" "1" "v13-c reader"
expect_summary_value "$SUMMARY_CSV" "diagnostic_store_read_claim_ready" "1" "v13-c store claim"
expect_summary_value "$SUMMARY_CSV" "diagnostic_nlg_claim_ready" "1" "v13-c nlg claim"
expect_summary_value "$SUMMARY_CSV" "diagnostic_external_trace_claim_ready" "1" "v13-c trace claim"
expect_summary_value "$SUMMARY_CSV" "diagnostic_workload_claim_ready" "1" "v13-c workload claim"
expect_summary_value "$SUMMARY_CSV" "learned_chunk_ranking_claim_ready" "0" "v13-c learned ranking stays blocked"
expect_summary_value "$SUMMARY_CSV" "v12_diagnostic_release_ready" "1" "v13-c v12 diagnostic"
expect_summary_value "$SUMMARY_CSV" "v12_real_release_ready" "0" "v13-c v12 real"
expect_summary_value "$SUMMARY_CSV" "claim_matrix_input_ready" "1" "v13-c claim matrix"
expect_summary_value "$SUMMARY_CSV" "evidence_packet_abi_ready" "1" "v13-c ABI"
expect_summary_value "$SUMMARY_CSV" "actual_nonfixture_run_verified" "0" "v13-c nonfixture"
expect_summary_value "$SUMMARY_CSV" "real_pc_routelm_artifact_verified" "0" "v13-c real artifact"
expect_summary_value "$SUMMARY_CSV" "real_pc_routelm_nlg_verified" "0" "v13-c real NLG"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v13-c real external"
expect_summary_value "$SUMMARY_CSV" "real_workload_speed_evidence_ready" "0" "v13-c real speed"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-c real release"
expect_summary_value "$SUMMARY_CSV" "gpu_speedup_claim" "deferred" "v13-c GPU claim"
expect_summary_value "$SUMMARY_CSV" "action" "v13-evidence-packet-ready-await-nonfixture-runner" "v13-c action"

expect_file "$PACKET_DIR/evidence_packet.csv"
expect_file "$PACKET_DIR/claim_matrix_input.csv"
expect_file "$PACKET_DIR/packet_manifest.json"
expect_file "$PACKET_DIR/sha256sums.txt"
expect_file "$PACKET_DIR/artifacts/v13b_reader_summary.csv"

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
    seen[$idx["source_id"]] = 1
    if ($idx["source_id"] == "h10s_scorer_eval_summary" && $idx["diagnostic_ready"] != "0") die("h10s scorer row should remain blocked", 20)
    if ($idx["source_id"] == "v13b_reader_summary" && $idx["diagnostic_ready"] != "1") die("reader row should be diagnostic-ready", 21)
    if ($idx["real_verified"] != "0") die("v13-c packet must not mark real evidence verified", 22)
  }
  END {
    if (rows != 22) die("expected 22 evidence packet rows", 23)
    split("run_manifest v13_run_manifest h11c_store_summary h11d_nlg_summary h9h_resource_summary v08_run_trace_summary h10s_scorer_eval_summary v12_claim_audit_input nlg_transcript nlg_result_summary speed_workload benchmark_runner_manifest benchmark_evaluator_manifest benchmark_query_trace benchmark_evaluator_output benchmark_metrics_recomputed store_manifest store_route_index store_page_table store_chunk_offsets store_chunk_pages v13b_reader_summary", required, " ")
    for (i in required) if (!(required[i] in seen)) die("missing packet source: " required[i], 24)
  }
' "$PACKET_DIR/evidence_packet.csv"

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
    if ($idx["claim_id"] == "learned_chunk_ranking_source_verified" && $idx["claim_state"] != "blocked") die("learned ranking claim should block", 30)
    if ($idx["claim_id"] == "gpu_speedup_claim" && $idx["claim_state"] != "deferred") die("GPU speedup should be deferred", 31)
  }
  END {
    if (rows != 7) die("expected seven v13-c claim rows", 32)
  }
' "$PACKET_DIR/claim_matrix_input.csv"

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
    if ($idx["gate"] == "run-hash-manifest" && $idx["status"] != "pass") die("v13-c run hash should pass", 40)
    if ($idx["gate"] == "store-hash-manifest" && $idx["status"] != "pass") die("v13-c store hash should pass", 41)
    if ($idx["gate"] == "artifact-rows" && $idx["status"] != "pass") die("v13-c artifacts should pass", 42)
    if ($idx["gate"] == "packet-hash-manifest" && $idx["status"] != "pass") die("v13-c packet hash should pass", 43)
    if ($idx["gate"] == "routelm-mmap-reader" && $idx["status"] != "pass") die("v13-c reader should pass", 44)
    if ($idx["gate"] == "claim-matrix-input" && $idx["status"] != "pass") die("v13-c matrix should pass", 45)
    if ($idx["gate"] == "diagnostic-claims" && $idx["status"] != "pass") die("v13-c diagnostic claims should pass", 46)
    if ($idx["gate"] == "learned-ranking-claim" && $idx["status"] != "blocked") die("v13-c learned ranking should block", 47)
    if ($idx["gate"] == "real-run-claims" && $idx["status"] != "blocked") die("v13-c real claims should block", 48)
    if ($idx["gate"] == "evidence-packet-abi" && $idx["status"] != "pass") die("v13-c ABI should pass", 49)
  }
  END {
    if (rows != 10) die("expected v13-c decision rows", 50)
  }
' "$DECISION_CSV"

rm -rf "$BAD_HASH_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_HASH_RUN_DIR"
printf '\ncorrupt-after-run-hash\n' >>"$BAD_HASH_RUN_DIR/evidence/h11d.csv"
V13_EVIDENCE_PACKET_RUN_DIR="$BAD_HASH_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_evidence_packet_abi.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-c bad-hash source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "0" "v13-c bad run hash"
expect_summary_value "$SUMMARY_CSV" "evidence_packet_abi_ready" "0" "v13-c bad hash should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-evidence-packet-run-hash-mismatch" "v13-c bad hash action"

rm -rf "$BAD_MISSING_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_MISSING_RUN_DIR"
rm "$BAD_MISSING_RUN_DIR/evidence/h11d.csv"
rewrite_run_hash_manifest "$BAD_MISSING_RUN_DIR"
V13_EVIDENCE_PACKET_RUN_DIR="$BAD_MISSING_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_evidence_packet_abi.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-c missing source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-c missing run hash"
expect_summary_value "$SUMMARY_CSV" "artifact_files_found" "21" "v13-c missing artifact count"
expect_summary_value "$SUMMARY_CSV" "artifact_sha_ready" "0" "v13-c missing artifact sha"
expect_summary_value "$SUMMARY_CSV" "evidence_packet_abi_ready" "0" "v13-c missing should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-evidence-packet-required-artifact-missing" "v13-c missing action"

"$ROOT_DIR/experiments/run_v13_evidence_packet_abi.sh" --smoke >/dev/null

echo "v13 evidence packet ABI smoke passed"
