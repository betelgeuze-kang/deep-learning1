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

PREFIX="v08_external_benchmark_authority_promotion_evidence"
AJ_PREFIX="v08_external_benchmark_live_publication_result_ingestion"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_authority_promotion_evidence_smoke"
  AJ_PREFIX="v08_external_benchmark_live_publication_result_ingestion_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_authority_promotion_evidence_full"
  AJ_PREFIX="v08_external_benchmark_live_publication_result_ingestion_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_publication_result_ingestion.sh" "${RUN_ARGS[@]}" >/dev/null

AJ_SUMMARY_CSV="$RESULTS_DIR/${AJ_PREFIX}_summary.csv"
INGESTION_CSV="${V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV:-$RESULTS_DIR/${AJ_PREFIX}_ingestion.csv}"
AUTHORITY_CSV="$RESULTS_DIR/${PREFIX}_authority.csv"
AUTHORITY_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
AUTHORITY_HASH_FIELDS_PER_ROW=14
AUTHORITY_URI_FIELDS_PER_ROW=14
AUTHORITY_NEW_ARTIFACT_URI_FIELDS_PER_ROW=10

write_authority_header() {
  echo "benchmark_family,reproduction_id,release_id,live_publication_record_uri,live_publication_record_hash,live_result_record_uri,live_result_record_hash,publication_content_digest_uri,publication_content_digest_hash,result_content_digest_uri,result_content_digest_hash,authority_decision_uri,authority_decision_hash,promotion_review_uri,promotion_review_hash,benchmark_registry_entry_uri,benchmark_registry_entry_hash,leaderboard_entry_uri,leaderboard_entry_hash,reproducibility_package_uri,reproducibility_package_hash,artifact_archive_uri,artifact_archive_hash,authority_identity_uri,authority_identity_hash,authority_conflict_disclosure_uri,authority_conflict_disclosure_hash,promotion_trace_uri,promotion_trace_hash,final_claim_packet_uri,final_claim_packet_hash,promoted_at_utc,live_publication_record_bound,live_result_record_bound,publication_content_digest_bound,result_content_digest_bound,authority_decision_bound,promotion_review_bound,benchmark_registry_entry_bound,leaderboard_entry_bound,reproducibility_package_bound,artifact_archive_bound,authority_identity_bound,authority_conflict_disclosure_bound,promotion_trace_bound,final_claim_packet_bound,independent_authority_declared,official_result_authority_declared,benchmark_owner_registry_declared,publication_result_consistent_declared,claim_scope_limited_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ak column: " column > "/dev/stderr"
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
        print "missing v08-ak summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_AUTHORITY_PROMOTION_EVIDENCE_CSV:-}" ]]; then
  AUTHORITY_CSV="$V08_EXTERNAL_BENCHMARK_AUTHORITY_PROMOTION_EVIDENCE_CSV"
  AUTHORITY_SOURCE="provided-csv"
  if [[ ! -s "$AUTHORITY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_AUTHORITY_PROMOTION_EVIDENCE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_authority_header >"$AUTHORITY_CSV"
fi

live_publication_result_ingestion_ready="$(csv_value "$AJ_SUMMARY_CSV" "live_publication_result_ingestion_ready")"
ingestion_rows_upstream="$(csv_value "$AJ_SUMMARY_CSV" "ingestion_rows")"
ingestion_expected_families="$(csv_value "$AJ_SUMMARY_CSV" "expected_external_families")"
ingestion_real_external="$(csv_value "$AJ_SUMMARY_CSV" "real_external_benchmark_verified")"
ingestion_action="$(csv_value "$AJ_SUMMARY_CSV" "action")"
ingestion_routing="$(csv_value "$AJ_SUMMARY_CSV" "routing_trigger_rate")"
ingestion_jump="$(csv_value "$AJ_SUMMARY_CSV" "active_jump_rate")"

declare -A ingestion_reproduction_id=()
declare -A ingestion_release_id=()
declare -A live_publication_record_uri_by_family=()
declare -A live_publication_record_hash_by_family=()
declare -A live_result_record_uri_by_family=()
declare -A live_result_record_hash_by_family=()
declare -A publication_content_digest_uri_by_family=()
declare -A publication_content_digest_hash_by_family=()
declare -A result_content_digest_uri_by_family=()
declare -A result_content_digest_hash_by_family=()
declare -A ingestion_family_seen=()
ingestion_family_rows=0
INGESTION_TSV="$TMP_DIR/live_publication_result_ingestion_rows.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id live_publication_record_uri live_publication_record_hash live_result_record_uri live_result_record_hash publication_content_digest_uri publication_content_digest_hash result_content_digest_uri result_content_digest_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ak upstream ingestion column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ak upstream ingestion row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$INGESTION_CSV" >"$INGESTION_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id live_publication_record_uri live_publication_record_hash live_result_record_uri live_result_record_hash publication_content_digest_uri publication_content_digest_hash result_content_digest_uri result_content_digest_hash; do
  ingestion_reproduction_id["$benchmark_family"]="$reproduction_id"
  ingestion_release_id["$benchmark_family"]="$release_id"
  live_publication_record_uri_by_family["$benchmark_family"]="$live_publication_record_uri"
  live_publication_record_hash_by_family["$benchmark_family"]="$live_publication_record_hash"
  live_result_record_uri_by_family["$benchmark_family"]="$live_result_record_uri"
  live_result_record_hash_by_family["$benchmark_family"]="$live_result_record_hash"
  publication_content_digest_uri_by_family["$benchmark_family"]="$publication_content_digest_uri"
  publication_content_digest_hash_by_family["$benchmark_family"]="$publication_content_digest_hash"
  result_content_digest_uri_by_family["$benchmark_family"]="$result_content_digest_uri"
  result_content_digest_hash_by_family["$benchmark_family"]="$result_content_digest_hash"
  ingestion_family_seen["$benchmark_family"]=1
done <"$INGESTION_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${ingestion_family_seen[$family]:-}" ]]; then
    ((ingestion_family_rows += 1))
  fi
done

authority_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_ingestion_family_rows=0
reproduction_id_match_rows=0
release_id_match_rows=0
live_publication_record_match_rows=0
live_result_record_match_rows=0
publication_content_digest_match_rows=0
result_content_digest_match_rows=0
required_authority_hash_fields=0
authority_hash_attested_fields=0
required_authority_uri_fields=0
nonlocal_authority_uri_fields=0
local_authority_uri_fields=0
required_new_authority_uri_fields=0
nonplaceholder_new_authority_uri_fields=0
placeholder_new_authority_uri_fields=0
live_publication_record_bound_rows=0
live_result_record_bound_rows=0
publication_content_digest_bound_rows=0
result_content_digest_bound_rows=0
authority_decision_bound_rows=0
promotion_review_bound_rows=0
benchmark_registry_entry_bound_rows=0
leaderboard_entry_bound_rows=0
reproducibility_package_bound_rows=0
artifact_archive_bound_rows=0
authority_identity_bound_rows=0
authority_conflict_disclosure_bound_rows=0
promotion_trace_bound_rows=0
final_claim_packet_bound_rows=0
independent_authority_declared_rows=0
official_result_authority_declared_rows=0
benchmark_owner_registry_declared_rows=0
publication_result_consistent_declared_rows=0
claim_scope_limited_declared_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
authority_routing="0.000000"
authority_jump="0.000000"
declare -A authority_family_seen=()

AUTHORITY_TSV="$TMP_DIR/authority_promotion_evidence.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id live_publication_record_uri live_publication_record_hash live_result_record_uri live_result_record_hash publication_content_digest_uri publication_content_digest_hash result_content_digest_uri result_content_digest_hash authority_decision_uri authority_decision_hash promotion_review_uri promotion_review_hash benchmark_registry_entry_uri benchmark_registry_entry_hash leaderboard_entry_uri leaderboard_entry_hash reproducibility_package_uri reproducibility_package_hash artifact_archive_uri artifact_archive_hash authority_identity_uri authority_identity_hash authority_conflict_disclosure_uri authority_conflict_disclosure_hash promotion_trace_uri promotion_trace_hash final_claim_packet_uri final_claim_packet_hash promoted_at_utc live_publication_record_bound live_result_record_bound publication_content_digest_bound result_content_digest_bound authority_decision_bound promotion_review_bound benchmark_registry_entry_bound leaderboard_entry_bound reproducibility_package_bound artifact_archive_bound authority_identity_bound authority_conflict_disclosure_bound promotion_trace_bound final_claim_packet_bound independent_authority_declared official_result_authority_declared benchmark_owner_registry_declared publication_result_consistent_declared claim_scope_limited_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ak authority column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ak authority row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$AUTHORITY_CSV" >"$AUTHORITY_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id live_publication_record_uri live_publication_record_hash live_result_record_uri live_result_record_hash publication_content_digest_uri publication_content_digest_hash result_content_digest_uri result_content_digest_hash authority_decision_uri authority_decision_hash promotion_review_uri promotion_review_hash benchmark_registry_entry_uri benchmark_registry_entry_hash leaderboard_entry_uri leaderboard_entry_hash reproducibility_package_uri reproducibility_package_hash artifact_archive_uri artifact_archive_hash authority_identity_uri authority_identity_hash authority_conflict_disclosure_uri authority_conflict_disclosure_hash promotion_trace_uri promotion_trace_hash final_claim_packet_uri final_claim_packet_hash promoted_at_utc live_publication_record_bound live_result_record_bound publication_content_digest_bound result_content_digest_bound authority_decision_bound promotion_review_bound benchmark_registry_entry_bound leaderboard_entry_bound reproducibility_package_bound artifact_archive_bound authority_identity_bound authority_conflict_disclosure_bound promotion_trace_bound final_claim_packet_bound independent_authority_declared official_result_authority_declared benchmark_owner_registry_declared publication_result_consistent_declared claim_scope_limited_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((authority_rows += 1))

  if [[ -n "${authority_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  authority_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${ingestion_release_id[$benchmark_family]:-}" ]]; then
    ((matched_ingestion_family_rows += 1))
  fi
  if [[ -n "${ingestion_reproduction_id[$benchmark_family]:-}" &&
        "$reproduction_id" == "${ingestion_reproduction_id[$benchmark_family]}" ]]; then
    ((reproduction_id_match_rows += 1))
  fi
  if [[ -n "${ingestion_release_id[$benchmark_family]:-}" &&
        "$release_id" == "${ingestion_release_id[$benchmark_family]}" ]]; then
    ((release_id_match_rows += 1))
  fi
  if [[ -n "${live_publication_record_uri_by_family[$benchmark_family]:-}" &&
        "$live_publication_record_uri" == "${live_publication_record_uri_by_family[$benchmark_family]}" &&
        "$live_publication_record_hash" == "${live_publication_record_hash_by_family[$benchmark_family]}" ]]; then
    ((live_publication_record_match_rows += 1))
  fi
  if [[ -n "${live_result_record_uri_by_family[$benchmark_family]:-}" &&
        "$live_result_record_uri" == "${live_result_record_uri_by_family[$benchmark_family]}" &&
        "$live_result_record_hash" == "${live_result_record_hash_by_family[$benchmark_family]}" ]]; then
    ((live_result_record_match_rows += 1))
  fi
  if [[ -n "${publication_content_digest_uri_by_family[$benchmark_family]:-}" &&
        "$publication_content_digest_uri" == "${publication_content_digest_uri_by_family[$benchmark_family]}" &&
        "$publication_content_digest_hash" == "${publication_content_digest_hash_by_family[$benchmark_family]}" ]]; then
    ((publication_content_digest_match_rows += 1))
  fi
  if [[ -n "${result_content_digest_uri_by_family[$benchmark_family]:-}" &&
        "$result_content_digest_uri" == "${result_content_digest_uri_by_family[$benchmark_family]}" &&
        "$result_content_digest_hash" == "${result_content_digest_hash_by_family[$benchmark_family]}" ]]; then
    ((result_content_digest_match_rows += 1))
  fi

  for pair in \
    "$live_publication_record_uri|$live_publication_record_hash" \
    "$live_result_record_uri|$live_result_record_hash" \
    "$publication_content_digest_uri|$publication_content_digest_hash" \
    "$result_content_digest_uri|$result_content_digest_hash" \
    "$authority_decision_uri|$authority_decision_hash" \
    "$promotion_review_uri|$promotion_review_hash" \
    "$benchmark_registry_entry_uri|$benchmark_registry_entry_hash" \
    "$leaderboard_entry_uri|$leaderboard_entry_hash" \
    "$reproducibility_package_uri|$reproducibility_package_hash" \
    "$artifact_archive_uri|$artifact_archive_hash" \
    "$authority_identity_uri|$authority_identity_hash" \
    "$authority_conflict_disclosure_uri|$authority_conflict_disclosure_hash" \
    "$promotion_trace_uri|$promotion_trace_hash" \
    "$final_claim_packet_uri|$final_claim_packet_hash"; do
    ((required_authority_hash_fields += 1))
    ((required_authority_uri_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((authority_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_authority_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_authority_uri_fields += 1))
    fi
  done

  for uri in \
    "$authority_decision_uri" \
    "$promotion_review_uri" \
    "$benchmark_registry_entry_uri" \
    "$leaderboard_entry_uri" \
    "$reproducibility_package_uri" \
    "$artifact_archive_uri" \
    "$authority_identity_uri" \
    "$authority_conflict_disclosure_uri" \
    "$promotion_trace_uri" \
    "$final_claim_packet_uri"; do
    ((required_new_authority_uri_fields += 1))
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_new_authority_uri_fields += 1))
    else
      ((placeholder_new_authority_uri_fields += 1))
    fi
  done

  [[ "$live_publication_record_bound" == "1" ]] && ((live_publication_record_bound_rows += 1))
  [[ "$live_result_record_bound" == "1" ]] && ((live_result_record_bound_rows += 1))
  [[ "$publication_content_digest_bound" == "1" ]] && ((publication_content_digest_bound_rows += 1))
  [[ "$result_content_digest_bound" == "1" ]] && ((result_content_digest_bound_rows += 1))
  [[ "$authority_decision_bound" == "1" ]] && ((authority_decision_bound_rows += 1))
  [[ "$promotion_review_bound" == "1" ]] && ((promotion_review_bound_rows += 1))
  [[ "$benchmark_registry_entry_bound" == "1" ]] && ((benchmark_registry_entry_bound_rows += 1))
  [[ "$leaderboard_entry_bound" == "1" ]] && ((leaderboard_entry_bound_rows += 1))
  [[ "$reproducibility_package_bound" == "1" ]] && ((reproducibility_package_bound_rows += 1))
  [[ "$artifact_archive_bound" == "1" ]] && ((artifact_archive_bound_rows += 1))
  [[ "$authority_identity_bound" == "1" ]] && ((authority_identity_bound_rows += 1))
  [[ "$authority_conflict_disclosure_bound" == "1" ]] && ((authority_conflict_disclosure_bound_rows += 1))
  [[ "$promotion_trace_bound" == "1" ]] && ((promotion_trace_bound_rows += 1))
  [[ "$final_claim_packet_bound" == "1" ]] && ((final_claim_packet_bound_rows += 1))
  [[ "$independent_authority_declared" == "1" ]] && ((independent_authority_declared_rows += 1))
  [[ "$official_result_authority_declared" == "1" ]] && ((official_result_authority_declared_rows += 1))
  [[ "$benchmark_owner_registry_declared" == "1" ]] && ((benchmark_owner_registry_declared_rows += 1))
  [[ "$publication_result_consistent_declared" == "1" ]] && ((publication_result_consistent_declared_rows += 1))
  [[ "$claim_scope_limited_declared" == "1" ]] && ((claim_scope_limited_declared_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$promoted_at_utc" && ((timestamp_rows += 1))
  authority_routing="$(awk -v a="$authority_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  authority_jump="$(awk -v a="$authority_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$AUTHORITY_TSV"

authority_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${authority_family_seen[$family]:-}" ]]; then
    ((authority_family_coverage += 1))
  fi
done

expected_authority_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * AUTHORITY_HASH_FIELDS_PER_ROW))
expected_authority_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * AUTHORITY_URI_FIELDS_PER_ROW))
expected_new_authority_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * AUTHORITY_NEW_ARTIFACT_URI_FIELDS_PER_ROW))
authority_promotion_evidence_ready=0
if [[ "$live_publication_result_ingestion_ready" == "1" &&
      "$ingestion_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$authority_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$authority_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_ingestion_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_publication_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_result_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_content_digest_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_content_digest_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_authority_hash_fields" -eq "$expected_authority_hash_fields" &&
      "$authority_hash_attested_fields" -eq "$expected_authority_hash_fields" &&
      "$required_authority_uri_fields" -eq "$expected_authority_uri_fields" &&
      "$nonlocal_authority_uri_fields" -eq "$expected_authority_uri_fields" &&
      "$local_authority_uri_fields" -eq 0 &&
      "$required_new_authority_uri_fields" -eq "$expected_new_authority_uri_fields" &&
      "$nonplaceholder_new_authority_uri_fields" -eq "$expected_new_authority_uri_fields" &&
      "$placeholder_new_authority_uri_fields" -eq 0 &&
      "$live_publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$authority_decision_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$promotion_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$benchmark_registry_entry_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$leaderboard_entry_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproducibility_package_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$artifact_archive_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$authority_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$authority_conflict_disclosure_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$promotion_trace_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$final_claim_packet_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_authority_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$official_result_authority_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$benchmark_owner_registry_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_result_consistent_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$claim_scope_limited_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$authority_routing" == "0.000000" &&
      "$authority_jump" == "0.000000" ]]; then
  authority_promotion_evidence_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$ingestion_routing" -v b="$authority_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$ingestion_jump" -v b="$authority_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-live-publication-result-ingestion-not-ready"
if [[ "$live_publication_result_ingestion_ready" != "1" ]]; then
  action="external-benchmark-live-publication-result-ingestion-not-ready"
elif [[ "$authority_rows" -eq 0 ]]; then
  action="external-benchmark-authority-promotion-evidence-missing"
elif [[ "$authority_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$authority_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-authority-promotion-evidence-coverage-incomplete"
elif [[ "$matched_ingestion_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-authority-promotion-evidence-binding-mismatch"
elif [[ "$live_publication_record_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_result_record_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_content_digest_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_content_digest_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-authority-promotion-evidence-ingestion-artifact-mismatch"
elif [[ "$required_authority_hash_fields" -ne "$expected_authority_hash_fields" ||
        "$authority_hash_attested_fields" -ne "$expected_authority_hash_fields" ]]; then
  action="external-benchmark-authority-promotion-evidence-hash-attestation-missing"
elif [[ "$required_authority_uri_fields" -ne "$expected_authority_uri_fields" ||
        "$nonlocal_authority_uri_fields" -ne "$expected_authority_uri_fields" ||
        "$local_authority_uri_fields" -ne 0 ]]; then
  action="external-benchmark-authority-promotion-evidence-local-artifact-uri"
elif [[ "$required_new_authority_uri_fields" -ne "$expected_new_authority_uri_fields" ||
        "$nonplaceholder_new_authority_uri_fields" -ne "$expected_new_authority_uri_fields" ||
        "$placeholder_new_authority_uri_fields" -ne 0 ]]; then
  action="external-benchmark-authority-promotion-evidence-placeholder-artifact-uri"
elif [[ "$live_publication_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_result_record_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_content_digest_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_content_digest_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$authority_decision_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$promotion_review_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$benchmark_registry_entry_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$leaderboard_entry_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproducibility_package_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$artifact_archive_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$authority_identity_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$authority_conflict_disclosure_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$promotion_trace_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$final_claim_packet_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-authority-promotion-evidence-proof-binding-missing"
elif [[ "$independent_authority_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$official_result_authority_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$benchmark_owner_registry_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_result_consistent_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$claim_scope_limited_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-authority-promotion-evidence-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-authority-promotion-evidence-jump-guardrail-violated"
elif [[ "$authority_promotion_evidence_ready" == "1" ]]; then
  action="external-benchmark-authority-promotion-evidence-ready-await-real-external-benchmark-run-evidence"
fi

{
  echo "benchmark_scope,authority_source,live_publication_result_ingestion_ready,ingestion_rows,ingestion_expected_families,ingestion_real_external,ingestion_action,ingestion_family_rows,authority_rows,expected_family_rows,duplicate_family_rows,matched_ingestion_family_rows,reproduction_id_match_rows,release_id_match_rows,live_publication_record_match_rows,live_result_record_match_rows,publication_content_digest_match_rows,result_content_digest_match_rows,required_authority_hash_fields,authority_hash_attested_fields,required_authority_uri_fields,nonlocal_authority_uri_fields,local_authority_uri_fields,required_new_authority_uri_fields,nonplaceholder_new_authority_uri_fields,placeholder_new_authority_uri_fields,live_publication_record_bound_rows,live_result_record_bound_rows,publication_content_digest_bound_rows,result_content_digest_bound_rows,authority_decision_bound_rows,promotion_review_bound_rows,benchmark_registry_entry_bound_rows,leaderboard_entry_bound_rows,reproducibility_package_bound_rows,artifact_archive_bound_rows,authority_identity_bound_rows,authority_conflict_disclosure_bound_rows,promotion_trace_bound_rows,final_claim_packet_bound_rows,independent_authority_declared_rows,official_result_authority_declared_rows,benchmark_owner_registry_declared_rows,publication_result_consistent_declared_rows,claim_scope_limited_declared_rows,non_fixture_declared_rows,fixture_free_rows,timestamp_rows,authority_family_coverage,expected_external_families,authority_promotion_evidence_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ak,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$AUTHORITY_SOURCE" \
    "$live_publication_result_ingestion_ready" \
    "$ingestion_rows_upstream" \
    "$ingestion_expected_families" \
    "$ingestion_real_external" \
    "$ingestion_action" \
    "$ingestion_family_rows" \
    "$authority_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_ingestion_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$live_publication_record_match_rows" \
    "$live_result_record_match_rows" \
    "$publication_content_digest_match_rows" \
    "$result_content_digest_match_rows" \
    "$required_authority_hash_fields" \
    "$authority_hash_attested_fields" \
    "$required_authority_uri_fields" \
    "$nonlocal_authority_uri_fields" \
    "$local_authority_uri_fields" \
    "$required_new_authority_uri_fields" \
    "$nonplaceholder_new_authority_uri_fields" \
    "$placeholder_new_authority_uri_fields" \
    "$live_publication_record_bound_rows" \
    "$live_result_record_bound_rows" \
    "$publication_content_digest_bound_rows" \
    "$result_content_digest_bound_rows" \
    "$authority_decision_bound_rows" \
    "$promotion_review_bound_rows" \
    "$benchmark_registry_entry_bound_rows" \
    "$leaderboard_entry_bound_rows" \
    "$reproducibility_package_bound_rows" \
    "$artifact_archive_bound_rows" \
    "$authority_identity_bound_rows" \
    "$authority_conflict_disclosure_bound_rows" \
    "$promotion_trace_bound_rows" \
    "$final_claim_packet_bound_rows" \
    "$independent_authority_declared_rows" \
    "$official_result_authority_declared_rows" \
    "$benchmark_owner_registry_declared_rows" \
    "$publication_result_consistent_declared_rows" \
    "$claim_scope_limited_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$authority_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$authority_promotion_evidence_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "live-publication-result-ingestion,%s,ready=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$live_publication_result_ingestion_ready" == "1" ]] && echo pass || echo blocked)" \
    "$live_publication_result_ingestion_ready" \
    "$ingestion_rows_upstream" \
    "$ingestion_expected_families" \
    "$ingestion_real_external" \
    "$ingestion_action"
  printf "authority-promotion-evidence-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$authority_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$authority_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$authority_rows" \
    "$expected_family_rows" \
    "$authority_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "authority-promotion-evidence-binding,%s,matched=%d reproduction=%d release=%d live_records=%d/%d digests=%d/%d\n" \
    "$([[ "$matched_ingestion_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_publication_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_result_record_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_content_digest_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_content_digest_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_ingestion_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$live_publication_record_match_rows" \
    "$live_result_record_match_rows" \
    "$publication_content_digest_match_rows" \
    "$result_content_digest_match_rows"
  printf "authority-promotion-evidence-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_authority_hash_fields" -eq "$expected_authority_hash_fields" && "$authority_hash_attested_fields" -eq "$expected_authority_hash_fields" ]] && echo pass || echo blocked)" \
    "$authority_hash_attested_fields" \
    "$expected_authority_hash_fields"
  printf "nonlocal-authority-promotion-evidence-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$required_authority_uri_fields" -eq "$expected_authority_uri_fields" && "$nonlocal_authority_uri_fields" -eq "$expected_authority_uri_fields" && "$local_authority_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_authority_uri_fields" \
    "$expected_authority_uri_fields" \
    "$local_authority_uri_fields"
  printf "nonplaceholder-authority-promotion-evidence-artifacts,%s,nonplaceholder=%d/%d placeholder=%d\n" \
    "$([[ "$required_new_authority_uri_fields" -eq "$expected_new_authority_uri_fields" && "$nonplaceholder_new_authority_uri_fields" -eq "$expected_new_authority_uri_fields" && "$placeholder_new_authority_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonplaceholder_new_authority_uri_fields" \
    "$expected_new_authority_uri_fields" \
    "$placeholder_new_authority_uri_fields"
  printf "authority-promotion-evidence-proof-bindings,%s,bound=%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$live_publication_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_result_record_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_content_digest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$authority_decision_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$promotion_review_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$benchmark_registry_entry_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$leaderboard_entry_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproducibility_package_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$artifact_archive_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$authority_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$authority_conflict_disclosure_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$promotion_trace_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$final_claim_packet_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$live_publication_record_bound_rows" \
    "$live_result_record_bound_rows" \
    "$publication_content_digest_bound_rows" \
    "$result_content_digest_bound_rows" \
    "$authority_decision_bound_rows" \
    "$promotion_review_bound_rows" \
    "$benchmark_registry_entry_bound_rows" \
    "$leaderboard_entry_bound_rows" \
    "$reproducibility_package_bound_rows" \
    "$artifact_archive_bound_rows" \
    "$authority_identity_bound_rows" \
    "$authority_conflict_disclosure_bound_rows" \
    "$promotion_trace_bound_rows" \
    "$final_claim_packet_bound_rows"
  printf "authority-promotion-evidence-declarations,%s,independent=%d official=%d registry=%d consistent=%d limited=%d non_fixture=%d fixture_free=%d timestamps=%d\n" \
    "$([[ "$independent_authority_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$official_result_authority_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$benchmark_owner_registry_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_result_consistent_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$claim_scope_limited_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$independent_authority_declared_rows" \
    "$official_result_authority_declared_rows" \
    "$benchmark_owner_registry_declared_rows" \
    "$publication_result_consistent_declared_rows" \
    "$claim_scope_limited_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows"
  printf "authority-promotion-evidence,%s,ready=%d action=%s\n" \
    "$([[ "$authority_promotion_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$authority_promotion_evidence_ready" \
    "$action"
  printf "real-external-benchmark,blocked,real_external_benchmark_verified=%d action=%s\n" \
    "$real_external_benchmark_verified" \
    "$action"
  printf "jump-guardrail,%s,routing=%.6f active_jump=%.6f\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "authority_promotion_evidence: $AUTHORITY_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
