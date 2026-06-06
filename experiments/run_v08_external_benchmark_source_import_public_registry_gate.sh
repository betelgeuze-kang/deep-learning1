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

PREFIX="v08_external_benchmark_source_import_public_registry_gate"
AUTHORITY_REVIEW_PREFIX="v08_external_benchmark_source_import_authoritative_review_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_public_registry_gate_smoke"
  AUTHORITY_REVIEW_PREFIX="v08_external_benchmark_source_import_authoritative_review_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_authoritative_review_gate.sh" "${RUN_ARGS[@]}" >/dev/null

AUTHORITY_SUMMARY_CSV="$RESULTS_DIR/${AUTHORITY_REVIEW_PREFIX}_summary.csv"
AUTHORITY_REVIEW_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV:-$RESULTS_DIR/${AUTHORITY_REVIEW_PREFIX}_review.csv}"
PUBLIC_REGISTRY_CSV="$RESULTS_DIR/${PREFIX}_registry.csv"
PUBLIC_REGISTRY_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_public_registry_header() {
  echo "benchmark_family,source_import_id,verifier_run_id,live_review_id,authority_review_id,registry_entry_id,public_registry_uri,public_registry_hash,registry_entry_uri,registry_entry_hash,registry_operator_identity_uri,registry_operator_identity_hash,registry_provenance_uri,registry_provenance_hash,reviewed_authority_review_report_hash,reviewed_authority_reviewer_identity_hash,reviewed_authority_reviewer_registry_hash,reviewed_authority_reviewer_conflict_disclosure_hash,reviewed_verifier_binary_hash,reviewed_verifier_stdout_hash,reviewed_verifier_stderr_hash,registry_name,registry_operator,registry_jurisdiction,registry_record_type,registry_protocol_version,official_public_registry,source_import_recorded,authority_review_recorded,artifact_hash_review_ready,source_import_binding_review_ready,registry_entry_approved,real_public_registry_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,public_registry_hash_attested,registry_entry_hash_attested,registry_operator_identity_hash_attested,registry_provenance_hash_attested"
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

count_registry_artifact() {
  local uri="$1"
  local hash="$2"
  local attested="$3"
  local counter="$4"

  if uri_to_local_path "$uri" >/dev/null; then
    case "$counter" in
      registry) ((local_public_registry_rows += 1)); ((public_registry_artifact_rows += 1)) ;;
      entry) ((local_registry_entry_rows += 1)); ((registry_entry_artifact_rows += 1)) ;;
      operator) ((local_registry_operator_identity_rows += 1)); ((registry_operator_identity_rows += 1)) ;;
      provenance) ((local_registry_provenance_rows += 1)); ((registry_provenance_rows += 1)) ;;
      *) echo "unknown registry artifact counter: $counter" >&2; exit 2 ;;
    esac
    if hash_matches_uri "$uri" "$hash"; then
      case "$counter" in
        registry) ((public_registry_hash_verified_rows += 1)) ;;
        entry) ((registry_entry_hash_verified_rows += 1)) ;;
        operator) ((registry_operator_identity_hash_verified_rows += 1)) ;;
        provenance) ((registry_provenance_hash_verified_rows += 1)) ;;
      esac
    fi
  elif is_https_uri "$uri" && [[ "$attested" == "1" ]] && is_sha256 "$hash"; then
    case "$counter" in
      registry) ((nonlocal_public_registry_rows += 1)); ((public_registry_artifact_rows += 1)); ((public_registry_hash_verified_rows += 1)) ;;
      entry) ((nonlocal_registry_entry_rows += 1)); ((registry_entry_artifact_rows += 1)); ((registry_entry_hash_verified_rows += 1)) ;;
      operator) ((nonlocal_registry_operator_identity_rows += 1)); ((registry_operator_identity_rows += 1)); ((registry_operator_identity_hash_verified_rows += 1)) ;;
      provenance) ((nonlocal_registry_provenance_rows += 1)); ((registry_provenance_rows += 1)); ((registry_provenance_hash_verified_rows += 1)) ;;
      *) echo "unknown registry artifact counter: $counter" >&2; exit 2 ;;
    esac
  fi
}

AUTHORITY_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready authority_review_source expected_authority_rows authority_review_rows source_import_authoritative_review_ready source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-r authority summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%s,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_contract_ready"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_live_verifier_ready"] + 0,
        $idx["source_import_independent_live_review_ready"] + 0,
        $idx["authority_review_source"],
        $idx["expected_authority_rows"] + 0,
        $idx["authority_review_rows"] + 0,
        $idx["source_import_authoritative_review_ready"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-r authority summary row", 3)
    }
  ' "$AUTHORITY_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready authority_review_source expected_authority_rows authority_review_rows source_import_authoritative_review_ready upstream_source_import_verified authority_action authority_routing authority_jump <<<"$AUTHORITY_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV:-}" ]]; then
  PUBLIC_REGISTRY_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV"
  PUBLIC_REGISTRY_SOURCE="provided-csv"
  if [[ ! -s "$PUBLIC_REGISTRY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_public_registry_header >"$PUBLIC_REGISTRY_CSV"
fi

declare -A expected_source_import_id
declare -A expected_verifier_run_id
declare -A expected_live_review_id
declare -A expected_authority_review_id
declare -A expected_authority_review_report_hash
declare -A expected_authority_identity_hash
declare -A expected_authority_registry_hash
declare -A expected_authority_conflict_hash
declare -A expected_verifier_binary_hash
declare -A expected_verifier_stdout_hash
declare -A expected_verifier_stderr_hash

expected_authority_review_rows_seen=0
if [[ -s "$AUTHORITY_REVIEW_CSV" ]]; then
  AUTHORITY_TSV="$TMP_DIR/authority_review.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id verifier_run_id live_review_id authority_review_id authority_review_report_hash authority_reviewer_identity_hash authority_reviewer_registry_hash authority_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-r authority source column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-r authority source row has wrong column count", 11)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
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
        $idx["reviewed_verifier_stderr_hash"]
    }
  ' "$AUTHORITY_REVIEW_CSV" >"$AUTHORITY_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id live_review_id authority_review_id authority_review_report_hash authority_identity_hash authority_registry_hash authority_conflict_hash verifier_binary_hash verifier_stdout_hash verifier_stderr_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-r authority family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_verifier_run_id["$benchmark_family"]="$verifier_run_id"
    expected_live_review_id["$benchmark_family"]="$live_review_id"
    expected_authority_review_id["$benchmark_family"]="$authority_review_id"
    expected_authority_review_report_hash["$benchmark_family"]="$authority_review_report_hash"
    expected_authority_identity_hash["$benchmark_family"]="$authority_identity_hash"
    expected_authority_registry_hash["$benchmark_family"]="$authority_registry_hash"
    expected_authority_conflict_hash["$benchmark_family"]="$authority_conflict_hash"
    expected_verifier_binary_hash["$benchmark_family"]="$verifier_binary_hash"
    expected_verifier_stdout_hash["$benchmark_family"]="$verifier_stdout_hash"
    expected_verifier_stderr_hash["$benchmark_family"]="$verifier_stderr_hash"
    ((expected_authority_review_rows_seen += 1))
  done <"$AUTHORITY_TSV"
fi

public_registry_rows=0
matched_authority_review_rows=0
source_import_id_match_rows=0
verifier_run_id_match_rows=0
live_review_id_match_rows=0
authority_review_id_match_rows=0
authority_review_hash_match_rows=0
verifier_hash_match_rows=0
registry_metadata_rows=0
public_registry_artifact_rows=0
public_registry_hash_verified_rows=0
local_public_registry_rows=0
nonlocal_public_registry_rows=0
registry_entry_artifact_rows=0
registry_entry_hash_verified_rows=0
local_registry_entry_rows=0
nonlocal_registry_entry_rows=0
registry_operator_identity_rows=0
registry_operator_identity_hash_verified_rows=0
local_registry_operator_identity_rows=0
nonlocal_registry_operator_identity_rows=0
registry_provenance_rows=0
registry_provenance_hash_verified_rows=0
local_registry_provenance_rows=0
nonlocal_registry_provenance_rows=0
official_public_registry_rows=0
source_import_recorded_rows=0
authority_review_recorded_rows=0
artifact_hash_review_ready_rows=0
source_import_binding_review_ready_rows=0
registry_entry_approved_rows=0
real_public_registry_declared_rows=0
non_fixture_declared_rows=0
registry_routing="0.000000"
registry_jump="0.000000"
declare -A registry_seen

REGISTRY_TSV="$TMP_DIR/public_registry.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id verifier_run_id live_review_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash registry_operator_identity_uri registry_operator_identity_hash registry_provenance_uri registry_provenance_hash reviewed_authority_review_report_hash reviewed_authority_reviewer_identity_hash reviewed_authority_reviewer_registry_hash reviewed_authority_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash registry_name registry_operator registry_jurisdiction registry_record_type registry_protocol_version official_public_registry source_import_recorded authority_review_recorded artifact_hash_review_ready source_import_binding_review_ready registry_entry_approved real_public_registry_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-r public registry column: " required[i], 13)
    }
    registry_attested_idx = ("public_registry_hash_attested" in idx) ? idx["public_registry_hash_attested"] : 0
    entry_attested_idx = ("registry_entry_hash_attested" in idx) ? idx["registry_entry_hash_attested"] : 0
    operator_attested_idx = ("registry_operator_identity_hash_attested" in idx) ? idx["registry_operator_identity_hash_attested"] : 0
    provenance_attested_idx = ("registry_provenance_hash_attested" in idx) ? idx["registry_provenance_hash_attested"] : 0
    next
  }
  {
    if (NF != header_fields) die("v08-r public registry row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%d\t%d\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["verifier_run_id"],
      $idx["live_review_id"],
      $idx["authority_review_id"],
      $idx["registry_entry_id"],
      $idx["public_registry_uri"],
      $idx["public_registry_hash"],
      $idx["registry_entry_uri"],
      $idx["registry_entry_hash"],
      $idx["registry_operator_identity_uri"],
      $idx["registry_operator_identity_hash"],
      $idx["registry_provenance_uri"],
      $idx["registry_provenance_hash"],
      $idx["reviewed_authority_review_report_hash"],
      $idx["reviewed_authority_reviewer_identity_hash"],
      $idx["reviewed_authority_reviewer_registry_hash"],
      $idx["reviewed_authority_reviewer_conflict_disclosure_hash"],
      $idx["reviewed_verifier_binary_hash"],
      $idx["reviewed_verifier_stdout_hash"],
      $idx["reviewed_verifier_stderr_hash"],
      $idx["registry_name"],
      $idx["registry_operator"],
      $idx["registry_jurisdiction"],
      $idx["registry_record_type"],
      $idx["registry_protocol_version"],
      $idx["official_public_registry"] + 0,
      $idx["source_import_recorded"] + 0,
      $idx["authority_review_recorded"] + 0,
      $idx["artifact_hash_review_ready"] + 0,
      $idx["source_import_binding_review_ready"] + 0,
      $idx["registry_entry_approved"] + 0,
      $idx["real_public_registry_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0,
      registry_attested_idx ? $registry_attested_idx + 0 : 0,
      entry_attested_idx ? $entry_attested_idx + 0 : 0,
      operator_attested_idx ? $operator_attested_idx + 0 : 0,
      provenance_attested_idx ? $provenance_attested_idx + 0 : 0
  }
' "$PUBLIC_REGISTRY_CSV" >"$REGISTRY_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id live_review_id authority_review_id registry_entry_id public_registry_uri public_registry_hash registry_entry_uri registry_entry_hash registry_operator_identity_uri registry_operator_identity_hash registry_provenance_uri registry_provenance_hash reviewed_authority_review_report_hash reviewed_authority_identity_hash reviewed_authority_registry_hash reviewed_authority_conflict_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash registry_name registry_operator registry_jurisdiction registry_record_type registry_protocol_version official_public_registry source_import_recorded authority_review_recorded artifact_hash_review_ready source_import_binding_review_ready registry_entry_approved real_public_registry_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate registry_hash_attested entry_hash_attested operator_hash_attested provenance_hash_attested; do
  ((public_registry_rows += 1))
  if [[ -n "${registry_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-r public registry family: $benchmark_family" >&2
    exit 15
  fi
  registry_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_authority_review_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_verifier_run_id[$benchmark_family]:-}" == "$verifier_run_id" ]] && is_present "$verifier_run_id"; then
    ((verifier_run_id_match_rows += 1))
  fi
  if [[ "${expected_live_review_id[$benchmark_family]:-}" == "$live_review_id" ]] && is_present "$live_review_id"; then
    ((live_review_id_match_rows += 1))
  fi
  if [[ "${expected_authority_review_id[$benchmark_family]:-}" == "$authority_review_id" ]] && is_present "$authority_review_id"; then
    ((authority_review_id_match_rows += 1))
  fi
  if [[ "${expected_authority_review_report_hash[$benchmark_family]:-}" == "$reviewed_authority_review_report_hash" &&
        "${expected_authority_identity_hash[$benchmark_family]:-}" == "$reviewed_authority_identity_hash" &&
        "${expected_authority_registry_hash[$benchmark_family]:-}" == "$reviewed_authority_registry_hash" &&
        "${expected_authority_conflict_hash[$benchmark_family]:-}" == "$reviewed_authority_conflict_hash" ]] &&
      is_sha256 "$reviewed_authority_review_report_hash" &&
      is_sha256 "$reviewed_authority_identity_hash" &&
      is_sha256 "$reviewed_authority_registry_hash" &&
      is_sha256 "$reviewed_authority_conflict_hash"; then
    ((authority_review_hash_match_rows += 1))
  fi
  if [[ "${expected_verifier_binary_hash[$benchmark_family]:-}" == "$reviewed_verifier_binary_hash" &&
        "${expected_verifier_stdout_hash[$benchmark_family]:-}" == "$reviewed_verifier_stdout_hash" &&
        "${expected_verifier_stderr_hash[$benchmark_family]:-}" == "$reviewed_verifier_stderr_hash" ]] &&
      is_sha256 "$reviewed_verifier_binary_hash" &&
      is_sha256 "$reviewed_verifier_stdout_hash" &&
      is_sha256 "$reviewed_verifier_stderr_hash"; then
    ((verifier_hash_match_rows += 1))
  fi

  if is_present "$registry_entry_id" &&
      is_present "$public_registry_uri" &&
      is_sha256 "$public_registry_hash" &&
      is_present "$registry_entry_uri" &&
      is_sha256 "$registry_entry_hash" &&
      is_present "$registry_operator_identity_uri" &&
      is_sha256 "$registry_operator_identity_hash" &&
      is_present "$registry_provenance_uri" &&
      is_sha256 "$registry_provenance_hash" &&
      is_present "$registry_name" &&
      is_present "$registry_operator" &&
      is_present "$registry_jurisdiction" &&
      is_present "$registry_record_type" &&
      is_present "$registry_protocol_version"; then
    ((registry_metadata_rows += 1))
  fi

  count_registry_artifact "$public_registry_uri" "$public_registry_hash" "$registry_hash_attested" registry
  count_registry_artifact "$registry_entry_uri" "$registry_entry_hash" "$entry_hash_attested" entry
  count_registry_artifact "$registry_operator_identity_uri" "$registry_operator_identity_hash" "$operator_hash_attested" operator
  count_registry_artifact "$registry_provenance_uri" "$registry_provenance_hash" "$provenance_hash_attested" provenance

  if [[ "$official_public_registry" == "1" ]]; then
    ((official_public_registry_rows += 1))
  fi
  if [[ "$source_import_recorded" == "1" ]]; then
    ((source_import_recorded_rows += 1))
  fi
  if [[ "$authority_review_recorded" == "1" ]]; then
    ((authority_review_recorded_rows += 1))
  fi
  if [[ "$artifact_hash_review_ready" == "1" ]]; then
    ((artifact_hash_review_ready_rows += 1))
  fi
  if [[ "$source_import_binding_review_ready" == "1" ]]; then
    ((source_import_binding_review_ready_rows += 1))
  fi
  if [[ "$registry_entry_approved" == "1" ]]; then
    ((registry_entry_approved_rows += 1))
  fi
  if [[ "$real_public_registry_declared" == "1" ]]; then
    ((real_public_registry_declared_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  registry_routing="$(awk -v a="$registry_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  registry_jump="$(awk -v a="$registry_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$REGISTRY_TSV"

local_registry_artifact_rows=$((local_public_registry_rows + local_registry_entry_rows + local_registry_operator_identity_rows + local_registry_provenance_rows))
nonlocal_registry_artifact_rows=$((nonlocal_public_registry_rows + nonlocal_registry_entry_rows + nonlocal_registry_operator_identity_rows + nonlocal_registry_provenance_rows))
expected_registry_artifact_rows=$((expected_authority_rows * 4))

source_import_public_registry_ready=0
if [[ "$source_import_authoritative_review_ready" == "1" &&
      "$expected_authority_rows" -gt 0 &&
      "$expected_authority_review_rows_seen" -eq "$expected_authority_rows" &&
      "$public_registry_rows" -eq "$expected_authority_rows" &&
      "$matched_authority_review_rows" -eq "$expected_authority_rows" &&
      "$source_import_id_match_rows" -eq "$expected_authority_rows" &&
      "$verifier_run_id_match_rows" -eq "$expected_authority_rows" &&
      "$live_review_id_match_rows" -eq "$expected_authority_rows" &&
      "$authority_review_id_match_rows" -eq "$expected_authority_rows" &&
      "$authority_review_hash_match_rows" -eq "$expected_authority_rows" &&
      "$verifier_hash_match_rows" -eq "$expected_authority_rows" &&
      "$registry_metadata_rows" -eq "$expected_authority_rows" &&
      "$public_registry_artifact_rows" -eq "$expected_authority_rows" &&
      "$public_registry_hash_verified_rows" -eq "$expected_authority_rows" &&
      "$registry_entry_artifact_rows" -eq "$expected_authority_rows" &&
      "$registry_entry_hash_verified_rows" -eq "$expected_authority_rows" &&
      "$registry_operator_identity_rows" -eq "$expected_authority_rows" &&
      "$registry_operator_identity_hash_verified_rows" -eq "$expected_authority_rows" &&
      "$registry_provenance_rows" -eq "$expected_authority_rows" &&
      "$registry_provenance_hash_verified_rows" -eq "$expected_authority_rows" &&
      "$local_registry_artifact_rows" -eq 0 &&
      "$nonlocal_registry_artifact_rows" -eq "$expected_registry_artifact_rows" &&
      "$official_public_registry_rows" -eq "$expected_authority_rows" &&
      "$source_import_recorded_rows" -eq "$expected_authority_rows" &&
      "$authority_review_recorded_rows" -eq "$expected_authority_rows" &&
      "$artifact_hash_review_ready_rows" -eq "$expected_authority_rows" &&
      "$source_import_binding_review_ready_rows" -eq "$expected_authority_rows" &&
      "$registry_entry_approved_rows" -eq "$expected_authority_rows" &&
      "$real_public_registry_declared_rows" -eq "$expected_authority_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_authority_rows" &&
      "$authority_routing" == "0.000000" &&
      "$authority_jump" == "0.000000" &&
      "$registry_routing" == "0.000000" &&
      "$registry_jump" == "0.000000" ]]; then
  source_import_public_registry_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$authority_action"
if [[ "$source_import_authoritative_review_ready" == "1" ]]; then
  if [[ "$public_registry_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-public-registry-missing"
  elif [[ "$public_registry_rows" -ne "$expected_authority_rows" ||
          "$matched_authority_review_rows" -ne "$expected_authority_rows" ||
          "$source_import_id_match_rows" -ne "$expected_authority_rows" ||
          "$verifier_run_id_match_rows" -ne "$expected_authority_rows" ||
          "$live_review_id_match_rows" -ne "$expected_authority_rows" ||
          "$authority_review_id_match_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-public-registry-row-mismatch"
  elif [[ "$authority_review_hash_match_rows" -ne "$expected_authority_rows" ||
          "$verifier_hash_match_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-public-registry-chain-mismatch"
  elif [[ "$registry_metadata_rows" -ne "$expected_authority_rows" ||
          "$public_registry_hash_verified_rows" -ne "$expected_authority_rows" ||
          "$registry_entry_hash_verified_rows" -ne "$expected_authority_rows" ||
          "$registry_operator_identity_hash_verified_rows" -ne "$expected_authority_rows" ||
          "$registry_provenance_hash_verified_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-public-registry-artifact-missing"
  elif [[ "$local_registry_artifact_rows" -gt 0 ||
          "$nonlocal_registry_artifact_rows" -ne "$expected_registry_artifact_rows" ]]; then
    action="external-benchmark-source-import-public-registry-nonlocal-artifact-missing"
  elif [[ "$official_public_registry_rows" -ne "$expected_authority_rows" ||
          "$source_import_recorded_rows" -ne "$expected_authority_rows" ||
          "$authority_review_recorded_rows" -ne "$expected_authority_rows" ||
          "$artifact_hash_review_ready_rows" -ne "$expected_authority_rows" ||
          "$source_import_binding_review_ready_rows" -ne "$expected_authority_rows" ||
          "$registry_entry_approved_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-public-registry-approval-missing"
  elif [[ "$real_public_registry_declared_rows" -ne "$expected_authority_rows" ||
          "$non_fixture_declared_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-public-registry-real-source-missing"
  elif [[ "$source_import_public_registry_ready" == "1" ]]; then
    action="external-benchmark-source-import-live-registry-query-missing"
  fi
fi

total_routing="$(awk -v a="$authority_routing" -v b="$registry_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$authority_jump" -v b="$registry_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_contract_ready,source_import_verifier_ready,source_import_live_verifier_ready,source_import_independent_live_review_ready,authority_review_source,expected_authority_rows,authority_review_rows,source_import_authoritative_review_ready,public_registry_source,expected_public_registry_rows,public_registry_rows,matched_authority_review_rows,source_import_id_match_rows,verifier_run_id_match_rows,live_review_id_match_rows,authority_review_id_match_rows,authority_review_hash_match_rows,verifier_hash_match_rows,registry_metadata_rows,public_registry_artifact_rows,public_registry_hash_verified_rows,registry_entry_artifact_rows,registry_entry_hash_verified_rows,registry_operator_identity_rows,registry_operator_identity_hash_verified_rows,registry_provenance_rows,registry_provenance_hash_verified_rows,local_registry_artifact_rows,nonlocal_registry_artifact_rows,official_public_registry_rows,source_import_recorded_rows,authority_review_recorded_rows,artifact_hash_review_ready_rows,source_import_binding_review_ready_rows,registry_entry_approved_rows,real_public_registry_declared_rows,non_fixture_declared_rows,source_import_public_registry_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  join_by_comma \
    route-memory-v08r \
    "$benchmark_families" \
    "$source_import_contract_ready" \
    "$source_import_verifier_ready" \
    "$source_import_live_verifier_ready" \
    "$source_import_independent_live_review_ready" \
    "$authority_review_source" \
    "$expected_authority_rows" \
    "$authority_review_rows" \
    "$source_import_authoritative_review_ready" \
    "$PUBLIC_REGISTRY_SOURCE" \
    "$expected_authority_rows" \
    "$public_registry_rows" \
    "$matched_authority_review_rows" \
    "$source_import_id_match_rows" \
    "$verifier_run_id_match_rows" \
    "$live_review_id_match_rows" \
    "$authority_review_id_match_rows" \
    "$authority_review_hash_match_rows" \
    "$verifier_hash_match_rows" \
    "$registry_metadata_rows" \
    "$public_registry_artifact_rows" \
    "$public_registry_hash_verified_rows" \
    "$registry_entry_artifact_rows" \
    "$registry_entry_hash_verified_rows" \
    "$registry_operator_identity_rows" \
    "$registry_operator_identity_hash_verified_rows" \
    "$registry_provenance_rows" \
    "$registry_provenance_hash_verified_rows" \
    "$local_registry_artifact_rows" \
    "$nonlocal_registry_artifact_rows" \
    "$official_public_registry_rows" \
    "$source_import_recorded_rows" \
    "$authority_review_recorded_rows" \
    "$artifact_hash_review_ready_rows" \
    "$source_import_binding_review_ready_rows" \
    "$registry_entry_approved_rows" \
    "$real_public_registry_declared_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_public_registry_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-authoritative-review,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_authoritative_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_authoritative_review_ready" \
    "$authority_action"
  printf "public-registry-rows,%s,rows=%d expected=%d matched=%d source_import_ids=%d verifier_runs=%d live_review_ids=%d authority_review_ids=%d\n" \
    "$([[ "$public_registry_rows" -eq "$expected_authority_rows" && "$matched_authority_review_rows" -eq "$expected_authority_rows" && "$source_import_id_match_rows" -eq "$expected_authority_rows" && "$verifier_run_id_match_rows" -eq "$expected_authority_rows" && "$live_review_id_match_rows" -eq "$expected_authority_rows" && "$authority_review_id_match_rows" -eq "$expected_authority_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$public_registry_rows" \
    "$expected_authority_rows" \
    "$matched_authority_review_rows" \
    "$source_import_id_match_rows" \
    "$verifier_run_id_match_rows" \
    "$live_review_id_match_rows" \
    "$authority_review_id_match_rows"
  printf "public-registry-chain,%s,authority_hash=%d/%d verifier_hash=%d/%d\n" \
    "$([[ "$authority_review_hash_match_rows" -eq "$expected_authority_rows" && "$verifier_hash_match_rows" -eq "$expected_authority_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$authority_review_hash_match_rows" \
    "$expected_authority_rows" \
    "$verifier_hash_match_rows" \
    "$expected_authority_rows"
  printf "public-registry-artifacts,%s,registry=%d/%d entry=%d operator=%d provenance=%d local=%d nonlocal=%d/%d\n" \
    "$([[ "$public_registry_hash_verified_rows" -eq "$expected_authority_rows" && "$registry_entry_hash_verified_rows" -eq "$expected_authority_rows" && "$registry_operator_identity_hash_verified_rows" -eq "$expected_authority_rows" && "$registry_provenance_hash_verified_rows" -eq "$expected_authority_rows" && "$local_registry_artifact_rows" -eq 0 && "$nonlocal_registry_artifact_rows" -eq "$expected_registry_artifact_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$public_registry_artifact_rows" \
    "$expected_authority_rows" \
    "$registry_entry_artifact_rows" \
    "$registry_operator_identity_rows" \
    "$registry_provenance_rows" \
    "$local_registry_artifact_rows" \
    "$nonlocal_registry_artifact_rows" \
    "$expected_registry_artifact_rows"
  printf "public-registry-approval,%s,official=%d/%d source_import=%d authority_review=%d artifact=%d binding=%d approved=%d real=%d non_fixture=%d\n" \
    "$([[ "$official_public_registry_rows" -eq "$expected_authority_rows" && "$source_import_recorded_rows" -eq "$expected_authority_rows" && "$authority_review_recorded_rows" -eq "$expected_authority_rows" && "$artifact_hash_review_ready_rows" -eq "$expected_authority_rows" && "$source_import_binding_review_ready_rows" -eq "$expected_authority_rows" && "$registry_entry_approved_rows" -eq "$expected_authority_rows" && "$real_public_registry_declared_rows" -eq "$expected_authority_rows" && "$non_fixture_declared_rows" -eq "$expected_authority_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$official_public_registry_rows" \
    "$expected_authority_rows" \
    "$source_import_recorded_rows" \
    "$authority_review_recorded_rows" \
    "$artifact_hash_review_ready_rows" \
    "$source_import_binding_review_ready_rows" \
    "$registry_entry_approved_rows" \
    "$real_public_registry_declared_rows" \
    "$non_fixture_declared_rows"
  printf "source-import-public-registry,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_public_registry_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_public_registry_ready" \
    "$action"
  printf "source-import-verification,%s,verified=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
