#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_nlg_transcript_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_nlg_transcript_smoke_decision.csv"
RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_runs/run_001"
TRANSCRIPT_PACKET_DIR="$RESULTS_DIR/v13_real_nlg_transcript_smoke_packet/run_001"
BAD_HASH_RUN_DIR="$RESULTS_DIR/v13_real_nlg_transcript_bad_hash_run"
BAD_GROUNDING_RUN_DIR="$RESULTS_DIR/v13_real_nlg_transcript_bad_grounding_run"

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
      if (!(field in idx)) die("missing v13-d summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-d summary row", 4)
    }
  ' "$summary_csv"
}

expect_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing expected v13-d file: $path" >&2
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

"$ROOT_DIR/experiments/run_v13_real_nlg_transcript.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_source" "generated-diagnostic-run" "v13-d source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-d run hash"
expect_summary_value "$SUMMARY_CSV" "store_hash_manifest_ready" "1" "v13-d store hash"
expect_summary_value "$SUMMARY_CSV" "packet_hash_manifest_ready" "1" "v13-d packet hash"
expect_summary_value "$SUMMARY_CSV" "evidence_packet_abi_ready" "1" "v13-d evidence packet"
expect_summary_value "$SUMMARY_CSV" "transcript_rows" "3" "v13-d transcript rows"
expect_summary_value "$SUMMARY_CSV" "transcript_json_valid" "1" "v13-d transcript json"
expect_summary_value "$SUMMARY_CSV" "result_json_valid" "1" "v13-d result json"
expect_summary_value "$SUMMARY_CSV" "route_index_rows" "3" "v13-d route rows"
expect_summary_value "$SUMMARY_CSV" "present_route_rows" "2" "v13-d present rows"
expect_summary_value "$SUMMARY_CSV" "missing_route_rows" "1" "v13-d missing rows"
expect_summary_value "$SUMMARY_CSV" "teacher_off_rows" "3" "v13-d teacher off"
expect_summary_value "$SUMMARY_CSV" "retrieved_chunk_matches" "3" "v13-d route chunk"
expect_summary_value "$SUMMARY_CSV" "evidence_span_matches" "3" "v13-d spans"
expect_summary_value "$SUMMARY_CSV" "span_byte_matches" "3" "v13-d bytes"
expect_summary_value "$SUMMARY_CSV" "answer_grounded_matches" "3" "v13-d grounded"
expect_summary_value "$SUMMARY_CSV" "citation_matches" "3" "v13-d citations"
expect_summary_value "$SUMMARY_CSV" "missing_abstain_matches" "1" "v13-d missing abstain"
expect_summary_value "$SUMMARY_CSV" "result_teacher_off" "1" "v13-d result teacher"
expect_summary_value "$SUMMARY_CSV" "result_retrieved_evidence_used" "1" "v13-d result retrieval"
expect_summary_value "$SUMMARY_CSV" "result_grounding_declared" "1" "v13-d result grounding"
expect_summary_value "$SUMMARY_CSV" "result_citation_declared" "1" "v13-d result citation"
expect_summary_value "$SUMMARY_CSV" "transcript_binding_rows" "3" "v13-d binding rows"
expect_summary_value "$SUMMARY_CSV" "transcript_binding_ready" "1" "v13-d binding"
expect_summary_value "$SUMMARY_CSV" "v13_real_nlg_transcript_ready" "1" "v13-d ready"
expect_summary_value "$SUMMARY_CSV" "real_nlg_transcript_ready" "0" "v13-d real NLG should block"
expect_summary_value "$SUMMARY_CSV" "actual_nonfixture_run_verified" "0" "v13-d nonfixture"
expect_summary_value "$SUMMARY_CSV" "real_pc_routelm_nlg_verified" "0" "v13-d real NLG flag"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v13-d real external"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-d real release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-nlg-transcript-bound-await-nonfixture-generator" "v13-d action"

expect_file "$TRANSCRIPT_PACKET_DIR/transcript_binding.csv"
expect_file "$TRANSCRIPT_PACKET_DIR/transcript_manifest.json"
expect_file "$TRANSCRIPT_PACKET_DIR/sha256sums.txt"

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
    if ($idx["route_index_match"] != "1") die("v13-d route index binding should pass", 20)
    if ($idx["span_byte_match"] != "1") die("v13-d span byte binding should pass", 21)
    if ($idx["answer_grounded"] != "1") die("v13-d answer grounding should pass", 22)
    if ($idx["citation_match"] != "1") die("v13-d citation should pass", 23)
  }
  END {
    if (rows != 3) die("expected three v13-d binding rows", 24)
  }
' "$TRANSCRIPT_PACKET_DIR/transcript_binding.csv"

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
    if ($idx["gate"] == "run-hash-manifest" && $idx["status"] != "pass") die("v13-d run hash should pass", 30)
    if ($idx["gate"] == "store-hash-manifest" && $idx["status"] != "pass") die("v13-d store hash should pass", 31)
    if ($idx["gate"] == "evidence-packet" && $idx["status"] != "pass") die("v13-d packet should pass", 32)
    if ($idx["gate"] == "transcript-json" && $idx["status"] != "pass") die("v13-d json should pass", 33)
    if ($idx["gate"] == "route-index-binding" && $idx["status"] != "pass") die("v13-d route binding should pass", 34)
    if ($idx["gate"] == "span-byte-binding" && $idx["status"] != "pass") die("v13-d span binding should pass", 35)
    if ($idx["gate"] == "grounded-answer" && $idx["status"] != "pass") die("v13-d grounded answer should pass", 36)
    if ($idx["gate"] == "result-summary" && $idx["status"] != "pass") die("v13-d result should pass", 37)
    if ($idx["gate"] == "transcript-packet-hash" && $idx["status"] != "pass") die("v13-d transcript hash should pass", 38)
    if ($idx["gate"] == "real-nlg-transcript" && $idx["status"] != "blocked") die("v13-d real NLG should block", 39)
    if ($idx["gate"] == "v13-real-nlg-transcript" && $idx["status"] != "pass") die("v13-d ABI should pass", 40)
  }
  END {
    if (rows != 11) die("expected v13-d decision rows", 41)
  }
' "$DECISION_CSV"

rm -rf "$BAD_HASH_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_HASH_RUN_DIR"
printf '\n{"query_id":"q_bad","route_key":"bad","retrieved_chunk_id":"bad","evidence_span":"bad","answer":"bad","citation":"bad","teacher_off_inference":true}\n' >>"$BAD_HASH_RUN_DIR/nlg/transcript.jsonl"
V13_REAL_NLG_TRANSCRIPT_RUN_DIR="$BAD_HASH_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_real_nlg_transcript.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-d bad-hash source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "0" "v13-d bad run hash"
expect_summary_value "$SUMMARY_CSV" "v13_real_nlg_transcript_ready" "0" "v13-d bad hash should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-nlg-transcript-run-hash-mismatch" "v13-d bad hash action"

rm -rf "$BAD_GROUNDING_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_GROUNDING_RUN_DIR"
awk '
  NR == 1 {
    sub(/"answer":"alpha_route"/, "\"answer\":\"wrong_answer\"")
  }
  { print }
' "$BAD_GROUNDING_RUN_DIR/nlg/transcript.jsonl" >"$BAD_GROUNDING_RUN_DIR/nlg/transcript.tmp"
mv "$BAD_GROUNDING_RUN_DIR/nlg/transcript.tmp" "$BAD_GROUNDING_RUN_DIR/nlg/transcript.jsonl"
rewrite_run_hash_manifest "$BAD_GROUNDING_RUN_DIR"
V13_REAL_NLG_TRANSCRIPT_RUN_DIR="$BAD_GROUNDING_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_real_nlg_transcript.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-d bad-grounding source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-d bad-grounding hash"
expect_summary_value "$SUMMARY_CSV" "answer_grounded_matches" "2" "v13-d bad-grounding count"
expect_summary_value "$SUMMARY_CSV" "transcript_binding_ready" "0" "v13-d bad-grounding binding"
expect_summary_value "$SUMMARY_CSV" "v13_real_nlg_transcript_ready" "0" "v13-d bad-grounding should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-nlg-answer-grounding-mismatch" "v13-d bad-grounding action"

"$ROOT_DIR/experiments/run_v13_real_nlg_transcript.sh" --smoke >/dev/null

echo "v13 real NLG transcript smoke passed"
