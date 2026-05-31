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

PREFIX="v08_external_benchmark_source_import_authoritative_review_gate"
LIVE_REVIEW_PREFIX="v08_external_benchmark_source_import_live_review_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_authoritative_review_gate_smoke"
  LIVE_REVIEW_PREFIX="v08_external_benchmark_source_import_live_review_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_review_gate.sh" "${RUN_ARGS[@]}" >/dev/null

LIVE_REVIEW_SUMMARY_CSV="$RESULTS_DIR/${LIVE_REVIEW_PREFIX}_summary.csv"
LIVE_REVIEW_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV:-$RESULTS_DIR/${LIVE_REVIEW_PREFIX}_review.csv}"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/${PREFIX}_review.csv"
AUTHORITY_REVIEW_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_authority_review_header() {
  echo "benchmark_family,source_import_id,verifier_run_id,live_review_id,authority_review_id,authority_review_report_uri,authority_review_report_hash,authority_reviewer_identity_uri,authority_reviewer_identity_hash,authority_reviewer_registry_uri,authority_reviewer_registry_hash,authority_reviewer_conflict_disclosure_uri,authority_reviewer_conflict_disclosure_hash,reviewed_live_review_report_hash,reviewed_live_reviewer_identity_hash,reviewed_live_reviewer_conflict_disclosure_hash,reviewed_verifier_binary_hash,reviewed_verifier_stdout_hash,reviewed_verifier_stderr_hash,reviewer_name,reviewer_org,reviewer_role,reviewer_independent,authority_registry_id,authority_basis,review_protocol_version,authoritative_source_import_review,live_review_reproduced,artifact_hash_review_ready,source_import_binding_review_ready,review_approved,real_authority_review_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,authority_review_report_hash_attested,authority_reviewer_identity_hash_attested,authority_reviewer_registry_hash_attested,authority_reviewer_conflict_disclosure_hash_attested"
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

count_authority_artifact() {
  local uri="$1"
  local hash="$2"
  local attested="$3"
  local counter="$4"

  if uri_to_local_path "$uri" >/dev/null; then
    case "$counter" in
      report) ((local_authority_report_rows += 1)); ((authority_report_rows += 1)) ;;
      identity) ((local_authority_identity_rows += 1)); ((authority_identity_rows += 1)) ;;
      registry) ((local_authority_registry_rows += 1)); ((authority_registry_rows += 1)) ;;
      conflict) ((local_authority_conflict_rows += 1)); ((authority_conflict_rows += 1)) ;;
      *) echo "unknown authority artifact counter: $counter" >&2; exit 2 ;;
    esac
    if hash_matches_uri "$uri" "$hash"; then
      case "$counter" in
        report) ((authority_report_hash_verified_rows += 1)) ;;
        identity) ((authority_identity_hash_verified_rows += 1)) ;;
        registry) ((authority_registry_hash_verified_rows += 1)) ;;
        conflict) ((authority_conflict_hash_verified_rows += 1)) ;;
      esac
    fi
  elif is_https_uri "$uri" && [[ "$attested" == "1" ]] && is_sha256 "$hash"; then
    case "$counter" in
      report) ((nonlocal_authority_report_rows += 1)); ((authority_report_rows += 1)); ((authority_report_hash_verified_rows += 1)) ;;
      identity) ((nonlocal_authority_identity_rows += 1)); ((authority_identity_rows += 1)); ((authority_identity_hash_verified_rows += 1)) ;;
      registry) ((nonlocal_authority_registry_rows += 1)); ((authority_registry_rows += 1)); ((authority_registry_hash_verified_rows += 1)) ;;
      conflict) ((nonlocal_authority_conflict_rows += 1)); ((authority_conflict_rows += 1)); ((authority_conflict_hash_verified_rows += 1)) ;;
      *) echo "unknown authority artifact counter: $counter" >&2; exit 2 ;;
    esac
  fi
}

LIVE_REVIEW_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_source source_import_action source_import_contract_ready upstream_source_import_verified source_import_verifier_source expected_verifier_rows source_import_verifier_rows live_network_verifier_rows offline_replay_rows declared_real_verifier_rows verifier_non_fixture_declared_rows source_import_verifier_ready source_import_live_verifier_ready live_review_source review_rows source_import_independent_live_review_ready source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-q live-review summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_source"],
        $idx["source_import_action"],
        $idx["source_import_contract_ready"] + 0,
        $idx["upstream_source_import_verified"] + 0,
        $idx["source_import_verifier_source"],
        $idx["expected_verifier_rows"] + 0,
        $idx["source_import_verifier_rows"] + 0,
        $idx["live_network_verifier_rows"] + 0,
        $idx["offline_replay_rows"] + 0,
        $idx["declared_real_verifier_rows"] + 0,
        $idx["verifier_non_fixture_declared_rows"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_live_verifier_ready"] + 0,
        $idx["live_review_source"],
        $idx["review_rows"] + 0,
        $idx["source_import_independent_live_review_ready"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-q live-review summary row", 3)
    }
  ' "$LIVE_REVIEW_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_source source_import_action source_import_contract_ready upstream_source_import_verified source_import_verifier_source expected_verifier_rows source_import_verifier_rows live_network_verifier_rows offline_replay_rows declared_real_verifier_rows verifier_non_fixture_declared_rows source_import_verifier_ready source_import_live_verifier_ready live_review_source live_review_rows source_import_independent_live_review_ready upstream_source_import_verified_after_live_review live_review_action live_review_routing live_review_jump <<<"$LIVE_REVIEW_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV:-}" ]]; then
  AUTHORITY_REVIEW_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV"
  AUTHORITY_REVIEW_SOURCE="provided-csv"
  if [[ ! -s "$AUTHORITY_REVIEW_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_authority_review_header >"$AUTHORITY_REVIEW_CSV"
fi

declare -A expected_source_import_id
declare -A expected_verifier_run_id
declare -A expected_live_review_id
declare -A expected_live_review_report_hash
declare -A expected_live_reviewer_identity_hash
declare -A expected_live_reviewer_conflict_hash
declare -A expected_verifier_binary_hash
declare -A expected_verifier_stdout_hash
declare -A expected_verifier_stderr_hash

expected_live_review_rows_seen=0
if [[ -s "$LIVE_REVIEW_CSV" ]]; then
  LIVE_REVIEW_TSV="$TMP_DIR/live_review.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id verifier_run_id live_review_id live_review_report_hash live_reviewer_identity_hash live_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-q live-review source column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-q live-review source row has wrong column count", 11)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["source_import_id"],
        $idx["verifier_run_id"],
        $idx["live_review_id"],
        $idx["live_review_report_hash"],
        $idx["live_reviewer_identity_hash"],
        $idx["live_reviewer_conflict_disclosure_hash"],
        $idx["reviewed_verifier_binary_hash"],
        $idx["reviewed_verifier_stdout_hash"],
        $idx["reviewed_verifier_stderr_hash"]
    }
  ' "$LIVE_REVIEW_CSV" >"$LIVE_REVIEW_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id live_review_id live_review_report_hash live_reviewer_identity_hash live_reviewer_conflict_hash verifier_binary_hash verifier_stdout_hash verifier_stderr_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-q live-review family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_verifier_run_id["$benchmark_family"]="$verifier_run_id"
    expected_live_review_id["$benchmark_family"]="$live_review_id"
    expected_live_review_report_hash["$benchmark_family"]="$live_review_report_hash"
    expected_live_reviewer_identity_hash["$benchmark_family"]="$live_reviewer_identity_hash"
    expected_live_reviewer_conflict_hash["$benchmark_family"]="$live_reviewer_conflict_hash"
    expected_verifier_binary_hash["$benchmark_family"]="$verifier_binary_hash"
    expected_verifier_stdout_hash["$benchmark_family"]="$verifier_stdout_hash"
    expected_verifier_stderr_hash["$benchmark_family"]="$verifier_stderr_hash"
    ((expected_live_review_rows_seen += 1))
  done <"$LIVE_REVIEW_TSV"
fi

authority_review_rows=0
matched_live_review_rows=0
source_import_id_match_rows=0
verifier_run_id_match_rows=0
live_review_id_match_rows=0
live_review_hash_match_rows=0
verifier_hash_match_rows=0
authority_metadata_rows=0
authority_report_rows=0
authority_report_hash_verified_rows=0
local_authority_report_rows=0
nonlocal_authority_report_rows=0
authority_identity_rows=0
authority_identity_hash_verified_rows=0
local_authority_identity_rows=0
nonlocal_authority_identity_rows=0
authority_registry_rows=0
authority_registry_hash_verified_rows=0
local_authority_registry_rows=0
nonlocal_authority_registry_rows=0
authority_conflict_rows=0
authority_conflict_hash_verified_rows=0
local_authority_conflict_rows=0
nonlocal_authority_conflict_rows=0
independent_authority_rows=0
authority_basis_rows=0
authoritative_review_rows=0
live_review_reproduced_rows=0
artifact_hash_review_ready_rows=0
source_import_binding_review_ready_rows=0
authority_review_approved_rows=0
real_authority_review_declared_rows=0
non_fixture_declared_rows=0
authority_routing="0.000000"
authority_jump="0.000000"
declare -A authority_seen

AUTHORITY_TSV="$TMP_DIR/authority_review.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id verifier_run_id live_review_id authority_review_id authority_review_report_uri authority_review_report_hash authority_reviewer_identity_uri authority_reviewer_identity_hash authority_reviewer_registry_uri authority_reviewer_registry_hash authority_reviewer_conflict_disclosure_uri authority_reviewer_conflict_disclosure_hash reviewed_live_review_report_hash reviewed_live_reviewer_identity_hash reviewed_live_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash reviewer_name reviewer_org reviewer_role reviewer_independent authority_registry_id authority_basis review_protocol_version authoritative_source_import_review live_review_reproduced artifact_hash_review_ready source_import_binding_review_ready review_approved real_authority_review_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-q authority review column: " required[i], 13)
    }
    report_attested_idx = ("authority_review_report_hash_attested" in idx) ? idx["authority_review_report_hash_attested"] : 0
    identity_attested_idx = ("authority_reviewer_identity_hash_attested" in idx) ? idx["authority_reviewer_identity_hash_attested"] : 0
    registry_attested_idx = ("authority_reviewer_registry_hash_attested" in idx) ? idx["authority_reviewer_registry_hash_attested"] : 0
    conflict_attested_idx = ("authority_reviewer_conflict_disclosure_hash_attested" in idx) ? idx["authority_reviewer_conflict_disclosure_hash_attested"] : 0
    next
  }
  {
    if (NF != header_fields) die("v08-q authority review row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%d\t%d\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["verifier_run_id"],
      $idx["live_review_id"],
      $idx["authority_review_id"],
      $idx["authority_review_report_uri"],
      $idx["authority_review_report_hash"],
      $idx["authority_reviewer_identity_uri"],
      $idx["authority_reviewer_identity_hash"],
      $idx["authority_reviewer_registry_uri"],
      $idx["authority_reviewer_registry_hash"],
      $idx["authority_reviewer_conflict_disclosure_uri"],
      $idx["authority_reviewer_conflict_disclosure_hash"],
      $idx["reviewed_live_review_report_hash"],
      $idx["reviewed_live_reviewer_identity_hash"],
      $idx["reviewed_live_reviewer_conflict_disclosure_hash"],
      $idx["reviewed_verifier_binary_hash"],
      $idx["reviewed_verifier_stdout_hash"],
      $idx["reviewed_verifier_stderr_hash"],
      $idx["reviewer_name"],
      $idx["reviewer_org"],
      $idx["reviewer_role"],
      $idx["reviewer_independent"] + 0,
      $idx["authority_registry_id"],
      $idx["authority_basis"],
      $idx["review_protocol_version"],
      $idx["authoritative_source_import_review"] + 0,
      $idx["live_review_reproduced"] + 0,
      $idx["artifact_hash_review_ready"] + 0,
      $idx["source_import_binding_review_ready"] + 0,
      $idx["review_approved"] + 0,
      $idx["real_authority_review_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0,
      report_attested_idx ? $report_attested_idx + 0 : 0,
      identity_attested_idx ? $identity_attested_idx + 0 : 0,
      registry_attested_idx ? $registry_attested_idx + 0 : 0,
      conflict_attested_idx ? $conflict_attested_idx + 0 : 0
  }
' "$AUTHORITY_REVIEW_CSV" >"$AUTHORITY_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id live_review_id authority_review_id authority_review_report_uri authority_review_report_hash authority_reviewer_identity_uri authority_reviewer_identity_hash authority_reviewer_registry_uri authority_reviewer_registry_hash authority_reviewer_conflict_disclosure_uri authority_reviewer_conflict_disclosure_hash reviewed_live_review_report_hash reviewed_live_reviewer_identity_hash reviewed_live_reviewer_conflict_hash reviewed_verifier_binary_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash reviewer_name reviewer_org reviewer_role reviewer_independent authority_registry_id authority_basis review_protocol_version authoritative_source_import_review live_review_reproduced artifact_hash_review_ready source_import_binding_review_ready review_approved real_authority_review_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate report_hash_attested identity_hash_attested registry_hash_attested conflict_hash_attested; do
  ((authority_review_rows += 1))
  if [[ -n "${authority_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-q authority review family: $benchmark_family" >&2
    exit 15
  fi
  authority_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_live_review_rows += 1))
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
  if [[ "${expected_live_review_report_hash[$benchmark_family]:-}" == "$reviewed_live_review_report_hash" &&
        "${expected_live_reviewer_identity_hash[$benchmark_family]:-}" == "$reviewed_live_reviewer_identity_hash" &&
        "${expected_live_reviewer_conflict_hash[$benchmark_family]:-}" == "$reviewed_live_reviewer_conflict_hash" ]] &&
      is_sha256 "$reviewed_live_review_report_hash" &&
      is_sha256 "$reviewed_live_reviewer_identity_hash" &&
      is_sha256 "$reviewed_live_reviewer_conflict_hash"; then
    ((live_review_hash_match_rows += 1))
  fi
  if [[ "${expected_verifier_binary_hash[$benchmark_family]:-}" == "$reviewed_verifier_binary_hash" &&
        "${expected_verifier_stdout_hash[$benchmark_family]:-}" == "$reviewed_verifier_stdout_hash" &&
        "${expected_verifier_stderr_hash[$benchmark_family]:-}" == "$reviewed_verifier_stderr_hash" ]] &&
      is_sha256 "$reviewed_verifier_binary_hash" &&
      is_sha256 "$reviewed_verifier_stdout_hash" &&
      is_sha256 "$reviewed_verifier_stderr_hash"; then
    ((verifier_hash_match_rows += 1))
  fi

  if is_present "$authority_review_id" &&
      is_present "$authority_review_report_uri" &&
      is_sha256 "$authority_review_report_hash" &&
      is_present "$authority_reviewer_identity_uri" &&
      is_sha256 "$authority_reviewer_identity_hash" &&
      is_present "$authority_reviewer_registry_uri" &&
      is_sha256 "$authority_reviewer_registry_hash" &&
      is_present "$authority_reviewer_conflict_disclosure_uri" &&
      is_sha256 "$authority_reviewer_conflict_disclosure_hash" &&
      is_present "$reviewer_name" &&
      is_present "$reviewer_org" &&
      is_present "$reviewer_role" &&
      is_present "$authority_registry_id" &&
      is_present "$authority_basis" &&
      is_present "$review_protocol_version"; then
    ((authority_metadata_rows += 1))
  fi

  count_authority_artifact "$authority_review_report_uri" "$authority_review_report_hash" "$report_hash_attested" report
  count_authority_artifact "$authority_reviewer_identity_uri" "$authority_reviewer_identity_hash" "$identity_hash_attested" identity
  count_authority_artifact "$authority_reviewer_registry_uri" "$authority_reviewer_registry_hash" "$registry_hash_attested" registry
  count_authority_artifact "$authority_reviewer_conflict_disclosure_uri" "$authority_reviewer_conflict_disclosure_hash" "$conflict_hash_attested" conflict

  if [[ "$reviewer_independent" == "1" ]]; then
    ((independent_authority_rows += 1))
  fi
  if is_present "$authority_registry_id" && is_present "$authority_basis"; then
    ((authority_basis_rows += 1))
  fi
  if [[ "$authoritative_source_import_review" == "1" ]]; then
    ((authoritative_review_rows += 1))
  fi
  if [[ "$live_review_reproduced" == "1" ]]; then
    ((live_review_reproduced_rows += 1))
  fi
  if [[ "$artifact_hash_review_ready" == "1" ]]; then
    ((artifact_hash_review_ready_rows += 1))
  fi
  if [[ "$source_import_binding_review_ready" == "1" ]]; then
    ((source_import_binding_review_ready_rows += 1))
  fi
  if [[ "$review_approved" == "1" ]]; then
    ((authority_review_approved_rows += 1))
  fi
  if [[ "$real_authority_review_declared" == "1" ]]; then
    ((real_authority_review_declared_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  authority_routing="$(awk -v a="$authority_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  authority_jump="$(awk -v a="$authority_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$AUTHORITY_TSV"

local_authority_artifact_rows=$((local_authority_report_rows + local_authority_identity_rows + local_authority_registry_rows + local_authority_conflict_rows))
nonlocal_authority_artifact_rows=$((nonlocal_authority_report_rows + nonlocal_authority_identity_rows + nonlocal_authority_registry_rows + nonlocal_authority_conflict_rows))
expected_authority_artifact_rows=$((expected_verifier_rows * 4))

source_import_authoritative_review_ready=0
if [[ "$source_import_independent_live_review_ready" == "1" &&
      "$expected_verifier_rows" -gt 0 &&
      "$expected_live_review_rows_seen" -eq "$expected_verifier_rows" &&
      "$authority_review_rows" -eq "$expected_verifier_rows" &&
      "$matched_live_review_rows" -eq "$expected_verifier_rows" &&
      "$source_import_id_match_rows" -eq "$expected_verifier_rows" &&
      "$verifier_run_id_match_rows" -eq "$expected_verifier_rows" &&
      "$live_review_id_match_rows" -eq "$expected_verifier_rows" &&
      "$live_review_hash_match_rows" -eq "$expected_verifier_rows" &&
      "$verifier_hash_match_rows" -eq "$expected_verifier_rows" &&
      "$authority_metadata_rows" -eq "$expected_verifier_rows" &&
      "$authority_report_rows" -eq "$expected_verifier_rows" &&
      "$authority_report_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$authority_identity_rows" -eq "$expected_verifier_rows" &&
      "$authority_identity_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$authority_registry_rows" -eq "$expected_verifier_rows" &&
      "$authority_registry_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$authority_conflict_rows" -eq "$expected_verifier_rows" &&
      "$authority_conflict_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$local_authority_artifact_rows" -eq 0 &&
      "$nonlocal_authority_artifact_rows" -eq "$expected_authority_artifact_rows" &&
      "$independent_authority_rows" -eq "$expected_verifier_rows" &&
      "$authority_basis_rows" -eq "$expected_verifier_rows" &&
      "$authoritative_review_rows" -eq "$expected_verifier_rows" &&
      "$live_review_reproduced_rows" -eq "$expected_verifier_rows" &&
      "$artifact_hash_review_ready_rows" -eq "$expected_verifier_rows" &&
      "$source_import_binding_review_ready_rows" -eq "$expected_verifier_rows" &&
      "$authority_review_approved_rows" -eq "$expected_verifier_rows" &&
      "$real_authority_review_declared_rows" -eq "$expected_verifier_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_verifier_rows" &&
      "$live_review_routing" == "0.000000" &&
      "$live_review_jump" == "0.000000" &&
      "$authority_routing" == "0.000000" &&
      "$authority_jump" == "0.000000" ]]; then
  source_import_authoritative_review_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$live_review_action"
if [[ "$source_import_independent_live_review_ready" == "1" ]]; then
  if [[ "$authority_review_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-authoritative-live-review-missing"
  elif [[ "$authority_review_rows" -ne "$expected_verifier_rows" ||
          "$matched_live_review_rows" -ne "$expected_verifier_rows" ||
          "$source_import_id_match_rows" -ne "$expected_verifier_rows" ||
          "$verifier_run_id_match_rows" -ne "$expected_verifier_rows" ||
          "$live_review_id_match_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-authority-review-row-mismatch"
  elif [[ "$live_review_hash_match_rows" -ne "$expected_verifier_rows" ||
          "$verifier_hash_match_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-authority-review-chain-mismatch"
  elif [[ "$authority_metadata_rows" -ne "$expected_verifier_rows" ||
          "$authority_report_rows" -ne "$expected_verifier_rows" ||
          "$authority_report_hash_verified_rows" -ne "$expected_verifier_rows" ||
          "$authority_identity_rows" -ne "$expected_verifier_rows" ||
          "$authority_identity_hash_verified_rows" -ne "$expected_verifier_rows" ||
          "$authority_registry_rows" -ne "$expected_verifier_rows" ||
          "$authority_registry_hash_verified_rows" -ne "$expected_verifier_rows" ||
          "$authority_conflict_rows" -ne "$expected_verifier_rows" ||
          "$authority_conflict_hash_verified_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-authority-review-artifact-missing"
  elif [[ "$local_authority_artifact_rows" -gt 0 ||
          "$nonlocal_authority_artifact_rows" -ne "$expected_authority_artifact_rows" ]]; then
    action="external-benchmark-source-import-authority-review-nonlocal-artifact-missing"
  elif [[ "$independent_authority_rows" -ne "$expected_verifier_rows" ||
          "$authority_basis_rows" -ne "$expected_verifier_rows" ||
          "$authoritative_review_rows" -ne "$expected_verifier_rows" ||
          "$live_review_reproduced_rows" -ne "$expected_verifier_rows" ||
          "$artifact_hash_review_ready_rows" -ne "$expected_verifier_rows" ||
          "$source_import_binding_review_ready_rows" -ne "$expected_verifier_rows" ||
          "$authority_review_approved_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-authority-review-approval-missing"
  elif [[ "$real_authority_review_declared_rows" -ne "$expected_verifier_rows" ||
          "$non_fixture_declared_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-authority-review-real-source-missing"
  elif [[ "$source_import_authoritative_review_ready" == "1" ]]; then
    action="external-benchmark-source-import-real-public-registry-missing"
  fi
fi

total_routing="$(awk -v a="$live_review_routing" -v b="$authority_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$live_review_jump" -v b="$authority_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_source,source_import_action,source_import_contract_ready,upstream_source_import_verified,source_import_verifier_source,expected_verifier_rows,source_import_verifier_rows,live_network_verifier_rows,offline_replay_rows,declared_real_verifier_rows,verifier_non_fixture_declared_rows,source_import_verifier_ready,source_import_live_verifier_ready,live_review_source,live_review_rows,source_import_independent_live_review_ready,authority_review_source,expected_authority_rows,authority_review_rows,matched_live_review_rows,source_import_id_match_rows,verifier_run_id_match_rows,live_review_id_match_rows,live_review_hash_match_rows,verifier_hash_match_rows,authority_metadata_rows,authority_report_rows,authority_report_hash_verified_rows,authority_identity_rows,authority_identity_hash_verified_rows,authority_registry_rows,authority_registry_hash_verified_rows,authority_conflict_rows,authority_conflict_hash_verified_rows,local_authority_artifact_rows,nonlocal_authority_artifact_rows,independent_authority_rows,authority_basis_rows,authoritative_review_rows,live_review_reproduced_rows,artifact_hash_review_ready_rows,source_import_binding_review_ready_rows,authority_review_approved_rows,real_authority_review_declared_rows,non_fixture_declared_rows,source_import_authoritative_review_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08q,%d,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$source_import_source" \
    "$source_import_action" \
    "$source_import_contract_ready" \
    "$upstream_source_import_verified" \
    "$source_import_verifier_source" \
    "$expected_verifier_rows" \
    "$source_import_verifier_rows" \
    "$live_network_verifier_rows" \
    "$offline_replay_rows" \
    "$declared_real_verifier_rows" \
    "$verifier_non_fixture_declared_rows" \
    "$source_import_verifier_ready" \
    "$source_import_live_verifier_ready" \
    "$live_review_source" \
    "$live_review_rows" \
    "$source_import_independent_live_review_ready" \
    "$AUTHORITY_REVIEW_SOURCE" \
    "$expected_verifier_rows" \
    "$authority_review_rows" \
    "$matched_live_review_rows" \
    "$source_import_id_match_rows" \
    "$verifier_run_id_match_rows" \
    "$live_review_id_match_rows" \
    "$live_review_hash_match_rows" \
    "$verifier_hash_match_rows" \
    "$authority_metadata_rows" \
    "$authority_report_rows" \
    "$authority_report_hash_verified_rows" \
    "$authority_identity_rows" \
    "$authority_identity_hash_verified_rows" \
    "$authority_registry_rows" \
    "$authority_registry_hash_verified_rows" \
    "$authority_conflict_rows" \
    "$authority_conflict_hash_verified_rows" \
    "$local_authority_artifact_rows" \
    "$nonlocal_authority_artifact_rows" \
    "$independent_authority_rows" \
    "$authority_basis_rows" \
    "$authoritative_review_rows" \
    "$live_review_reproduced_rows" \
    "$artifact_hash_review_ready_rows" \
    "$source_import_binding_review_ready_rows" \
    "$authority_review_approved_rows" \
    "$real_authority_review_declared_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_authoritative_review_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-independent-live-review,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_independent_live_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_independent_live_review_ready" \
    "$live_review_action"
  printf "authority-review-rows,%s,rows=%d expected=%d matched=%d ids=%d verifier_runs=%d live_review_ids=%d\n" \
    "$([[ "$authority_review_rows" -eq "$expected_verifier_rows" && "$matched_live_review_rows" -eq "$expected_verifier_rows" && "$source_import_id_match_rows" -eq "$expected_verifier_rows" && "$verifier_run_id_match_rows" -eq "$expected_verifier_rows" && "$live_review_id_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$authority_review_rows" \
    "$expected_verifier_rows" \
    "$matched_live_review_rows" \
    "$source_import_id_match_rows" \
    "$verifier_run_id_match_rows" \
    "$live_review_id_match_rows"
  printf "authority-review-chain,%s,live_review_hash=%d/%d verifier_hash=%d/%d\n" \
    "$([[ "$live_review_hash_match_rows" -eq "$expected_verifier_rows" && "$verifier_hash_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$live_review_hash_match_rows" \
    "$expected_verifier_rows" \
    "$verifier_hash_match_rows" \
    "$expected_verifier_rows"
  printf "authority-review-artifacts,%s,report=%d/%d identity=%d registry=%d conflict=%d local=%d nonlocal=%d/%d\n" \
    "$([[ "$authority_report_hash_verified_rows" -eq "$expected_verifier_rows" && "$authority_identity_hash_verified_rows" -eq "$expected_verifier_rows" && "$authority_registry_hash_verified_rows" -eq "$expected_verifier_rows" && "$authority_conflict_hash_verified_rows" -eq "$expected_verifier_rows" && "$local_authority_artifact_rows" -eq 0 && "$nonlocal_authority_artifact_rows" -eq "$expected_authority_artifact_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$authority_report_rows" \
    "$expected_verifier_rows" \
    "$authority_identity_rows" \
    "$authority_registry_rows" \
    "$authority_conflict_rows" \
    "$local_authority_artifact_rows" \
    "$nonlocal_authority_artifact_rows" \
    "$expected_authority_artifact_rows"
  printf "authority-review-approval,%s,independent=%d/%d basis=%d authoritative=%d reproduced=%d artifact=%d binding=%d approved=%d real=%d non_fixture=%d\n" \
    "$([[ "$independent_authority_rows" -eq "$expected_verifier_rows" && "$authority_basis_rows" -eq "$expected_verifier_rows" && "$authoritative_review_rows" -eq "$expected_verifier_rows" && "$live_review_reproduced_rows" -eq "$expected_verifier_rows" && "$artifact_hash_review_ready_rows" -eq "$expected_verifier_rows" && "$source_import_binding_review_ready_rows" -eq "$expected_verifier_rows" && "$authority_review_approved_rows" -eq "$expected_verifier_rows" && "$real_authority_review_declared_rows" -eq "$expected_verifier_rows" && "$non_fixture_declared_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$independent_authority_rows" \
    "$expected_verifier_rows" \
    "$authority_basis_rows" \
    "$authoritative_review_rows" \
    "$live_review_reproduced_rows" \
    "$artifact_hash_review_ready_rows" \
    "$source_import_binding_review_ready_rows" \
    "$authority_review_approved_rows" \
    "$real_authority_review_declared_rows" \
    "$non_fixture_declared_rows"
  printf "source-import-authoritative-review,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_authoritative_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_authoritative_review_ready" \
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
