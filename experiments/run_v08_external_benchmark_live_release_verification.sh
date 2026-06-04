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

PREFIX="v08_external_benchmark_live_release_verification"
AF_PREFIX="v08_external_benchmark_official_release_evidence"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_live_release_verification_smoke"
  AF_PREFIX="v08_external_benchmark_official_release_evidence_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_live_release_verification_full"
  AF_PREFIX="v08_external_benchmark_official_release_evidence_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_official_release_evidence.sh" "${RUN_ARGS[@]}" >/dev/null

AF_SUMMARY_CSV="$RESULTS_DIR/${AF_PREFIX}_summary.csv"
RELEASE_CSV="${V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV:-$RESULTS_DIR/${AF_PREFIX}_release.csv}"
LIVE_CSV="$RESULTS_DIR/${PREFIX}_live_verification.csv"
LIVE_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
LIVE_HASH_FIELDS_PER_ROW=7
LIVE_URI_FIELDS_PER_ROW=7

write_live_header() {
  echo "benchmark_family,reproduction_id,release_id,official_release_record_uri,official_release_record_hash,public_archive_record_uri,public_archive_record_hash,dataset_version_record_uri,dataset_version_record_hash,release_authority_uri,release_authority_hash,live_verification_report_uri,live_verification_report_hash,network_observation_uri,network_observation_hash,verifier_identity_uri,verifier_identity_hash,verified_at_utc,official_release_bound,public_archive_bound,dataset_version_bound,release_authority_bound,live_verification_report_bound,network_observation_bound,verifier_identity_bound,live_network_observed,independent_verifier_declared,stable_release_observed,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ag column: " column > "/dev/stderr"
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
        print "missing v08-ag summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV:-}" ]]; then
  LIVE_CSV="$V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV"
  LIVE_SOURCE="provided-csv"
  if [[ ! -s "$LIVE_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_live_header >"$LIVE_CSV"
fi

official_release_evidence_ready="$(csv_value "$AF_SUMMARY_CSV" "official_release_evidence_ready")"
release_rows="$(csv_value "$AF_SUMMARY_CSV" "release_rows")"
release_expected_families="$(csv_value "$AF_SUMMARY_CSV" "expected_external_families")"
release_real_external="$(csv_value "$AF_SUMMARY_CSV" "real_external_benchmark_verified")"
release_action="$(csv_value "$AF_SUMMARY_CSV" "action")"
release_routing="$(csv_value "$AF_SUMMARY_CSV" "routing_trigger_rate")"
release_jump="$(csv_value "$AF_SUMMARY_CSV" "active_jump_rate")"

declare -A release_reproduction_id=()
declare -A release_id_by_family=()
declare -A release_official_uri=()
declare -A release_official_hash=()
declare -A release_archive_uri=()
declare -A release_archive_hash=()
declare -A release_dataset_uri=()
declare -A release_dataset_hash=()
declare -A release_authority_uri=()
declare -A release_authority_hash=()
declare -A release_family_seen=()
release_family_rows=0
RELEASE_TSV="$TMP_DIR/official_release_rows.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id official_release_record_uri official_release_record_hash public_archive_record_uri public_archive_record_hash dataset_version_record_uri dataset_version_record_hash release_authority_uri release_authority_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ag upstream release column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ag upstream release row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$RELEASE_CSV" >"$RELEASE_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id official_release_record_uri official_release_record_hash public_archive_record_uri public_archive_record_hash dataset_version_record_uri dataset_version_record_hash release_authority_uri_value release_authority_hash_value; do
  release_reproduction_id["$benchmark_family"]="$reproduction_id"
  release_id_by_family["$benchmark_family"]="$release_id"
  release_official_uri["$benchmark_family"]="$official_release_record_uri"
  release_official_hash["$benchmark_family"]="$official_release_record_hash"
  release_archive_uri["$benchmark_family"]="$public_archive_record_uri"
  release_archive_hash["$benchmark_family"]="$public_archive_record_hash"
  release_dataset_uri["$benchmark_family"]="$dataset_version_record_uri"
  release_dataset_hash["$benchmark_family"]="$dataset_version_record_hash"
  release_authority_uri["$benchmark_family"]="$release_authority_uri_value"
  release_authority_hash["$benchmark_family"]="$release_authority_hash_value"
  release_family_seen["$benchmark_family"]=1
done <"$RELEASE_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${release_family_seen[$family]:-}" ]]; then
    ((release_family_rows += 1))
  fi
done

live_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_release_family_rows=0
reproduction_id_match_rows=0
release_id_match_rows=0
official_release_match_rows=0
public_archive_match_rows=0
dataset_version_match_rows=0
release_authority_match_rows=0
required_live_hash_fields=0
live_hash_attested_fields=0
required_live_uri_fields=0
nonlocal_live_uri_fields=0
local_live_uri_fields=0
official_release_bound_rows=0
public_archive_bound_rows=0
dataset_version_bound_rows=0
release_authority_bound_rows=0
live_verification_report_bound_rows=0
network_observation_bound_rows=0
verifier_identity_bound_rows=0
live_network_observed_rows=0
independent_verifier_declared_rows=0
stable_release_observed_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
live_routing="0.000000"
live_jump="0.000000"
declare -A live_family_seen=()

LIVE_TSV="$TMP_DIR/live_release_verification.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id official_release_record_uri official_release_record_hash public_archive_record_uri public_archive_record_hash dataset_version_record_uri dataset_version_record_hash release_authority_uri release_authority_hash live_verification_report_uri live_verification_report_hash network_observation_uri network_observation_hash verifier_identity_uri verifier_identity_hash verified_at_utc official_release_bound public_archive_bound dataset_version_bound release_authority_bound live_verification_report_bound network_observation_bound verifier_identity_bound live_network_observed independent_verifier_declared stable_release_observed non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ag live verification column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ag live verification row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$LIVE_CSV" >"$LIVE_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id official_release_record_uri official_release_record_hash public_archive_record_uri public_archive_record_hash dataset_version_record_uri dataset_version_record_hash release_authority_uri_value release_authority_hash_value live_verification_report_uri live_verification_report_hash network_observation_uri network_observation_hash verifier_identity_uri verifier_identity_hash verified_at_utc official_release_bound public_archive_bound dataset_version_bound release_authority_bound live_verification_report_bound network_observation_bound verifier_identity_bound live_network_observed independent_verifier_declared stable_release_observed non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((live_rows += 1))

  if [[ -n "${live_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  live_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${release_id_by_family[$benchmark_family]:-}" ]]; then
    ((matched_release_family_rows += 1))
  fi
  if [[ -n "${release_reproduction_id[$benchmark_family]:-}" &&
        "$reproduction_id" == "${release_reproduction_id[$benchmark_family]}" ]]; then
    ((reproduction_id_match_rows += 1))
  fi
  if [[ -n "${release_id_by_family[$benchmark_family]:-}" &&
        "$release_id" == "${release_id_by_family[$benchmark_family]}" ]]; then
    ((release_id_match_rows += 1))
  fi
  if [[ -n "${release_official_uri[$benchmark_family]:-}" &&
        "$official_release_record_uri" == "${release_official_uri[$benchmark_family]}" &&
        "$official_release_record_hash" == "${release_official_hash[$benchmark_family]}" ]]; then
    ((official_release_match_rows += 1))
  fi
  if [[ -n "${release_archive_uri[$benchmark_family]:-}" &&
        "$public_archive_record_uri" == "${release_archive_uri[$benchmark_family]}" &&
        "$public_archive_record_hash" == "${release_archive_hash[$benchmark_family]}" ]]; then
    ((public_archive_match_rows += 1))
  fi
  if [[ -n "${release_dataset_uri[$benchmark_family]:-}" &&
        "$dataset_version_record_uri" == "${release_dataset_uri[$benchmark_family]}" &&
        "$dataset_version_record_hash" == "${release_dataset_hash[$benchmark_family]}" ]]; then
    ((dataset_version_match_rows += 1))
  fi
  if [[ -n "${release_authority_uri[$benchmark_family]:-}" &&
        "$release_authority_uri_value" == "${release_authority_uri[$benchmark_family]}" &&
        "$release_authority_hash_value" == "${release_authority_hash[$benchmark_family]}" ]]; then
    ((release_authority_match_rows += 1))
  fi

  for pair in \
    "$official_release_record_uri|$official_release_record_hash" \
    "$public_archive_record_uri|$public_archive_record_hash" \
    "$dataset_version_record_uri|$dataset_version_record_hash" \
    "$release_authority_uri_value|$release_authority_hash_value" \
    "$live_verification_report_uri|$live_verification_report_hash" \
    "$network_observation_uri|$network_observation_hash" \
    "$verifier_identity_uri|$verifier_identity_hash"; do
    ((required_live_hash_fields += 1))
    ((required_live_uri_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((live_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_live_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_live_uri_fields += 1))
    fi
  done

  [[ "$official_release_bound" == "1" ]] && ((official_release_bound_rows += 1))
  [[ "$public_archive_bound" == "1" ]] && ((public_archive_bound_rows += 1))
  [[ "$dataset_version_bound" == "1" ]] && ((dataset_version_bound_rows += 1))
  [[ "$release_authority_bound" == "1" ]] && ((release_authority_bound_rows += 1))
  [[ "$live_verification_report_bound" == "1" ]] && ((live_verification_report_bound_rows += 1))
  [[ "$network_observation_bound" == "1" ]] && ((network_observation_bound_rows += 1))
  [[ "$verifier_identity_bound" == "1" ]] && ((verifier_identity_bound_rows += 1))
  [[ "$live_network_observed" == "1" ]] && ((live_network_observed_rows += 1))
  [[ "$independent_verifier_declared" == "1" ]] && ((independent_verifier_declared_rows += 1))
  [[ "$stable_release_observed" == "1" ]] && ((stable_release_observed_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$verified_at_utc" && ((timestamp_rows += 1))
  live_routing="$(awk -v a="$live_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  live_jump="$(awk -v a="$live_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$LIVE_TSV"

live_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${live_family_seen[$family]:-}" ]]; then
    ((live_family_coverage += 1))
  fi
done

expected_live_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * LIVE_HASH_FIELDS_PER_ROW))
expected_live_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * LIVE_URI_FIELDS_PER_ROW))
official_release_live_verification_ready=0
if [[ "$official_release_evidence_ready" == "1" &&
      "$release_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_release_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$official_release_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_archive_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$dataset_version_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_authority_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_live_hash_fields" -eq "$expected_live_hash_fields" &&
      "$live_hash_attested_fields" -eq "$expected_live_hash_fields" &&
      "$required_live_uri_fields" -eq "$expected_live_uri_fields" &&
      "$nonlocal_live_uri_fields" -eq "$expected_live_uri_fields" &&
      "$local_live_uri_fields" -eq 0 &&
      "$official_release_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$public_archive_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$dataset_version_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_verification_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$network_observation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$verifier_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_network_observed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_verifier_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$stable_release_observed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_routing" == "0.000000" &&
      "$live_jump" == "0.000000" ]]; then
  official_release_live_verification_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$release_routing" -v b="$live_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$release_jump" -v b="$live_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-official-release-evidence-not-ready"
if [[ "$official_release_evidence_ready" != "1" ]]; then
  action="external-benchmark-official-release-evidence-not-ready"
elif [[ "$live_rows" -eq 0 ]]; then
  action="external-benchmark-live-release-verification-missing"
elif [[ "$live_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-live-release-coverage-incomplete"
elif [[ "$matched_release_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-release-binding-mismatch"
elif [[ "$official_release_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$public_archive_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$dataset_version_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_authority_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-release-artifact-mismatch"
elif [[ "$required_live_hash_fields" -ne "$expected_live_hash_fields" ||
        "$live_hash_attested_fields" -ne "$expected_live_hash_fields" ]]; then
  action="external-benchmark-live-release-hash-attestation-missing"
elif [[ "$required_live_uri_fields" -ne "$expected_live_uri_fields" ||
        "$nonlocal_live_uri_fields" -ne "$expected_live_uri_fields" ||
        "$local_live_uri_fields" -ne 0 ]]; then
  action="external-benchmark-live-release-local-artifact-uri"
elif [[ "$official_release_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$public_archive_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$dataset_version_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_authority_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$live_verification_report_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$network_observation_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$verifier_identity_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-release-proof-binding-missing"
elif [[ "$live_network_observed_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$independent_verifier_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$stable_release_observed_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-live-release-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-live-release-jump-guardrail-violated"
elif [[ "$official_release_live_verification_ready" == "1" ]]; then
  action="external-benchmark-live-release-verification-ready-await-canonical-online-confirmation"
fi

{
  echo "benchmark_scope,live_source,official_release_evidence_ready,release_rows,release_expected_families,release_real_external,release_action,release_family_rows,live_rows,expected_family_rows,duplicate_family_rows,matched_release_family_rows,reproduction_id_match_rows,release_id_match_rows,official_release_match_rows,public_archive_match_rows,dataset_version_match_rows,release_authority_match_rows,required_live_hash_fields,live_hash_attested_fields,required_live_uri_fields,nonlocal_live_uri_fields,local_live_uri_fields,official_release_bound_rows,public_archive_bound_rows,dataset_version_bound_rows,release_authority_bound_rows,live_verification_report_bound_rows,network_observation_bound_rows,verifier_identity_bound_rows,live_network_observed_rows,independent_verifier_declared_rows,stable_release_observed_rows,non_fixture_declared_rows,fixture_free_rows,timestamp_rows,live_family_coverage,expected_external_families,official_release_live_verification_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ag,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$LIVE_SOURCE" \
    "$official_release_evidence_ready" \
    "$release_rows" \
    "$release_expected_families" \
    "$release_real_external" \
    "$release_action" \
    "$release_family_rows" \
    "$live_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_release_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$official_release_match_rows" \
    "$public_archive_match_rows" \
    "$dataset_version_match_rows" \
    "$release_authority_match_rows" \
    "$required_live_hash_fields" \
    "$live_hash_attested_fields" \
    "$required_live_uri_fields" \
    "$nonlocal_live_uri_fields" \
    "$local_live_uri_fields" \
    "$official_release_bound_rows" \
    "$public_archive_bound_rows" \
    "$dataset_version_bound_rows" \
    "$release_authority_bound_rows" \
    "$live_verification_report_bound_rows" \
    "$network_observation_bound_rows" \
    "$verifier_identity_bound_rows" \
    "$live_network_observed_rows" \
    "$independent_verifier_declared_rows" \
    "$stable_release_observed_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$live_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$official_release_live_verification_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "official-release-evidence,%s,ready=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$official_release_evidence_ready" == "1" ]] && echo pass || echo blocked)" \
    "$official_release_evidence_ready" \
    "$release_rows" \
    "$release_expected_families" \
    "$release_real_external" \
    "$release_action"
  printf "live-release-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$live_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$live_rows" \
    "$expected_family_rows" \
    "$live_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "live-release-binding,%s,matched=%d reproduction=%d release=%d artifacts=%d/%d/%d/%d\n" \
    "$([[ "$matched_release_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$official_release_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$public_archive_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$dataset_version_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_authority_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_release_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$official_release_match_rows" \
    "$public_archive_match_rows" \
    "$dataset_version_match_rows" \
    "$release_authority_match_rows"
  printf "live-release-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_live_hash_fields" -eq "$expected_live_hash_fields" && "$live_hash_attested_fields" -eq "$expected_live_hash_fields" ]] && echo pass || echo blocked)" \
    "$live_hash_attested_fields" \
    "$expected_live_hash_fields"
  printf "nonlocal-live-release-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$required_live_uri_fields" -eq "$expected_live_uri_fields" && "$nonlocal_live_uri_fields" -eq "$expected_live_uri_fields" && "$local_live_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_live_uri_fields" \
    "$expected_live_uri_fields" \
    "$local_live_uri_fields"
  printf "live-release-proof-bindings,%s,bound=%d/%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$official_release_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$public_archive_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$dataset_version_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_verification_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$network_observation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$verifier_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$official_release_bound_rows" \
    "$public_archive_bound_rows" \
    "$dataset_version_bound_rows" \
    "$release_authority_bound_rows" \
    "$live_verification_report_bound_rows" \
    "$network_observation_bound_rows" \
    "$verifier_identity_bound_rows"
  printf "live-release-declarations,%s,network=%d independent=%d stable=%d non_fixture=%d fixture_free=%d timestamps=%d\n" \
    "$([[ "$live_network_observed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$independent_verifier_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$stable_release_observed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$live_network_observed_rows" \
    "$independent_verifier_declared_rows" \
    "$stable_release_observed_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows"
  printf "official-release-live-verification,%s,ready=%d action=%s\n" \
    "$([[ "$official_release_live_verification_ready" == "1" ]] && echo pass || echo blocked)" \
    "$official_release_live_verification_ready" \
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

echo "live verification: $LIVE_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
