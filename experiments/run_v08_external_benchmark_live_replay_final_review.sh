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

PREFIX="v08_external_benchmark_live_replay_final_review"
AM_PREFIX="v08_external_benchmark_independent_run_evaluator_evidence"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_live_replay_final_review_smoke"
  AM_PREFIX="v08_external_benchmark_independent_run_evaluator_evidence_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_live_replay_final_review_full"
  AM_PREFIX="v08_external_benchmark_independent_run_evaluator_evidence_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_independent_run_evaluator_evidence.sh" "${RUN_ARGS[@]}" >/dev/null

AM_SUMMARY_CSV="$RESULTS_DIR/${AM_PREFIX}_summary.csv"
REPLAY_CSV="$RESULTS_DIR/${PREFIX}_review.csv"
REPLAY_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
REPLAY_REVIEW_URI_FIELDS_PER_ROW=8
REPLAY_REVIEW_HASH_FIELDS_PER_ROW=8
MIN_REPLAYED_QUERY_ROWS_PER_FAMILY=7

write_replay_header() {
  echo "benchmark_family,external_run_id,live_replay_id,final_review_id,v08am_evidence_bound,all_queries_replayed,metrics_recomputed,live_replay_declared,runner_owned_replay_declared,network_observed_declared,final_review_approved,independent_final_reviewer_declared,public_registry_bound,non_fixture_declared,fixture_or_synthetic_declared,replayed_query_rows,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,replay_manifest_uri,replay_manifest_hash,replay_run_log_uri,replay_run_log_hash,replay_evaluator_output_uri,replay_evaluator_output_hash,replay_metric_report_uri,replay_metric_report_hash,replay_network_receipt_uri,replay_network_receipt_hash,final_review_report_uri,final_review_report_hash,final_reviewer_identity_uri,final_reviewer_identity_hash,final_review_registry_uri,final_review_registry_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-an column: " column > "/dev/stderr"
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
        print "missing v08-an summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_LIVE_REPLAY_FINAL_REVIEW_CSV:-}" ]]; then
  REPLAY_CSV="$V08_EXTERNAL_BENCHMARK_LIVE_REPLAY_FINAL_REVIEW_CSV"
  REPLAY_SOURCE="provided-csv"
  if [[ ! -s "$REPLAY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_LIVE_REPLAY_FINAL_REVIEW_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_replay_header >"$REPLAY_CSV"
fi

upstream_independent_ready="$(csv_value "$AM_SUMMARY_CSV" "external_benchmark_independent_run_evaluator_evidence_ready")"
upstream_real_external="$(csv_value "$AM_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AM_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AM_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AM_SUMMARY_CSV" "active_jump_rate")"

review_rows=0
expected_family_rows=0
duplicate_family_rows=0
required_replay_review_uri_fields=0
nonlocal_replay_review_uri_fields=0
local_replay_review_uri_fields=0
nonplaceholder_replay_review_uri_fields=0
required_replay_review_hash_fields=0
replay_review_hash_attested_fields=0
total_replayed_query_rows=0
min_replayed_query_rows_pass_rows=0
metric_threshold_pass_rows=0
v08am_evidence_bound_rows=0
all_queries_replayed_rows=0
metrics_recomputed_rows=0
live_replay_declared_rows=0
runner_owned_replay_declared_rows=0
network_observed_declared_rows=0
final_review_approved_rows=0
independent_final_reviewer_declared_rows=0
public_registry_bound_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
replay_routing="0.000000"
replay_jump="0.000000"
declare -A review_family_seen=()

REPLAY_TSV="$TMP_DIR/live_replay_final_review.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family external_run_id live_replay_id final_review_id v08am_evidence_bound all_queries_replayed metrics_recomputed live_replay_declared runner_owned_replay_declared network_observed_declared final_review_approved independent_final_reviewer_declared public_registry_bound non_fixture_declared fixture_or_synthetic_declared replayed_query_rows span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate replay_manifest_uri replay_manifest_hash replay_run_log_uri replay_run_log_hash replay_evaluator_output_uri replay_evaluator_output_hash replay_metric_report_uri replay_metric_report_hash replay_network_receipt_uri replay_network_receipt_hash final_review_report_uri final_review_report_hash final_reviewer_identity_uri final_reviewer_identity_hash final_review_registry_uri final_review_registry_hash observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-an live replay/final-review column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-an live replay/final-review row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$REPLAY_CSV" >"$REPLAY_TSV"

while IFS=$'\t' read -r benchmark_family external_run_id live_replay_id final_review_id v08am_evidence_bound all_queries_replayed metrics_recomputed live_replay_declared runner_owned_replay_declared network_observed_declared final_review_approved independent_final_reviewer_declared public_registry_bound non_fixture_declared fixture_or_synthetic_declared replayed_query_rows span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate replay_manifest_uri replay_manifest_hash replay_run_log_uri replay_run_log_hash replay_evaluator_output_uri replay_evaluator_output_hash replay_metric_report_uri replay_metric_report_hash replay_network_receipt_uri replay_network_receipt_hash final_review_report_uri final_review_report_hash final_reviewer_identity_uri final_reviewer_identity_hash final_review_registry_uri final_review_registry_hash observed_at_utc routing_trigger_rate active_jump_rate; do
  ((review_rows += 1))
  ((total_replayed_query_rows += replayed_query_rows))

  if [[ -n "${review_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  review_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi

  for pair in \
    "$replay_manifest_uri|$replay_manifest_hash" \
    "$replay_run_log_uri|$replay_run_log_hash" \
    "$replay_evaluator_output_uri|$replay_evaluator_output_hash" \
    "$replay_metric_report_uri|$replay_metric_report_hash" \
    "$replay_network_receipt_uri|$replay_network_receipt_hash" \
    "$final_review_report_uri|$final_review_report_hash" \
    "$final_reviewer_identity_uri|$final_reviewer_identity_hash" \
    "$final_review_registry_uri|$final_review_registry_hash"; do
    ((required_replay_review_uri_fields += 1))
    ((required_replay_review_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((replay_review_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_replay_review_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_replay_review_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_replay_review_uri_fields += 1))
    fi
  done

  if [[ "$replayed_query_rows" -ge "$MIN_REPLAYED_QUERY_ROWS_PER_FAMILY" ]]; then
    ((min_replayed_query_rows_pass_rows += 1))
  fi
  if float_ge "$span_exact" "0.800000" &&
     float_ge "$chunk_exact" "0.750000" &&
     float_ge "$missing_abstain" "0.850000" &&
     float_le "$near_miss_false_positive" "0.050000" &&
     float_le "$wrong_answer_rate" "0.080000"; then
    ((metric_threshold_pass_rows += 1))
  fi

  [[ "$v08am_evidence_bound" == "1" ]] && ((v08am_evidence_bound_rows += 1))
  [[ "$all_queries_replayed" == "1" ]] && ((all_queries_replayed_rows += 1))
  [[ "$metrics_recomputed" == "1" ]] && ((metrics_recomputed_rows += 1))
  [[ "$live_replay_declared" == "1" ]] && ((live_replay_declared_rows += 1))
  [[ "$runner_owned_replay_declared" == "1" ]] && ((runner_owned_replay_declared_rows += 1))
  [[ "$network_observed_declared" == "1" ]] && ((network_observed_declared_rows += 1))
  [[ "$final_review_approved" == "1" ]] && ((final_review_approved_rows += 1))
  [[ "$independent_final_reviewer_declared" == "1" ]] && ((independent_final_reviewer_declared_rows += 1))
  [[ "$public_registry_bound" == "1" ]] && ((public_registry_bound_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  replay_routing="$(awk -v a="$replay_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  replay_jump="$(awk -v a="$replay_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$REPLAY_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${review_family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

expected_replay_review_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * REPLAY_REVIEW_URI_FIELDS_PER_ROW))
expected_replay_review_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * REPLAY_REVIEW_HASH_FIELDS_PER_ROW))
external_benchmark_live_replay_final_review_ready=0
if [[ "$upstream_independent_ready" == "1" &&
      "$review_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$required_replay_review_uri_fields" -eq "$expected_replay_review_uri_fields" &&
      "$nonlocal_replay_review_uri_fields" -eq "$expected_replay_review_uri_fields" &&
      "$local_replay_review_uri_fields" -eq 0 &&
      "$nonplaceholder_replay_review_uri_fields" -eq "$expected_replay_review_uri_fields" &&
      "$required_replay_review_hash_fields" -eq "$expected_replay_review_hash_fields" &&
      "$replay_review_hash_attested_fields" -eq "$expected_replay_review_hash_fields" &&
      "$min_replayed_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$v08am_evidence_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$all_queries_replayed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metrics_recomputed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_replay_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$runner_owned_replay_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$network_observed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$final_review_approved_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_final_reviewer_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_registry_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$replay_routing" == "0.000000" &&
      "$replay_jump" == "0.000000" ]]; then
  external_benchmark_live_replay_final_review_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$replay_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$replay_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-independent-run-evaluator-evidence-not-ready"
if [[ "$upstream_independent_ready" != "1" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-not-ready"
elif [[ "$review_rows" -eq 0 ]]; then
  action="external-benchmark-live-replay-final-review-evidence-missing"
elif [[ "$review_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-live-replay-final-review-coverage-incomplete"
elif [[ "$required_replay_review_hash_fields" -ne "$expected_replay_review_hash_fields" ||
        "$replay_review_hash_attested_fields" -ne "$expected_replay_review_hash_fields" ]]; then
  action="external-benchmark-live-replay-final-review-hash-attestation-missing"
elif [[ "$required_replay_review_uri_fields" -ne "$expected_replay_review_uri_fields" ||
        "$nonlocal_replay_review_uri_fields" -ne "$expected_replay_review_uri_fields" ||
        "$local_replay_review_uri_fields" -ne 0 ]]; then
  action="external-benchmark-live-replay-final-review-local-artifact-uri"
elif [[ "$nonplaceholder_replay_review_uri_fields" -ne "$expected_replay_review_uri_fields" ]]; then
  action="external-benchmark-live-replay-final-review-placeholder-artifact-uri"
elif [[ "$min_replayed_query_rows_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-replay-final-review-query-volume-insufficient"
elif [[ "$metric_threshold_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-replay-final-review-quality-threshold-missing"
elif [[ "$v08am_evidence_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$all_queries_replayed_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$metrics_recomputed_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-replay-final-review-binding-missing"
elif [[ "$live_replay_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$runner_owned_replay_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$network_observed_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-replay-final-review-replay-declaration-missing"
elif [[ "$final_review_approved_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$independent_final_reviewer_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$public_registry_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-replay-final-review-review-declaration-missing"
elif [[ "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-replay-final-review-fixture-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-live-replay-final-review-jump-guardrail-violated"
elif [[ "$external_benchmark_live_replay_final_review_ready" == "1" ]]; then
  action="live-replay-final-review-ready-await-public-nonfixture-verification"
fi

{
  echo "benchmark_scope,replay_source,upstream_independent_run_evaluator_evidence_ready,upstream_real_external,upstream_action,review_rows,expected_family_rows,duplicate_family_rows,family_coverage,expected_external_families,required_replay_review_uri_fields,nonlocal_replay_review_uri_fields,local_replay_review_uri_fields,nonplaceholder_replay_review_uri_fields,required_replay_review_hash_fields,replay_review_hash_attested_fields,total_replayed_query_rows,min_replayed_query_rows_pass_rows,metric_threshold_pass_rows,v08am_evidence_bound_rows,all_queries_replayed_rows,metrics_recomputed_rows,live_replay_declared_rows,runner_owned_replay_declared_rows,network_observed_declared_rows,final_review_approved_rows,independent_final_reviewer_declared_rows,public_registry_bound_rows,non_fixture_declared_rows,fixture_free_rows,timestamp_rows,external_benchmark_live_replay_final_review_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08an,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s\n" \
    "$REPLAY_SOURCE" \
    "$upstream_independent_ready" \
    "$upstream_real_external" \
    "$upstream_action" \
    "$review_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$required_replay_review_uri_fields" \
    "$nonlocal_replay_review_uri_fields" \
    "$local_replay_review_uri_fields" \
    "$nonplaceholder_replay_review_uri_fields" \
    "$required_replay_review_hash_fields" \
    "$replay_review_hash_attested_fields" \
    "$total_replayed_query_rows" \
    "$min_replayed_query_rows_pass_rows" \
    "$metric_threshold_pass_rows" \
    "$v08am_evidence_bound_rows" \
    "$all_queries_replayed_rows" \
    "$metrics_recomputed_rows" \
    "$live_replay_declared_rows" \
    "$runner_owned_replay_declared_rows" \
    "$network_observed_declared_rows" \
    "$final_review_approved_rows" \
    "$independent_final_reviewer_declared_rows" \
    "$public_registry_bound_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$external_benchmark_live_replay_final_review_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "upstream-independent-run-evaluator-evidence,%s,ready=%d action=%s\n" \
    "$([[ "$upstream_independent_ready" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_independent_ready" \
    "$upstream_action"
  printf "live-replay-final-review-coverage,%s,coverage=%d/%d rows=%d duplicates=%d\n" \
    "$([[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$review_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$review_rows" \
    "$duplicate_family_rows"
  printf "live-replay-final-review-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$([[ "$nonlocal_replay_review_uri_fields" -eq "$expected_replay_review_uri_fields" && "$replay_review_hash_attested_fields" -eq "$expected_replay_review_hash_fields" && "$local_replay_review_uri_fields" -eq 0 && "$nonplaceholder_replay_review_uri_fields" -eq "$expected_replay_review_uri_fields" ]] && echo pass || echo blocked)" \
    "$nonlocal_replay_review_uri_fields" \
    "$expected_replay_review_uri_fields" \
    "$replay_review_hash_attested_fields" \
    "$expected_replay_review_hash_fields" \
    "$local_replay_review_uri_fields" \
    "$nonplaceholder_replay_review_uri_fields" \
    "$expected_replay_review_uri_fields"
  printf "live-replay-final-review-query-volume,%s,pass_rows=%d/%d total_replayed_query_rows=%d min=%d\n" \
    "$([[ "$min_replayed_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$min_replayed_query_rows_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$total_replayed_query_rows" \
    "$MIN_REPLAYED_QUERY_ROWS_PER_FAMILY"
  printf "live-replay-final-review-metric-thresholds,%s,pass_rows=%d/%d\n" \
    "$([[ "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_threshold_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "live-replay-final-review-bindings,%s,v08am=%d all_queries=%d metrics=%d expected=%d\n" \
    "$([[ "$v08am_evidence_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$all_queries_replayed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$metrics_recomputed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$v08am_evidence_bound_rows" \
    "$all_queries_replayed_rows" \
    "$metrics_recomputed_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "live-replay-declarations,%s,live=%d runner_owned=%d network=%d expected=%d\n" \
    "$([[ "$live_replay_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$runner_owned_replay_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$network_observed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$live_replay_declared_rows" \
    "$runner_owned_replay_declared_rows" \
    "$network_observed_declared_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "final-review-declarations,%s,approved=%d independent_reviewer=%d public_registry=%d expected=%d\n" \
    "$([[ "$final_review_approved_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$independent_final_reviewer_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$public_registry_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$final_review_approved_rows" \
    "$independent_final_reviewer_declared_rows" \
    "$public_registry_bound_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "fixture-declarations,%s,non_fixture=%d fixture_free=%d timestamp=%d expected=%d\n" \
    "$([[ "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "external-benchmark-live-replay-final-review,%s,ready=%d action=%s\n" \
    "$([[ "$external_benchmark_live_replay_final_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_live_replay_final_review_ready" \
    "$action"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d\n" \
    blocked \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "review: $REPLAY_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
