#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_routelm_mmap_reader_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_routelm_mmap_reader_smoke_decision.csv"
RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_runs/run_001"
BAD_HASH_RUN_DIR="$RESULTS_DIR/v13_routelm_mmap_reader_bad_hash_run"
BAD_SPAN_RUN_DIR="$RESULTS_DIR/v13_routelm_mmap_reader_bad_span_run"

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
      if (!(field in idx)) die("missing v13-b summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-b summary row", 4)
    }
  ' "$summary_csv"
}

rewrite_store_hash_manifest() {
  local store_dir="$1"
  (
    cd "$store_dir"
    sha256sum \
      route_memory_store.bin \
      route_index.bin \
      chunk_pages.bin \
      chunk_offsets.bin \
      chunk_credit.bin \
      page_table.bin \
      manifest.json >sha256sums.txt
  )
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

"$ROOT_DIR/experiments/run_v13_routelm_mmap_reader.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_source" "generated-diagnostic-run" "v13-b source"
expect_summary_value "$SUMMARY_CSV" "store_files_found" "7" "v13-b store files"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-b run hash"
expect_summary_value "$SUMMARY_CSV" "store_hash_manifest_ready" "1" "v13-b store hash"
expect_summary_value "$SUMMARY_CSV" "manifest_page_size_bytes" "96" "v13-b page size"
expect_summary_value "$SUMMARY_CSV" "page_table_rows" "4" "v13-b page rows"
expect_summary_value "$SUMMARY_CSV" "page_table_contiguous" "1" "v13-b page table"
expect_summary_value "$SUMMARY_CSV" "route_index_rows" "3" "v13-b route rows"
expect_summary_value "$SUMMARY_CSV" "present_query_rows" "2" "v13-b present rows"
expect_summary_value "$SUMMARY_CSV" "missing_query_rows" "1" "v13-b missing rows"
expect_summary_value "$SUMMARY_CSV" "mmap_opened" "1" "v13-b mmap open"
expect_summary_value "$SUMMARY_CSV" "mmap_span_reads" "2" "v13-b span reads"
expect_summary_value "$SUMMARY_CSV" "mmap_page_reads" "2" "v13-b page reads"
expect_summary_value "$SUMMARY_CSV" "span_matches" "2" "v13-b span matches"
expect_summary_value "$SUMMARY_CSV" "span_mismatches" "0" "v13-b span mismatches"
expect_summary_value "$SUMMARY_CSV" "chunk_offset_matches" "2" "v13-b chunk offsets"
expect_summary_value "$SUMMARY_CSV" "route_key_matches" "2" "v13-b route key matches"
expect_summary_value "$SUMMARY_CSV" "missing_abstain_matches" "1" "v13-b missing abstain"
expect_summary_value "$SUMMARY_CSV" "byte_window_matches" "2" "v13-b byte windows"
expect_summary_value "$SUMMARY_CSV" "mmap_reader_ready" "1" "v13-b mmap reader"
expect_summary_value "$SUMMARY_CSV" "routelm_mmap_reader_ready" "1" "v13-b ready"
expect_summary_value "$SUMMARY_CSV" "actual_nonfixture_run_verified" "0" "v13-b nonfixture"
expect_summary_value "$SUMMARY_CSV" "real_pc_routelm_artifact_verified" "0" "v13-b real artifact"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v13-b real external"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-b real release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-routelm-mmap-reader-ready-await-nonfixture-runner" "v13-b action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-b routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-b jump"

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
    if ($idx["gate"] == "store-files" && $idx["status"] != "pass") die("v13-b store files should pass", 20)
    if ($idx["gate"] == "run-hash-manifest" && $idx["status"] != "pass") die("v13-b run hash should pass", 21)
    if ($idx["gate"] == "store-hash-manifest" && $idx["status"] != "pass") die("v13-b store hash should pass", 22)
    if ($idx["gate"] == "mmap-open" && $idx["status"] != "pass") die("v13-b mmap open should pass", 23)
    if ($idx["gate"] == "mmap-span-read" && $idx["status"] != "pass") die("v13-b mmap span should pass", 24)
    if ($idx["gate"] == "route-index" && $idx["status"] != "pass") die("v13-b route index should pass", 25)
    if ($idx["gate"] == "routelm-mmap-reader" && $idx["status"] != "pass") die("v13-b reader should pass", 26)
    if ($idx["gate"] == "real-run-claims" && $idx["status"] != "blocked") die("v13-b real claims should block", 27)
  }
  END {
    if (rows != 8) die("expected v13-b decision rows", 28)
  }
' "$DECISION_CSV"

rm -rf "$BAD_HASH_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_HASH_RUN_DIR"
printf '\ncorrupt-after-run-hash\n' >>"$BAD_HASH_RUN_DIR/store/chunk_pages.bin"
V13_ROUTELM_MMAP_READER_RUN_DIR="$BAD_HASH_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_routelm_mmap_reader.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-b bad-hash source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "0" "v13-b bad run hash"
expect_summary_value "$SUMMARY_CSV" "routelm_mmap_reader_ready" "0" "v13-b bad hash should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-routelm-run-hash-mismatch" "v13-b bad hash action"

rm -rf "$BAD_SPAN_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_SPAN_RUN_DIR"
awk -F, 'BEGIN { OFS = "," } NR == 1 { print; next } $1 == "q_symbol_alpha" { $7 = "wrong_span!" } { print }' \
  "$BAD_SPAN_RUN_DIR/store/route_index.bin" >"$BAD_SPAN_RUN_DIR/store/route_index.tmp"
mv "$BAD_SPAN_RUN_DIR/store/route_index.tmp" "$BAD_SPAN_RUN_DIR/store/route_index.bin"
rewrite_store_hash_manifest "$BAD_SPAN_RUN_DIR/store"
rewrite_run_hash_manifest "$BAD_SPAN_RUN_DIR"
V13_ROUTELM_MMAP_READER_RUN_DIR="$BAD_SPAN_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_routelm_mmap_reader.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-b bad-span source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-b bad-span run hash"
expect_summary_value "$SUMMARY_CSV" "store_hash_manifest_ready" "1" "v13-b bad-span store hash"
expect_summary_value "$SUMMARY_CSV" "span_matches" "1" "v13-b bad-span matches"
expect_summary_value "$SUMMARY_CSV" "span_mismatches" "1" "v13-b bad-span mismatches"
expect_summary_value "$SUMMARY_CSV" "routelm_mmap_reader_ready" "0" "v13-b bad span should block"
expect_summary_value "$SUMMARY_CSV" "action" "v13-routelm-mmap-span-mismatch" "v13-b bad span action"

"$ROOT_DIR/experiments/run_v13_routelm_mmap_reader.sh" --smoke >/dev/null

echo "v13 RouteLM mmap reader smoke passed"
