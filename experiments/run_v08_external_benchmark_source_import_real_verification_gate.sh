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

PREFIX="v08_external_benchmark_source_import_real_verification_gate"
NETWORK_PROOF_PREFIX="v08_external_benchmark_source_import_live_registry_network_proof"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_real_verification_gate_smoke"
  NETWORK_PROOF_PREFIX="v08_external_benchmark_source_import_live_registry_network_proof_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" "${RUN_ARGS[@]}" >/dev/null

NETWORK_PROOF_SUMMARY_CSV="$RESULTS_DIR/${NETWORK_PROOF_PREFIX}_summary.csv"
NETWORK_PROOF_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV:-$RESULTS_DIR/${NETWORK_PROOF_PREFIX}_proof.csv}"
VERIFICATION_CSV="$RESULTS_DIR/${PREFIX}_verification.csv"
VERIFICATION_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_verification_header() {
  echo "benchmark_family,source_import_id,network_proof_id,verification_record_id,verification_registry_uri,verification_record_uri,verification_report_uri,verification_report_hash,verifier_identity_uri,verifier_identity_hash,proof_transcript_uri,proof_transcript_hash,verified_registry_cache_hash,verified_registry_entry_cache_hash,official_external_registry,independent_verifier,network_proof_replayed,live_network_observed,real_source_import_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
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

is_placeholder_uri() {
  local uri="$1"
  [[ "$uri" == *".example.invalid"* ||
     "$uri" == *"localhost"* ||
     "$uri" == *"127.0.0.1"* ||
     "$uri" == *"0.0.0.0"* ]]
}

is_nonplaceholder_https_uri() {
  local uri="$1"
  is_https_uri "$uri" && ! is_placeholder_uri "$uri"
}

NETWORK_PROOF_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready source_import_live_registry_network_proof_runner_ready source_import_live_registry_network_proof_ready expected_network_proof_rows network_proof_rows source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-v network-proof summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
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
        $idx["expected_network_proof_rows"] + 0,
        $idx["network_proof_rows"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-v network-proof summary row", 3)
    }
  ' "$NETWORK_PROOF_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready source_import_live_registry_network_proof_runner_ready source_import_live_registry_network_proof_ready expected_network_proof_rows network_proof_rows upstream_source_import_verified network_proof_action network_proof_routing network_proof_jump <<<"$NETWORK_PROOF_VALUES"

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV:-}" ]]; then
  VERIFICATION_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV"
  VERIFICATION_SOURCE="provided-csv"
  if [[ ! -s "$VERIFICATION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_verification_header >"$VERIFICATION_CSV"
fi

declare -A expected_source_import_id
declare -A expected_network_proof_id
declare -A expected_registry_cache_hash
declare -A expected_registry_entry_cache_hash

proof_rows_seen=0
if [[ -s "$NETWORK_PROOF_CSV" ]]; then
  NETWORK_PROOF_TSV="$TMP_DIR/live_registry_network_proof.tsv"
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family source_import_id network_proof_id registry_cache_hash registry_entry_cache_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-v network-proof source column: " required[i], 10)
      }
      next
    }
    {
      if (NF != header_fields) die("v08-v network-proof source row has wrong column count", 11)
      printf "%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["source_import_id"],
        $idx["network_proof_id"],
        $idx["registry_cache_hash"],
        $idx["registry_entry_cache_hash"]
    }
  ' "$NETWORK_PROOF_CSV" >"$NETWORK_PROOF_TSV"

  while IFS=$'\t' read -r benchmark_family source_import_id network_proof_id registry_cache_hash registry_entry_cache_hash; do
    if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
      echo "duplicate v08-v network proof family: $benchmark_family" >&2
      exit 12
    fi
    expected_source_import_id["$benchmark_family"]="$source_import_id"
    expected_network_proof_id["$benchmark_family"]="$network_proof_id"
    expected_registry_cache_hash["$benchmark_family"]="$registry_cache_hash"
    expected_registry_entry_cache_hash["$benchmark_family"]="$registry_entry_cache_hash"
    ((proof_rows_seen += 1))
  done <"$NETWORK_PROOF_TSV"
fi

verification_rows=0
matched_proof_rows=0
source_import_id_match_rows=0
network_proof_id_match_rows=0
hash_match_rows=0
artifact_metadata_rows=0
nonplaceholder_artifact_rows=0
hash_attestation_rows=0
official_external_registry_rows=0
independent_verifier_rows=0
network_proof_replayed_rows=0
live_network_observed_rows=0
declared_real_source_rows=0
non_fixture_declared_rows=0
verification_routing="0.000000"
verification_jump="0.000000"
declare -A verification_seen

VERIFICATION_TSV="$TMP_DIR/source_import_real_verification.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family source_import_id network_proof_id verification_record_id verification_registry_uri verification_record_uri verification_report_uri verification_report_hash verifier_identity_uri verifier_identity_hash proof_transcript_uri proof_transcript_hash verified_registry_cache_hash verified_registry_entry_cache_hash official_external_registry independent_verifier network_proof_replayed live_network_observed real_source_import_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-v real verification column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-v real verification row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
      $idx["benchmark_family"],
      $idx["source_import_id"],
      $idx["network_proof_id"],
      $idx["verification_record_id"],
      $idx["verification_registry_uri"],
      $idx["verification_record_uri"],
      $idx["verification_report_uri"],
      $idx["verification_report_hash"],
      $idx["verifier_identity_uri"],
      $idx["verifier_identity_hash"],
      $idx["proof_transcript_uri"],
      $idx["proof_transcript_hash"],
      $idx["verified_registry_cache_hash"],
      $idx["verified_registry_entry_cache_hash"],
      $idx["official_external_registry"] + 0,
      $idx["independent_verifier"] + 0,
      $idx["network_proof_replayed"] + 0,
      $idx["live_network_observed"] + 0,
      $idx["real_source_import_declared"] + 0,
      $idx["fixture_or_synthetic_declared"] + 0,
      $idx["hash_attestation_ready"] + 0,
      $idx["routing_trigger_rate"] + 0,
      $idx["active_jump_rate"] + 0
  }
' "$VERIFICATION_CSV" >"$VERIFICATION_TSV"

while IFS=$'\t' read -r benchmark_family source_import_id network_proof_id verification_record_id verification_registry_uri verification_record_uri verification_report_uri verification_report_hash verifier_identity_uri verifier_identity_hash proof_transcript_uri proof_transcript_hash verified_registry_cache_hash verified_registry_entry_cache_hash official_external_registry independent_verifier network_proof_replayed live_network_observed real_source_import_declared fixture_or_synthetic_declared hash_attestation_ready routing_trigger_rate active_jump_rate; do
  ((verification_rows += 1))
  if [[ -n "${verification_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-v real verification family: $benchmark_family" >&2
    exit 15
  fi
  verification_seen["$benchmark_family"]=1

  if [[ -n "${expected_source_import_id[$benchmark_family]:-}" ]]; then
    ((matched_proof_rows += 1))
  fi
  if [[ "${expected_source_import_id[$benchmark_family]:-}" == "$source_import_id" ]] && is_present "$source_import_id"; then
    ((source_import_id_match_rows += 1))
  fi
  if [[ "${expected_network_proof_id[$benchmark_family]:-}" == "$network_proof_id" ]] && is_present "$network_proof_id"; then
    ((network_proof_id_match_rows += 1))
  fi
  if [[ "${expected_registry_cache_hash[$benchmark_family]:-}" == "$verified_registry_cache_hash" &&
        "${expected_registry_entry_cache_hash[$benchmark_family]:-}" == "$verified_registry_entry_cache_hash" ]] &&
      is_sha256 "$verified_registry_cache_hash" &&
      is_sha256 "$verified_registry_entry_cache_hash"; then
    ((hash_match_rows += 1))
  fi

  if is_present "$verification_record_id" &&
      is_https_uri "$verification_registry_uri" &&
      is_https_uri "$verification_record_uri" &&
      is_https_uri "$verification_report_uri" &&
      is_https_uri "$verifier_identity_uri" &&
      is_https_uri "$proof_transcript_uri" &&
      is_sha256 "$verification_report_hash" &&
      is_sha256 "$verifier_identity_hash" &&
      is_sha256 "$proof_transcript_hash"; then
    ((artifact_metadata_rows += 1))
  fi
  if is_nonplaceholder_https_uri "$verification_registry_uri" &&
      is_nonplaceholder_https_uri "$verification_record_uri" &&
      is_nonplaceholder_https_uri "$verification_report_uri" &&
      is_nonplaceholder_https_uri "$verifier_identity_uri" &&
      is_nonplaceholder_https_uri "$proof_transcript_uri"; then
    ((nonplaceholder_artifact_rows += 1))
  fi
  if [[ "$hash_attestation_ready" == "1" ]]; then
    ((hash_attestation_rows += 1))
  fi
  if [[ "$official_external_registry" == "1" ]]; then
    ((official_external_registry_rows += 1))
  fi
  if [[ "$independent_verifier" == "1" ]]; then
    ((independent_verifier_rows += 1))
  fi
  if [[ "$network_proof_replayed" == "1" ]]; then
    ((network_proof_replayed_rows += 1))
  fi
  if [[ "$live_network_observed" == "1" ]]; then
    ((live_network_observed_rows += 1))
  fi
  if [[ "$real_source_import_declared" == "1" ]]; then
    ((declared_real_source_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  verification_routing="$(awk -v a="$verification_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  verification_jump="$(awk -v a="$verification_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$VERIFICATION_TSV"

source_import_real_verification_review_ready=0
if [[ "$source_import_live_registry_network_proof_ready" == "1" &&
      "$expected_network_proof_rows" -gt 0 &&
      "$proof_rows_seen" -eq "$expected_network_proof_rows" &&
      "$verification_rows" -eq "$expected_network_proof_rows" &&
      "$matched_proof_rows" -eq "$expected_network_proof_rows" &&
      "$source_import_id_match_rows" -eq "$expected_network_proof_rows" &&
      "$network_proof_id_match_rows" -eq "$expected_network_proof_rows" &&
      "$hash_match_rows" -eq "$expected_network_proof_rows" &&
      "$artifact_metadata_rows" -eq "$expected_network_proof_rows" &&
      "$hash_attestation_rows" -eq "$expected_network_proof_rows" &&
      "$network_proof_routing" == "0.000000" &&
      "$network_proof_jump" == "0.000000" &&
      "$verification_routing" == "0.000000" &&
      "$verification_jump" == "0.000000" ]]; then
  source_import_real_verification_review_ready=1
fi

source_import_real_verification_ready=0
if [[ "$source_import_real_verification_review_ready" == "1" &&
      "$nonplaceholder_artifact_rows" -eq "$expected_network_proof_rows" &&
      "$official_external_registry_rows" -eq "$expected_network_proof_rows" &&
      "$independent_verifier_rows" -eq "$expected_network_proof_rows" &&
      "$network_proof_replayed_rows" -eq 0 &&
      "$live_network_observed_rows" -eq "$expected_network_proof_rows" &&
      "$declared_real_source_rows" -eq "$expected_network_proof_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_network_proof_rows" ]]; then
  source_import_real_verification_ready=1
fi

source_import_verified=0
if [[ "$source_import_real_verification_ready" == "1" ]]; then
  source_import_verified=1
fi

real_external_benchmark_verified=0
action="$network_proof_action"
if [[ "$source_import_live_registry_network_proof_ready" == "1" ]]; then
  if [[ "$verification_rows" -eq 0 ]]; then
    action="external-benchmark-source-import-real-verification-missing"
  elif [[ "$verification_rows" -ne "$expected_network_proof_rows" ||
          "$matched_proof_rows" -ne "$expected_network_proof_rows" ||
          "$source_import_id_match_rows" -ne "$expected_network_proof_rows" ||
          "$network_proof_id_match_rows" -ne "$expected_network_proof_rows" ]]; then
    action="external-benchmark-source-import-real-verification-row-mismatch"
  elif [[ "$hash_match_rows" -ne "$expected_network_proof_rows" ]]; then
    action="external-benchmark-source-import-real-verification-hash-mismatch"
  elif [[ "$artifact_metadata_rows" -ne "$expected_network_proof_rows" ||
          "$hash_attestation_rows" -ne "$expected_network_proof_rows" ]]; then
    action="external-benchmark-source-import-real-verification-artifact-missing"
  elif [[ "$nonplaceholder_artifact_rows" -ne "$expected_network_proof_rows" ]]; then
    action="external-benchmark-source-import-real-verification-placeholder-domain"
  elif [[ "$official_external_registry_rows" -ne "$expected_network_proof_rows" ||
          "$independent_verifier_rows" -ne "$expected_network_proof_rows" ]]; then
    action="external-benchmark-source-import-real-verification-authority-missing"
  elif [[ "$network_proof_replayed_rows" -ne 0 ||
          "$live_network_observed_rows" -ne "$expected_network_proof_rows" ]]; then
    action="external-benchmark-source-import-real-verification-live-network-missing"
  elif [[ "$declared_real_source_rows" -ne "$expected_network_proof_rows" ||
          "$non_fixture_declared_rows" -ne "$expected_network_proof_rows" ]]; then
    action="external-benchmark-source-import-real-verification-fixture-only"
  elif [[ "$source_import_verified" == "1" ]]; then
    action="external-benchmark-source-import-verified"
  fi
fi

total_routing="$(awk -v a="$network_proof_routing" -v b="$verification_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$network_proof_jump" -v b="$verification_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,source_import_contract_ready,source_import_verifier_ready,source_import_live_verifier_ready,source_import_independent_live_review_ready,source_import_authoritative_review_ready,source_import_public_registry_ready,source_import_live_registry_query_ready,source_import_live_registry_fetcher_ready,source_import_live_registry_fetch_ready,source_import_live_registry_network_proof_runner_ready,source_import_live_registry_network_proof_ready,source_import_real_verification_source,expected_real_verification_rows,real_verification_rows,matched_proof_rows,source_import_id_match_rows,network_proof_id_match_rows,hash_match_rows,artifact_metadata_rows,nonplaceholder_artifact_rows,hash_attestation_rows,official_external_registry_rows,independent_verifier_rows,network_proof_replayed_rows,live_network_observed_rows,declared_real_source_rows,non_fixture_declared_rows,source_import_real_verification_review_ready,source_import_real_verification_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  join_by_comma \
    route-memory-v08v \
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
    "$VERIFICATION_SOURCE" \
    "$expected_network_proof_rows" \
    "$verification_rows" \
    "$matched_proof_rows" \
    "$source_import_id_match_rows" \
    "$network_proof_id_match_rows" \
    "$hash_match_rows" \
    "$artifact_metadata_rows" \
    "$nonplaceholder_artifact_rows" \
    "$hash_attestation_rows" \
    "$official_external_registry_rows" \
    "$independent_verifier_rows" \
    "$network_proof_replayed_rows" \
    "$live_network_observed_rows" \
    "$declared_real_source_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_real_verification_review_ready" \
    "$source_import_real_verification_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-live-registry-network-proof,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_live_registry_network_proof_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_registry_network_proof_ready" \
    "$network_proof_action"
  printf "real-verification-rows,%s,rows=%d expected=%d matched=%d source_import_ids=%d network_proof_ids=%d\n" \
    "$([[ "$verification_rows" -eq "$expected_network_proof_rows" && "$matched_proof_rows" -eq "$expected_network_proof_rows" && "$source_import_id_match_rows" -eq "$expected_network_proof_rows" && "$network_proof_id_match_rows" -eq "$expected_network_proof_rows" && "$expected_network_proof_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$verification_rows" \
    "$expected_network_proof_rows" \
    "$matched_proof_rows" \
    "$source_import_id_match_rows" \
    "$network_proof_id_match_rows"
  printf "real-verification-hash,%s,hash_match=%d/%d\n" \
    "$([[ "$hash_match_rows" -eq "$expected_network_proof_rows" && "$expected_network_proof_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$hash_match_rows" \
    "$expected_network_proof_rows"
  printf "real-verification-artifacts,%s,metadata=%d/%d hash_attestation=%d/%d nonplaceholder=%d/%d source=%s\n" \
    "$([[ "$artifact_metadata_rows" -eq "$expected_network_proof_rows" && "$hash_attestation_rows" -eq "$expected_network_proof_rows" && "$nonplaceholder_artifact_rows" -eq "$expected_network_proof_rows" && "$expected_network_proof_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$artifact_metadata_rows" \
    "$expected_network_proof_rows" \
    "$hash_attestation_rows" \
    "$expected_network_proof_rows" \
    "$nonplaceholder_artifact_rows" \
    "$expected_network_proof_rows" \
    "$VERIFICATION_SOURCE"
  printf "real-verification-authority,%s,official=%d/%d independent=%d/%d replayed=%d live_observed=%d/%d real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$official_external_registry_rows" -eq "$expected_network_proof_rows" && "$independent_verifier_rows" -eq "$expected_network_proof_rows" && "$network_proof_replayed_rows" -eq 0 && "$live_network_observed_rows" -eq "$expected_network_proof_rows" && "$declared_real_source_rows" -eq "$expected_network_proof_rows" && "$non_fixture_declared_rows" -eq "$expected_network_proof_rows" && "$expected_network_proof_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$official_external_registry_rows" \
    "$expected_network_proof_rows" \
    "$independent_verifier_rows" \
    "$expected_network_proof_rows" \
    "$network_proof_replayed_rows" \
    "$live_network_observed_rows" \
    "$expected_network_proof_rows" \
    "$declared_real_source_rows" \
    "$expected_network_proof_rows" \
    "$non_fixture_declared_rows" \
    "$expected_network_proof_rows"
  printf "source-import-real-verification,%s,review_ready=%d ready=%d action=%s\n" \
    "$([[ "$source_import_real_verification_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_real_verification_review_ready" \
    "$source_import_real_verification_ready" \
    "$action"
  printf "source-import-verification,%s,verified=%d real_verification_ready=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$source_import_real_verification_ready" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
