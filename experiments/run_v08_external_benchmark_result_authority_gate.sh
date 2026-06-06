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

PREFIX="v08_external_benchmark_result_authority_gate"
FINAL_REVIEW_PREFIX="v08_external_benchmark_final_review_gate"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
EXECUTION_PREFIX="v08_external_benchmark_execution_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_result_authority_gate_smoke"
  FINAL_REVIEW_PREFIX="v08_external_benchmark_final_review_gate_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  EXECUTION_PREFIX="v08_external_benchmark_execution_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_final_review_gate.sh" "${RUN_ARGS[@]}" >/dev/null

FINAL_REVIEW_SUMMARY_CSV="$RESULTS_DIR/${FINAL_REVIEW_PREFIX}_summary.csv"
EVIDENCE_CSV="${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv}"
EXECUTION_CSV="${V08_EXTERNAL_BENCHMARK_EXECUTION_CSV:-$RESULTS_DIR/${EXECUTION_PREFIX}_execution.csv}"
RESULT_AUTHORITY_CSV="$RESULTS_DIR/${PREFIX}_result_authority.csv"
RESULT_AUTHORITY_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_result_authority_header() {
  echo "benchmark_family,benchmark_result_id,official_result_authority_id,official_result_authority_domain,leaderboard_uri,leaderboard_hash,result_record_uri,result_record_hash,result_artifact_uri,result_artifact_hash,metric_definition_uri,metric_definition_hash,evaluation_protocol_uri,evaluation_protocol_hash,submitter_identity_uri,submitter_identity_hash,authority_review_uri,authority_review_hash,reviewed_result_uri,reviewed_provenance_hash,reviewed_evaluator_output_hash,reviewed_run_log_hash,reviewed_metric_value,official_leaderboard_declared,official_metric_declared,independent_result_review,live_result_observed,real_result_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
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

is_https_uri() {
  local uri="$1"
  [[ "$uri" == https://* ]]
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

host_matches_domain() {
  local uri="$1"
  local domain="$2"
  local host

  is_https_uri "$uri" || return 1
  host="$(uri_host "$uri")"
  [[ "$host" == "$domain" ]]
}

FINAL_REVIEW_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families final_review_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-x final-review summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["final_review_verified"] + 0,
        $idx["real_external_benchmark_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-x final-review summary row", 3)
    }
  ' "$FINAL_REVIEW_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families final_review_verified upstream_real_external_benchmark_verified final_review_action final_review_routing final_review_jump <<<"$FINAL_REVIEW_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV:-}" ]]; then
  RESULT_AUTHORITY_CSV="$V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV"
  RESULT_AUTHORITY_SOURCE="provided-csv"
  if [[ ! -s "$RESULT_AUTHORITY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_result_authority_header >"$RESULT_AUTHORITY_CSV"
fi

declare -A expected_result_uri
declare -A expected_provenance_hash
declare -A expected_evaluator_output_hash
declare -A expected_run_log_hash
declare -A expected_metric_value

evidence_rows_seen=0
EVIDENCE_TSV="$TMP_DIR/external_benchmark_evidence.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family result_uri provenance_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-x evidence column: " required[i], 10)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-x evidence row has wrong column count", 11)
    printf "%s\t%s\t%s\n",
      $idx["benchmark_family"],
      $idx["result_uri"],
      $idx["provenance_hash"]
  }
' "$EVIDENCE_CSV" >"$EVIDENCE_TSV"

while IFS=$'\t' read -r benchmark_family result_uri provenance_hash; do
  if [[ -n "${expected_result_uri[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-x evidence family: $benchmark_family" >&2
    exit 12
  fi
  expected_result_uri["$benchmark_family"]="$result_uri"
  expected_provenance_hash["$benchmark_family"]="$provenance_hash"
  ((evidence_rows_seen += 1))
done <"$EVIDENCE_TSV"

execution_rows_seen=0
EXECUTION_TSV="$TMP_DIR/external_benchmark_execution.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family evaluator_output_hash run_log_hash metric_value", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-x execution column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-x execution row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\n",
      $idx["benchmark_family"],
      $idx["evaluator_output_hash"],
      $idx["run_log_hash"],
      $idx["metric_value"]
  }
' "$EXECUTION_CSV" >"$EXECUTION_TSV"

while IFS=$'\t' read -r benchmark_family evaluator_output_hash run_log_hash metric_value; do
  if [[ -n "${expected_evaluator_output_hash[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-x execution family: $benchmark_family" >&2
    exit 15
  fi
  expected_evaluator_output_hash["$benchmark_family"]="$evaluator_output_hash"
  expected_run_log_hash["$benchmark_family"]="$run_log_hash"
  expected_metric_value["$benchmark_family"]="$metric_value"
  ((execution_rows_seen += 1))
done <"$EXECUTION_TSV"

result_authority_rows=0
matched_evidence_rows=0
matched_execution_rows=0
result_uri_match_rows=0
provenance_hash_match_rows=0
evaluator_output_hash_match_rows=0
run_log_hash_match_rows=0
metric_value_match_rows=0
result_authority_artifact_rows=0
nonplaceholder_result_authority_artifact_rows=0
result_authority_hash_attestation_rows=0
result_authority_domain_match_rows=0
official_leaderboard_rows=0
official_metric_rows=0
independent_result_review_rows=0
live_result_observed_rows=0
declared_real_result_rows=0
non_fixture_declared_rows=0
result_authority_routing="0.000000"
result_authority_jump="0.000000"
declare -A result_authority_seen

RESULT_AUTHORITY_TSV="$TMP_DIR/external_benchmark_result_authority.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family benchmark_result_id official_result_authority_id official_result_authority_domain leaderboard_uri leaderboard_hash result_record_uri result_record_hash result_artifact_uri result_artifact_hash metric_definition_uri metric_definition_hash evaluation_protocol_uri evaluation_protocol_hash submitter_identity_uri submitter_identity_hash authority_review_uri authority_review_hash reviewed_result_uri reviewed_provenance_hash reviewed_evaluator_output_hash reviewed_run_log_hash reviewed_metric_value official_leaderboard_declared official_metric_declared independent_result_review live_result_observed real_result_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-x result authority column: " required[i], 16)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-x result authority row has wrong column count", 17)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
      $idx["benchmark_family"],
      $idx["benchmark_result_id"],
      $idx["official_result_authority_id"],
      $idx["official_result_authority_domain"],
      $idx["leaderboard_uri"],
      $idx["leaderboard_hash"],
      $idx["result_record_uri"],
      $idx["result_record_hash"],
      $idx["result_artifact_uri"],
      $idx["result_artifact_hash"],
      $idx["metric_definition_uri"],
      $idx["metric_definition_hash"],
      $idx["evaluation_protocol_uri"],
      $idx["evaluation_protocol_hash"],
      $idx["submitter_identity_uri"],
      $idx["submitter_identity_hash"],
      $idx["authority_review_uri"],
      $idx["authority_review_hash"],
      $idx["reviewed_result_uri"],
      $idx["reviewed_provenance_hash"],
      $idx["reviewed_evaluator_output_hash"],
      $idx["reviewed_run_log_hash"],
      $idx["reviewed_metric_value"],
      $idx["official_leaderboard_declared"] + 0,
      $idx["official_metric_declared"] + 0,
      $idx["independent_result_review"] + 0,
      $idx["live_result_observed"] + 0,
      $idx["real_result_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["hash_attestation_ready"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0
  }
' "$RESULT_AUTHORITY_CSV" >"$RESULT_AUTHORITY_TSV"

while IFS=$'\t' read -r benchmark_family benchmark_result_id official_result_authority_id official_result_authority_domain leaderboard_uri leaderboard_hash result_record_uri result_record_hash result_artifact_uri result_artifact_hash metric_definition_uri metric_definition_hash evaluation_protocol_uri evaluation_protocol_hash submitter_identity_uri submitter_identity_hash authority_review_uri authority_review_hash reviewed_result_uri reviewed_provenance_hash reviewed_evaluator_output_hash reviewed_run_log_hash reviewed_metric_value official_leaderboard_declared official_metric_declared independent_result_review live_result_observed real_result_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate; do
  ((result_authority_rows += 1))
  if [[ -n "${result_authority_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-x result authority family: $benchmark_family" >&2
    exit 18
  fi
  result_authority_seen["$benchmark_family"]=1

  if [[ -n "${expected_result_uri[$benchmark_family]:-}" ]]; then
    ((matched_evidence_rows += 1))
  fi
  if [[ -n "${expected_evaluator_output_hash[$benchmark_family]:-}" ]]; then
    ((matched_execution_rows += 1))
  fi
  if [[ "${expected_result_uri[$benchmark_family]:-}" == "$reviewed_result_uri" ]] && is_present "$reviewed_result_uri"; then
    ((result_uri_match_rows += 1))
  fi
  if [[ "${expected_provenance_hash[$benchmark_family]:-}" == "$reviewed_provenance_hash" ]] && is_sha256 "$reviewed_provenance_hash"; then
    ((provenance_hash_match_rows += 1))
  fi
  if [[ "${expected_evaluator_output_hash[$benchmark_family]:-}" == "$reviewed_evaluator_output_hash" ]] && is_sha256 "$reviewed_evaluator_output_hash"; then
    ((evaluator_output_hash_match_rows += 1))
  fi
  if [[ "${expected_run_log_hash[$benchmark_family]:-}" == "$reviewed_run_log_hash" ]] && is_sha256 "$reviewed_run_log_hash"; then
    ((run_log_hash_match_rows += 1))
  fi
  if [[ "${expected_metric_value[$benchmark_family]:-}" == "$reviewed_metric_value" ]] && is_present "$reviewed_metric_value"; then
    ((metric_value_match_rows += 1))
  fi

  if is_present "$benchmark_result_id" &&
      is_present "$official_result_authority_id" &&
      is_present "$official_result_authority_domain" &&
      is_https_uri "$leaderboard_uri" &&
      is_https_uri "$result_record_uri" &&
      is_https_uri "$result_artifact_uri" &&
      is_https_uri "$metric_definition_uri" &&
      is_https_uri "$evaluation_protocol_uri" &&
      is_https_uri "$submitter_identity_uri" &&
      is_https_uri "$authority_review_uri" &&
      is_sha256 "$leaderboard_hash" &&
      is_sha256 "$result_record_hash" &&
      is_sha256 "$result_artifact_hash" &&
      is_sha256 "$metric_definition_hash" &&
      is_sha256 "$evaluation_protocol_hash" &&
      is_sha256 "$submitter_identity_hash" &&
      is_sha256 "$authority_review_hash"; then
    ((result_authority_artifact_rows += 1))
  fi
  if ! is_placeholder_domain "$official_result_authority_domain" &&
      is_nonplaceholder_https_uri "$leaderboard_uri" &&
      is_nonplaceholder_https_uri "$result_record_uri" &&
      is_nonplaceholder_https_uri "$result_artifact_uri" &&
      is_nonplaceholder_https_uri "$metric_definition_uri" &&
      is_nonplaceholder_https_uri "$evaluation_protocol_uri" &&
      is_nonplaceholder_https_uri "$submitter_identity_uri" &&
      is_nonplaceholder_https_uri "$authority_review_uri"; then
    ((nonplaceholder_result_authority_artifact_rows += 1))
  fi
  if [[ "$hash_attestation_ready" == "1" ]]; then
    ((result_authority_hash_attestation_rows += 1))
  fi
  if host_matches_domain "$leaderboard_uri" "$official_result_authority_domain" &&
      host_matches_domain "$result_record_uri" "$official_result_authority_domain" &&
      host_matches_domain "$result_artifact_uri" "$official_result_authority_domain" &&
      host_matches_domain "$metric_definition_uri" "$official_result_authority_domain" &&
      host_matches_domain "$evaluation_protocol_uri" "$official_result_authority_domain" &&
      host_matches_domain "$submitter_identity_uri" "$official_result_authority_domain" &&
      host_matches_domain "$authority_review_uri" "$official_result_authority_domain"; then
    ((result_authority_domain_match_rows += 1))
  fi
  if [[ "$official_leaderboard_declared" == "1" ]]; then
    ((official_leaderboard_rows += 1))
  fi
  if [[ "$official_metric_declared" == "1" ]]; then
    ((official_metric_rows += 1))
  fi
  if [[ "$independent_result_review" == "1" ]]; then
    ((independent_result_review_rows += 1))
  fi
  if [[ "$live_result_observed" == "1" ]]; then
    ((live_result_observed_rows += 1))
  fi
  if [[ "$real_result_declared" == "1" ]]; then
    ((declared_real_result_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  result_authority_routing="$(awk -v a="$result_authority_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  result_authority_jump="$(awk -v a="$result_authority_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$RESULT_AUTHORITY_TSV"

expected_result_authority_rows="$benchmark_families"

external_benchmark_result_authority_review_ready=0
if [[ "$final_review_verified" == "1" &&
      "$expected_result_authority_rows" -gt 0 &&
      "$evidence_rows_seen" -eq "$expected_result_authority_rows" &&
      "$execution_rows_seen" -eq "$expected_result_authority_rows" &&
      "$result_authority_rows" -eq "$expected_result_authority_rows" &&
      "$matched_evidence_rows" -eq "$expected_result_authority_rows" &&
      "$matched_execution_rows" -eq "$expected_result_authority_rows" &&
      "$result_uri_match_rows" -eq "$expected_result_authority_rows" &&
      "$provenance_hash_match_rows" -eq "$expected_result_authority_rows" &&
      "$evaluator_output_hash_match_rows" -eq "$expected_result_authority_rows" &&
      "$run_log_hash_match_rows" -eq "$expected_result_authority_rows" &&
      "$metric_value_match_rows" -eq "$expected_result_authority_rows" &&
      "$result_authority_artifact_rows" -eq "$expected_result_authority_rows" &&
      "$result_authority_hash_attestation_rows" -eq "$expected_result_authority_rows" &&
      "$result_authority_domain_match_rows" -eq "$expected_result_authority_rows" &&
      "$final_review_routing" == "0.000000" &&
      "$final_review_jump" == "0.000000" &&
      "$result_authority_routing" == "0.000000" &&
      "$result_authority_jump" == "0.000000" ]]; then
  external_benchmark_result_authority_review_ready=1
fi

external_benchmark_result_authority_ready=0
if [[ "$external_benchmark_result_authority_review_ready" == "1" &&
      "$nonplaceholder_result_authority_artifact_rows" -eq "$expected_result_authority_rows" &&
      "$official_leaderboard_rows" -eq "$expected_result_authority_rows" &&
      "$official_metric_rows" -eq "$expected_result_authority_rows" &&
      "$independent_result_review_rows" -eq "$expected_result_authority_rows" &&
      "$live_result_observed_rows" -eq "$expected_result_authority_rows" &&
      "$declared_real_result_rows" -eq "$expected_result_authority_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_result_authority_rows" ]]; then
  external_benchmark_result_authority_ready=1
fi

real_external_benchmark_verified=0
if [[ "$final_review_verified" == "1" &&
      "$external_benchmark_result_authority_ready" == "1" ]]; then
  real_external_benchmark_verified=1
fi

action="$final_review_action"
if [[ "$final_review_verified" == "1" ]]; then
  if [[ "$result_authority_rows" -eq 0 ]]; then
    action="external-benchmark-result-authority-missing"
  elif [[ "$result_authority_rows" -ne "$expected_result_authority_rows" ||
          "$matched_evidence_rows" -ne "$expected_result_authority_rows" ||
          "$matched_execution_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-row-mismatch"
  elif [[ "$result_uri_match_rows" -ne "$expected_result_authority_rows" ||
          "$provenance_hash_match_rows" -ne "$expected_result_authority_rows" ||
          "$evaluator_output_hash_match_rows" -ne "$expected_result_authority_rows" ||
          "$run_log_hash_match_rows" -ne "$expected_result_authority_rows" ||
          "$metric_value_match_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-result-mismatch"
  elif [[ "$result_authority_artifact_rows" -ne "$expected_result_authority_rows" ||
          "$result_authority_hash_attestation_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-artifact-missing"
  elif [[ "$result_authority_domain_match_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-domain-mismatch"
  elif [[ "$nonplaceholder_result_authority_artifact_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-placeholder-domain"
  elif [[ "$official_leaderboard_rows" -ne "$expected_result_authority_rows" ||
          "$official_metric_rows" -ne "$expected_result_authority_rows" ||
          "$independent_result_review_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-trust-root-missing"
  elif [[ "$live_result_observed_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-live-observation-missing"
  elif [[ "$declared_real_result_rows" -ne "$expected_result_authority_rows" ||
          "$non_fixture_declared_rows" -ne "$expected_result_authority_rows" ]]; then
    action="external-benchmark-result-authority-fixture-only"
  elif [[ "$real_external_benchmark_verified" == "1" ]]; then
    action="external-benchmark-result-authority-verified"
  fi
fi

total_routing="$(awk -v a="$final_review_routing" -v b="$result_authority_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$final_review_jump" -v b="$result_authority_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,final_review_verified,upstream_real_external_benchmark_verified,external_benchmark_result_authority_source,expected_result_authority_rows,result_authority_rows,matched_evidence_rows,matched_execution_rows,result_uri_match_rows,provenance_hash_match_rows,evaluator_output_hash_match_rows,run_log_hash_match_rows,metric_value_match_rows,result_authority_artifact_rows,nonplaceholder_result_authority_artifact_rows,result_authority_hash_attestation_rows,result_authority_domain_match_rows,official_leaderboard_rows,official_metric_rows,independent_result_review_rows,live_result_observed_rows,declared_real_result_rows,non_fixture_declared_rows,external_benchmark_result_authority_review_ready,external_benchmark_result_authority_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  join_by_comma \
    route-memory-v08x \
    "$benchmark_families" \
    "$final_review_verified" \
    "$upstream_real_external_benchmark_verified" \
    "$RESULT_AUTHORITY_SOURCE" \
    "$expected_result_authority_rows" \
    "$result_authority_rows" \
    "$matched_evidence_rows" \
    "$matched_execution_rows" \
    "$result_uri_match_rows" \
    "$provenance_hash_match_rows" \
    "$evaluator_output_hash_match_rows" \
    "$run_log_hash_match_rows" \
    "$metric_value_match_rows" \
    "$result_authority_artifact_rows" \
    "$nonplaceholder_result_authority_artifact_rows" \
    "$result_authority_hash_attestation_rows" \
    "$result_authority_domain_match_rows" \
    "$official_leaderboard_rows" \
    "$official_metric_rows" \
    "$independent_result_review_rows" \
    "$live_result_observed_rows" \
    "$declared_real_result_rows" \
    "$non_fixture_declared_rows" \
    "$external_benchmark_result_authority_review_ready" \
    "$external_benchmark_result_authority_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "final-review,%s,final_review_verified=%d upstream_real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$final_review_verified" == "1" ]] && echo pass || echo blocked)" \
    "$final_review_verified" \
    "$upstream_real_external_benchmark_verified" \
    "$final_review_action"
  printf "result-authority-rows,%s,rows=%d expected=%d evidence=%d execution=%d\n" \
    "$([[ "$result_authority_rows" -eq "$expected_result_authority_rows" && "$matched_evidence_rows" -eq "$expected_result_authority_rows" && "$matched_execution_rows" -eq "$expected_result_authority_rows" && "$expected_result_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$result_authority_rows" \
    "$expected_result_authority_rows" \
    "$matched_evidence_rows" \
    "$matched_execution_rows"
  printf "result-authority-result-binding,%s,result_uri=%d/%d provenance=%d/%d evaluator_output=%d/%d run_log=%d/%d metric=%d/%d\n" \
    "$([[ "$result_uri_match_rows" -eq "$expected_result_authority_rows" && "$provenance_hash_match_rows" -eq "$expected_result_authority_rows" && "$evaluator_output_hash_match_rows" -eq "$expected_result_authority_rows" && "$run_log_hash_match_rows" -eq "$expected_result_authority_rows" && "$metric_value_match_rows" -eq "$expected_result_authority_rows" && "$expected_result_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$result_uri_match_rows" \
    "$expected_result_authority_rows" \
    "$provenance_hash_match_rows" \
    "$expected_result_authority_rows" \
    "$evaluator_output_hash_match_rows" \
    "$expected_result_authority_rows" \
    "$run_log_hash_match_rows" \
    "$expected_result_authority_rows" \
    "$metric_value_match_rows" \
    "$expected_result_authority_rows"
  printf "result-authority-artifacts,%s,metadata=%d/%d hash_attestation=%d/%d nonplaceholder=%d/%d domain_match=%d/%d source=%s\n" \
    "$([[ "$result_authority_artifact_rows" -eq "$expected_result_authority_rows" && "$result_authority_hash_attestation_rows" -eq "$expected_result_authority_rows" && "$nonplaceholder_result_authority_artifact_rows" -eq "$expected_result_authority_rows" && "$result_authority_domain_match_rows" -eq "$expected_result_authority_rows" && "$expected_result_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$result_authority_artifact_rows" \
    "$expected_result_authority_rows" \
    "$result_authority_hash_attestation_rows" \
    "$expected_result_authority_rows" \
    "$nonplaceholder_result_authority_artifact_rows" \
    "$expected_result_authority_rows" \
    "$result_authority_domain_match_rows" \
    "$expected_result_authority_rows" \
    "$RESULT_AUTHORITY_SOURCE"
  printf "result-authority-trust-root,%s,leaderboard=%d/%d metric=%d/%d independent=%d/%d live=%d/%d real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$official_leaderboard_rows" -eq "$expected_result_authority_rows" && "$official_metric_rows" -eq "$expected_result_authority_rows" && "$independent_result_review_rows" -eq "$expected_result_authority_rows" && "$live_result_observed_rows" -eq "$expected_result_authority_rows" && "$declared_real_result_rows" -eq "$expected_result_authority_rows" && "$non_fixture_declared_rows" -eq "$expected_result_authority_rows" && "$expected_result_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$official_leaderboard_rows" \
    "$expected_result_authority_rows" \
    "$official_metric_rows" \
    "$expected_result_authority_rows" \
    "$independent_result_review_rows" \
    "$expected_result_authority_rows" \
    "$live_result_observed_rows" \
    "$expected_result_authority_rows" \
    "$declared_real_result_rows" \
    "$expected_result_authority_rows" \
    "$non_fixture_declared_rows" \
    "$expected_result_authority_rows"
  printf "external-benchmark-result-authority,%s,review_ready=%d ready=%d action=%s\n" \
    "$([[ "$external_benchmark_result_authority_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_result_authority_review_ready" \
    "$external_benchmark_result_authority_ready" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
