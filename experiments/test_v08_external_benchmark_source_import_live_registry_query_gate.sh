#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_query_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_query_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_fixture.csv"
PUBLIC_REGISTRY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_public_registry_fixture.csv"
LIVE_REGISTRY_QUERY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_query_fixture.csv"
BAD_LIVE_REGISTRY_QUERY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_bad_live_registry_query_fixture.csv"

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
      if (!(field in idx)) die("missing v08-s summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-s summary row", 4)
    }
  ' "$summary_csv"
}

sha_text_uri() {
  local text="$1"
  printf 'sha256:%s\n' "$(printf '%s' "$text" | sha256sum | awk '{print $1}')"
}

sha_file_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

make_live_registry_query_csv() {
  local public_registry_csv="$1"
  local live_registry_query_csv="$2"
  local runner_script="$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh"
  local script_uri="file://$runner_script"
  local script_hash

  script_hash="$(sha_file_uri "$runner_script")"
  {
    echo "benchmark_family,source_import_id,authority_review_id,registry_entry_id,public_registry_uri,public_registry_hash,registry_entry_uri,registry_entry_hash,live_registry_query_id,query_runner_id,query_tool_uri,query_tool_hash,query_command_hash,query_started_at_utc,query_completed_at_utc,http_status,registry_response_uri,registry_response_hash,registry_entry_response_uri,registry_entry_response_hash,registry_lookup_hash,stdout_hash,stderr_hash,network_query_performed,offline_replay_used,runner_owned_query,query_output_hash_verified,real_live_query_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    awk -F, '
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
        header_fields = NF
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08-s live registry query fixture source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-s live registry query fixture source row has wrong column count", 3)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["authority_review_id"],
          $idx["registry_entry_id"],
          $idx["public_registry_uri"],
          $idx["public_registry_hash"],
          $idx["registry_entry_uri"],
          $idx["registry_entry_hash"],
          slugify($idx["benchmark_family"])
      }
    ' "$public_registry_csv" |
    while IFS=$'\t' read -r benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash family_slug; do
      query_id="live-registry-query-${family_slug}"
      runner_id="betelgeuze-live-registry-query-v1"
      command_hash="$(sha_text_uri "GET ${public_registry_uri} ${registry_entry_uri} ${source_import_id}")"
      lookup_hash="$(sha_text_uri "${benchmark_family}|${source_import_id}|${authority_review_id}|${registry_entry_id}")"
      stdout_hash="$(sha_text_uri "${benchmark_family}|${public_registry_hash}|${registry_entry_hash}")"
      stderr_hash="$(sha_text_uri "")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-05-31T00:00:00Z,2026-05-31T00:00:01Z,200,%s,%s,%s,%s,%s,%s,%s,1,0,1,1,1,0,0,0\n" \
        "$benchmark_family" \
        "$source_import_id" \
        "$authority_review_id" \
        "$registry_entry_id" \
        "$public_registry_uri" \
        "$public_registry_hash" \
        "$registry_entry_uri" \
        "$registry_entry_hash" \
        "$query_id" \
        "$runner_id" \
        "$script_uri" \
        "$script_hash" \
        "$command_hash" \
        "$public_registry_uri" \
        "$public_registry_hash" \
        "$registry_entry_uri" \
        "$registry_entry_hash" \
        "$lookup_hash" \
        "$stdout_hash" \
        "$stderr_hash"
    done
  } >"$live_registry_query_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08s" "default v08-s scope"
expect_summary_value "$SUMMARY_CSV" "source_import_public_registry_ready" "0" "default v08-s should block before public registry"
expect_summary_value "$SUMMARY_CSV" "runner_owned_registry_query_ready" "0" "default v08-s should not have query evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "0" "default v08-s should not have live query evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-s must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-s must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-s action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_public_registry_gate.sh" >/dev/null

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_public_registry_ready" "1" "v08-s should see public registry readiness"
expect_summary_value "$SUMMARY_CSV" "registry_query_rows" "0" "v08-s should have no query rows before query import"
expect_summary_value "$SUMMARY_CSV" "runner_owned_registry_query_ready" "0" "v08-s should block before runner-owned query"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "0" "v08-s should block before live query"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-query-missing" "v08-s should ask for live registry query evidence"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_REPLAY=1 \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "live_registry_query_source" "runner-owned-replay" "v08-s replay should be runner-owned"
expect_summary_value "$SUMMARY_CSV" "registry_query_rows" "4" "v08-s replay should have rows"
expect_summary_value "$SUMMARY_CSV" "runner_owned_registry_query_ready" "1" "v08-s replay should satisfy runner-owned mechanics"
expect_summary_value "$SUMMARY_CSV" "network_query_rows" "0" "v08-s replay should not be network fetch"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "4" "v08-s replay should remain offline"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "0" "v08-s replay must not satisfy live query"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-network-fetch-missing" "v08-s replay should wait for live network query"

make_live_registry_query_csv "$PUBLIC_REGISTRY_CSV" "$LIVE_REGISTRY_QUERY_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$LIVE_REGISTRY_QUERY_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "live_registry_query_source" "provided-csv" "v08-s live query should be provided"
expect_summary_value "$SUMMARY_CSV" "registry_query_rows" "4" "v08-s live query fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_public_registry_rows" "4" "v08-s live query should bind public registry rows"
expect_summary_value "$SUMMARY_CSV" "query_tool_hash_verified_rows" "4" "v08-s live query should verify query tool hash"
expect_summary_value "$SUMMARY_CSV" "query_output_hash_match_rows" "4" "v08-s live query should bind fetched output hashes"
expect_summary_value "$SUMMARY_CSV" "runner_owned_registry_query_ready" "1" "v08-s live query should satisfy runner-owned mechanics"
expect_summary_value "$SUMMARY_CSV" "network_query_rows" "4" "v08-s live query should be marked network"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "0" "v08-s live query should not be replay"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "1" "v08-s live query fixture should satisfy live query mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-s live query fixture must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-s live query fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-query-fixture-only" "v08-s live query fixture should remain fixture-only"

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
    if ($idx["gate"] == "source-import-public-registry" && $idx["status"] != "pass") die("v08-s public registry should pass", 20)
    if ($idx["gate"] == "live-registry-query-rows" && $idx["status"] != "pass") die("v08-s query rows should pass", 21)
    if ($idx["gate"] == "live-registry-query-chain" && $idx["status"] != "pass") die("v08-s query chain should pass", 22)
    if ($idx["gate"] == "runner-owned-registry-query" && $idx["status"] != "pass") die("v08-s runner-owned query should pass", 23)
    if ($idx["gate"] == "live-registry-network-fetch" && $idx["status"] != "pass") die("v08-s live network query should pass", 24)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-s source import verification should still block", 25)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-s real benchmark should block", 26)
  }
  END {
    if (rows != 7) die("expected seven v08-s decision rows", 27)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["registry_response_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$LIVE_REGISTRY_QUERY_CSV" >"$BAD_LIVE_REGISTRY_QUERY_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$BAD_LIVE_REGISTRY_QUERY_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_public_registry_ready" "1" "v08-s bad query should preserve public registry readiness"
expect_summary_value "$SUMMARY_CSV" "runner_owned_registry_query_ready" "0" "v08-s bad query should block runner-owned readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "0" "v08-s bad query should block live query readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-query-output-mismatch" "v08-s bad query should block at output mismatch"

echo "v08 external benchmark source import live registry query gate smoke passed"
