#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PREFIX="v08_external_benchmark_source_import_live_registry_network_proof"
FETCH_PREFIX="v08_external_benchmark_source_import_live_registry_fetcher"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_live_registry_network_proof_smoke"
  FETCH_PREFIX="v08_external_benchmark_source_import_live_registry_fetcher_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" "${RUN_ARGS[@]}" >/dev/null

FETCH_SUMMARY_CSV="$RESULTS_DIR/${FETCH_PREFIX}_summary.csv"
FETCH_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV:-$RESULTS_DIR/${FETCH_PREFIX}_fetch.csv}"
PROOF_CSV="$RESULTS_DIR/${PREFIX}_proof.csv"
PROOF_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_proof_header() {
  echo "benchmark_family,source_import_id,live_registry_query_id,fetcher_run_id,public_registry_uri,registry_entry_uri,registry_cache_uri,registry_cache_hash,registry_entry_cache_uri,registry_entry_cache_hash,network_proof_id,network_proof_runner_id,network_tool_uri,network_tool_hash,request_manifest_hash,response_header_hash,tls_peer_cert_hash,dns_resolution_hash,runner_nonce_hash,network_started_at_utc,network_completed_at_utc,http_status,registry_body_hash,registry_entry_body_hash,registry_cache_hash_verified,registry_entry_cache_hash_verified,network_fetch_performed,offline_replay_used,runner_owned_network_proof,real_network_proof_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
}

join_by_comma() {
  local IFS=,
  printf '%s\n' "$*"
}

is_present() {
  local value="$1"
  [[ "$value" != "" && "$value" != "pending" ]]
}

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

uri_to_local_path() {
  local uri="$1"
  if [[ "$uri" == file://* ]]; then
    printf '%s\n' "${uri#file://}"
    return 0
  fi
  return 1
}

hash_matches_uri() {
  local uri="$1"
  local expected="$2"
  local path
  local expected_hex
  local actual_hex

  if ! is_sha256 "$expected"; then
    return 1
  fi
  if ! path="$(uri_to_local_path "$uri")"; then
    return 1
  fi
  if [[ ! -f "$path" ]]; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

sha_file_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

sha_text_uri() {
  local text="$1"
  printf 'sha256:%s\n' "$(printf '%s' "$text" | sha256sum | awk '{print $1}')"
}

FETCH_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready expected_live_registry_fetch_rows fetch_rows source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-u fetch summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_contract_ready"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_live_verifier_ready"] + 0,
        $idx["source_import_independent_live_review_ready"] + 0,
        $idx["source_import_authoritative_review_ready"] + 0,
        $idx["source_import_public_registry_ready"] + 0,
        $idx["source_import_live_registry_query_ready"] + 0,
        $idx["source_import_live_registry_fetcher_ready"] + 0,
        $idx["source_import_live_registry_fetch_ready"] + 0,
        $idx["expected_live_registry_fetch_rows"] + 0,
        $idx["fetch_rows"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-u fetch summary row", 3)
    }
  ' "$FETCH_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready expected_fetch_rows fetch_rows upstream_source_import_verified fetch_action fetch_routing fetch_jump <<<"$FETCH_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV:-}" ]]; then
  PROOF_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV"
  PROOF_SOURCE="provided-csv"
  if [[ ! -s "$PROOF_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
elif [[ "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_REPLAY:-0}" == "1" ]]; then
  PROOF_SOURCE="runner-owned-replay"
  script_hash="$(sha_file_uri "$0")"
  script_uri="file://$0"
  {
    write_proof_header
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
          if (!(required[i] in idx)) die("missing v08-u replay source column: " required[i], 4)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-u replay source row has wrong column count", 5)
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
    ' "$FETCH_CSV" |
    while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id fetcher_run_id public_registry_uri registry_entry_uri registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash; do
      proof_id="live-registry-network-proof-replay-${benchmark_family//[^A-Za-z0-9]/-}"
      runner_id="betelgeuze-live-registry-network-proof-replay-v1"
      request_hash="$(sha_text_uri "GET ${public_registry_uri} ${registry_entry_uri} ${source_import_id}")"
      header_hash="$(sha_text_uri "HTTP/200|${registry_cache_hash}|${registry_entry_cache_hash}")"
      tls_hash="$(sha_text_uri "replay-tls|${public_registry_uri}|${registry_entry_uri}")"
      dns_hash="$(sha_text_uri "replay-dns|${public_registry_uri}|${registry_entry_uri}")"
      nonce_hash="$(sha_text_uri "${proof_id}|${fetcher_run_id}|2026-06-01T00:00:00Z")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-06-01T00:00:00Z,2026-06-01T00:00:01Z,200,%s,%s,1,1,0,1,1,0,1,0,0\n" \
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
        "$registry_entry_cache_hash"
    done
  } >"$PROOF_CSV"
else
  write_proof_header >"$PROOF_CSV"
fi

declare -A expected_source_import_id
declare -A expected_live_registry_query_id
declare -A expected_fetcher_run_id
declare -A expected_public_registry_uri
declare -A expected_registry_entry_uri
declare -A expected_registry_cache_uri
declare -A expected_registry_cache_hash
declare -A expected_registry_entry_cache_uri
declare -A expected_registry_entry_cache_hash

expected_fetch_rows_seen=0
if [[ -s "$FETCH_CSV" ]]; then
  FETCH_TSV="$TMP_DIR/live_registry_fetch.tsv"
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
        if (!(required[i] in idx)) die("missing v08-u fetch source column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-u fetch source row has wrong column count", 11)
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
  ' "$FETCH_CSV" >"$FETCH_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id fetcher_run_id public_registry_uri registry_entry_uri registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-u live registry fetch family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_live_registry_query_id["$benchmark_family"]="$live_registry_query_id"
    expected_fetcher_run_id["$benchmark_family"]="$fetcher_run_id"
    expected_public_registry_uri["$benchmark_family"]="$public_registry_uri"
    expected_registry_entry_uri["$benchmark_family"]="$registry_entry_uri"
    expected_registry_cache_uri["$benchmark_family"]="$registry_cache_uri"
    expected_registry_cache_hash["$benchmark_family"]="$registry_cache_hash"
    expected_registry_entry_cache_uri["$benchmark_family"]="$registry_entry_cache_uri"
    expected_registry_entry_cache_hash["$benchmark_family"]="$registry_entry_cache_hash"
    ((expected_fetch_rows_seen += 1))
  done <"$FETCH_TSV"
fi

proof_rows=0
matched_fetch_rows=0
source_import_id_match_rows=0
live_registry_query_id_match_rows=0
fetcher_run_id_match_rows=0
registry_uri_match_rows=0
cache_uri_match_rows=0
body_hash_match_rows=0
registry_cache_hash_verified_rows=0
registry_entry_cache_hash_verified_rows=0
proof_metadata_rows=0
network_tool_hash_verified_rows=0
http_ok_rows=0
runner_owned_network_proof_rows=0
network_fetch_rows=0
offline_replay_rows=0
declared_real_proof_rows=0
non_fixture_declared_rows=0
proof_routing="0.000000"
proof_jump="0.000000"
declare -A proof_seen

PROOF_TSV="$TMP_DIR/live_registry_network_proof.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id live_registry_query_id fetcher_run_id public_registry_uri registry_entry_uri registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash network_proof_id network_proof_runner_id network_tool_uri network_tool_hash request_manifest_hash response_header_hash tls_peer_cert_hash dns_resolution_hash runner_nonce_hash network_started_at_utc network_completed_at_utc http_status registry_body_hash registry_entry_body_hash registry_cache_hash_verified registry_entry_cache_hash_verified network_fetch_performed offline_replay_used runner_owned_network_proof real_network_proof_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-u network proof column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-u network proof row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["live_registry_query_id"],
      $idx["fetcher_run_id"],
      $idx["public_registry_uri"],
      $idx["registry_entry_uri"],
      $idx["registry_cache_uri"],
      $idx["registry_cache_hash"],
      $idx["registry_entry_cache_uri"],
      $idx["registry_entry_cache_hash"],
      $idx["network_proof_id"],
      $idx["network_proof_runner_id"],
      $idx["network_tool_uri"],
      $idx["network_tool_hash"],
      $idx["request_manifest_hash"],
      $idx["response_header_hash"],
      $idx["tls_peer_cert_hash"],
      $idx["dns_resolution_hash"],
      $idx["runner_nonce_hash"],
      $idx["network_started_at_utc"],
      $idx["network_completed_at_utc"],
      $idx["http_status"] + 0,
      $idx["registry_body_hash"],
      $idx["registry_entry_body_hash"],
      $idx["registry_cache_hash_verified"] + 0,
      $idx["registry_entry_cache_hash_verified"] + 0,
      $idx["network_fetch_performed"] + 0,
      $idx["offline_replay_used"] + 0,
      $idx["runner_owned_network_proof"] + 0,
      $idx["real_network_proof_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0
  }
' "$PROOF_CSV" >"$PROOF_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id fetcher_run_id public_registry_uri registry_entry_uri registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash network_proof_id network_proof_runner_id network_tool_uri network_tool_hash request_manifest_hash response_header_hash tls_peer_cert_hash dns_resolution_hash runner_nonce_hash network_started_at_utc network_completed_at_utc http_status registry_body_hash registry_entry_body_hash registry_cache_hash_verified registry_entry_cache_hash_verified network_fetch_performed offline_replay_used runner_owned_network_proof real_network_proof_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((proof_rows += 1))
  if [[ -n "${proof_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-u network proof family: $benchmark_family" >&2
    exit 15
  fi
  proof_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_fetch_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_live_registry_query_id[$benchmark_family]:-}" == "$live_registry_query_id" ]] && is_present "$live_registry_query_id"; then
    ((live_registry_query_id_match_rows += 1))
  fi
  if [[ "${expected_fetcher_run_id[$benchmark_family]:-}" == "$fetcher_run_id" ]] && is_present "$fetcher_run_id"; then
    ((fetcher_run_id_match_rows += 1))
  fi
  if [[ "${expected_public_registry_uri[$benchmark_family]:-}" == "$public_registry_uri" &&
        "${expected_registry_entry_uri[$benchmark_family]:-}" == "$registry_entry_uri" ]] &&
      is_present "$public_registry_uri" &&
      is_present "$registry_entry_uri"; then
    ((registry_uri_match_rows += 1))
  fi
  if [[ "${expected_registry_cache_uri[$benchmark_family]:-}" == "$registry_cache_uri" &&
        "${expected_registry_entry_cache_uri[$benchmark_family]:-}" == "$registry_entry_cache_uri" ]] &&
      is_present "$registry_cache_uri" &&
      is_present "$registry_entry_cache_uri"; then
    ((cache_uri_match_rows += 1))
  fi
  if [[ "${expected_registry_cache_hash[$benchmark_family]:-}" == "$registry_cache_hash" &&
        "${expected_registry_entry_cache_hash[$benchmark_family]:-}" == "$registry_entry_cache_hash" &&
        "$registry_cache_hash" == "$registry_body_hash" &&
        "$registry_entry_cache_hash" == "$registry_entry_body_hash" ]] &&
      is_sha256 "$registry_body_hash" &&
      is_sha256 "$registry_entry_body_hash"; then
    ((body_hash_match_rows += 1))
  fi
  if [[ "$registry_cache_hash_verified" == "1" ]] && hash_matches_uri "$registry_cache_uri" "$registry_body_hash"; then
    ((registry_cache_hash_verified_rows += 1))
  fi
  if [[ "$registry_entry_cache_hash_verified" == "1" ]] && hash_matches_uri "$registry_entry_cache_uri" "$registry_entry_body_hash"; then
    ((registry_entry_cache_hash_verified_rows += 1))
  fi

  if is_present "$network_proof_id" &&
      is_present "$network_proof_runner_id" &&
      is_present "$network_tool_uri" &&
      is_sha256 "$network_tool_hash" &&
      is_sha256 "$request_manifest_hash" &&
      is_sha256 "$response_header_hash" &&
      is_sha256 "$tls_peer_cert_hash" &&
      is_sha256 "$dns_resolution_hash" &&
      is_sha256 "$runner_nonce_hash" &&
      is_present "$network_started_at_utc" &&
      is_present "$network_completed_at_utc"; then
    ((proof_metadata_rows += 1))
  fi
  if hash_matches_uri "$network_tool_uri" "$network_tool_hash"; then
    ((network_tool_hash_verified_rows += 1))
  fi
  if [[ "$http_status" == "200" ]]; then
    ((http_ok_rows += 1))
  fi
  if [[ "$runner_owned_network_proof" == "1" ]]; then
    ((runner_owned_network_proof_rows += 1))
  fi
  if [[ "$network_fetch_performed" == "1" ]]; then
    ((network_fetch_rows += 1))
  fi
  if [[ "$offline_replay_used" == "1" ]]; then
    ((offline_replay_rows += 1))
  fi
  if [[ "$real_network_proof_declared" == "1" ]]; then
    ((declared_real_proof_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  proof_routing="$(awk -v a="$proof_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  proof_jump="$(awk -v a="$proof_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$PROOF_TSV"

source_import_live_registry_network_proof_runner_ready=0
if [[ "$source_import_live_registry_fetch_ready" == "1" &&
      "$expected_fetch_rows" -gt 0 &&
      "$expected_fetch_rows_seen" -eq "$expected_fetch_rows" &&
      "$proof_rows" -eq "$expected_fetch_rows" &&
      "$matched_fetch_rows" -eq "$expected_fetch_rows" &&
      "$source_import_id_match_rows" -eq "$expected_fetch_rows" &&
      "$live_registry_query_id_match_rows" -eq "$expected_fetch_rows" &&
      "$fetcher_run_id_match_rows" -eq "$expected_fetch_rows" &&
      "$registry_uri_match_rows" -eq "$expected_fetch_rows" &&
      "$cache_uri_match_rows" -eq "$expected_fetch_rows" &&
      "$body_hash_match_rows" -eq "$expected_fetch_rows" &&
      "$registry_cache_hash_verified_rows" -eq "$expected_fetch_rows" &&
      "$registry_entry_cache_hash_verified_rows" -eq "$expected_fetch_rows" &&
      "$proof_metadata_rows" -eq "$expected_fetch_rows" &&
      "$network_tool_hash_verified_rows" -eq "$expected_fetch_rows" &&
      "$http_ok_rows" -eq "$expected_fetch_rows" &&
      "$runner_owned_network_proof_rows" -eq "$expected_fetch_rows" &&
      "$fetch_routing" == "0.000000" &&
      "$fetch_jump" == "0.000000" &&
      "$proof_routing" == "0.000000" &&
      "$proof_jump" == "0.000000" ]]; then
  source_import_live_registry_network_proof_runner_ready=1
fi

source_import_live_registry_network_proof_ready=0
if [[ "$source_import_live_registry_network_proof_runner_ready" == "1" &&
      "$network_fetch_rows" -eq "$expected_fetch_rows" &&
      "$offline_replay_rows" -eq 0 &&
      "$declared_real_proof_rows" -eq "$expected_fetch_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_fetch_rows" ]]; then
  source_import_live_registry_network_proof_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$fetch_action"
if [[ "$source_import_live_registry_fetch_ready" == "1" ]]; then
  if [[ "$proof_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-live-registry-network-proof-missing"
  elif [[ "$proof_rows" -ne "$expected_fetch_rows" ||
          "$matched_fetch_rows" -ne "$expected_fetch_rows" ||
          "$source_import_id_match_rows" -ne "$expected_fetch_rows" ||
          "$live_registry_query_id_match_rows" -ne "$expected_fetch_rows" ||
          "$fetcher_run_id_match_rows" -ne "$expected_fetch_rows" ||
          "$registry_uri_match_rows" -ne "$expected_fetch_rows" ||
          "$cache_uri_match_rows" -ne "$expected_fetch_rows" ]]; then
    action="external-benchmark-source-import-live-registry-network-proof-row-mismatch"
  elif [[ "$body_hash_match_rows" -ne "$expected_fetch_rows" ||
          "$registry_cache_hash_verified_rows" -ne "$expected_fetch_rows" ||
          "$registry_entry_cache_hash_verified_rows" -ne "$expected_fetch_rows" ]]; then
    action="external-benchmark-source-import-live-registry-network-proof-cache-mismatch"
  elif [[ "$proof_metadata_rows" -ne "$expected_fetch_rows" ||
          "$network_tool_hash_verified_rows" -ne "$expected_fetch_rows" ]]; then
    action="external-benchmark-source-import-live-registry-network-proof-artifact-missing"
  elif [[ "$source_import_live_registry_network_proof_runner_ready" != "1" ]]; then
    action="external-benchmark-source-import-runner-owned-live-registry-network-proof-missing"
  elif [[ "$source_import_live_registry_network_proof_ready" != "1" ]]; then
    action="external-benchmark-source-import-live-registry-network-proof-nonlive"
  elif [[ "$source_import_live_registry_network_proof_ready" == "1" ]]; then
    action="external-benchmark-source-import-live-registry-network-proof-fixture-only"
  fi
fi

total_routing="$(awk -v a="$fetch_routing" -v b="$proof_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$fetch_jump" -v b="$proof_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_contract_ready,source_import_verifier_ready,source_import_live_verifier_ready,source_import_independent_live_review_ready,source_import_authoritative_review_ready,source_import_public_registry_ready,source_import_live_registry_query_ready,source_import_live_registry_fetcher_ready,source_import_live_registry_fetch_ready,live_registry_fetch_source,expected_live_registry_fetch_rows,fetch_rows,live_registry_network_proof_source,expected_network_proof_rows,network_proof_rows,matched_fetch_rows,source_import_id_match_rows,live_registry_query_id_match_rows,fetcher_run_id_match_rows,registry_uri_match_rows,cache_uri_match_rows,body_hash_match_rows,registry_cache_hash_verified_rows,registry_entry_cache_hash_verified_rows,proof_metadata_rows,network_tool_hash_verified_rows,http_ok_rows,runner_owned_network_proof_rows,network_fetch_rows,offline_replay_rows,declared_real_proof_rows,non_fixture_declared_rows,source_import_live_registry_network_proof_runner_ready,source_import_live_registry_network_proof_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  join_by_comma \
    route-memory-v08u \
    "$benchmark_families" \
    "$source_import_contract_ready" \
    "$source_import_verifier_ready" \
    "$source_import_live_verifier_ready" \
    "$source_import_independent_live_review_ready" \
    "$source_import_authoritative_review_ready" \
    "$source_import_public_registry_ready" \
    "$source_import_live_registry_query_ready" \
    "$source_import_live_registry_fetcher_ready" \
    "$source_import_live_registry_fetch_ready" \
    v08-t \
    "$expected_fetch_rows" \
    "$fetch_rows" \
    "$PROOF_SOURCE" \
    "$expected_fetch_rows" \
    "$proof_rows" \
    "$matched_fetch_rows" \
    "$source_import_id_match_rows" \
    "$live_registry_query_id_match_rows" \
    "$fetcher_run_id_match_rows" \
    "$registry_uri_match_rows" \
    "$cache_uri_match_rows" \
    "$body_hash_match_rows" \
    "$registry_cache_hash_verified_rows" \
    "$registry_entry_cache_hash_verified_rows" \
    "$proof_metadata_rows" \
    "$network_tool_hash_verified_rows" \
    "$http_ok_rows" \
    "$runner_owned_network_proof_rows" \
    "$network_fetch_rows" \
    "$offline_replay_rows" \
    "$declared_real_proof_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_live_registry_network_proof_runner_ready" \
    "$source_import_live_registry_network_proof_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-live-registry-fetch,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_live_registry_fetch_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_fetch_ready" \
    "$fetch_action"
  printf "network-proof-rows,%s,rows=%d expected=%d matched=%d source_import_ids=%d query_ids=%d fetcher_ids=%d\n" \
    "$([[ "$proof_rows" -eq "$expected_fetch_rows" && "$matched_fetch_rows" -eq "$expected_fetch_rows" && "$source_import_id_match_rows" -eq "$expected_fetch_rows" && "$live_registry_query_id_match_rows" -eq "$expected_fetch_rows" && "$fetcher_run_id_match_rows" -eq "$expected_fetch_rows" && "$expected_fetch_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$proof_rows" \
    "$expected_fetch_rows" \
    "$matched_fetch_rows" \
    "$source_import_id_match_rows" \
    "$live_registry_query_id_match_rows" \
    "$fetcher_run_id_match_rows"
  printf "network-proof-cache,%s,body_hash=%d/%d registry_cache=%d/%d entry_cache=%d/%d\n" \
    "$([[ "$body_hash_match_rows" -eq "$expected_fetch_rows" && "$registry_cache_hash_verified_rows" -eq "$expected_fetch_rows" && "$registry_entry_cache_hash_verified_rows" -eq "$expected_fetch_rows" && "$expected_fetch_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$body_hash_match_rows" \
    "$expected_fetch_rows" \
    "$registry_cache_hash_verified_rows" \
    "$expected_fetch_rows" \
    "$registry_entry_cache_hash_verified_rows" \
    "$expected_fetch_rows"
  printf "runner-owned-network-proof,%s,ready=%d source=%s metadata=%d/%d tool_hash=%d/%d runner=%d/%d\n" \
    "$([[ "$source_import_live_registry_network_proof_runner_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_network_proof_runner_ready" \
    "$PROOF_SOURCE" \
    "$proof_metadata_rows" \
    "$expected_fetch_rows" \
    "$network_tool_hash_verified_rows" \
    "$expected_fetch_rows" \
    "$runner_owned_network_proof_rows" \
    "$expected_fetch_rows"
  printf "live-network-proof,%s,ready=%d network=%d/%d replay=%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$source_import_live_registry_network_proof_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_network_proof_ready" \
    "$network_fetch_rows" \
    "$expected_fetch_rows" \
    "$offline_replay_rows" \
    "$declared_real_proof_rows" \
    "$expected_fetch_rows" \
    "$non_fixture_declared_rows" \
    "$expected_fetch_rows"
  printf "source-import-verification,%s,verified=%d network_proof_ready=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$source_import_live_registry_network_proof_ready" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
