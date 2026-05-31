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

PREFIX="v08_external_benchmark_source_import_live_review_gate"
LIVE_VERIFIER_PREFIX="v08_external_benchmark_source_import_live_verifier_gate"
VERIFIER_PREFIX="v08_external_benchmark_source_import_verifier_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_live_review_gate_smoke"
  LIVE_VERIFIER_PREFIX="v08_external_benchmark_source_import_live_verifier_gate_smoke"
  VERIFIER_PREFIX="v08_external_benchmark_source_import_verifier_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_verifier_gate.sh" "${RUN_ARGS[@]}" >/dev/null

LIVE_VERIFIER_SUMMARY_CSV="$RESULTS_DIR/${LIVE_VERIFIER_PREFIX}_summary.csv"
VERIFIER_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV:-$RESULTS_DIR/${VERIFIER_PREFIX}_verifier.csv}"
REVIEW_CSV="$RESULTS_DIR/${PREFIX}_review.csv"
REVIEW_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_review_header() {
  echo "benchmark_family,source_import_id,verifier_run_id,live_review_id,live_review_report_uri,live_review_report_hash,live_reviewer_identity_uri,live_reviewer_identity_hash,live_reviewer_conflict_disclosure_uri,live_reviewer_conflict_disclosure_hash,reviewed_verifier_binary_hash,reviewed_verifier_command_hash,reviewed_verifier_stdout_hash,reviewed_verifier_stderr_hash,reviewed_import_manifest_hash,reviewed_import_fetch_log_hash,reviewer_name,reviewer_org,reviewer_role,reviewer_independent,review_protocol_version,live_fetch_observed,network_isolation_review_ready,artifact_hash_review_ready,source_import_binding_review_ready,review_approved,real_live_review_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate,live_review_report_hash_attested,live_reviewer_identity_hash_attested,live_reviewer_conflict_disclosure_hash_attested"
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

count_review_artifact() {
  local uri="$1"
  local hash="$2"
  local attested="$3"
  local counter_prefix="$4"

  if uri_to_local_path "$uri" >/dev/null; then
    case "$counter_prefix" in
      report) ((local_review_report_rows += 1)); ((review_report_rows += 1)) ;;
      identity) ((local_reviewer_identity_rows += 1)); ((reviewer_identity_rows += 1)) ;;
      conflict) ((local_reviewer_conflict_rows += 1)); ((reviewer_conflict_rows += 1)) ;;
      *) echo "unknown review artifact counter: $counter_prefix" >&2; exit 2 ;;
    esac
    if hash_matches_uri "$uri" "$hash"; then
      case "$counter_prefix" in
        report) ((review_report_hash_verified_rows += 1)) ;;
        identity) ((reviewer_identity_hash_verified_rows += 1)) ;;
        conflict) ((reviewer_conflict_hash_verified_rows += 1)) ;;
      esac
    fi
  elif is_https_uri "$uri" && [[ "$attested" == "1" ]] && is_sha256 "$hash"; then
    case "$counter_prefix" in
      report) ((nonlocal_review_report_rows += 1)); ((review_report_rows += 1)); ((review_report_hash_verified_rows += 1)) ;;
      identity) ((nonlocal_reviewer_identity_rows += 1)); ((reviewer_identity_rows += 1)); ((reviewer_identity_hash_verified_rows += 1)) ;;
      conflict) ((nonlocal_reviewer_conflict_rows += 1)); ((reviewer_conflict_rows += 1)); ((reviewer_conflict_hash_verified_rows += 1)) ;;
      *) echo "unknown review artifact counter: $counter_prefix" >&2; exit 2 ;;
    esac
  fi
}

LIVE_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_source source_import_action source_import_contract_ready upstream_source_import_verified source_import_verifier_source expected_verifier_rows source_import_verifier_rows live_network_verifier_rows offline_replay_rows declared_real_verifier_rows non_fixture_declared_rows source_import_verifier_ready source_import_live_verifier_ready source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-p live verifier summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
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
        $idx["non_fixture_declared_rows"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_live_verifier_ready"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-p live verifier summary row", 3)
    }
  ' "$LIVE_VERIFIER_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_source source_import_action source_import_contract_ready upstream_source_import_verified source_import_verifier_source expected_verifier_rows source_import_verifier_rows live_network_verifier_rows offline_replay_rows declared_real_verifier_rows verifier_non_fixture_declared_rows source_import_verifier_ready source_import_live_verifier_ready upstream_source_import_verified_after_live live_verifier_action live_routing live_jump <<<"$LIVE_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV:-}" ]]; then
  REVIEW_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV"
  REVIEW_SOURCE="provided-csv"
  if [[ ! -s "$REVIEW_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_review_header >"$REVIEW_CSV"
fi

declare -A expected_source_import_id
declare -A expected_verifier_run_id
declare -A expected_verifier_binary_hash
declare -A expected_verifier_command_hash
declare -A expected_verifier_stdout_hash
declare -A expected_verifier_stderr_hash
declare -A expected_import_manifest_hash
declare -A expected_import_fetch_log_hash

expected_verifier_rows_seen=0
if [[ -s "$VERIFIER_CSV" ]]; then
  VERIFIER_TSV="$TMP_DIR/verifier.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id verifier_run_id verifier_binary_hash verifier_command_hash verifier_stdout_hash verifier_stderr_hash verified_import_manifest_hash verified_import_fetch_log_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-p verifier column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-p verifier row has wrong column count", 11)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["source_import_id"],
        $idx["verifier_run_id"],
        $idx["verifier_binary_hash"],
        $idx["verifier_command_hash"],
        $idx["verifier_stdout_hash"],
        $idx["verifier_stderr_hash"],
        $idx["verified_import_manifest_hash"],
        $idx["verified_import_fetch_log_hash"]
    }
  ' "$VERIFIER_CSV" >"$VERIFIER_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id verifier_binary_hash verifier_command_hash verifier_stdout_hash verifier_stderr_hash import_manifest_hash import_fetch_log_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-p verifier family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_verifier_run_id["$benchmark_family"]="$verifier_run_id"
    expected_verifier_binary_hash["$benchmark_family"]="$verifier_binary_hash"
    expected_verifier_command_hash["$benchmark_family"]="$verifier_command_hash"
    expected_verifier_stdout_hash["$benchmark_family"]="$verifier_stdout_hash"
    expected_verifier_stderr_hash["$benchmark_family"]="$verifier_stderr_hash"
    expected_import_manifest_hash["$benchmark_family"]="$import_manifest_hash"
    expected_import_fetch_log_hash["$benchmark_family"]="$import_fetch_log_hash"
    ((expected_verifier_rows_seen += 1))
  done <"$VERIFIER_TSV"
fi

review_rows=0
matched_verifier_rows=0
source_import_id_match_rows=0
verifier_run_id_match_rows=0
verifier_hash_match_rows=0
import_hash_match_rows=0
review_metadata_rows=0
review_report_rows=0
review_report_hash_verified_rows=0
local_review_report_rows=0
nonlocal_review_report_rows=0
reviewer_identity_rows=0
reviewer_identity_hash_verified_rows=0
local_reviewer_identity_rows=0
nonlocal_reviewer_identity_rows=0
reviewer_conflict_rows=0
reviewer_conflict_hash_verified_rows=0
local_reviewer_conflict_rows=0
nonlocal_reviewer_conflict_rows=0
independent_reviewer_rows=0
live_fetch_observed_rows=0
network_isolation_review_ready_rows=0
artifact_hash_review_ready_rows=0
source_import_binding_review_ready_rows=0
review_approved_rows=0
real_live_review_declared_rows=0
non_fixture_declared_rows=0
review_routing="0.000000"
review_jump="0.000000"
declare -A review_seen

REVIEW_TSV="$TMP_DIR/review.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id verifier_run_id live_review_id live_review_report_uri live_review_report_hash live_reviewer_identity_uri live_reviewer_identity_hash live_reviewer_conflict_disclosure_uri live_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_command_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash reviewed_import_manifest_hash reviewed_import_fetch_log_hash reviewer_name reviewer_org reviewer_role reviewer_independent review_protocol_version live_fetch_observed network_isolation_review_ready artifact_hash_review_ready source_import_binding_review_ready review_approved real_live_review_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-p live review column: " required[i], 13)
    }
    report_attested_idx = ("live_review_report_hash_attested" in idx) ? idx["live_review_report_hash_attested"] : 0
    identity_attested_idx = ("live_reviewer_identity_hash_attested" in idx) ? idx["live_reviewer_identity_hash_attested"] : 0
    conflict_attested_idx = ("live_reviewer_conflict_disclosure_hash_attested" in idx) ? idx["live_reviewer_conflict_disclosure_hash_attested"] : 0
    next
  }
  {
    if (NF != header_fields) die("v08-p live review row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%d\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["verifier_run_id"],
      $idx["live_review_id"],
      $idx["live_review_report_uri"],
      $idx["live_review_report_hash"],
      $idx["live_reviewer_identity_uri"],
      $idx["live_reviewer_identity_hash"],
      $idx["live_reviewer_conflict_disclosure_uri"],
      $idx["live_reviewer_conflict_disclosure_hash"],
      $idx["reviewed_verifier_binary_hash"],
      $idx["reviewed_verifier_command_hash"],
      $idx["reviewed_verifier_stdout_hash"],
      $idx["reviewed_verifier_stderr_hash"],
      $idx["reviewed_import_manifest_hash"],
      $idx["reviewed_import_fetch_log_hash"],
      $idx["reviewer_name"],
      $idx["reviewer_org"],
      $idx["reviewer_role"],
      $idx["reviewer_independent"] + 0,
      $idx["review_protocol_version"],
      $idx["live_fetch_observed"] + 0,
      $idx["network_isolation_review_ready"] + 0,
      $idx["artifact_hash_review_ready"] + 0,
      $idx["source_import_binding_review_ready"] + 0,
      $idx["review_approved"] + 0,
      $idx["real_live_review_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0,
      report_attested_idx ? $report_attested_idx + 0 : 0,
      identity_attested_idx ? $identity_attested_idx + 0 : 0,
      conflict_attested_idx ? $conflict_attested_idx + 0 : 0
  }
' "$REVIEW_CSV" >"$REVIEW_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id verifier_run_id live_review_id live_review_report_uri live_review_report_hash live_reviewer_identity_uri live_reviewer_identity_hash live_reviewer_conflict_disclosure_uri live_reviewer_conflict_disclosure_hash reviewed_verifier_binary_hash reviewed_verifier_command_hash reviewed_verifier_stdout_hash reviewed_verifier_stderr_hash reviewed_import_manifest_hash reviewed_import_fetch_log_hash reviewer_name reviewer_org reviewer_role reviewer_independent review_protocol_version live_fetch_observed network_isolation_review_ready artifact_hash_review_ready source_import_binding_review_ready review_approved real_live_review_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate report_hash_attested identity_hash_attested conflict_hash_attested; do
  ((review_rows += 1))
  if [[ -n "${review_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-p live review family: $benchmark_family" >&2
    exit 15
  fi
  review_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_verifier_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_verifier_run_id[$benchmark_family]:-}" == "$verifier_run_id" ]] && is_present "$verifier_run_id"; then
    ((verifier_run_id_match_rows += 1))
  fi
  if [[ "${expected_verifier_binary_hash[$benchmark_family]:-}" == "$reviewed_verifier_binary_hash" &&
        "${expected_verifier_command_hash[$benchmark_family]:-}" == "$reviewed_verifier_command_hash" &&
        "${expected_verifier_stdout_hash[$benchmark_family]:-}" == "$reviewed_verifier_stdout_hash" &&
        "${expected_verifier_stderr_hash[$benchmark_family]:-}" == "$reviewed_verifier_stderr_hash" ]] &&
      is_sha256 "$reviewed_verifier_binary_hash" &&
      is_sha256 "$reviewed_verifier_command_hash" &&
      is_sha256 "$reviewed_verifier_stdout_hash" &&
      is_sha256 "$reviewed_verifier_stderr_hash"; then
    ((verifier_hash_match_rows += 1))
  fi
  if [[ "${expected_import_manifest_hash[$benchmark_family]:-}" == "$reviewed_import_manifest_hash" &&
        "${expected_import_fetch_log_hash[$benchmark_family]:-}" == "$reviewed_import_fetch_log_hash" ]] &&
      is_sha256 "$reviewed_import_manifest_hash" &&
      is_sha256 "$reviewed_import_fetch_log_hash"; then
    ((import_hash_match_rows += 1))
  fi

  if is_present "$live_review_id" &&
      is_present "$live_review_report_uri" &&
      is_sha256 "$live_review_report_hash" &&
      is_present "$live_reviewer_identity_uri" &&
      is_sha256 "$live_reviewer_identity_hash" &&
      is_present "$live_reviewer_conflict_disclosure_uri" &&
      is_sha256 "$live_reviewer_conflict_disclosure_hash" &&
      is_present "$reviewer_name" &&
      is_present "$reviewer_org" &&
      is_present "$reviewer_role" &&
      is_present "$review_protocol_version"; then
    ((review_metadata_rows += 1))
  fi

  count_review_artifact "$live_review_report_uri" "$live_review_report_hash" "$report_hash_attested" report
  count_review_artifact "$live_reviewer_identity_uri" "$live_reviewer_identity_hash" "$identity_hash_attested" identity
  count_review_artifact "$live_reviewer_conflict_disclosure_uri" "$live_reviewer_conflict_disclosure_hash" "$conflict_hash_attested" conflict

  if [[ "$reviewer_independent" == "1" ]]; then
    ((independent_reviewer_rows += 1))
  fi
  if [[ "$live_fetch_observed" == "1" ]]; then
    ((live_fetch_observed_rows += 1))
  fi
  if [[ "$network_isolation_review_ready" == "1" ]]; then
    ((network_isolation_review_ready_rows += 1))
  fi
  if [[ "$artifact_hash_review_ready" == "1" ]]; then
    ((artifact_hash_review_ready_rows += 1))
  fi
  if [[ "$source_import_binding_review_ready" == "1" ]]; then
    ((source_import_binding_review_ready_rows += 1))
  fi
  if [[ "$review_approved" == "1" ]]; then
    ((review_approved_rows += 1))
  fi
  if [[ "$real_live_review_declared" == "1" ]]; then
    ((real_live_review_declared_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  review_routing="$(awk -v a="$review_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  review_jump="$(awk -v a="$review_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$REVIEW_TSV"

expected_review_artifact_rows="$expected_verifier_rows"
local_live_review_artifact_rows=$((local_review_report_rows + local_reviewer_identity_rows + local_reviewer_conflict_rows))
nonlocal_live_review_artifact_rows=$((nonlocal_review_report_rows + nonlocal_reviewer_identity_rows + nonlocal_reviewer_conflict_rows))

source_import_independent_live_review_ready=0
if [[ "$source_import_live_verifier_ready" == "1" &&
      "$expected_verifier_rows" -gt 0 &&
      "$expected_verifier_rows_seen" -eq "$expected_verifier_rows" &&
      "$review_rows" -eq "$expected_verifier_rows" &&
      "$matched_verifier_rows" -eq "$expected_verifier_rows" &&
      "$source_import_id_match_rows" -eq "$expected_verifier_rows" &&
      "$verifier_run_id_match_rows" -eq "$expected_verifier_rows" &&
      "$verifier_hash_match_rows" -eq "$expected_verifier_rows" &&
      "$import_hash_match_rows" -eq "$expected_verifier_rows" &&
      "$review_metadata_rows" -eq "$expected_verifier_rows" &&
      "$review_report_rows" -eq "$expected_verifier_rows" &&
      "$review_report_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$reviewer_identity_rows" -eq "$expected_verifier_rows" &&
      "$reviewer_identity_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$reviewer_conflict_rows" -eq "$expected_verifier_rows" &&
      "$reviewer_conflict_hash_verified_rows" -eq "$expected_verifier_rows" &&
      "$local_live_review_artifact_rows" -eq 0 &&
      "$nonlocal_live_review_artifact_rows" -eq $((expected_verifier_rows * 3)) &&
      "$independent_reviewer_rows" -eq "$expected_verifier_rows" &&
      "$live_fetch_observed_rows" -eq "$expected_verifier_rows" &&
      "$network_isolation_review_ready_rows" -eq "$expected_verifier_rows" &&
      "$artifact_hash_review_ready_rows" -eq "$expected_verifier_rows" &&
      "$source_import_binding_review_ready_rows" -eq "$expected_verifier_rows" &&
      "$review_approved_rows" -eq "$expected_verifier_rows" &&
      "$real_live_review_declared_rows" -eq "$expected_verifier_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_verifier_rows" &&
      "$live_routing" == "0.000000" &&
      "$live_jump" == "0.000000" &&
      "$review_routing" == "0.000000" &&
      "$review_jump" == "0.000000" ]]; then
  source_import_independent_live_review_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$live_verifier_action"
if [[ "$source_import_live_verifier_ready" == "1" ]]; then
  if [[ "$review_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-independent-live-review-missing"
  elif [[ "$review_rows" -ne "$expected_verifier_rows" ||
          "$matched_verifier_rows" -ne "$expected_verifier_rows" ||
          "$source_import_id_match_rows" -ne "$expected_verifier_rows" ||
          "$verifier_run_id_match_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-live-review-row-mismatch"
  elif [[ "$verifier_hash_match_rows" -ne "$expected_verifier_rows" ||
          "$import_hash_match_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-live-review-chain-mismatch"
  elif [[ "$review_metadata_rows" -ne "$expected_verifier_rows" ||
          "$review_report_rows" -ne "$expected_verifier_rows" ||
          "$review_report_hash_verified_rows" -ne "$expected_verifier_rows" ||
          "$reviewer_identity_rows" -ne "$expected_verifier_rows" ||
          "$reviewer_identity_hash_verified_rows" -ne "$expected_verifier_rows" ||
          "$reviewer_conflict_rows" -ne "$expected_verifier_rows" ||
          "$reviewer_conflict_hash_verified_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-live-review-artifact-missing"
  elif [[ "$local_live_review_artifact_rows" -gt 0 ||
          "$nonlocal_live_review_artifact_rows" -ne $((expected_verifier_rows * 3)) ]]; then
    action="external-benchmark-source-import-live-review-nonlocal-artifact-missing"
  elif [[ "$independent_reviewer_rows" -ne "$expected_verifier_rows" ||
          "$live_fetch_observed_rows" -ne "$expected_verifier_rows" ||
          "$network_isolation_review_ready_rows" -ne "$expected_verifier_rows" ||
          "$artifact_hash_review_ready_rows" -ne "$expected_verifier_rows" ||
          "$source_import_binding_review_ready_rows" -ne "$expected_verifier_rows" ||
          "$review_approved_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-live-review-approval-missing"
  elif [[ "$real_live_review_declared_rows" -ne "$expected_verifier_rows" ||
          "$non_fixture_declared_rows" -ne "$expected_verifier_rows" ]]; then
    action="external-benchmark-source-import-live-review-real-source-missing"
  elif [[ "$source_import_independent_live_review_ready" == "1" ]]; then
    action="external-benchmark-source-import-authoritative-live-review-missing"
  fi
fi

total_routing="$(awk -v a="$live_routing" -v b="$review_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$live_jump" -v b="$review_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_source,source_import_action,source_import_contract_ready,upstream_source_import_verified,source_import_verifier_source,expected_verifier_rows,source_import_verifier_rows,live_network_verifier_rows,offline_replay_rows,declared_real_verifier_rows,verifier_non_fixture_declared_rows,source_import_verifier_ready,source_import_live_verifier_ready,live_review_source,expected_review_rows,review_rows,matched_verifier_rows,source_import_id_match_rows,verifier_run_id_match_rows,verifier_hash_match_rows,import_hash_match_rows,review_metadata_rows,review_report_rows,review_report_hash_verified_rows,local_review_report_rows,nonlocal_review_report_rows,reviewer_identity_rows,reviewer_identity_hash_verified_rows,local_reviewer_identity_rows,nonlocal_reviewer_identity_rows,reviewer_conflict_rows,reviewer_conflict_hash_verified_rows,local_reviewer_conflict_rows,nonlocal_reviewer_conflict_rows,local_live_review_artifact_rows,nonlocal_live_review_artifact_rows,independent_reviewer_rows,live_fetch_observed_rows,network_isolation_review_ready_rows,artifact_hash_review_ready_rows,source_import_binding_review_ready_rows,review_approved_rows,real_live_review_declared_rows,non_fixture_declared_rows,source_import_independent_live_review_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08p,%d,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
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
    "$REVIEW_SOURCE" \
    "$expected_review_artifact_rows" \
    "$review_rows" \
    "$matched_verifier_rows" \
    "$source_import_id_match_rows" \
    "$verifier_run_id_match_rows" \
    "$verifier_hash_match_rows" \
    "$import_hash_match_rows" \
    "$review_metadata_rows" \
    "$review_report_rows" \
    "$review_report_hash_verified_rows" \
    "$local_review_report_rows" \
    "$nonlocal_review_report_rows" \
    "$reviewer_identity_rows" \
    "$reviewer_identity_hash_verified_rows" \
    "$local_reviewer_identity_rows" \
    "$nonlocal_reviewer_identity_rows" \
    "$reviewer_conflict_rows" \
    "$reviewer_conflict_hash_verified_rows" \
    "$local_reviewer_conflict_rows" \
    "$nonlocal_reviewer_conflict_rows" \
    "$local_live_review_artifact_rows" \
    "$nonlocal_live_review_artifact_rows" \
    "$independent_reviewer_rows" \
    "$live_fetch_observed_rows" \
    "$network_isolation_review_ready_rows" \
    "$artifact_hash_review_ready_rows" \
    "$source_import_binding_review_ready_rows" \
    "$review_approved_rows" \
    "$real_live_review_declared_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_independent_live_review_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-live-verifier,%s,live_ready=%d action=%s\n" \
    "$([[ "$source_import_live_verifier_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_verifier_ready" \
    "$live_verifier_action"
  printf "live-review-rows,%s,rows=%d expected=%d matched=%d ids=%d verifier_runs=%d\n" \
    "$([[ "$review_rows" -eq "$expected_verifier_rows" && "$matched_verifier_rows" -eq "$expected_verifier_rows" && "$source_import_id_match_rows" -eq "$expected_verifier_rows" && "$verifier_run_id_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$review_rows" \
    "$expected_verifier_rows" \
    "$matched_verifier_rows" \
    "$source_import_id_match_rows" \
    "$verifier_run_id_match_rows"
  printf "live-review-chain,%s,verifier_hash=%d/%d import_hash=%d/%d\n" \
    "$([[ "$verifier_hash_match_rows" -eq "$expected_verifier_rows" && "$import_hash_match_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$verifier_hash_match_rows" \
    "$expected_verifier_rows" \
    "$import_hash_match_rows" \
    "$expected_verifier_rows"
  printf "live-review-artifact,%s,report=%d/%d hash=%d nonlocal=%d local=%d\n" \
    "$([[ "$review_report_rows" -eq "$expected_verifier_rows" && "$review_report_hash_verified_rows" -eq "$expected_verifier_rows" && "$nonlocal_review_report_rows" -eq "$expected_verifier_rows" && "$local_review_report_rows" -eq 0 && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$review_report_rows" \
    "$expected_verifier_rows" \
    "$review_report_hash_verified_rows" \
    "$nonlocal_review_report_rows" \
    "$local_review_report_rows"
  printf "live-reviewer-identity,%s,identity=%d/%d hash=%d nonlocal=%d local=%d\n" \
    "$([[ "$reviewer_identity_rows" -eq "$expected_verifier_rows" && "$reviewer_identity_hash_verified_rows" -eq "$expected_verifier_rows" && "$nonlocal_reviewer_identity_rows" -eq "$expected_verifier_rows" && "$local_reviewer_identity_rows" -eq 0 && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$reviewer_identity_rows" \
    "$expected_verifier_rows" \
    "$reviewer_identity_hash_verified_rows" \
    "$nonlocal_reviewer_identity_rows" \
    "$local_reviewer_identity_rows"
  printf "live-reviewer-conflict,%s,conflict=%d/%d hash=%d nonlocal=%d local=%d\n" \
    "$([[ "$reviewer_conflict_rows" -eq "$expected_verifier_rows" && "$reviewer_conflict_hash_verified_rows" -eq "$expected_verifier_rows" && "$nonlocal_reviewer_conflict_rows" -eq "$expected_verifier_rows" && "$local_reviewer_conflict_rows" -eq 0 && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$reviewer_conflict_rows" \
    "$expected_verifier_rows" \
    "$reviewer_conflict_hash_verified_rows" \
    "$nonlocal_reviewer_conflict_rows" \
    "$local_reviewer_conflict_rows"
  printf "live-review-approval,%s,independent=%d/%d live_observed=%d network=%d artifact=%d binding=%d approved=%d real=%d non_fixture=%d\n" \
    "$([[ "$independent_reviewer_rows" -eq "$expected_verifier_rows" && "$live_fetch_observed_rows" -eq "$expected_verifier_rows" && "$network_isolation_review_ready_rows" -eq "$expected_verifier_rows" && "$artifact_hash_review_ready_rows" -eq "$expected_verifier_rows" && "$source_import_binding_review_ready_rows" -eq "$expected_verifier_rows" && "$review_approved_rows" -eq "$expected_verifier_rows" && "$real_live_review_declared_rows" -eq "$expected_verifier_rows" && "$non_fixture_declared_rows" -eq "$expected_verifier_rows" && "$expected_verifier_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$independent_reviewer_rows" \
    "$expected_verifier_rows" \
    "$live_fetch_observed_rows" \
    "$network_isolation_review_ready_rows" \
    "$artifact_hash_review_ready_rows" \
    "$source_import_binding_review_ready_rows" \
    "$review_approved_rows" \
    "$real_live_review_declared_rows" \
    "$non_fixture_declared_rows"
  printf "source-import-independent-live-review,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_independent_live_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_independent_live_review_ready" \
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
