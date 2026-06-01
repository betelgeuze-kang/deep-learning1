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

PREFIX="v08_external_benchmark_source_acquisition_gate"
ADAPTER_PREFIX="v08_external_benchmark_adapter"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_acquisition_gate_smoke"
  ADAPTER_PREFIX="v08_external_benchmark_adapter_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_adapter.sh" "${RUN_ARGS[@]}" >/dev/null

ADAPTER_MANIFEST_CSV="$RESULTS_DIR/${ADAPTER_PREFIX}_manifest.csv"
ACQUISITION_CSV="$RESULTS_DIR/${PREFIX}_acquisition.csv"
ACQUISITION_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_acquisition_header() {
  echo "benchmark_family,acquisition_id,official_benchmark_domain,source_landing_uri,source_landing_hash,dataset_artifact_uri,dataset_artifact_hash,benchmark_card_uri,benchmark_card_hash,split_manifest_uri,split_manifest_hash,license_uri,license_hash,metric_spec_uri,metric_spec_hash,acquisition_method,retrieval_tool,content_hash_algorithm,live_acquisition_observed,independent_source_review,real_external_source_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
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

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV:-}" ]]; then
  ACQUISITION_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV"
  ACQUISITION_SOURCE="provided-csv"
  if [[ ! -s "$ACQUISITION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_acquisition_header >"$ACQUISITION_CSV"
fi

declare -A expected_family
expected_families=0
ADAPTER_TSV="$TMP_DIR/adapter.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("benchmark_family" in idx)) die("missing v08-z adapter benchmark_family column", 2)
    next
  }
  {
    if (NF != header_fields) die("v08-z adapter row has wrong column count", 3)
    print $idx["benchmark_family"]
  }
' "$ADAPTER_MANIFEST_CSV" >"$ADAPTER_TSV"

while IFS= read -r benchmark_family; do
  if [[ -z "${expected_family[$benchmark_family]:-}" ]]; then
    expected_family["$benchmark_family"]=1
    ((expected_families += 1))
  fi
done <"$ADAPTER_TSV"

acquisition_rows=0
matched_adapter_rows=0
official_domain_rows=0
nonplaceholder_domain_rows=0
remote_uri_rows=0
local_uri_rows=0
placeholder_uri_rows=0
insecure_uri_rows=0
missing_uri_rows=0
hash_attestation_rows=0
acquisition_method_rows=0
live_acquisition_observed_rows=0
independent_source_review_rows=0
declared_real_source_rows=0
non_fixture_declared_rows=0
acquisition_routing="0.000000"
acquisition_jump="0.000000"
declare -A acquisition_seen

ACQUISITION_TSV="$TMP_DIR/external_benchmark_source_acquisition.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id official_benchmark_domain source_landing_uri source_landing_hash dataset_artifact_uri dataset_artifact_hash benchmark_card_uri benchmark_card_hash split_manifest_uri split_manifest_hash license_uri license_hash metric_spec_uri metric_spec_hash acquisition_method retrieval_tool content_hash_algorithm live_acquisition_observed independent_source_review real_external_source_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-z acquisition column: " required[i], 10)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-z acquisition row has wrong column count", 11)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$ACQUISITION_CSV" >"$ACQUISITION_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id official_benchmark_domain source_landing_uri source_landing_hash dataset_artifact_uri dataset_artifact_hash benchmark_card_uri benchmark_card_hash split_manifest_uri split_manifest_hash license_uri license_hash metric_spec_uri metric_spec_hash acquisition_method retrieval_tool content_hash_algorithm live_acquisition_observed independent_source_review real_external_source_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate; do
  ((acquisition_rows += 1))
  if [[ -n "${acquisition_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-z acquisition family: $benchmark_family" >&2
    exit 12
  fi
  acquisition_seen["$benchmark_family"]=1

  if [[ -n "${expected_family[$benchmark_family]:-}" ]]; then
    ((matched_adapter_rows += 1))
  fi
  if is_present "$acquisition_id" && is_present "$official_benchmark_domain"; then
    ((official_domain_rows += 1))
  fi
  if ! is_placeholder_domain "$official_benchmark_domain"; then
    ((nonplaceholder_domain_rows += 1))
  fi

  row_remote_uris=0
  row_local_uris=0
  row_placeholder_uris=0
  row_insecure_uris=0
  row_missing_uris=0
  for uri in "$source_landing_uri" "$dataset_artifact_uri" "$benchmark_card_uri" "$split_manifest_uri" "$license_uri" "$metric_spec_uri"; do
    if ! is_present "$uri"; then
      ((row_missing_uris += 1))
    elif [[ "$uri" == file://* ]]; then
      ((row_local_uris += 1))
    elif is_https_uri "$uri"; then
      if is_placeholder_uri "$uri"; then
        ((row_placeholder_uris += 1))
      elif host_matches_domain "$uri" "$official_benchmark_domain"; then
        ((row_remote_uris += 1))
      else
        ((row_insecure_uris += 1))
      fi
    else
      ((row_insecure_uris += 1))
    fi
  done
  if [[ "$row_remote_uris" -eq 6 ]]; then
    ((remote_uri_rows += 1))
  fi
  if [[ "$row_local_uris" -gt 0 ]]; then
    ((local_uri_rows += 1))
  fi
  if [[ "$row_placeholder_uris" -gt 0 ]]; then
    ((placeholder_uri_rows += 1))
  fi
  if [[ "$row_insecure_uris" -gt 0 ]]; then
    ((insecure_uri_rows += 1))
  fi
  if [[ "$row_missing_uris" -gt 0 ]]; then
    ((missing_uri_rows += 1))
  fi

  if is_sha256 "$source_landing_hash" &&
      is_sha256 "$dataset_artifact_hash" &&
      is_sha256 "$benchmark_card_hash" &&
      is_sha256 "$split_manifest_hash" &&
      is_sha256 "$license_hash" &&
      is_sha256 "$metric_spec_hash" &&
      [[ "$hash_attestation_ready" == "1" ]]; then
    ((hash_attestation_rows += 1))
  fi
  if is_present "$acquisition_method" &&
      is_present "$retrieval_tool" &&
      is_present "$content_hash_algorithm" &&
      [[ "$acquisition_method" != "local" &&
         "$acquisition_method" != "fixture" &&
         "$acquisition_method" != "pending" &&
         "$retrieval_tool" != "local" &&
         "$retrieval_tool" != "fixture" &&
         "$retrieval_tool" != "pending" &&
         "$content_hash_algorithm" == "sha256" ]]; then
    ((acquisition_method_rows += 1))
  fi
  if [[ "$live_acquisition_observed" == "1" ]]; then
    ((live_acquisition_observed_rows += 1))
  fi
  if [[ "$independent_source_review" == "1" ]]; then
    ((independent_source_review_rows += 1))
  fi
  if [[ "$real_external_source_declared" == "1" ]]; then
    ((declared_real_source_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi
  acquisition_routing="$(awk -v a="$acquisition_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  acquisition_jump="$(awk -v a="$acquisition_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$ACQUISITION_TSV"

expected_acquisition_rows="$expected_families"
external_benchmark_source_acquisition_review_ready=0
if [[ "$expected_acquisition_rows" -gt 0 &&
      "$acquisition_rows" -eq "$expected_acquisition_rows" &&
      "$matched_adapter_rows" -eq "$expected_acquisition_rows" &&
      "$official_domain_rows" -eq "$expected_acquisition_rows" &&
      "$nonplaceholder_domain_rows" -eq "$expected_acquisition_rows" &&
      "$remote_uri_rows" -eq "$expected_acquisition_rows" &&
      "$local_uri_rows" -eq 0 &&
      "$placeholder_uri_rows" -eq 0 &&
      "$insecure_uri_rows" -eq 0 &&
      "$missing_uri_rows" -eq 0 &&
      "$hash_attestation_rows" -eq "$expected_acquisition_rows" &&
      "$acquisition_method_rows" -eq "$expected_acquisition_rows" &&
      "$independent_source_review_rows" -eq "$expected_acquisition_rows" &&
      "$acquisition_routing" == "0.000000" &&
      "$acquisition_jump" == "0.000000" ]]; then
  external_benchmark_source_acquisition_review_ready=1
fi

external_benchmark_source_acquisition_ready=0
if [[ "$external_benchmark_source_acquisition_review_ready" == "1" &&
      "$live_acquisition_observed_rows" -eq "$expected_acquisition_rows" &&
      "$declared_real_source_rows" -eq "$expected_acquisition_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_acquisition_rows" ]]; then
  external_benchmark_source_acquisition_ready=1
fi

real_external_benchmark_verified=0
action="external-benchmark-source-acquisition-missing"
if [[ "$acquisition_rows" -eq 0 ]]; then
  action="external-benchmark-source-acquisition-missing"
elif [[ "$acquisition_rows" -ne "$expected_acquisition_rows" ||
        "$matched_adapter_rows" -ne "$expected_acquisition_rows" ]]; then
  action="external-benchmark-source-acquisition-row-mismatch"
elif [[ "$missing_uri_rows" -ne 0 ]]; then
  action="external-benchmark-source-acquisition-uri-missing"
elif [[ "$local_uri_rows" -ne 0 ]]; then
  action="external-benchmark-source-acquisition-local-artifact"
elif [[ "$placeholder_uri_rows" -ne 0 ||
        "$nonplaceholder_domain_rows" -ne "$expected_acquisition_rows" ]]; then
  action="external-benchmark-source-acquisition-placeholder-domain"
elif [[ "$remote_uri_rows" -ne "$expected_acquisition_rows" ||
        "$insecure_uri_rows" -ne 0 ]]; then
  action="external-benchmark-source-acquisition-domain-mismatch"
elif [[ "$hash_attestation_rows" -ne "$expected_acquisition_rows" ]]; then
  action="external-benchmark-source-acquisition-hash-missing"
elif [[ "$acquisition_method_rows" -ne "$expected_acquisition_rows" ]]; then
  action="external-benchmark-source-acquisition-method-missing"
elif [[ "$independent_source_review_rows" -ne "$expected_acquisition_rows" ]]; then
  action="external-benchmark-source-acquisition-review-missing"
elif [[ "$live_acquisition_observed_rows" -ne "$expected_acquisition_rows" ]]; then
  action="external-benchmark-source-acquisition-live-observation-missing"
elif [[ "$declared_real_source_rows" -ne "$expected_acquisition_rows" ||
        "$non_fixture_declared_rows" -ne "$expected_acquisition_rows" ]]; then
  action="external-benchmark-source-acquisition-fixture-only"
elif [[ "$external_benchmark_source_acquisition_ready" == "1" ]]; then
  action="external-benchmark-source-acquisition-ready-await-import"
fi

{
  echo "benchmark_scope,benchmark_families,external_benchmark_source_acquisition_source,expected_acquisition_rows,acquisition_rows,matched_adapter_rows,official_domain_rows,nonplaceholder_domain_rows,remote_uri_rows,local_uri_rows,placeholder_uri_rows,insecure_uri_rows,missing_uri_rows,hash_attestation_rows,acquisition_method_rows,live_acquisition_observed_rows,independent_source_review_rows,declared_real_source_rows,non_fixture_declared_rows,external_benchmark_source_acquisition_review_ready,external_benchmark_source_acquisition_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08z,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$expected_families" \
    "$ACQUISITION_SOURCE" \
    "$expected_acquisition_rows" \
    "$acquisition_rows" \
    "$matched_adapter_rows" \
    "$official_domain_rows" \
    "$nonplaceholder_domain_rows" \
    "$remote_uri_rows" \
    "$local_uri_rows" \
    "$placeholder_uri_rows" \
    "$insecure_uri_rows" \
    "$missing_uri_rows" \
    "$hash_attestation_rows" \
    "$acquisition_method_rows" \
    "$live_acquisition_observed_rows" \
    "$independent_source_review_rows" \
    "$declared_real_source_rows" \
    "$non_fixture_declared_rows" \
    "$external_benchmark_source_acquisition_review_ready" \
    "$external_benchmark_source_acquisition_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$acquisition_routing" \
    "$acquisition_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "adapter-families,%s,matched=%d/%d\n" \
    "$([[ "$matched_adapter_rows" -eq "$expected_acquisition_rows" && "$expected_acquisition_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$matched_adapter_rows" \
    "$expected_acquisition_rows"
  printf "source-uris,%s,remote=%d/%d local=%d placeholder=%d insecure=%d missing=%d\n" \
    "$([[ "$remote_uri_rows" -eq "$expected_acquisition_rows" && "$local_uri_rows" -eq 0 && "$placeholder_uri_rows" -eq 0 && "$insecure_uri_rows" -eq 0 && "$missing_uri_rows" -eq 0 && "$expected_acquisition_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$remote_uri_rows" \
    "$expected_acquisition_rows" \
    "$local_uri_rows" \
    "$placeholder_uri_rows" \
    "$insecure_uri_rows" \
    "$missing_uri_rows"
  printf "hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$hash_attestation_rows" -eq "$expected_acquisition_rows" && "$expected_acquisition_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$hash_attestation_rows" \
    "$expected_acquisition_rows"
  printf "acquisition-method,%s,method=%d/%d review=%d/%d live=%d/%d\n" \
    "$([[ "$acquisition_method_rows" -eq "$expected_acquisition_rows" && "$independent_source_review_rows" -eq "$expected_acquisition_rows" && "$expected_acquisition_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$acquisition_method_rows" \
    "$expected_acquisition_rows" \
    "$independent_source_review_rows" \
    "$expected_acquisition_rows" \
    "$live_acquisition_observed_rows" \
    "$expected_acquisition_rows"
  printf "source-declaration,%s,real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$declared_real_source_rows" -eq "$expected_acquisition_rows" && "$non_fixture_declared_rows" -eq "$expected_acquisition_rows" && "$expected_acquisition_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$declared_real_source_rows" \
    "$expected_acquisition_rows" \
    "$non_fixture_declared_rows" \
    "$expected_acquisition_rows"
  printf "external-benchmark-source-acquisition,%s,review_ready=%d acquisition_ready=%d real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$external_benchmark_source_acquisition_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_source_acquisition_review_ready" \
    "$external_benchmark_source_acquisition_ready" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "acquisition: $ACQUISITION_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
