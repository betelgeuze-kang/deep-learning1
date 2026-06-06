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

PREFIX="v08_external_benchmark_independent_run_evaluator_evidence"
AL_PREFIX="v08_external_benchmark_run_evaluator_trace"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_independent_run_evaluator_evidence_smoke"
  AL_PREFIX="v08_external_benchmark_run_evaluator_trace_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_independent_run_evaluator_evidence_full"
  AL_PREFIX="v08_external_benchmark_run_evaluator_trace_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_run_evaluator_trace.sh" "${RUN_ARGS[@]}" >/dev/null

AL_SUMMARY_CSV="$RESULTS_DIR/${AL_PREFIX}_summary.csv"
EVIDENCE_CSV="$RESULTS_DIR/${PREFIX}_evidence.csv"
EVIDENCE_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
EVIDENCE_URI_FIELDS_PER_ROW=7
EVIDENCE_HASH_FIELDS_PER_ROW=7
MIN_QUERY_ROWS_PER_FAMILY=7

write_evidence_header() {
  echo "benchmark_family,external_run_id,trace_manifest_uri,trace_manifest_hash,run_log_uri,run_log_hash,evaluator_output_uri,evaluator_output_hash,metric_report_uri,metric_report_hash,query_trace_uri,query_trace_hash,observer_identity_uri,observer_identity_hash,authority_packet_uri,authority_packet_hash,query_rows,span_exact,chunk_exact,missing_abstain,near_miss_false_positive,wrong_answer_rate,trace_bound,evaluator_bound,metrics_bound,authority_bound,independent_evaluator_declared,official_metric_declared,all_queries_bound_declared,non_fixture_declared,fixture_or_synthetic_declared,observed_at_utc,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-am column: " column > "/dev/stderr"
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
        print "missing v08-am summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_INDEPENDENT_RUN_EVALUATOR_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_INDEPENDENT_RUN_EVALUATOR_EVIDENCE_CSV"
  EVIDENCE_SOURCE="provided-csv"
  if [[ ! -s "$EVIDENCE_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_INDEPENDENT_RUN_EVALUATOR_EVIDENCE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_evidence_header >"$EVIDENCE_CSV"
fi

upstream_codebase_run_evaluator_trace_ready="$(csv_value "$AL_SUMMARY_CSV" "codebase_run_evaluator_trace_ready")"
upstream_authority_promotion_evidence_ready="$(csv_value "$AL_SUMMARY_CSV" "authority_promotion_evidence_ready")"
upstream_external_family_coverage="$(csv_value "$AL_SUMMARY_CSV" "external_family_coverage")"
upstream_real_external="$(csv_value "$AL_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AL_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AL_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AL_SUMMARY_CSV" "active_jump_rate")"

evidence_rows=0
expected_family_rows=0
duplicate_family_rows=0
required_evidence_uri_fields=0
nonlocal_evidence_uri_fields=0
local_evidence_uri_fields=0
nonplaceholder_evidence_uri_fields=0
required_evidence_hash_fields=0
evidence_hash_attested_fields=0
total_query_rows=0
min_query_rows_pass_rows=0
metric_threshold_pass_rows=0
trace_bound_rows=0
evaluator_bound_rows=0
metrics_bound_rows=0
authority_bound_rows=0
independent_evaluator_declared_rows=0
official_metric_declared_rows=0
all_queries_bound_declared_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
evidence_routing="0.000000"
evidence_jump="0.000000"
declare -A evidence_family_seen=()

EVIDENCE_TSV="$TMP_DIR/independent_run_evaluator_evidence.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family external_run_id trace_manifest_uri trace_manifest_hash run_log_uri run_log_hash evaluator_output_uri evaluator_output_hash metric_report_uri metric_report_hash query_trace_uri query_trace_hash observer_identity_uri observer_identity_hash authority_packet_uri authority_packet_hash query_rows span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate trace_bound evaluator_bound metrics_bound authority_bound independent_evaluator_declared official_metric_declared all_queries_bound_declared non_fixture_declared fixture_or_synthetic_declared observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-am independent evidence column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-am independent evidence row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$EVIDENCE_CSV" >"$EVIDENCE_TSV"

while IFS=$'\t' read -r benchmark_family external_run_id trace_manifest_uri trace_manifest_hash run_log_uri run_log_hash evaluator_output_uri evaluator_output_hash metric_report_uri metric_report_hash query_trace_uri query_trace_hash observer_identity_uri observer_identity_hash authority_packet_uri authority_packet_hash query_rows span_exact chunk_exact missing_abstain near_miss_false_positive wrong_answer_rate trace_bound evaluator_bound metrics_bound authority_bound independent_evaluator_declared official_metric_declared all_queries_bound_declared non_fixture_declared fixture_or_synthetic_declared observed_at_utc routing_trigger_rate active_jump_rate; do
  ((evidence_rows += 1))
  ((total_query_rows += query_rows))

  if [[ -n "${evidence_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  evidence_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi

  for pair in \
    "$trace_manifest_uri|$trace_manifest_hash" \
    "$run_log_uri|$run_log_hash" \
    "$evaluator_output_uri|$evaluator_output_hash" \
    "$metric_report_uri|$metric_report_hash" \
    "$query_trace_uri|$query_trace_hash" \
    "$observer_identity_uri|$observer_identity_hash" \
    "$authority_packet_uri|$authority_packet_hash"; do
    ((required_evidence_uri_fields += 1))
    ((required_evidence_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((evidence_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_evidence_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_evidence_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_evidence_uri_fields += 1))
    fi
  done

  if [[ "$query_rows" -ge "$MIN_QUERY_ROWS_PER_FAMILY" ]]; then
    ((min_query_rows_pass_rows += 1))
  fi
  if float_ge "$span_exact" "0.800000" &&
     float_ge "$chunk_exact" "0.750000" &&
     float_ge "$missing_abstain" "0.850000" &&
     float_le "$near_miss_false_positive" "0.050000" &&
     float_le "$wrong_answer_rate" "0.080000"; then
    ((metric_threshold_pass_rows += 1))
  fi

  [[ "$trace_bound" == "1" ]] && ((trace_bound_rows += 1))
  [[ "$evaluator_bound" == "1" ]] && ((evaluator_bound_rows += 1))
  [[ "$metrics_bound" == "1" ]] && ((metrics_bound_rows += 1))
  [[ "$authority_bound" == "1" ]] && ((authority_bound_rows += 1))
  [[ "$independent_evaluator_declared" == "1" ]] && ((independent_evaluator_declared_rows += 1))
  [[ "$official_metric_declared" == "1" ]] && ((official_metric_declared_rows += 1))
  [[ "$all_queries_bound_declared" == "1" ]] && ((all_queries_bound_declared_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  evidence_routing="$(awk -v a="$evidence_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  evidence_jump="$(awk -v a="$evidence_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$EVIDENCE_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${evidence_family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

expected_evidence_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * EVIDENCE_URI_FIELDS_PER_ROW))
expected_evidence_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * EVIDENCE_HASH_FIELDS_PER_ROW))
external_benchmark_independent_run_evaluator_evidence_ready=0
if [[ "$upstream_codebase_run_evaluator_trace_ready" == "1" &&
      "$upstream_authority_promotion_evidence_ready" == "1" &&
      "$evidence_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$required_evidence_uri_fields" -eq "$expected_evidence_uri_fields" &&
      "$nonlocal_evidence_uri_fields" -eq "$expected_evidence_uri_fields" &&
      "$local_evidence_uri_fields" -eq 0 &&
      "$nonplaceholder_evidence_uri_fields" -eq "$expected_evidence_uri_fields" &&
      "$required_evidence_hash_fields" -eq "$expected_evidence_hash_fields" &&
      "$evidence_hash_attested_fields" -eq "$expected_evidence_hash_fields" &&
      "$min_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$trace_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$evaluator_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metrics_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_evaluator_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$official_metric_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$all_queries_bound_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$evidence_routing" == "0.000000" &&
      "$evidence_jump" == "0.000000" ]]; then
  external_benchmark_independent_run_evaluator_evidence_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$evidence_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$evidence_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-run-evaluator-trace-not-ready"
if [[ "$upstream_codebase_run_evaluator_trace_ready" != "1" ]]; then
  action="external-benchmark-run-evaluator-trace-not-ready"
elif [[ "$upstream_authority_promotion_evidence_ready" != "1" ]]; then
  action="external-benchmark-authority-promotion-evidence-not-ready"
elif [[ "$evidence_rows" -eq 0 ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-missing"
elif [[ "$evidence_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-coverage-incomplete"
elif [[ "$required_evidence_hash_fields" -ne "$expected_evidence_hash_fields" ||
        "$evidence_hash_attested_fields" -ne "$expected_evidence_hash_fields" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-hash-attestation-missing"
elif [[ "$required_evidence_uri_fields" -ne "$expected_evidence_uri_fields" ||
        "$nonlocal_evidence_uri_fields" -ne "$expected_evidence_uri_fields" ||
        "$local_evidence_uri_fields" -ne 0 ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-local-artifact-uri"
elif [[ "$nonplaceholder_evidence_uri_fields" -ne "$expected_evidence_uri_fields" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-placeholder-artifact-uri"
elif [[ "$min_query_rows_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-query-volume-insufficient"
elif [[ "$metric_threshold_pass_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-quality-threshold-missing"
elif [[ "$trace_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$evaluator_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$metrics_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$authority_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-proof-binding-missing"
elif [[ "$independent_evaluator_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$official_metric_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$all_queries_bound_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-independent-run-evaluator-evidence-jump-guardrail-violated"
elif [[ "$external_benchmark_independent_run_evaluator_evidence_ready" == "1" ]]; then
  action="independent-run-evaluator-evidence-ready-await-live-replay-or-final-review"
fi

{
  echo "benchmark_scope,evidence_source,upstream_codebase_run_evaluator_trace_ready,upstream_authority_promotion_evidence_ready,upstream_external_family_coverage,upstream_real_external,upstream_action,evidence_rows,expected_family_rows,duplicate_family_rows,family_coverage,expected_external_families,required_evidence_uri_fields,nonlocal_evidence_uri_fields,local_evidence_uri_fields,nonplaceholder_evidence_uri_fields,required_evidence_hash_fields,evidence_hash_attested_fields,total_query_rows,min_query_rows_pass_rows,metric_threshold_pass_rows,trace_bound_rows,evaluator_bound_rows,metrics_bound_rows,authority_bound_rows,independent_evaluator_declared_rows,official_metric_declared_rows,all_queries_bound_declared_rows,non_fixture_declared_rows,fixture_free_rows,timestamp_rows,external_benchmark_independent_run_evaluator_evidence_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08am,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s\n" \
    "$EVIDENCE_SOURCE" \
    "$upstream_codebase_run_evaluator_trace_ready" \
    "$upstream_authority_promotion_evidence_ready" \
    "$upstream_external_family_coverage" \
    "$upstream_real_external" \
    "$upstream_action" \
    "$evidence_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$required_evidence_uri_fields" \
    "$nonlocal_evidence_uri_fields" \
    "$local_evidence_uri_fields" \
    "$nonplaceholder_evidence_uri_fields" \
    "$required_evidence_hash_fields" \
    "$evidence_hash_attested_fields" \
    "$total_query_rows" \
    "$min_query_rows_pass_rows" \
    "$metric_threshold_pass_rows" \
    "$trace_bound_rows" \
    "$evaluator_bound_rows" \
    "$metrics_bound_rows" \
    "$authority_bound_rows" \
    "$independent_evaluator_declared_rows" \
    "$official_metric_declared_rows" \
    "$all_queries_bound_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$external_benchmark_independent_run_evaluator_evidence_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "upstream-run-evaluator-trace,%s,ready=%d action=%s\n" \
    "$([[ "$upstream_codebase_run_evaluator_trace_ready" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_codebase_run_evaluator_trace_ready" \
    "$upstream_action"
  printf "upstream-authority-promotion-evidence,%s,ready=%d\n" \
    "$([[ "$upstream_authority_promotion_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_authority_promotion_evidence_ready"
  printf "independent-family-coverage,%s,coverage=%d/%d rows=%d duplicates=%d\n" \
    "$([[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$evidence_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$evidence_rows" \
    "$duplicate_family_rows"
  printf "independent-evidence-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$([[ "$nonlocal_evidence_uri_fields" -eq "$expected_evidence_uri_fields" && "$evidence_hash_attested_fields" -eq "$expected_evidence_hash_fields" && "$local_evidence_uri_fields" -eq 0 && "$nonplaceholder_evidence_uri_fields" -eq "$expected_evidence_uri_fields" ]] && echo pass || echo blocked)" \
    "$nonlocal_evidence_uri_fields" \
    "$expected_evidence_uri_fields" \
    "$evidence_hash_attested_fields" \
    "$expected_evidence_hash_fields" \
    "$local_evidence_uri_fields" \
    "$nonplaceholder_evidence_uri_fields" \
    "$expected_evidence_uri_fields"
  printf "independent-query-volume,%s,pass_rows=%d/%d total_query_rows=%d min=%d\n" \
    "$([[ "$min_query_rows_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$min_query_rows_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$total_query_rows" \
    "$MIN_QUERY_ROWS_PER_FAMILY"
  printf "independent-metric-thresholds,%s,pass_rows=%d/%d span>=0.80 chunk>=0.75 missing>=0.85 near_miss_fp<=0.05 wrong<=0.08\n" \
    "$([[ "$metric_threshold_pass_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$metric_threshold_pass_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "independent-proof-bindings,%s,trace=%d evaluator=%d metrics=%d authority=%d expected=%d\n" \
    "$([[ "$trace_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$evaluator_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$metrics_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$trace_bound_rows" \
    "$evaluator_bound_rows" \
    "$metrics_bound_rows" \
    "$authority_bound_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "independent-declarations,%s,independent=%d official_metric=%d all_queries=%d non_fixture=%d fixture_free=%d timestamp=%d expected=%d\n" \
    "$([[ "$independent_evaluator_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$official_metric_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$all_queries_bound_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$independent_evaluator_declared_rows" \
    "$official_metric_declared_rows" \
    "$all_queries_bound_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "external-benchmark-independent-run-evaluator-evidence,%s,ready=%d action=%s\n" \
    "$([[ "$external_benchmark_independent_run_evaluator_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_independent_run_evaluator_evidence_ready" \
    "$action"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d\n" \
    blocked \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "evidence: $EVIDENCE_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
