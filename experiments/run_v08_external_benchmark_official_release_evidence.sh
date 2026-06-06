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

PREFIX="v08_external_benchmark_official_release_evidence"
AE_PREFIX="v08_external_benchmark_independent_reproduction_review"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_official_release_evidence_smoke"
  AE_PREFIX="v08_external_benchmark_independent_reproduction_review_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_official_release_evidence_full"
  AE_PREFIX="v08_external_benchmark_independent_reproduction_review_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_independent_reproduction_review.sh" "${RUN_ARGS[@]}" >/dev/null

AE_SUMMARY_CSV="$RESULTS_DIR/${AE_PREFIX}_summary.csv"
REPRODUCTION_CSV="${V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV:-$RESULTS_DIR/${AE_PREFIX}_reproduction.csv}"
RELEASE_CSV="$RESULTS_DIR/${PREFIX}_release.csv"
RELEASE_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
RELEASE_HASH_FIELDS_PER_ROW=11
RELEASE_URI_FIELDS_PER_ROW=10

write_release_header() {
  echo "benchmark_family,reproduction_id,release_id,independent_reproduction_summary_uri,independent_reproduction_summary_hash,release_package_uri,release_package_hash,release_manifest_uri,release_manifest_hash,official_release_record_uri,official_release_record_hash,public_archive_record_uri,public_archive_record_hash,dataset_version_record_uri,dataset_version_record_hash,license_notice_uri,license_notice_hash,reproducibility_bundle_uri,reproducibility_bundle_hash,review_decision_uri,review_decision_hash,artifact_index_uri,artifact_index_hash,release_authority_uri,release_authority_hash,independent_reproduction_bound,release_package_bound,release_manifest_bound,official_release_bound,public_archive_bound,dataset_version_bound,license_bound,reproducibility_bound,review_decision_bound,artifact_index_bound,release_authority_bound,official_release_declared,public_archive_declared,stable_version_declared,license_compatible_declared,reproducibility_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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

hash_matches_uri() {
  local uri="$1"
  local expected="$2"
  local path
  local expected_hex
  local actual_hex

  is_sha256 "$expected" || return 1
  path="$(uri_to_local_path "$uri")" || return 1
  [[ -f "$path" ]] || return 1
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
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
        print "missing v08-af column: " column > "/dev/stderr"
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
        print "missing v08-af summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV:-}" ]]; then
  RELEASE_CSV="$V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV"
  RELEASE_SOURCE="provided-csv"
  if [[ ! -s "$RELEASE_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_release_header >"$RELEASE_CSV"
fi

independent_reproduction_review_ready="$(csv_value "$AE_SUMMARY_CSV" "independent_reproduction_review_ready")"
reproduction_rows="$(csv_value "$AE_SUMMARY_CSV" "reproduction_rows")"
reproduction_expected_families="$(csv_value "$AE_SUMMARY_CSV" "expected_external_families")"
reproduction_real_external="$(csv_value "$AE_SUMMARY_CSV" "real_external_benchmark_verified")"
reproduction_action="$(csv_value "$AE_SUMMARY_CSV" "action")"
reproduction_routing="$(csv_value "$AE_SUMMARY_CSV" "routing_trigger_rate")"
reproduction_jump="$(csv_value "$AE_SUMMARY_CSV" "active_jump_rate")"

declare -A reproduction_id_by_family=()
declare -A reproduction_family_seen=()
reproduction_family_rows=0
REPRODUCTION_TSV="$TMP_DIR/reproduction_rows.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-af reproduction column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-af reproduction row has wrong column count", 14)
    printf "%s\t%s\n", $idx["benchmark_family"], $idx["reproduction_id"]
  }
' "$REPRODUCTION_CSV" >"$REPRODUCTION_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id; do
  reproduction_id_by_family["$benchmark_family"]="$reproduction_id"
  reproduction_family_seen["$benchmark_family"]=1
done <"$REPRODUCTION_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${reproduction_family_seen[$family]:-}" ]]; then
    ((reproduction_family_rows += 1))
  fi
done

release_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_reproduction_family_rows=0
reproduction_id_match_rows=0
independent_reproduction_summary_hash_verified_rows=0
required_release_hash_fields=0
release_hash_attested_fields=0
required_release_uri_fields=0
nonlocal_release_uri_fields=0
local_release_uri_fields=0
release_package_bound_rows=0
release_manifest_bound_rows=0
official_release_bound_rows=0
public_archive_bound_rows=0
dataset_version_bound_rows=0
license_bound_rows=0
reproducibility_bound_rows=0
review_decision_bound_rows=0
artifact_index_bound_rows=0
release_authority_bound_rows=0
independent_reproduction_bound_rows=0
official_release_declared_rows=0
public_archive_declared_rows=0
stable_version_declared_rows=0
license_compatible_declared_rows=0
reproducibility_declared_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
release_routing="0.000000"
release_jump="0.000000"
declare -A release_family_seen=()

RELEASE_TSV="$TMP_DIR/official_release.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id independent_reproduction_summary_uri independent_reproduction_summary_hash release_package_uri release_package_hash release_manifest_uri release_manifest_hash official_release_record_uri official_release_record_hash public_archive_record_uri public_archive_record_hash dataset_version_record_uri dataset_version_record_hash license_notice_uri license_notice_hash reproducibility_bundle_uri reproducibility_bundle_hash review_decision_uri review_decision_hash artifact_index_uri artifact_index_hash release_authority_uri release_authority_hash independent_reproduction_bound release_package_bound release_manifest_bound official_release_bound public_archive_bound dataset_version_bound license_bound reproducibility_bound review_decision_bound artifact_index_bound release_authority_bound official_release_declared public_archive_declared stable_version_declared license_compatible_declared reproducibility_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-af release column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-af release row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$RELEASE_CSV" >"$RELEASE_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id independent_reproduction_summary_uri independent_reproduction_summary_hash release_package_uri release_package_hash release_manifest_uri release_manifest_hash official_release_record_uri official_release_record_hash public_archive_record_uri public_archive_record_hash dataset_version_record_uri dataset_version_record_hash license_notice_uri license_notice_hash reproducibility_bundle_uri reproducibility_bundle_hash review_decision_uri review_decision_hash artifact_index_uri artifact_index_hash release_authority_uri release_authority_hash independent_reproduction_bound release_package_bound release_manifest_bound official_release_bound public_archive_bound dataset_version_bound license_bound reproducibility_bound review_decision_bound artifact_index_bound release_authority_bound official_release_declared public_archive_declared stable_version_declared license_compatible_declared reproducibility_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((release_rows += 1))

  if [[ -n "${release_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  release_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${reproduction_id_by_family[$benchmark_family]:-}" ]]; then
    ((matched_reproduction_family_rows += 1))
  fi
  if [[ -n "${reproduction_id_by_family[$benchmark_family]:-}" &&
        "$reproduction_id" == "${reproduction_id_by_family[$benchmark_family]}" ]]; then
    ((reproduction_id_match_rows += 1))
  fi
  if hash_matches_uri "$independent_reproduction_summary_uri" "$independent_reproduction_summary_hash"; then
    ((independent_reproduction_summary_hash_verified_rows += 1))
  fi

  ((required_release_hash_fields += 1))
  if is_sha256 "$independent_reproduction_summary_hash"; then
    ((release_hash_attested_fields += 1))
  fi

  for pair in \
    "$release_package_uri|$release_package_hash" \
    "$release_manifest_uri|$release_manifest_hash" \
    "$official_release_record_uri|$official_release_record_hash" \
    "$public_archive_record_uri|$public_archive_record_hash" \
    "$dataset_version_record_uri|$dataset_version_record_hash" \
    "$license_notice_uri|$license_notice_hash" \
    "$reproducibility_bundle_uri|$reproducibility_bundle_hash" \
    "$review_decision_uri|$review_decision_hash" \
    "$artifact_index_uri|$artifact_index_hash" \
    "$release_authority_uri|$release_authority_hash"; do
    ((required_release_hash_fields += 1))
    ((required_release_uri_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((release_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_release_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_release_uri_fields += 1))
    fi
  done

  [[ "$independent_reproduction_bound" == "1" ]] && ((independent_reproduction_bound_rows += 1))
  [[ "$release_package_bound" == "1" ]] && ((release_package_bound_rows += 1))
  [[ "$release_manifest_bound" == "1" ]] && ((release_manifest_bound_rows += 1))
  [[ "$official_release_bound" == "1" ]] && ((official_release_bound_rows += 1))
  [[ "$public_archive_bound" == "1" ]] && ((public_archive_bound_rows += 1))
  [[ "$dataset_version_bound" == "1" ]] && ((dataset_version_bound_rows += 1))
  [[ "$license_bound" == "1" ]] && ((license_bound_rows += 1))
  [[ "$reproducibility_bound" == "1" ]] && ((reproducibility_bound_rows += 1))
  [[ "$review_decision_bound" == "1" ]] && ((review_decision_bound_rows += 1))
  [[ "$artifact_index_bound" == "1" ]] && ((artifact_index_bound_rows += 1))
  [[ "$release_authority_bound" == "1" ]] && ((release_authority_bound_rows += 1))
  [[ "$official_release_declared" == "1" ]] && ((official_release_declared_rows += 1))
  [[ "$public_archive_declared" == "1" ]] && ((public_archive_declared_rows += 1))
  [[ "$stable_version_declared" == "1" ]] && ((stable_version_declared_rows += 1))
  [[ "$license_compatible_declared" == "1" ]] && ((license_compatible_declared_rows += 1))
  [[ "$reproducibility_declared" == "1" ]] && ((reproducibility_declared_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  release_routing="$(awk -v a="$release_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  release_jump="$(awk -v a="$release_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$RELEASE_TSV"

release_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${release_family_seen[$family]:-}" ]]; then
    ((release_family_coverage += 1))
  fi
done

expected_release_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * RELEASE_HASH_FIELDS_PER_ROW))
expected_release_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * RELEASE_URI_FIELDS_PER_ROW))
official_release_evidence_ready=0
if [[ "$independent_reproduction_review_ready" == "1" &&
      "$reproduction_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_reproduction_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_reproduction_summary_hash_verified_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_release_hash_fields" -eq "$expected_release_hash_fields" &&
      "$release_hash_attested_fields" -eq "$expected_release_hash_fields" &&
      "$required_release_uri_fields" -eq "$expected_release_uri_fields" &&
      "$nonlocal_release_uri_fields" -eq "$expected_release_uri_fields" &&
      "$local_release_uri_fields" -eq 0 &&
      "$independent_reproduction_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_package_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_manifest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$official_release_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_archive_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$dataset_version_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$license_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproducibility_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$review_decision_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$artifact_index_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$official_release_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_archive_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$stable_version_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$license_compatible_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproducibility_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_routing" == "0.000000" &&
      "$release_jump" == "0.000000" ]]; then
  official_release_evidence_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$reproduction_routing" -v b="$release_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$reproduction_jump" -v b="$release_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-independent-reproduction-not-ready"
if [[ "$independent_reproduction_review_ready" != "1" ]]; then
  action="external-benchmark-independent-reproduction-not-ready"
elif [[ "$release_rows" -eq 0 ]]; then
  action="external-benchmark-official-release-evidence-missing"
elif [[ "$release_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-official-release-coverage-incomplete"
elif [[ "$matched_reproduction_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-official-release-reproduction-mismatch"
elif [[ "$independent_reproduction_summary_hash_verified_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-official-release-summary-hash-mismatch"
elif [[ "$required_release_hash_fields" -ne "$expected_release_hash_fields" ||
        "$release_hash_attested_fields" -ne "$expected_release_hash_fields" ]]; then
  action="external-benchmark-official-release-hash-attestation-missing"
elif [[ "$required_release_uri_fields" -ne "$expected_release_uri_fields" ||
        "$nonlocal_release_uri_fields" -ne "$expected_release_uri_fields" ||
        "$local_release_uri_fields" -ne 0 ]]; then
  action="external-benchmark-official-release-local-artifact-uri"
elif [[ "$independent_reproduction_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_package_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_manifest_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$official_release_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$public_archive_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$dataset_version_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$license_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproducibility_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$review_decision_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$artifact_index_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_authority_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-official-release-binding-missing"
elif [[ "$official_release_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$public_archive_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$stable_version_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$license_compatible_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproducibility_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-official-release-declaration-missing"
elif [[ "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-official-release-fixture-only"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-official-release-jump-guardrail-violated"
elif [[ "$official_release_evidence_ready" == "1" ]]; then
  action="external-benchmark-official-release-evidence-ready-await-live-release-verification"
fi

{
  echo "benchmark_scope,release_source,independent_reproduction_review_ready,reproduction_rows,reproduction_expected_families,reproduction_real_external,reproduction_action,reproduction_family_rows,release_rows,expected_family_rows,duplicate_family_rows,matched_reproduction_family_rows,reproduction_id_match_rows,independent_reproduction_summary_hash_verified_rows,required_release_hash_fields,release_hash_attested_fields,required_release_uri_fields,nonlocal_release_uri_fields,local_release_uri_fields,independent_reproduction_bound_rows,release_package_bound_rows,release_manifest_bound_rows,official_release_bound_rows,public_archive_bound_rows,dataset_version_bound_rows,license_bound_rows,reproducibility_bound_rows,review_decision_bound_rows,artifact_index_bound_rows,release_authority_bound_rows,official_release_declared_rows,public_archive_declared_rows,stable_version_declared_rows,license_compatible_declared_rows,reproducibility_declared_rows,non_fixture_declared_rows,fixture_free_rows,release_family_coverage,expected_external_families,official_release_evidence_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08af,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$RELEASE_SOURCE" \
    "$independent_reproduction_review_ready" \
    "$reproduction_rows" \
    "$reproduction_expected_families" \
    "$reproduction_real_external" \
    "$reproduction_action" \
    "$reproduction_family_rows" \
    "$release_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_reproduction_family_rows" \
    "$reproduction_id_match_rows" \
    "$independent_reproduction_summary_hash_verified_rows" \
    "$required_release_hash_fields" \
    "$release_hash_attested_fields" \
    "$required_release_uri_fields" \
    "$nonlocal_release_uri_fields" \
    "$local_release_uri_fields" \
    "$independent_reproduction_bound_rows" \
    "$release_package_bound_rows" \
    "$release_manifest_bound_rows" \
    "$official_release_bound_rows" \
    "$public_archive_bound_rows" \
    "$dataset_version_bound_rows" \
    "$license_bound_rows" \
    "$reproducibility_bound_rows" \
    "$review_decision_bound_rows" \
    "$artifact_index_bound_rows" \
    "$release_authority_bound_rows" \
    "$official_release_declared_rows" \
    "$public_archive_declared_rows" \
    "$stable_version_declared_rows" \
    "$license_compatible_declared_rows" \
    "$reproducibility_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$release_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$official_release_evidence_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "independent-reproduction,%s,ready=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$independent_reproduction_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$independent_reproduction_review_ready" \
    "$reproduction_rows" \
    "$reproduction_expected_families" \
    "$reproduction_real_external" \
    "$reproduction_action"
  printf "release-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$release_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$release_rows" \
    "$expected_family_rows" \
    "$release_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "reproduction-binding,%s,matched=%d id_match=%d summary_hash=%d/%d\n" \
    "$([[ "$matched_reproduction_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$independent_reproduction_summary_hash_verified_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_reproduction_family_rows" \
    "$reproduction_id_match_rows" \
    "$independent_reproduction_summary_hash_verified_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "release-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_release_hash_fields" -eq "$expected_release_hash_fields" && "$release_hash_attested_fields" -eq "$expected_release_hash_fields" ]] && echo pass || echo blocked)" \
    "$release_hash_attested_fields" \
    "$expected_release_hash_fields"
  printf "nonlocal-release-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$required_release_uri_fields" -eq "$expected_release_uri_fields" && "$nonlocal_release_uri_fields" -eq "$expected_release_uri_fields" && "$local_release_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_release_uri_fields" \
    "$expected_release_uri_fields" \
    "$local_release_uri_fields"
  printf "release-bindings,%s,bound=%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$independent_reproduction_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_package_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_manifest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$official_release_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$public_archive_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$dataset_version_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$license_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproducibility_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$review_decision_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$artifact_index_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$independent_reproduction_bound_rows" \
    "$release_package_bound_rows" \
    "$release_manifest_bound_rows" \
    "$official_release_bound_rows" \
    "$public_archive_bound_rows" \
    "$dataset_version_bound_rows" \
    "$license_bound_rows" \
    "$reproducibility_bound_rows" \
    "$review_decision_bound_rows" \
    "$artifact_index_bound_rows" \
    "$release_authority_bound_rows"
  printf "release-declarations,%s,official=%d archive=%d stable=%d license=%d reproducible=%d non_fixture=%d fixture_free=%d\n" \
    "$([[ "$official_release_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$public_archive_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$stable_version_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$license_compatible_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproducibility_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$official_release_declared_rows" \
    "$public_archive_declared_rows" \
    "$stable_version_declared_rows" \
    "$license_compatible_declared_rows" \
    "$reproducibility_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows"
  printf "official-release-evidence,%s,ready=%d action=%s\n" \
    "$([[ "$official_release_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$official_release_evidence_ready" \
    "$action"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "release: $RELEASE_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
