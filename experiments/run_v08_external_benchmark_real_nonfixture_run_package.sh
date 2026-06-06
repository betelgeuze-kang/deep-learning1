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

PREFIX="v08_external_benchmark_real_nonfixture_run_package"
AQ_PREFIX="v08_external_benchmark_independent_live_rerun_confirmation"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_real_nonfixture_run_package_smoke"
  AQ_PREFIX="v08_external_benchmark_independent_live_rerun_confirmation_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_real_nonfixture_run_package_full"
  AQ_PREFIX="v08_external_benchmark_independent_live_rerun_confirmation_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_independent_live_rerun_confirmation.sh" "${RUN_ARGS[@]}" >/dev/null

AQ_SUMMARY_CSV="$RESULTS_DIR/${AQ_PREFIX}_summary.csv"
PACKAGE_CSV="$RESULTS_DIR/${PREFIX}_package.csv"
PACKAGE_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
RUN_PACKAGE_URI_FIELDS_PER_ROW=15
RUN_PACKAGE_HASH_FIELDS_PER_ROW=15
MIN_PACKAGE_QUERY_ROWS_PER_FAMILY=7

write_package_header() {
  echo "benchmark_family,independent_rerun_id,real_run_package_id,public_package_id,v08aq_confirmation_bound,run_package_nonfixture_declared,official_benchmark_declared,public_archive_declared,raw_query_set_declared,raw_prediction_output_declared,evaluator_container_declared,immutable_archive_declared,license_review_declared,pii_review_declared,third_party_reproducibility_declared,fixture_or_synthetic_declared,query_rows_packaged,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,metric_delta_abs,run_package_manifest_uri,run_package_manifest_hash,raw_query_set_uri,raw_query_set_hash,raw_prediction_output_uri,raw_prediction_output_hash,evaluator_container_digest_uri,evaluator_container_digest_hash,evaluator_config_uri,evaluator_config_hash,metric_report_uri,metric_report_hash,submission_receipt_uri,submission_receipt_hash,public_archive_uri,public_archive_hash,official_leaderboard_entry_uri,official_leaderboard_entry_hash,license_review_uri,license_review_hash,pii_review_uri,pii_review_hash,third_party_repro_report_uri,third_party_repro_report_hash,package_signature_uri,package_signature_hash,timestamp_authority_uri,timestamp_authority_hash,package_registry_entry_uri,package_registry_entry_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ar column: " column > "/dev/stderr"
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
        print "missing v08-ar summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_REAL_NONFIXTURE_RUN_PACKAGE_CSV:-}" ]]; then
  PACKAGE_CSV="$V08_EXTERNAL_BENCHMARK_REAL_NONFIXTURE_RUN_PACKAGE_CSV"
  PACKAGE_SOURCE="provided-csv"
  if [[ ! -s "$PACKAGE_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_REAL_NONFIXTURE_RUN_PACKAGE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_package_header >"$PACKAGE_CSV"
fi

upstream_independent_live_rerun_confirmation_ready="$(csv_value "$AQ_SUMMARY_CSV" "external_benchmark_independent_live_rerun_confirmation_ready")"
upstream_real_external="$(csv_value "$AQ_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AQ_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AQ_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AQ_SUMMARY_CSV" "active_jump_rate")"

package_rows=0
expected_family_rows=0
duplicate_family_rows=0
required_run_package_uri_fields=0
nonlocal_run_package_uri_fields=0
local_run_package_uri_fields=0
nonplaceholder_run_package_uri_fields=0
required_run_package_hash_fields=0
run_package_hash_attested_fields=0
total_packaged_query_rows=0
min_packaged_query_rows_pass_rows=0
metric_threshold_pass_rows=0
metric_delta_pass_rows=0
v08aq_confirmation_bound_rows=0
run_package_nonfixture_declared_rows=0
official_benchmark_declared_rows=0
public_archive_declared_rows=0
raw_query_set_declared_rows=0
raw_prediction_output_declared_rows=0
evaluator_container_declared_rows=0
immutable_archive_declared_rows=0
license_review_declared_rows=0
pii_review_declared_rows=0
third_party_reproducibility_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
package_routing="0.000000"
package_jump="0.000000"
declare -A package_family_seen=()

PACKAGE_TSV="$TMP_DIR/real_nonfixture_run_package.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family independent_rerun_id real_run_package_id public_package_id v08aq_confirmation_bound run_package_nonfixture_declared official_benchmark_declared public_archive_declared raw_query_set_declared raw_prediction_output_declared evaluator_container_declared immutable_archive_declared license_review_declared pii_review_declared third_party_reproducibility_declared fixture_or_synthetic_declared query_rows_packaged span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate metric_delta_abs run_package_manifest_uri run_package_manifest_hash raw_query_set_uri raw_query_set_hash raw_prediction_output_uri raw_prediction_output_hash evaluator_container_digest_uri evaluator_container_digest_hash evaluator_config_uri evaluator_config_hash metric_report_uri metric_report_hash submission_receipt_uri submission_receipt_hash public_archive_uri public_archive_hash official_leaderboard_entry_uri official_leaderboard_entry_hash license_review_uri license_review_hash pii_review_uri pii_review_hash third_party_repro_report_uri third_party_repro_report_hash package_signature_uri package_signature_hash timestamp_authority_uri timestamp_authority_hash package_registry_entry_uri package_registry_entry_hash observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ar real nonfixture run package column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ar real nonfixture run package row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$PACKAGE_CSV" >"$PACKAGE_TSV"

while IFS=$'\t' read -r benchmark_family independent_rerun_id real_run_package_id public_package_id v08aq_confirmation_bound run_package_nonfixture_declared official_benchmark_declared public_archive_declared raw_query_set_declared raw_prediction_output_declared evaluator_container_declared immutable_archive_declared license_review_declared pii_review_declared third_party_reproducibility_declared fixture_or_synthetic_declared query_rows_packaged span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate metric_delta_abs run_package_manifest_uri run_package_manifest_hash raw_query_set_uri raw_query_set_hash raw_prediction_output_uri raw_prediction_output_hash evaluator_container_digest_uri evaluator_container_digest_hash evaluator_config_uri evaluator_config_hash metric_report_uri metric_report_hash submission_receipt_uri submission_receipt_hash public_archive_uri public_archive_hash official_leaderboard_entry_uri official_leaderboard_entry_hash license_review_uri license_review_hash pii_review_uri pii_review_hash third_party_repro_report_uri third_party_repro_report_hash package_signature_uri package_signature_hash timestamp_authority_uri timestamp_authority_hash package_registry_entry_uri package_registry_entry_hash observed_at_utc routing_trigger_rate active_jump_rate; do
  ((package_rows += 1))
  ((total_packaged_query_rows += query_rows_packaged))

  if [[ -n "${package_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  package_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi

  for pair in \
    "$run_package_manifest_uri|$run_package_manifest_hash" \
    "$raw_query_set_uri|$raw_query_set_hash" \
    "$raw_prediction_output_uri|$raw_prediction_output_hash" \
    "$evaluator_container_digest_uri|$evaluator_container_digest_hash" \
    "$evaluator_config_uri|$evaluator_config_hash" \
    "$metric_report_uri|$metric_report_hash" \
    "$submission_receipt_uri|$submission_receipt_hash" \
    "$public_archive_uri|$public_archive_hash" \
    "$official_leaderboard_entry_uri|$official_leaderboard_entry_hash" \
    "$license_review_uri|$license_review_hash" \
    "$pii_review_uri|$pii_review_hash" \
    "$third_party_repro_report_uri|$third_party_repro_report_hash" \
    "$package_signature_uri|$package_signature_hash" \
    "$timestamp_authority_uri|$timestamp_authority_hash" \
    "$package_registry_entry_uri|$package_registry_entry_hash"; do
    ((required_run_package_uri_fields += 1))
    ((required_run_package_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((run_package_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_run_package_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_run_package_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_run_package_uri_fields += 1))
    fi
  done

  if [[ "$query_rows_packaged" -ge "$MIN_PACKAGE_QUERY_ROWS_PER_FAMILY" ]]; then
    ((min_packaged_query_rows_pass_rows += 1))
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

  [[ "$v08aq_confirmation_bound" == "1" ]] && ((v08aq_confirmation_bound_rows += 1))
  [[ "$run_package_nonfixture_declared" == "1" ]] && ((run_package_nonfixture_declared_rows += 1))
  [[ "$official_benchmark_declared" == "1" ]] && ((official_benchmark_declared_rows += 1))
  [[ "$public_archive_declared" == "1" ]] && ((public_archive_declared_rows += 1))
  [[ "$raw_query_set_declared" == "1" ]] && ((raw_query_set_declared_rows += 1))
  [[ "$raw_prediction_output_declared" == "1" ]] && ((raw_prediction_output_declared_rows += 1))
  [[ "$evaluator_container_declared" == "1" ]] && ((evaluator_container_declared_rows += 1))
  [[ "$immutable_archive_declared" == "1" ]] && ((immutable_archive_declared_rows += 1))
  [[ "$license_review_declared" == "1" ]] && ((license_review_declared_rows += 1))
  [[ "$pii_review_declared" == "1" ]] && ((pii_review_declared_rows += 1))
  [[ "$third_party_reproducibility_declared" == "1" ]] && ((third_party_reproducibility_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  package_routing="$(awk -v a="$package_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  package_jump="$(awk -v a="$package_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$PACKAGE_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${package_family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

expected_run_package_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * RUN_PACKAGE_URI_FIELDS_PER_ROW))
expected_run_package_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * RUN_PACKAGE_HASH_FIELDS_PER_ROW))
external_benchmark_real_nonfixture_run_package_intake_ready=0
if [[ "$upstream_independent_live_rerun_confirmation_ready" == "1" &&
      "$package_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$required_run_package_uri_fields" -eq "$expected_run_package_uri_fields" &&
      "$nonlocal_run_package_uri_fields" -eq "$expected_run_package_uri_fields" &&
      "$local_run_package_uri_fields" -eq 0 &&
      "$nonplaceholder_run_package_uri_fields" -eq "$expected_run_package_uri_fields" &&
      "$required_run_package_hash_fields" -eq "$expected_run_package_hash_fields" &&
      "$run_package_hash_attested_fields" -eq "$expected_run_package_hash_fields" &&
      "$min_packaged_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_delta_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$v08aq_confirmation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$run_package_nonfixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$official_benchmark_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_archive_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$raw_query_set_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$raw_prediction_output_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$evaluator_container_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$immutable_archive_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$license_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$pii_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$third_party_reproducibility_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$package_routing" == "0.000000" &&
      "$package_jump" == "0.000000" ]]; then
  external_benchmark_real_nonfixture_run_package_intake_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$package_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$package_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-independent-live-rerun-confirmation-not-ready"
if [[ "$upstream_independent_live_rerun_confirmation_ready" != "1" ]]; then
  action="external-benchmark-independent-live-rerun-confirmation-not-ready"
elif [[ "$package_rows" -eq 0 ]]; then
  action="external-benchmark-real-nonfixture-run-package-missing"
elif [[ "$package_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-real-nonfixture-run-package-coverage-incomplete"
elif [[ "$required_run_package_hash_fields" -ne "$expected_run_package_hash_fields" ||
        "$run_package_hash_attested_fields" -ne "$expected_run_package_hash_fields" ]]; then
  action="external-benchmark-real-nonfixture-run-package-hash-attestation-missing"
elif [[ "$required_run_package_uri_fields" -ne "$expected_run_package_uri_fields" ||
        "$nonlocal_run_package_uri_fields" -ne "$expected_run_package_uri_fields" ||
        "$local_run_package_uri_fields" -ne 0 ]]; then
  action="external-benchmark-real-nonfixture-run-package-local-artifact-uri"
elif [[ "$nonplaceholder_run_package_uri_fields" -ne "$expected_run_package_uri_fields" ]]; then
  action="external-benchmark-real-nonfixture-run-package-placeholder-artifact-uri"
elif [[ "$min_packaged_query_rows_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-real-nonfixture-run-package-query-volume-insufficient"
elif [[ "$metric_threshold_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-real-nonfixture-run-package-quality-threshold-missing"
elif [[ "$metric_delta_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-real-nonfixture-run-package-metric-delta-too-large"
elif [[ "$v08aq_confirmation_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-real-nonfixture-run-package-binding-missing"
elif [[ "$run_package_nonfixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$official_benchmark_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$public_archive_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$raw_query_set_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$raw_prediction_output_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$evaluator_container_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$immutable_archive_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-real-nonfixture-run-package-package-declaration-missing"
elif [[ "$license_review_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$pii_review_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$third_party_reproducibility_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-real-nonfixture-run-package-review-declaration-missing"
elif [[ "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-real-nonfixture-run-package-fixture-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-real-nonfixture-run-package-jump-guardrail-violated"
elif [[ "$external_benchmark_real_nonfixture_run_package_intake_ready" == "1" ]]; then
  action="real-nonfixture-run-package-intake-ready-await-live-package-artifact-fetch"
fi

summary_header=(
  benchmark_scope
  package_source
  upstream_independent_live_rerun_confirmation_ready
  upstream_real_external
  upstream_action
  package_rows
  expected_family_rows
  duplicate_family_rows
  family_coverage
  expected_external_families
  required_run_package_uri_fields
  nonlocal_run_package_uri_fields
  local_run_package_uri_fields
  nonplaceholder_run_package_uri_fields
  required_run_package_hash_fields
  run_package_hash_attested_fields
  total_packaged_query_rows
  min_packaged_query_rows_pass_rows
  metric_threshold_pass_rows
  metric_delta_pass_rows
  v08aq_confirmation_bound_rows
  run_package_nonfixture_declared_rows
  official_benchmark_declared_rows
  public_archive_declared_rows
  raw_query_set_declared_rows
  raw_prediction_output_declared_rows
  evaluator_container_declared_rows
  immutable_archive_declared_rows
  license_review_declared_rows
  pii_review_declared_rows
  third_party_reproducibility_declared_rows
  fixture_free_rows
  timestamp_rows
  external_benchmark_real_nonfixture_run_package_intake_ready
  real_external_benchmark_verified
  action
  routing_trigger_rate
  active_jump_rate
)
summary_values=(
  route-memory-v08ar
  "$PACKAGE_SOURCE"
  "$upstream_independent_live_rerun_confirmation_ready"
  "$upstream_real_external"
  "$upstream_action"
  "$package_rows"
  "$expected_family_rows"
  "$duplicate_family_rows"
  "$family_coverage"
  "$EXPECTED_EXTERNAL_FAMILIES"
  "$required_run_package_uri_fields"
  "$nonlocal_run_package_uri_fields"
  "$local_run_package_uri_fields"
  "$nonplaceholder_run_package_uri_fields"
  "$required_run_package_hash_fields"
  "$run_package_hash_attested_fields"
  "$total_packaged_query_rows"
  "$min_packaged_query_rows_pass_rows"
  "$metric_threshold_pass_rows"
  "$metric_delta_pass_rows"
  "$v08aq_confirmation_bound_rows"
  "$run_package_nonfixture_declared_rows"
  "$official_benchmark_declared_rows"
  "$public_archive_declared_rows"
  "$raw_query_set_declared_rows"
  "$raw_prediction_output_declared_rows"
  "$evaluator_container_declared_rows"
  "$immutable_archive_declared_rows"
  "$license_review_declared_rows"
  "$pii_review_declared_rows"
  "$third_party_reproducibility_declared_rows"
  "$fixture_free_rows"
  "$timestamp_rows"
  "$external_benchmark_real_nonfixture_run_package_intake_ready"
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
  printf "upstream-independent-live-rerun-confirmation,%s,ready=%d action=%s\n" \
    "$([[ "$upstream_independent_live_rerun_confirmation_ready" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_independent_live_rerun_confirmation_ready" \
    "$upstream_action"
  printf "real-nonfixture-run-package-coverage,%s,coverage=%d/%d rows=%d duplicates=%d\n" \
    "$([[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$package_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$package_rows" \
    "$duplicate_family_rows"
  printf "real-nonfixture-run-package-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$([[ "$nonlocal_run_package_uri_fields" -eq "$expected_run_package_uri_fields" && "$run_package_hash_attested_fields" -eq "$expected_run_package_hash_fields" && "$local_run_package_uri_fields" -eq 0 && "$nonplaceholder_run_package_uri_fields" -eq "$expected_run_package_uri_fields" ]] && echo pass || echo blocked)" \
    "$nonlocal_run_package_uri_fields" \
    "$expected_run_package_uri_fields" \
    "$run_package_hash_attested_fields" \
    "$expected_run_package_hash_fields" \
    "$local_run_package_uri_fields" \
    "$nonplaceholder_run_package_uri_fields" \
    "$expected_run_package_uri_fields"
  printf "real-nonfixture-run-package-query-volume,%s,pass_rows=%d/%d total_packaged_query_rows=%d min=%d\n" \
    "$([[ "$min_packaged_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$min_packaged_query_rows_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$total_packaged_query_rows" \
    "$MIN_PACKAGE_QUERY_ROWS_PER_FAMILY"
  printf "real-nonfixture-run-package-metric-thresholds,%s,pass_rows=%d/%d\n" \
    "$([[ "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_threshold_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "real-nonfixture-run-package-metric-delta,%s,pass_rows=%d/%d max_abs_delta=0.020000\n" \
    "$([[ "$metric_delta_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_delta_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "real-nonfixture-run-package-bindings,%s,v08aq=%d expected=%d\n" \
    "$([[ "$v08aq_confirmation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$v08aq_confirmation_bound_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "real-nonfixture-run-package-declarations,%s,nonfixture=%d official=%d archive=%d raw_queries=%d raw_outputs=%d evaluator=%d immutable=%d expected=%d\n" \
    "$([[ "$run_package_nonfixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$official_benchmark_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$public_archive_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$raw_query_set_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$raw_prediction_output_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$evaluator_container_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$immutable_archive_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$run_package_nonfixture_declared_rows" \
    "$official_benchmark_declared_rows" \
    "$public_archive_declared_rows" \
    "$raw_query_set_declared_rows" \
    "$raw_prediction_output_declared_rows" \
    "$evaluator_container_declared_rows" \
    "$immutable_archive_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "package-review-declarations,%s,license=%d pii=%d third_party=%d expected=%d\n" \
    "$([[ "$license_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$pii_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$third_party_reproducibility_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$license_review_declared_rows" \
    "$pii_review_declared_rows" \
    "$third_party_reproducibility_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "fixture-declarations,%s,fixture_free=%d timestamp=%d expected=%d\n" \
    "$([[ "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "external-benchmark-real-nonfixture-run-package-intake,%s,ready=%d action=%s\n" \
    "$([[ "$external_benchmark_real_nonfixture_run_package_intake_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_real_nonfixture_run_package_intake_ready" \
    "$action"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d\n" \
    blocked \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "package: $PACKAGE_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
