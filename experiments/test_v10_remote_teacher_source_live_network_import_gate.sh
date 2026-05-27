#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

REMOTE_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_content_fixture.csv"
FETCH_ATTESTATION_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_style_fixture.csv"
REPLAY_RUNTIME_CSV="$RESULTS_DIR/v10_remote_teacher_source_runtime_fetcher_smoke_runtime_fetch.csv"
LIVE_RUNTIME_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_network_import_gate_live_runtime_fixture.csv"
BAD_LIVE_RUNTIME_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_network_import_gate_bad_live_runtime_fixture.csv"

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
      if (!(field in idx)) die("missing h10-q summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one h10-q summary row", 4)
    }
  ' "$summary_csv"
}

rewrite_runtime_csv_flags() {
  local input_csv="$1"
  local output_csv="$2"
  local network_value="$3"
  local offline_value="$4"
  local real_value="$5"
  local fixture_value="$6"

  awk -F, -v OFS=, \
      -v network_value="$network_value" \
      -v offline_value="$offline_value" \
      -v real_value="$real_value" \
      -v fixture_value="$fixture_value" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("network_fetch_performed offline_replay_used real_runtime_fetch_declared fixture_or_synthetic_declared", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          print "missing h10-q runtime fixture column: " required[i] > "/dev/stderr"
          exit 2
        }
      }
      print
      next
    }
    {
      $idx["network_fetch_performed"] = network_value
      $idx["offline_replay_used"] = offline_value
      $idx["real_runtime_fetch_declared"] = real_value
      $idx["fixture_or_synthetic_declared"] = fixture_value
      print
    }
  ' "$input_csv" >"$output_csv"
}

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_network_import_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_network_import_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_network_import_gate_smoke_decision.csv"

expect_summary_value "$SUMMARY_CSV" "teacher_source_live_network_scope" "route-memory-h10q" "default live-network import scope"
expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "0" "default h10-q should block before runtime fetcher"
expect_summary_value "$SUMMARY_CSV" "live_network_fetch_ready" "0" "default h10-q should block live network fetch"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_network_import_ready" "0" "default h10-q must not import live network source"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "default h10-q must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-fetch-attestation-not-ready" "default h10-q should inherit h10-p blocker"

"$ROOT_DIR/experiments/test_v10_remote_teacher_source_runtime_fetcher.sh" >/dev/null

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_REPLAY=1 \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_network_import_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "runtime_fetch_source" "runner-owned-replay" "h10-q replay should preserve runtime source"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_rows" "6" "h10-q replay should have six runtime rows"
expect_summary_value "$SUMMARY_CSV" "network_fetch_rows" "0" "h10-q replay must not count as network fetch"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "6" "h10-q replay should expose replay rows"
expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "1" "h10-q replay should satisfy runner-owned runtime fetcher"
expect_summary_value "$SUMMARY_CSV" "live_network_fetch_ready" "0" "h10-q replay must still block live network fetch"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_network_import_ready" "0" "h10-q replay must not import live network source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-live-network-fetch-missing" "h10-q replay should block at live network fetch"

rewrite_runtime_csv_flags "$REPLAY_RUNTIME_CSV" "$LIVE_RUNTIME_CSV" 1 0 1 0

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$LIVE_RUNTIME_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_network_import_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "runtime_fetch_source" "provided-csv" "h10-q live fixture should be provided"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_rows" "6" "h10-q live fixture should have six rows"
expect_summary_value "$SUMMARY_CSV" "network_fetch_rows" "6" "h10-q live fixture should count network rows"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "0" "h10-q live fixture should not be replay"
expect_summary_value "$SUMMARY_CSV" "declared_real_rows" "6" "h10-q live fixture should carry real runtime declarations"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "6" "h10-q live fixture should carry non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "1" "h10-q live fixture should satisfy runner-owned runtime fetcher"
expect_summary_value "$SUMMARY_CSV" "live_network_fetch_ready" "1" "h10-q live fixture should satisfy live network fetch evidence"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_network_import_ready" "1" "h10-q live fixture should satisfy live network import"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "h10-q live fixture must still wait for real source import"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-real-source-import-missing" "h10-q live fixture should stop at real source import"

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
    if ($idx["gate"] == "runner-owned-runtime-fetcher" && $idx["status"] != "pass") die("h10-q runner-owned runtime fetcher should pass", 20)
    if ($idx["gate"] == "live-network-fetch" && $idx["status"] != "pass") die("h10-q live network fetch should pass", 21)
    if ($idx["gate"] == "live-network-import" && $idx["status"] != "pass") die("h10-q live network import should pass", 22)
    if ($idx["gate"] == "real-teacher-source-verification" && $idx["status"] != "blocked") die("h10-q real teacher source should still block", 23)
  }
  END {
    if (rows != 4) die("expected four h10-q decision rows", 24)
  }
' "$DECISION_CSV"

rewrite_runtime_csv_flags "$REPLAY_RUNTIME_CSV" "$BAD_LIVE_RUNTIME_CSV" 0 0 1 0

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$BAD_LIVE_RUNTIME_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_network_import_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "runner_owned_runtime_fetcher_ready" "1" "h10-q bad live fixture should still satisfy runtime fetcher mechanics"
expect_summary_value "$SUMMARY_CSV" "live_network_fetch_ready" "0" "h10-q bad live fixture should block live network fetch"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_network_import_ready" "0" "h10-q bad live fixture must not import live network source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-live-network-fetch-missing" "h10-q bad live fixture should block at live network fetch"

echo "v10 remote teacher-source live network import gate smoke passed"
