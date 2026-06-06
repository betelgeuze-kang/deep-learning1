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

PREFIX="v08_external_benchmark_public_nonfixture_verification"
AN_PREFIX="v08_external_benchmark_live_replay_final_review"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_public_nonfixture_verification_smoke"
  AN_PREFIX="v08_external_benchmark_live_replay_final_review_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_public_nonfixture_verification_full"
  AN_PREFIX="v08_external_benchmark_live_replay_final_review_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_replay_final_review.sh" "${RUN_ARGS[@]}" >/dev/null

AN_SUMMARY_CSV="$RESULTS_DIR/${AN_PREFIX}_summary.csv"
VERIFICATION_CSV="$RESULTS_DIR/${PREFIX}_verification.csv"
VERIFICATION_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
PUBLIC_VERIFICATION_URI_FIELDS_PER_ROW=10
PUBLIC_VERIFICATION_HASH_FIELDS_PER_ROW=10
MIN_VERIFIED_QUERY_ROWS_PER_FAMILY=7

write_verification_header() {
  echo "benchmark_family,external_run_id,live_replay_id,final_review_id,public_verification_id,direct_run_id,v08an_review_bound,public_nonfixture_verification_declared,public_artifact_registry_declared,direct_runner_owned_run_declared,direct_external_dataset_declared,direct_evaluator_execution_declared,live_network_fetch_declared,third_party_reviewer_declared,fixture_or_synthetic_declared,query_rows_verified,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,public_verification_report_uri,public_verification_report_hash,public_run_manifest_uri,public_run_manifest_hash,public_dataset_snapshot_uri,public_dataset_snapshot_hash,public_evaluator_output_uri,public_evaluator_output_hash,public_metric_report_uri,public_metric_report_hash,direct_run_log_uri,direct_run_log_hash,direct_network_receipt_uri,direct_network_receipt_hash,direct_runner_identity_uri,direct_runner_identity_hash,public_registry_entry_uri,public_registry_entry_hash,reviewer_attestation_uri,reviewer_attestation_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ao column: " column > "/dev/stderr"
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
        print "missing v08-ao summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_PUBLIC_NONFIXTURE_VERIFICATION_CSV:-}" ]]; then
  VERIFICATION_CSV="$V08_EXTERNAL_BENCHMARK_PUBLIC_NONFIXTURE_VERIFICATION_CSV"
  VERIFICATION_SOURCE="provided-csv"
  if [[ ! -s "$VERIFICATION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_PUBLIC_NONFIXTURE_VERIFICATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_verification_header >"$VERIFICATION_CSV"
fi

upstream_live_replay_ready="$(csv_value "$AN_SUMMARY_CSV" "external_benchmark_live_replay_final_review_ready")"
upstream_real_external="$(csv_value "$AN_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AN_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AN_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AN_SUMMARY_CSV" "active_jump_rate")"

verification_rows=0
expected_family_rows=0
duplicate_family_rows=0
required_public_verification_uri_fields=0
nonlocal_public_verification_uri_fields=0
local_public_verification_uri_fields=0
nonplaceholder_public_verification_uri_fields=0
required_public_verification_hash_fields=0
public_verification_hash_attested_fields=0
total_verified_query_rows=0
min_verified_query_rows_pass_rows=0
metric_threshold_pass_rows=0
v08an_review_bound_rows=0
public_nonfixture_verification_declared_rows=0
public_artifact_registry_declared_rows=0
direct_runner_owned_run_declared_rows=0
direct_external_dataset_declared_rows=0
direct_evaluator_execution_declared_rows=0
live_network_fetch_declared_rows=0
third_party_reviewer_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
verification_routing="0.000000"
verification_jump="0.000000"
declare -A verification_family_seen=()

VERIFICATION_TSV="$TMP_DIR/public_nonfixture_verification.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family external_run_id live_replay_id final_review_id public_verification_id direct_run_id v08an_review_bound public_nonfixture_verification_declared public_artifact_registry_declared direct_runner_owned_run_declared direct_external_dataset_declared direct_evaluator_execution_declared live_network_fetch_declared third_party_reviewer_declared fixture_or_synthetic_declared query_rows_verified span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate public_verification_report_uri public_verification_report_hash public_run_manifest_uri public_run_manifest_hash public_dataset_snapshot_uri public_dataset_snapshot_hash public_evaluator_output_uri public_evaluator_output_hash public_metric_report_uri public_metric_report_hash direct_run_log_uri direct_run_log_hash direct_network_receipt_uri direct_network_receipt_hash direct_runner_identity_uri direct_runner_identity_hash public_registry_entry_uri public_registry_entry_hash reviewer_attestation_uri reviewer_attestation_hash observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ao public non-fixture verification column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ao public non-fixture verification row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$VERIFICATION_CSV" >"$VERIFICATION_TSV"

while IFS=$'\t' read -r benchmark_family external_run_id live_replay_id final_review_id public_verification_id direct_run_id v08an_review_bound public_nonfixture_verification_declared public_artifact_registry_declared direct_runner_owned_run_declared direct_external_dataset_declared direct_evaluator_execution_declared live_network_fetch_declared third_party_reviewer_declared fixture_or_synthetic_declared query_rows_verified span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate public_verification_report_uri public_verification_report_hash public_run_manifest_uri public_run_manifest_hash public_dataset_snapshot_uri public_dataset_snapshot_hash public_evaluator_output_uri public_evaluator_output_hash public_metric_report_uri public_metric_report_hash direct_run_log_uri direct_run_log_hash direct_network_receipt_uri direct_network_receipt_hash direct_runner_identity_uri direct_runner_identity_hash public_registry_entry_uri public_registry_entry_hash reviewer_attestation_uri reviewer_attestation_hash observed_at_utc routing_trigger_rate active_jump_rate; do
  ((verification_rows += 1))
  ((total_verified_query_rows += query_rows_verified))

  if [[ -n "${verification_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  verification_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi

  for pair in \
    "$public_verification_report_uri|$public_verification_report_hash" \
    "$public_run_manifest_uri|$public_run_manifest_hash" \
    "$public_dataset_snapshot_uri|$public_dataset_snapshot_hash" \
    "$public_evaluator_output_uri|$public_evaluator_output_hash" \
    "$public_metric_report_uri|$public_metric_report_hash" \
    "$direct_run_log_uri|$direct_run_log_hash" \
    "$direct_network_receipt_uri|$direct_network_receipt_hash" \
    "$direct_runner_identity_uri|$direct_runner_identity_hash" \
    "$public_registry_entry_uri|$public_registry_entry_hash" \
    "$reviewer_attestation_uri|$reviewer_attestation_hash"; do
    ((required_public_verification_uri_fields += 1))
    ((required_public_verification_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((public_verification_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_public_verification_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_public_verification_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_public_verification_uri_fields += 1))
    fi
  done

  if [[ "$query_rows_verified" -ge "$MIN_VERIFIED_QUERY_ROWS_PER_FAMILY" ]]; then
    ((min_verified_query_rows_pass_rows += 1))
  fi
  if float_ge "$span_exact" "0.800000" &&
     float_ge "$chunk_exact" "0.750000" &&
     float_ge "$missing_abstain" "0.850000" &&
     float_le "$near_miss_false_positive" "0.050000" &&
     float_le "$wrong_answer_rate" "0.080000"; then
    ((metric_threshold_pass_rows += 1))
  fi

  [[ "$v08an_review_bound" == "1" ]] && ((v08an_review_bound_rows += 1))
  [[ "$public_nonfixture_verification_declared" == "1" ]] && ((public_nonfixture_verification_declared_rows += 1))
  [[ "$public_artifact_registry_declared" == "1" ]] && ((public_artifact_registry_declared_rows += 1))
  [[ "$direct_runner_owned_run_declared" == "1" ]] && ((direct_runner_owned_run_declared_rows += 1))
  [[ "$direct_external_dataset_declared" == "1" ]] && ((direct_external_dataset_declared_rows += 1))
  [[ "$direct_evaluator_execution_declared" == "1" ]] && ((direct_evaluator_execution_declared_rows += 1))
  [[ "$live_network_fetch_declared" == "1" ]] && ((live_network_fetch_declared_rows += 1))
  [[ "$third_party_reviewer_declared" == "1" ]] && ((third_party_reviewer_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  verification_routing="$(awk -v a="$verification_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  verification_jump="$(awk -v a="$verification_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$VERIFICATION_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${verification_family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

expected_public_verification_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * PUBLIC_VERIFICATION_URI_FIELDS_PER_ROW))
expected_public_verification_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * PUBLIC_VERIFICATION_HASH_FIELDS_PER_ROW))
external_benchmark_public_nonfixture_verification_ready=0
if [[ "$upstream_live_replay_ready" == "1" &&
      "$verification_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$required_public_verification_uri_fields" -eq "$expected_public_verification_uri_fields" &&
      "$nonlocal_public_verification_uri_fields" -eq "$expected_public_verification_uri_fields" &&
      "$local_public_verification_uri_fields" -eq 0 &&
      "$nonplaceholder_public_verification_uri_fields" -eq "$expected_public_verification_uri_fields" &&
      "$required_public_verification_hash_fields" -eq "$expected_public_verification_hash_fields" &&
      "$public_verification_hash_attested_fields" -eq "$expected_public_verification_hash_fields" &&
      "$min_verified_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$v08an_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_nonfixture_verification_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_artifact_registry_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$direct_runner_owned_run_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$direct_external_dataset_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$direct_evaluator_execution_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_network_fetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$third_party_reviewer_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$verification_routing" == "0.000000" &&
      "$verification_jump" == "0.000000" ]]; then
  external_benchmark_public_nonfixture_verification_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$verification_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$verification_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-live-replay-final-review-not-ready"
if [[ "$upstream_live_replay_ready" != "1" ]]; then
  action="external-benchmark-live-replay-final-review-not-ready"
elif [[ "$verification_rows" -eq 0 ]]; then
  action="external-benchmark-public-nonfixture-verification-missing"
elif [[ "$verification_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-public-nonfixture-verification-coverage-incomplete"
elif [[ "$required_public_verification_hash_fields" -ne "$expected_public_verification_hash_fields" ||
        "$public_verification_hash_attested_fields" -ne "$expected_public_verification_hash_fields" ]]; then
  action="external-benchmark-public-nonfixture-verification-hash-attestation-missing"
elif [[ "$required_public_verification_uri_fields" -ne "$expected_public_verification_uri_fields" ||
        "$nonlocal_public_verification_uri_fields" -ne "$expected_public_verification_uri_fields" ||
        "$local_public_verification_uri_fields" -ne 0 ]]; then
  action="external-benchmark-public-nonfixture-verification-local-artifact-uri"
elif [[ "$nonplaceholder_public_verification_uri_fields" -ne "$expected_public_verification_uri_fields" ]]; then
  action="external-benchmark-public-nonfixture-verification-placeholder-artifact-uri"
elif [[ "$min_verified_query_rows_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-public-nonfixture-verification-query-volume-insufficient"
elif [[ "$metric_threshold_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-public-nonfixture-verification-quality-threshold-missing"
elif [[ "$v08an_review_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-public-nonfixture-verification-binding-missing"
elif [[ "$public_nonfixture_verification_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$public_artifact_registry_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$third_party_reviewer_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-public-nonfixture-verification-public-declaration-missing"
elif [[ "$direct_runner_owned_run_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$direct_external_dataset_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$direct_evaluator_execution_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_network_fetch_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-public-nonfixture-verification-direct-run-declaration-missing"
elif [[ "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-public-nonfixture-verification-fixture-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-public-nonfixture-verification-jump-guardrail-violated"
elif [[ "$external_benchmark_public_nonfixture_verification_ready" == "1" ]]; then
  action="public-nonfixture-verification-ready-await-runner-owned-live-execution-audit"
fi

summary_header=(
  benchmark_scope
  verification_source
  upstream_live_replay_final_review_ready
  upstream_real_external
  upstream_action
  verification_rows
  expected_family_rows
  duplicate_family_rows
  family_coverage
  expected_external_families
  required_public_verification_uri_fields
  nonlocal_public_verification_uri_fields
  local_public_verification_uri_fields
  nonplaceholder_public_verification_uri_fields
  required_public_verification_hash_fields
  public_verification_hash_attested_fields
  total_verified_query_rows
  min_verified_query_rows_pass_rows
  metric_threshold_pass_rows
  v08an_review_bound_rows
  public_nonfixture_verification_declared_rows
  public_artifact_registry_declared_rows
  direct_runner_owned_run_declared_rows
  direct_external_dataset_declared_rows
  direct_evaluator_execution_declared_rows
  live_network_fetch_declared_rows
  third_party_reviewer_declared_rows
  fixture_free_rows
  timestamp_rows
  external_benchmark_public_nonfixture_verification_ready
  real_external_benchmark_verified
  action
  routing_trigger_rate
  active_jump_rate
)
summary_values=(
  route-memory-v08ao
  "$VERIFICATION_SOURCE"
  "$upstream_live_replay_ready"
  "$upstream_real_external"
  "$upstream_action"
  "$verification_rows"
  "$expected_family_rows"
  "$duplicate_family_rows"
  "$family_coverage"
  "$EXPECTED_EXTERNAL_FAMILIES"
  "$required_public_verification_uri_fields"
  "$nonlocal_public_verification_uri_fields"
  "$local_public_verification_uri_fields"
  "$nonplaceholder_public_verification_uri_fields"
  "$required_public_verification_hash_fields"
  "$public_verification_hash_attested_fields"
  "$total_verified_query_rows"
  "$min_verified_query_rows_pass_rows"
  "$metric_threshold_pass_rows"
  "$v08an_review_bound_rows"
  "$public_nonfixture_verification_declared_rows"
  "$public_artifact_registry_declared_rows"
  "$direct_runner_owned_run_declared_rows"
  "$direct_external_dataset_declared_rows"
  "$direct_evaluator_execution_declared_rows"
  "$live_network_fetch_declared_rows"
  "$third_party_reviewer_declared_rows"
  "$fixture_free_rows"
  "$timestamp_rows"
  "$external_benchmark_public_nonfixture_verification_ready"
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
  printf "upstream-live-replay-final-review,%s,ready=%d action=%s\n" \
    "$([[ "$upstream_live_replay_ready" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_live_replay_ready" \
    "$upstream_action"
  printf "public-nonfixture-verification-coverage,%s,coverage=%d/%d rows=%d duplicates=%d\n" \
    "$([[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$verification_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$verification_rows" \
    "$duplicate_family_rows"
  printf "public-nonfixture-verification-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$([[ "$nonlocal_public_verification_uri_fields" -eq "$expected_public_verification_uri_fields" && "$public_verification_hash_attested_fields" -eq "$expected_public_verification_hash_fields" && "$local_public_verification_uri_fields" -eq 0 && "$nonplaceholder_public_verification_uri_fields" -eq "$expected_public_verification_uri_fields" ]] && echo pass || echo blocked)" \
    "$nonlocal_public_verification_uri_fields" \
    "$expected_public_verification_uri_fields" \
    "$public_verification_hash_attested_fields" \
    "$expected_public_verification_hash_fields" \
    "$local_public_verification_uri_fields" \
    "$nonplaceholder_public_verification_uri_fields" \
    "$expected_public_verification_uri_fields"
  printf "public-nonfixture-verification-query-volume,%s,pass_rows=%d/%d total_verified_query_rows=%d min=%d\n" \
    "$([[ "$min_verified_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$min_verified_query_rows_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$total_verified_query_rows" \
    "$MIN_VERIFIED_QUERY_ROWS_PER_FAMILY"
  printf "public-nonfixture-verification-metric-thresholds,%s,pass_rows=%d/%d\n" \
    "$([[ "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_threshold_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "public-nonfixture-verification-bindings,%s,v08an=%d expected=%d\n" \
    "$([[ "$v08an_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$v08an_review_bound_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "public-nonfixture-declarations,%s,public=%d registry=%d reviewer=%d expected=%d\n" \
    "$([[ "$public_nonfixture_verification_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$public_artifact_registry_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$third_party_reviewer_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$public_nonfixture_verification_declared_rows" \
    "$public_artifact_registry_declared_rows" \
    "$third_party_reviewer_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "direct-run-declarations,%s,runner=%d dataset=%d evaluator=%d network=%d expected=%d\n" \
    "$([[ "$direct_runner_owned_run_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$direct_external_dataset_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$direct_evaluator_execution_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_network_fetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$direct_runner_owned_run_declared_rows" \
    "$direct_external_dataset_declared_rows" \
    "$direct_evaluator_execution_declared_rows" \
    "$live_network_fetch_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "fixture-declarations,%s,fixture_free=%d timestamp=%d expected=%d\n" \
    "$([[ "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "external-benchmark-public-nonfixture-verification,%s,ready=%d action=%s\n" \
    "$([[ "$external_benchmark_public_nonfixture_verification_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_public_nonfixture_verification_ready" \
    "$action"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d\n" \
    blocked \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "verification: $VERIFICATION_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
