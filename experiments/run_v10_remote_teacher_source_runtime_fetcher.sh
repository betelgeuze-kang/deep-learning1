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

PREFIX="v10_remote_teacher_source_runtime_fetcher"
FETCH_PREFIX="v10_remote_teacher_source_live_fetch_attestation"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_remote_teacher_source_runtime_fetcher_smoke"
  FETCH_PREFIX="v10_remote_teacher_source_live_fetch_attestation_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh" "${RUN_ARGS[@]}" >/dev/null

FETCH_ATTESTATION_CSV="${V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV:-$RESULTS_DIR/${FETCH_PREFIX}_fetch_attestation.csv}"
FETCH_SUMMARY_CSV="$RESULTS_DIR/${FETCH_PREFIX}_summary.csv"
RUNTIME_CSV="$RESULTS_DIR/${PREFIX}_runtime_fetch.csv"
RUNTIME_SOURCE="pending-fixture"

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

is_present() {
  local value="$1"
  [[ "$value" != "" && "$value" != "pending" ]]
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

write_runtime_header() {
  echo "teacher_id,artifact_kind,remote_uri,cache_uri,content_hash,runtime_fetch_id,fetcher_runner_id,fetcher_binary_uri,fetcher_binary_hash,fetch_command_hash,fetch_started_at_utc,fetch_completed_at_utc,exit_code,stdout_hash,stderr_hash,network_fetch_performed,offline_replay_used,runner_owned_fetch,download_cache_uri,download_content_hash,output_hash_verified,runtime_fetch_ready,real_runtime_fetch_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
}

if [[ -n "${V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV:-}" ]]; then
  RUNTIME_CSV="$V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV"
  RUNTIME_SOURCE="provided-csv"
  if [[ ! -s "$RUNTIME_CSV" ]]; then
    echo "V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
elif [[ "${V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_REPLAY:-0}" == "1" ]]; then
  RUNTIME_SOURCE="runner-owned-replay"
  script_hash="$(sha_file_uri "$0")"
  script_uri="file://$0"
  {
    write_runtime_header
    awk -F, '
      function die(message, code) {
        print message > "/dev/stderr"
        exit code
      }
      NR == 1 {
        header_fields = NF
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("teacher_id artifact_kind remote_uri cache_uri content_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing h10-p replay source column: " required[i], 2)
        }
        next
      }
      {
        if (NF != header_fields) die("h10-p replay source row has wrong column count", 3)
        printf "%s\t%s\t%s\t%s\t%s\n",
          $idx["teacher_id"],
          $idx["artifact_kind"],
          $idx["remote_uri"],
          $idx["cache_uri"],
          $idx["content_hash"]
      }
    ' "$FETCH_ATTESTATION_CSV" |
    while IFS=$'\t' read -r teacher_id artifact_kind remote_uri cache_uri content_hash; do
      runtime_id="runtime-replay-${teacher_id}-${artifact_kind}"
      runner_id="betelgeuze-runtime-fetcher-replay-v1"
      command_hash="$(sha_text_uri "GET ${remote_uri} ${content_hash}")"
      stdout_hash="$(sha_text_uri "${teacher_id}|${artifact_kind}|${content_hash}")"
      stderr_hash="$(sha_text_uri "")"
      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,2026-05-28T00:00:00Z,2026-05-28T00:00:01Z,0,%s,%s,0,1,1,%s,%s,1,1,0,1,0,0\n" \
        "$teacher_id" \
        "$artifact_kind" \
        "$remote_uri" \
        "$cache_uri" \
        "$content_hash" \
        "$runtime_id" \
        "$runner_id" \
        "$script_uri" \
        "$script_hash" \
        "$command_hash" \
        "$stdout_hash" \
        "$stderr_hash" \
        "$cache_uri" \
        "$content_hash"
    done
  } >"$RUNTIME_CSV"
else
  write_runtime_header >"$RUNTIME_CSV"
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

FETCH_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("fetch_attestation_source expected_fetch_artifact_rows fetch_attestation_rows remote_teacher_source_live_fetch_attestation_ready real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-p fetch-attestation summary column: " required[i], 4)
      }
      next
    }
    {
      rows++
      printf "%s,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["fetch_attestation_source"],
        $idx["expected_fetch_artifact_rows"] + 0,
        $idx["fetch_attestation_rows"] + 0,
        $idx["remote_teacher_source_live_fetch_attestation_ready"] + 0,
        $idx["real_teacher_source_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h10-p fetch-attestation summary row", 5)
    }
  ' "$FETCH_SUMMARY_CSV"
)"

IFS=, read -r fetch_attestation_source expected_fetch_rows fetch_attestation_rows live_fetch_attestation_ready fetch_real_verified fetch_action fetch_routing fetch_jump <<<"$FETCH_VALUES"

declare -A expected_remote_uri
declare -A expected_cache_uri
declare -A expected_content_hash
expected_rows_seen=0
FETCH_TSV="$TMP_DIR/fetch_attestation.tsv"

awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("teacher_id artifact_kind remote_uri cache_uri content_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-p fetch-attestation column: " required[i], 6)
      }
      next
    }
    {
      if (NF != header_fields) die("h10-p fetch-attestation row has wrong column count", 7)
      printf "%s\t%s\t%s\t%s\t%s\n",
        $idx["teacher_id"],
        $idx["artifact_kind"],
        $idx["remote_uri"],
        $idx["cache_uri"],
        $idx["content_hash"]
    }
  ' "$FETCH_ATTESTATION_CSV" >"$FETCH_TSV"

while IFS=$'\t' read -r teacher_id artifact_kind remote_uri cache_uri content_hash; do
  key="${teacher_id}|${artifact_kind}"
  if [[ -n "${expected_remote_uri[$key]:-}" ]]; then
    echo "duplicate h10-p fetch-attestation artifact: $key" >&2
    exit 8
  fi
  expected_remote_uri["$key"]="$remote_uri"
  expected_cache_uri["$key"]="$cache_uri"
  expected_content_hash["$key"]="$content_hash"
  ((expected_rows_seen += 1))
done <"$FETCH_TSV"

runtime_rows=0
matched_artifact_rows=0
remote_uri_match_rows=0
cache_uri_match_rows=0
content_hash_match_rows=0
download_cache_match_rows=0
download_hash_match_rows=0
download_cache_hash_verified_rows=0
fetcher_metadata_rows=0
runner_owned_fetch_rows=0
runtime_fetch_ready_rows=0
output_hash_verified_rows=0
network_fetch_rows=0
offline_replay_rows=0
declared_real_rows=0
non_fixture_declared_rows=0
runtime_routing="0.000000"
runtime_jump="0.000000"
declare -A runtime_seen
RUNTIME_TSV="$TMP_DIR/runtime_fetch.tsv"

awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("teacher_id artifact_kind remote_uri cache_uri content_hash runtime_fetch_id fetcher_runner_id fetcher_binary_uri fetcher_binary_hash fetch_command_hash fetch_started_at_utc fetch_completed_at_utc exit_code stdout_hash stderr_hash network_fetch_performed offline_replay_used runner_owned_fetch download_cache_uri download_content_hash output_hash_verified runtime_fetch_ready real_runtime_fetch_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-p runtime fetch column: " required[i], 9)
      }
      next
    }
    {
      if (NF != header_fields) die("h10-p runtime fetch row has wrong column count", 10)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%d\t%d\t%d\t%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["teacher_id"],
        $idx["artifact_kind"],
        $idx["remote_uri"],
        $idx["cache_uri"],
        $idx["content_hash"],
        $idx["runtime_fetch_id"],
        $idx["fetcher_runner_id"],
        $idx["fetcher_binary_uri"],
        $idx["fetcher_binary_hash"],
        $idx["fetch_command_hash"],
        $idx["fetch_started_at_utc"],
        $idx["fetch_completed_at_utc"],
        $idx["exit_code"] + 0,
        $idx["stdout_hash"],
        $idx["stderr_hash"],
        $idx["network_fetch_performed"] + 0,
        $idx["offline_replay_used"] + 0,
        $idx["runner_owned_fetch"] + 0,
        $idx["download_cache_uri"],
        $idx["download_content_hash"],
        $idx["output_hash_verified"] + 0,
        $idx["runtime_fetch_ready"] + 0,
        $idx["real_runtime_fetch_declared"] + 0,
        $idx["fixture_or_synthetic_declared"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$RUNTIME_CSV" >"$RUNTIME_TSV"

while IFS=$'\t' read -r teacher_id artifact_kind remote_uri cache_uri content_hash runtime_fetch_id fetcher_runner_id fetcher_binary_uri fetcher_binary_hash fetch_command_hash fetch_started fetch_completed exit_code stdout_hash stderr_hash network_fetch_performed offline_replay_used runner_owned_fetch download_cache_uri download_content_hash output_hash_verified runtime_fetch_ready real_runtime_fetch_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((runtime_rows += 1))
  key="${teacher_id}|${artifact_kind}"
  if [[ -n "${runtime_seen[$key]:-}" ]]; then
    echo "duplicate h10-p runtime fetch artifact: $key" >&2
    exit 11
  fi
  runtime_seen["$key"]=1

  if [[ -n "${expected_remote_uri[$key]:-}" ]]; then
    ((matched_artifact_rows += 1))
  fi
  if [[ "${expected_remote_uri[$key]:-}" == "$remote_uri" && -n "$remote_uri" ]]; then
    ((remote_uri_match_rows += 1))
  fi
  if [[ "${expected_cache_uri[$key]:-}" == "$cache_uri" && -n "$cache_uri" ]]; then
    ((cache_uri_match_rows += 1))
  fi
  if [[ "${expected_content_hash[$key]:-}" == "$content_hash" && -n "$content_hash" ]]; then
    ((content_hash_match_rows += 1))
  fi
  if [[ "${expected_cache_uri[$key]:-}" == "$download_cache_uri" && -n "$download_cache_uri" ]]; then
    ((download_cache_match_rows += 1))
  fi
  if [[ "${expected_content_hash[$key]:-}" == "$download_content_hash" && -n "$download_content_hash" ]]; then
    ((download_hash_match_rows += 1))
  fi
  if hash_matches_uri "$download_cache_uri" "$download_content_hash"; then
    ((download_cache_hash_verified_rows += 1))
  fi

  if is_present "$runtime_fetch_id" &&
      is_present "$fetcher_runner_id" &&
      is_present "$fetcher_binary_uri" &&
      is_sha256 "$fetcher_binary_hash" &&
      is_sha256 "$fetch_command_hash" &&
      is_present "$fetch_started" &&
      is_present "$fetch_completed" &&
      [[ "$exit_code" -eq 0 ]] &&
      is_sha256 "$stdout_hash" &&
      is_sha256 "$stderr_hash"; then
    ((fetcher_metadata_rows += 1))
  fi
  if [[ "$runner_owned_fetch" == "1" ]]; then
    ((runner_owned_fetch_rows += 1))
  fi
  if [[ "$runtime_fetch_ready" == "1" ]]; then
    ((runtime_fetch_ready_rows += 1))
  fi
  if [[ "$output_hash_verified" == "1" ]]; then
    ((output_hash_verified_rows += 1))
  fi
  if [[ "$network_fetch_performed" == "1" ]]; then
    ((network_fetch_rows += 1))
  fi
  if [[ "$offline_replay_used" == "1" ]]; then
    ((offline_replay_rows += 1))
  fi
  if [[ "$real_runtime_fetch_declared" == "1" ]]; then
    ((declared_real_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  runtime_routing="$(awk -v a="$runtime_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  runtime_jump="$(awk -v a="$runtime_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$RUNTIME_TSV"

runner_owned_runtime_fetcher_ready=0
if [[ "$live_fetch_attestation_ready" == "1" &&
      "$expected_fetch_rows" -gt 0 &&
      "$runtime_rows" -eq "$expected_fetch_rows" &&
      "$expected_rows_seen" -eq "$expected_fetch_rows" &&
      "$matched_artifact_rows" -eq "$expected_fetch_rows" &&
      "$remote_uri_match_rows" -eq "$expected_fetch_rows" &&
      "$cache_uri_match_rows" -eq "$expected_fetch_rows" &&
      "$content_hash_match_rows" -eq "$expected_fetch_rows" &&
      "$download_cache_match_rows" -eq "$expected_fetch_rows" &&
      "$download_hash_match_rows" -eq "$expected_fetch_rows" &&
      "$download_cache_hash_verified_rows" -eq "$expected_fetch_rows" &&
      "$fetcher_metadata_rows" -eq "$expected_fetch_rows" &&
      "$runner_owned_fetch_rows" -eq "$expected_fetch_rows" &&
      "$runtime_fetch_ready_rows" -eq "$expected_fetch_rows" &&
      "$output_hash_verified_rows" -eq "$expected_fetch_rows" &&
      "$fetch_routing" == "0.000000" &&
      "$fetch_jump" == "0.000000" &&
      "$runtime_routing" == "0.000000" &&
      "$runtime_jump" == "0.000000" ]]; then
  runner_owned_runtime_fetcher_ready=1
fi

live_network_fetch_ready=0
if [[ "$runner_owned_runtime_fetcher_ready" == "1" &&
      "$network_fetch_rows" -eq "$expected_fetch_rows" &&
      "$offline_replay_rows" -eq 0 &&
      "$declared_real_rows" -eq "$expected_fetch_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_fetch_rows" ]]; then
  live_network_fetch_ready=1
fi

real_teacher_source_verified=0
action="remote-teacher-source-fetch-attestation-not-ready"
if [[ "$live_fetch_attestation_ready" == "1" ]]; then
  if [[ "$runtime_rows" -eq 0 ]]; then
    action="remote-teacher-source-runtime-fetch-missing"
  elif [[ "$runtime_rows" -ne "$expected_fetch_rows" ||
          "$matched_artifact_rows" -ne "$expected_fetch_rows" ||
          "$remote_uri_match_rows" -ne "$expected_fetch_rows" ||
          "$cache_uri_match_rows" -ne "$expected_fetch_rows" ]]; then
    action="remote-teacher-source-runtime-fetch-artifact-mismatch"
  elif [[ "$content_hash_match_rows" -ne "$expected_fetch_rows" ||
          "$download_cache_match_rows" -ne "$expected_fetch_rows" ||
          "$download_hash_match_rows" -ne "$expected_fetch_rows" ||
          "$download_cache_hash_verified_rows" -ne "$expected_fetch_rows" ]]; then
    action="remote-teacher-source-runtime-fetch-content-hash-mismatch"
  elif [[ "$fetcher_metadata_rows" -ne "$expected_fetch_rows" ||
          "$runner_owned_fetch_rows" -ne "$expected_fetch_rows" ||
          "$runtime_fetch_ready_rows" -ne "$expected_fetch_rows" ||
          "$output_hash_verified_rows" -ne "$expected_fetch_rows" ]]; then
    action="remote-teacher-source-runtime-fetch-contract-incomplete"
  elif [[ "$runner_owned_runtime_fetcher_ready" == "1" && "$live_network_fetch_ready" == "0" ]]; then
    action="remote-teacher-source-live-network-fetch-missing"
  elif [[ "$live_network_fetch_ready" == "1" ]]; then
    action="remote-teacher-source-real-source-import-missing"
  fi
fi

total_routing="$(awk -v a="$fetch_routing" -v b="$runtime_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$fetch_jump" -v b="$runtime_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "teacher_source_runtime_scope,fetch_attestation_source,runtime_fetch_source,h10o_action,expected_runtime_artifact_rows,runtime_fetch_rows,matched_artifact_rows,remote_uri_match_rows,cache_uri_match_rows,content_hash_match_rows,download_cache_match_rows,download_hash_match_rows,download_cache_hash_verified_rows,fetcher_metadata_rows,runner_owned_fetch_rows,runtime_fetch_ready_rows,output_hash_verified_rows,network_fetch_rows,offline_replay_rows,declared_real_rows,non_fixture_declared_rows,remote_teacher_source_live_fetch_attestation_ready,runner_owned_runtime_fetcher_ready,live_network_fetch_ready,real_teacher_source_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-h10p,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$fetch_attestation_source" \
    "$RUNTIME_SOURCE" \
    "$fetch_action" \
    "$expected_fetch_rows" \
    "$runtime_rows" \
    "$matched_artifact_rows" \
    "$remote_uri_match_rows" \
    "$cache_uri_match_rows" \
    "$content_hash_match_rows" \
    "$download_cache_match_rows" \
    "$download_hash_match_rows" \
    "$download_cache_hash_verified_rows" \
    "$fetcher_metadata_rows" \
    "$runner_owned_fetch_rows" \
    "$runtime_fetch_ready_rows" \
    "$output_hash_verified_rows" \
    "$network_fetch_rows" \
    "$offline_replay_rows" \
    "$declared_real_rows" \
    "$non_fixture_declared_rows" \
    "$live_fetch_attestation_ready" \
    "$runner_owned_runtime_fetcher_ready" \
    "$live_network_fetch_ready" \
    "$real_teacher_source_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "live-fetch-attestation,%s,ready=%d h10o_action=%s\n" \
    "$([[ "$live_fetch_attestation_ready" == "1" ]] && echo pass || echo blocked)" \
    "$live_fetch_attestation_ready" \
    "$fetch_action"
  printf "runtime-fetch-rows,%s,rows=%d expected=%d\n" \
    "$([[ "$runtime_rows" -gt 0 && "$runtime_rows" -eq "$expected_fetch_rows" ]] && echo pass || echo blocked)" \
    "$runtime_rows" \
    "$expected_fetch_rows"
  printf "runtime-artifact-match,%s,matched=%d/%d remote=%d cache=%d\n" \
    "$([[ "$matched_artifact_rows" -eq "$expected_fetch_rows" && "$remote_uri_match_rows" -eq "$expected_fetch_rows" && "$cache_uri_match_rows" -eq "$expected_fetch_rows" && "$expected_fetch_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$matched_artifact_rows" \
    "$expected_fetch_rows" \
    "$remote_uri_match_rows" \
    "$cache_uri_match_rows"
  printf "runtime-content-hash,%s,content=%d/%d download=%d cache_verified=%d\n" \
    "$([[ "$content_hash_match_rows" -eq "$expected_fetch_rows" && "$download_hash_match_rows" -eq "$expected_fetch_rows" && "$download_cache_hash_verified_rows" -eq "$expected_fetch_rows" && "$expected_fetch_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$content_hash_match_rows" \
    "$expected_fetch_rows" \
    "$download_hash_match_rows" \
    "$download_cache_hash_verified_rows"
  printf "fetcher-metadata,%s,metadata=%d/%d ready=%d output_hash=%d\n" \
    "$([[ "$fetcher_metadata_rows" -eq "$expected_fetch_rows" && "$runtime_fetch_ready_rows" -eq "$expected_fetch_rows" && "$output_hash_verified_rows" -eq "$expected_fetch_rows" && "$expected_fetch_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$fetcher_metadata_rows" \
    "$expected_fetch_rows" \
    "$runtime_fetch_ready_rows" \
    "$output_hash_verified_rows"
  printf "runner-owned-fetch,%s,runner_owned=%d/%d source=%s\n" \
    "$([[ "$runner_owned_fetch_rows" -eq "$expected_fetch_rows" && "$expected_fetch_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$runner_owned_fetch_rows" \
    "$expected_fetch_rows" \
    "$RUNTIME_SOURCE"
  printf "runtime-fetch-contract,%s,ready=%d action=%s\n" \
    "$([[ "$runner_owned_runtime_fetcher_ready" == "1" ]] && echo pass || echo blocked)" \
    "$runner_owned_runtime_fetcher_ready" \
    "$action"
  printf "live-network-fetch,%s,network=%d/%d offline_replay=%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$live_network_fetch_ready" == "1" ]] && echo pass || echo blocked)" \
    "$network_fetch_rows" \
    "$expected_fetch_rows" \
    "$offline_replay_rows" \
    "$declared_real_rows" \
    "$expected_fetch_rows" \
    "$non_fixture_declared_rows" \
    "$expected_fetch_rows"
  printf "real-teacher-source-verification,%s,real_verified=%d action=%s\n" \
    "$([[ "$real_teacher_source_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_teacher_source_verified" \
    "$action"
} >"$DECISION_CSV"

echo "runtime_fetch: $RUNTIME_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
