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

PREFIX="v08_external_benchmark_official_result_reconciliation"
AS_PREFIX="v08_external_benchmark_live_package_artifact_fetch_authority"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_official_result_reconciliation_smoke"
  AS_PREFIX="v08_external_benchmark_live_package_artifact_fetch_authority_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_official_result_reconciliation_full"
  AS_PREFIX="v08_external_benchmark_live_package_artifact_fetch_authority_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_package_artifact_fetch_authority.sh" "${RUN_ARGS[@]}" >/dev/null

AS_SUMMARY_CSV="$RESULTS_DIR/${AS_PREFIX}_summary.csv"
FETCH_CSV="${V08_EXTERNAL_BENCHMARK_LIVE_PACKAGE_ARTIFACT_FETCH_AUTHORITY_CSV:-$RESULTS_DIR/${AS_PREFIX}_fetch_authority.csv}"
RECONCILIATION_CSV="$RESULTS_DIR/${PREFIX}_reconciliation.csv"
RECONCILIATION_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_ARTIFACT_TYPES=(
  official_leaderboard_entry
  metric_report
  submission_receipt
  evaluator_config
  raw_prediction_output
  package_registry_entry
)
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
EXPECTED_RECONCILIATION_ROWS="$EXPECTED_EXTERNAL_FAMILIES"
RECONCILIATION_URI_FIELDS_PER_ROW=7
RECONCILIATION_HASH_FIELDS_PER_ROW=7

write_reconciliation_header() {
  echo "benchmark_family,real_run_package_id,official_result_reconciliation_id,v08as_live_fetch_authority_bound,official_leaderboard_entry_bound,metric_report_bound,submission_receipt_bound,evaluator_config_bound,raw_prediction_output_bound,package_registry_entry_bound,official_result_uri,official_result_hash,official_leaderboard_uri,official_leaderboard_hash,reconciled_metric_report_uri,reconciled_metric_report_hash,reconciled_submission_receipt_uri,reconciled_submission_receipt_hash,reconciled_evaluator_config_uri,reconciled_evaluator_config_hash,reconciled_raw_prediction_output_uri,reconciled_raw_prediction_output_hash,reconciled_package_registry_uri,reconciled_package_registry_hash,metric_name,reported_metric_value,official_metric_value,metric_delta,metric_tolerance,query_count,official_query_count,query_count_match_declared,evaluator_identity_match_declared,result_digest_match_declared,official_source_observed_declared,public_leaderboard_observed_declared,runner_owned_reconciliation_declared,fixture_or_replay_declared,observed_at_utc,routing_trigger_rate,active_jump_rate"
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

is_number() {
  local value="$1"
  [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

is_integer() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]]
}

is_expected_family() {
  local family="$1"
  local expected

  for expected in "${EXPECTED_FAMILIES[@]}"; do
    [[ "$family" == "$expected" ]] && return 0
  done
  return 1
}

is_expected_artifact_type() {
  local artifact_type="$1"
  local expected

  for expected in "${EXPECTED_ARTIFACT_TYPES[@]}"; do
    [[ "$artifact_type" == "$expected" ]] && return 0
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
        print "missing v08-at column: " column > "/dev/stderr"
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
        print "missing v08-at summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_OFFICIAL_RESULT_RECONCILIATION_CSV:-}" ]]; then
  RECONCILIATION_CSV="$V08_EXTERNAL_BENCHMARK_OFFICIAL_RESULT_RECONCILIATION_CSV"
  RECONCILIATION_SOURCE="provided-csv"
  if [[ ! -s "$RECONCILIATION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_OFFICIAL_RESULT_RECONCILIATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_reconciliation_header >"$RECONCILIATION_CSV"
fi

upstream_live_package_artifact_fetch_authority_ready="$(csv_value "$AS_SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready")"
upstream_real_external="$(csv_value "$AS_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AS_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AS_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AS_SUMMARY_CSV" "active_jump_rate")"

declare -A expected_fetch_package_id=()
declare -A expected_fetch_artifact_uri=()
declare -A expected_fetch_artifact_hash=()
fetch_artifact_rows_seen=0
if [[ -s "$FETCH_CSV" ]]; then
  FETCH_TSV="$TMP_DIR/live_package_fetch_artifacts.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family real_run_package_id artifact_type fetched_artifact_uri fetched_artifact_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-at upstream fetch column: " required[i], 13)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-at upstream fetch row has wrong column count", 14)
      printf "%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["artifact_type"],
        $idx["real_run_package_id"],
        $idx["fetched_artifact_uri"],
        $idx["fetched_artifact_hash"]
    }
  ' "$FETCH_CSV" >"$FETCH_TSV"

  while IFS=$'\t' read -r benchmark_family artifact_type real_run_package_id fetched_artifact_uri fetched_artifact_hash; do
    if is_expected_artifact_type "$artifact_type"; then
      key="${benchmark_family}|${artifact_type}"
      expected_fetch_package_id["$key"]="$real_run_package_id"
      expected_fetch_artifact_uri["$key"]="$fetched_artifact_uri"
      expected_fetch_artifact_hash["$key"]="$fetched_artifact_hash"
      ((fetch_artifact_rows_seen += 1))
    fi
  done <"$FETCH_TSV"
fi

reconciliation_rows=0
expected_family_rows=0
duplicate_family_rows=0
required_reconciliation_uri_fields=0
nonlocal_reconciliation_uri_fields=0
local_reconciliation_uri_fields=0
nonplaceholder_reconciliation_uri_fields=0
required_reconciliation_hash_fields=0
reconciliation_hash_attested_fields=0
v08as_live_fetch_authority_bound_rows=0
package_identity_match_rows=0
artifact_binding_declared_rows=0
fetch_artifact_identity_match_rows=0
metric_delta_within_tolerance_rows=0
query_count_exact_match_rows=0
query_count_match_declared_rows=0
evaluator_identity_match_declared_rows=0
result_digest_match_declared_rows=0
official_source_observed_declared_rows=0
public_leaderboard_observed_declared_rows=0
runner_owned_reconciliation_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
reconciliation_routing="0.000000"
reconciliation_jump="0.000000"
declare -A family_seen=()

RECONCILIATION_TSV="$TMP_DIR/official_result_reconciliation.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family real_run_package_id official_result_reconciliation_id v08as_live_fetch_authority_bound official_leaderboard_entry_bound metric_report_bound submission_receipt_bound evaluator_config_bound raw_prediction_output_bound package_registry_entry_bound official_result_uri official_result_hash official_leaderboard_uri official_leaderboard_hash reconciled_metric_report_uri reconciled_metric_report_hash reconciled_submission_receipt_uri reconciled_submission_receipt_hash reconciled_evaluator_config_uri reconciled_evaluator_config_hash reconciled_raw_prediction_output_uri reconciled_raw_prediction_output_hash reconciled_package_registry_uri reconciled_package_registry_hash metric_name reported_metric_value official_metric_value metric_delta metric_tolerance query_count official_query_count query_count_match_declared evaluator_identity_match_declared result_digest_match_declared official_source_observed_declared public_leaderboard_observed_declared runner_owned_reconciliation_declared fixture_or_replay_declared observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-at reconciliation column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-at reconciliation row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$RECONCILIATION_CSV" >"$RECONCILIATION_TSV"

while IFS=$'\t' read -r benchmark_family real_run_package_id official_result_reconciliation_id v08as_live_fetch_authority_bound official_leaderboard_entry_bound metric_report_bound submission_receipt_bound evaluator_config_bound raw_prediction_output_bound package_registry_entry_bound official_result_uri official_result_hash official_leaderboard_uri official_leaderboard_hash reconciled_metric_report_uri reconciled_metric_report_hash reconciled_submission_receipt_uri reconciled_submission_receipt_hash reconciled_evaluator_config_uri reconciled_evaluator_config_hash reconciled_raw_prediction_output_uri reconciled_raw_prediction_output_hash reconciled_package_registry_uri reconciled_package_registry_hash metric_name reported_metric_value official_metric_value metric_delta metric_tolerance query_count official_query_count query_count_match_declared evaluator_identity_match_declared result_digest_match_declared official_source_observed_declared public_leaderboard_observed_declared runner_owned_reconciliation_declared fixture_or_replay_declared observed_at_utc routing_trigger_rate active_jump_rate; do
  ((reconciliation_rows += 1))

  if [[ -n "${family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  family_seen["$benchmark_family"]=1
  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi

  for pair in \
    "$official_result_uri|$official_result_hash" \
    "$official_leaderboard_uri|$official_leaderboard_hash" \
    "$reconciled_metric_report_uri|$reconciled_metric_report_hash" \
    "$reconciled_submission_receipt_uri|$reconciled_submission_receipt_hash" \
    "$reconciled_evaluator_config_uri|$reconciled_evaluator_config_hash" \
    "$reconciled_raw_prediction_output_uri|$reconciled_raw_prediction_output_hash" \
    "$reconciled_package_registry_uri|$reconciled_package_registry_hash"; do
    ((required_reconciliation_uri_fields += 1))
    ((required_reconciliation_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((reconciliation_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_reconciliation_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_reconciliation_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_reconciliation_uri_fields += 1))
    fi
  done

  [[ "$v08as_live_fetch_authority_bound" == "1" ]] && ((v08as_live_fetch_authority_bound_rows += 1))

  artifact_binding_complete=1
  [[ "$official_leaderboard_entry_bound" == "1" ]] || artifact_binding_complete=0
  [[ "$metric_report_bound" == "1" ]] || artifact_binding_complete=0
  [[ "$submission_receipt_bound" == "1" ]] || artifact_binding_complete=0
  [[ "$evaluator_config_bound" == "1" ]] || artifact_binding_complete=0
  [[ "$raw_prediction_output_bound" == "1" ]] || artifact_binding_complete=0
  [[ "$package_registry_entry_bound" == "1" ]] || artifact_binding_complete=0
  [[ "$artifact_binding_complete" == "1" ]] && ((artifact_binding_declared_rows += 1))

  package_identity_complete=1
  artifact_identity_complete=1
  key="${benchmark_family}|official_leaderboard_entry"
  [[ "${expected_fetch_package_id[$key]:-}" == "$real_run_package_id" ]] || package_identity_complete=0
  [[ "${expected_fetch_artifact_uri[$key]:-}" == "$official_leaderboard_uri" &&
     "${expected_fetch_artifact_hash[$key]:-}" == "$official_leaderboard_hash" ]] || artifact_identity_complete=0
  key="${benchmark_family}|metric_report"
  [[ "${expected_fetch_package_id[$key]:-}" == "$real_run_package_id" ]] || package_identity_complete=0
  [[ "${expected_fetch_artifact_uri[$key]:-}" == "$reconciled_metric_report_uri" &&
     "${expected_fetch_artifact_hash[$key]:-}" == "$reconciled_metric_report_hash" ]] || artifact_identity_complete=0
  key="${benchmark_family}|submission_receipt"
  [[ "${expected_fetch_package_id[$key]:-}" == "$real_run_package_id" ]] || package_identity_complete=0
  [[ "${expected_fetch_artifact_uri[$key]:-}" == "$reconciled_submission_receipt_uri" &&
     "${expected_fetch_artifact_hash[$key]:-}" == "$reconciled_submission_receipt_hash" ]] || artifact_identity_complete=0
  key="${benchmark_family}|evaluator_config"
  [[ "${expected_fetch_package_id[$key]:-}" == "$real_run_package_id" ]] || package_identity_complete=0
  [[ "${expected_fetch_artifact_uri[$key]:-}" == "$reconciled_evaluator_config_uri" &&
     "${expected_fetch_artifact_hash[$key]:-}" == "$reconciled_evaluator_config_hash" ]] || artifact_identity_complete=0
  key="${benchmark_family}|raw_prediction_output"
  [[ "${expected_fetch_package_id[$key]:-}" == "$real_run_package_id" ]] || package_identity_complete=0
  [[ "${expected_fetch_artifact_uri[$key]:-}" == "$reconciled_raw_prediction_output_uri" &&
     "${expected_fetch_artifact_hash[$key]:-}" == "$reconciled_raw_prediction_output_hash" ]] || artifact_identity_complete=0
  key="${benchmark_family}|package_registry_entry"
  [[ "${expected_fetch_package_id[$key]:-}" == "$real_run_package_id" ]] || package_identity_complete=0
  [[ "${expected_fetch_artifact_uri[$key]:-}" == "$reconciled_package_registry_uri" &&
     "${expected_fetch_artifact_hash[$key]:-}" == "$reconciled_package_registry_hash" ]] || artifact_identity_complete=0
  [[ "$package_identity_complete" == "1" ]] && ((package_identity_match_rows += 1))
  [[ "$artifact_identity_complete" == "1" ]] && ((fetch_artifact_identity_match_rows += 1))

  if is_number "$reported_metric_value" &&
     is_number "$official_metric_value" &&
     is_number "$metric_delta" &&
     is_number "$metric_tolerance"; then
    metric_within="$(
      awk -v reported="$reported_metric_value" \
          -v official="$official_metric_value" \
          -v delta="$metric_delta" \
          -v tolerance="$metric_tolerance" '
        BEGIN {
          diff = reported - official
          if (diff < 0) diff = -diff
          if (diff <= tolerance + 0.000000001 && delta <= tolerance + 0.000000001) {
            print 1
          } else {
            print 0
          }
        }
      '
    )"
    [[ "$metric_within" == "1" ]] && ((metric_delta_within_tolerance_rows += 1))
  fi

  if is_integer "$query_count" &&
     is_integer "$official_query_count" &&
     [[ "$query_count" == "$official_query_count" ]]; then
    ((query_count_exact_match_rows += 1))
  fi
  [[ "$query_count_match_declared" == "1" ]] && ((query_count_match_declared_rows += 1))
  [[ "$evaluator_identity_match_declared" == "1" ]] && ((evaluator_identity_match_declared_rows += 1))
  [[ "$result_digest_match_declared" == "1" ]] && ((result_digest_match_declared_rows += 1))
  [[ "$official_source_observed_declared" == "1" ]] && ((official_source_observed_declared_rows += 1))
  [[ "$public_leaderboard_observed_declared" == "1" ]] && ((public_leaderboard_observed_declared_rows += 1))
  [[ "$runner_owned_reconciliation_declared" == "1" ]] && ((runner_owned_reconciliation_declared_rows += 1))
  [[ "$fixture_or_replay_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  reconciliation_routing="$(awk -v a="$reconciliation_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  reconciliation_jump="$(awk -v a="$reconciliation_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$RECONCILIATION_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

expected_reconciliation_uri_fields=$((EXPECTED_RECONCILIATION_ROWS * RECONCILIATION_URI_FIELDS_PER_ROW))
expected_reconciliation_hash_fields=$((EXPECTED_RECONCILIATION_ROWS * RECONCILIATION_HASH_FIELDS_PER_ROW))
external_benchmark_official_result_reconciliation_ready=0
if [[ "$upstream_live_package_artifact_fetch_authority_ready" == "1" &&
      "$reconciliation_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$expected_family_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$duplicate_family_rows" -eq 0 &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_reconciliation_uri_fields" -eq "$expected_reconciliation_uri_fields" &&
      "$nonlocal_reconciliation_uri_fields" -eq "$expected_reconciliation_uri_fields" &&
      "$local_reconciliation_uri_fields" -eq 0 &&
      "$nonplaceholder_reconciliation_uri_fields" -eq "$expected_reconciliation_uri_fields" &&
      "$required_reconciliation_hash_fields" -eq "$expected_reconciliation_hash_fields" &&
      "$reconciliation_hash_attested_fields" -eq "$expected_reconciliation_hash_fields" &&
      "$v08as_live_fetch_authority_bound_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$package_identity_match_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$artifact_binding_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$fetch_artifact_identity_match_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$metric_delta_within_tolerance_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$query_count_exact_match_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$query_count_match_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$evaluator_identity_match_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$result_digest_match_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$official_source_observed_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$public_leaderboard_observed_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$runner_owned_reconciliation_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$fixture_free_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$timestamp_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
      "$reconciliation_routing" == "0.000000" &&
      "$reconciliation_jump" == "0.000000" ]]; then
  external_benchmark_official_result_reconciliation_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$reconciliation_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$reconciliation_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-live-package-artifact-fetch-authority-not-ready"
if [[ "$upstream_live_package_artifact_fetch_authority_ready" != "1" ]]; then
  action="external-benchmark-live-package-artifact-fetch-authority-not-ready"
elif [[ "$reconciliation_rows" -eq 0 ]]; then
  action="external-benchmark-official-result-reconciliation-missing"
elif [[ "$reconciliation_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ||
        "$expected_family_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ||
        "$duplicate_family_rows" -ne 0 ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-official-result-reconciliation-coverage-incomplete"
elif [[ "$required_reconciliation_hash_fields" -ne "$expected_reconciliation_hash_fields" ||
        "$reconciliation_hash_attested_fields" -ne "$expected_reconciliation_hash_fields" ]]; then
  action="external-benchmark-official-result-reconciliation-hash-attestation-missing"
elif [[ "$required_reconciliation_uri_fields" -ne "$expected_reconciliation_uri_fields" ||
        "$nonlocal_reconciliation_uri_fields" -ne "$expected_reconciliation_uri_fields" ||
        "$local_reconciliation_uri_fields" -ne 0 ]]; then
  action="external-benchmark-official-result-reconciliation-local-artifact-uri"
elif [[ "$nonplaceholder_reconciliation_uri_fields" -ne "$expected_reconciliation_uri_fields" ]]; then
  action="external-benchmark-official-result-reconciliation-placeholder-artifact-uri"
elif [[ "$v08as_live_fetch_authority_bound_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-v08as-binding-missing"
elif [[ "$package_identity_match_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-package-identity-mismatch"
elif [[ "$artifact_binding_declared_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-artifact-binding-missing"
elif [[ "$fetch_artifact_identity_match_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-artifact-identity-mismatch"
elif [[ "$metric_delta_within_tolerance_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-metric-mismatch"
elif [[ "$query_count_exact_match_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ||
        "$query_count_match_declared_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-query-count-mismatch"
elif [[ "$evaluator_identity_match_declared_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ||
        "$result_digest_match_declared_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-evaluator-or-digest-declaration-missing"
elif [[ "$official_source_observed_declared_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ||
        "$public_leaderboard_observed_declared_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-official-source-missing"
elif [[ "$runner_owned_reconciliation_declared_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-runner-declaration-missing"
elif [[ "$fixture_free_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ||
        "$timestamp_rows" -ne "$EXPECTED_RECONCILIATION_ROWS" ]]; then
  action="external-benchmark-official-result-reconciliation-fixture-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-official-result-reconciliation-jump-guardrail-violated"
elif [[ "$external_benchmark_official_result_reconciliation_ready" == "1" ]]; then
  action="official-result-reconciliation-ready-await-public-real-external-claim"
fi

summary_header=(
  benchmark_scope
  reconciliation_source
  upstream_live_package_artifact_fetch_authority_ready
  upstream_real_external
  upstream_action
  fetch_artifact_rows_seen
  reconciliation_rows
  expected_reconciliation_rows
  expected_family_rows
  duplicate_family_rows
  family_coverage
  expected_external_families
  required_reconciliation_uri_fields
  nonlocal_reconciliation_uri_fields
  local_reconciliation_uri_fields
  nonplaceholder_reconciliation_uri_fields
  required_reconciliation_hash_fields
  reconciliation_hash_attested_fields
  v08as_live_fetch_authority_bound_rows
  package_identity_match_rows
  artifact_binding_declared_rows
  fetch_artifact_identity_match_rows
  metric_delta_within_tolerance_rows
  query_count_exact_match_rows
  query_count_match_declared_rows
  evaluator_identity_match_declared_rows
  result_digest_match_declared_rows
  official_source_observed_declared_rows
  public_leaderboard_observed_declared_rows
  runner_owned_reconciliation_declared_rows
  fixture_free_rows
  timestamp_rows
  external_benchmark_official_result_reconciliation_ready
  real_external_benchmark_verified
  action
  routing_trigger_rate
  active_jump_rate
)
summary_values=(
  route-memory-v08at
  "$RECONCILIATION_SOURCE"
  "$upstream_live_package_artifact_fetch_authority_ready"
  "$upstream_real_external"
  "$upstream_action"
  "$fetch_artifact_rows_seen"
  "$reconciliation_rows"
  "$EXPECTED_RECONCILIATION_ROWS"
  "$expected_family_rows"
  "$duplicate_family_rows"
  "$family_coverage"
  "$EXPECTED_EXTERNAL_FAMILIES"
  "$required_reconciliation_uri_fields"
  "$nonlocal_reconciliation_uri_fields"
  "$local_reconciliation_uri_fields"
  "$nonplaceholder_reconciliation_uri_fields"
  "$required_reconciliation_hash_fields"
  "$reconciliation_hash_attested_fields"
  "$v08as_live_fetch_authority_bound_rows"
  "$package_identity_match_rows"
  "$artifact_binding_declared_rows"
  "$fetch_artifact_identity_match_rows"
  "$metric_delta_within_tolerance_rows"
  "$query_count_exact_match_rows"
  "$query_count_match_declared_rows"
  "$evaluator_identity_match_declared_rows"
  "$result_digest_match_declared_rows"
  "$official_source_observed_declared_rows"
  "$public_leaderboard_observed_declared_rows"
  "$runner_owned_reconciliation_declared_rows"
  "$fixture_free_rows"
  "$timestamp_rows"
  "$external_benchmark_official_result_reconciliation_ready"
  "$real_external_benchmark_verified"
  "$action"
  "$routing_trigger_rate"
  "$active_jump_rate"
)
{
  (IFS=,; printf '%s\n' "${summary_header[*]}")
  (IFS=,; printf '%s\n' "${summary_values[*]}")
} >"$SUMMARY_CSV"

coverage_status=blocked
[[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
   "$reconciliation_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$duplicate_family_rows" -eq 0 &&
   "$expected_family_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" ]] && coverage_status=pass
artifact_status=blocked
[[ "$nonlocal_reconciliation_uri_fields" -eq "$expected_reconciliation_uri_fields" &&
   "$reconciliation_hash_attested_fields" -eq "$expected_reconciliation_hash_fields" &&
   "$local_reconciliation_uri_fields" -eq 0 &&
   "$nonplaceholder_reconciliation_uri_fields" -eq "$expected_reconciliation_uri_fields" ]] && artifact_status=pass
binding_status=blocked
[[ "$v08as_live_fetch_authority_bound_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$package_identity_match_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$artifact_binding_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" ]] && binding_status=pass
identity_status=blocked
[[ "$fetch_artifact_identity_match_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" ]] && identity_status=pass
metric_status=blocked
[[ "$metric_delta_within_tolerance_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" ]] && metric_status=pass
query_status=blocked
[[ "$query_count_exact_match_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$query_count_match_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" ]] && query_status=pass
declaration_status=blocked
[[ "$evaluator_identity_match_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$result_digest_match_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$official_source_observed_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$public_leaderboard_observed_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$runner_owned_reconciliation_declared_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" ]] && declaration_status=pass
fixture_status=blocked
[[ "$fixture_free_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" &&
   "$timestamp_rows" -eq "$EXPECTED_RECONCILIATION_ROWS" ]] && fixture_status=pass
ready_status=blocked
[[ "$external_benchmark_official_result_reconciliation_ready" == "1" ]] && ready_status=pass
jump_status=blocked
[[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && jump_status=pass
upstream_status=blocked
[[ "$upstream_live_package_artifact_fetch_authority_ready" == "1" ]] && upstream_status=pass

{
  echo "gate,status,reason"
  printf "upstream-live-package-artifact-fetch-authority,%s,ready=%d action=%s\n" \
    "$upstream_status" \
    "$upstream_live_package_artifact_fetch_authority_ready" \
    "$upstream_action"
  printf "official-result-reconciliation-coverage,%s,coverage=%d/%d rows=%d/%d duplicates=%d\n" \
    "$coverage_status" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$reconciliation_rows" \
    "$EXPECTED_RECONCILIATION_ROWS" \
    "$duplicate_family_rows"
  printf "official-result-reconciliation-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$artifact_status" \
    "$nonlocal_reconciliation_uri_fields" \
    "$expected_reconciliation_uri_fields" \
    "$reconciliation_hash_attested_fields" \
    "$expected_reconciliation_hash_fields" \
    "$local_reconciliation_uri_fields" \
    "$nonplaceholder_reconciliation_uri_fields" \
    "$expected_reconciliation_uri_fields"
  printf "official-result-reconciliation-bindings,%s,v08as=%d package=%d artifact_bindings=%d expected=%d\n" \
    "$binding_status" \
    "$v08as_live_fetch_authority_bound_rows" \
    "$package_identity_match_rows" \
    "$artifact_binding_declared_rows" \
    "$EXPECTED_RECONCILIATION_ROWS"
  printf "official-result-reconciliation-artifact-identity,%s,identity=%d/%d fetch_artifacts=%d\n" \
    "$identity_status" \
    "$fetch_artifact_identity_match_rows" \
    "$EXPECTED_RECONCILIATION_ROWS" \
    "$fetch_artifact_rows_seen"
  printf "official-result-reconciliation-metrics,%s,metric_delta_within_tolerance=%d/%d\n" \
    "$metric_status" \
    "$metric_delta_within_tolerance_rows" \
    "$EXPECTED_RECONCILIATION_ROWS"
  printf "official-result-reconciliation-query-count,%s,exact=%d/%d declared=%d/%d\n" \
    "$query_status" \
    "$query_count_exact_match_rows" \
    "$EXPECTED_RECONCILIATION_ROWS" \
    "$query_count_match_declared_rows" \
    "$EXPECTED_RECONCILIATION_ROWS"
  printf "official-result-reconciliation-declarations,%s,evaluator=%d digest=%d official=%d leaderboard=%d runner=%d expected=%d\n" \
    "$declaration_status" \
    "$evaluator_identity_match_declared_rows" \
    "$result_digest_match_declared_rows" \
    "$official_source_observed_declared_rows" \
    "$public_leaderboard_observed_declared_rows" \
    "$runner_owned_reconciliation_declared_rows" \
    "$EXPECTED_RECONCILIATION_ROWS"
  printf "fixture-declarations,%s,fixture_free=%d timestamp=%d expected=%d\n" \
    "$fixture_status" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_RECONCILIATION_ROWS"
  printf "external-benchmark-official-result-reconciliation,%s,ready=%d action=%s\n" \
    "$ready_status" \
    "$external_benchmark_official_result_reconciliation_ready" \
    "$action"
  printf "real-external-benchmark,blocked,real_external_benchmark_verified=%d\n" \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$jump_status" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"
