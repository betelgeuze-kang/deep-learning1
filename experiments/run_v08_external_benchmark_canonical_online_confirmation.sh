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

PREFIX="v08_external_benchmark_canonical_online_confirmation"
AG_PREFIX="v08_external_benchmark_live_release_verification"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_canonical_online_confirmation_smoke"
  AG_PREFIX="v08_external_benchmark_live_release_verification_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_canonical_online_confirmation_full"
  AG_PREFIX="v08_external_benchmark_live_release_verification_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_release_verification.sh" "${RUN_ARGS[@]}" >/dev/null

AG_SUMMARY_CSV="$RESULTS_DIR/${AG_PREFIX}_summary.csv"
LIVE_CSV="${V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV:-$RESULTS_DIR/${AG_PREFIX}_live_verification.csv}"
CONFIRMATION_CSV="$RESULTS_DIR/${PREFIX}_confirmation.csv"
CONFIRMATION_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
CONFIRMATION_HASH_FIELDS_PER_ROW=9
CONFIRMATION_URI_FIELDS_PER_ROW=9

write_confirmation_header() {
  echo "benchmark_family,reproduction_id,release_id,live_verification_report_uri,live_verification_report_hash,network_observation_uri,network_observation_hash,verifier_identity_uri,verifier_identity_hash,canonical_confirmation_report_uri,canonical_confirmation_report_hash,runner_network_transcript_uri,runner_network_transcript_hash,tls_certificate_chain_uri,tls_certificate_chain_hash,dns_resolution_uri,dns_resolution_hash,http_response_header_uri,http_response_header_hash,content_digest_manifest_uri,content_digest_manifest_hash,confirmed_at_utc,live_verification_report_bound,network_observation_bound,verifier_identity_bound,canonical_confirmation_report_bound,runner_network_transcript_bound,tls_certificate_chain_bound,dns_resolution_bound,http_response_header_bound,content_digest_manifest_bound,runner_owned_confirmation_declared,canonical_authority_observed,online_fetch_declared,content_digest_match_declared,non_fixture_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ah column: " column > "/dev/stderr"
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
        print "missing v08-ah summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV:-}" ]]; then
  CONFIRMATION_CSV="$V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV"
  CONFIRMATION_SOURCE="provided-csv"
  if [[ ! -s "$CONFIRMATION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_confirmation_header >"$CONFIRMATION_CSV"
fi

official_release_live_verification_ready="$(csv_value "$AG_SUMMARY_CSV" "official_release_live_verification_ready")"
live_rows_upstream="$(csv_value "$AG_SUMMARY_CSV" "live_rows")"
live_expected_families="$(csv_value "$AG_SUMMARY_CSV" "expected_external_families")"
live_real_external="$(csv_value "$AG_SUMMARY_CSV" "real_external_benchmark_verified")"
live_action="$(csv_value "$AG_SUMMARY_CSV" "action")"
live_routing="$(csv_value "$AG_SUMMARY_CSV" "routing_trigger_rate")"
live_jump="$(csv_value "$AG_SUMMARY_CSV" "active_jump_rate")"

declare -A live_reproduction_id=()
declare -A live_release_id=()
declare -A live_report_uri_by_family=()
declare -A live_report_hash_by_family=()
declare -A live_network_uri_by_family=()
declare -A live_network_hash_by_family=()
declare -A live_verifier_uri_by_family=()
declare -A live_verifier_hash_by_family=()
declare -A live_family_seen=()
live_family_rows=0
LIVE_TSV="$TMP_DIR/live_rows.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id live_verification_report_uri live_verification_report_hash network_observation_uri network_observation_hash verifier_identity_uri verifier_identity_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ah upstream live column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ah upstream live row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$LIVE_CSV" >"$LIVE_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id live_verification_report_uri live_verification_report_hash network_observation_uri network_observation_hash verifier_identity_uri verifier_identity_hash; do
  live_reproduction_id["$benchmark_family"]="$reproduction_id"
  live_release_id["$benchmark_family"]="$release_id"
  live_report_uri_by_family["$benchmark_family"]="$live_verification_report_uri"
  live_report_hash_by_family["$benchmark_family"]="$live_verification_report_hash"
  live_network_uri_by_family["$benchmark_family"]="$network_observation_uri"
  live_network_hash_by_family["$benchmark_family"]="$network_observation_hash"
  live_verifier_uri_by_family["$benchmark_family"]="$verifier_identity_uri"
  live_verifier_hash_by_family["$benchmark_family"]="$verifier_identity_hash"
  live_family_seen["$benchmark_family"]=1
done <"$LIVE_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${live_family_seen[$family]:-}" ]]; then
    ((live_family_rows += 1))
  fi
done

confirmation_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_live_family_rows=0
reproduction_id_match_rows=0
release_id_match_rows=0
live_report_match_rows=0
network_observation_match_rows=0
verifier_identity_match_rows=0
required_confirmation_hash_fields=0
confirmation_hash_attested_fields=0
required_confirmation_uri_fields=0
nonlocal_confirmation_uri_fields=0
local_confirmation_uri_fields=0
live_verification_report_bound_rows=0
network_observation_bound_rows=0
verifier_identity_bound_rows=0
canonical_confirmation_report_bound_rows=0
runner_network_transcript_bound_rows=0
tls_certificate_chain_bound_rows=0
dns_resolution_bound_rows=0
http_response_header_bound_rows=0
content_digest_manifest_bound_rows=0
runner_owned_confirmation_declared_rows=0
canonical_authority_observed_rows=0
online_fetch_declared_rows=0
content_digest_match_declared_rows=0
non_fixture_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
confirmation_routing="0.000000"
confirmation_jump="0.000000"
declare -A confirmation_family_seen=()

CONFIRMATION_TSV="$TMP_DIR/canonical_online_confirmation.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family reproduction_id release_id live_verification_report_uri live_verification_report_hash network_observation_uri network_observation_hash verifier_identity_uri verifier_identity_hash canonical_confirmation_report_uri canonical_confirmation_report_hash runner_network_transcript_uri runner_network_transcript_hash tls_certificate_chain_uri tls_certificate_chain_hash dns_resolution_uri dns_resolution_hash http_response_header_uri http_response_header_hash content_digest_manifest_uri content_digest_manifest_hash confirmed_at_utc live_verification_report_bound network_observation_bound verifier_identity_bound canonical_confirmation_report_bound runner_network_transcript_bound tls_certificate_chain_bound dns_resolution_bound http_response_header_bound content_digest_manifest_bound runner_owned_confirmation_declared canonical_authority_observed online_fetch_declared content_digest_match_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ah confirmation column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ah confirmation row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$CONFIRMATION_CSV" >"$CONFIRMATION_TSV"

while IFS=$'\t' read -r benchmark_family reproduction_id release_id live_verification_report_uri live_verification_report_hash network_observation_uri network_observation_hash verifier_identity_uri verifier_identity_hash canonical_confirmation_report_uri canonical_confirmation_report_hash runner_network_transcript_uri runner_network_transcript_hash tls_certificate_chain_uri tls_certificate_chain_hash dns_resolution_uri dns_resolution_hash http_response_header_uri http_response_header_hash content_digest_manifest_uri content_digest_manifest_hash confirmed_at_utc live_verification_report_bound network_observation_bound verifier_identity_bound canonical_confirmation_report_bound runner_network_transcript_bound tls_certificate_chain_bound dns_resolution_bound http_response_header_bound content_digest_manifest_bound runner_owned_confirmation_declared canonical_authority_observed online_fetch_declared content_digest_match_declared non_fixture_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((confirmation_rows += 1))

  if [[ -n "${confirmation_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  confirmation_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${live_release_id[$benchmark_family]:-}" ]]; then
    ((matched_live_family_rows += 1))
  fi
  if [[ -n "${live_reproduction_id[$benchmark_family]:-}" &&
        "$reproduction_id" == "${live_reproduction_id[$benchmark_family]}" ]]; then
    ((reproduction_id_match_rows += 1))
  fi
  if [[ -n "${live_release_id[$benchmark_family]:-}" &&
        "$release_id" == "${live_release_id[$benchmark_family]}" ]]; then
    ((release_id_match_rows += 1))
  fi
  if [[ -n "${live_report_uri_by_family[$benchmark_family]:-}" &&
        "$live_verification_report_uri" == "${live_report_uri_by_family[$benchmark_family]}" &&
        "$live_verification_report_hash" == "${live_report_hash_by_family[$benchmark_family]}" ]]; then
    ((live_report_match_rows += 1))
  fi
  if [[ -n "${live_network_uri_by_family[$benchmark_family]:-}" &&
        "$network_observation_uri" == "${live_network_uri_by_family[$benchmark_family]}" &&
        "$network_observation_hash" == "${live_network_hash_by_family[$benchmark_family]}" ]]; then
    ((network_observation_match_rows += 1))
  fi
  if [[ -n "${live_verifier_uri_by_family[$benchmark_family]:-}" &&
        "$verifier_identity_uri" == "${live_verifier_uri_by_family[$benchmark_family]}" &&
        "$verifier_identity_hash" == "${live_verifier_hash_by_family[$benchmark_family]}" ]]; then
    ((verifier_identity_match_rows += 1))
  fi

  for pair in \
    "$live_verification_report_uri|$live_verification_report_hash" \
    "$network_observation_uri|$network_observation_hash" \
    "$verifier_identity_uri|$verifier_identity_hash" \
    "$canonical_confirmation_report_uri|$canonical_confirmation_report_hash" \
    "$runner_network_transcript_uri|$runner_network_transcript_hash" \
    "$tls_certificate_chain_uri|$tls_certificate_chain_hash" \
    "$dns_resolution_uri|$dns_resolution_hash" \
    "$http_response_header_uri|$http_response_header_hash" \
    "$content_digest_manifest_uri|$content_digest_manifest_hash"; do
    ((required_confirmation_hash_fields += 1))
    ((required_confirmation_uri_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((confirmation_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_confirmation_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_confirmation_uri_fields += 1))
    fi
  done

  [[ "$live_verification_report_bound" == "1" ]] && ((live_verification_report_bound_rows += 1))
  [[ "$network_observation_bound" == "1" ]] && ((network_observation_bound_rows += 1))
  [[ "$verifier_identity_bound" == "1" ]] && ((verifier_identity_bound_rows += 1))
  [[ "$canonical_confirmation_report_bound" == "1" ]] && ((canonical_confirmation_report_bound_rows += 1))
  [[ "$runner_network_transcript_bound" == "1" ]] && ((runner_network_transcript_bound_rows += 1))
  [[ "$tls_certificate_chain_bound" == "1" ]] && ((tls_certificate_chain_bound_rows += 1))
  [[ "$dns_resolution_bound" == "1" ]] && ((dns_resolution_bound_rows += 1))
  [[ "$http_response_header_bound" == "1" ]] && ((http_response_header_bound_rows += 1))
  [[ "$content_digest_manifest_bound" == "1" ]] && ((content_digest_manifest_bound_rows += 1))
  [[ "$runner_owned_confirmation_declared" == "1" ]] && ((runner_owned_confirmation_declared_rows += 1))
  [[ "$canonical_authority_observed" == "1" ]] && ((canonical_authority_observed_rows += 1))
  [[ "$online_fetch_declared" == "1" ]] && ((online_fetch_declared_rows += 1))
  [[ "$content_digest_match_declared" == "1" ]] && ((content_digest_match_declared_rows += 1))
  [[ "$non_fixture_declared" == "1" ]] && ((non_fixture_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$confirmed_at_utc" && ((timestamp_rows += 1))
  confirmation_routing="$(awk -v a="$confirmation_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  confirmation_jump="$(awk -v a="$confirmation_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$CONFIRMATION_TSV"

confirmation_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${confirmation_family_seen[$family]:-}" ]]; then
    ((confirmation_family_coverage += 1))
  fi
done

expected_confirmation_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * CONFIRMATION_HASH_FIELDS_PER_ROW))
expected_confirmation_uri_fields=$((EXPECTED_EXTERNAL_FAMILIES * CONFIRMATION_URI_FIELDS_PER_ROW))
canonical_online_confirmation_ready=0
if [[ "$official_release_live_verification_ready" == "1" &&
      "$live_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$confirmation_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$confirmation_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_live_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$live_report_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$network_observation_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$verifier_identity_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_confirmation_hash_fields" -eq "$expected_confirmation_hash_fields" &&
      "$confirmation_hash_attested_fields" -eq "$expected_confirmation_hash_fields" &&
      "$required_confirmation_uri_fields" -eq "$expected_confirmation_uri_fields" &&
      "$nonlocal_confirmation_uri_fields" -eq "$expected_confirmation_uri_fields" &&
      "$local_confirmation_uri_fields" -eq 0 &&
      "$live_verification_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$network_observation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$verifier_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$canonical_confirmation_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$runner_network_transcript_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$tls_certificate_chain_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$dns_resolution_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$http_response_header_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$content_digest_manifest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$runner_owned_confirmation_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$canonical_authority_observed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$online_fetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$content_digest_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$confirmation_routing" == "0.000000" &&
      "$confirmation_jump" == "0.000000" ]]; then
  canonical_online_confirmation_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$live_routing" -v b="$confirmation_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$live_jump" -v b="$confirmation_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-live-release-verification-not-ready"
if [[ "$official_release_live_verification_ready" != "1" ]]; then
  action="external-benchmark-live-release-verification-not-ready"
elif [[ "$confirmation_rows" -eq 0 ]]; then
  action="external-benchmark-canonical-online-confirmation-missing"
elif [[ "$confirmation_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$confirmation_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-canonical-online-confirmation-coverage-incomplete"
elif [[ "$matched_live_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$release_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-canonical-online-confirmation-binding-mismatch"
elif [[ "$live_report_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$network_observation_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$verifier_identity_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-canonical-online-confirmation-live-artifact-mismatch"
elif [[ "$required_confirmation_hash_fields" -ne "$expected_confirmation_hash_fields" ||
        "$confirmation_hash_attested_fields" -ne "$expected_confirmation_hash_fields" ]]; then
  action="external-benchmark-canonical-online-confirmation-hash-attestation-missing"
elif [[ "$required_confirmation_uri_fields" -ne "$expected_confirmation_uri_fields" ||
        "$nonlocal_confirmation_uri_fields" -ne "$expected_confirmation_uri_fields" ||
        "$local_confirmation_uri_fields" -ne 0 ]]; then
  action="external-benchmark-canonical-online-confirmation-local-artifact-uri"
elif [[ "$live_verification_report_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$network_observation_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$verifier_identity_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$canonical_confirmation_report_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$runner_network_transcript_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$tls_certificate_chain_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$dns_resolution_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$http_response_header_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$content_digest_manifest_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-canonical-online-confirmation-proof-binding-missing"
elif [[ "$runner_owned_confirmation_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$canonical_authority_observed_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$online_fetch_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$content_digest_match_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$fixture_free_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$timestamp_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-canonical-online-confirmation-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-canonical-online-confirmation-jump-guardrail-violated"
elif [[ "$canonical_online_confirmation_ready" == "1" ]]; then
  action="external-benchmark-canonical-online-confirmation-ready-await-nonfixture-publication-result-review"
fi

{
  echo "benchmark_scope,confirmation_source,official_release_live_verification_ready,live_rows,live_expected_families,live_real_external,live_action,live_family_rows,confirmation_rows,expected_family_rows,duplicate_family_rows,matched_live_family_rows,reproduction_id_match_rows,release_id_match_rows,live_report_match_rows,network_observation_match_rows,verifier_identity_match_rows,required_confirmation_hash_fields,confirmation_hash_attested_fields,required_confirmation_uri_fields,nonlocal_confirmation_uri_fields,local_confirmation_uri_fields,live_verification_report_bound_rows,network_observation_bound_rows,verifier_identity_bound_rows,canonical_confirmation_report_bound_rows,runner_network_transcript_bound_rows,tls_certificate_chain_bound_rows,dns_resolution_bound_rows,http_response_header_bound_rows,content_digest_manifest_bound_rows,runner_owned_confirmation_declared_rows,canonical_authority_observed_rows,online_fetch_declared_rows,content_digest_match_declared_rows,non_fixture_declared_rows,fixture_free_rows,timestamp_rows,confirmation_family_coverage,expected_external_families,canonical_online_confirmation_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ah,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$CONFIRMATION_SOURCE" \
    "$official_release_live_verification_ready" \
    "$live_rows_upstream" \
    "$live_expected_families" \
    "$live_real_external" \
    "$live_action" \
    "$live_family_rows" \
    "$confirmation_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_live_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$live_report_match_rows" \
    "$network_observation_match_rows" \
    "$verifier_identity_match_rows" \
    "$required_confirmation_hash_fields" \
    "$confirmation_hash_attested_fields" \
    "$required_confirmation_uri_fields" \
    "$nonlocal_confirmation_uri_fields" \
    "$local_confirmation_uri_fields" \
    "$live_verification_report_bound_rows" \
    "$network_observation_bound_rows" \
    "$verifier_identity_bound_rows" \
    "$canonical_confirmation_report_bound_rows" \
    "$runner_network_transcript_bound_rows" \
    "$tls_certificate_chain_bound_rows" \
    "$dns_resolution_bound_rows" \
    "$http_response_header_bound_rows" \
    "$content_digest_manifest_bound_rows" \
    "$runner_owned_confirmation_declared_rows" \
    "$canonical_authority_observed_rows" \
    "$online_fetch_declared_rows" \
    "$content_digest_match_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$confirmation_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$canonical_online_confirmation_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "live-release-verification,%s,ready=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$official_release_live_verification_ready" == "1" ]] && echo pass || echo blocked)" \
    "$official_release_live_verification_ready" \
    "$live_rows_upstream" \
    "$live_expected_families" \
    "$live_real_external" \
    "$live_action"
  printf "canonical-confirmation-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$confirmation_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$confirmation_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$confirmation_rows" \
    "$expected_family_rows" \
    "$confirmation_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "canonical-confirmation-binding,%s,matched=%d reproduction=%d release=%d live=%d/%d/%d\n" \
    "$([[ "$matched_live_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$release_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$live_report_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$network_observation_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$verifier_identity_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_live_family_rows" \
    "$reproduction_id_match_rows" \
    "$release_id_match_rows" \
    "$live_report_match_rows" \
    "$network_observation_match_rows" \
    "$verifier_identity_match_rows"
  printf "canonical-confirmation-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_confirmation_hash_fields" -eq "$expected_confirmation_hash_fields" && "$confirmation_hash_attested_fields" -eq "$expected_confirmation_hash_fields" ]] && echo pass || echo blocked)" \
    "$confirmation_hash_attested_fields" \
    "$expected_confirmation_hash_fields"
  printf "nonlocal-canonical-confirmation-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$required_confirmation_uri_fields" -eq "$expected_confirmation_uri_fields" && "$nonlocal_confirmation_uri_fields" -eq "$expected_confirmation_uri_fields" && "$local_confirmation_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_confirmation_uri_fields" \
    "$expected_confirmation_uri_fields" \
    "$local_confirmation_uri_fields"
  printf "canonical-confirmation-proof-bindings,%s,bound=%d/%d/%d/%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$live_verification_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$network_observation_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$verifier_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$canonical_confirmation_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$runner_network_transcript_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$tls_certificate_chain_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$dns_resolution_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$http_response_header_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$content_digest_manifest_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$live_verification_report_bound_rows" \
    "$network_observation_bound_rows" \
    "$verifier_identity_bound_rows" \
    "$canonical_confirmation_report_bound_rows" \
    "$runner_network_transcript_bound_rows" \
    "$tls_certificate_chain_bound_rows" \
    "$dns_resolution_bound_rows" \
    "$http_response_header_bound_rows" \
    "$content_digest_manifest_bound_rows"
  printf "canonical-confirmation-declarations,%s,runner=%d authority=%d online=%d digest=%d non_fixture=%d fixture_free=%d timestamps=%d\n" \
    "$([[ "$runner_owned_confirmation_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$canonical_authority_observed_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$online_fetch_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$content_digest_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$fixture_free_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$timestamp_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$runner_owned_confirmation_declared_rows" \
    "$canonical_authority_observed_rows" \
    "$online_fetch_declared_rows" \
    "$content_digest_match_declared_rows" \
    "$non_fixture_declared_rows" \
    "$fixture_free_rows" \
    "$timestamp_rows"
  printf "canonical-online-confirmation,%s,ready=%d action=%s\n" \
    "$([[ "$canonical_online_confirmation_ready" == "1" ]] && echo pass || echo blocked)" \
    "$canonical_online_confirmation_ready" \
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

echo "confirmation: $CONFIRMATION_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
