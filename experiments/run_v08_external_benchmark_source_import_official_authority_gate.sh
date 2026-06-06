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

PREFIX="v08_external_benchmark_source_import_official_authority_gate"
REAL_VERIFICATION_PREFIX="v08_external_benchmark_source_import_real_verification_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_official_authority_gate_smoke"
  REAL_VERIFICATION_PREFIX="v08_external_benchmark_source_import_real_verification_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_real_verification_gate.sh" "${RUN_ARGS[@]}" >/dev/null

REAL_VERIFICATION_SUMMARY_CSV="$RESULTS_DIR/${REAL_VERIFICATION_PREFIX}_summary.csv"
REAL_VERIFICATION_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV:-$RESULTS_DIR/${REAL_VERIFICATION_PREFIX}_verification.csv}"
AUTHORITY_CSV="$RESULTS_DIR/${PREFIX}_authority.csv"
AUTHORITY_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_authority_header() {
  echo "benchmark_family,source_import_id,network_proof_id,verification_record_id,official_authority_id,official_authority_domain,official_authority_registry_uri,official_authority_record_uri,official_authority_record_hash,benchmark_source_uri,benchmark_source_hash,benchmark_license_uri,benchmark_license_hash,authority_operator_identity_uri,authority_operator_identity_hash,authority_review_uri,authority_review_hash,verified_verification_report_hash,canonical_benchmark_declared,official_trust_root_declared,independent_authority_review,live_authority_observed,real_source_import_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
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

REAL_VERIFICATION_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready source_import_live_registry_network_proof_runner_ready source_import_live_registry_network_proof_ready source_import_real_verification_review_ready source_import_real_verification_ready expected_real_verification_rows real_verification_rows source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-w real-verification summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_contract_ready"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_live_verifier_ready"] + 0,
        $idx["source_import_independent_live_review_ready"] + 0,
        $idx["source_import_authoritative_review_ready"] + 0,
        $idx["source_import_public_registry_ready"] + 0,
        $idx["source_import_live_registry_query_ready"] + 0,
        $idx["source_import_live_registry_fetcher_ready"] + 0,
        $idx["source_import_live_registry_fetch_ready"] + 0,
        $idx["source_import_live_registry_network_proof_runner_ready"] + 0,
        $idx["source_import_live_registry_network_proof_ready"] + 0,
        $idx["source_import_real_verification_review_ready"] + 0,
        $idx["source_import_real_verification_ready"] + 0,
        $idx["expected_real_verification_rows"] + 0,
        $idx["real_verification_rows"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-w real-verification summary row", 3)
    }
  ' "$REAL_VERIFICATION_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready source_import_live_registry_network_proof_runner_ready source_import_live_registry_network_proof_ready source_import_real_verification_review_ready source_import_real_verification_ready expected_real_verification_rows real_verification_rows upstream_source_import_verified real_verification_action real_verification_routing real_verification_jump <<<"$REAL_VERIFICATION_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV:-}" ]]; then
  AUTHORITY_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV"
  AUTHORITY_SOURCE="provided-csv"
  if [[ ! -s "$AUTHORITY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_authority_header >"$AUTHORITY_CSV"
fi

declare -A expected_source_import_id
declare -A expected_network_proof_id
declare -A expected_verification_record_id
declare -A expected_verification_report_hash
declare -A expected_verification_registry_uri
declare -A expected_verification_record_uri
declare -A expected_verification_report_uri
declare -A expected_verifier_identity_uri
declare -A expected_proof_transcript_uri

verification_rows_seen=0
if [[ -s "$REAL_VERIFICATION_CSV" ]]; then
  REAL_VERIFICATION_TSV="$TMP_DIR/source_import_real_verification.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id network_proof_id verification_record_id verification_registry_uri verification_record_uri verification_report_uri verification_report_hash verifier_identity_uri proof_transcript_uri", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-w real-verification source column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-w real-verification source row has wrong column count", 11)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["source_import_id"],
        $idx["network_proof_id"],
        $idx["verification_record_id"],
        $idx["verification_registry_uri"],
        $idx["verification_record_uri"],
        $idx["verification_report_uri"],
        $idx["verification_report_hash"],
        $idx["verifier_identity_uri"],
        $idx["proof_transcript_uri"]
    }
  ' "$REAL_VERIFICATION_CSV" >"$REAL_VERIFICATION_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id network_proof_id verification_record_id verification_registry_uri verification_record_uri verification_report_uri verification_report_hash verifier_identity_uri proof_transcript_uri; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-w real verification family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_network_proof_id["$benchmark_family"]="$network_proof_id"
    expected_verification_record_id["$benchmark_family"]="$verification_record_id"
    expected_verification_report_hash["$benchmark_family"]="$verification_report_hash"
    expected_verification_registry_uri["$benchmark_family"]="$verification_registry_uri"
    expected_verification_record_uri["$benchmark_family"]="$verification_record_uri"
    expected_verification_report_uri["$benchmark_family"]="$verification_report_uri"
    expected_verifier_identity_uri["$benchmark_family"]="$verifier_identity_uri"
    expected_proof_transcript_uri["$benchmark_family"]="$proof_transcript_uri"
    ((verification_rows_seen += 1))
  done <"$REAL_VERIFICATION_TSV"
fi

authority_rows=0
matched_verification_rows=0
source_import_id_match_rows=0
network_proof_id_match_rows=0
verification_record_id_match_rows=0
verification_report_hash_match_rows=0
authority_artifact_rows=0
nonplaceholder_authority_artifact_rows=0
authority_hash_attestation_rows=0
authority_domain_match_rows=0
canonical_benchmark_rows=0
official_trust_root_rows=0
independent_authority_review_rows=0
live_authority_observed_rows=0
declared_real_source_rows=0
non_fixture_declared_rows=0
authority_routing="0.000000"
authority_jump="0.000000"
declare -A authority_seen

AUTHORITY_TSV="$TMP_DIR/source_import_official_authority.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id network_proof_id verification_record_id official_authority_id official_authority_domain official_authority_registry_uri official_authority_record_uri official_authority_record_hash benchmark_source_uri benchmark_source_hash benchmark_license_uri benchmark_license_hash authority_operator_identity_uri authority_operator_identity_hash authority_review_uri authority_review_hash verified_verification_report_hash canonical_benchmark_declared official_trust_root_declared independent_authority_review live_authority_observed real_source_import_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-w official authority column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-w official authority row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["network_proof_id"],
      $idx["verification_record_id"],
      $idx["official_authority_id"],
      $idx["official_authority_domain"],
      $idx["official_authority_registry_uri"],
      $idx["official_authority_record_uri"],
      $idx["official_authority_record_hash"],
      $idx["benchmark_source_uri"],
      $idx["benchmark_source_hash"],
      $idx["benchmark_license_uri"],
      $idx["benchmark_license_hash"],
      $idx["authority_operator_identity_uri"],
      $idx["authority_operator_identity_hash"],
      $idx["authority_review_uri"],
      $idx["authority_review_hash"],
      $idx["verified_verification_report_hash"],
      $idx["canonical_benchmark_declared"] + 0,
      $idx["official_trust_root_declared"] + 0,
      $idx["independent_authority_review"] + 0,
      $idx["live_authority_observed"] + 0,
      $idx["real_source_import_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["hash_attestation_ready"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0
  }
' "$AUTHORITY_CSV" >"$AUTHORITY_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id network_proof_id verification_record_id official_authority_id official_authority_domain official_authority_registry_uri official_authority_record_uri official_authority_record_hash benchmark_source_uri benchmark_source_hash benchmark_license_uri benchmark_license_hash authority_operator_identity_uri authority_operator_identity_hash authority_review_uri authority_review_hash verified_verification_report_hash canonical_benchmark_declared official_trust_root_declared independent_authority_review live_authority_observed real_source_import_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate; do
  ((authority_rows += 1))
  if [[ -n "${authority_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-w official authority family: $benchmark_family" >&2
    exit 15
  fi
  authority_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_verification_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_network_proof_id[$benchmark_family]:-}" == "$network_proof_id" ]] && is_present "$network_proof_id"; then
    ((network_proof_id_match_rows += 1))
  fi
  if [[ "${expected_verification_record_id[$benchmark_family]:-}" == "$verification_record_id" ]] && is_present "$verification_record_id"; then
    ((verification_record_id_match_rows += 1))
  fi
  if [[ "${expected_verification_report_hash[$benchmark_family]:-}" == "$verified_verification_report_hash" ]] && is_sha256 "$verified_verification_report_hash"; then
    ((verification_report_hash_match_rows += 1))
  fi

  if is_present "$official_authority_id" &&
      is_present "$official_authority_domain" &&
      is_https_uri "$official_authority_registry_uri" &&
      is_https_uri "$official_authority_record_uri" &&
      is_https_uri "$benchmark_source_uri" &&
      is_https_uri "$benchmark_license_uri" &&
      is_https_uri "$authority_operator_identity_uri" &&
      is_https_uri "$authority_review_uri" &&
      is_sha256 "$official_authority_record_hash" &&
      is_sha256 "$benchmark_source_hash" &&
      is_sha256 "$benchmark_license_hash" &&
      is_sha256 "$authority_operator_identity_hash" &&
      is_sha256 "$authority_review_hash"; then
    ((authority_artifact_rows += 1))
  fi
  if ! is_placeholder_domain "$official_authority_domain" &&
      is_nonplaceholder_https_uri "$official_authority_registry_uri" &&
      is_nonplaceholder_https_uri "$official_authority_record_uri" &&
      is_nonplaceholder_https_uri "$benchmark_source_uri" &&
      is_nonplaceholder_https_uri "$benchmark_license_uri" &&
      is_nonplaceholder_https_uri "$authority_operator_identity_uri" &&
      is_nonplaceholder_https_uri "$authority_review_uri"; then
    ((nonplaceholder_authority_artifact_rows += 1))
  fi
  if [[ "$hash_attestation_ready" == "1" ]]; then
    ((authority_hash_attestation_rows += 1))
  fi
  if ! is_placeholder_domain "$official_authority_domain" &&
      host_matches_domain "${expected_verification_registry_uri[$benchmark_family]:-}" "$official_authority_domain" &&
      host_matches_domain "${expected_verification_record_uri[$benchmark_family]:-}" "$official_authority_domain" &&
      host_matches_domain "${expected_verification_report_uri[$benchmark_family]:-}" "$official_authority_domain" &&
      host_matches_domain "${expected_verifier_identity_uri[$benchmark_family]:-}" "$official_authority_domain" &&
      host_matches_domain "${expected_proof_transcript_uri[$benchmark_family]:-}" "$official_authority_domain" &&
      host_matches_domain "$official_authority_registry_uri" "$official_authority_domain" &&
      host_matches_domain "$official_authority_record_uri" "$official_authority_domain" &&
      host_matches_domain "$benchmark_source_uri" "$official_authority_domain" &&
      host_matches_domain "$benchmark_license_uri" "$official_authority_domain" &&
      host_matches_domain "$authority_operator_identity_uri" "$official_authority_domain" &&
      host_matches_domain "$authority_review_uri" "$official_authority_domain"; then
    ((authority_domain_match_rows += 1))
  fi
  if [[ "$canonical_benchmark_declared" == "1" ]]; then
    ((canonical_benchmark_rows += 1))
  fi
  if [[ "$official_trust_root_declared" == "1" ]]; then
    ((official_trust_root_rows += 1))
  fi
  if [[ "$independent_authority_review" == "1" ]]; then
    ((independent_authority_review_rows += 1))
  fi
  if [[ "$live_authority_observed" == "1" ]]; then
    ((live_authority_observed_rows += 1))
  fi
  if [[ "$real_source_import_declared" == "1" ]]; then
    ((declared_real_source_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  authority_routing="$(awk -v a="$authority_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  authority_jump="$(awk -v a="$authority_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$AUTHORITY_TSV"

expected_authority_rows="$expected_real_verification_rows"

source_import_official_authority_review_ready=0
if [[ "$source_import_real_verification_ready" == "1" &&
      "$expected_authority_rows" -gt 0 &&
      "$verification_rows_seen" -eq "$expected_authority_rows" &&
      "$authority_rows" -eq "$expected_authority_rows" &&
      "$matched_verification_rows" -eq "$expected_authority_rows" &&
      "$source_import_id_match_rows" -eq "$expected_authority_rows" &&
      "$network_proof_id_match_rows" -eq "$expected_authority_rows" &&
      "$verification_record_id_match_rows" -eq "$expected_authority_rows" &&
      "$verification_report_hash_match_rows" -eq "$expected_authority_rows" &&
      "$authority_artifact_rows" -eq "$expected_authority_rows" &&
      "$authority_hash_attestation_rows" -eq "$expected_authority_rows" &&
      "$authority_domain_match_rows" -eq "$expected_authority_rows" &&
      "$real_verification_routing" == "0.000000" &&
      "$real_verification_jump" == "0.000000" &&
      "$authority_routing" == "0.000000" &&
      "$authority_jump" == "0.000000" ]]; then
  source_import_official_authority_review_ready=1
fi

source_import_official_authority_ready=0
if [[ "$source_import_official_authority_review_ready" == "1" &&
      "$nonplaceholder_authority_artifact_rows" -eq "$expected_authority_rows" &&
      "$canonical_benchmark_rows" -eq "$expected_authority_rows" &&
      "$official_trust_root_rows" -eq "$expected_authority_rows" &&
      "$independent_authority_review_rows" -eq "$expected_authority_rows" &&
      "$live_authority_observed_rows" -eq "$expected_authority_rows" &&
      "$declared_real_source_rows" -eq "$expected_authority_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_authority_rows" ]]; then
  source_import_official_authority_ready=1
fi

source_import_verified=0
if [[ "$source_import_official_authority_ready" == "1" ]]; then
  source_import_verified=1
fi

real_external_benchmark_verified=0
action="$real_verification_action"
if [[ "$source_import_real_verification_ready" == "1" ]]; then
  if [[ "$authority_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-official-authority-missing"
  elif [[ "$authority_rows" -ne "$expected_authority_rows" ||
          "$matched_verification_rows" -ne "$expected_authority_rows" ||
          "$source_import_id_match_rows" -ne "$expected_authority_rows" ||
          "$network_proof_id_match_rows" -ne "$expected_authority_rows" ||
          "$verification_record_id_match_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-row-mismatch"
  elif [[ "$verification_report_hash_match_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-hash-mismatch"
  elif [[ "$authority_artifact_rows" -ne "$expected_authority_rows" ||
          "$authority_hash_attestation_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-artifact-missing"
  elif [[ "$authority_domain_match_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-domain-mismatch"
  elif [[ "$nonplaceholder_authority_artifact_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-placeholder-domain"
  elif [[ "$canonical_benchmark_rows" -ne "$expected_authority_rows" ||
          "$official_trust_root_rows" -ne "$expected_authority_rows" ||
          "$independent_authority_review_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-trust-root-missing"
  elif [[ "$live_authority_observed_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-live-observation-missing"
  elif [[ "$declared_real_source_rows" -ne "$expected_authority_rows" ||
          "$non_fixture_declared_rows" -ne "$expected_authority_rows" ]]; then
    action="external-benchmark-source-import-official-authority-fixture-only"
  elif [[ "$source_import_verified" == "1" ]]; then
    action="external-benchmark-source-import-verified"
  fi
fi

total_routing="$(awk -v a="$real_verification_routing" -v b="$authority_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$real_verification_jump" -v b="$authority_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_contract_ready,source_import_verifier_ready,source_import_live_verifier_ready,source_import_independent_live_review_ready,source_import_authoritative_review_ready,source_import_public_registry_ready,source_import_live_registry_query_ready,source_import_live_registry_fetcher_ready,source_import_live_registry_fetch_ready,source_import_live_registry_network_proof_runner_ready,source_import_live_registry_network_proof_ready,source_import_real_verification_review_ready,source_import_real_verification_ready,source_import_official_authority_source,expected_official_authority_rows,official_authority_rows,matched_verification_rows,source_import_id_match_rows,network_proof_id_match_rows,verification_record_id_match_rows,verification_report_hash_match_rows,authority_artifact_rows,nonplaceholder_authority_artifact_rows,authority_hash_attestation_rows,authority_domain_match_rows,canonical_benchmark_rows,official_trust_root_rows,independent_authority_review_rows,live_authority_observed_rows,declared_real_source_rows,non_fixture_declared_rows,source_import_official_authority_review_ready,source_import_official_authority_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  join_by_comma \
    route-memory-v08w \
    "$benchmark_families" \
    "$source_import_contract_ready" \
    "$source_import_verifier_ready" \
    "$source_import_live_verifier_ready" \
    "$source_import_independent_live_review_ready" \
    "$source_import_authoritative_review_ready" \
    "$source_import_public_registry_ready" \
    "$source_import_live_registry_query_ready" \
    "$source_import_live_registry_fetcher_ready" \
    "$source_import_live_registry_fetch_ready" \
    "$source_import_live_registry_network_proof_runner_ready" \
    "$source_import_live_registry_network_proof_ready" \
    "$source_import_real_verification_review_ready" \
    "$source_import_real_verification_ready" \
    "$AUTHORITY_SOURCE" \
    "$expected_authority_rows" \
    "$authority_rows" \
    "$matched_verification_rows" \
    "$source_import_id_match_rows" \
    "$network_proof_id_match_rows" \
    "$verification_record_id_match_rows" \
    "$verification_report_hash_match_rows" \
    "$authority_artifact_rows" \
    "$nonplaceholder_authority_artifact_rows" \
    "$authority_hash_attestation_rows" \
    "$authority_domain_match_rows" \
    "$canonical_benchmark_rows" \
    "$official_trust_root_rows" \
    "$independent_authority_review_rows" \
    "$live_authority_observed_rows" \
    "$declared_real_source_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_official_authority_review_ready" \
    "$source_import_official_authority_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-real-verification,%s,review_ready=%d ready=%d action=%s\n" \
    "$([[ "$source_import_real_verification_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_real_verification_review_ready" \
    "$source_import_real_verification_ready" \
    "$real_verification_action"
  printf "official-authority-rows,%s,rows=%d expected=%d matched=%d source_import_ids=%d network_proof_ids=%d verification_record_ids=%d\n" \
    "$([[ "$authority_rows" -eq "$expected_authority_rows" && "$matched_verification_rows" -eq "$expected_authority_rows" && "$source_import_id_match_rows" -eq "$expected_authority_rows" && "$network_proof_id_match_rows" -eq "$expected_authority_rows" && "$verification_record_id_match_rows" -eq "$expected_authority_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$authority_rows" \
    "$expected_authority_rows" \
    "$matched_verification_rows" \
    "$source_import_id_match_rows" \
    "$network_proof_id_match_rows" \
    "$verification_record_id_match_rows"
  printf "official-authority-hash,%s,verification_report_hash=%d/%d\n" \
    "$([[ "$verification_report_hash_match_rows" -eq "$expected_authority_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$verification_report_hash_match_rows" \
    "$expected_authority_rows"
  printf "official-authority-artifacts,%s,metadata=%d/%d hash_attestation=%d/%d nonplaceholder=%d/%d domain_match=%d/%d source=%s\n" \
    "$([[ "$authority_artifact_rows" -eq "$expected_authority_rows" && "$authority_hash_attestation_rows" -eq "$expected_authority_rows" && "$nonplaceholder_authority_artifact_rows" -eq "$expected_authority_rows" && "$authority_domain_match_rows" -eq "$expected_authority_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$authority_artifact_rows" \
    "$expected_authority_rows" \
    "$authority_hash_attestation_rows" \
    "$expected_authority_rows" \
    "$nonplaceholder_authority_artifact_rows" \
    "$expected_authority_rows" \
    "$authority_domain_match_rows" \
    "$expected_authority_rows" \
    "$AUTHORITY_SOURCE"
  printf "official-authority-trust-root,%s,canonical=%d/%d trust_root=%d/%d independent=%d/%d live=%d/%d real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$canonical_benchmark_rows" -eq "$expected_authority_rows" && "$official_trust_root_rows" -eq "$expected_authority_rows" && "$independent_authority_review_rows" -eq "$expected_authority_rows" && "$live_authority_observed_rows" -eq "$expected_authority_rows" && "$declared_real_source_rows" -eq "$expected_authority_rows" && "$non_fixture_declared_rows" -eq "$expected_authority_rows" && "$expected_authority_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$canonical_benchmark_rows" \
    "$expected_authority_rows" \
    "$official_trust_root_rows" \
    "$expected_authority_rows" \
    "$independent_authority_review_rows" \
    "$expected_authority_rows" \
    "$live_authority_observed_rows" \
    "$expected_authority_rows" \
    "$declared_real_source_rows" \
    "$expected_authority_rows" \
    "$non_fixture_declared_rows" \
    "$expected_authority_rows"
  printf "source-import-official-authority,%s,review_ready=%d ready=%d action=%s\n" \
    "$([[ "$source_import_official_authority_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_official_authority_review_ready" \
    "$source_import_official_authority_ready" \
    "$action"
  printf "source-import-verification,%s,verified=%d official_authority_ready=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$source_import_official_authority_ready" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
