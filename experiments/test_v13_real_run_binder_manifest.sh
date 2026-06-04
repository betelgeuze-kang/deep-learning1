#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_decision.csv"
RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_runs/run_001"
BAD_RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_bad_hash_run"

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
      if (!(field in idx)) die("missing v13-a summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-a summary row", 4)
    }
  ' "$summary_csv"
}

expect_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing expected v13-a file: $path" >&2
    exit 5
  fi
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_run_binder_manifest.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_source" "generated-diagnostic-run" "v13-a source"
expect_summary_value "$SUMMARY_CSV" "store_files" "8" "v13-a store files"
expect_summary_value "$SUMMARY_CSV" "nlg_files" "2" "v13-a nlg files"
expect_summary_value "$SUMMARY_CSV" "benchmark_files" "7" "v13-a benchmark files"
expect_summary_value "$SUMMARY_CSV" "speed_files" "1" "v13-a speed files"
expect_summary_value "$SUMMARY_CSV" "evidence_files" "7" "v13-a evidence files"
expect_summary_value "$SUMMARY_CSV" "required_sections_ready" "1" "v13-a sections ready"
expect_summary_value "$SUMMARY_CSV" "hash_manifest_ready" "1" "v13-a hash manifest"
expect_summary_value "$SUMMARY_CSV" "h11c_ready" "1" "v13-a h11c ready"
expect_summary_value "$SUMMARY_CSV" "h11d_ready" "1" "v13-a h11d ready"
expect_summary_value "$SUMMARY_CSV" "h9h_ready" "1" "v13-a h9h ready"
expect_summary_value "$SUMMARY_CSV" "v08_trace_ready" "1" "v13-a v08 trace ready"
expect_summary_value "$SUMMARY_CSV" "h10s_student_eval_ready" "0" "v13-a h10s student eval should stay unresolved without supplied eval"
expect_summary_value "$SUMMARY_CSV" "h10s_source_verified_eval_ready" "0" "v13-a source-verified eval should stay blocked"
expect_summary_value "$SUMMARY_CSV" "v12_diagnostic_release_ready" "1" "v13-a v12 diagnostic"
expect_summary_value "$SUMMARY_CSV" "v12_real_release_ready" "0" "v13-a v12 real release should stay blocked"
expect_summary_value "$SUMMARY_CSV" "real_run_binder_manifest_ready" "1" "v13-a manifest ready"
expect_summary_value "$SUMMARY_CSV" "actual_nonfixture_run_verified" "0" "v13-a must not verify actual nonfixture run"
expect_summary_value "$SUMMARY_CSV" "real_pc_routelm_nlg_verified" "0" "v13-a must not verify real NLG"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v13-a must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "real_workload_speed_evidence_ready" "0" "v13-a must not verify speed evidence"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-a must not verify real release"
expect_summary_value "$SUMMARY_CSV" "gpu_speedup_claim" "deferred" "v13-a GPU claim"
expect_summary_value "$SUMMARY_CSV" "action" "real-run-binder-manifest-ready-await-nonfixture-runner" "v13-a action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-a routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-a jump"

expect_file "$RUN_DIR/run_manifest.json"
expect_file "$RUN_DIR/sha256sums.txt"
expect_file "$RUN_DIR/store/route_memory_store.bin"
expect_file "$RUN_DIR/nlg/transcript.jsonl"
expect_file "$RUN_DIR/nlg/result_summary.json"
expect_file "$RUN_DIR/benchmark/query_trace.csv"
expect_file "$RUN_DIR/speed/workload.csv"
expect_file "$RUN_DIR/evidence/v13_run_manifest.csv"
expect_file "$RUN_DIR/evidence/h11c.csv"
expect_file "$RUN_DIR/evidence/h11d.csv"
expect_file "$RUN_DIR/evidence/h9h.csv"
expect_file "$RUN_DIR/evidence/v08_run.csv"
expect_file "$RUN_DIR/evidence/h10s.csv"
expect_file "$RUN_DIR/evidence/v12_input.csv"

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
    if ($idx["gate"] == "run-directory-sections" && $idx["status"] != "pass") die("v13-a sections should pass", 20)
    if ($idx["gate"] == "run-directory-hash-manifest" && $idx["status"] != "pass") die("v13-a hash should pass", 21)
    if ($idx["gate"] == "upstream-diagnostic-inputs" && $idx["status"] != "pass") die("v13-a upstream should pass", 22)
    if ($idx["gate"] == "real-run-binder-manifest" && $idx["status"] != "pass") die("v13-a manifest should pass", 23)
    if ($idx["gate"] == "real-run-claims" && $idx["status"] != "blocked") die("v13-a claims should stay blocked", 24)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v13-a jump guardrail should pass", 25)
  }
  END {
    if (rows != 6) die("expected v13-a decision rows", 26)
  }
' "$DECISION_CSV"

rm -rf "$BAD_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_RUN_DIR"
printf '\ncorrupt-after-hash\n' >>"$BAD_RUN_DIR/run_manifest.json"
V13_REAL_RUN_BINDER_RUN_DIR="$BAD_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_real_run_binder_manifest.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-a provided source"
expect_summary_value "$SUMMARY_CSV" "hash_manifest_ready" "0" "v13-a bad hash manifest"
expect_summary_value "$SUMMARY_CSV" "real_run_binder_manifest_ready" "0" "v13-a bad hash should block"
expect_summary_value "$SUMMARY_CSV" "action" "real-run-binder-hash-manifest-mismatch" "v13-a bad hash action"

"$ROOT_DIR/experiments/run_v13_real_run_binder_manifest.sh" --smoke >/dev/null

echo "v13 real run binder manifest smoke passed"
