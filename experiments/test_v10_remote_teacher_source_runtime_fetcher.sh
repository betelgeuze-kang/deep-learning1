#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

REMOTE_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_content_fixture.csv"
FETCH_ATTESTATION_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_style_fixture.csv"
RUNTIME_CSV="$RESULTS_DIR/v10_remote_teacher_source_runtime_fetcher_smoke_runtime_fetch.csv"
BAD_RUNTIME_CSV="$RESULTS_DIR/v10_remote_teacher_source_runtime_fetcher_bad_hash_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v10_remote_teacher_source_runtime_fetcher_malformed_fixture.csv"

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
      if (!(field in idx)) die("missing h10-p summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one h10-p summary row", 4)
    }
  ' "$summary_csv"
}

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_runtime_fetcher.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_remote_teacher_source_runtime_fetcher_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_remote_teacher_source_runtime_fetcher_smoke_decision.csv"

expect_summary_value "$SUMMARY_CSV" "teacher_source_runtime_scope" "route-memory-h10p" "default runtime scope"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_fetch_attestation_ready" "0" "default h10-o should block"
expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "0" "default runtime fetcher should block"
expect_summary_value "$SUMMARY_CSV" "live_network_fetch_ready" "0" "default live network fetch should block"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "default runtime fetcher must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-fetch-attestation-not-ready" "default runtime should block at h10-o"

"$ROOT_DIR/experiments/test_v10_remote_teacher_source_live_fetch_attestation.sh" >/dev/null

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_runtime_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_fetch_attestation_ready" "1" "h10-o remote-style attestation should pass"
expect_summary_value "$SUMMARY_CSV" "expected_runtime_artifact_rows" "6" "runtime fetcher should expect six artifacts"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_rows" "0" "runtime fetcher without replay should have no rows"
expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "0" "runtime fetcher without rows should block"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-runtime-fetch-missing" "h10-p should wait for runtime fetch evidence"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_REPLAY=1 \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_runtime_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "runtime_fetch_source" "runner-owned-replay" "runtime replay should be runner-owned"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_rows" "6" "runtime replay should produce six rows"
expect_summary_value "$SUMMARY_CSV" "matched_artifact_rows" "6" "runtime replay should match h10-o artifacts"
expect_summary_value "$SUMMARY_CSV" "download_cache_match_rows" "6" "runtime replay should reuse expected caches"
expect_summary_value "$SUMMARY_CSV" "download_hash_match_rows" "6" "runtime replay should match expected content hashes"
expect_summary_value "$SUMMARY_CSV" "download_cache_hash_verified_rows" "6" "runtime replay should verify download cache hashes"
expect_summary_value "$SUMMARY_CSV" "fetcher_metadata_rows" "6" "runtime replay should expose fetcher metadata"
expect_summary_value "$SUMMARY_CSV" "runner_owned_fetch_rows" "6" "runtime replay should mark runner-owned fetch rows"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_ready_rows" "6" "runtime replay should mark fetch rows ready"
expect_summary_value "$SUMMARY_CSV" "output_hash_verified_rows" "6" "runtime replay should verify output hashes"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "6" "runtime replay should identify offline replay rows"
expect_summary_value "$SUMMARY_CSV" "network_fetch_rows" "0" "runtime replay must not count as live network fetch"
expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "1" "runtime replay should satisfy runner-owned fetcher contract"
expect_summary_value "$SUMMARY_CSV" "live_network_fetch_ready" "0" "runtime replay should still block live network fetch"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "runtime replay must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-live-network-fetch-missing" "runtime replay should wait for live network fetch"

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
    if ($idx["gate"] == "live-fetch-attestation" && $idx["status"] != "pass") die("h10-p h10-o gate should pass", 20)
    if ($idx["gate"] == "runtime-fetch-rows" && $idx["status"] != "pass") die("h10-p runtime rows should pass", 21)
    if ($idx["gate"] == "runtime-content-hash" && $idx["status"] != "pass") die("h10-p runtime hash should pass", 22)
    if ($idx["gate"] == "fetcher-metadata" && $idx["status"] != "pass") die("h10-p fetcher metadata should pass", 23)
    if ($idx["gate"] == "runner-owned-fetch" && $idx["status"] != "pass") die("h10-p runner-owned fetch should pass", 24)
    if ($idx["gate"] == "runtime-fetch-contract" && $idx["status"] != "pass") die("h10-p runtime fetch contract should pass", 25)
    if ($idx["gate"] == "live-network-fetch" && $idx["status"] != "blocked") die("h10-p live network fetch should still block", 26)
    if ($idx["gate"] == "real-teacher-source-verification" && $idx["status"] != "blocked") die("h10-p real verification should still block", 27)
  }
  END {
    if (rows != 9) die("expected nine h10-p decision rows", 28)
  }
' "$DECISION_CSV"

{
  head -n 1 "$RUNTIME_CSV"
  sed -n '2p' "$RUNTIME_CSV" | awk -F, 'BEGIN { OFS="," } { $20 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"; print }'
  sed -n '3,$p' "$RUNTIME_CSV"
} >"$BAD_RUNTIME_CSV"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$BAD_RUNTIME_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_runtime_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "0" "bad runtime download hash should block runtime readiness"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-runtime-fetch-content-hash-mismatch" "bad runtime download hash should block at content hash"

{
  head -n 1 "$RUNTIME_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$RUNTIME_CSV")"
} >"$MALFORMED_CSV"

if V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
   V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
   V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
   V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v10_remote_teacher_source_runtime_fetcher.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h10-p should reject malformed runtime fetch CSV row widths" >&2
  exit 40
fi

echo "v10 remote teacher-source runtime fetcher smoke passed"
