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

PREFIX="v08_external_benchmark_runner_owned_live_execution_audit"
AO_PREFIX="v08_external_benchmark_public_nonfixture_verification"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_runner_owned_live_execution_audit_smoke"
  AO_PREFIX="v08_external_benchmark_public_nonfixture_verification_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_runner_owned_live_execution_audit_full"
  AO_PREFIX="v08_external_benchmark_public_nonfixture_verification_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_public_nonfixture_verification.sh" "${RUN_ARGS[@]}" >/dev/null

AO_SUMMARY_CSV="$RESULTS_DIR/${AO_PREFIX}_summary.csv"
AUDIT_CSV="$RESULTS_DIR/${PREFIX}_audit.csv"
AUDIT_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
LIVE_EXECUTION_AUDIT_URI_FIELDS_PER_ROW=13
LIVE_EXECUTION_AUDIT_HASH_FIELDS_PER_ROW=13
MIN_EXECUTED_QUERY_ROWS_PER_FAMILY=7

write_audit_header() {
  echo "benchmark_family,public_verification_id,direct_run_id,live_execution_audit_id,runner_execution_id,v08ao_verification_bound,runner_owned_execution_declared,live_network_execution_declared,external_dataset_live_fetch_declared,evaluator_invoked_by_runner_declared,replay_disabled_declared,audit_log_complete_declared,third_party_audit_review_declared,fixture_or_synthetic_declared,query_rows_executed,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,live_execution_manifest_uri,live_execution_manifest_hash,live_command_receipt_uri,live_command_receipt_hash,runner_stdout_uri,runner_stdout_hash,runner_stderr_uri,runner_stderr_hash,live_network_trace_uri,live_network_trace_hash,dataset_fetch_receipt_uri,dataset_fetch_receipt_hash,evaluator_invocation_log_uri,evaluator_invocation_log_hash,evaluator_output_uri,evaluator_output_hash,metric_recompute_report_uri,metric_recompute_report_hash,environment_attestation_uri,environment_attestation_hash,audit_report_uri,audit_report_hash,auditor_identity_uri,auditor_identity_hash,public_receipt_reconciliation_uri,public_receipt_reconciliation_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ap column: " column > "/dev/stderr"
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
        print "missing v08-ap summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_RUNNER_OWNED_LIVE_EXECUTION_AUDIT_CSV:-}" ]]; then
  AUDIT_CSV="$V08_EXTERNAL_BENCHMARK_RUNNER_OWNED_LIVE_EXECUTION_AUDIT_CSV"
  AUDIT_SOURCE="provided-csv"
  if [[ ! -s "$AUDIT_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_RUNNER_OWNED_LIVE_EXECUTION_AUDIT_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_audit_header >"$AUDIT_CSV"
fi

upstream_public_nonfixture_ready="$(csv_value "$AO_SUMMARY_CSV" "external_benchmark_public_nonfixture_verification_ready")"
upstream_real_external="$(csv_value "$AO_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AO_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AO_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AO_SUMMARY_CSV" "active_jump_rate")"

audit_rows=0
expected_family_rows=0
duplicate_family_rows=0
required_live_execution_audit_uri_fields=0
nonlocal_live_execution_audit_uri_fields=0
local_live_execution_audit_uri_fields=0
nonplaceholder_live_execution_audit_uri_fields=0
required_live_execution_audit_hash_fields=0
live_execution_audit_hash_attested_fields=0
total_executed_query_rows=0
min_executed_query_rows_pass_rows=0
metric_threshold_pass_rows=0
v08ao_verification_bound_rows=0
runner_owned_execution_declared_rows=0
live_network_execution_declared_rows=0
external_dataset_live_fetch_declared_rows=0
evaluator_invoked_by_runner_declared_rows=0
replay_disabled_declared_rows=0
audit_log_complete_declared_rows=0
third_party_audit_review_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
audit_routing="0.000000"
audit_jump="0.000000"
declare -A audit_family_seen=()

AUDIT_TSV="$TMP_DIR/runner_owned_live_execution_audit.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family public_verification_id direct_run_id live_execution_audit_id runner_execution_id v08ao_verification_bound runner_owned_execution_declared live_network_execution_declared external_dataset_live_fetch_declared evaluator_invoked_by_runner_declared replay_disabled_declared audit_log_complete_declared third_party_audit_review_declared fixture_or_synthetic_declared query_rows_executed span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate live_execution_manifest_uri live_execution_manifest_hash live_command_receipt_uri live_command_receipt_hash runner_stdout_uri runner_stdout_hash runner_stderr_uri runner_stderr_hash live_network_trace_uri live_network_trace_hash dataset_fetch_receipt_uri dataset_fetch_receipt_hash evaluator_invocation_log_uri evaluator_invocation_log_hash evaluator_output_uri evaluator_output_hash metric_recompute_report_uri metric_recompute_report_hash environment_attestation_uri environment_attestation_hash audit_report_uri audit_report_hash auditor_identity_uri auditor_identity_hash public_receipt_reconciliation_uri public_receipt_reconciliation_hash observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ap runner-owned live execution audit column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ap runner-owned live execution audit row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$AUDIT_CSV" >"$AUDIT_TSV"

while IFS=$'\t' read -r benchmark_family public_verification_id direct_run_id live_execution_audit_id runner_execution_id v08ao_verification_bound runner_owned_execution_declared live_network_execution_declared external_dataset_live_fetch_declared evaluator_invoked_by_runner_declared replay_disabled_declared audit_log_complete_declared third_party_audit_review_declared fixture_or_synthetic_declared query_rows_executed span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate live_execution_manifest_uri live_execution_manifest_hash live_command_receipt_uri live_command_receipt_hash runner_stdout_uri runner_stdout_hash runner_stderr_uri runner_stderr_hash live_network_trace_uri live_network_trace_hash dataset_fetch_receipt_uri dataset_fetch_receipt_hash evaluator_invocation_log_uri evaluator_invocation_log_hash evaluator_output_uri evaluator_output_hash metric_recompute_report_uri metric_recompute_report_hash environment_attestation_uri environment_attestation_hash audit_report_uri audit_report_hash auditor_identity_uri auditor_identity_hash public_receipt_reconciliation_uri public_receipt_reconciliation_hash observed_at_utc routing_trigger_rate active_jump_rate; do
  ((audit_rows += 1))
  ((total_executed_query_rows += query_rows_executed))

  if [[ -n "${audit_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  audit_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi

  for pair in \
    "$live_execution_manifest_uri|$live_execution_manifest_hash" \
    "$live_command_receipt_uri|$live_command_receipt_hash" \
    "$runner_stdout_uri|$runner_stdout_hash" \
    "$runner_stderr_uri|$runner_stderr_hash" \
    "$live_network_trace_uri|$live_network_trace_hash" \
    "$dataset_fetch_receipt_uri|$dataset_fetch_receipt_hash" \
    "$evaluator_invocation_log_uri|$evaluator_invocation_log_hash" \
    "$evaluator_output_uri|$evaluator_output_hash" \
    "$metric_recompute_report_uri|$metric_recompute_report_hash" \
    "$environment_attestation_uri|$environment_attestation_hash" \
    "$audit_report_uri|$audit_report_hash" \
    "$auditor_identity_uri|$auditor_identity_hash" \
    "$public_receipt_reconciliation_uri|$public_receipt_reconciliation_hash"; do
    ((required_live_execution_audit_uri_fields += 1))
    ((required_live_execution_audit_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((live_execution_audit_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_live_execution_audit_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_live_execution_audit_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_live_execution_audit_uri_fields += 1))
    fi
  done

  if [[ "$query_rows_executed" -ge "$MIN_EXECUTED_QUERY_ROWS_PER_FAMILY" ]]; then
    ((min_executed_query_rows_pass_rows += 1))
  fi
  if float_ge "$span_exact" "0.800000" &&
     float_ge "$chunk_exact" "0.750000" &&
     float_ge "$missing_abstain" "0.850000" &&
     float_le "$near_miss_false_positive" "0.050000" &&
     float_le "$wrong_answer_rate" "0.080000"; then
    ((metric_threshold_pass_rows += 1))
  fi

  [[ "$v08ao_verification_bound" == "1" ]] && ((v08ao_verification_bound_rows += 1))
  [[ "$runner_owned_execution_declared" == "1" ]] && ((runner_owned_execution_declared_rows += 1))
  [[ "$live_network_execution_declared" == "1" ]] && ((live_network_execution_declared_rows += 1))
  [[ "$external_dataset_live_fetch_declared" == "1" ]] && ((external_dataset_live_fetch_declared_rows += 1))
  [[ "$evaluator_invoked_by_runner_declared" == "1" ]] && ((evaluator_invoked_by_runner_declared_rows += 1))
  [[ "$replay_disabled_declared" == "1" ]] && ((replay_disabled_declared_rows += 1))
  [[ "$audit_log_complete_declared" == "1" ]] && ((audit_log_complete_declared_rows += 1))
  [[ "$third_party_audit_review_declared" == "1" ]] && ((third_party_audit_review_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  audit_routing="$(awk -v a="$audit_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  audit_jump="$(awk -v a="$audit_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$AUDIT_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${audit_family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

expected_live_execution_audit_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * LIVE_EXECUTION_AUDIT_URI_FIELDS_PER_ROW))
expected_live_execution_audit_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * LIVE_EXECUTION_AUDIT_HASH_FIELDS_PER_ROW))
external_benchmark_runner_owned_live_execution_audit_ready=0
if [[ "$upstream_public_nonfixture_ready" == "1" &&
      "$audit_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$required_live_execution_audit_uri_fields" -eq "$expected_live_execution_audit_uri_fields" &&
      "$nonlocal_live_execution_audit_uri_fields" -eq "$expected_live_execution_audit_uri_fields" &&
      "$local_live_execution_audit_uri_fields" -eq 0 &&
      "$nonplaceholder_live_execution_audit_uri_fields" -eq "$expected_live_execution_audit_uri_fields" &&
      "$required_live_execution_audit_hash_fields" -eq "$expected_live_execution_audit_hash_fields" &&
      "$live_execution_audit_hash_attested_fields" -eq "$expected_live_execution_audit_hash_fields" &&
      "$min_executed_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$v08ao_verification_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$runner_owned_execution_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_network_execution_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$external_dataset_live_fetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$evaluator_invoked_by_runner_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$replay_disabled_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$audit_log_complete_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$third_party_audit_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$audit_routing" == "0.000000" &&
      "$audit_jump" == "0.000000" ]]; then
  external_benchmark_runner_owned_live_execution_audit_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$audit_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$audit_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-public-nonfixture-verification-not-ready"
if [[ "$upstream_public_nonfixture_ready" != "1" ]]; then
  action="external-benchmark-public-nonfixture-verification-not-ready"
elif [[ "$audit_rows" -eq 0 ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-missing"
elif [[ "$audit_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-coverage-incomplete"
elif [[ "$required_live_execution_audit_hash_fields" -ne "$expected_live_execution_audit_hash_fields" ||
        "$live_execution_audit_hash_attested_fields" -ne "$expected_live_execution_audit_hash_fields" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-hash-attestation-missing"
elif [[ "$required_live_execution_audit_uri_fields" -ne "$expected_live_execution_audit_uri_fields" ||
        "$nonlocal_live_execution_audit_uri_fields" -ne "$expected_live_execution_audit_uri_fields" ||
        "$local_live_execution_audit_uri_fields" -ne 0 ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-local-artifact-uri"
elif [[ "$nonplaceholder_live_execution_audit_uri_fields" -ne "$expected_live_execution_audit_uri_fields" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-placeholder-artifact-uri"
elif [[ "$min_executed_query_rows_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-query-volume-insufficient"
elif [[ "$metric_threshold_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-quality-threshold-missing"
elif [[ "$v08ao_verification_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-binding-missing"
elif [[ "$runner_owned_execution_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$evaluator_invoked_by_runner_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-runner-declaration-missing"
elif [[ "$live_network_execution_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$external_dataset_live_fetch_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$replay_disabled_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-live-execution-declaration-missing"
elif [[ "$audit_log_complete_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$third_party_audit_review_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-audit-declaration-missing"
elif [[ "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-fixture-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-runner-owned-live-execution-audit-jump-guardrail-violated"
elif [[ "$external_benchmark_runner_owned_live_execution_audit_ready" == "1" ]]; then
  action="runner-owned-live-execution-audit-ready-await-independent-live-rerun-confirmation"
fi

summary_header=(
  benchmark_scope
  audit_source
  upstream_public_nonfixture_verification_ready
  upstream_real_external
  upstream_action
  audit_rows
  expected_family_rows
  duplicate_family_rows
  family_coverage
  expected_external_families
  required_live_execution_audit_uri_fields
  nonlocal_live_execution_audit_uri_fields
  local_live_execution_audit_uri_fields
  nonplaceholder_live_execution_audit_uri_fields
  required_live_execution_audit_hash_fields
  live_execution_audit_hash_attested_fields
  total_executed_query_rows
  min_executed_query_rows_pass_rows
  metric_threshold_pass_rows
  v08ao_verification_bound_rows
  runner_owned_execution_declared_rows
  live_network_execution_declared_rows
  external_dataset_live_fetch_declared_rows
  evaluator_invoked_by_runner_declared_rows
  replay_disabled_declared_rows
  audit_log_complete_declared_rows
  third_party_audit_review_declared_rows
  fixture_free_rows
  timestamp_rows
  external_benchmark_runner_owned_live_execution_audit_ready
  real_external_benchmark_verified
  action
  routing_trigger_rate
  active_jump_rate
)
summary_values=(
  route-memory-v08ap
  "$AUDIT_SOURCE"
  "$upstream_public_nonfixture_ready"
  "$upstream_real_external"
  "$upstream_action"
  "$audit_rows"
  "$expected_family_rows"
  "$duplicate_family_rows"
  "$family_coverage"
  "$EXPECTED_EXTERNAL_FAMILIES"
  "$required_live_execution_audit_uri_fields"
  "$nonlocal_live_execution_audit_uri_fields"
  "$local_live_execution_audit_uri_fields"
  "$nonplaceholder_live_execution_audit_uri_fields"
  "$required_live_execution_audit_hash_fields"
  "$live_execution_audit_hash_attested_fields"
  "$total_executed_query_rows"
  "$min_executed_query_rows_pass_rows"
  "$metric_threshold_pass_rows"
  "$v08ao_verification_bound_rows"
  "$runner_owned_execution_declared_rows"
  "$live_network_execution_declared_rows"
  "$external_dataset_live_fetch_declared_rows"
  "$evaluator_invoked_by_runner_declared_rows"
  "$replay_disabled_declared_rows"
  "$audit_log_complete_declared_rows"
  "$third_party_audit_review_declared_rows"
  "$fixture_free_rows"
  "$timestamp_rows"
  "$external_benchmark_runner_owned_live_execution_audit_ready"
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
  printf "upstream-public-nonfixture-verification,%s,ready=%d action=%s\n" \
    "$([[ "$upstream_public_nonfixture_ready" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_public_nonfixture_ready" \
    "$upstream_action"
  printf "runner-owned-live-execution-audit-coverage,%s,coverage=%d/%d rows=%d duplicates=%d\n" \
    "$([[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$audit_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$audit_rows" \
    "$duplicate_family_rows"
  printf "runner-owned-live-execution-audit-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$([[ "$nonlocal_live_execution_audit_uri_fields" -eq "$expected_live_execution_audit_uri_fields" && "$live_execution_audit_hash_attested_fields" -eq "$expected_live_execution_audit_hash_fields" && "$local_live_execution_audit_uri_fields" -eq 0 && "$nonplaceholder_live_execution_audit_uri_fields" -eq "$expected_live_execution_audit_uri_fields" ]] && echo pass || echo blocked)" \
    "$nonlocal_live_execution_audit_uri_fields" \
    "$expected_live_execution_audit_uri_fields" \
    "$live_execution_audit_hash_attested_fields" \
    "$expected_live_execution_audit_hash_fields" \
    "$local_live_execution_audit_uri_fields" \
    "$nonplaceholder_live_execution_audit_uri_fields" \
    "$expected_live_execution_audit_uri_fields"
  printf "runner-owned-live-execution-audit-query-volume,%s,pass_rows=%d/%d total_executed_query_rows=%d min=%d\n" \
    "$([[ "$min_executed_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$min_executed_query_rows_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$total_executed_query_rows" \
    "$MIN_EXECUTED_QUERY_ROWS_PER_FAMILY"
  printf "runner-owned-live-execution-audit-metric-thresholds,%s,pass_rows=%d/%d\n" \
    "$([[ "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_threshold_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "runner-owned-live-execution-audit-bindings,%s,v08ao=%d expected=%d\n" \
    "$([[ "$v08ao_verification_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$v08ao_verification_bound_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "runner-execution-declarations,%s,runner=%d evaluator=%d expected=%d\n" \
    "$([[ "$runner_owned_execution_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$evaluator_invoked_by_runner_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$runner_owned_execution_declared_rows" \
    "$evaluator_invoked_by_runner_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "live-execution-declarations,%s,network=%d dataset=%d replay_disabled=%d expected=%d\n" \
    "$([[ "$live_network_execution_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$external_dataset_live_fetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$replay_disabled_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$live_network_execution_declared_rows" \
    "$external_dataset_live_fetch_declared_rows" \
    "$replay_disabled_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "audit-declarations,%s,audit_log=%d third_party=%d expected=%d\n" \
    "$([[ "$audit_log_complete_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$third_party_audit_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$audit_log_complete_declared_rows" \
    "$third_party_audit_review_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "fixture-declarations,%s,fixture_free=%d timestamp=%d expected=%d\n" \
    "$([[ "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "external-benchmark-runner-owned-live-execution-audit,%s,ready=%d action=%s\n" \
    "$([[ "$external_benchmark_runner_owned_live_execution_audit_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_runner_owned_live_execution_audit_ready" \
    "$action"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d\n" \
    blocked \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "audit: $AUDIT_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
