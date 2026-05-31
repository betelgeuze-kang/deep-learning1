#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_verifier_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_verifier_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
REPLAY_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_verifier_gate_smoke_verifier.csv"
BAD_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_verifier_bad_manifest_fixture.csv"

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
      if (!(field in idx)) die("missing v08-n summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-n summary row", 4)
    }
  ' "$summary_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08n" "default v08-n scope"
expect_summary_value "$SUMMARY_CSV" "source_import_contract_ready" "0" "default v08-n should block before source-import contract"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_rows" "0" "default v08-n should have no verifier rows"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "0" "default v08-n verifier must not be ready"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-n must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-n must not verify real benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-n action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_remote_contract.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_contract_ready" "1" "v08-n should see the v08-m source-import contract"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_source" "pending-fixture" "v08-n without verifier evidence should stay pending"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_rows" "0" "v08-n should require verifier rows"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "0" "v08-n without verifier rows should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-verifier-missing" "v08-n should ask for verifier evidence"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_REPLAY=1 \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_verifier_source" "runner-owned-replay" "v08-n replay should be runner-owned"
expect_summary_value "$SUMMARY_CSV" "expected_verifier_rows" "4" "v08-n replay should expect four verifier rows"
expect_summary_value "$SUMMARY_CSV" "expected_verifier_artifacts" "12" "v08-n replay should expect three artifacts per row"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_rows" "4" "v08-n replay should produce four rows"
expect_summary_value "$SUMMARY_CSV" "matched_source_import_rows" "4" "v08-n replay should match source-import rows"
expect_summary_value "$SUMMARY_CSV" "source_import_id_match_rows" "4" "v08-n replay should match source-import ids"
expect_summary_value "$SUMMARY_CSV" "import_manifest_uri_match_rows" "4" "v08-n replay should bind manifest URIs"
expect_summary_value "$SUMMARY_CSV" "import_manifest_hash_match_rows" "4" "v08-n replay should bind manifest hashes"
expect_summary_value "$SUMMARY_CSV" "import_fetch_log_uri_match_rows" "4" "v08-n replay should bind fetch-log URIs"
expect_summary_value "$SUMMARY_CSV" "import_fetch_log_hash_match_rows" "4" "v08-n replay should bind fetch-log hashes"
expect_summary_value "$SUMMARY_CSV" "reviewer_identity_uri_match_rows" "4" "v08-n replay should bind reviewer URIs"
expect_summary_value "$SUMMARY_CSV" "reviewer_identity_hash_match_rows" "4" "v08-n replay should bind reviewer hashes"
expect_summary_value "$SUMMARY_CSV" "benchmark_artifact_uri_match_rows" "4" "v08-n replay should bind benchmark artifacts"
expect_summary_value "$SUMMARY_CSV" "verifier_artifact_rows" "12" "v08-n replay should expose verifier artifacts"
expect_summary_value "$SUMMARY_CSV" "verifier_hash_verified_rows" "12" "v08-n replay should verify verifier artifact hashes"
expect_summary_value "$SUMMARY_CSV" "local_verifier_artifact_rows" "12" "v08-n replay artifacts are local mechanics"
expect_summary_value "$SUMMARY_CSV" "nonlocal_verifier_artifact_rows" "0" "v08-n replay should not fake nonlocal verifier artifacts"
expect_summary_value "$SUMMARY_CSV" "verifier_metadata_rows" "4" "v08-n replay should expose verifier metadata"
expect_summary_value "$SUMMARY_CSV" "runner_owned_verifier_rows" "4" "v08-n replay should be runner-owned"
expect_summary_value "$SUMMARY_CSV" "verifier_ready_rows" "4" "v08-n replay should mark verifier rows ready"
expect_summary_value "$SUMMARY_CSV" "verifier_output_hash_verified_rows" "4" "v08-n replay should verify output hashes"
expect_summary_value "$SUMMARY_CSV" "live_network_verifier_rows" "0" "v08-n replay must not count as live network verification"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "4" "v08-n replay should expose replay rows"
expect_summary_value "$SUMMARY_CSV" "declared_real_verifier_rows" "0" "v08-n replay must not declare real verifier rows"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "0" "v08-n replay must remain fixture-declared"
expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "1" "v08-n replay should satisfy verifier mechanics"
expect_summary_value "$SUMMARY_CSV" "live_network_source_import_verified" "0" "v08-n replay must not verify live network source import"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-n replay must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-n replay must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-verifier-missing" "v08-n replay should stop at live verifier"

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
    if ($idx["gate"] == "source-import-contract" && $idx["status"] != "pass") die("v08-n source-import contract should pass", 20)
    if ($idx["gate"] == "verifier-rows" && $idx["status"] != "pass") die("v08-n verifier rows should pass", 21)
    if ($idx["gate"] == "source-import-binding" && $idx["status"] != "pass") die("v08-n source-import binding should pass", 22)
    if ($idx["gate"] == "verifier-artifact-hash" && $idx["status"] != "pass") die("v08-n verifier artifact hash should pass", 23)
    if ($idx["gate"] == "source-import-verifier-contract" && $idx["status"] != "pass") die("v08-n verifier contract should pass", 24)
    if ($idx["gate"] == "live-network-verifier" && $idx["status"] != "blocked") die("v08-n live network verifier should block", 25)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-n source-import verification should block", 26)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-n real benchmark should block", 27)
  }
  END {
    if (rows != 14) die("expected fourteen v08-n decision rows", 28)
  }
' "$DECISION_CSV"

{
  head -n 1 "$REPLAY_VERIFIER_CSV"
  sed -n '2p' "$REPLAY_VERIFIER_CSV" | awk -F, 'BEGIN { OFS="," } { $13 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"; print }'
  sed -n '3,$p' "$REPLAY_VERIFIER_CSV"
} >"$BAD_VERIFIER_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$BAD_VERIFIER_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_verifier_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_verifier_ready" "0" "bad v08-n manifest hash should block verifier readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-verifier-chain-mismatch" "bad v08-n manifest hash should block at chain mismatch"

echo "v08 external benchmark source import verifier gate smoke passed"
