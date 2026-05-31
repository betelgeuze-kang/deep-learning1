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

PREFIX="v08_external_benchmark_source_import_live_registry_fetcher"
QUERY_PREFIX="v08_external_benchmark_source_import_live_registry_query_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_live_registry_fetcher_smoke"
  QUERY_PREFIX="v08_external_benchmark_source_import_live_registry_query_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh" "${RUN_ARGS[@]}" >/dev/null

QUERY_SUMMARY_CSV="$RESULTS_DIR/${QUERY_PREFIX}_summary.csv"
QUERY_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV:-$RESULTS_DIR/${QUERY_PREFIX}_query.csv}"
FETCH_CSV="$RESULTS_DIR/${PREFIX}_fetch.csv"
FETCH_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_fetch_header() {
  echo "benchmark_family,source_import_id,live_registry_query_id,public_registry_uri,registry_entry_uri,registry_response_uri,registry_response_hash,registry_entry_response_uri,registry_entry_response_hash,fetcher_run_id,fetcher_runner_id,fetcher_tool_uri,fetcher_tool_hash,fetch_command_hash,fetch_started_at_utc,fetch_completed_at_utc,http_status,registry_cache_uri,registry_cache_hash,registry_entry_cache_uri,registry_entry_cache_hash,network_fetch_performed,offline_replay_used,runner_owned_fetch,cache_hash_verified,real_live_fetch_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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

QUERY_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready expected_live_registry_query_rows registry_query_rows runner_owned_registry_query_ready source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-t live registry query summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_contract_ready"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_live_verifier_ready"] + 0,
        $idx["source_import_independent_live_review_ready"] + 0,
        $idx["source_import_authoritative_review_ready"] + 0,
        $idx["source_import_public_registry_ready"] + 0,
        $idx["source_import_live_registry_query_ready"] + 0,
        $idx["expected_live_registry_query_rows"] + 0,
        $idx["registry_query_rows"] + 0,
        $idx["runner_owned_registry_query_ready"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-t live registry query summary row", 3)
    }
  ' "$QUERY_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready expected_live_registry_query_rows registry_query_rows upstream_runner_owned_registry_query_ready upstream_source_import_verified query_action query_routing query_jump <<<"$QUERY_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV:-}" ]]; then
  FETCH_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV"
  FETCH_SOURCE="provided-csv"
  if [[ ! -s "$FETCH_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
elif [[ "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_REPLAY:-0}" == "1" ]]; then
  FETCH_SOURCE="runner-owned-replay"
  script_hash="$(sha_file_uri "$0")"
  script_uri="file://$0"
  {
    write_fetch_header
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
          if (!(required[i] in idx)) die("missing v08-t replay source column: " required[i], 4)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-t replay source row has wrong column count", 5)
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
    ' "$QUERY_CSV" |
    while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id public_registry_uri registry_entry_uri registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash; do
      fetcher_run_id="live-registry-fetch-replay-${benchmark_family//[^A-Za-z0-9]/-}"
      runner_id="betelgeuze-live-registry-fetcher-replay-v1"
      command_hash="$(sha_text_uri "GET ${public_registry_uri} ${registry_entry_uri} ${source_import_id}")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-05-31T00:00:02Z,2026-05-31T00:00:03Z,200,%s,%s,%s,%s,0,1,1,1,0,1,0,0\n" \
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
        "$registry_entry_response_hash"
    done
  } >"$FETCH_CSV"
else
  write_fetch_header >"$FETCH_CSV"
fi

declare -A expected_source_import_id
declare -A expected_live_registry_query_id
declare -A expected_public_registry_uri
declare -A expected_registry_entry_uri
declare -A expected_registry_response_uri
declare -A expected_registry_response_hash
declare -A expected_registry_entry_response_uri
declare -A expected_registry_entry_response_hash

expected_query_rows_seen=0
if [[ -s "$QUERY_CSV" ]]; then
  QUERY_TSV="$TMP_DIR/live_registry_query.tsv"
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
        if (!(required[i] in idx)) die("missing v08-t live registry query source column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-t live registry query source row has wrong column count", 11)
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
  ' "$QUERY_CSV" >"$QUERY_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id public_registry_uri registry_entry_uri registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-t live registry query family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_live_registry_query_id["$benchmark_family"]="$live_registry_query_id"
    expected_public_registry_uri["$benchmark_family"]="$public_registry_uri"
    expected_registry_entry_uri["$benchmark_family"]="$registry_entry_uri"
    expected_registry_response_uri["$benchmark_family"]="$registry_response_uri"
    expected_registry_response_hash["$benchmark_family"]="$registry_response_hash"
    expected_registry_entry_response_uri["$benchmark_family"]="$registry_entry_response_uri"
    expected_registry_entry_response_hash["$benchmark_family"]="$registry_entry_response_hash"
    ((expected_query_rows_seen += 1))
  done <"$QUERY_TSV"
fi

fetch_rows=0
matched_query_rows=0
source_import_id_match_rows=0
live_registry_query_id_match_rows=0
registry_uri_match_rows=0
registry_response_uri_match_rows=0
registry_response_hash_match_rows=0
registry_entry_response_uri_match_rows=0
registry_entry_response_hash_match_rows=0
cache_uri_match_rows=0
cache_hash_match_rows=0
registry_cache_hash_verified_rows=0
registry_entry_cache_hash_verified_rows=0
fetcher_metadata_rows=0
fetcher_tool_hash_verified_rows=0
http_ok_rows=0
runner_owned_fetch_rows=0
cache_hash_verified_rows=0
network_fetch_rows=0
offline_replay_rows=0
declared_real_fetch_rows=0
non_fixture_declared_rows=0
fetch_routing="0.000000"
fetch_jump="0.000000"
declare -A fetch_seen

FETCH_TSV="$TMP_DIR/live_registry_fetch.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id live_registry_query_id public_registry_uri registry_entry_uri registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash fetcher_run_id fetcher_runner_id fetcher_tool_uri fetcher_tool_hash fetch_command_hash fetch_started_at_utc fetch_completed_at_utc http_status registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash network_fetch_performed offline_replay_used runner_owned_fetch cache_hash_verified real_live_fetch_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-t live registry fetch column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-t live registry fetch row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["live_registry_query_id"],
      $idx["public_registry_uri"],
      $idx["registry_entry_uri"],
      $idx["registry_response_uri"],
      $idx["registry_response_hash"],
      $idx["registry_entry_response_uri"],
      $idx["registry_entry_response_hash"],
      $idx["fetcher_run_id"],
      $idx["fetcher_runner_id"],
      $idx["fetcher_tool_uri"],
      $idx["fetcher_tool_hash"],
      $idx["fetch_command_hash"],
      $idx["fetch_started_at_utc"],
      $idx["fetch_completed_at_utc"],
      $idx["http_status"] + 0,
      $idx["registry_cache_uri"],
      $idx["registry_cache_hash"],
      $idx["registry_entry_cache_uri"],
      $idx["registry_entry_cache_hash"],
      $idx["network_fetch_performed"] + 0,
      $idx["offline_replay_used"] + 0,
      $idx["runner_owned_fetch"] + 0,
      $idx["cache_hash_verified"] + 0,
      $idx["real_live_fetch_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0
  }
' "$FETCH_CSV" >"$FETCH_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id live_registry_query_id public_registry_uri registry_entry_uri registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash fetcher_run_id fetcher_runner_id fetcher_tool_uri fetcher_tool_hash fetch_command_hash fetch_started_at_utc fetch_completed_at_utc http_status registry_cache_uri registry_cache_hash registry_entry_cache_uri registry_entry_cache_hash network_fetch_performed offline_replay_used runner_owned_fetch cache_hash_verified real_live_fetch_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((fetch_rows += 1))
  if [[ -n "${fetch_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-t live registry fetch family: $benchmark_family" >&2
    exit 15
  fi
  fetch_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_query_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_live_registry_query_id[$benchmark_family]:-}" == "$live_registry_query_id" ]] && is_present "$live_registry_query_id"; then
    ((live_registry_query_id_match_rows += 1))
  fi
  if [[ "${expected_public_registry_uri[$benchmark_family]:-}" == "$public_registry_uri" &&
        "${expected_registry_entry_uri[$benchmark_family]:-}" == "$registry_entry_uri" ]] &&
      is_present "$public_registry_uri" &&
      is_present "$registry_entry_uri"; then
    ((registry_uri_match_rows += 1))
  fi
  if [[ "${expected_registry_response_uri[$benchmark_family]:-}" == "$registry_response_uri" ]] && is_present "$registry_response_uri"; then
    ((registry_response_uri_match_rows += 1))
  fi
  if [[ "${expected_registry_response_hash[$benchmark_family]:-}" == "$registry_response_hash" ]] && is_sha256 "$registry_response_hash"; then
    ((registry_response_hash_match_rows += 1))
  fi
  if [[ "${expected_registry_entry_response_uri[$benchmark_family]:-}" == "$registry_entry_response_uri" ]] && is_present "$registry_entry_response_uri"; then
    ((registry_entry_response_uri_match_rows += 1))
  fi
  if [[ "${expected_registry_entry_response_hash[$benchmark_family]:-}" == "$registry_entry_response_hash" ]] && is_sha256 "$registry_entry_response_hash"; then
    ((registry_entry_response_hash_match_rows += 1))
  fi
  if [[ "${expected_registry_response_uri[$benchmark_family]:-}" == "$registry_cache_uri" &&
        "${expected_registry_entry_response_uri[$benchmark_family]:-}" == "$registry_entry_cache_uri" ]] &&
      is_present "$registry_cache_uri" &&
      is_present "$registry_entry_cache_uri"; then
    ((cache_uri_match_rows += 1))
  fi
  if [[ "${expected_registry_response_hash[$benchmark_family]:-}" == "$registry_cache_hash" &&
        "${expected_registry_entry_response_hash[$benchmark_family]:-}" == "$registry_entry_cache_hash" ]] &&
      is_sha256 "$registry_cache_hash" &&
      is_sha256 "$registry_entry_cache_hash"; then
    ((cache_hash_match_rows += 1))
  fi
  if hash_matches_uri "$registry_cache_uri" "$registry_cache_hash"; then
    ((registry_cache_hash_verified_rows += 1))
  fi
  if hash_matches_uri "$registry_entry_cache_uri" "$registry_entry_cache_hash"; then
    ((registry_entry_cache_hash_verified_rows += 1))
  fi

  if is_present "$fetcher_run_id" &&
      is_present "$fetcher_runner_id" &&
      is_present "$fetcher_tool_uri" &&
      is_sha256 "$fetcher_tool_hash" &&
      is_sha256 "$fetch_command_hash" &&
      is_present "$fetch_started_at_utc" &&
      is_present "$fetch_completed_at_utc"; then
    ((fetcher_metadata_rows += 1))
  fi
  if hash_matches_uri "$fetcher_tool_uri" "$fetcher_tool_hash"; then
    ((fetcher_tool_hash_verified_rows += 1))
  fi
  if [[ "$http_status" == "200" ]]; then
    ((http_ok_rows += 1))
  fi
  if [[ "$runner_owned_fetch" == "1" ]]; then
    ((runner_owned_fetch_rows += 1))
  fi
  if [[ "$cache_hash_verified" == "1" ]]; then
    ((cache_hash_verified_rows += 1))
  fi
  if [[ "$network_fetch_performed" == "1" ]]; then
    ((network_fetch_rows += 1))
  fi
  if [[ "$offline_replay_used" == "1" ]]; then
    ((offline_replay_rows += 1))
  fi
  if [[ "$real_live_fetch_declared" == "1" ]]; then
    ((declared_real_fetch_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  fetch_routing="$(awk -v a="$fetch_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  fetch_jump="$(awk -v a="$fetch_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$FETCH_TSV"

source_import_live_registry_fetcher_ready=0
if [[ "$source_import_live_registry_query_ready" == "1" &&
      "$expected_live_registry_query_rows" -gt 0 &&
      "$expected_query_rows_seen" -eq "$expected_live_registry_query_rows" &&
      "$fetch_rows" -eq "$expected_live_registry_query_rows" &&
      "$matched_query_rows" -eq "$expected_live_registry_query_rows" &&
      "$source_import_id_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$live_registry_query_id_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$registry_uri_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$registry_response_uri_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$registry_response_hash_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$registry_entry_response_uri_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$registry_entry_response_hash_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$cache_uri_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$cache_hash_match_rows" -eq "$expected_live_registry_query_rows" &&
      "$registry_cache_hash_verified_rows" -eq "$expected_live_registry_query_rows" &&
      "$registry_entry_cache_hash_verified_rows" -eq "$expected_live_registry_query_rows" &&
      "$fetcher_metadata_rows" -eq "$expected_live_registry_query_rows" &&
      "$fetcher_tool_hash_verified_rows" -eq "$expected_live_registry_query_rows" &&
      "$http_ok_rows" -eq "$expected_live_registry_query_rows" &&
      "$runner_owned_fetch_rows" -eq "$expected_live_registry_query_rows" &&
      "$cache_hash_verified_rows" -eq "$expected_live_registry_query_rows" &&
      "$query_routing" == "0.000000" &&
      "$query_jump" == "0.000000" &&
      "$fetch_routing" == "0.000000" &&
      "$fetch_jump" == "0.000000" ]]; then
  source_import_live_registry_fetcher_ready=1
fi

source_import_live_registry_fetch_ready=0
if [[ "$source_import_live_registry_fetcher_ready" == "1" &&
      "$network_fetch_rows" -eq "$expected_live_registry_query_rows" &&
      "$offline_replay_rows" -eq 0 &&
      "$declared_real_fetch_rows" -eq "$expected_live_registry_query_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_live_registry_query_rows" ]]; then
  source_import_live_registry_fetch_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$query_action"
if [[ "$source_import_live_registry_query_ready" == "1" ]]; then
  if [[ "$fetch_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-live-registry-fetch-missing"
  elif [[ "$fetch_rows" -ne "$expected_live_registry_query_rows" ||
          "$matched_query_rows" -ne "$expected_live_registry_query_rows" ||
          "$source_import_id_match_rows" -ne "$expected_live_registry_query_rows" ||
          "$live_registry_query_id_match_rows" -ne "$expected_live_registry_query_rows" ||
          "$registry_uri_match_rows" -ne "$expected_live_registry_query_rows" ||
          "$registry_response_uri_match_rows" -ne "$expected_live_registry_query_rows" ||
          "$registry_entry_response_uri_match_rows" -ne "$expected_live_registry_query_rows" ]]; then
    action="external-benchmark-source-import-live-registry-fetch-row-mismatch"
  elif [[ "$registry_response_hash_match_rows" -ne "$expected_live_registry_query_rows" ||
          "$registry_entry_response_hash_match_rows" -ne "$expected_live_registry_query_rows" ||
          "$cache_hash_match_rows" -ne "$expected_live_registry_query_rows" ]]; then
    action="external-benchmark-source-import-live-registry-fetch-hash-mismatch"
  elif [[ "$registry_cache_hash_verified_rows" -ne "$expected_live_registry_query_rows" ||
          "$registry_entry_cache_hash_verified_rows" -ne "$expected_live_registry_query_rows" ||
          "$cache_hash_verified_rows" -ne "$expected_live_registry_query_rows" ]]; then
    action="external-benchmark-source-import-live-registry-fetch-cache-missing"
  elif [[ "$fetcher_metadata_rows" -ne "$expected_live_registry_query_rows" ||
          "$fetcher_tool_hash_verified_rows" -ne "$expected_live_registry_query_rows" ]]; then
    action="external-benchmark-source-import-live-registry-fetch-artifact-missing"
  elif [[ "$source_import_live_registry_fetcher_ready" != "1" ]]; then
    action="external-benchmark-source-import-live-registry-fetcher-missing"
  elif [[ "$source_import_live_registry_fetch_ready" != "1" ]]; then
    action="external-benchmark-source-import-live-registry-network-fetch-proof-missing"
  elif [[ "$source_import_live_registry_fetch_ready" == "1" ]]; then
    action="external-benchmark-source-import-live-registry-fetch-fixture-only"
  fi
fi

total_routing="$(awk -v a="$query_routing" -v b="$fetch_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$query_jump" -v b="$fetch_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_contract_ready,source_import_verifier_ready,source_import_live_verifier_ready,source_import_independent_live_review_ready,source_import_authoritative_review_ready,source_import_public_registry_ready,source_import_live_registry_query_ready,live_registry_query_source,expected_live_registry_query_rows,registry_query_rows,runner_owned_registry_query_ready,live_registry_fetch_source,expected_live_registry_fetch_rows,fetch_rows,matched_query_rows,source_import_id_match_rows,live_registry_query_id_match_rows,registry_uri_match_rows,registry_response_uri_match_rows,registry_response_hash_match_rows,registry_entry_response_uri_match_rows,registry_entry_response_hash_match_rows,cache_uri_match_rows,cache_hash_match_rows,registry_cache_hash_verified_rows,registry_entry_cache_hash_verified_rows,fetcher_metadata_rows,fetcher_tool_hash_verified_rows,http_ok_rows,runner_owned_fetch_rows,cache_hash_verified_rows,network_fetch_rows,offline_replay_rows,declared_real_fetch_rows,non_fixture_declared_rows,source_import_live_registry_fetcher_ready,source_import_live_registry_fetch_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  join_by_comma \
    route-memory-v08t \
    "$benchmark_families" \
    "$source_import_contract_ready" \
    "$source_import_verifier_ready" \
    "$source_import_live_verifier_ready" \
    "$source_import_independent_live_review_ready" \
    "$source_import_authoritative_review_ready" \
    "$source_import_public_registry_ready" \
    "$source_import_live_registry_query_ready" \
    v08-s \
    "$expected_live_registry_query_rows" \
    "$registry_query_rows" \
    "$upstream_runner_owned_registry_query_ready" \
    "$FETCH_SOURCE" \
    "$expected_live_registry_query_rows" \
    "$fetch_rows" \
    "$matched_query_rows" \
    "$source_import_id_match_rows" \
    "$live_registry_query_id_match_rows" \
    "$registry_uri_match_rows" \
    "$registry_response_uri_match_rows" \
    "$registry_response_hash_match_rows" \
    "$registry_entry_response_uri_match_rows" \
    "$registry_entry_response_hash_match_rows" \
    "$cache_uri_match_rows" \
    "$cache_hash_match_rows" \
    "$registry_cache_hash_verified_rows" \
    "$registry_entry_cache_hash_verified_rows" \
    "$fetcher_metadata_rows" \
    "$fetcher_tool_hash_verified_rows" \
    "$http_ok_rows" \
    "$runner_owned_fetch_rows" \
    "$cache_hash_verified_rows" \
    "$network_fetch_rows" \
    "$offline_replay_rows" \
    "$declared_real_fetch_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_live_registry_fetcher_ready" \
    "$source_import_live_registry_fetch_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-live-registry-query,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_live_registry_query_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_query_ready" \
    "$query_action"
  printf "live-registry-fetch-rows,%s,rows=%d expected=%d matched=%d source_import_ids=%d query_ids=%d\n" \
    "$([[ "$fetch_rows" -eq "$expected_live_registry_query_rows" && "$matched_query_rows" -eq "$expected_live_registry_query_rows" && "$source_import_id_match_rows" -eq "$expected_live_registry_query_rows" && "$live_registry_query_id_match_rows" -eq "$expected_live_registry_query_rows" && "$expected_live_registry_query_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$fetch_rows" \
    "$expected_live_registry_query_rows" \
    "$matched_query_rows" \
    "$source_import_id_match_rows" \
    "$live_registry_query_id_match_rows"
  printf "live-registry-fetch-cache,%s,response_hash=%d/%d entry_hash=%d/%d cache_hash=%d/%d registry_cache_verified=%d/%d entry_cache_verified=%d/%d flag=%d/%d\n" \
    "$([[ "$registry_response_hash_match_rows" -eq "$expected_live_registry_query_rows" && "$registry_entry_response_hash_match_rows" -eq "$expected_live_registry_query_rows" && "$cache_hash_match_rows" -eq "$expected_live_registry_query_rows" && "$registry_cache_hash_verified_rows" -eq "$expected_live_registry_query_rows" && "$registry_entry_cache_hash_verified_rows" -eq "$expected_live_registry_query_rows" && "$cache_hash_verified_rows" -eq "$expected_live_registry_query_rows" && "$expected_live_registry_query_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$registry_response_hash_match_rows" \
    "$expected_live_registry_query_rows" \
    "$registry_entry_response_hash_match_rows" \
    "$expected_live_registry_query_rows" \
    "$cache_hash_match_rows" \
    "$expected_live_registry_query_rows" \
    "$registry_cache_hash_verified_rows" \
    "$expected_live_registry_query_rows" \
    "$registry_entry_cache_hash_verified_rows" \
    "$expected_live_registry_query_rows" \
    "$cache_hash_verified_rows" \
    "$expected_live_registry_query_rows"
  printf "runner-owned-live-registry-fetcher,%s,ready=%d source=%s metadata=%d/%d tool_hash=%d/%d runner=%d/%d\n" \
    "$([[ "$source_import_live_registry_fetcher_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_fetcher_ready" \
    "$FETCH_SOURCE" \
    "$fetcher_metadata_rows" \
    "$expected_live_registry_query_rows" \
    "$fetcher_tool_hash_verified_rows" \
    "$expected_live_registry_query_rows" \
    "$runner_owned_fetch_rows" \
    "$expected_live_registry_query_rows"
  printf "live-registry-network-fetch-proof,%s,ready=%d network=%d/%d replay=%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$source_import_live_registry_fetch_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_fetch_ready" \
    "$network_fetch_rows" \
    "$expected_live_registry_query_rows" \
    "$offline_replay_rows" \
    "$declared_real_fetch_rows" \
    "$expected_live_registry_query_rows" \
    "$non_fixture_declared_rows" \
    "$expected_live_registry_query_rows"
  printf "source-import-verification,%s,verified=%d live_registry_fetch_ready=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$source_import_live_registry_fetch_ready" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
