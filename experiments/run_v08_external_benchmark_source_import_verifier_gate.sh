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

PREFIX="v08_external_benchmark_source_import_verifier_gate"
SOURCE_IMPORT_PREFIX="v08_external_benchmark_source_import_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_verifier_gate_smoke"
  SOURCE_IMPORT_PREFIX="v08_external_benchmark_source_import_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_gate.sh" "${RUN_ARGS[@]}" >/dev/null

SOURCE_IMPORT_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_IMPORT_PREFIX}_summary.csv"
SOURCE_IMPORT_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV:-}"
VERIFIER_CSV="$RESULTS_DIR/${PREFIX}_verifier.csv"
VERIFIER_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ARTIFACT_DIR="$RESULTS_DIR/${PREFIX}_replay_artifacts"

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

is_https_uri() {
  local uri="$1"
  [[ "$uri" == https://* ]]
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

slugify() {
  local value="$1"
  printf '%s\n' "$value" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-//; s/-$//'
}

write_verifier_header() {
  echo "benchmark_family,source_import_id,verifier_run_id,verifier_runner_id,verifier_binary_uri,verifier_binary_hash,verifier_command_hash,verifier_stdout_uri,verifier_stdout_hash,verifier_stderr_uri,verifier_stderr_hash,verified_import_manifest_uri,verified_import_manifest_hash,verified_import_fetch_log_uri,verified_import_fetch_log_hash,verified_import_reviewer_identity_uri,verified_import_reviewer_identity_hash,verified_dataset_uri,verified_result_uri,verified_evaluator_output_uri,verified_run_log_uri,runner_owned_verifier,verifier_artifacts_ready,verifier_output_hash_verified,live_network_verifier_run,offline_replay_used,real_source_import_verifier_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,verifier_binary_hash_attested,verifier_stdout_hash_attested,verifier_stderr_hash_attested"
}

SOURCE_IMPORT_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_source source_import_rows source_import_contract_ready source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-n source-import summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_source"],
        $idx["source_import_rows"] + 0,
        $idx["source_import_contract_ready"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-n source-import summary row", 3)
    }
  ' "$SOURCE_IMPORT_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_source source_import_rows source_import_contract_ready upstream_source_import_verified source_import_action source_import_routing source_import_jump <<<"$SOURCE_IMPORT_VALUES"

declare -A expected_source_import_id
declare -A expected_dataset_uri
declare -A expected_result_uri
declare -A expected_evaluator_output_uri
declare -A expected_run_log_uri
declare -A expected_import_manifest_uri
declare -A expected_import_manifest_hash
declare -A expected_import_fetch_log_uri
declare -A expected_import_fetch_log_hash
declare -A expected_import_reviewer_identity_uri
declare -A expected_import_reviewer_identity_hash

expected_source_import_rows_seen=0
if [[ -n "$SOURCE_IMPORT_CSV" ]]; then
  if [[ ! -s "$SOURCE_IMPORT_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
  SOURCE_IMPORT_TSV="$TMP_DIR/source_import.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id dataset_uri result_uri evaluator_output_uri run_log_uri import_manifest_uri import_manifest_hash import_fetch_log_uri import_fetch_log_hash import_reviewer_identity_uri import_reviewer_identity_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-n source-import column: " required[i], 4)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-n source-import row has wrong column count", 5)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["source_import_id"],
        $idx["dataset_uri"],
        $idx["result_uri"],
        $idx["evaluator_output_uri"],
        $idx["run_log_uri"],
        $idx["import_manifest_uri"],
        $idx["import_manifest_hash"],
        $idx["import_fetch_log_uri"],
        $idx["import_fetch_log_hash"],
        $idx["import_reviewer_identity_uri"],
        $idx["import_reviewer_identity_hash"]
    }
  ' "$SOURCE_IMPORT_CSV" >"$SOURCE_IMPORT_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id dataset_uri result_uri evaluator_output_uri run_log_uri import_manifest_uri import_manifest_hash import_fetch_log_uri import_fetch_log_hash import_reviewer_identity_uri import_reviewer_identity_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-n source-import family: $benchmark_family" >&2
      exit 6
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_dataset_uri["$benchmark_family"]="$dataset_uri"
    expected_result_uri["$benchmark_family"]="$result_uri"
    expected_evaluator_output_uri["$benchmark_family"]="$evaluator_output_uri"
    expected_run_log_uri["$benchmark_family"]="$run_log_uri"
    expected_import_manifest_uri["$benchmark_family"]="$import_manifest_uri"
    expected_import_manifest_hash["$benchmark_family"]="$import_manifest_hash"
    expected_import_fetch_log_uri["$benchmark_family"]="$import_fetch_log_uri"
    expected_import_fetch_log_hash["$benchmark_family"]="$import_fetch_log_hash"
    expected_import_reviewer_identity_uri["$benchmark_family"]="$import_reviewer_identity_uri"
    expected_import_reviewer_identity_hash["$benchmark_family"]="$import_reviewer_identity_hash"
    ((expected_source_import_rows_seen += 1))
  done <"$SOURCE_IMPORT_TSV"
fi

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV:-}" ]]; then
  VERIFIER_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV"
  VERIFIER_SOURCE="provided-csv"
  if [[ ! -s "$VERIFIER_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV must point to a non-empty CSV" >&2
    exit 10
  fi
elif [[ "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_REPLAY:-0}" == "1" && -n "$SOURCE_IMPORT_CSV" ]]; then
  VERIFIER_SOURCE="runner-owned-replay"
  mkdir -p "$ARTIFACT_DIR"
  {
    write_verifier_header
    while IFS=$'\t' read -r benchmark_family source_import_id dataset_uri result_uri evaluator_output_uri run_log_uri import_manifest_uri import_manifest_hash import_fetch_log_uri import_fetch_log_hash import_reviewer_identity_uri import_reviewer_identity_hash; do
      slug="$(slugify "$benchmark_family")"
      stdout_path="$ARTIFACT_DIR/${slug}-stdout.txt"
      stderr_path="$ARTIFACT_DIR/${slug}-stderr.txt"
      printf 'verified_source_import=%s\nmanifest_hash=%s\nfetch_log_hash=%s\n' \
        "$source_import_id" "$import_manifest_hash" "$import_fetch_log_hash" >"$stdout_path"
      : >"$stderr_path"
      verifier_command_hash="$(sha_text_uri "VERIFY ${source_import_id} ${import_manifest_hash} ${import_fetch_log_hash}")"
      printf "%s,%s,%s,%s,file://%s,%s,%s,file://%s,%s,file://%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,1,1,0,1,0,1,0.000000,0.000000,0,0,0\n" \
        "$benchmark_family" \
        "$source_import_id" \
        "source-import-verifier-replay-${slug}" \
        "betelgeuze-source-import-verifier-replay-v1" \
        "$0" \
        "$(sha_file_uri "$0")" \
        "$verifier_command_hash" \
        "$stdout_path" \
        "$(sha_file_uri "$stdout_path")" \
        "$stderr_path" \
        "$(sha_file_uri "$stderr_path")" \
        "$import_manifest_uri" \
        "$import_manifest_hash" \
        "$import_fetch_log_uri" \
        "$import_fetch_log_hash" \
        "$import_reviewer_identity_uri" \
        "$import_reviewer_identity_hash" \
        "$dataset_uri" \
        "$result_uri" \
        "$evaluator_output_uri" \
        "$run_log_uri"
    done <"$SOURCE_IMPORT_TSV"
  } >"$VERIFIER_CSV"
else
  write_verifier_header >"$VERIFIER_CSV"
fi

expected_verifier_rows="$source_import_rows"
expected_verifier_artifacts=$((expected_verifier_rows * 3))
source_import_verifier_rows=0
matched_source_import_rows=0
source_import_id_match_rows=0
import_manifest_uri_match_rows=0
import_manifest_hash_match_rows=0
import_fetch_log_uri_match_rows=0
import_fetch_log_hash_match_rows=0
reviewer_identity_uri_match_rows=0
reviewer_identity_hash_match_rows=0
benchmark_artifact_uri_match_rows=0
verifier_artifact_rows=0
verifier_hash_verified_rows=0
local_verifier_artifact_rows=0
nonlocal_verifier_artifact_rows=0
verifier_metadata_rows=0
runner_owned_verifier_rows=0
verifier_ready_rows=0
verifier_output_hash_verified_rows=0
live_network_verifier_rows=0
offline_replay_rows=0
declared_real_verifier_rows=0
non_fixture_declared_rows=0
verifier_routing="0.000000"
verifier_jump="0.000000"
declare -A verifier_seen
VERIFIER_TSV="$TMP_DIR/verifier.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id verifier_run_id verifier_runner_id verifier_binary_uri verifier_binary_hash verifier_command_hash verifier_stdout_uri verifier_stdout_hash verifier_stderr_uri verifier_stderr_hash verified_import_manifest_uri verified_import_manifest_hash verified_import_fetch_log_uri verified_import_fetch_log_hash verified_import_reviewer_identity_uri verified_import_reviewer_identity_hash verified_dataset_uri verified_result_uri verified_evaluator_output_uri verified_run_log_uri runner_owned_verifier verifier_artifacts_ready verifier_output_hash_verified live_network_verifier_run offline_replay_used real_source_import_verifier_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-n verifier column: " required[i], 11)
    }
    verifier_binary_hash_attested_idx = ("verifier_binary_hash_attested" in idx) ? idx["verifier_binary_hash_attested"] : 0
    verifier_stdout_hash_attested_idx = ("verifier_stdout_hash_attested" in idx) ? idx["verifier_stdout_hash_attested"] : 0
    verifier_stderr_hash_attested_idx = ("verifier_stderr_hash_attested" in idx) ? idx["verifier_stderr_hash_attested"] : 0
    next
  }
  {
    if (NF != header_fields) die("v08-n verifier row has wrong column count", 12)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%d\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["verifier_run_id"],
      $idx["verifier_runner_id"],
      $idx["verifier_binary_uri"],
      $idx["verifier_binary_hash"],
      $idx["verifier_command_hash"],
      $idx["verifier_stdout_uri"],
      $idx["verifier_stdout_hash"],
      $idx["verifier_stderr_uri"],
      $idx["verifier_stderr_hash"],
      $idx["verified_import_manifest_uri"],
      $idx["verified_import_manifest_hash"],
      $idx["verified_import_fetch_log_uri"],
      $idx["verified_import_fetch_log_hash"],
      $idx["verified_import_reviewer_identity_uri"],
      $idx["verified_import_reviewer_identity_hash"],
      $idx["verified_dataset_uri"],
      $idx["verified_result_uri"],
      $idx["verified_evaluator_output_uri"],
      $idx["verified_run_log_uri"],
      $idx["runner_owned_verifier"] + 0,
      $idx["verifier_artifacts_ready"] + 0,
      $idx["verifier_output_hash_verified"] + 0,
      $idx["live_network_verifier_run"] + 0,
      $idx["offline_replay_used"] + 0,
      $idx["real_source_import_verifier_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0,
      verifier_binary_hash_attested_idx ? $verifier_binary_hash_attested_idx + 0 : 0,
      verifier_stdout_hash_attested_idx ? $verifier_stdout_hash_attested_idx + 0 : 0,
      verifier_stderr_hash_attested_idx ? $verifier_stderr_hash_attested_idx + 0 : 0
  }
' "$VERIFIER_CSV" >"$VERIFIER_TSV"

count_verifier_artifact() {
  local uri="$1"
  local hash="$2"
  local attested="$3"

  if uri_to_local_path "$uri" >/dev/null; then
    ((local_verifier_artifact_rows += 1))
    ((verifier_artifact_rows += 1))
    if hash_matches_uri "$uri" "$hash"; then
      ((verifier_hash_verified_rows += 1))
    fi
  elif is_https_uri "$uri" && [[ "$attested" == "1" ]] && is_sha256 "$hash"; then
    ((nonlocal_verifier_artifact_rows += 1))
    ((verifier_artifact_rows += 1))
    ((verifier_hash_verified_rows += 1))
  fi
}

while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id verifier_runner_id verifier_binary_uri verifier_binary_hash verifier_command_hash verifier_stdout_uri verifier_stdout_hash verifier_stderr_uri verifier_stderr_hash verified_import_manifest_uri verified_import_manifest_hash verified_import_fetch_log_uri verified_import_fetch_log_hash verified_import_reviewer_identity_uri verified_import_reviewer_identity_hash verified_dataset_uri verified_result_uri verified_evaluator_output_uri verified_run_log_uri runner_owned_verifier verifier_artifacts_ready verifier_output_hash_verified live_network_verifier_run offline_replay_used real_source_import_verifier_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate verifier_binary_hash_attested verifier_stdout_hash_attested verifier_stderr_hash_attested; do
  ((source_import_verifier_rows += 1))
  if [[ -n "${verifier_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-n verifier family: $benchmark_family" >&2
    exit 13
  fi
  verifier_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_source_import_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_import_manifest_uri[$benchmark_family]:-}" == "$verified_import_manifest_uri" ]] && is_present "$verified_import_manifest_uri"; then
    ((import_manifest_uri_match_rows += 1))
  fi
  if [[ "${expected_import_manifest_hash[$benchmark_family]:-}" == "$verified_import_manifest_hash" ]] && is_sha256 "$verified_import_manifest_hash"; then
    ((import_manifest_hash_match_rows += 1))
  fi
  if [[ "${expected_import_fetch_log_uri[$benchmark_family]:-}" == "$verified_import_fetch_log_uri" ]] && is_present "$verified_import_fetch_log_uri"; then
    ((import_fetch_log_uri_match_rows += 1))
  fi
  if [[ "${expected_import_fetch_log_hash[$benchmark_family]:-}" == "$verified_import_fetch_log_hash" ]] && is_sha256 "$verified_import_fetch_log_hash"; then
    ((import_fetch_log_hash_match_rows += 1))
  fi
  if [[ "${expected_import_reviewer_identity_uri[$benchmark_family]:-}" == "$verified_import_reviewer_identity_uri" ]] && is_present "$verified_import_reviewer_identity_uri"; then
    ((reviewer_identity_uri_match_rows += 1))
  fi
  if [[ "${expected_import_reviewer_identity_hash[$benchmark_family]:-}" == "$verified_import_reviewer_identity_hash" ]] && is_sha256 "$verified_import_reviewer_identity_hash"; then
    ((reviewer_identity_hash_match_rows += 1))
  fi
  if [[ "${expected_dataset_uri[$benchmark_family]:-}" == "$verified_dataset_uri" &&
        "${expected_result_uri[$benchmark_family]:-}" == "$verified_result_uri" &&
        "${expected_evaluator_output_uri[$benchmark_family]:-}" == "$verified_evaluator_output_uri" &&
        "${expected_run_log_uri[$benchmark_family]:-}" == "$verified_run_log_uri" ]] &&
      is_present "$verified_dataset_uri" &&
      is_present "$verified_result_uri" &&
      is_present "$verified_evaluator_output_uri" &&
      is_present "$verified_run_log_uri"; then
    ((benchmark_artifact_uri_match_rows += 1))
  fi

  count_verifier_artifact "$verifier_binary_uri" "$verifier_binary_hash" "$verifier_binary_hash_attested"
  count_verifier_artifact "$verifier_stdout_uri" "$verifier_stdout_hash" "$verifier_stdout_hash_attested"
  count_verifier_artifact "$verifier_stderr_uri" "$verifier_stderr_hash" "$verifier_stderr_hash_attested"

  if is_present "$verifier_run_id" &&
      is_present "$verifier_runner_id" &&
      is_present "$verifier_binary_uri" &&
      is_sha256 "$verifier_binary_hash" &&
      is_sha256 "$verifier_command_hash" &&
      is_present "$verifier_stdout_uri" &&
      is_sha256 "$verifier_stdout_hash" &&
      is_present "$verifier_stderr_uri" &&
      is_sha256 "$verifier_stderr_hash"; then
    ((verifier_metadata_rows += 1))
  fi
  if [[ "$runner_owned_verifier" == "1" ]]; then
    ((runner_owned_verifier_rows += 1))
  fi
  if [[ "$verifier_artifacts_ready" == "1" ]]; then
    ((verifier_ready_rows += 1))
  fi
  if [[ "$verifier_output_hash_verified" == "1" ]]; then
    ((verifier_output_hash_verified_rows += 1))
  fi
  if [[ "$live_network_verifier_run" == "1" ]]; then
    ((live_network_verifier_rows += 1))
  fi
  if [[ "$offline_replay_used" == "1" ]]; then
    ((offline_replay_rows += 1))
  fi
  if [[ "$real_source_import_verifier_declared" == "1" ]]; then
    ((declared_real_verifier_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  verifier_routing="$(awk -v a="$verifier_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  verifier_jump="$(awk -v a="$verifier_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$VERIFIER_TSV"

source_import_verifier_ready=0
if [[ "$source_import_contract_ready" == "1" &&
      "$expected_verifier_rows" -gt 0 &&
      "$expected_source_import_rows_seen" -eq "$expected_verifier_rows" &&
      "$source_import_verifier_rows" -eq "$expected_verifier_rows" &&
      "$matched_source_import_rows" -eq "$expected_verifier_rows" &&
      "$source_import_id_match_rows" -eq "$expected_verifier_rows" &&
      "$import_manifest_uri_match_rows" -eq "$expected_verifier_rows" &&
      "$import_manifest_hash_match_rows" -eq "$expected_verifier_rows" &&
      "$import_fetch_log_uri_match_rows" -eq "$expected_verifier_rows" &&
      "$import_fetch_log_hash_match_rows" -eq "$expected_verifier_rows" &&
      "$reviewer_identity_uri_match_rows" -eq "$expected_verifier_rows" &&
      "$reviewer_identity_hash_match_rows" -eq "$expected_verifier_rows" &&
      "$benchmark_artifact_uri_match_rows" -eq "$expected_verifier_rows" &&
      "$verifier_artifact_rows" -eq "$expected_verifier_artifacts" &&
      "$verifier_hash_verified_rows" -eq "$expected_verifier_artifacts" &&
      "$verifier_metadata_rows" -eq "$expected_verifier_rows" &&
      "$runner_owned_verifier_rows" -eq "$expected_verifier_rows" &&
      "$verifier_ready_rows" -eq "$expected_verifier_rows" &&
      "$verifier_output_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$source_import_routing" == "0.000000" &&
      "$source_import_jump" == "0.000000" &&
      "$verifier_routing" == "0.000000" &&
      "$verifier_jump" == "0.000000" ]]; then
  source_import_verifier_ready=1
fi

live_network_source_import_verified=0
source_import_verified=0
real_external_benchmark_verified=0
action="external-benchmark-source-import-contract-missing"
if [[ "$source_import_contract_ready" == "1" ]]; then
  if [[ "$source_import_verifier_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-verifier-missing"
  elif [[ "$source_import_verifier_rows" -ne "$expected_verifier_rows" ||
          "$matched_source_import_rows" -ne "$expected_verifier_rows" ||
          "$source_import_id_match_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-verifier-row-mismatch"
  elif [[ "$import_manifest_uri_match_rows" -ne "$expected_verifier_rows" ||
          "$import_manifest_hash_match_rows" -ne "$expected_verifier_rows" ||
          "$import_fetch_log_uri_match_rows" -ne "$expected_verifier_rows" ||
          "$import_fetch_log_hash_match_rows" -ne "$expected_verifier_rows" ||
          "$reviewer_identity_uri_match_rows" -ne "$expected_verifier_rows" ||
          "$reviewer_identity_hash_match_rows" -ne "$expected_verifier_rows" ||
          "$benchmark_artifact_uri_match_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-verifier-chain-mismatch"
  elif [[ "$verifier_artifact_rows" -ne "$expected_verifier_artifacts" ||
          "$verifier_hash_verified_rows" -ne "$expected_verifier_artifacts" ]]; then
    action="external-benchmark-source-import-verifier-artifact-hash-mismatch"
  elif [[ "$verifier_metadata_rows" -ne "$expected_verifier_rows" ||
          "$runner_owned_verifier_rows" -ne "$expected_verifier_rows" ||
          "$verifier_ready_rows" -ne "$expected_verifier_rows" ||
          "$verifier_output_hash_verified_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-verifier-contract-incomplete"
  elif [[ "$source_import_verifier_ready" == "1" &&
          ( "$live_network_verifier_rows" -ne "$expected_verifier_rows" ||
            "$offline_replay_rows" -ne 0 ||
            "$declared_real_verifier_rows" -ne "$expected_verifier_rows" ||
            "$non_fixture_declared_rows" -ne "$expected_verifier_rows" ) ]]; then
    action="external-benchmark-source-import-live-verifier-missing"
  elif [[ "$source_import_verifier_ready" == "1" ]]; then
    action="external-benchmark-source-import-independent-live-review-missing"
  fi
fi

total_routing="$(awk -v a="$source_import_routing" -v b="$verifier_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$source_import_jump" -v b="$verifier_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_source,source_import_action,source_import_contract_ready,upstream_source_import_verified,source_import_verifier_source,expected_verifier_rows,expected_verifier_artifacts,source_import_verifier_rows,matched_source_import_rows,source_import_id_match_rows,import_manifest_uri_match_rows,import_manifest_hash_match_rows,import_fetch_log_uri_match_rows,import_fetch_log_hash_match_rows,reviewer_identity_uri_match_rows,reviewer_identity_hash_match_rows,benchmark_artifact_uri_match_rows,verifier_artifact_rows,verifier_hash_verified_rows,local_verifier_artifact_rows,nonlocal_verifier_artifact_rows,verifier_metadata_rows,runner_owned_verifier_rows,verifier_ready_rows,verifier_output_hash_verified_rows,live_network_verifier_rows,offline_replay_rows,declared_real_verifier_rows,non_fixture_declared_rows,source_import_verifier_ready,live_network_source_import_verified,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08n,%d,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$source_import_source" \
    "$source_import_action" \
    "$source_import_contract_ready" \
    "$upstream_source_import_verified" \
    "$VERIFIER_SOURCE" \
    "$expected_verifier_rows" \
    "$expected_verifier_artifacts" \
    "$source_import_verifier_rows" \
    "$matched_source_import_rows" \
    "$source_import_id_match_rows" \
    "$import_manifest_uri_match_rows" \
    "$import_manifest_hash_match_rows" \
    "$import_fetch_log_uri_match_rows" \
    "$import_fetch_log_hash_match_rows" \
    "$reviewer_identity_uri_match_rows" \
    "$reviewer_identity_hash_match_rows" \
    "$benchmark_artifact_uri_match_rows" \
    "$verifier_artifact_rows" \
    "$verifier_hash_verified_rows" \
    "$local_verifier_artifact_rows" \
    "$nonlocal_verifier_artifact_rows" \
    "$verifier_metadata_rows" \
    "$runner_owned_verifier_rows" \
    "$verifier_ready_rows" \
    "$verifier_output_hash_verified_rows" \
    "$live_network_verifier_rows" \
    "$offline_replay_rows" \
    "$declared_real_verifier_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_verifier_ready" \
    "$live_network_source_import_verified" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-contract,%s,ready=%d source_import_action=%s\n" \
    "$([[ "$source_import_contract_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_contract_ready" \
    "$source_import_action"
  printf "verifier-rows,%s,rows=%d expected=%d source=%s\n" \
    "$([[ "$source_import_verifier_rows" -gt 0 && "$source_import_verifier_rows" -eq "$expected_verifier_rows" ]] && echo pass || echo blocked)" \
    "$source_import_verifier_rows" \
    "$expected_verifier_rows" \
    "$VERIFIER_SOURCE"
  printf "source-import-binding,%s,matched=%d/%d ids=%d\n" \
    "$([[ "$matched_source_import_rows" -eq "$expected_verifier_rows" && "$source_import_id_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$matched_source_import_rows" \
    "$expected_verifier_rows" \
    "$source_import_id_match_rows"
  printf "import-manifest-binding,%s,uri=%d/%d hash=%d/%d\n" \
    "$([[ "$import_manifest_uri_match_rows" -eq "$expected_verifier_rows" && "$import_manifest_hash_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$import_manifest_uri_match_rows" \
    "$expected_verifier_rows" \
    "$import_manifest_hash_match_rows" \
    "$expected_verifier_rows"
  printf "import-fetch-log-binding,%s,uri=%d/%d hash=%d/%d\n" \
    "$([[ "$import_fetch_log_uri_match_rows" -eq "$expected_verifier_rows" && "$import_fetch_log_hash_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$import_fetch_log_uri_match_rows" \
    "$expected_verifier_rows" \
    "$import_fetch_log_hash_match_rows" \
    "$expected_verifier_rows"
  printf "reviewer-identity-binding,%s,uri=%d/%d hash=%d/%d\n" \
    "$([[ "$reviewer_identity_uri_match_rows" -eq "$expected_verifier_rows" && "$reviewer_identity_hash_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$reviewer_identity_uri_match_rows" \
    "$expected_verifier_rows" \
    "$reviewer_identity_hash_match_rows" \
    "$expected_verifier_rows"
  printf "benchmark-artifact-binding,%s,artifact_uri_match=%d/%d\n" \
    "$([[ "$benchmark_artifact_uri_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$benchmark_artifact_uri_match_rows" \
    "$expected_verifier_rows"
  printf "verifier-artifact-hash,%s,artifact_rows=%d/%d hash_rows=%d/%d local=%d nonlocal=%d\n" \
    "$([[ "$verifier_artifact_rows" -eq "$expected_verifier_artifacts" && "$verifier_hash_verified_rows" -eq "$expected_verifier_artifacts" && "$expected_verifier_artifacts" -gt 0 ]] && echo pass || echo blocked)" \
    "$verifier_artifact_rows" \
    "$expected_verifier_artifacts" \
    "$verifier_hash_verified_rows" \
    "$expected_verifier_artifacts" \
    "$local_verifier_artifact_rows" \
    "$nonlocal_verifier_artifact_rows"
  printf "verifier-metadata,%s,metadata=%d/%d ready=%d output_hash=%d\n" \
    "$([[ "$verifier_metadata_rows" -eq "$expected_verifier_rows" && "$verifier_ready_rows" -eq "$expected_verifier_rows" && "$verifier_output_hash_verified_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$verifier_metadata_rows" \
    "$expected_verifier_rows" \
    "$verifier_ready_rows" \
    "$verifier_output_hash_verified_rows"
  printf "runner-owned-verifier,%s,runner_owned=%d/%d\n" \
    "$([[ "$runner_owned_verifier_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$runner_owned_verifier_rows" \
    "$expected_verifier_rows"
  printf "source-import-verifier-contract,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_verifier_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verifier_ready" \
    "$action"
  printf "live-network-verifier,%s,live=%d/%d replay=%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$live_network_verifier_rows" -eq "$expected_verifier_rows" && "$offline_replay_rows" -eq 0 && "$declared_real_verifier_rows" -eq "$expected_verifier_rows" && "$non_fixture_declared_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$live_network_verifier_rows" \
    "$expected_verifier_rows" \
    "$offline_replay_rows" \
    "$declared_real_verifier_rows" \
    "$expected_verifier_rows" \
    "$non_fixture_declared_rows" \
    "$expected_verifier_rows"
  printf "source-import-verification,%s,verified=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "verifier: $VERIFIER_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
