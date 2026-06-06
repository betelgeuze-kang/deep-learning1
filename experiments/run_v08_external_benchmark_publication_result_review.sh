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

PREFIX="v08_external_benchmark_publication_result_review"
AH_PREFIX="v08_external_benchmark_canonical_online_confirmation"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_publication_result_review_smoke"
  AH_PREFIX="v08_external_benchmark_canonical_online_confirmation_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_publication_result_review_full"
  AH_PREFIX="v08_external_benchmark_canonical_online_confirmation_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_canonical_online_confirmation.sh" "${RUN_ARGS[@]}" >/dev/null

AH_SUMMARY_CSV="$RESULTS_DIR/${AH_PREFIX}_summary.csv"
CONFIRMATION_CSV="${V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV:-$RESULTS_DIR/${AH_PREFIX}_confirmation.csv}"
REVIEW_CSV="$RESULTS_DIR/${PREFIX}_review.csv"
REVIEW_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
REVIEW_HASH_FIELDS_PER_ROW=9
REVIEW_URI_FIELDS_PER_ROW=9
REVIEW_NEW_ARTIFACT_URI_FIELDS_PER_ROW=7

write_review_header() {
  echo "benchmark_family,reproduction_id,release_id,canonical_confirmation_report_uri,canonical_confirmation_report_hash,content_digest_manifest_uri,content_digest_manifest_hash,publication_review_uri,publication_review_hash,result_review_uri,result_review_hash,publication_record_uri,publication_record_hash,result_record_uri,result_record_hash,reviewer_identity_uri,reviewer_identity_hash,publication_authority_uri,publication_authority_hash,result_authority_uri,result_authority_hash,reviewed_at_utc,canonical_confirmation_bound,content_digest_manifest_bound,publication_review_bound,result_review_bound,publication_record_bound,result_record_bound,reviewer_identity_bound,publication_authority_bound,result_authority_bound,independent_review_declared,publication_observed_declared,result_observed_declared,canonical_result_match_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ai column: " column > "/dev/stderr"
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
        print "missing v08-ai summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV:-}" ]]; then
  REVIEW_CSV="$V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV"
  REVIEW_SOURCE="provided-csv"
  if [[ ! -s "$REVIEW_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_review_header >"$REVIEW_CSV"
fi

canonical_online_confirmation_ready="$(csv_value "$AH_SUMMARY_CSV" "canonical_online_confirmation_ready")"
canonical_confirmation_rows_upstream="$(csv_value "$AH_SUMMARY_CSV" "confirmation_rows")"
canonical_expected_families="$(csv_value "$AH_SUMMARY_CSV" "expected_external_families")"
canonical_real_external="$(csv_value "$AH_SUMMARY_CSV" "real_external_benchmark_verified")"
canonical_action="$(csv_value "$AH_SUMMARY_CSV" "action")"
canonical_routing="$(csv_value "$AH_SUMMARY_CSV" "routing_trigger_rate")"
canonical_jump="$(csv_value "$AH_SUMMARY_CSV" "active_jump_rate")"

declare -A canonical_reproduction_id=()
declare -A canonical_release_id=()
declare -A canonical_report_uri_by_family=()
declare -A canonical_report_hash_by_family=()
declare -A content_digest_uri_by_family=()
declare -A content_digest_hash_by_family=()
declare -A canonical_family_seen=()
canonical_family_rows=0
CONFIRMATION_TSV="$TMP_DIR/canonical_confirmation_rows.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id canonical_confirmation_report_uri canonical_confirmation_report_hash content_digest_manifest_uri content_digest_manifest_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ai upstream confirmation column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ai upstream confirmation row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$CONFIRMATION_CSV" >"$CONFIRMATION_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id canonical_confirmation_report_uri canonical_confirmation_report_hash content_digest_manifest_uri content_digest_manifest_hash; do
  canonical_reproduction_id["$benchmark_family"]="$reproduction_id"
  canonical_release_id["$benchmark_family"]="$release_id"
  canonical_report_uri_by_family["$benchmark_family"]="$canonical_confirmation_report_uri"
  canonical_report_hash_by_family["$benchmark_family"]="$canonical_confirmation_report_hash"
  content_digest_uri_by_family["$benchmark_family"]="$content_digest_manifest_uri"
  content_digest_hash_by_family["$benchmark_family"]="$content_digest_manifest_hash"
  canonical_family_seen["$benchmark_family"]=1
done <"$CONFIRMATION_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${canonical_family_seen[$family]:-}" ]]; then
    ((canonical_family_rows += 1))
  fi
done

review_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_canonical_family_rows=0
reproduction_id_match_rows=0
release_id_match_rows=0
canonical_confirmation_match_rows=0
content_digest_match_rows=0
required_review_hash_fields=0
review_hash_attested_fields=0
required_review_uri_fields=0
nonlocal_review_uri_fields=0
local_review_uri_fields=0
required_new_review_uri_fields=0
nonplaceholder_new_review_uri_fields=0
placeholder_new_review_uri_fields=0
canonical_confirmation_bound_rows=0
content_digest_manifest_bound_rows=0
publication_review_bound_rows=0
result_review_bound_rows=0
publication_record_bound_rows=0
result_record_bound_rows=0
reviewer_identity_bound_rows=0
publication_authority_bound_rows=0
result_authority_bound_rows=0
independent_review_declared_rows=0
publication_observed_declared_rows=0
result_observed_declared_rows=0
canonical_result_match_declared_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
review_routing="0.000000"
review_jump="0.000000"
declare -A review_family_seen=()

REVIEW_TSV="$TMP_DIR/publication_result_review.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id canonical_confirmation_report_uri canonical_confirmation_report_hash content_digest_manifest_uri content_digest_manifest_hash publication_review_uri publication_review_hash result_review_uri result_review_hash publication_record_uri publication_record_hash result_record_uri result_record_hash reviewer_identity_uri reviewer_identity_hash publication_authority_uri publication_authority_hash result_authority_uri result_authority_hash reviewed_at_utc canonical_confirmation_bound content_digest_manifest_bound publication_review_bound result_review_bound publication_record_bound result_record_bound reviewer_identity_bound publication_authority_bound result_authority_bound independent_review_declared publication_observed_declared result_observed_declared canonical_result_match_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ai review column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ai review row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$REVIEW_CSV" >"$REVIEW_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id canonical_confirmation_report_uri canonical_confirmation_report_hash content_digest_manifest_uri content_digest_manifest_hash publication_review_uri publication_review_hash result_review_uri result_review_hash publication_record_uri publication_record_hash result_record_uri result_record_hash reviewer_identity_uri reviewer_identity_hash publication_authority_uri publication_authority_hash result_authority_uri result_authority_hash reviewed_at_utc canonical_confirmation_bound content_digest_manifest_bound publication_review_bound result_review_bound publication_record_bound result_record_bound reviewer_identity_bound publication_authority_bound result_authority_bound independent_review_declared publication_observed_declared result_observed_declared canonical_result_match_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((review_rows += 1))

  if [[ -n "${review_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  review_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${canonical_release_id[$benchmark_family]:-}" ]]; then
    ((matched_canonical_family_rows += 1))
  fi
  if [[ -n "${canonical_reproduction_id[$benchmark_family]:-}" &&
        "$reproduction_id" == "${canonical_reproduction_id[$benchmark_family]}" ]]; then
    ((reproduction_id_match_rows += 1))
  fi
  if [[ -n "${canonical_release_id[$benchmark_family]:-}" &&
        "$release_id" == "${canonical_release_id[$benchmark_family]}" ]]; then
    ((release_id_match_rows += 1))
  fi
  if [[ -n "${canonical_report_uri_by_family[$benchmark_family]:-}" &&
        "$canonical_confirmation_report_uri" == "${canonical_report_uri_by_family[$benchmark_family]}" &&
        "$canonical_confirmation_report_hash" == "${canonical_report_hash_by_family[$benchmark_family]}" ]]; then
    ((canonical_confirmation_match_rows += 1))
  fi
  if [[ -n "${content_digest_uri_by_family[$benchmark_family]:-}" &&
        "$content_digest_manifest_uri" == "${content_digest_uri_by_family[$benchmark_family]}" &&
        "$content_digest_manifest_hash" == "${content_digest_hash_by_family[$benchmark_family]}" ]]; then
    ((content_digest_match_rows += 1))
  fi

  for pair in \
    "$canonical_confirmation_report_uri|$canonical_confirmation_report_hash" \
    "$content_digest_manifest_uri|$content_digest_manifest_hash" \
    "$publication_review_uri|$publication_review_hash" \
    "$result_review_uri|$result_review_hash" \
    "$publication_record_uri|$publication_record_hash" \
    "$result_record_uri|$result_record_hash" \
    "$reviewer_identity_uri|$reviewer_identity_hash" \
    "$publication_authority_uri|$publication_authority_hash" \
    "$result_authority_uri|$result_authority_hash"; do
    ((required_review_hash_fields += 1))
    ((required_review_uri_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((review_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_review_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_review_uri_fields += 1))
    fi
  done

  for uri in \
    "$publication_review_uri" \
    "$result_review_uri" \
    "$publication_record_uri" \
    "$result_record_uri" \
    "$reviewer_identity_uri" \
    "$publication_authority_uri" \
    "$result_authority_uri"; do
    ((required_new_review_uri_fields += 1))
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_new_review_uri_fields += 1))
    else
      ((placeholder_new_review_uri_fields += 1))
    fi
  done

  [[ "$canonical_confirmation_bound" == "1" ]] && ((canonical_confirmation_bound_rows += 1))
  [[ "$content_digest_manifest_bound" == "1" ]] && ((content_digest_manifest_bound_rows += 1))
  [[ "$publication_review_bound" == "1" ]] && ((publication_review_bound_rows += 1))
  [[ "$result_review_bound" == "1" ]] && ((result_review_bound_rows += 1))
  [[ "$publication_record_bound" == "1" ]] && ((publication_record_bound_rows += 1))
  [[ "$result_record_bound" == "1" ]] && ((result_record_bound_rows += 1))
  [[ "$reviewer_identity_bound" == "1" ]] && ((reviewer_identity_bound_rows += 1))
  [[ "$publication_authority_bound" == "1" ]] && ((publication_authority_bound_rows += 1))
  [[ "$result_authority_bound" == "1" ]] && ((result_authority_bound_rows += 1))
  [[ "$independent_review_declared" == "1" ]] && ((independent_review_declared_rows += 1))
  [[ "$publication_observed_declared" == "1" ]] && ((publication_observed_declared_rows += 1))
  [[ "$result_observed_declared" == "1" ]] && ((result_observed_declared_rows += 1))
  [[ "$canonical_result_match_declared" == "1" ]] && ((canonical_result_match_declared_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$reviewed_at_utc" && ((timestamp_rows += 1))
  review_routing="$(awk -v a="$review_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  review_jump="$(awk -v a="$review_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$REVIEW_TSV"

review_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${review_family_seen[$family]:-}" ]]; then
    ((review_family_coverage += 1))
  fi
done

expected_review_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * REVIEW_HASH_FIELDS_PER_ROW))
expected_review_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * REVIEW_URI_FIELDS_PER_ROW))
expected_new_review_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * REVIEW_NEW_ARTIFACT_URI_FIELDS_PER_ROW))
publication_result_review_ready=0
if [[ "$canonical_online_confirmation_ready" == "1" &&
      "$canonical_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$review_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$review_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_canonical_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$canonical_confirmation_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$content_digest_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_review_hash_fields" -eq "$expected_review_hash_fields" &&
      "$review_hash_attested_fields" -eq "$expected_review_hash_fields" &&
      "$required_review_uri_fields" -eq "$expected_review_uri_fields" &&
      "$nonlocal_review_uri_fields" -eq "$expected_review_uri_fields" &&
      "$local_review_uri_fields" -eq 0 &&
      "$required_new_review_uri_fields" -eq "$expected_new_review_uri_fields" &&
      "$nonplaceholder_new_review_uri_fields" -eq "$expected_new_review_uri_fields" &&
      "$placeholder_new_review_uri_fields" -eq 0 &&
      "$canonical_confirmation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$content_digest_manifest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reviewer_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_observed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_observed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$canonical_result_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$review_routing" == "0.000000" &&
      "$review_jump" == "0.000000" ]]; then
  publication_result_review_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$canonical_routing" -v b="$review_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$canonical_jump" -v b="$review_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-canonical-online-confirmation-not-ready"
if [[ "$canonical_online_confirmation_ready" != "1" ]]; then
  action="external-benchmark-canonical-online-confirmation-not-ready"
elif [[ "$review_rows" -eq 0 ]]; then
  action="external-benchmark-publication-result-review-missing"
elif [[ "$review_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$review_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-publication-result-review-coverage-incomplete"
elif [[ "$matched_canonical_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-publication-result-review-binding-mismatch"
elif [[ "$canonical_confirmation_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$content_digest_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-publication-result-review-canonical-artifact-mismatch"
elif [[ "$required_review_hash_fields" -ne "$expected_review_hash_fields" ||
        "$review_hash_attested_fields" -ne "$expected_review_hash_fields" ]]; then
  action="external-benchmark-publication-result-review-hash-attestation-missing"
elif [[ "$required_review_uri_fields" -ne "$expected_review_uri_fields" ||
        "$nonlocal_review_uri_fields" -ne "$expected_review_uri_fields" ||
        "$local_review_uri_fields" -ne 0 ]]; then
  action="external-benchmark-publication-result-review-local-artifact-uri"
elif [[ "$required_new_review_uri_fields" -ne "$expected_new_review_uri_fields" ||
        "$nonplaceholder_new_review_uri_fields" -ne "$expected_new_review_uri_fields" ||
        "$placeholder_new_review_uri_fields" -ne 0 ]]; then
  action="external-benchmark-publication-result-review-placeholder-artifact-uri"
elif [[ "$canonical_confirmation_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$content_digest_manifest_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_review_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_review_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reviewer_identity_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_authority_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_authority_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-publication-result-review-proof-binding-missing"
elif [[ "$independent_review_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_observed_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_observed_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$canonical_result_match_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-publication-result-review-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-publication-result-review-jump-guardrail-violated"
elif [[ "$publication_result_review_ready" == "1" ]]; then
  action="external-benchmark-publication-result-review-ready-await-live-ingestion-promotion-evidence"
fi

{
  echo "benchmark_scope,review_source,canonical_online_confirmation_ready,canonical_confirmation_rows,canonical_expected_families,canonical_real_external,canonical_action,canonical_family_rows,review_rows,expected_family_rows,duplicate_family_rows,matched_canonical_family_rows,reproduction_id_match_rows,release_id_match_rows,canonical_confirmation_match_rows,content_digest_match_rows,required_review_hash_fields,review_hash_attested_fields,required_review_uri_fields,nonlocal_review_uri_fields,local_review_uri_fields,required_new_review_uri_fields,nonplaceholder_new_review_uri_fields,placeholder_new_review_uri_fields,canonical_confirmation_bound_rows,content_digest_manifest_bound_rows,publication_review_bound_rows,result_review_bound_rows,publication_record_bound_rows,result_record_bound_rows,reviewer_identity_bound_rows,publication_authority_bound_rows,result_authority_bound_rows,independent_review_declared_rows,publication_observed_declared_rows,result_observed_declared_rows,canonical_result_match_declared_rows,non_fixture_declared_rows,fixture_free_rows,timestamp_rows,review_family_coverage,expected_external_families,publication_result_review_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ai,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$REVIEW_SOURCE" \
    "$canonical_online_confirmation_ready" \
    "$canonical_confirmation_rows_upstream" \
    "$canonical_expected_families" \
    "$canonical_real_external" \
    "$canonical_action" \
    "$canonical_family_rows" \
    "$review_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_canonical_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$canonical_confirmation_match_rows" \
    "$content_digest_match_rows" \
    "$required_review_hash_fields" \
    "$review_hash_attested_fields" \
    "$required_review_uri_fields" \
    "$nonlocal_review_uri_fields" \
    "$local_review_uri_fields" \
    "$required_new_review_uri_fields" \
    "$nonplaceholder_new_review_uri_fields" \
    "$placeholder_new_review_uri_fields" \
    "$canonical_confirmation_bound_rows" \
    "$content_digest_manifest_bound_rows" \
    "$publication_review_bound_rows" \
    "$result_review_bound_rows" \
    "$publication_record_bound_rows" \
    "$result_record_bound_rows" \
    "$reviewer_identity_bound_rows" \
    "$publication_authority_bound_rows" \
    "$result_authority_bound_rows" \
    "$independent_review_declared_rows" \
    "$publication_observed_declared_rows" \
    "$result_observed_declared_rows" \
    "$canonical_result_match_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$review_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$publication_result_review_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "canonical-online-confirmation,%s,ready=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$canonical_online_confirmation_ready" == "1" ]] && echo pass || echo blocked)" \
    "$canonical_online_confirmation_ready" \
    "$canonical_confirmation_rows_upstream" \
    "$canonical_expected_families" \
    "$canonical_real_external" \
    "$canonical_action"
  printf "publication-result-review-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$review_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$review_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$review_rows" \
    "$expected_family_rows" \
    "$review_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "publication-result-review-binding,%s,matched=%d reproduction=%d release=%d canonical=%d digest=%d\n" \
    "$([[ "$matched_canonical_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$canonical_confirmation_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$content_digest_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_canonical_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$canonical_confirmation_match_rows" \
    "$content_digest_match_rows"
  printf "publication-result-review-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_review_hash_fields" -eq "$expected_review_hash_fields" && "$review_hash_attested_fields" -eq "$expected_review_hash_fields" ]] && echo pass || echo blocked)" \
    "$review_hash_attested_fields" \
    "$expected_review_hash_fields"
  printf "nonlocal-publication-result-review-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$required_review_uri_fields" -eq "$expected_review_uri_fields" && "$nonlocal_review_uri_fields" -eq "$expected_review_uri_fields" && "$local_review_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_review_uri_fields" \
    "$expected_review_uri_fields" \
    "$local_review_uri_fields"
  printf "nonplaceholder-publication-result-review-artifacts,%s,nonplaceholder=%d/%d placeholder=%d\n" \
    "$([[ "$required_new_review_uri_fields" -eq "$expected_new_review_uri_fields" && "$nonplaceholder_new_review_uri_fields" -eq "$expected_new_review_uri_fields" && "$placeholder_new_review_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonplaceholder_new_review_uri_fields" \
    "$expected_new_review_uri_fields" \
    "$placeholder_new_review_uri_fields"
  printf "publication-result-review-proof-bindings,%s,bound=%d/%d/%d/%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$canonical_confirmation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$content_digest_manifest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reviewer_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$canonical_confirmation_bound_rows" \
    "$content_digest_manifest_bound_rows" \
    "$publication_review_bound_rows" \
    "$result_review_bound_rows" \
    "$publication_record_bound_rows" \
    "$result_record_bound_rows" \
    "$reviewer_identity_bound_rows" \
    "$publication_authority_bound_rows" \
    "$result_authority_bound_rows"
  printf "publication-result-review-declarations,%s,independent=%d publication=%d result=%d canonical_match=%d non_fixture=%d fixture_free=%d timestamps=%d\n" \
    "$([[ "$independent_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_observed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_observed_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$canonical_result_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$independent_review_declared_rows" \
    "$publication_observed_declared_rows" \
    "$result_observed_declared_rows" \
    "$canonical_result_match_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows"
  printf "publication-result-review,%s,ready=%d action=%s\n" \
    "$([[ "$publication_result_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$publication_result_review_ready" \
    "$action"
  printf "real-external-benchmark,blocked,real_external_benchmark_verified=%d action=%s\n" \
    "$real_external_benchmark_verified" \
    "$action"
  printf "jump-guardrail,%s,routing=%.6f active_jump=%.6f\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "publication_result_review: $REVIEW_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
