#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_smoke_decision.csv"
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
BAD_LIVE_REGISTRY_FETCH_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_bad_fetch_fixture.csv"
MALFORMED_FETCH_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_malformed_fetch_fixture.csv"
CACHE_DIR="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_cache"

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
      if (!(field in idx)) die("missing v08-t summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-t summary row", 4)
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

make_cache_backed_public_registry_csv() {
  local authority_csv="$1"
  local public_registry_csv="$2"
  local cache_dir="$3"

  mkdir -p "$cache_dir"
  {
    echo "benchmark_family,source_import_id,verifier_run_id,live_review_id,authority_review_id,registry_entry_id,public_registry_uri,public_registry_hash,registry_entry_uri,registry_entry_hash,registry_operator_identity_uri,registry_operator_identity_hash,registry_provenance_uri,registry_provenance_hash,reviewed_authority_review_report_hash,reviewed_authority_reviewer_identity_hash,reviewed_authority_reviewer_registry_hash,reviewed_authority_reviewer_conflict_disclosure_hash,reviewed_verifier_binary_hash,reviewed_verifier_stdout_hash,reviewed_verifier_stderr_hash,registry_name,registry_operator,registry_jurisdiction,registry_record_type,registry_protocol_version,official_public_registry,source_import_recorded,authority_review_recorded,artifact_hash_review_ready,source_import_binding_review_ready,registry_entry_approved,real_public_registry_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,public_registry_hash_attested,registry_entry_hash_attested,registry_operator_identity_hash_attested,registry_provenance_hash_attested"
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
        required_count = split("benchmark_family source_import_id verifier_run_id live_review_id authority_review_id authority_review_report_hash authority_reviewer_identity_hash authority_reviewer_registry_hash authority_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08-t public registry source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-t public registry source row has wrong column count", 3)
        family_slug = slugify($idx["benchmark_family"])
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["verifier_run_id"],
          $idx["live_review_id"],
          $idx["authority_review_id"],
          $idx["authority_review_report_hash"],
          $idx["authority_reviewer_identity_hash"],
          $idx["authority_reviewer_registry_hash"],
          $idx["authority_reviewer_conflict_disclosure_hash"],
          $idx["reviewed_verifier_binary_hash"],
          $idx["reviewed_verifier_stdout_hash"],
          $idx["reviewed_verifier_stderr_hash"],
          family_slug
      }
    ' "$authority_csv" |
    while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id live_review_id authority_review_id authority_report_hash authority_identity_hash authority_registry_hash authority_conflict_hash verifier_binary_hash verifier_stdout_hash verifier_stderr_hash family_slug; do
      registry_cache="$cache_dir/${family_slug}-registry.json"
      entry_cache="$cache_dir/${family_slug}-entry.json"
      printf '{"benchmark_family":"%s","source_import_id":"%s","authority_review_id":"%s","kind":"public-registry"}' \
        "$benchmark_family" "$source_import_id" "$authority_review_id" >"$registry_cache"
      printf '{"benchmark_family":"%s","registry_entry_id":"public-registry-entry-%s","kind":"registry-entry"}' \
        "$benchmark_family" "$family_slug" >"$entry_cache"
      public_registry_hash="$(sha_file_uri "$registry_cache")"
      registry_entry_hash="$(sha_file_uri "$entry_cache")"
      operator_identity_hash="$(sha_text_uri "operator|${benchmark_family}|${source_import_id}")"
      registry_provenance_hash="$(sha_text_uri "provenance|${benchmark_family}|${authority_review_id}")"
      printf "%s,%s,%s,%s,%s,public-registry-entry-%s,https://benchmarks.example.invalid/v08/source-import/public-registry/%s.json,%s,https://benchmarks.example.invalid/v08/source-import/public-registry-entry/%s.json,%s,https://benchmarks.example.invalid/v08/source-import/public-registry-operator/%s-identity.json,%s,https://benchmarks.example.invalid/v08/source-import/public-registry-provenance/%s.json,%s,%s,%s,%s,%s,%s,%s,%s,Public Benchmark Source Import Registry,Public Benchmark Authority,global-public-cache-fixture,source-import-authority-record,v08-source-import-public-registry-v1,1,1,1,1,1,1,1,0,0.000000,0.000000,1,1,1,1\n" \
        "$benchmark_family" \
        "$source_import_id" \
        "$verifier_run_id" \
        "$live_review_id" \
        "$authority_review_id" \
        "$family_slug" \
        "$family_slug" \
        "$public_registry_hash" \
        "$family_slug" \
        "$registry_entry_hash" \
        "$family_slug" \
        "$operator_identity_hash" \
        "$family_slug" \
        "$registry_provenance_hash" \
        "$authority_report_hash" \
        "$authority_identity_hash" \
        "$authority_registry_hash" \
        "$authority_conflict_hash" \
        "$verifier_binary_hash" \
        "$verifier_stdout_hash" \
        "$verifier_stderr_hash"
    done
  } >"$public_registry_csv"
}

make_live_registry_query_csv() {
  local public_registry_csv="$1"
  local live_registry_query_csv="$2"
  local cache_dir="$3"
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
          if (!(required[i] in idx)) die("missing v08-t live registry query fixture source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-t live registry query fixture source row has wrong column count", 3)
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
      registry_response_uri="file://$cache_dir/${family_slug}-registry.json"
      registry_entry_response_uri="file://$cache_dir/${family_slug}-entry.json"
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
        "$registry_response_uri" \
        "$public_registry_hash" \
        "$registry_entry_response_uri" \
        "$registry_entry_hash" \
        "$lookup_hash" \
        "$stdout_hash" \
        "$stderr_hash"
    done
  } >"$live_registry_query_csv"
}

make_live_registry_fetch_csv() {
  local live_registry_query_csv="$1"
  local live_registry_fetch_csv="$2"
  local network_fetch="$3"
  local offline_replay="$4"
  local real_declared="$5"
  local fixture_declared="$6"
  local runner_script="$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh"
  local script_uri="file://$runner_script"
  local script_hash

  script_hash="$(sha_file_uri "$runner_script")"
  {
    echo "benchmark_family,source_import_id,live_registry_query_id,public_registry_uri,registry_entry_uri,registry_response_uri,registry_response_hash,registry_entry_response_uri,registry_entry_response_hash,fetcher_run_id,fetcher_runner_id,fetcher_tool_uri,fetcher_tool_hash,fetch_command_hash,fetch_started_at_utc,fetch_completed_at_utc,http_status,registry_cache_uri,registry_cache_hash,registry_entry_cache_uri,registry_entry_cache_hash,network_fetch_performed,offline_replay_used,runner_owned_fetch,cache_hash_verified,real_live_fetch_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    awk -F, '
      function die(message, code) {
        print message > "/dev/stderr"
        exit code
      }
      NR == 1 {
        header_fields = NF
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("benchmark_family source_import_id live_registry_query_id public_registry_uri registry_entry_uri registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08-t live registry fetch fixture source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-t live registry fetch fixture source row has wrong column count", 3)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["live_registry_query_id"],
          $idx["public_registry_uri"],
          $idx["registry_entry_uri"],
          $idx["registry_response_uri"],
          $idx["registry_response_hash"],
          $idx["registry_entry_response_uri"],
          $idx["registry_entry_response_hash"]
      }
    ' "$live_registry_query_csv" |
    while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id public_registry_uri registry_entry_uri registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash; do
      fetcher_run_id="live-registry-fetch-${benchmark_family//[^A-Za-z0-9]/-}"
      runner_id="betelgeuze-live-registry-fetcher-v1"
      command_hash="$(sha_text_uri "GET ${public_registry_uri} ${registry_entry_uri} ${source_import_id}")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-05-31T00:00:02Z,2026-05-31T00:00:03Z,200,%s,%s,%s,%s,%d,%d,1,1,%d,%d,0,0\n" \
        "$benchmark_family" \
        "$source_import_id" \
        "$live_registry_query_id" \
        "$public_registry_uri" \
        "$registry_entry_uri" \
        "$registry_response_uri" \
        "$registry_response_hash" \
        "$registry_entry_response_uri" \
        "$registry_entry_response_hash" \
        "$fetcher_run_id" \
        "$runner_id" \
        "$script_uri" \
        "$script_hash" \
        "$command_hash" \
        "$registry_response_uri" \
        "$registry_response_hash" \
        "$registry_entry_response_uri" \
        "$registry_entry_response_hash" \
        "$network_fetch" \
        "$offline_replay" \
        "$real_declared" \
        "$fixture_declared"
    done
  } >"$live_registry_fetch_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08t" "default v08-t scope"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "0" "default v08-t should block before live registry query"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetcher_ready" "0" "default v08-t should not have fetcher evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "0" "default v08-t should not have live fetch evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "default v08-t must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-t must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-contract-missing" "default v08-t action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_authoritative_review_gate.sh" >/dev/null
make_cache_backed_public_registry_csv "$AUTHORITY_REVIEW_CSV" "$PUBLIC_REGISTRY_CSV" "$CACHE_DIR"
make_live_registry_query_csv "$PUBLIC_REGISTRY_CSV" "$LIVE_REGISTRY_QUERY_CSV" "$CACHE_DIR"

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
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "1" "v08-t should see live registry query readiness"
expect_summary_value "$SUMMARY_CSV" "fetch_rows" "0" "v08-t should have no fetch rows before fetch evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetcher_ready" "0" "v08-t should block before fetcher evidence"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "0" "v08-t should block before live fetch proof"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-fetch-missing" "v08-t should ask for live registry fetch evidence"

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
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_REPLAY=1 \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "live_registry_fetch_source" "runner-owned-replay" "v08-t replay should be runner-owned"
expect_summary_value "$SUMMARY_CSV" "fetch_rows" "4" "v08-t replay should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_query_rows" "4" "v08-t replay should match query rows"
expect_summary_value "$SUMMARY_CSV" "cache_hash_match_rows" "4" "v08-t replay should match cache hashes"
expect_summary_value "$SUMMARY_CSV" "registry_cache_hash_verified_rows" "4" "v08-t replay should verify registry cache hashes"
expect_summary_value "$SUMMARY_CSV" "registry_entry_cache_hash_verified_rows" "4" "v08-t replay should verify entry cache hashes"
expect_summary_value "$SUMMARY_CSV" "fetcher_tool_hash_verified_rows" "4" "v08-t replay should verify fetcher tool hash"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetcher_ready" "1" "v08-t replay should satisfy fetcher mechanics"
expect_summary_value "$SUMMARY_CSV" "network_fetch_rows" "0" "v08-t replay should not be network fetch"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "4" "v08-t replay should remain offline"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "0" "v08-t replay must not satisfy live fetch"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-network-fetch-proof-missing" "v08-t replay should wait for live network proof"

make_live_registry_fetch_csv "$LIVE_REGISTRY_QUERY_CSV" "$LIVE_REGISTRY_FETCH_CSV" 1 0 1 0

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
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "live_registry_fetch_source" "provided-csv" "v08-t live fetch should be provided"
expect_summary_value "$SUMMARY_CSV" "fetch_rows" "4" "v08-t live fetch fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetcher_ready" "1" "v08-t live fetch should satisfy fetcher mechanics"
expect_summary_value "$SUMMARY_CSV" "network_fetch_rows" "4" "v08-t live fetch should be marked network"
expect_summary_value "$SUMMARY_CSV" "offline_replay_rows" "0" "v08-t live fetch should not be replay"
expect_summary_value "$SUMMARY_CSV" "declared_real_fetch_rows" "4" "v08-t live fetch should carry real declaration"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "4" "v08-t live fetch should carry non-fixture declaration"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "1" "v08-t live fetch fixture should satisfy live fetch mechanics"
expect_summary_value "$SUMMARY_CSV" "source_import_verified" "0" "v08-t live fetch fixture must not verify source import"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-t live fetch fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-fetch-fixture-only" "v08-t live fetch fixture should remain fixture-only"

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
    if ($idx["gate"] == "source-import-live-registry-query" && $idx["status"] != "pass") die("v08-t live registry query should pass", 20)
    if ($idx["gate"] == "live-registry-fetch-rows" && $idx["status"] != "pass") die("v08-t fetch rows should pass", 21)
    if ($idx["gate"] == "live-registry-fetch-cache" && $idx["status"] != "pass") die("v08-t fetch cache should pass", 22)
    if ($idx["gate"] == "runner-owned-live-registry-fetcher" && $idx["status"] != "pass") die("v08-t runner-owned fetcher should pass", 23)
    if ($idx["gate"] == "live-registry-network-fetch-proof" && $idx["status"] != "pass") die("v08-t live network fetch proof should pass", 24)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("v08-t source import verification should still block", 25)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-t real benchmark should block", 26)
  }
  END {
    if (rows != 7) die("expected seven v08-t decision rows", 27)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["registry_cache_hash"] = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    print
  }
' "$LIVE_REGISTRY_FETCH_CSV" >"$BAD_LIVE_REGISTRY_FETCH_CSV"

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
V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$BAD_LIVE_REGISTRY_FETCH_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_query_ready" "1" "v08-t bad fetch should preserve live query readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetcher_ready" "0" "v08-t bad fetch should block fetcher readiness"
expect_summary_value "$SUMMARY_CSV" "source_import_live_registry_fetch_ready" "0" "v08-t bad fetch should block live fetch readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-source-import-live-registry-fetch-hash-mismatch" "v08-t bad fetch should block at cache hash mismatch"

{
  head -n 1 "$LIVE_REGISTRY_FETCH_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$LIVE_REGISTRY_FETCH_CSV")"
} >"$MALFORMED_FETCH_CSV"

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
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$MALFORMED_FETCH_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-t should reject malformed live registry fetch CSV row widths" >&2
  exit 40
fi

echo "v08 external benchmark source import live registry fetcher smoke passed"
