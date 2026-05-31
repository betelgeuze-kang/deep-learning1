#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
REPLAY_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_verifier_gate_smoke_verifier.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
BAD_LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_live_review_fixture.csv"

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
      if (!(field in idx)) die("missing v08-p summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-p summary row", 4)
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
          print "missing v08-p verifier fixture column: " required[i] > "/dev/stderr"
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

make_live_review_csv() {
  local verifier_csv="$1"
  local review_csv="$2"

  awk -F, -v OFS=, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    function slugify(value, out) {
      out = tolower(value)
      gsub(/[^a-z0-9]+/, "-", out)
      gsub(/^-|-$/, "", out)
      return out
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id verifier_run_id verifier_binary_hash verifier_command_hash verifier_stdout_hash verifier_stderr_hash verified_import_manifest_hash verified_import_fetch_log_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-p review fixture source column: " required[i], 2)
      }
      print "benchmark_family,source_import_id,verifier_run_id,live_review_id,live_review_report_uri,live_review_report_hash,live_reviewer_identity_uri,live_reviewer_identity_hash,live_reviewer_conflict_disclosure_uri,live_reviewer_conflict_disclosure_hash,reviewed_verifier_binary_hash,reviewed_verifier_command_hash,reviewed_verifier_stdout_hash,reviewed_verifier_stderr_hash,reviewed_import_manifest_hash,reviewed_import_fetch_log_hash,reviewer_name,reviewer_org,reviewer_role,reviewer_independent,review_protocol_version,live_fetch_observed,network_isolation_review_ready,artifact_hash_review_ready,source_import_binding_review_ready,review_approved,real_live_review_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,live_review_report_hash_attested,live_reviewer_identity_hash_attested,live_reviewer_conflict_disclosure_hash_attested"
      next
    }
    {
      family_slug = slugify($idx["benchmark_family"])
      report_hash = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
      identity_hash = "sha256:2222222222222222222222222222222222222222222222222222222222222222"
      conflict_hash = "sha256:3333333333333333333333333333333333333333333333333333333333333333"
      print \
        $idx["benchmark_family"], \
        $idx["source_import_id"], \
        $idx["verifier_run_id"], \
        "live-review-" family_slug, \
        "https://benchmarks.example.invalid/v08/source-import/live-review/" family_slug ".json", \
        report_hash, \
        "https://benchmarks.example.invalid/v08/source-import/live-reviewer/" family_slug "-identity.json", \
        identity_hash, \
        "https://benchmarks.example.invalid/v08/source-import/live-reviewer/" family_slug "-conflict.json", \
        conflict_hash, \
        $idx["verifier_binary_hash"], \
        $idx["verifier_command_hash"], \
        $idx["verifier_stdout_hash"], \
        $idx["verifier_stderr_hash"], \
        $idx["verified_import_manifest_hash"], \
        $idx["verified_import_fetch_log_hash"], \
        "Independent Source Import Reviewer", \
        "External Benchmark Review Org", \
        "source-import-live-reviewer", \
        1, \
        "v08-source-import-live-review-v1", \
        1, \
        1, \
        1, \
        1, \
        1, \
        1, \
        0, \
        "0.000000", \
        "0.000000", \
        1, \
        1, \
        1
    }
  ' "$verifier_csv" >"$review_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08p" "default v08-p scope"
expect_summary_value "$SUMMARY_CSV" "source_import_live_verifier_ready" "0" "default v08-p should block before live verifier"
expect_summary_value "$SUMMARY_CSV" "source_import_independent_live_review_ready" "0" "default v08-p should not have independent live review"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-p must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-p must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-p action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_verifier_gate.sh" >/dev/null
rewrite_verifier_csv_flags "$REPLAY_VERIFIER_CSV" "$LIVE_VERIFIER_CSV" 1 0 1 0

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_live_verifier_ready" "1" "v08-p should see live verifier readiness"
expect_summary_value "$SUMMARY_CSV" "review_rows" "0" "v08-p should have no review rows before live review import"
expect_summary_value "$SUMMARY_CSV" "source_import_independent_live_review_ready" "0" "v08-p should block before independent live review"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-independent-live-review-missing" "v08-p should ask for live review"

make_live_review_csv "$LIVE_VERIFIER_CSV" "$LIVE_REVIEW_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "live_review_source" "provided-csv" "v08-p live review should be provided"
expect_summary_value "$SUMMARY_CSV" "review_rows" "4" "v08-p live review fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_verifier_rows" "4" "v08-p live review should bind verifier rows"
expect_summary_value "$SUMMARY_CSV" "verifier_hash_match_rows" "4" "v08-p live review should bind verifier hashes"
expect_summary_value "$SUMMARY_CSV" "import_hash_match_rows" "4" "v08-p live review should bind import hashes"
expect_summary_value "$SUMMARY_CSV" "local_live_review_artifact_rows" "0" "v08-p live review should be nonlocal"
expect_summary_value "$SUMMARY_CSV" "nonlocal_live_review_artifact_rows" "12" "v08-p live review should expose nonlocal review artifacts"
expect_summary_value "$SUMMARY_CSV" "source_import_independent_live_review_ready" "1" "v08-p live review fixture should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-p live review fixture must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-p live review fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-authoritative-live-review-missing" "v08-p should still require authoritative live review"

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
    if ($idx["gate"] == "source-import-live-verifier" && $idx["status"] != "pass") die("v08-p live verifier should pass", 20)
    if ($idx["gate"] == "live-review-rows" && $idx["status"] != "pass") die("v08-p live review rows should pass", 21)
    if ($idx["gate"] == "live-review-chain" && $idx["status"] != "pass") die("v08-p live review chain should pass", 22)
    if ($idx["gate"] == "live-review-artifact" && $idx["status"] != "pass") die("v08-p live review artifact should pass", 23)
    if ($idx["gate"] == "live-reviewer-identity" && $idx["status"] != "pass") die("v08-p live reviewer identity should pass", 24)
    if ($idx["gate"] == "live-reviewer-conflict" && $idx["status"] != "pass") die("v08-p live reviewer conflict should pass", 25)
    if ($idx["gate"] == "live-review-approval" && $idx["status"] != "pass") die("v08-p live review approval should pass", 26)
    if ($idx["gate"] == "source-import-independent-live-review" && $idx["status"] != "pass") die("v08-p independent live review should pass", 27)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-p source import verification should still block", 28)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-p real benchmark should block", 29)
  }
  END {
    if (rows != 10) die("expected ten v08-p decision rows", 30)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["reviewed_verifier_stdout_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$LIVE_REVIEW_CSV" >"$BAD_LIVE_REVIEW_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$BAD_LIVE_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_review_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_live_verifier_ready" "1" "v08-p bad review should preserve live verifier readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_independent_live_review_ready" "0" "v08-p bad review should block independent review"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-review-chain-mismatch" "v08-p bad review should block at chain mismatch"

echo "v08 external benchmark source import live review gate smoke passed"
