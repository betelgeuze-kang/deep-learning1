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

PREFIX="v08_external_benchmark_independent_live_rerun_confirmation"
AP_PREFIX="v08_external_benchmark_runner_owned_live_execution_audit"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_independent_live_rerun_confirmation_smoke"
  AP_PREFIX="v08_external_benchmark_runner_owned_live_execution_audit_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_independent_live_rerun_confirmation_full"
  AP_PREFIX="v08_external_benchmark_runner_owned_live_execution_audit_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_runner_owned_live_execution_audit.sh" "${RUN_ARGS[@]}" >/dev/null

AP_SUMMARY_CSV="$RESULTS_DIR/${AP_PREFIX}_summary.csv"
CONFIRMATION_CSV="$RESULTS_DIR/${PREFIX}_confirmation.csv"
CONFIRMATION_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
LIVE_RERUN_CONFIRMATION_URI_FIELDS_PER_ROW=15
LIVE_RERUN_CONFIRMATION_HASH_FIELDS_PER_ROW=15
MIN_RERUN_QUERY_ROWS_PER_FAMILY=7

write_confirmation_header() {
  echo "benchmark_family,live_execution_audit_id,independent_rerun_id,independent_observer_id,v08ap_audit_bound,independent_runner_declared,independent_environment_declared,live_network_rerun_declared,external_dataset_refetch_declared,evaluator_reinvoked_declared,audit_receipt_reconciled_declared,metric_recomputed_declared,third_party_confirmation_declared,fixture_or_synthetic_declared,query_rows_rerun,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,metric_delta_abs,rerun_manifest_uri,rerun_manifest_hash,independent_command_receipt_uri,independent_command_receipt_hash,rerun_stdout_uri,rerun_stdout_hash,rerun_stderr_uri,rerun_stderr_hash,independent_network_trace_uri,independent_network_trace_hash,dataset_refetch_receipt_uri,dataset_refetch_receipt_hash,evaluator_reinvocation_log_uri,evaluator_reinvocation_log_hash,rerun_evaluator_output_uri,rerun_evaluator_output_hash,metric_recompute_diff_uri,metric_recompute_diff_hash,audit_receipt_reconciliation_uri,audit_receipt_reconciliation_hash,environment_reproduction_attestation_uri,environment_reproduction_attestation_hash,observer_identity_uri,observer_identity_hash,third_party_confirmation_report_uri,third_party_confirmation_report_hash,timestamp_authority_uri,timestamp_authority_hash,public_rerun_registry_entry_uri,public_rerun_registry_entry_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

is_https_uri() {
  local uri="$1"
  [[ "$uri" == https://* ]]
}

uri_to_local_path() {
  local uri="$1"
  if [[ "$uri" == file://* ]]; then
    printf '%s\n' "${uri#file://}"
    return 0
  fi
  return 1
}

uri_host() {
  local uri="$1"
  uri="${uri#https://}"
  printf '%s\n' "${uri%%/*}"
}

is_placeholder_domain() {
  local domain="$1"
  [[ "$domain" == "" ||
     "$domain" == "localhost" ||
     "$domain" == "127.0.0.1" ||
     "$domain" == "0.0.0.0" ||
     "$domain" == *".example.org" ||
     "$domain" == *".example.com" ||
     "$domain" == *".example.net" ||
     "$domain" == *".example.invalid" ||
     "$domain" == *".example" ||
     "$domain" == *".invalid" ||
     "$domain" == *".test" ||
     "$domain" == *".localhost" ]]
}

is_placeholder_uri() {
  local uri="$1"
  local host

  is_https_uri "$uri" || return 0
  host="$(uri_host "$uri")"
  is_placeholder_domain "$host"
}

is_nonplaceholder_https_uri() {
  local uri="$1"
  is_https_uri "$uri" && ! is_placeholder_uri "$uri"
}

is_present_timestamp() {
  local value="$1"
  [[ "$value" != "" && "$value" != "pending" && "$value" != "0" ]]
}

float_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit ((a + 0) >= (b + 0) ? 0 : 1) }'
}

float_le() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit ((a + 0) <= (b + 0) ? 0 : 1) }'
}

is_expected_family() {
  local family="$1"
  local expected

  for expected in "${EXPECTED_FAMILIES[@]}"; do
    [[ "$family" == "$expected" ]] && return 0
  done
  return 1
}

csv_value() {
  local file="$1"
  local column="$2"
  awk -F, -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(column in idx)) {
        print "missing v08-aq column: " column > "/dev/stderr"
        exit 11
      }
      next
    }
    NR == 2 {
      print $idx[column]
      found = 1
      exit
    }
    END {
      if (!found) {
        print "missing v08-aq summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_INDEPENDENT_LIVE_RERUN_CONFIRMATION_CSV:-}" ]]; then
  CONFIRMATION_CSV="$V08_EXTERNAL_BENCHMARK_INDEPENDENT_LIVE_RERUN_CONFIRMATION_CSV"
  CONFIRMATION_SOURCE="provided-csv"
  if [[ ! -s "$CONFIRMATION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_INDEPENDENT_LIVE_RERUN_CONFIRMATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_confirmation_header >"$CONFIRMATION_CSV"
fi

upstream_runner_owned_audit_ready="$(csv_value "$AP_SUMMARY_CSV" "external_benchmark_runner_owned_live_execution_audit_ready")"
upstream_real_external="$(csv_value "$AP_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AP_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AP_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AP_SUMMARY_CSV" "active_jump_rate")"

confirmation_rows=0
expected_family_rows=0
duplicate_family_rows=0
required_live_rerun_confirmation_uri_fields=0
nonlocal_live_rerun_confirmation_uri_fields=0
local_live_rerun_confirmation_uri_fields=0
nonplaceholder_live_rerun_confirmation_uri_fields=0
required_live_rerun_confirmation_hash_fields=0
live_rerun_confirmation_hash_attested_fields=0
total_rerun_query_rows=0
min_rerun_query_rows_pass_rows=0
metric_threshold_pass_rows=0
metric_delta_pass_rows=0
v08ap_audit_bound_rows=0
independent_runner_declared_rows=0
independent_environment_declared_rows=0
live_network_rerun_declared_rows=0
external_dataset_refetch_declared_rows=0
evaluator_reinvoked_declared_rows=0
audit_receipt_reconciled_declared_rows=0
metric_recomputed_declared_rows=0
third_party_confirmation_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
confirmation_routing="0.000000"
confirmation_jump="0.000000"
declare -A confirmation_family_seen=()

CONFIRMATION_TSV="$TMP_DIR/independent_live_rerun_confirmation.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family live_execution_audit_id independent_rerun_id independent_observer_id v08ap_audit_bound independent_runner_declared independent_environment_declared live_network_rerun_declared external_dataset_refetch_declared evaluator_reinvoked_declared audit_receipt_reconciled_declared metric_recomputed_declared third_party_confirmation_declared fixture_or_synthetic_declared query_rows_rerun span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate metric_delta_abs rerun_manifest_uri rerun_manifest_hash independent_command_receipt_uri independent_command_receipt_hash rerun_stdout_uri rerun_stdout_hash rerun_stderr_uri rerun_stderr_hash independent_network_trace_uri independent_network_trace_hash dataset_refetch_receipt_uri dataset_refetch_receipt_hash evaluator_reinvocation_log_uri evaluator_reinvocation_log_hash rerun_evaluator_output_uri rerun_evaluator_output_hash metric_recompute_diff_uri metric_recompute_diff_hash audit_receipt_reconciliation_uri audit_receipt_reconciliation_hash environment_reproduction_attestation_uri environment_reproduction_attestation_hash observer_identity_uri observer_identity_hash third_party_confirmation_report_uri third_party_confirmation_report_hash timestamp_authority_uri timestamp_authority_hash public_rerun_registry_entry_uri public_rerun_registry_entry_hash observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-aq independent live rerun confirmation column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-aq independent live rerun confirmation row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$CONFIRMATION_CSV" >"$CONFIRMATION_TSV"

while IFS=$'\t' read -r benchmark_family live_execution_audit_id independent_rerun_id independent_observer_id v08ap_audit_bound independent_runner_declared independent_environment_declared live_network_rerun_declared external_dataset_refetch_declared evaluator_reinvoked_declared audit_receipt_reconciled_declared metric_recomputed_declared third_party_confirmation_declared fixture_or_synthetic_declared query_rows_rerun span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate metric_delta_abs rerun_manifest_uri rerun_manifest_hash independent_command_receipt_uri independent_command_receipt_hash rerun_stdout_uri rerun_stdout_hash rerun_stderr_uri rerun_stderr_hash independent_network_trace_uri independent_network_trace_hash dataset_refetch_receipt_uri dataset_refetch_receipt_hash evaluator_reinvocation_log_uri evaluator_reinvocation_log_hash rerun_evaluator_output_uri rerun_evaluator_output_hash metric_recompute_diff_uri metric_recompute_diff_hash audit_receipt_reconciliation_uri audit_receipt_reconciliation_hash environment_reproduction_attestation_uri environment_reproduction_attestation_hash observer_identity_uri observer_identity_hash third_party_confirmation_report_uri third_party_confirmation_report_hash timestamp_authority_uri timestamp_authority_hash public_rerun_registry_entry_uri public_rerun_registry_entry_hash observed_at_utc routing_trigger_rate active_jump_rate; do
  ((confirmation_rows += 1))
  ((total_rerun_query_rows += query_rows_rerun))

  if [[ -n "${confirmation_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  confirmation_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi

  for pair in \
    "$rerun_manifest_uri|$rerun_manifest_hash" \
    "$independent_command_receipt_uri|$independent_command_receipt_hash" \
    "$rerun_stdout_uri|$rerun_stdout_hash" \
    "$rerun_stderr_uri|$rerun_stderr_hash" \
    "$independent_network_trace_uri|$independent_network_trace_hash" \
    "$dataset_refetch_receipt_uri|$dataset_refetch_receipt_hash" \
    "$evaluator_reinvocation_log_uri|$evaluator_reinvocation_log_hash" \
    "$rerun_evaluator_output_uri|$rerun_evaluator_output_hash" \
    "$metric_recompute_diff_uri|$metric_recompute_diff_hash" \
    "$audit_receipt_reconciliation_uri|$audit_receipt_reconciliation_hash" \
    "$environment_reproduction_attestation_uri|$environment_reproduction_attestation_hash" \
    "$observer_identity_uri|$observer_identity_hash" \
    "$third_party_confirmation_report_uri|$third_party_confirmation_report_hash" \
    "$timestamp_authority_uri|$timestamp_authority_hash" \
    "$public_rerun_registry_entry_uri|$public_rerun_registry_entry_hash"; do
    ((required_live_rerun_confirmation_uri_fields += 1))
    ((required_live_rerun_confirmation_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((live_rerun_confirmation_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_live_rerun_confirmation_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_live_rerun_confirmation_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_live_rerun_confirmation_uri_fields += 1))
    fi
  done

  if [[ "$query_rows_rerun" -ge "$MIN_RERUN_QUERY_ROWS_PER_FAMILY" ]]; then
    ((min_rerun_query_rows_pass_rows += 1))
  fi
  if float_ge "$span_exact" "0.800000" &&
     float_ge "$chunk_exact" "0.750000" &&
     float_ge "$missing_abstain" "0.850000" &&
     float_le "$near_miss_false_positive" "0.050000" &&
     float_le "$wrong_answer_rate" "0.080000"; then
    ((metric_threshold_pass_rows += 1))
  fi
  if float_le "$metric_delta_abs" "0.020000"; then
    ((metric_delta_pass_rows += 1))
  fi

  [[ "$v08ap_audit_bound" == "1" ]] && ((v08ap_audit_bound_rows += 1))
  [[ "$independent_runner_declared" == "1" ]] && ((independent_runner_declared_rows += 1))
  [[ "$independent_environment_declared" == "1" ]] && ((independent_environment_declared_rows += 1))
  [[ "$live_network_rerun_declared" == "1" ]] && ((live_network_rerun_declared_rows += 1))
  [[ "$external_dataset_refetch_declared" == "1" ]] && ((external_dataset_refetch_declared_rows += 1))
  [[ "$evaluator_reinvoked_declared" == "1" ]] && ((evaluator_reinvoked_declared_rows += 1))
  [[ "$audit_receipt_reconciled_declared" == "1" ]] && ((audit_receipt_reconciled_declared_rows += 1))
  [[ "$metric_recomputed_declared" == "1" ]] && ((metric_recomputed_declared_rows += 1))
  [[ "$third_party_confirmation_declared" == "1" ]] && ((third_party_confirmation_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  confirmation_routing="$(awk -v a="$confirmation_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  confirmation_jump="$(awk -v a="$confirmation_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$CONFIRMATION_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${confirmation_family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

expected_live_rerun_confirmation_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * LIVE_RERUN_CONFIRMATION_URI_FIELDS_PER_ROW))
expected_live_rerun_confirmation_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * LIVE_RERUN_CONFIRMATION_HASH_FIELDS_PER_ROW))
external_benchmark_independent_live_rerun_confirmation_ready=0
if [[ "$upstream_runner_owned_audit_ready" == "1" &&
      "$confirmation_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$required_live_rerun_confirmation_uri_fields" -eq "$expected_live_rerun_confirmation_uri_fields" &&
      "$nonlocal_live_rerun_confirmation_uri_fields" -eq "$expected_live_rerun_confirmation_uri_fields" &&
      "$local_live_rerun_confirmation_uri_fields" -eq 0 &&
      "$nonplaceholder_live_rerun_confirmation_uri_fields" -eq "$expected_live_rerun_confirmation_uri_fields" &&
      "$required_live_rerun_confirmation_hash_fields" -eq "$expected_live_rerun_confirmation_hash_fields" &&
      "$live_rerun_confirmation_hash_attested_fields" -eq "$expected_live_rerun_confirmation_hash_fields" &&
      "$min_rerun_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_delta_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$v08ap_audit_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_runner_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_environment_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_network_rerun_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$external_dataset_refetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$evaluator_reinvoked_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$audit_receipt_reconciled_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_recomputed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$third_party_confirmation_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$confirmation_routing" == "0.000000" &&
      "$confirmation_jump" == "0.000000" ]]; then
  external_benchmark_independent_live_rerun_confirmation_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$confirmation_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$confirmation_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-runner-owned-live-execution-audit-not-ready"
if [[ "$upstream_runner_owned_audit_ready" != "1" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-not-ready"
elif [[ "$confirmation_rows" -eq 0 ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-missing"
elif [[ "$confirmation_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-coverage-incomplete"
elif [[ "$required_live_rerun_confirmation_hash_fields" -ne "$expected_live_rerun_confirmation_hash_fields" ||
        "$live_rerun_confirmation_hash_attested_fields" -ne "$expected_live_rerun_confirmation_hash_fields" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-hash-attestation-missing"
elif [[ "$required_live_rerun_confirmation_uri_fields" -ne "$expected_live_rerun_confirmation_uri_fields" ||
        "$nonlocal_live_rerun_confirmation_uri_fields" -ne "$expected_live_rerun_confirmation_uri_fields" ||
        "$local_live_rerun_confirmation_uri_fields" -ne 0 ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-local-artifact-uri"
elif [[ "$nonplaceholder_live_rerun_confirmation_uri_fields" -ne "$expected_live_rerun_confirmation_uri_fields" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-placeholder-artifact-uri"
elif [[ "$min_rerun_query_rows_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-query-volume-insufficient"
elif [[ "$metric_threshold_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-quality-threshold-missing"
elif [[ "$metric_delta_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-metric-delta-too-large"
elif [[ "$v08ap_audit_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-binding-missing"
elif [[ "$independent_runner_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$independent_environment_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-independent-declaration-missing"
elif [[ "$live_network_rerun_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$external_dataset_refetch_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$evaluator_reinvoked_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-live-rerun-declaration-missing"
elif [[ "$audit_receipt_reconciled_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$metric_recomputed_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$third_party_confirmation_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-reconciliation-declaration-missing"
elif [[ "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-fixture-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-jump-guardrail-violated"
elif [[ "$external_benchmark_independent_live_rerun_confirmation_ready" == "1" ]]; then
  action="independent-live-rerun-confirmation-ready-await-real-nonfixture-benchmark-run-package"
fi

summary_header=(
  benchmark_scope
  confirmation_source
  upstream_runner_owned_live_execution_audit_ready
  upstream_real_external
  upstream_action
  confirmation_rows
  expected_family_rows
  duplicate_family_rows
  family_coverage
  expected_external_families
  required_live_rerun_confirmation_uri_fields
  nonlocal_live_rerun_confirmation_uri_fields
  local_live_rerun_confirmation_uri_fields
  nonplaceholder_live_rerun_confirmation_uri_fields
  required_live_rerun_confirmation_hash_fields
  live_rerun_confirmation_hash_attested_fields
  total_rerun_query_rows
  min_rerun_query_rows_pass_rows
  metric_threshold_pass_rows
  metric_delta_pass_rows
  v08ap_audit_bound_rows
  independent_runner_declared_rows
  independent_environment_declared_rows
  live_network_rerun_declared_rows
  external_dataset_refetch_declared_rows
  evaluator_reinvoked_declared_rows
  audit_receipt_reconciled_declared_rows
  metric_recomputed_declared_rows
  third_party_confirmation_declared_rows
  fixture_free_rows
  timestamp_rows
  external_benchmark_independent_live_rerun_confirmation_ready
  real_external_benchmark_verified
  action
  routing_trigger_rate
  active_jump_rate
)
summary_values=(
  route-memory-v08aq
  "$CONFIRMATION_SOURCE"
  "$upstream_runner_owned_audit_ready"
  "$upstream_real_external"
  "$upstream_action"
  "$confirmation_rows"
  "$expected_family_rows"
  "$duplicate_family_rows"
  "$family_coverage"
  "$EXPECTED_EXTERNAL_FAMILIES"
  "$required_live_rerun_confirmation_uri_fields"
  "$nonlocal_live_rerun_confirmation_uri_fields"
  "$local_live_rerun_confirmation_uri_fields"
  "$nonplaceholder_live_rerun_confirmation_uri_fields"
  "$required_live_rerun_confirmation_hash_fields"
  "$live_rerun_confirmation_hash_attested_fields"
  "$total_rerun_query_rows"
  "$min_rerun_query_rows_pass_rows"
  "$metric_threshold_pass_rows"
  "$metric_delta_pass_rows"
  "$v08ap_audit_bound_rows"
  "$independent_runner_declared_rows"
  "$independent_environment_declared_rows"
  "$live_network_rerun_declared_rows"
  "$external_dataset_refetch_declared_rows"
  "$evaluator_reinvoked_declared_rows"
  "$audit_receipt_reconciled_declared_rows"
  "$metric_recomputed_declared_rows"
  "$third_party_confirmation_declared_rows"
  "$fixture_free_rows"
  "$timestamp_rows"
  "$external_benchmark_independent_live_rerun_confirmation_ready"
  "$real_external_benchmark_verified"
  "$action"
  "$routing_trigger_rate"
  "$active_jump_rate"
)
{
  (IFS=,; printf '%s\n' "${summary_header[*]}")
  (IFS=,; printf '%s\n' "${summary_values[*]}")
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "upstream-runner-owned-live-execution-audit,%s,ready=%d action=%s\n" \
    "$([[ "$upstream_runner_owned_audit_ready" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_runner_owned_audit_ready" \
    "$upstream_action"
  printf "independent-live-rerun-confirmation-coverage,%s,coverage=%d/%d rows=%d duplicates=%d\n" \
    "$([[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$confirmation_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$confirmation_rows" \
    "$duplicate_family_rows"
  printf "independent-live-rerun-confirmation-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$([[ "$nonlocal_live_rerun_confirmation_uri_fields" -eq "$expected_live_rerun_confirmation_uri_fields" && "$live_rerun_confirmation_hash_attested_fields" -eq "$expected_live_rerun_confirmation_hash_fields" && "$local_live_rerun_confirmation_uri_fields" -eq 0 && "$nonplaceholder_live_rerun_confirmation_uri_fields" -eq "$expected_live_rerun_confirmation_uri_fields" ]] && echo pass || echo blocked)" \
    "$nonlocal_live_rerun_confirmation_uri_fields" \
    "$expected_live_rerun_confirmation_uri_fields" \
    "$live_rerun_confirmation_hash_attested_fields" \
    "$expected_live_rerun_confirmation_hash_fields" \
    "$local_live_rerun_confirmation_uri_fields" \
    "$nonplaceholder_live_rerun_confirmation_uri_fields" \
    "$expected_live_rerun_confirmation_uri_fields"
  printf "independent-live-rerun-confirmation-query-volume,%s,pass_rows=%d/%d total_rerun_query_rows=%d min=%d\n" \
    "$([[ "$min_rerun_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$min_rerun_query_rows_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$total_rerun_query_rows" \
    "$MIN_RERUN_QUERY_ROWS_PER_FAMILY"
  printf "independent-live-rerun-confirmation-metric-thresholds,%s,pass_rows=%d/%d\n" \
    "$([[ "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_threshold_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "independent-live-rerun-confirmation-metric-delta,%s,pass_rows=%d/%d max_abs_delta=0.020000\n" \
    "$([[ "$metric_delta_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_delta_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "independent-live-rerun-confirmation-bindings,%s,v08ap=%d expected=%d\n" \
    "$([[ "$v08ap_audit_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$v08ap_audit_bound_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "independent-runner-declarations,%s,runner=%d environment=%d expected=%d\n" \
    "$([[ "$independent_runner_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$independent_environment_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$independent_runner_declared_rows" \
    "$independent_environment_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "live-rerun-declarations,%s,network=%d dataset=%d evaluator=%d expected=%d\n" \
    "$([[ "$live_network_rerun_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$external_dataset_refetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$evaluator_reinvoked_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$live_network_rerun_declared_rows" \
    "$external_dataset_refetch_declared_rows" \
    "$evaluator_reinvoked_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "rerun-reconciliation-declarations,%s,reconciled=%d recomputed=%d third_party=%d expected=%d\n" \
    "$([[ "$audit_receipt_reconciled_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$metric_recomputed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$third_party_confirmation_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$audit_receipt_reconciled_declared_rows" \
    "$metric_recomputed_declared_rows" \
    "$third_party_confirmation_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "fixture-declarations,%s,fixture_free=%d timestamp=%d expected=%d\n" \
    "$([[ "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "external-benchmark-independent-live-rerun-confirmation,%s,ready=%d action=%s\n" \
    "$([[ "$external_benchmark_independent_live_rerun_confirmation_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_independent_live_rerun_confirmation_ready" \
    "$action"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d\n" \
    blocked \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "confirmation: $CONFIRMATION_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
