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

PREFIX="v08_external_benchmark_publication_gate"
RESULT_AUTHORITY_PREFIX="v08_external_benchmark_result_authority_gate"
COMPARISON_PREFIX="v08_external_benchmark_comparison_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_publication_gate_smoke"
  RESULT_AUTHORITY_PREFIX="v08_external_benchmark_result_authority_gate_smoke"
  COMPARISON_PREFIX="v08_external_benchmark_comparison_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_result_authority_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_comparison_gate.sh" "${RUN_ARGS[@]}" >/dev/null

RESULT_AUTHORITY_SUMMARY_CSV="$RESULTS_DIR/${RESULT_AUTHORITY_PREFIX}_summary.csv"
RESULT_AUTHORITY_CSV="${V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV:-$RESULTS_DIR/${RESULT_AUTHORITY_PREFIX}_result_authority.csv}"
COMPARISON_SUMMARY_CSV="${V08_EXTERNAL_BENCHMARK_COMPARISON_SUMMARY_CSV:-$RESULTS_DIR/${COMPARISON_PREFIX}_summary.csv}"
COMPARISON_CSV="${V08_EXTERNAL_BENCHMARK_COMPARISON_CSV:-$RESULTS_DIR/${COMPARISON_PREFIX}_comparison.csv}"
PUBLICATION_CSV="$RESULTS_DIR/${PREFIX}_publication.csv"
PUBLICATION_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_publication_header() {
  echo "benchmark_family,publication_package_id,publication_authority_domain,publication_uri,publication_hash,report_uri,report_hash,comparison_table_uri,comparison_table_hash,reproducibility_bundle_uri,reproducibility_bundle_hash,release_license_uri,release_license_hash,conflict_disclosure_uri,conflict_disclosure_hash,publication_review_uri,publication_review_hash,published_leaderboard_uri,published_leaderboard_hash,published_result_record_uri,published_result_record_hash,published_metric_definition_uri,published_metric_definition_hash,published_evaluation_protocol_uri,published_evaluation_protocol_hash,published_comparison_delta,published_comparison_verdict,independent_publication_review,live_publication_observed,real_publication_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
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

if [[ -n "${V08_EXTERNAL_BENCHMARK_PUBLICATION_CSV:-}" ]]; then
  PUBLICATION_CSV="$V08_EXTERNAL_BENCHMARK_PUBLICATION_CSV"
  PUBLICATION_SOURCE="provided-csv"
  if [[ ! -s "$PUBLICATION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_PUBLICATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_publication_header >"$PUBLICATION_CSV"
fi

RESULT_AUTHORITY_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families external_benchmark_result_authority_review_ready external_benchmark_result_authority_ready real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-y result-authority summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["external_benchmark_result_authority_review_ready"] + 0,
        $idx["external_benchmark_result_authority_ready"] + 0,
        $idx["real_external_benchmark_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-y result-authority summary row", 3)
    }
  ' "$RESULT_AUTHORITY_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families result_authority_review_ready result_authority_ready upstream_real_external_benchmark_verified result_authority_action result_authority_routing result_authority_jump <<<"$RESULT_AUTHORITY_VALUES"

COMPARISON_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_comparison_ready publishable_comparison_ready default_promotion real_external_benchmark_verified comparable_rows action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-y comparison summary column: " required[i], 4)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_comparison_ready"] + 0,
        $idx["publishable_comparison_ready"] + 0,
        $idx["default_promotion"] + 0,
        $idx["real_external_benchmark_verified"] + 0,
        $idx["comparable_rows"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-y comparison summary row", 5)
    }
  ' "$COMPARISON_SUMMARY_CSV"
)"

IFS=, read -r benchmark_comparison_ready publishable_comparison_ready default_promotion comparison_real_external_benchmark_verified comparable_rows comparison_action comparison_routing comparison_jump <<<"$COMPARISON_VALUES"

declare -A expected_leaderboard_uri
declare -A expected_leaderboard_hash
declare -A expected_result_record_uri
declare -A expected_result_record_hash
declare -A expected_metric_definition_uri
declare -A expected_metric_definition_hash
declare -A expected_evaluation_protocol_uri
declare -A expected_evaluation_protocol_hash
result_authority_rows_seen=0

RESULT_AUTHORITY_TSV="$TMP_DIR/external_benchmark_result_authority.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family leaderboard_uri leaderboard_hash result_record_uri result_record_hash metric_definition_uri metric_definition_hash evaluation_protocol_uri evaluation_protocol_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-y result-authority column: " required[i], 10)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-y result-authority row has wrong column count", 11)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
      $idx["benchmark_family"],
      $idx["leaderboard_uri"],
      $idx["leaderboard_hash"],
      $idx["result_record_uri"],
      $idx["result_record_hash"],
      $idx["metric_definition_uri"],
      $idx["metric_definition_hash"],
      $idx["evaluation_protocol_uri"],
      $idx["evaluation_protocol_hash"]
  }
' "$RESULT_AUTHORITY_CSV" >"$RESULT_AUTHORITY_TSV"

while IFS=$'\t' read -r benchmark_family leaderboard_uri leaderboard_hash result_record_uri result_record_hash metric_definition_uri metric_definition_hash evaluation_protocol_uri evaluation_protocol_hash; do
  if [[ -n "${expected_leaderboard_uri[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-y result-authority family: $benchmark_family" >&2
    exit 12
  fi
  expected_leaderboard_uri["$benchmark_family"]="$leaderboard_uri"
  expected_leaderboard_hash["$benchmark_family"]="$leaderboard_hash"
  expected_result_record_uri["$benchmark_family"]="$result_record_uri"
  expected_result_record_hash["$benchmark_family"]="$result_record_hash"
  expected_metric_definition_uri["$benchmark_family"]="$metric_definition_uri"
  expected_metric_definition_hash["$benchmark_family"]="$metric_definition_hash"
  expected_evaluation_protocol_uri["$benchmark_family"]="$evaluation_protocol_uri"
  expected_evaluation_protocol_hash["$benchmark_family"]="$evaluation_protocol_hash"
  ((result_authority_rows_seen += 1))
done <"$RESULT_AUTHORITY_TSV"

declare -A expected_comparison_delta
declare -A expected_comparison_verdict
comparison_rows_seen=0

COMPARISON_TSV="$TMP_DIR/external_benchmark_comparison.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family delta verdict", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-y comparison column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-y comparison row has wrong column count", 14)
    printf "%s\t%s\t%s\n",
      $idx["benchmark_family"],
      $idx["delta"],
      $idx["verdict"]
  }
' "$COMPARISON_CSV" >"$COMPARISON_TSV"

while IFS=$'\t' read -r benchmark_family delta verdict; do
  if [[ -n "${expected_comparison_delta[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-y comparison family: $benchmark_family" >&2
    exit 15
  fi
  expected_comparison_delta["$benchmark_family"]="$delta"
  expected_comparison_verdict["$benchmark_family"]="$verdict"
  ((comparison_rows_seen += 1))
done <"$COMPARISON_TSV"

publication_rows=0
matched_result_authority_rows=0
matched_comparison_rows=0
leaderboard_match_rows=0
result_record_match_rows=0
metric_definition_match_rows=0
evaluation_protocol_match_rows=0
comparison_delta_match_rows=0
comparison_verdict_match_rows=0
publication_artifact_rows=0
nonplaceholder_publication_artifact_rows=0
publication_hash_attestation_rows=0
publication_domain_match_rows=0
reproducibility_bundle_rows=0
independent_publication_review_rows=0
live_publication_observed_rows=0
declared_real_publication_rows=0
non_fixture_declared_rows=0
publication_routing="0.000000"
publication_jump="0.000000"
declare -A publication_seen

PUBLICATION_TSV="$TMP_DIR/external_benchmark_publication.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family publication_package_id publication_authority_domain publication_uri publication_hash report_uri report_hash comparison_table_uri comparison_table_hash reproducibility_bundle_uri reproducibility_bundle_hash release_license_uri release_license_hash conflict_disclosure_uri conflict_disclosure_hash publication_review_uri publication_review_hash published_leaderboard_uri published_leaderboard_hash published_result_record_uri published_result_record_hash published_metric_definition_uri published_metric_definition_hash published_evaluation_protocol_uri published_evaluation_protocol_hash published_comparison_delta published_comparison_verdict independent_publication_review live_publication_observed real_publication_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-y publication column: " required[i], 16)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-y publication row has wrong column count", 17)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$PUBLICATION_CSV" >"$PUBLICATION_TSV"

while IFS=$'\t' read -r benchmark_family publication_package_id publication_authority_domain publication_uri publication_hash report_uri report_hash comparison_table_uri comparison_table_hash reproducibility_bundle_uri reproducibility_bundle_hash release_license_uri release_license_hash conflict_disclosure_uri conflict_disclosure_hash publication_review_uri publication_review_hash published_leaderboard_uri published_leaderboard_hash published_result_record_uri published_result_record_hash published_metric_definition_uri published_metric_definition_hash published_evaluation_protocol_uri published_evaluation_protocol_hash published_comparison_delta published_comparison_verdict independent_publication_review live_publication_observed real_publication_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate; do
  ((publication_rows += 1))
  if [[ -n "${publication_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-y publication family: $benchmark_family" >&2
    exit 18
  fi
  publication_seen["$benchmark_family"]=1

  if [[ -n "${expected_leaderboard_uri[$benchmark_family]:-}" ]]; then
    ((matched_result_authority_rows += 1))
    if [[ "$published_leaderboard_uri" == "${expected_leaderboard_uri[$benchmark_family]}" &&
          "$published_leaderboard_hash" == "${expected_leaderboard_hash[$benchmark_family]}" ]]; then
      ((leaderboard_match_rows += 1))
    fi
    if [[ "$published_result_record_uri" == "${expected_result_record_uri[$benchmark_family]}" &&
          "$published_result_record_hash" == "${expected_result_record_hash[$benchmark_family]}" ]]; then
      ((result_record_match_rows += 1))
    fi
    if [[ "$published_metric_definition_uri" == "${expected_metric_definition_uri[$benchmark_family]}" &&
          "$published_metric_definition_hash" == "${expected_metric_definition_hash[$benchmark_family]}" ]]; then
      ((metric_definition_match_rows += 1))
    fi
    if [[ "$published_evaluation_protocol_uri" == "${expected_evaluation_protocol_uri[$benchmark_family]}" &&
          "$published_evaluation_protocol_hash" == "${expected_evaluation_protocol_hash[$benchmark_family]}" ]]; then
      ((evaluation_protocol_match_rows += 1))
    fi
  fi

  if [[ -n "${expected_comparison_delta[$benchmark_family]:-}" &&
        "${expected_comparison_delta[$benchmark_family]}" != "NA" ]]; then
    ((matched_comparison_rows += 1))
    if [[ "$published_comparison_delta" == "${expected_comparison_delta[$benchmark_family]}" ]]; then
      ((comparison_delta_match_rows += 1))
    fi
    if [[ "$published_comparison_verdict" == "${expected_comparison_verdict[$benchmark_family]}" ]]; then
      ((comparison_verdict_match_rows += 1))
    fi
  fi

  if is_present "$publication_package_id" &&
      is_present "$publication_authority_domain" &&
      is_present "$publication_uri" &&
      is_present "$publication_hash" &&
      is_present "$report_uri" &&
      is_present "$report_hash" &&
      is_present "$comparison_table_uri" &&
      is_present "$comparison_table_hash" &&
      is_present "$reproducibility_bundle_uri" &&
      is_present "$reproducibility_bundle_hash" &&
      is_present "$release_license_uri" &&
      is_present "$release_license_hash" &&
      is_present "$conflict_disclosure_uri" &&
      is_present "$conflict_disclosure_hash" &&
      is_present "$publication_review_uri" &&
      is_present "$publication_review_hash"; then
    ((publication_artifact_rows += 1))
  fi
  if ! is_placeholder_domain "$publication_authority_domain" &&
      is_nonplaceholder_https_uri "$publication_uri" &&
      is_nonplaceholder_https_uri "$report_uri" &&
      is_nonplaceholder_https_uri "$comparison_table_uri" &&
      is_nonplaceholder_https_uri "$reproducibility_bundle_uri" &&
      is_nonplaceholder_https_uri "$release_license_uri" &&
      is_nonplaceholder_https_uri "$conflict_disclosure_uri" &&
      is_nonplaceholder_https_uri "$publication_review_uri"; then
    ((nonplaceholder_publication_artifact_rows += 1))
  fi
  if is_sha256 "$publication_hash" &&
      is_sha256 "$report_hash" &&
      is_sha256 "$comparison_table_hash" &&
      is_sha256 "$reproducibility_bundle_hash" &&
      is_sha256 "$release_license_hash" &&
      is_sha256 "$conflict_disclosure_hash" &&
      is_sha256 "$publication_review_hash" &&
      [[ "$hash_attestation_ready" == "1" ]]; then
    ((publication_hash_attestation_rows += 1))
  fi
  if host_matches_domain "$publication_uri" "$publication_authority_domain" &&
      host_matches_domain "$report_uri" "$publication_authority_domain" &&
      host_matches_domain "$comparison_table_uri" "$publication_authority_domain" &&
      host_matches_domain "$reproducibility_bundle_uri" "$publication_authority_domain" &&
      host_matches_domain "$release_license_uri" "$publication_authority_domain" &&
      host_matches_domain "$conflict_disclosure_uri" "$publication_authority_domain" &&
      host_matches_domain "$publication_review_uri" "$publication_authority_domain"; then
    ((publication_domain_match_rows += 1))
  fi
  if is_present "$reproducibility_bundle_uri" && is_sha256 "$reproducibility_bundle_hash"; then
    ((reproducibility_bundle_rows += 1))
  fi
  if [[ "$independent_publication_review" == "1" ]]; then
    ((independent_publication_review_rows += 1))
  fi
  if [[ "$live_publication_observed" == "1" ]]; then
    ((live_publication_observed_rows += 1))
  fi
  if [[ "$real_publication_declared" == "1" ]]; then
    ((declared_real_publication_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi
  publication_routing="$(awk -v a="$publication_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  publication_jump="$(awk -v a="$publication_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$PUBLICATION_TSV"

expected_publication_rows="$benchmark_families"
external_benchmark_publication_review_ready=0
if [[ "$result_authority_review_ready" == "1" &&
      "$result_authority_ready" == "1" &&
      "$upstream_real_external_benchmark_verified" == "1" &&
      "$comparison_real_external_benchmark_verified" == "1" &&
      "$benchmark_comparison_ready" == "1" &&
      "$expected_publication_rows" -gt 0 &&
      "$result_authority_rows_seen" -eq "$expected_publication_rows" &&
      "$comparison_rows_seen" -eq "$expected_publication_rows" &&
      "$comparable_rows" -eq "$expected_publication_rows" &&
      "$publication_rows" -eq "$expected_publication_rows" &&
      "$matched_result_authority_rows" -eq "$expected_publication_rows" &&
      "$matched_comparison_rows" -eq "$expected_publication_rows" &&
      "$leaderboard_match_rows" -eq "$expected_publication_rows" &&
      "$result_record_match_rows" -eq "$expected_publication_rows" &&
      "$metric_definition_match_rows" -eq "$expected_publication_rows" &&
      "$evaluation_protocol_match_rows" -eq "$expected_publication_rows" &&
      "$comparison_delta_match_rows" -eq "$expected_publication_rows" &&
      "$comparison_verdict_match_rows" -eq "$expected_publication_rows" &&
      "$publication_artifact_rows" -eq "$expected_publication_rows" &&
      "$publication_hash_attestation_rows" -eq "$expected_publication_rows" &&
      "$publication_domain_match_rows" -eq "$expected_publication_rows" &&
      "$result_authority_routing" == "0.000000" &&
      "$result_authority_jump" == "0.000000" &&
      "$comparison_routing" == "0.000000" &&
      "$comparison_jump" == "0.000000" &&
      "$publication_routing" == "0.000000" &&
      "$publication_jump" == "0.000000" ]]; then
  external_benchmark_publication_review_ready=1
fi

external_benchmark_publication_ready=0
if [[ "$external_benchmark_publication_review_ready" == "1" &&
      "$publishable_comparison_ready" == "1" &&
      "$nonplaceholder_publication_artifact_rows" -eq "$expected_publication_rows" &&
      "$reproducibility_bundle_rows" -eq "$expected_publication_rows" &&
      "$independent_publication_review_rows" -eq "$expected_publication_rows" &&
      "$live_publication_observed_rows" -eq "$expected_publication_rows" &&
      "$declared_real_publication_rows" -eq "$expected_publication_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_publication_rows" ]]; then
  external_benchmark_publication_ready=1
fi

real_external_benchmark_verified=0
if [[ "$external_benchmark_publication_ready" == "1" ]]; then
  real_external_benchmark_verified=1
fi

action="external-benchmark-publication-upstream-missing"
if [[ "$result_authority_ready" != "1" || "$upstream_real_external_benchmark_verified" != "1" ]]; then
  action="external-benchmark-publication-upstream-missing"
elif [[ "$publication_rows" -eq 0 ]]; then
  action="external-benchmark-publication-missing"
elif [[ "$publication_rows" -ne "$expected_publication_rows" ||
        "$matched_result_authority_rows" -ne "$expected_publication_rows" ||
        "$matched_comparison_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-row-mismatch"
elif [[ "$leaderboard_match_rows" -ne "$expected_publication_rows" ||
        "$result_record_match_rows" -ne "$expected_publication_rows" ||
        "$metric_definition_match_rows" -ne "$expected_publication_rows" ||
        "$evaluation_protocol_match_rows" -ne "$expected_publication_rows" ||
        "$comparison_delta_match_rows" -ne "$expected_publication_rows" ||
        "$comparison_verdict_match_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-binding-mismatch"
elif [[ "$publication_artifact_rows" -ne "$expected_publication_rows" ||
        "$publication_hash_attestation_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-artifact-missing"
elif [[ "$publication_domain_match_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-domain-mismatch"
elif [[ "$nonplaceholder_publication_artifact_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-placeholder-domain"
elif [[ "$reproducibility_bundle_rows" -ne "$expected_publication_rows" ||
        "$independent_publication_review_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-review-missing"
elif [[ "$live_publication_observed_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-live-observation-missing"
elif [[ "$declared_real_publication_rows" -ne "$expected_publication_rows" ||
        "$non_fixture_declared_rows" -ne "$expected_publication_rows" ]]; then
  action="external-benchmark-publication-fixture-only"
elif [[ "$publishable_comparison_ready" != "1" ]]; then
  action="external-benchmark-publication-comparison-not-publishable"
elif [[ "$real_external_benchmark_verified" == "1" ]]; then
  action="external-benchmark-publication-verified"
fi

total_routing="$(awk -v a="$result_authority_routing" -v b="$comparison_routing" -v c="$publication_routing" 'BEGIN { printf "%.6f", a + b + c }')"
total_jump="$(awk -v a="$result_authority_jump" -v b="$comparison_jump" -v c="$publication_jump" 'BEGIN { printf "%.6f", a + b + c }')"

{
  echo "benchmark_scope,benchmark_families,upstream_real_external_benchmark_verified,external_benchmark_publication_source,benchmark_comparison_ready,publishable_comparison_ready,default_promotion,expected_publication_rows,publication_rows,matched_result_authority_rows,matched_comparison_rows,leaderboard_match_rows,result_record_match_rows,metric_definition_match_rows,evaluation_protocol_match_rows,comparison_delta_match_rows,comparison_verdict_match_rows,publication_artifact_rows,nonplaceholder_publication_artifact_rows,publication_hash_attestation_rows,publication_domain_match_rows,reproducibility_bundle_rows,independent_publication_review_rows,live_publication_observed_rows,declared_real_publication_rows,non_fixture_declared_rows,external_benchmark_publication_review_ready,external_benchmark_publication_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08y,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$upstream_real_external_benchmark_verified" \
    "$PUBLICATION_SOURCE" \
    "$benchmark_comparison_ready" \
    "$publishable_comparison_ready" \
    "$default_promotion" \
    "$expected_publication_rows" \
    "$publication_rows" \
    "$matched_result_authority_rows" \
    "$matched_comparison_rows" \
    "$leaderboard_match_rows" \
    "$result_record_match_rows" \
    "$metric_definition_match_rows" \
    "$evaluation_protocol_match_rows" \
    "$comparison_delta_match_rows" \
    "$comparison_verdict_match_rows" \
    "$publication_artifact_rows" \
    "$nonplaceholder_publication_artifact_rows" \
    "$publication_hash_attestation_rows" \
    "$publication_domain_match_rows" \
    "$reproducibility_bundle_rows" \
    "$independent_publication_review_rows" \
    "$live_publication_observed_rows" \
    "$declared_real_publication_rows" \
    "$non_fixture_declared_rows" \
    "$external_benchmark_publication_review_ready" \
    "$external_benchmark_publication_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "result-authority,%s,upstream_real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$upstream_real_external_benchmark_verified" == "1" ]] && echo pass || echo blocked)" \
    "$upstream_real_external_benchmark_verified" \
    "$result_authority_action"
  printf "comparison,%s,benchmark_comparison_ready=%d publishable_comparison_ready=%d action=%s\n" \
    "$([[ "$benchmark_comparison_ready" == "1" ]] && echo pass || echo blocked)" \
    "$benchmark_comparison_ready" \
    "$publishable_comparison_ready" \
    "$comparison_action"
  printf "publication-rows,%s,publication_rows=%d expected=%d source=%s\n" \
    "$([[ "$publication_rows" -eq "$expected_publication_rows" && "$expected_publication_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$publication_rows" \
    "$expected_publication_rows" \
    "$PUBLICATION_SOURCE"
  printf "publication-binding,%s,result_authority=%d/%d comparison=%d/%d\n" \
    "$([[ "$leaderboard_match_rows" -eq "$expected_publication_rows" && "$result_record_match_rows" -eq "$expected_publication_rows" && "$metric_definition_match_rows" -eq "$expected_publication_rows" && "$evaluation_protocol_match_rows" -eq "$expected_publication_rows" && "$comparison_delta_match_rows" -eq "$expected_publication_rows" && "$comparison_verdict_match_rows" -eq "$expected_publication_rows" && "$expected_publication_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$matched_result_authority_rows" \
    "$expected_publication_rows" \
    "$matched_comparison_rows" \
    "$expected_publication_rows"
  printf "publication-artifacts,%s,artifacts=%d/%d hashes=%d/%d domain=%d/%d nonplaceholder=%d/%d\n" \
    "$([[ "$publication_artifact_rows" -eq "$expected_publication_rows" && "$publication_hash_attestation_rows" -eq "$expected_publication_rows" && "$publication_domain_match_rows" -eq "$expected_publication_rows" && "$nonplaceholder_publication_artifact_rows" -eq "$expected_publication_rows" && "$expected_publication_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$publication_artifact_rows" \
    "$expected_publication_rows" \
    "$publication_hash_attestation_rows" \
    "$expected_publication_rows" \
    "$publication_domain_match_rows" \
    "$expected_publication_rows" \
    "$nonplaceholder_publication_artifact_rows" \
    "$expected_publication_rows"
  printf "publication-review,%s,reproducibility=%d/%d independent=%d/%d live=%d/%d real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$reproducibility_bundle_rows" -eq "$expected_publication_rows" && "$independent_publication_review_rows" -eq "$expected_publication_rows" && "$live_publication_observed_rows" -eq "$expected_publication_rows" && "$declared_real_publication_rows" -eq "$expected_publication_rows" && "$non_fixture_declared_rows" -eq "$expected_publication_rows" && "$expected_publication_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$reproducibility_bundle_rows" \
    "$expected_publication_rows" \
    "$independent_publication_review_rows" \
    "$expected_publication_rows" \
    "$live_publication_observed_rows" \
    "$expected_publication_rows" \
    "$declared_real_publication_rows" \
    "$expected_publication_rows" \
    "$non_fixture_declared_rows" \
    "$expected_publication_rows"
  printf "external-benchmark-publication,%s,review_ready=%d publication_ready=%d real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$external_benchmark_publication_review_ready" \
    "$external_benchmark_publication_ready" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
