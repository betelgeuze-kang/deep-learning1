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

PREFIX="v08_external_benchmark_live_publication_result_ingestion"
AI_PREFIX="v08_external_benchmark_publication_result_review"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_live_publication_result_ingestion_smoke"
  AI_PREFIX="v08_external_benchmark_publication_result_review_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_live_publication_result_ingestion_full"
  AI_PREFIX="v08_external_benchmark_publication_result_review_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_publication_result_review.sh" "${RUN_ARGS[@]}" >/dev/null

AI_SUMMARY_CSV="$RESULTS_DIR/${AI_PREFIX}_summary.csv"
REVIEW_CSV="${V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV:-$RESULTS_DIR/${AI_PREFIX}_review.csv}"
INGESTION_CSV="$RESULTS_DIR/${PREFIX}_ingestion.csv"
INGESTION_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
INGESTION_HASH_FIELDS_PER_ROW=14
INGESTION_URI_FIELDS_PER_ROW=14
INGESTION_NEW_ARTIFACT_URI_FIELDS_PER_ROW=10

write_ingestion_header() {
  echo "benchmark_family,reproduction_id,release_id,publication_review_uri,publication_review_hash,result_review_uri,result_review_hash,publication_record_uri,publication_record_hash,result_record_uri,result_record_hash,live_publication_record_uri,live_publication_record_hash,live_result_record_uri,live_result_record_hash,publication_ingest_transcript_uri,publication_ingest_transcript_hash,result_ingest_transcript_uri,result_ingest_transcript_hash,publication_response_header_uri,publication_response_header_hash,result_response_header_uri,result_response_header_hash,publication_content_digest_uri,publication_content_digest_hash,result_content_digest_uri,result_content_digest_hash,publication_tls_certificate_chain_uri,publication_tls_certificate_chain_hash,result_tls_certificate_chain_uri,result_tls_certificate_chain_hash,ingested_at_utc,publication_review_bound,result_review_bound,publication_record_bound,result_record_bound,live_publication_record_bound,live_result_record_bound,publication_ingest_transcript_bound,result_ingest_transcript_bound,publication_response_header_bound,result_response_header_bound,publication_content_digest_bound,result_content_digest_bound,publication_tls_certificate_chain_bound,result_tls_certificate_chain_bound,runner_owned_ingestion_declared,live_network_ingestion_declared,publication_record_digest_match_declared,result_record_digest_match_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-aj column: " column > "/dev/stderr"
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
        print "missing v08-aj summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV:-}" ]]; then
  INGESTION_CSV="$V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV"
  INGESTION_SOURCE="provided-csv"
  if [[ ! -s "$INGESTION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_ingestion_header >"$INGESTION_CSV"
fi

publication_result_review_ready="$(csv_value "$AI_SUMMARY_CSV" "publication_result_review_ready")"
review_rows_upstream="$(csv_value "$AI_SUMMARY_CSV" "review_rows")"
review_expected_families="$(csv_value "$AI_SUMMARY_CSV" "expected_external_families")"
review_real_external="$(csv_value "$AI_SUMMARY_CSV" "real_external_benchmark_verified")"
review_action="$(csv_value "$AI_SUMMARY_CSV" "action")"
review_routing="$(csv_value "$AI_SUMMARY_CSV" "routing_trigger_rate")"
review_jump="$(csv_value "$AI_SUMMARY_CSV" "active_jump_rate")"

declare -A review_reproduction_id=()
declare -A review_release_id=()
declare -A publication_review_uri_by_family=()
declare -A publication_review_hash_by_family=()
declare -A result_review_uri_by_family=()
declare -A result_review_hash_by_family=()
declare -A publication_record_uri_by_family=()
declare -A publication_record_hash_by_family=()
declare -A result_record_uri_by_family=()
declare -A result_record_hash_by_family=()
declare -A review_family_seen=()
review_family_rows=0
REVIEW_TSV="$TMP_DIR/publication_result_review_rows.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id publication_review_uri publication_review_hash result_review_uri result_review_hash publication_record_uri publication_record_hash result_record_uri result_record_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-aj upstream review column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-aj upstream review row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$REVIEW_CSV" >"$REVIEW_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id publication_review_uri publication_review_hash result_review_uri result_review_hash publication_record_uri publication_record_hash result_record_uri result_record_hash; do
  review_reproduction_id["$benchmark_family"]="$reproduction_id"
  review_release_id["$benchmark_family"]="$release_id"
  publication_review_uri_by_family["$benchmark_family"]="$publication_review_uri"
  publication_review_hash_by_family["$benchmark_family"]="$publication_review_hash"
  result_review_uri_by_family["$benchmark_family"]="$result_review_uri"
  result_review_hash_by_family["$benchmark_family"]="$result_review_hash"
  publication_record_uri_by_family["$benchmark_family"]="$publication_record_uri"
  publication_record_hash_by_family["$benchmark_family"]="$publication_record_hash"
  result_record_uri_by_family["$benchmark_family"]="$result_record_uri"
  result_record_hash_by_family["$benchmark_family"]="$result_record_hash"
  review_family_seen["$benchmark_family"]=1
done <"$REVIEW_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${review_family_seen[$family]:-}" ]]; then
    ((review_family_rows += 1))
  fi
done

ingestion_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_review_family_rows=0
reproduction_id_match_rows=0
release_id_match_rows=0
publication_review_match_rows=0
result_review_match_rows=0
publication_record_match_rows=0
result_record_match_rows=0
required_ingestion_hash_fields=0
ingestion_hash_attested_fields=0
required_ingestion_uri_fields=0
nonlocal_ingestion_uri_fields=0
local_ingestion_uri_fields=0
required_new_ingestion_uri_fields=0
nonplaceholder_new_ingestion_uri_fields=0
placeholder_new_ingestion_uri_fields=0
publication_review_bound_rows=0
result_review_bound_rows=0
publication_record_bound_rows=0
result_record_bound_rows=0
live_publication_record_bound_rows=0
live_result_record_bound_rows=0
publication_ingest_transcript_bound_rows=0
result_ingest_transcript_bound_rows=0
publication_response_header_bound_rows=0
result_response_header_bound_rows=0
publication_content_digest_bound_rows=0
result_content_digest_bound_rows=0
publication_tls_certificate_chain_bound_rows=0
result_tls_certificate_chain_bound_rows=0
runner_owned_ingestion_declared_rows=0
live_network_ingestion_declared_rows=0
publication_record_digest_match_declared_rows=0
result_record_digest_match_declared_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
ingestion_routing="0.000000"
ingestion_jump="0.000000"
declare -A ingestion_family_seen=()

INGESTION_TSV="$TMP_DIR/live_publication_result_ingestion.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id publication_review_uri publication_review_hash result_review_uri result_review_hash publication_record_uri publication_record_hash result_record_uri result_record_hash live_publication_record_uri live_publication_record_hash live_result_record_uri live_result_record_hash publication_ingest_transcript_uri publication_ingest_transcript_hash result_ingest_transcript_uri result_ingest_transcript_hash publication_response_header_uri publication_response_header_hash result_response_header_uri result_response_header_hash publication_content_digest_uri publication_content_digest_hash result_content_digest_uri result_content_digest_hash publication_tls_certificate_chain_uri publication_tls_certificate_chain_hash result_tls_certificate_chain_uri result_tls_certificate_chain_hash ingested_at_utc publication_review_bound result_review_bound publication_record_bound result_record_bound live_publication_record_bound live_result_record_bound publication_ingest_transcript_bound result_ingest_transcript_bound publication_response_header_bound result_response_header_bound publication_content_digest_bound result_content_digest_bound publication_tls_certificate_chain_bound result_tls_certificate_chain_bound runner_owned_ingestion_declared live_network_ingestion_declared publication_record_digest_match_declared result_record_digest_match_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-aj ingestion column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-aj ingestion row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$INGESTION_CSV" >"$INGESTION_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id publication_review_uri publication_review_hash result_review_uri result_review_hash publication_record_uri publication_record_hash result_record_uri result_record_hash live_publication_record_uri live_publication_record_hash live_result_record_uri live_result_record_hash publication_ingest_transcript_uri publication_ingest_transcript_hash result_ingest_transcript_uri result_ingest_transcript_hash publication_response_header_uri publication_response_header_hash result_response_header_uri result_response_header_hash publication_content_digest_uri publication_content_digest_hash result_content_digest_uri result_content_digest_hash publication_tls_certificate_chain_uri publication_tls_certificate_chain_hash result_tls_certificate_chain_uri result_tls_certificate_chain_hash ingested_at_utc publication_review_bound result_review_bound publication_record_bound result_record_bound live_publication_record_bound live_result_record_bound publication_ingest_transcript_bound result_ingest_transcript_bound publication_response_header_bound result_response_header_bound publication_content_digest_bound result_content_digest_bound publication_tls_certificate_chain_bound result_tls_certificate_chain_bound runner_owned_ingestion_declared live_network_ingestion_declared publication_record_digest_match_declared result_record_digest_match_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((ingestion_rows += 1))

  if [[ -n "${ingestion_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  ingestion_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${review_release_id[$benchmark_family]:-}" ]]; then
    ((matched_review_family_rows += 1))
  fi
  if [[ -n "${review_reproduction_id[$benchmark_family]:-}" &&
        "$reproduction_id" == "${review_reproduction_id[$benchmark_family]}" ]]; then
    ((reproduction_id_match_rows += 1))
  fi
  if [[ -n "${review_release_id[$benchmark_family]:-}" &&
        "$release_id" == "${review_release_id[$benchmark_family]}" ]]; then
    ((release_id_match_rows += 1))
  fi
  if [[ -n "${publication_review_uri_by_family[$benchmark_family]:-}" &&
        "$publication_review_uri" == "${publication_review_uri_by_family[$benchmark_family]}" &&
        "$publication_review_hash" == "${publication_review_hash_by_family[$benchmark_family]}" ]]; then
    ((publication_review_match_rows += 1))
  fi
  if [[ -n "${result_review_uri_by_family[$benchmark_family]:-}" &&
        "$result_review_uri" == "${result_review_uri_by_family[$benchmark_family]}" &&
        "$result_review_hash" == "${result_review_hash_by_family[$benchmark_family]}" ]]; then
    ((result_review_match_rows += 1))
  fi
  if [[ -n "${publication_record_uri_by_family[$benchmark_family]:-}" &&
        "$publication_record_uri" == "${publication_record_uri_by_family[$benchmark_family]}" &&
        "$publication_record_hash" == "${publication_record_hash_by_family[$benchmark_family]}" ]]; then
    ((publication_record_match_rows += 1))
  fi
  if [[ -n "${result_record_uri_by_family[$benchmark_family]:-}" &&
        "$result_record_uri" == "${result_record_uri_by_family[$benchmark_family]}" &&
        "$result_record_hash" == "${result_record_hash_by_family[$benchmark_family]}" ]]; then
    ((result_record_match_rows += 1))
  fi

  for pair in \
    "$publication_review_uri|$publication_review_hash" \
    "$result_review_uri|$result_review_hash" \
    "$publication_record_uri|$publication_record_hash" \
    "$result_record_uri|$result_record_hash" \
    "$live_publication_record_uri|$live_publication_record_hash" \
    "$live_result_record_uri|$live_result_record_hash" \
    "$publication_ingest_transcript_uri|$publication_ingest_transcript_hash" \
    "$result_ingest_transcript_uri|$result_ingest_transcript_hash" \
    "$publication_response_header_uri|$publication_response_header_hash" \
    "$result_response_header_uri|$result_response_header_hash" \
    "$publication_content_digest_uri|$publication_content_digest_hash" \
    "$result_content_digest_uri|$result_content_digest_hash" \
    "$publication_tls_certificate_chain_uri|$publication_tls_certificate_chain_hash" \
    "$result_tls_certificate_chain_uri|$result_tls_certificate_chain_hash"; do
    ((required_ingestion_hash_fields += 1))
    ((required_ingestion_uri_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((ingestion_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_ingestion_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_ingestion_uri_fields += 1))
    fi
  done

  for uri in \
    "$live_publication_record_uri" \
    "$live_result_record_uri" \
    "$publication_ingest_transcript_uri" \
    "$result_ingest_transcript_uri" \
    "$publication_response_header_uri" \
    "$result_response_header_uri" \
    "$publication_content_digest_uri" \
    "$result_content_digest_uri" \
    "$publication_tls_certificate_chain_uri" \
    "$result_tls_certificate_chain_uri"; do
    ((required_new_ingestion_uri_fields += 1))
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_new_ingestion_uri_fields += 1))
    else
      ((placeholder_new_ingestion_uri_fields += 1))
    fi
  done

  [[ "$publication_review_bound" == "1" ]] && ((publication_review_bound_rows += 1))
  [[ "$result_review_bound" == "1" ]] && ((result_review_bound_rows += 1))
  [[ "$publication_record_bound" == "1" ]] && ((publication_record_bound_rows += 1))
  [[ "$result_record_bound" == "1" ]] && ((result_record_bound_rows += 1))
  [[ "$live_publication_record_bound" == "1" ]] && ((live_publication_record_bound_rows += 1))
  [[ "$live_result_record_bound" == "1" ]] && ((live_result_record_bound_rows += 1))
  [[ "$publication_ingest_transcript_bound" == "1" ]] && ((publication_ingest_transcript_bound_rows += 1))
  [[ "$result_ingest_transcript_bound" == "1" ]] && ((result_ingest_transcript_bound_rows += 1))
  [[ "$publication_response_header_bound" == "1" ]] && ((publication_response_header_bound_rows += 1))
  [[ "$result_response_header_bound" == "1" ]] && ((result_response_header_bound_rows += 1))
  [[ "$publication_content_digest_bound" == "1" ]] && ((publication_content_digest_bound_rows += 1))
  [[ "$result_content_digest_bound" == "1" ]] && ((result_content_digest_bound_rows += 1))
  [[ "$publication_tls_certificate_chain_bound" == "1" ]] && ((publication_tls_certificate_chain_bound_rows += 1))
  [[ "$result_tls_certificate_chain_bound" == "1" ]] && ((result_tls_certificate_chain_bound_rows += 1))
  [[ "$runner_owned_ingestion_declared" == "1" ]] && ((runner_owned_ingestion_declared_rows += 1))
  [[ "$live_network_ingestion_declared" == "1" ]] && ((live_network_ingestion_declared_rows += 1))
  [[ "$publication_record_digest_match_declared" == "1" ]] && ((publication_record_digest_match_declared_rows += 1))
  [[ "$result_record_digest_match_declared" == "1" ]] && ((result_record_digest_match_declared_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$ingested_at_utc" && ((timestamp_rows += 1))
  ingestion_routing="$(awk -v a="$ingestion_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  ingestion_jump="$(awk -v a="$ingestion_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$INGESTION_TSV"

ingestion_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${ingestion_family_seen[$family]:-}" ]]; then
    ((ingestion_family_coverage += 1))
  fi
done

expected_ingestion_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * INGESTION_HASH_FIELDS_PER_ROW))
expected_ingestion_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * INGESTION_URI_FIELDS_PER_ROW))
expected_new_ingestion_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * INGESTION_NEW_ARTIFACT_URI_FIELDS_PER_ROW))
live_publication_result_ingestion_ready=0
if [[ "$publication_result_review_ready" == "1" &&
      "$review_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$ingestion_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$ingestion_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_review_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_review_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_review_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_ingestion_hash_fields" -eq "$expected_ingestion_hash_fields" &&
      "$ingestion_hash_attested_fields" -eq "$expected_ingestion_hash_fields" &&
      "$required_ingestion_uri_fields" -eq "$expected_ingestion_uri_fields" &&
      "$nonlocal_ingestion_uri_fields" -eq "$expected_ingestion_uri_fields" &&
      "$local_ingestion_uri_fields" -eq 0 &&
      "$required_new_ingestion_uri_fields" -eq "$expected_new_ingestion_uri_fields" &&
      "$nonplaceholder_new_ingestion_uri_fields" -eq "$expected_new_ingestion_uri_fields" &&
      "$placeholder_new_ingestion_uri_fields" -eq 0 &&
      "$publication_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_ingest_transcript_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_ingest_transcript_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_response_header_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_response_header_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_tls_certificate_chain_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_tls_certificate_chain_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$runner_owned_ingestion_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_network_ingestion_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_record_digest_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_record_digest_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$ingestion_routing" == "0.000000" &&
      "$ingestion_jump" == "0.000000" ]]; then
  live_publication_result_ingestion_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$review_routing" -v b="$ingestion_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$review_jump" -v b="$ingestion_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-publication-result-review-not-ready"
if [[ "$publication_result_review_ready" != "1" ]]; then
  action="external-benchmark-publication-result-review-not-ready"
elif [[ "$ingestion_rows" -eq 0 ]]; then
  action="external-benchmark-live-publication-result-ingestion-missing"
elif [[ "$ingestion_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$ingestion_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-live-publication-result-ingestion-coverage-incomplete"
elif [[ "$matched_review_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-publication-result-ingestion-binding-mismatch"
elif [[ "$publication_review_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_review_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_record_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_record_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-publication-result-ingestion-review-artifact-mismatch"
elif [[ "$required_ingestion_hash_fields" -ne "$expected_ingestion_hash_fields" ||
        "$ingestion_hash_attested_fields" -ne "$expected_ingestion_hash_fields" ]]; then
  action="external-benchmark-live-publication-result-ingestion-hash-attestation-missing"
elif [[ "$required_ingestion_uri_fields" -ne "$expected_ingestion_uri_fields" ||
        "$nonlocal_ingestion_uri_fields" -ne "$expected_ingestion_uri_fields" ||
        "$local_ingestion_uri_fields" -ne 0 ]]; then
  action="external-benchmark-live-publication-result-ingestion-local-artifact-uri"
elif [[ "$required_new_ingestion_uri_fields" -ne "$expected_new_ingestion_uri_fields" ||
        "$nonplaceholder_new_ingestion_uri_fields" -ne "$expected_new_ingestion_uri_fields" ||
        "$placeholder_new_ingestion_uri_fields" -ne 0 ]]; then
  action="external-benchmark-live-publication-result-ingestion-placeholder-artifact-uri"
elif [[ "$publication_review_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_review_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_publication_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_result_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_ingest_transcript_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_ingest_transcript_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_response_header_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_response_header_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_content_digest_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_content_digest_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_tls_certificate_chain_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_tls_certificate_chain_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-publication-result-ingestion-proof-binding-missing"
elif [[ "$runner_owned_ingestion_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_network_ingestion_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_record_digest_match_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_record_digest_match_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-publication-result-ingestion-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-live-publication-result-ingestion-jump-guardrail-violated"
elif [[ "$live_publication_result_ingestion_ready" == "1" ]]; then
  action="external-benchmark-live-publication-result-ingestion-ready-await-promotion-authority-evidence"
fi

{
  echo "benchmark_scope,ingestion_source,publication_result_review_ready,review_rows,review_expected_families,review_real_external,review_action,review_family_rows,ingestion_rows,expected_family_rows,duplicate_family_rows,matched_review_family_rows,reproduction_id_match_rows,release_id_match_rows,publication_review_match_rows,result_review_match_rows,publication_record_match_rows,result_record_match_rows,required_ingestion_hash_fields,ingestion_hash_attested_fields,required_ingestion_uri_fields,nonlocal_ingestion_uri_fields,local_ingestion_uri_fields,required_new_ingestion_uri_fields,nonplaceholder_new_ingestion_uri_fields,placeholder_new_ingestion_uri_fields,publication_review_bound_rows,result_review_bound_rows,publication_record_bound_rows,result_record_bound_rows,live_publication_record_bound_rows,live_result_record_bound_rows,publication_ingest_transcript_bound_rows,result_ingest_transcript_bound_rows,publication_response_header_bound_rows,result_response_header_bound_rows,publication_content_digest_bound_rows,result_content_digest_bound_rows,publication_tls_certificate_chain_bound_rows,result_tls_certificate_chain_bound_rows,runner_owned_ingestion_declared_rows,live_network_ingestion_declared_rows,publication_record_digest_match_declared_rows,result_record_digest_match_declared_rows,non_fixture_declared_rows,fixture_free_rows,timestamp_rows,ingestion_family_coverage,expected_external_families,live_publication_result_ingestion_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08aj,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$INGESTION_SOURCE" \
    "$publication_result_review_ready" \
    "$review_rows_upstream" \
    "$review_expected_families" \
    "$review_real_external" \
    "$review_action" \
    "$review_family_rows" \
    "$ingestion_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_review_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$publication_review_match_rows" \
    "$result_review_match_rows" \
    "$publication_record_match_rows" \
    "$result_record_match_rows" \
    "$required_ingestion_hash_fields" \
    "$ingestion_hash_attested_fields" \
    "$required_ingestion_uri_fields" \
    "$nonlocal_ingestion_uri_fields" \
    "$local_ingestion_uri_fields" \
    "$required_new_ingestion_uri_fields" \
    "$nonplaceholder_new_ingestion_uri_fields" \
    "$placeholder_new_ingestion_uri_fields" \
    "$publication_review_bound_rows" \
    "$result_review_bound_rows" \
    "$publication_record_bound_rows" \
    "$result_record_bound_rows" \
    "$live_publication_record_bound_rows" \
    "$live_result_record_bound_rows" \
    "$publication_ingest_transcript_bound_rows" \
    "$result_ingest_transcript_bound_rows" \
    "$publication_response_header_bound_rows" \
    "$result_response_header_bound_rows" \
    "$publication_content_digest_bound_rows" \
    "$result_content_digest_bound_rows" \
    "$publication_tls_certificate_chain_bound_rows" \
    "$result_tls_certificate_chain_bound_rows" \
    "$runner_owned_ingestion_declared_rows" \
    "$live_network_ingestion_declared_rows" \
    "$publication_record_digest_match_declared_rows" \
    "$result_record_digest_match_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$ingestion_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$live_publication_result_ingestion_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "publication-result-review,%s,ready=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$publication_result_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$publication_result_review_ready" \
    "$review_rows_upstream" \
    "$review_expected_families" \
    "$review_real_external" \
    "$review_action"
  printf "live-publication-result-ingestion-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$ingestion_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$ingestion_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$ingestion_rows" \
    "$expected_family_rows" \
    "$ingestion_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "live-publication-result-ingestion-binding,%s,matched=%d reproduction=%d release=%d reviews=%d/%d records=%d/%d\n" \
    "$([[ "$matched_review_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_review_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_review_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_review_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$publication_review_match_rows" \
    "$result_review_match_rows" \
    "$publication_record_match_rows" \
    "$result_record_match_rows"
  printf "live-publication-result-ingestion-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_ingestion_hash_fields" -eq "$expected_ingestion_hash_fields" && "$ingestion_hash_attested_fields" -eq "$expected_ingestion_hash_fields" ]] && echo pass || echo blocked)" \
    "$ingestion_hash_attested_fields" \
    "$expected_ingestion_hash_fields"
  printf "nonlocal-live-publication-result-ingestion-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$required_ingestion_uri_fields" -eq "$expected_ingestion_uri_fields" && "$nonlocal_ingestion_uri_fields" -eq "$expected_ingestion_uri_fields" && "$local_ingestion_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_ingestion_uri_fields" \
    "$expected_ingestion_uri_fields" \
    "$local_ingestion_uri_fields"
  printf "nonplaceholder-live-publication-result-ingestion-artifacts,%s,nonplaceholder=%d/%d placeholder=%d\n" \
    "$([[ "$required_new_ingestion_uri_fields" -eq "$expected_new_ingestion_uri_fields" && "$nonplaceholder_new_ingestion_uri_fields" -eq "$expected_new_ingestion_uri_fields" && "$placeholder_new_ingestion_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonplaceholder_new_ingestion_uri_fields" \
    "$expected_new_ingestion_uri_fields" \
    "$placeholder_new_ingestion_uri_fields"
  printf "live-publication-result-ingestion-proof-bindings,%s,bound=%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$publication_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_ingest_transcript_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_ingest_transcript_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_response_header_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_response_header_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_tls_certificate_chain_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_tls_certificate_chain_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$publication_review_bound_rows" \
    "$result_review_bound_rows" \
    "$publication_record_bound_rows" \
    "$result_record_bound_rows" \
    "$live_publication_record_bound_rows" \
    "$live_result_record_bound_rows" \
    "$publication_ingest_transcript_bound_rows" \
    "$result_ingest_transcript_bound_rows" \
    "$publication_response_header_bound_rows" \
    "$result_response_header_bound_rows" \
    "$publication_content_digest_bound_rows" \
    "$result_content_digest_bound_rows" \
    "$publication_tls_certificate_chain_bound_rows" \
    "$result_tls_certificate_chain_bound_rows"
  printf "live-publication-result-ingestion-declarations,%s,runner=%d live=%d publication_digest=%d result_digest=%d non_fixture=%d fixture_free=%d timestamps=%d\n" \
    "$([[ "$runner_owned_ingestion_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_network_ingestion_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_record_digest_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_record_digest_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$runner_owned_ingestion_declared_rows" \
    "$live_network_ingestion_declared_rows" \
    "$publication_record_digest_match_declared_rows" \
    "$result_record_digest_match_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows"
  printf "live-publication-result-ingestion,%s,ready=%d action=%s\n" \
    "$([[ "$live_publication_result_ingestion_ready" == "1" ]] && echo pass || echo blocked)" \
    "$live_publication_result_ingestion_ready" \
    "$action"
  printf "real-external-benchmark,blocked,real_external_benchmark_verified=%d action=%s\n" \
    "$real_external_benchmark_verified" \
    "$action"
  printf "jump-guardrail,%s,routing=%.6f active_jump=%.6f\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "live_publication_result_ingestion: $INGESTION_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
