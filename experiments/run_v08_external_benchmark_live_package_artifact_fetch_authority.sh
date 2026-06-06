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

PREFIX="v08_external_benchmark_live_package_artifact_fetch_authority"
AR_PREFIX="v08_external_benchmark_real_nonfixture_run_package"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_live_package_artifact_fetch_authority_smoke"
  AR_PREFIX="v08_external_benchmark_real_nonfixture_run_package_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_live_package_artifact_fetch_authority_full"
  AR_PREFIX="v08_external_benchmark_real_nonfixture_run_package_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_real_nonfixture_run_package.sh" "${RUN_ARGS[@]}" >/dev/null

AR_SUMMARY_CSV="$RESULTS_DIR/${AR_PREFIX}_summary.csv"
FETCH_CSV="$RESULTS_DIR/${PREFIX}_fetch_authority.csv"
FETCH_SOURCE="pending-csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_ARTIFACT_TYPES=(
  run_package_manifest
  raw_query_set
  raw_prediction_output
  evaluator_container_digest
  evaluator_config
  metric_report
  submission_receipt
  public_archive
  official_leaderboard_entry
  license_review
  pii_review
  third_party_repro_report
  package_signature
  timestamp_authority
  package_registry_entry
)
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
EXPECTED_ARTIFACT_TYPES_PER_FAMILY="${#EXPECTED_ARTIFACT_TYPES[@]}"
EXPECTED_ARTIFACT_ROWS=$((EXPECTED_EXTERNAL_FAMILIES * EXPECTED_ARTIFACT_TYPES_PER_FAMILY))
LIVE_FETCH_URI_FIELDS_PER_ROW=3
LIVE_FETCH_HASH_FIELDS_PER_ROW=3

write_fetch_header() {
  echo "benchmark_family,real_run_package_id,artifact_type,fetch_authority_verification_id,v08ar_package_intake_bound,runner_owned_live_fetch_declared,network_fetch_transcript_declared,tls_certificate_verified_declared,dns_resolution_verified_declared,http_status_verified_declared,content_digest_match_declared,authority_registry_verified_declared,official_source_authority_verified_declared,fixture_or_replay_declared,fetch_http_status,fetched_artifact_uri,fetched_artifact_hash,fetch_receipt_uri,fetch_receipt_hash,authority_record_uri,authority_record_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
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

is_expected_artifact_type() {
  local artifact_type="$1"
  local expected

  for expected in "${EXPECTED_ARTIFACT_TYPES[@]}"; do
    [[ "$artifact_type" == "$expected" ]] && return 0
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
        print "missing v08-as column: " column > "/dev/stderr"
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
        print "missing v08-as summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_LIVE_PACKAGE_ARTIFACT_FETCH_AUTHORITY_CSV:-}" ]]; then
  FETCH_CSV="$V08_EXTERNAL_BENCHMARK_LIVE_PACKAGE_ARTIFACT_FETCH_AUTHORITY_CSV"
  FETCH_SOURCE="provided-csv"
  if [[ ! -s "$FETCH_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_LIVE_PACKAGE_ARTIFACT_FETCH_AUTHORITY_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_fetch_header >"$FETCH_CSV"
fi

upstream_real_nonfixture_run_package_intake_ready="$(csv_value "$AR_SUMMARY_CSV" "external_benchmark_real_nonfixture_run_package_intake_ready")"
upstream_real_external="$(csv_value "$AR_SUMMARY_CSV" "real_external_benchmark_verified")"
upstream_action="$(csv_value "$AR_SUMMARY_CSV" "action")"
upstream_routing="$(csv_value "$AR_SUMMARY_CSV" "routing_trigger_rate")"
upstream_jump="$(csv_value "$AR_SUMMARY_CSV" "active_jump_rate")"

fetch_rows=0
expected_family_rows=0
unexpected_artifact_type_rows=0
duplicate_artifact_rows=0
required_live_fetch_uri_fields=0
nonlocal_live_fetch_uri_fields=0
local_live_fetch_uri_fields=0
nonplaceholder_live_fetch_uri_fields=0
required_live_fetch_hash_fields=0
live_fetch_hash_attested_fields=0
http_status_pass_rows=0
content_digest_match_declared_rows=0
v08ar_package_intake_bound_rows=0
runner_owned_live_fetch_declared_rows=0
network_fetch_transcript_declared_rows=0
tls_certificate_verified_declared_rows=0
dns_resolution_verified_declared_rows=0
http_status_verified_declared_rows=0
authority_registry_verified_declared_rows=0
official_source_authority_verified_declared_rows=0
fixture_free_rows=0
timestamp_rows=0
fetch_routing="0.000000"
fetch_jump="0.000000"
declare -A family_seen=()
declare -A artifact_seen=()

FETCH_TSV="$TMP_DIR/live_package_artifact_fetch_authority.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family real_run_package_id artifact_type fetch_authority_verification_id v08ar_package_intake_bound runner_owned_live_fetch_declared network_fetch_transcript_declared tls_certificate_verified_declared dns_resolution_verified_declared http_status_verified_declared content_digest_match_declared authority_registry_verified_declared official_source_authority_verified_declared fixture_or_replay_declared fetch_http_status fetched_artifact_uri fetched_artifact_hash fetch_receipt_uri fetch_receipt_hash authority_record_uri authority_record_hash observed_at_utc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-as live fetch authority column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-as live fetch authority row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$FETCH_CSV" >"$FETCH_TSV"

while IFS=$'\t' read -r benchmark_family real_run_package_id artifact_type fetch_authority_verification_id v08ar_package_intake_bound runner_owned_live_fetch_declared network_fetch_transcript_declared tls_certificate_verified_declared dns_resolution_verified_declared http_status_verified_declared content_digest_match_declared authority_registry_verified_declared official_source_authority_verified_declared fixture_or_replay_declared fetch_http_status fetched_artifact_uri fetched_artifact_hash fetch_receipt_uri fetch_receipt_hash authority_record_uri authority_record_hash observed_at_utc routing_trigger_rate active_jump_rate; do
  ((fetch_rows += 1))

  family_seen["$benchmark_family"]=1
  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if ! is_expected_artifact_type "$artifact_type"; then
    ((unexpected_artifact_type_rows += 1))
  fi

  artifact_key="${benchmark_family}|${artifact_type}"
  if [[ -n "${artifact_seen[$artifact_key]:-}" ]]; then
    ((duplicate_artifact_rows += 1))
  fi
  artifact_seen["$artifact_key"]=1

  for pair in \
    "$fetched_artifact_uri|$fetched_artifact_hash" \
    "$fetch_receipt_uri|$fetch_receipt_hash" \
    "$authority_record_uri|$authority_record_hash"; do
    ((required_live_fetch_uri_fields += 1))
    ((required_live_fetch_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((live_fetch_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_live_fetch_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_live_fetch_uri_fields += 1))
    fi
    if is_nonplaceholder_https_uri "$uri"; then
      ((nonplaceholder_live_fetch_uri_fields += 1))
    fi
  done

  [[ "$fetch_http_status" == "200" ]] && ((http_status_pass_rows += 1))
  [[ "$content_digest_match_declared" == "1" ]] && ((content_digest_match_declared_rows += 1))
  [[ "$v08ar_package_intake_bound" == "1" ]] && ((v08ar_package_intake_bound_rows += 1))
  [[ "$runner_owned_live_fetch_declared" == "1" ]] && ((runner_owned_live_fetch_declared_rows += 1))
  [[ "$network_fetch_transcript_declared" == "1" ]] && ((network_fetch_transcript_declared_rows += 1))
  [[ "$tls_certificate_verified_declared" == "1" ]] && ((tls_certificate_verified_declared_rows += 1))
  [[ "$dns_resolution_verified_declared" == "1" ]] && ((dns_resolution_verified_declared_rows += 1))
  [[ "$http_status_verified_declared" == "1" ]] && ((http_status_verified_declared_rows += 1))
  [[ "$authority_registry_verified_declared" == "1" ]] && ((authority_registry_verified_declared_rows += 1))
  [[ "$official_source_authority_verified_declared" == "1" ]] && ((official_source_authority_verified_declared_rows += 1))
  [[ "$fixture_or_replay_declared" == "0" ]] && ((fixture_free_rows += 1))
  is_present_timestamp "$observed_at_utc" && ((timestamp_rows += 1))
  fetch_routing="$(awk -v a="$fetch_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  fetch_jump="$(awk -v a="$fetch_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$FETCH_TSV"

family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${family_seen[$family]:-}" ]]; then
    ((family_coverage += 1))
  fi
done

artifact_type_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  for artifact_type in "${EXPECTED_ARTIFACT_TYPES[@]}"; do
    if [[ -n "${artifact_seen[$family|$artifact_type]:-}" ]]; then
      ((artifact_type_coverage += 1))
    fi
  done
done

expected_live_fetch_uri_fields=$((EXPECTED_ARTIFACT_ROWS * LIVE_FETCH_URI_FIELDS_PER_ROW))
expected_live_fetch_hash_fields=$((EXPECTED_ARTIFACT_ROWS * LIVE_FETCH_HASH_FIELDS_PER_ROW))
external_benchmark_live_package_artifact_fetch_authority_ready=0
if [[ "$upstream_real_nonfixture_run_package_intake_ready" == "1" &&
      "$fetch_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$expected_family_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$unexpected_artifact_type_rows" -eq 0 &&
      "$duplicate_artifact_rows" -eq 0 &&
      "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$artifact_type_coverage" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$required_live_fetch_uri_fields" -eq "$expected_live_fetch_uri_fields" &&
      "$nonlocal_live_fetch_uri_fields" -eq "$expected_live_fetch_uri_fields" &&
      "$local_live_fetch_uri_fields" -eq 0 &&
      "$nonplaceholder_live_fetch_uri_fields" -eq "$expected_live_fetch_uri_fields" &&
      "$required_live_fetch_hash_fields" -eq "$expected_live_fetch_hash_fields" &&
      "$live_fetch_hash_attested_fields" -eq "$expected_live_fetch_hash_fields" &&
      "$http_status_pass_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$content_digest_match_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$v08ar_package_intake_bound_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$runner_owned_live_fetch_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$network_fetch_transcript_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$tls_certificate_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$dns_resolution_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$http_status_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$authority_registry_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$official_source_authority_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$fixture_free_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$timestamp_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
      "$fetch_routing" == "0.000000" &&
      "$fetch_jump" == "0.000000" ]]; then
  external_benchmark_live_package_artifact_fetch_authority_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$upstream_routing" -v b="$fetch_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$upstream_jump" -v b="$fetch_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-real-nonfixture-run-package-intake-not-ready"
if [[ "$upstream_real_nonfixture_run_package_intake_ready" != "1" ]]; then
  action="external-benchmark-real-nonfixture-run-package-intake-not-ready"
elif [[ "$fetch_rows" -eq 0 ]]; then
  action="external-benchmark-live-package-artifact-fetch-missing"
elif [[ "$fetch_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ||
        "$expected_family_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ||
        "$unexpected_artifact_type_rows" -ne 0 ||
        "$duplicate_artifact_rows" -ne 0 ||
        "$family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$artifact_type_coverage" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-coverage-incomplete"
elif [[ "$required_live_fetch_hash_fields" -ne "$expected_live_fetch_hash_fields" ||
        "$live_fetch_hash_attested_fields" -ne "$expected_live_fetch_hash_fields" ]]; then
  action="external-benchmark-live-package-artifact-fetch-hash-attestation-missing"
elif [[ "$required_live_fetch_uri_fields" -ne "$expected_live_fetch_uri_fields" ||
        "$nonlocal_live_fetch_uri_fields" -ne "$expected_live_fetch_uri_fields" ||
        "$local_live_fetch_uri_fields" -ne 0 ]]; then
  action="external-benchmark-live-package-artifact-fetch-local-artifact-uri"
elif [[ "$nonplaceholder_live_fetch_uri_fields" -ne "$expected_live_fetch_uri_fields" ]]; then
  action="external-benchmark-live-package-artifact-fetch-placeholder-artifact-uri"
elif [[ "$http_status_pass_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ||
        "$http_status_verified_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-http-status-missing"
elif [[ "$content_digest_match_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-content-digest-mismatch"
elif [[ "$v08ar_package_intake_bound_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-binding-missing"
elif [[ "$runner_owned_live_fetch_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-runner-declaration-missing"
elif [[ "$network_fetch_transcript_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ||
        "$tls_certificate_verified_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ||
        "$dns_resolution_verified_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-network-proof-missing"
elif [[ "$authority_registry_verified_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ||
        "$official_source_authority_verified_declared_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-authority-verification-missing"
elif [[ "$fixture_free_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ||
        "$timestamp_rows" -ne "$EXPECTED_ARTIFACT_ROWS" ]]; then
  action="external-benchmark-live-package-artifact-fetch-fixture-declaration-missing"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-live-package-artifact-fetch-jump-guardrail-violated"
elif [[ "$external_benchmark_live_package_artifact_fetch_authority_ready" == "1" ]]; then
  action="live-package-artifact-fetch-authority-ready-await-official-result-reconciliation"
fi

summary_header=(
  benchmark_scope
  fetch_source
  upstream_real_nonfixture_run_package_intake_ready
  upstream_real_external
  upstream_action
  fetch_rows
  expected_artifact_rows
  expected_family_rows
  unexpected_artifact_type_rows
  duplicate_artifact_rows
  family_coverage
  expected_external_families
  artifact_type_coverage
  expected_artifact_types_per_family
  required_live_fetch_uri_fields
  nonlocal_live_fetch_uri_fields
  local_live_fetch_uri_fields
  nonplaceholder_live_fetch_uri_fields
  required_live_fetch_hash_fields
  live_fetch_hash_attested_fields
  http_status_pass_rows
  content_digest_match_declared_rows
  v08ar_package_intake_bound_rows
  runner_owned_live_fetch_declared_rows
  network_fetch_transcript_declared_rows
  tls_certificate_verified_declared_rows
  dns_resolution_verified_declared_rows
  http_status_verified_declared_rows
  authority_registry_verified_declared_rows
  official_source_authority_verified_declared_rows
  fixture_free_rows
  timestamp_rows
  external_benchmark_live_package_artifact_fetch_authority_ready
  real_external_benchmark_verified
  action
  routing_trigger_rate
  active_jump_rate
)
summary_values=(
  route-memory-v08as
  "$FETCH_SOURCE"
  "$upstream_real_nonfixture_run_package_intake_ready"
  "$upstream_real_external"
  "$upstream_action"
  "$fetch_rows"
  "$EXPECTED_ARTIFACT_ROWS"
  "$expected_family_rows"
  "$unexpected_artifact_type_rows"
  "$duplicate_artifact_rows"
  "$family_coverage"
  "$EXPECTED_EXTERNAL_FAMILIES"
  "$artifact_type_coverage"
  "$EXPECTED_ARTIFACT_TYPES_PER_FAMILY"
  "$required_live_fetch_uri_fields"
  "$nonlocal_live_fetch_uri_fields"
  "$local_live_fetch_uri_fields"
  "$nonplaceholder_live_fetch_uri_fields"
  "$required_live_fetch_hash_fields"
  "$live_fetch_hash_attested_fields"
  "$http_status_pass_rows"
  "$content_digest_match_declared_rows"
  "$v08ar_package_intake_bound_rows"
  "$runner_owned_live_fetch_declared_rows"
  "$network_fetch_transcript_declared_rows"
  "$tls_certificate_verified_declared_rows"
  "$dns_resolution_verified_declared_rows"
  "$http_status_verified_declared_rows"
  "$authority_registry_verified_declared_rows"
  "$official_source_authority_verified_declared_rows"
  "$fixture_free_rows"
  "$timestamp_rows"
  "$external_benchmark_live_package_artifact_fetch_authority_ready"
  "$real_external_benchmark_verified"
  "$action"
  "$routing_trigger_rate"
  "$active_jump_rate"
)
{
  (IFS=,; printf '%s\n' "${summary_header[*]}")
  (IFS=,; printf '%s\n' "${summary_values[*]}")
} >"$SUMMARY_CSV"

coverage_status=blocked
[[ "$family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
   "$artifact_type_coverage" -eq "$EXPECTED_ARTIFACT_ROWS" &&
   "$fetch_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
   "$duplicate_artifact_rows" -eq 0 &&
   "$unexpected_artifact_type_rows" -eq 0 ]] && coverage_status=pass
artifact_status=blocked
[[ "$nonlocal_live_fetch_uri_fields" -eq "$expected_live_fetch_uri_fields" &&
   "$live_fetch_hash_attested_fields" -eq "$expected_live_fetch_hash_fields" &&
   "$local_live_fetch_uri_fields" -eq 0 &&
   "$nonplaceholder_live_fetch_uri_fields" -eq "$expected_live_fetch_uri_fields" ]] && artifact_status=pass
http_status=blocked
[[ "$http_status_pass_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
   "$http_status_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" ]] && http_status=pass
digest_status=blocked
[[ "$content_digest_match_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" ]] && digest_status=pass
binding_status=blocked
[[ "$v08ar_package_intake_bound_rows" -eq "$EXPECTED_ARTIFACT_ROWS" ]] && binding_status=pass
runner_status=blocked
[[ "$runner_owned_live_fetch_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" ]] && runner_status=pass
network_status=blocked
[[ "$network_fetch_transcript_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
   "$tls_certificate_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
   "$dns_resolution_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" ]] && network_status=pass
authority_status=blocked
[[ "$authority_registry_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
   "$official_source_authority_verified_declared_rows" -eq "$EXPECTED_ARTIFACT_ROWS" ]] && authority_status=pass
fixture_status=blocked
[[ "$fixture_free_rows" -eq "$EXPECTED_ARTIFACT_ROWS" &&
   "$timestamp_rows" -eq "$EXPECTED_ARTIFACT_ROWS" ]] && fixture_status=pass
ready_status=blocked
[[ "$external_benchmark_live_package_artifact_fetch_authority_ready" == "1" ]] && ready_status=pass
jump_status=blocked
[[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && jump_status=pass
upstream_status=blocked
[[ "$upstream_real_nonfixture_run_package_intake_ready" == "1" ]] && upstream_status=pass

{
  echo "gate,status,reason"
  printf "upstream-real-nonfixture-run-package-intake,%s,ready=%d action=%s\n" \
    "$upstream_status" \
    "$upstream_real_nonfixture_run_package_intake_ready" \
    "$upstream_action"
  printf "live-package-artifact-fetch-coverage,%s,coverage=%d/%d artifact_rows=%d/%d duplicates=%d unexpected_artifact_types=%d\n" \
    "$coverage_status" \
    "$family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$artifact_type_coverage" \
    "$EXPECTED_ARTIFACT_ROWS" \
    "$duplicate_artifact_rows" \
    "$unexpected_artifact_type_rows"
  printf "live-package-artifact-fetch-artifacts,%s,uris=%d/%d hashes=%d/%d local=%d nonplaceholder=%d/%d\n" \
    "$artifact_status" \
    "$nonlocal_live_fetch_uri_fields" \
    "$expected_live_fetch_uri_fields" \
    "$live_fetch_hash_attested_fields" \
    "$expected_live_fetch_hash_fields" \
    "$local_live_fetch_uri_fields" \
    "$nonplaceholder_live_fetch_uri_fields" \
    "$expected_live_fetch_uri_fields"
  printf "live-package-artifact-fetch-http-status,%s,pass_rows=%d/%d declared=%d/%d\n" \
    "$http_status" \
    "$http_status_pass_rows" \
    "$EXPECTED_ARTIFACT_ROWS" \
    "$http_status_verified_declared_rows" \
    "$EXPECTED_ARTIFACT_ROWS"
  printf "live-package-artifact-fetch-content-digest,%s,match_rows=%d/%d\n" \
    "$digest_status" \
    "$content_digest_match_declared_rows" \
    "$EXPECTED_ARTIFACT_ROWS"
  printf "live-package-artifact-fetch-bindings,%s,v08ar=%d expected=%d\n" \
    "$binding_status" \
    "$v08ar_package_intake_bound_rows" \
    "$EXPECTED_ARTIFACT_ROWS"
  printf "runner-live-fetch-declarations,%s,runner=%d expected=%d\n" \
    "$runner_status" \
    "$runner_owned_live_fetch_declared_rows" \
    "$EXPECTED_ARTIFACT_ROWS"
  printf "network-proof-declarations,%s,network=%d tls=%d dns=%d expected=%d\n" \
    "$network_status" \
    "$network_fetch_transcript_declared_rows" \
    "$tls_certificate_verified_declared_rows" \
    "$dns_resolution_verified_declared_rows" \
    "$EXPECTED_ARTIFACT_ROWS"
  printf "authority-verification-declarations,%s,registry=%d official=%d expected=%d\n" \
    "$authority_status" \
    "$authority_registry_verified_declared_rows" \
    "$official_source_authority_verified_declared_rows" \
    "$EXPECTED_ARTIFACT_ROWS"
  printf "fixture-declarations,%s,fixture_free=%d timestamp=%d expected=%d\n" \
    "$fixture_status" \
    "$fixture_free_rows" \
    "$timestamp_rows" \
    "$EXPECTED_ARTIFACT_ROWS"
  printf "external-benchmark-live-package-artifact-fetch-authority,%s,ready=%d action=%s\n" \
    "$ready_status" \
    "$external_benchmark_live_package_artifact_fetch_authority_ready" \
    "$action"
  printf "real-external-benchmark,blocked,real_external_benchmark_verified=%d\n" \
    "$real_external_benchmark_verified"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$jump_status" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"
