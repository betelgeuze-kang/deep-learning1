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

PREFIX="v08_external_benchmark_source_import_live_registry_query_gate"
PUBLIC_REGISTRY_PREFIX="v08_external_benchmark_source_import_public_registry_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_live_registry_query_gate_smoke"
  PUBLIC_REGISTRY_PREFIX="v08_external_benchmark_source_import_public_registry_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_public_registry_gate.sh" "${RUN_ARGS[@]}" >/dev/null

PUBLIC_REGISTRY_SUMMARY_CSV="$RESULTS_DIR/${PUBLIC_REGISTRY_PREFIX}_summary.csv"
PUBLIC_REGISTRY_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV:-$RESULTS_DIR/${PUBLIC_REGISTRY_PREFIX}_registry.csv}"
LIVE_REGISTRY_QUERY_CSV="$RESULTS_DIR/${PREFIX}_query.csv"
LIVE_REGISTRY_QUERY_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_live_registry_query_header() {
  echo "benchmark_family,source_import_id,authority_review_id,registry_entry_id,public_registry_uri,public_registry_hash,registry_entry_uri,registry_entry_hash,live_registry_query_id,query_runner_id,query_tool_uri,query_tool_hash,query_command_hash,query_started_at_utc,query_completed_at_utc,http_status,registry_response_uri,registry_response_hash,registry_entry_response_uri,registry_entry_response_hash,registry_lookup_hash,stdout_hash,stderr_hash,network_query_performed,offline_replay_used,runner_owned_query,query_output_hash_verified,real_live_query_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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

PUBLIC_REGISTRY_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready expected_public_registry_rows public_registry_rows source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-s public registry summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_contract_ready"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_live_verifier_ready"] + 0,
        $idx["source_import_independent_live_review_ready"] + 0,
        $idx["source_import_authoritative_review_ready"] + 0,
        $idx["source_import_public_registry_ready"] + 0,
        $idx["expected_public_registry_rows"] + 0,
        $idx["public_registry_rows"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-s public registry summary row", 3)
    }
  ' "$PUBLIC_REGISTRY_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready expected_public_registry_rows public_registry_rows upstream_source_import_verified public_registry_action public_registry_routing public_registry_jump <<<"$PUBLIC_REGISTRY_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV:-}" ]]; then
  LIVE_REGISTRY_QUERY_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV"
  LIVE_REGISTRY_QUERY_SOURCE="provided-csv"
  if [[ ! -s "$LIVE_REGISTRY_QUERY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
elif [[ "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_REPLAY:-0}" == "1" ]]; then
  LIVE_REGISTRY_QUERY_SOURCE="runner-owned-replay"
  script_hash="$(sha_file_uri "$0")"
  script_uri="file://$0"
  {
    write_live_registry_query_header
    awk -F, '
      function die(message, code) {
        print message > "/dev/stderr"
        exit code
      }
      NR == 1 {
        header_fields = NF
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08-s replay source column: " required[i], 4)
        }
        next
      }
      {
        if (NF != header_fields) die("v08-s replay source row has wrong column count", 5)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["authority_review_id"],
          $idx["registry_entry_id"],
          $idx["public_registry_uri"],
          $idx["public_registry_hash"],
          $idx["registry_entry_uri"],
          $idx["registry_entry_hash"]
      }
    ' "$PUBLIC_REGISTRY_CSV" |
    while IFS=$'\t' read -r benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash; do
      query_id="live-registry-query-replay-${benchmark_family//[^A-Za-z0-9]/-}"
      runner_id="betelgeuze-live-registry-query-replay-v1"
      command_hash="$(sha_text_uri "GET ${public_registry_uri} ${registry_entry_uri} ${source_import_id}")"
      lookup_hash="$(sha_text_uri "${benchmark_family}|${source_import_id}|${authority_review_id}|${registry_entry_id}")"
      stdout_hash="$(sha_text_uri "${benchmark_family}|${public_registry_hash}|${registry_entry_hash}")"
      stderr_hash="$(sha_text_uri "")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-05-31T00:00:00Z,2026-05-31T00:00:01Z,200,%s,%s,%s,%s,%s,%s,%s,0,1,1,1,0,1,0,0\n" \
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
  } >"$LIVE_REGISTRY_QUERY_CSV"
else
  write_live_registry_query_header >"$LIVE_REGISTRY_QUERY_CSV"
fi

declare -A expected_source_import_id
declare -A expected_authority_review_id
declare -A expected_registry_entry_id
declare -A expected_public_registry_uri
declare -A expected_public_registry_hash
declare -A expected_registry_entry_uri
declare -A expected_registry_entry_hash

expected_public_registry_rows_seen=0
if [[ -s "$PUBLIC_REGISTRY_CSV" ]]; then
  PUBLIC_REGISTRY_TSV="$TMP_DIR/public_registry.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-s public registry source column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-s public registry source row has wrong column count", 11)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["source_import_id"],
        $idx["authority_review_id"],
        $idx["registry_entry_id"],
        $idx["public_registry_uri"],
        $idx["public_registry_hash"],
        $idx["registry_entry_uri"],
        $idx["registry_entry_hash"]
    }
  ' "$PUBLIC_REGISTRY_CSV" >"$PUBLIC_REGISTRY_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-s public registry family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_authority_review_id["$benchmark_family"]="$authority_review_id"
    expected_registry_entry_id["$benchmark_family"]="$registry_entry_id"
    expected_public_registry_uri["$benchmark_family"]="$public_registry_uri"
    expected_public_registry_hash["$benchmark_family"]="$public_registry_hash"
    expected_registry_entry_uri["$benchmark_family"]="$registry_entry_uri"
    expected_registry_entry_hash["$benchmark_family"]="$registry_entry_hash"
    ((expected_public_registry_rows_seen += 1))
  done <"$PUBLIC_REGISTRY_TSV"
fi

registry_query_rows=0
matched_public_registry_rows=0
source_import_id_match_rows=0
authority_review_id_match_rows=0
registry_entry_id_match_rows=0
registry_uri_match_rows=0
registry_hash_match_rows=0
registry_entry_uri_match_rows=0
registry_entry_hash_match_rows=0
query_metadata_rows=0
http_ok_rows=0
query_tool_hash_verified_rows=0
query_output_hash_match_rows=0
query_output_hash_verified_rows=0
runner_owned_query_rows=0
network_query_rows=0
offline_replay_rows=0
declared_real_query_rows=0
non_fixture_declared_rows=0
query_routing="0.000000"
query_jump="0.000000"
declare -A query_seen

QUERY_TSV="$TMP_DIR/live_registry_query.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash live_registry_query_id query_runner_id query_tool_uri query_tool_hash query_command_hash query_started_at_utc query_completed_at_utc http_status registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash registry_lookup_hash stdout_hash stderr_hash network_query_performed offline_replay_used runner_owned_query query_output_hash_verified real_live_query_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-s live registry query column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-s live registry query row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["authority_review_id"],
      $idx["registry_entry_id"],
      $idx["public_registry_uri"],
      $idx["public_registry_hash"],
      $idx["registry_entry_uri"],
      $idx["registry_entry_hash"],
      $idx["live_registry_query_id"],
      $idx["query_runner_id"],
      $idx["query_tool_uri"],
      $idx["query_tool_hash"],
      $idx["query_command_hash"],
      $idx["query_started_at_utc"],
      $idx["query_completed_at_utc"],
      $idx["http_status"] + 0,
      $idx["registry_response_uri"],
      $idx["registry_response_hash"],
      $idx["registry_entry_response_uri"],
      $idx["registry_entry_response_hash"],
      $idx["registry_lookup_hash"],
      $idx["stdout_hash"],
      $idx["stderr_hash"],
      $idx["network_query_performed"] + 0,
      $idx["offline_replay_used"] + 0,
      $idx["runner_owned_query"] + 0,
      $idx["query_output_hash_verified"] + 0,
      $idx["real_live_query_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0
  }
' "$LIVE_REGISTRY_QUERY_CSV" >"$QUERY_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash live_registry_query_id query_runner_id query_tool_uri query_tool_hash query_command_hash query_started_at_utc query_completed_at_utc http_status registry_response_uri registry_response_hash registry_entry_response_uri registry_entry_response_hash registry_lookup_hash stdout_hash stderr_hash network_query_performed offline_replay_used runner_owned_query query_output_hash_verified real_live_query_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((registry_query_rows += 1))
  if [[ -n "${query_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-s live registry query family: $benchmark_family" >&2
    exit 15
  fi
  query_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_public_registry_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_authority_review_id[$benchmark_family]:-}" == "$authority_review_id" ]] && is_present "$authority_review_id"; then
    ((authority_review_id_match_rows += 1))
  fi
  if [[ "${expected_registry_entry_id[$benchmark_family]:-}" == "$registry_entry_id" ]] && is_present "$registry_entry_id"; then
    ((registry_entry_id_match_rows += 1))
  fi
  if [[ "${expected_public_registry_uri[$benchmark_family]:-}" == "$public_registry_uri" ]] && is_present "$public_registry_uri"; then
    ((registry_uri_match_rows += 1))
  fi
  if [[ "${expected_public_registry_hash[$benchmark_family]:-}" == "$public_registry_hash" ]] && is_sha256 "$public_registry_hash"; then
    ((registry_hash_match_rows += 1))
  fi
  if [[ "${expected_registry_entry_uri[$benchmark_family]:-}" == "$registry_entry_uri" ]] && is_present "$registry_entry_uri"; then
    ((registry_entry_uri_match_rows += 1))
  fi
  if [[ "${expected_registry_entry_hash[$benchmark_family]:-}" == "$registry_entry_hash" ]] && is_sha256 "$registry_entry_hash"; then
    ((registry_entry_hash_match_rows += 1))
  fi

  if is_present "$live_registry_query_id" &&
      is_present "$query_runner_id" &&
      is_present "$query_tool_uri" &&
      is_sha256 "$query_tool_hash" &&
      is_sha256 "$query_command_hash" &&
      is_present "$query_started_at_utc" &&
      is_present "$query_completed_at_utc" &&
      is_present "$registry_response_uri" &&
      is_sha256 "$registry_response_hash" &&
      is_present "$registry_entry_response_uri" &&
      is_sha256 "$registry_entry_response_hash" &&
      is_sha256 "$registry_lookup_hash" &&
      is_sha256 "$stdout_hash" &&
      is_sha256 "$stderr_hash"; then
    ((query_metadata_rows += 1))
  fi
  if [[ "$http_status" == "200" ]]; then
    ((http_ok_rows += 1))
  fi
  if hash_matches_uri "$query_tool_uri" "$query_tool_hash"; then
    ((query_tool_hash_verified_rows += 1))
  fi
  if [[ "${expected_public_registry_hash[$benchmark_family]:-}" == "$registry_response_hash" &&
        "${expected_registry_entry_hash[$benchmark_family]:-}" == "$registry_entry_response_hash" ]] &&
      is_sha256 "$registry_response_hash" &&
      is_sha256 "$registry_entry_response_hash"; then
    ((query_output_hash_match_rows += 1))
  fi
  if [[ "$query_output_hash_verified" == "1" ]]; then
    ((query_output_hash_verified_rows += 1))
  fi
  if [[ "$runner_owned_query" == "1" ]]; then
    ((runner_owned_query_rows += 1))
  fi
  if [[ "$network_query_performed" == "1" ]]; then
    ((network_query_rows += 1))
  fi
  if [[ "$offline_replay_used" == "1" ]]; then
    ((offline_replay_rows += 1))
  fi
  if [[ "$real_live_query_declared" == "1" ]]; then
    ((declared_real_query_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  query_routing="$(awk -v a="$query_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  query_jump="$(awk -v a="$query_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$QUERY_TSV"

runner_owned_registry_query_ready=0
if [[ "$source_import_public_registry_ready" == "1" &&
      "$expected_public_registry_rows" -gt 0 &&
      "$expected_public_registry_rows_seen" -eq "$expected_public_registry_rows" &&
      "$registry_query_rows" -eq "$expected_public_registry_rows" &&
      "$matched_public_registry_rows" -eq "$expected_public_registry_rows" &&
      "$source_import_id_match_rows" -eq "$expected_public_registry_rows" &&
      "$authority_review_id_match_rows" -eq "$expected_public_registry_rows" &&
      "$registry_entry_id_match_rows" -eq "$expected_public_registry_rows" &&
      "$registry_uri_match_rows" -eq "$expected_public_registry_rows" &&
      "$registry_hash_match_rows" -eq "$expected_public_registry_rows" &&
      "$registry_entry_uri_match_rows" -eq "$expected_public_registry_rows" &&
      "$registry_entry_hash_match_rows" -eq "$expected_public_registry_rows" &&
      "$query_metadata_rows" -eq "$expected_public_registry_rows" &&
      "$query_tool_hash_verified_rows" -eq "$expected_public_registry_rows" &&
      "$query_output_hash_match_rows" -eq "$expected_public_registry_rows" &&
      "$query_output_hash_verified_rows" -eq "$expected_public_registry_rows" &&
      "$runner_owned_query_rows" -eq "$expected_public_registry_rows" &&
      "$public_registry_routing" == "0.000000" &&
      "$public_registry_jump" == "0.000000" &&
      "$query_routing" == "0.000000" &&
      "$query_jump" == "0.000000" ]]; then
  runner_owned_registry_query_ready=1
fi

source_import_live_registry_query_ready=0
if [[ "$runner_owned_registry_query_ready" == "1" &&
      "$network_query_rows" -eq "$expected_public_registry_rows" &&
      "$offline_replay_rows" -eq 0 &&
      "$http_ok_rows" -eq "$expected_public_registry_rows" &&
      "$declared_real_query_rows" -eq "$expected_public_registry_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_public_registry_rows" ]]; then
  source_import_live_registry_query_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$public_registry_action"
if [[ "$source_import_public_registry_ready" == "1" ]]; then
  if [[ "$registry_query_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-live-registry-query-missing"
  elif [[ "$registry_query_rows" -ne "$expected_public_registry_rows" ||
          "$matched_public_registry_rows" -ne "$expected_public_registry_rows" ||
          "$source_import_id_match_rows" -ne "$expected_public_registry_rows" ||
          "$authority_review_id_match_rows" -ne "$expected_public_registry_rows" ||
          "$registry_entry_id_match_rows" -ne "$expected_public_registry_rows" ||
          "$registry_uri_match_rows" -ne "$expected_public_registry_rows" ||
          "$registry_entry_uri_match_rows" -ne "$expected_public_registry_rows" ]]; then
    action="external-benchmark-source-import-live-registry-query-row-mismatch"
  elif [[ "$registry_hash_match_rows" -ne "$expected_public_registry_rows" ||
          "$registry_entry_hash_match_rows" -ne "$expected_public_registry_rows" ||
          "$query_output_hash_match_rows" -ne "$expected_public_registry_rows" ||
          "$query_output_hash_verified_rows" -ne "$expected_public_registry_rows" ]]; then
    action="external-benchmark-source-import-live-registry-query-output-mismatch"
  elif [[ "$query_metadata_rows" -ne "$expected_public_registry_rows" ||
          "$query_tool_hash_verified_rows" -ne "$expected_public_registry_rows" ]]; then
    action="external-benchmark-source-import-live-registry-query-artifact-missing"
  elif [[ "$runner_owned_registry_query_ready" != "1" ]]; then
    action="external-benchmark-source-import-runner-owned-registry-query-missing"
  elif [[ "$source_import_live_registry_query_ready" != "1" ]]; then
    action="external-benchmark-source-import-live-registry-network-fetch-missing"
  elif [[ "$source_import_live_registry_query_ready" == "1" ]]; then
    action="external-benchmark-source-import-live-registry-query-fixture-only"
  fi
fi

total_routing="$(awk -v a="$public_registry_routing" -v b="$query_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$public_registry_jump" -v b="$query_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_contract_ready,source_import_verifier_ready,source_import_live_verifier_ready,source_import_independent_live_review_ready,source_import_authoritative_review_ready,source_import_public_registry_ready,public_registry_source,expected_public_registry_rows,public_registry_rows,live_registry_query_source,expected_live_registry_query_rows,registry_query_rows,matched_public_registry_rows,source_import_id_match_rows,authority_review_id_match_rows,registry_entry_id_match_rows,registry_uri_match_rows,registry_hash_match_rows,registry_entry_uri_match_rows,registry_entry_hash_match_rows,query_metadata_rows,http_ok_rows,query_tool_hash_verified_rows,query_output_hash_match_rows,query_output_hash_verified_rows,runner_owned_query_rows,network_query_rows,offline_replay_rows,declared_real_query_rows,non_fixture_declared_rows,runner_owned_registry_query_ready,source_import_live_registry_query_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  join_by_comma \
    route-memory-v08s \
    "$benchmark_families" \
    "$source_import_contract_ready" \
    "$source_import_verifier_ready" \
    "$source_import_live_verifier_ready" \
    "$source_import_independent_live_review_ready" \
    "$source_import_authoritative_review_ready" \
    "$source_import_public_registry_ready" \
    "v08-r" \
    "$expected_public_registry_rows" \
    "$public_registry_rows" \
    "$LIVE_REGISTRY_QUERY_SOURCE" \
    "$expected_public_registry_rows" \
    "$registry_query_rows" \
    "$matched_public_registry_rows" \
    "$source_import_id_match_rows" \
    "$authority_review_id_match_rows" \
    "$registry_entry_id_match_rows" \
    "$registry_uri_match_rows" \
    "$registry_hash_match_rows" \
    "$registry_entry_uri_match_rows" \
    "$registry_entry_hash_match_rows" \
    "$query_metadata_rows" \
    "$http_ok_rows" \
    "$query_tool_hash_verified_rows" \
    "$query_output_hash_match_rows" \
    "$query_output_hash_verified_rows" \
    "$runner_owned_query_rows" \
    "$network_query_rows" \
    "$offline_replay_rows" \
    "$declared_real_query_rows" \
    "$non_fixture_declared_rows" \
    "$runner_owned_registry_query_ready" \
    "$source_import_live_registry_query_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-public-registry,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_public_registry_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_public_registry_ready" \
    "$public_registry_action"
  printf "live-registry-query-rows,%s,rows=%d expected=%d matched=%d source_import_ids=%d authority_reviews=%d registry_entries=%d\n" \
    "$([[ "$registry_query_rows" -eq "$expected_public_registry_rows" && "$matched_public_registry_rows" -eq "$expected_public_registry_rows" && "$source_import_id_match_rows" -eq "$expected_public_registry_rows" && "$authority_review_id_match_rows" -eq "$expected_public_registry_rows" && "$registry_entry_id_match_rows" -eq "$expected_public_registry_rows" && "$expected_public_registry_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$registry_query_rows" \
    "$expected_public_registry_rows" \
    "$matched_public_registry_rows" \
    "$source_import_id_match_rows" \
    "$authority_review_id_match_rows" \
    "$registry_entry_id_match_rows"
  printf "live-registry-query-chain,%s,registry_uri=%d/%d registry_hash=%d/%d entry_uri=%d/%d entry_hash=%d/%d output_hash=%d/%d verified=%d/%d\n" \
    "$([[ "$registry_uri_match_rows" -eq "$expected_public_registry_rows" && "$registry_hash_match_rows" -eq "$expected_public_registry_rows" && "$registry_entry_uri_match_rows" -eq "$expected_public_registry_rows" && "$registry_entry_hash_match_rows" -eq "$expected_public_registry_rows" && "$query_output_hash_match_rows" -eq "$expected_public_registry_rows" && "$query_output_hash_verified_rows" -eq "$expected_public_registry_rows" && "$expected_public_registry_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$registry_uri_match_rows" \
    "$expected_public_registry_rows" \
    "$registry_hash_match_rows" \
    "$expected_public_registry_rows" \
    "$registry_entry_uri_match_rows" \
    "$expected_public_registry_rows" \
    "$registry_entry_hash_match_rows" \
    "$expected_public_registry_rows" \
    "$query_output_hash_match_rows" \
    "$expected_public_registry_rows" \
    "$query_output_hash_verified_rows" \
    "$expected_public_registry_rows"
  printf "runner-owned-registry-query,%s,ready=%d source=%s metadata=%d/%d tool_hash=%d/%d runner=%d/%d\n" \
    "$([[ "$runner_owned_registry_query_ready" == "1" ]] && echo pass || echo blocked)" \
    "$runner_owned_registry_query_ready" \
    "$LIVE_REGISTRY_QUERY_SOURCE" \
    "$query_metadata_rows" \
    "$expected_public_registry_rows" \
    "$query_tool_hash_verified_rows" \
    "$expected_public_registry_rows" \
    "$runner_owned_query_rows" \
    "$expected_public_registry_rows"
  printf "live-registry-network-fetch,%s,ready=%d network=%d/%d replay=%d http_ok=%d/%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$source_import_live_registry_query_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_query_ready" \
    "$network_query_rows" \
    "$expected_public_registry_rows" \
    "$offline_replay_rows" \
    "$http_ok_rows" \
    "$expected_public_registry_rows" \
    "$declared_real_query_rows" \
    "$expected_public_registry_rows" \
    "$non_fixture_declared_rows" \
    "$expected_public_registry_rows"
  printf "source-import-verification,%s,verified=%d live_registry_query_ready=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$source_import_live_registry_query_ready" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
