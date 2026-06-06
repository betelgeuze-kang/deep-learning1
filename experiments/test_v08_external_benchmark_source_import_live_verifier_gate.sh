#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
REPLAY_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_verifier_gate_smoke_verifier.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
BAD_LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_live_verifier_fixture.csv"

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
      if (!(field in idx)) die("missing v08-o summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-o summary row", 4)
    }
  ' "$summary_csv"
}

rewrite_verifier_csv_flags() {
  local input_csv="$1"
  local output_csv="$2"
  local live_value="$3"
  local replay_value="$4"
  local real_value="$5"
  local fixture_value="$6"

  awk -F, -v OFS=, \
      -v live_value="$live_value" \
      -v replay_value="$replay_value" \
      -v real_value="$real_value" \
      -v fixture_value="$fixture_value" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("live_network_verifier_run offline_replay_used real_source_import_verifier_declared fixture_or_synthetic_declared", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          print "missing v08-o verifier fixture column: " required[i] > "/dev/stderr"
          exit 2
        }
      }
      print
      next
    }
    {
      $idx["live_network_verifier_run"] = live_value
      $idx["offline_replay_used"] = replay_value
      $idx["real_source_import_verifier_declared"] = real_value
      $idx["fixture_or_synthetic_declared"] = fixture_value
      print
    }
  ' "$input_csv" >"$output_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08o" "default v08-o scope"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "0" "default v08-o should block before verifier"
expect_summary_value "$SUMMARY_CSV" "source_import_live_verifier_ready" "0" "default v08-o should not have live verifier evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-o must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-o must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-o action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_verifier_gate.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_REPLAY=1 \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_verifier_source" "runner-owned-replay" "v08-o replay should preserve verifier source"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_rows" "4" "v08-o replay should have verifier rows"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "1" "v08-o replay should satisfy verifier mechanics"
expect_summary_value "$SUMMARY_CSV" "live_network_verifier_rows" "0" "v08-o replay must not count as live verifier"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "4" "v08-o replay should expose replay rows"
expect_summary_value "$SUMMARY_CSV" "source_import_live_verifier_ready" "0" "v08-o replay must block live verifier evidence"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-verifier-missing" "v08-o replay should ask for live verifier evidence"

rewrite_verifier_csv_flags "$REPLAY_VERIFIER_CSV" "$LIVE_VERIFIER_CSV" 1 0 1 0

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_verifier_source" "provided-csv" "v08-o live verifier should be provided"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_rows" "4" "v08-o live fixture should have verifier rows"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "1" "v08-o live fixture should satisfy verifier mechanics"
expect_summary_value "$SUMMARY_CSV" "live_network_verifier_rows" "4" "v08-o live fixture should expose live verifier rows"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "0" "v08-o live fixture must not be replay"
expect_summary_value "$SUMMARY_CSV" "declared_real_verifier_rows" "4" "v08-o live fixture should carry real declarations"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-o live fixture should carry non-fixture declarations"
expect_summary_value "$SUMMARY_CSV" "source_import_live_verifier_ready" "1" "v08-o live fixture should satisfy live verifier evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-o live fixture must still wait for independent live review"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-o live fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-independent-live-review-missing" "v08-o live fixture should stop at independent live review"

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
    if ($idx["gate"] == "source-import-verifier-contract" && $idx["status"] != "pass") die("v08-o verifier contract should pass", 20)
    if ($idx["gate"] == "live-network-verifier-evidence" && $idx["status"] != "pass") die("v08-o live verifier evidence should pass", 21)
    if ($idx["gate"] == "source-import-live-verifier" && $idx["status"] != "pass") die("v08-o live verifier should pass", 22)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-o source-import verification should block", 23)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-o real benchmark should block", 24)
  }
  END {
    if (rows != 5) die("expected five v08-o decision rows", 25)
  }
' "$DECISION_CSV"

rewrite_verifier_csv_flags "$REPLAY_VERIFIER_CSV" "$BAD_LIVE_VERIFIER_CSV" 0 0 1 0

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$BAD_LIVE_VERIFIER_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "1" "v08-o bad live fixture should still satisfy verifier mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_live_verifier_ready" "0" "v08-o bad live fixture should block live verifier"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-verifier-missing" "v08-o bad live fixture should block at live verifier"

echo "v08 external benchmark source import live verifier gate smoke passed"
