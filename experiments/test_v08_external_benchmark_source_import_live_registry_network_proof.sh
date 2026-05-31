#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_network_proof_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_network_proof_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_fixture.csv"
PUBLIC_REGISTRY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_public_registry_fixture.csv"
LIVE_REGISTRY_QUERY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_query_fixture.csv"
LIVE_REGISTRY_FETCH_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_fetch_fixture.csv"
NETWORK_PROOF_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_network_proof_fixture.csv"
BAD_NETWORK_PROOF_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_bad_network_proof_fixture.csv"
MALFORMED_NETWORK_PROOF_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_malformed_network_proof_fixture.csv"

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
      if (!(field in idx)) die("missing v08-u summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-u summary row", 4)
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

make_network_proof_csv() {
  local fetch_csv="$1"
  local proof_csv="$2"
  local network_fetch="$3"
  local offline_replay="$4"
  local real_declared="$5"
  local fixture_declared="$6"
  local runner_script="$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh"
  local script_uri="file://$runner_script"
  local script_hash

  script_hash="$(sha_file_uri "$runner_script")"
  {
    echo "benchmark_family,source_import_id,live_registry_query_id,fetcher_run_id,public_registry_uri,registry_entry_uri,registry_cache_uri,registry_cache_hash,registry_entry_cache_uri,registry_entry_cache_hash,network_proof_id,network_proof_runner_id,network_tool_uri,network_tool_hash,request_manifest_hash,response_header_hash,tls_peer_cert_hash,dns_resolution_hash,runner_nonce_hash,network_started_at_utc,network_completed_at_utc,http_status,registry_body_hash,registry_entry_body_hash,registry_cache_hash_verified,registry_entry_cache_hash_verified,network_fetch_performed,offline_replay_used,runner_owned_network_proof,real_network_proof_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    awk -F, '
      function die(message, code) {
        print message > "/dev/stderr"
        exit code
      }
      NR == 1 {
        header_fields = NF
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("benchmark_family source_import_id live_registry_query_id fetcher_run_id public_registry_uri registry_entry_uri registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08-u network proof fixture source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-u network proof fixture source row has wrong column count", 3)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["live_registry_query_id"],
          $idx["fetcher_run_id"],
          $idx["public_registry_uri"],
          $idx["registry_entry_uri"],
          $idx["registry_cache_uri"],
          $idx["registry_cache_hash"],
          $idx["registry_entry_cache_uri"],
          $idx["registry_entry_cache_hash"]
      }
    ' "$fetch_csv" |
    while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id fetcher_run_id public_registry_uri registry_entry_uri registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash; do
      proof_id="live-registry-network-proof-${benchmark_family//[^A-Za-z0-9]/-}"
      runner_id="betelgeuze-live-registry-network-proof-v1"
      request_hash="$(sha_text_uri "GET ${public_registry_uri} ${registry_entry_uri} ${source_import_id}")"
      header_hash="$(sha_text_uri "HTTP/200|${registry_cache_hash}|${registry_entry_cache_hash}")"
      tls_hash="$(sha_text_uri "tls|${public_registry_uri}|${registry_entry_uri}")"
      dns_hash="$(sha_text_uri "dns|${public_registry_uri}|${registry_entry_uri}")"
      nonce_hash="$(sha_text_uri "${proof_id}|${fetcher_run_id}|2026-06-01T00:00:00Z")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-06-01T00:00:00Z,2026-06-01T00:00:01Z,200,%s,%s,1,1,%d,%d,1,%d,%d,0,0\n" \
        "$benchmark_family" \
        "$source_import_id" \
        "$live_registry_query_id" \
        "$fetcher_run_id" \
        "$public_registry_uri" \
        "$registry_entry_uri" \
        "$registry_cache_uri" \
        "$registry_cache_hash" \
        "$registry_entry_cache_uri" \
        "$registry_entry_cache_hash" \
        "$proof_id" \
        "$runner_id" \
        "$script_uri" \
        "$script_hash" \
        "$request_hash" \
        "$header_hash" \
        "$tls_hash" \
        "$dns_hash" \
        "$nonce_hash" \
        "$registry_cache_hash" \
        "$registry_entry_cache_hash" \
        "$network_fetch" \
        "$offline_replay" \
        "$real_declared" \
        "$fixture_declared"
    done
  } >"$proof_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08u" "default v08-u scope"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "0" "default v08-u should block before live registry fetch"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_runner_ready" "0" "default v08-u should not have runner proof"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "0" "default v08-u should not have live proof"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-u must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-u must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-u action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_live_registry_fetcher.sh" >/dev/null

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
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "1" "v08-u should see live registry fetch readiness"
expect_summary_value "$SUMMARY_CSV" "network_proof_rows" "0" "v08-u should have no proof rows before proof evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_runner_ready" "0" "v08-u should block before runner proof"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "0" "v08-u should block before live proof"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-network-proof-missing" "v08-u should ask for network proof"

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
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_REPLAY=1 \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "live_registry_network_proof_source" "runner-owned-replay" "v08-u replay should be runner-owned"
expect_summary_value "$SUMMARY_CSV" "network_proof_rows" "4" "v08-u replay should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_fetch_rows" "4" "v08-u replay should match fetch rows"
expect_summary_value "$SUMMARY_CSV" "body_hash_match_rows" "4" "v08-u replay should match body hashes"
expect_summary_value "$SUMMARY_CSV" "registry_cache_hash_verified_rows" "4" "v08-u replay should verify registry cache hashes"
expect_summary_value "$SUMMARY_CSV" "registry_entry_cache_hash_verified_rows" "4" "v08-u replay should verify entry cache hashes"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_runner_ready" "1" "v08-u replay should satisfy runner proof mechanics"
expect_summary_value "$SUMMARY_CSV" "network_fetch_rows" "0" "v08-u replay should not be network proof"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "4" "v08-u replay should remain offline"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "0" "v08-u replay must not satisfy live proof"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-network-proof-nonlive" "v08-u replay should wait for live network proof"

make_network_proof_csv "$LIVE_REGISTRY_FETCH_CSV" "$NETWORK_PROOF_CSV" 1 0 1 0

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
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$NETWORK_PROOF_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "live_registry_network_proof_source" "provided-csv" "v08-u live proof should be provided"
expect_summary_value "$SUMMARY_CSV" "network_proof_rows" "4" "v08-u live proof fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_runner_ready" "1" "v08-u live proof should satisfy runner proof mechanics"
expect_summary_value "$SUMMARY_CSV" "network_fetch_rows" "4" "v08-u live proof should be marked network"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "0" "v08-u live proof should not be replay"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "1" "v08-u live proof fixture should satisfy proof mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-u live proof fixture must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-u live proof fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-network-proof-fixture-only" "v08-u live proof fixture should remain fixture-only"

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
    if ($idx["gate"] == "source-import-live-registry-fetch" && $idx["status"] != "pass") die("v08-u live registry fetch should pass", 20)
    if ($idx["gate"] == "network-proof-rows" && $idx["status"] != "pass") die("v08-u proof rows should pass", 21)
    if ($idx["gate"] == "network-proof-cache" && $idx["status"] != "pass") die("v08-u proof cache should pass", 22)
    if ($idx["gate"] == "runner-owned-network-proof" && $idx["status"] != "pass") die("v08-u runner proof should pass", 23)
    if ($idx["gate"] == "live-network-proof" && $idx["status"] != "pass") die("v08-u live network proof should pass", 24)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-u source import verification should still block", 25)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-u real benchmark should block", 26)
  }
  END {
    if (rows != 7) die("expected seven v08-u decision rows", 27)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["registry_body_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$NETWORK_PROOF_CSV" >"$BAD_NETWORK_PROOF_CSV"

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
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$BAD_NETWORK_PROOF_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "1" "v08-u bad proof should preserve live fetch readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_runner_ready" "0" "v08-u bad proof should block runner proof readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_network_proof_ready" "0" "v08-u bad proof should block live proof readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-network-proof-cache-mismatch" "v08-u bad proof should block at cache mismatch"

{
  head -n 1 "$NETWORK_PROOF_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$NETWORK_PROOF_CSV")"
} >"$MALFORMED_NETWORK_PROOF_CSV"

if V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
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
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$MALFORMED_NETWORK_PROOF_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-u should reject malformed live registry network proof CSV row widths" >&2
  exit 40
fi

echo "v08 external benchmark source import live registry network proof smoke passed"
