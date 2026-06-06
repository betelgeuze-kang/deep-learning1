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

PREFIX="v08_external_benchmark_final_review_gate"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
EXECUTION_PREFIX="v08_external_benchmark_execution_gate"
ATTESTATION_PREFIX="v08_external_benchmark_attestation_gate"
IDENTITY_PREFIX="v08_external_benchmark_attestor_identity_gate"
SOURCE_IMPORT_PREFIX="v08_external_benchmark_source_import_gate"
SOURCE_IMPORT_VERIFIER_PREFIX="v08_external_benchmark_source_import_verifier_gate"
SOURCE_IMPORT_LIVE_VERIFIER_PREFIX="v08_external_benchmark_source_import_live_verifier_gate"
SOURCE_IMPORT_LIVE_REVIEW_PREFIX="v08_external_benchmark_source_import_live_review_gate"
SOURCE_IMPORT_AUTHORITY_REVIEW_PREFIX="v08_external_benchmark_source_import_authoritative_review_gate"
SOURCE_IMPORT_PUBLIC_REGISTRY_PREFIX="v08_external_benchmark_source_import_public_registry_gate"
SOURCE_IMPORT_LIVE_REGISTRY_QUERY_PREFIX="v08_external_benchmark_source_import_live_registry_query_gate"
SOURCE_IMPORT_LIVE_REGISTRY_FETCHER_PREFIX="v08_external_benchmark_source_import_live_registry_fetcher"
SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_PREFIX="v08_external_benchmark_source_import_live_registry_network_proof"
SOURCE_IMPORT_REAL_VERIFICATION_PREFIX="v08_external_benchmark_source_import_real_verification_gate"
SOURCE_IMPORT_OFFICIAL_AUTHORITY_PREFIX="v08_external_benchmark_source_import_official_authority_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_final_review_gate_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  EXECUTION_PREFIX="v08_external_benchmark_execution_gate_smoke"
  ATTESTATION_PREFIX="v08_external_benchmark_attestation_gate_smoke"
  IDENTITY_PREFIX="v08_external_benchmark_attestor_identity_gate_smoke"
  SOURCE_IMPORT_PREFIX="v08_external_benchmark_source_import_gate_smoke"
  SOURCE_IMPORT_VERIFIER_PREFIX="v08_external_benchmark_source_import_verifier_gate_smoke"
  SOURCE_IMPORT_LIVE_VERIFIER_PREFIX="v08_external_benchmark_source_import_live_verifier_gate_smoke"
  SOURCE_IMPORT_LIVE_REVIEW_PREFIX="v08_external_benchmark_source_import_live_review_gate_smoke"
  SOURCE_IMPORT_AUTHORITY_REVIEW_PREFIX="v08_external_benchmark_source_import_authoritative_review_gate_smoke"
  SOURCE_IMPORT_PUBLIC_REGISTRY_PREFIX="v08_external_benchmark_source_import_public_registry_gate_smoke"
  SOURCE_IMPORT_LIVE_REGISTRY_QUERY_PREFIX="v08_external_benchmark_source_import_live_registry_query_gate_smoke"
  SOURCE_IMPORT_LIVE_REGISTRY_FETCHER_PREFIX="v08_external_benchmark_source_import_live_registry_fetcher_smoke"
  SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_PREFIX="v08_external_benchmark_source_import_live_registry_network_proof_smoke"
  SOURCE_IMPORT_REAL_VERIFICATION_PREFIX="v08_external_benchmark_source_import_real_verification_gate_smoke"
  SOURCE_IMPORT_OFFICIAL_AUTHORITY_PREFIX="v08_external_benchmark_source_import_official_authority_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_attestor_identity_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_verifier_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_verifier_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_review_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_authoritative_review_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_public_registry_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_query_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_fetcher.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_live_registry_network_proof.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_real_verification_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_official_authority_gate.sh" "${RUN_ARGS[@]}" >/dev/null

EVIDENCE_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv"
EXECUTION_CSV="$RESULTS_DIR/${EXECUTION_PREFIX}_execution.csv"
ATTESTATION_CSV="$RESULTS_DIR/${ATTESTATION_PREFIX}_attestation.csv"
IDENTITY_CSV="$RESULTS_DIR/${IDENTITY_PREFIX}_identity.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV"
fi
if [[ -n "${V08_EXTERNAL_BENCHMARK_EXECUTION_CSV:-}" ]]; then
  EXECUTION_CSV="$V08_EXTERNAL_BENCHMARK_EXECUTION_CSV"
fi
if [[ -n "${V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV:-}" ]]; then
  ATTESTATION_CSV="$V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV"
fi
if [[ -n "${V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV:-}" ]]; then
  IDENTITY_CSV="$V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV"
fi

REVIEW_CSV="$RESULTS_DIR/${PREFIX}_review.csv"
REVIEW_SOURCE="pending-fixture"
if [[ -n "${V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV:-}" ]]; then
  REVIEW_CSV="$V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV"
  REVIEW_SOURCE="provided-csv"
  if [[ ! -s "$REVIEW_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  awk -F, -v out="$REVIEW_CSV" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family attestation_id attestor_registry_id", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          print "missing v08 final review pending fixture identity column: " required[i] > "/dev/stderr"
          exit 2
        }
      }
      print "benchmark_family,attestation_id,review_id,review_report_uri,review_report_hash,reviewer_name,reviewer_org,reviewer_role,reviewer_independent,reviewer_identity_uri,reviewer_identity_hash,reviewer_conflict_disclosure_uri,reviewer_conflict_disclosure_hash,review_scope,review_protocol_version,reviewed_source_hash,reviewed_provenance_hash,reviewed_evaluator_output_hash,reviewed_run_log_hash,reviewed_metric_value,reviewed_attestor_registry_id,real_benchmark_source_declared,fixture_or_synthetic_declared,license_review_ready,metric_review_ready,execution_review_ready,attestation_review_ready,identity_review_ready,conflict_review_ready,reproducibility_review_ready,review_approved,routing_trigger_rate,active_jump_rate" > out
      next
    }
    {
      printf "%s,%s,pending,pending,pending,pending,pending,pending,0,pending,pending,pending,pending,pending,pending,pending,pending,pending,pending,pending,%s,0,1,0,0,0,0,0,0,0,0,0,0\n",
        $idx["benchmark_family"],
        $idx["attestation_id"],
        $idx["attestor_registry_id"] >> out
    }
  ' "$IDENTITY_CSV"
fi

IDENTITY_SUMMARY_CSV="$RESULTS_DIR/${IDENTITY_PREFIX}_summary.csv"
SOURCE_IMPORT_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_IMPORT_OFFICIAL_AUTHORITY_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

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

uri_to_local_path() {
  local uri="$1"
  if [[ "$uri" == file://* ]]; then
    printf '%s\n' "${uri#file://}"
    return 0
  fi
  return 1
}

is_https_uri() {
  local uri="$1"
  [[ "$uri" == https://* ]]
}

hash_matches() {
  local path="$1"
  local expected="$2"
  local expected_hex
  local actual_hex

  if [[ ! -f "$path" ]] || ! is_sha256 "$expected"; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

IDENTITY_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families evidence_source authenticity_source execution_source attestation_source attestor_identity_source evaluator_execution_verified independent_attestation_verified attestor_identity_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 final review identity summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%s,%s,%s,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["evidence_source"],
        $idx["authenticity_source"],
        $idx["execution_source"],
        $idx["attestation_source"],
        $idx["attestor_identity_source"],
        $idx["evaluator_execution_verified"] + 0,
        $idx["independent_attestation_verified"] + 0,
        $idx["attestor_identity_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08 final review identity summary row", 3)
    }
  ' "$IDENTITY_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families evidence_source authenticity_source execution_source attestation_source attestor_identity_source evaluator_execution_verified independent_attestation_verified attestor_identity_verified identity_action summary_routing summary_jump <<<"$IDENTITY_VALUES"

declare -A source_hash_by_family
declare -A provenance_hash_by_family
local_upstream_evidence_artifact_rows=0
while IFS=$'\t' read -r benchmark_family dataset_uri source_hash result_uri provenance_hash; do
  source_hash_by_family["$benchmark_family"]="$source_hash"
  provenance_hash_by_family["$benchmark_family"]="$provenance_hash"
  if uri_to_local_path "$dataset_uri" >/dev/null; then
    ((local_upstream_evidence_artifact_rows += 1))
  fi
  if uri_to_local_path "$result_uri" >/dev/null; then
    ((local_upstream_evidence_artifact_rows += 1))
  fi
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family dataset_uri source_hash result_uri provenance_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 final review evidence column: " required[i], 4)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["dataset_uri"],
        $idx["source_hash"],
        $idx["result_uri"],
        $idx["provenance_hash"]
    }
  ' "$EVIDENCE_CSV"
)

declare -A evaluator_output_hash_by_family
declare -A run_log_hash_by_family
declare -A metric_value_by_family
local_upstream_execution_artifact_rows=0
while IFS=$'\t' read -r benchmark_family evaluator_output_uri evaluator_output_hash run_log_uri run_log_hash metric_value; do
  evaluator_output_hash_by_family["$benchmark_family"]="$evaluator_output_hash"
  run_log_hash_by_family["$benchmark_family"]="$run_log_hash"
  metric_value_by_family["$benchmark_family"]="$metric_value"
  if uri_to_local_path "$evaluator_output_uri" >/dev/null; then
    ((local_upstream_execution_artifact_rows += 1))
  fi
  if uri_to_local_path "$run_log_uri" >/dev/null; then
    ((local_upstream_execution_artifact_rows += 1))
  fi
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family evaluator_output_uri evaluator_output_hash run_log_uri run_log_hash metric_value", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 final review execution column: " required[i], 5)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["evaluator_output_uri"],
        $idx["evaluator_output_hash"],
        $idx["run_log_uri"],
        $idx["run_log_hash"],
        $idx["metric_value"]
    }
  ' "$EXECUTION_CSV"
)

declare -A attestation_id_by_family
local_upstream_attestation_artifact_rows=0
while IFS=$'\t' read -r benchmark_family attestation_id attestation_uri; do
  attestation_id_by_family["$benchmark_family"]="$attestation_id"
  if uri_to_local_path "$attestation_uri" >/dev/null; then
    ((local_upstream_attestation_artifact_rows += 1))
  fi
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family attestation_id attestation_uri", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 final review attestation column: " required[i], 6)
      }
      next
    }
    {
      printf "%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["attestation_id"],
        $idx["attestation_uri"]
    }
  ' "$ATTESTATION_CSV"
)

declare -A identity_attestation_id_by_family
declare -A attestor_registry_id_by_family
identity_rows=0
local_upstream_identity_artifact_rows=0
while IFS=$'\t' read -r benchmark_family attestation_id attestor_registry_id attestor_identity_uri attestor_registry_uri conflict_disclosure_uri; do
  ((identity_rows += 1))
  identity_attestation_id_by_family["$benchmark_family"]="$attestation_id"
  attestor_registry_id_by_family["$benchmark_family"]="$attestor_registry_id"
  if uri_to_local_path "$attestor_identity_uri" >/dev/null; then
    ((local_upstream_identity_artifact_rows += 1))
  fi
  if uri_to_local_path "$attestor_registry_uri" >/dev/null; then
    ((local_upstream_identity_artifact_rows += 1))
  fi
  if uri_to_local_path "$conflict_disclosure_uri" >/dev/null; then
    ((local_upstream_identity_artifact_rows += 1))
  fi
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family attestation_id attestor_registry_id attestor_identity_uri attestor_registry_uri conflict_disclosure_uri", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 final review identity column: " required[i], 7)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["attestation_id"],
        $idx["attestor_registry_id"],
        $idx["attestor_identity_uri"],
        $idx["attestor_registry_uri"],
        $idx["conflict_disclosure_uri"]
    }
  ' "$IDENTITY_CSV"
)

local_upstream_artifact_rows=$((local_upstream_evidence_artifact_rows + local_upstream_execution_artifact_rows + local_upstream_attestation_artifact_rows + local_upstream_identity_artifact_rows))

SOURCE_IMPORT_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready source_import_live_registry_network_proof_runner_ready source_import_live_registry_network_proof_ready source_import_real_verification_review_ready source_import_real_verification_ready source_import_official_authority_review_ready source_import_official_authority_ready source_import_verified action", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 final review source import summary column: " required[i], 8)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s\n",
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
        $idx["source_import_official_authority_review_ready"] + 0,
        $idx["source_import_official_authority_ready"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"]
    }
    END {
      if (rows != 1) die("expected one v08 final review source import summary row", 9)
    }
  ' "$SOURCE_IMPORT_SUMMARY_CSV"
)"

IFS=, read -r source_import_contract_ready source_import_verifier_ready source_import_live_verifier_ready source_import_independent_live_review_ready source_import_authoritative_review_ready source_import_public_registry_ready source_import_live_registry_query_ready source_import_live_registry_fetcher_ready source_import_live_registry_fetch_ready source_import_live_registry_network_proof_runner_ready source_import_live_registry_network_proof_ready source_import_real_verification_review_ready source_import_real_verification_ready source_import_official_authority_review_ready source_import_official_authority_ready source_import_verified source_import_action <<<"$SOURCE_IMPORT_VALUES"

review_rows=0
matched_attestation_rows=0
review_ready_rows=0
review_artifact_rows=0
review_hash_verified_rows=0
local_final_review_artifact_rows=0
nonlocal_final_review_artifact_rows=0
reviewer_identity_rows=0
reviewer_identity_hash_verified_rows=0
local_reviewer_identity_rows=0
nonlocal_reviewer_identity_rows=0
reviewer_conflict_rows=0
reviewer_conflict_hash_verified_rows=0
local_reviewer_conflict_rows=0
nonlocal_reviewer_conflict_rows=0
critical_hash_match_rows=0
metric_match_rows=0
review_approved_rows=0
real_source_declared_rows=0
non_fixture_declared_rows=0
review_routing="0.000000"
review_jump="0.000000"
declare -A review_seen

while IFS=$'\t' read -r benchmark_family attestation_id review_id review_report_uri review_report_hash reviewer_name reviewer_org reviewer_role reviewer_independent reviewer_identity_uri reviewer_identity_hash reviewer_conflict_disclosure_uri reviewer_conflict_disclosure_hash review_scope review_protocol_version reviewed_source_hash reviewed_provenance_hash reviewed_evaluator_output_hash reviewed_run_log_hash reviewed_metric_value reviewed_attestor_registry_id real_benchmark_source_declared fixture_or_synthetic_declared license_review_ready metric_review_ready execution_review_ready attestation_review_ready identity_review_ready conflict_review_ready reproducibility_review_ready review_approved routing_trigger_rate active_jump_rate review_report_hash_attested reviewer_identity_hash_attested reviewer_conflict_disclosure_hash_attested; do
  ((review_rows += 1))
  if [[ -n "${review_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08 final review family: $benchmark_family" >&2
    exit 8
  fi
  review_seen["$benchmark_family"]=1

  if [[ -n "${identity_attestation_id_by_family[$benchmark_family]:-}" &&
        -n "${attestation_id_by_family[$benchmark_family]:-}" &&
        "${identity_attestation_id_by_family[$benchmark_family]}" == "$attestation_id" &&
        "${attestation_id_by_family[$benchmark_family]}" == "$attestation_id" ]] &&
      is_present "$attestation_id"; then
    ((matched_attestation_rows += 1))
  fi

  if [[ "$license_review_ready" == "1" &&
        "$metric_review_ready" == "1" &&
        "$execution_review_ready" == "1" &&
        "$attestation_review_ready" == "1" &&
        "$identity_review_ready" == "1" &&
        "$conflict_review_ready" == "1" &&
        "$reproducibility_review_ready" == "1" ]] &&
      is_present "$review_id" &&
      is_present "$review_report_uri" &&
      is_present "$reviewer_name" &&
      is_present "$reviewer_org" &&
      is_present "$reviewer_role" &&
      is_present "$review_scope" &&
      is_present "$review_protocol_version"; then
    ((review_ready_rows += 1))
  fi

  if review_path="$(uri_to_local_path "$review_report_uri")"; then
    ((local_final_review_artifact_rows += 1))
    ((review_artifact_rows += 1))
    if hash_matches "$review_path" "$review_report_hash"; then
      ((review_hash_verified_rows += 1))
    fi
  elif is_https_uri "$review_report_uri" &&
       [[ "$review_report_hash_attested" == "1" ]] &&
       is_sha256 "$review_report_hash"; then
    ((nonlocal_final_review_artifact_rows += 1))
    ((review_artifact_rows += 1))
    ((review_hash_verified_rows += 1))
  fi

  if reviewer_identity_path="$(uri_to_local_path "$reviewer_identity_uri")"; then
    ((local_reviewer_identity_rows += 1))
    ((reviewer_identity_rows += 1))
    if hash_matches "$reviewer_identity_path" "$reviewer_identity_hash"; then
      ((reviewer_identity_hash_verified_rows += 1))
    fi
  elif is_https_uri "$reviewer_identity_uri" &&
       [[ "$reviewer_identity_hash_attested" == "1" ]] &&
       is_sha256 "$reviewer_identity_hash"; then
    ((nonlocal_reviewer_identity_rows += 1))
    ((reviewer_identity_rows += 1))
    ((reviewer_identity_hash_verified_rows += 1))
  fi

  if reviewer_conflict_path="$(uri_to_local_path "$reviewer_conflict_disclosure_uri")"; then
    ((local_reviewer_conflict_rows += 1))
    ((reviewer_conflict_rows += 1))
    if hash_matches "$reviewer_conflict_path" "$reviewer_conflict_disclosure_hash"; then
      ((reviewer_conflict_hash_verified_rows += 1))
    fi
  elif is_https_uri "$reviewer_conflict_disclosure_uri" &&
       [[ "$reviewer_conflict_disclosure_hash_attested" == "1" ]] &&
       is_sha256 "$reviewer_conflict_disclosure_hash"; then
    ((nonlocal_reviewer_conflict_rows += 1))
    ((reviewer_conflict_rows += 1))
    ((reviewer_conflict_hash_verified_rows += 1))
  fi

  if [[ -n "${source_hash_by_family[$benchmark_family]:-}" &&
        -n "${provenance_hash_by_family[$benchmark_family]:-}" &&
        -n "${evaluator_output_hash_by_family[$benchmark_family]:-}" &&
        -n "${run_log_hash_by_family[$benchmark_family]:-}" &&
        -n "${attestor_registry_id_by_family[$benchmark_family]:-}" &&
        "$reviewed_source_hash" == "${source_hash_by_family[$benchmark_family]}" &&
        "$reviewed_provenance_hash" == "${provenance_hash_by_family[$benchmark_family]}" &&
        "$reviewed_evaluator_output_hash" == "${evaluator_output_hash_by_family[$benchmark_family]}" &&
        "$reviewed_run_log_hash" == "${run_log_hash_by_family[$benchmark_family]}" &&
        "$reviewed_attestor_registry_id" == "${attestor_registry_id_by_family[$benchmark_family]}" ]] &&
      is_sha256 "$reviewed_source_hash" &&
      is_sha256 "$reviewed_provenance_hash" &&
      is_sha256 "$reviewed_evaluator_output_hash" &&
      is_sha256 "$reviewed_run_log_hash" &&
      is_present "$reviewed_attestor_registry_id"; then
    ((critical_hash_match_rows += 1))
  fi

  if [[ -n "${metric_value_by_family[$benchmark_family]:-}" &&
        "$reviewed_metric_value" == "${metric_value_by_family[$benchmark_family]}" ]] &&
      is_present "$reviewed_metric_value"; then
    ((metric_match_rows += 1))
  fi

  if [[ "$review_approved" == "1" &&
        "$reviewer_independent" == "1" ]]; then
    ((review_approved_rows += 1))
  fi

  if [[ "$real_benchmark_source_declared" == "1" ]]; then
    ((real_source_declared_rows += 1))
  fi

  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  review_routing="$(awk -v a="$review_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  review_jump="$(awk -v a="$review_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family attestation_id review_id review_report_uri review_report_hash reviewer_name reviewer_org reviewer_role reviewer_independent reviewer_identity_uri reviewer_identity_hash reviewer_conflict_disclosure_uri reviewer_conflict_disclosure_hash review_scope review_protocol_version reviewed_source_hash reviewed_provenance_hash reviewed_evaluator_output_hash reviewed_run_log_hash reviewed_metric_value reviewed_attestor_registry_id real_benchmark_source_declared fixture_or_synthetic_declared license_review_ready metric_review_ready execution_review_ready attestation_review_ready identity_review_ready conflict_review_ready reproducibility_review_ready review_approved routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 final review column: " required[i], 9)
      }
      review_report_hash_attested_idx = ("review_report_hash_attested" in idx) ? idx["review_report_hash_attested"] : 0
      reviewer_identity_hash_attested_idx = ("reviewer_identity_hash_attested" in idx) ? idx["reviewer_identity_hash_attested"] : 0
      reviewer_conflict_disclosure_hash_attested_idx = ("reviewer_conflict_disclosure_hash_attested" in idx) ? idx["reviewer_conflict_disclosure_hash_attested"] : 0
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%d\n",
        $idx["benchmark_family"],
        $idx["attestation_id"],
        $idx["review_id"],
        $idx["review_report_uri"],
        $idx["review_report_hash"],
        $idx["reviewer_name"],
        $idx["reviewer_org"],
        $idx["reviewer_role"],
        $idx["reviewer_independent"] + 0,
        $idx["reviewer_identity_uri"],
        $idx["reviewer_identity_hash"],
        $idx["reviewer_conflict_disclosure_uri"],
        $idx["reviewer_conflict_disclosure_hash"],
        $idx["review_scope"],
        $idx["review_protocol_version"],
        $idx["reviewed_source_hash"],
        $idx["reviewed_provenance_hash"],
        $idx["reviewed_evaluator_output_hash"],
        $idx["reviewed_run_log_hash"],
        $idx["reviewed_metric_value"],
        $idx["reviewed_attestor_registry_id"],
        $idx["real_benchmark_source_declared"] + 0,
        $idx["fixture_or_synthetic_declared"] + 0,
        $idx["license_review_ready"] + 0,
        $idx["metric_review_ready"] + 0,
        $idx["execution_review_ready"] + 0,
        $idx["attestation_review_ready"] + 0,
        $idx["identity_review_ready"] + 0,
        $idx["conflict_review_ready"] + 0,
        $idx["reproducibility_review_ready"] + 0,
        $idx["review_approved"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0,
        review_report_hash_attested_idx ? $review_report_hash_attested_idx + 0 : 0,
        reviewer_identity_hash_attested_idx ? $reviewer_identity_hash_attested_idx + 0 : 0,
        reviewer_conflict_disclosure_hash_attested_idx ? $reviewer_conflict_disclosure_hash_attested_idx + 0 : 0
    }
  ' "$REVIEW_CSV"
)

final_review_verified=0
if [[ "$attestor_identity_verified" == "1" &&
      "$review_rows" -eq "$benchmark_families" &&
      "$matched_attestation_rows" -eq "$benchmark_families" &&
      "$review_ready_rows" -eq "$benchmark_families" &&
      "$review_artifact_rows" -eq "$benchmark_families" &&
      "$review_hash_verified_rows" -eq "$benchmark_families" &&
      "$reviewer_identity_rows" -eq "$benchmark_families" &&
      "$reviewer_identity_hash_verified_rows" -eq "$benchmark_families" &&
      "$reviewer_conflict_rows" -eq "$benchmark_families" &&
      "$reviewer_conflict_hash_verified_rows" -eq "$benchmark_families" &&
      "$critical_hash_match_rows" -eq "$benchmark_families" &&
      "$metric_match_rows" -eq "$benchmark_families" &&
      "$review_approved_rows" -eq "$benchmark_families" &&
      "$real_source_declared_rows" -eq "$benchmark_families" &&
      "$non_fixture_declared_rows" -eq "$benchmark_families" &&
      "$source_import_verified" == "1" &&
      "$local_final_review_artifact_rows" -eq 0 &&
      "$local_reviewer_identity_rows" -eq 0 &&
      "$local_reviewer_conflict_rows" -eq 0 &&
      "$local_upstream_artifact_rows" -eq 0 &&
      "$review_routing" == "0.000000" &&
      "$review_jump" == "0.000000" ]]; then
  final_review_verified=1
fi

real_external_benchmark_verified=0
action="external-benchmark-attestor-identity-missing"
if [[ "$attestor_identity_verified" == "1" ]]; then
  if [[ "$review_rows" -ne "$benchmark_families" ||
        "$matched_attestation_rows" -ne "$benchmark_families" ||
        "$review_ready_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-final-review-missing"
  elif [[ "$review_artifact_rows" -ne "$benchmark_families" ||
          "$review_hash_verified_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-final-review-hash-mismatch"
  elif [[ "$reviewer_identity_rows" -ne "$benchmark_families" ||
          "$reviewer_identity_hash_verified_rows" -ne "$benchmark_families" ||
          "$reviewer_conflict_rows" -ne "$benchmark_families" ||
          "$reviewer_conflict_hash_verified_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-final-reviewer-provenance-missing"
  elif [[ "$critical_hash_match_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-final-review-chain-incomplete"
  elif [[ "$metric_match_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-final-review-metric-mismatch"
  elif [[ "$review_approved_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-final-review-approval-missing"
  elif [[ "$real_source_declared_rows" -ne "$benchmark_families" ||
          "$non_fixture_declared_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-real-source-review-missing"
  elif [[ "$local_final_review_artifact_rows" -gt 0 ||
          "$local_reviewer_identity_rows" -gt 0 ||
          "$local_reviewer_conflict_rows" -gt 0 ]]; then
    action="external-benchmark-local-final-review-artifact"
  elif [[ "$local_upstream_artifact_rows" -gt 0 ]]; then
    action="external-benchmark-local-upstream-artifact"
  elif [[ "$source_import_verified" != "1" ]]; then
    action="$source_import_action"
  elif [[ "$final_review_verified" == "1" ]]; then
    real_external_benchmark_verified=1
    action="external-benchmark-verified"
  fi
fi

total_routing="$(awk -v a="$summary_routing" -v b="$review_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$summary_jump" -v b="$review_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,evidence_source,authenticity_source,execution_source,attestation_source,attestor_identity_source,final_review_source,evaluator_execution_verified,independent_attestation_verified,attestor_identity_verified,identity_action,review_rows,matched_attestation_rows,review_artifact_rows,review_hash_verified_rows,local_final_review_artifact_rows,nonlocal_final_review_artifact_rows,reviewer_identity_rows,reviewer_identity_hash_verified_rows,local_reviewer_identity_rows,nonlocal_reviewer_identity_rows,reviewer_conflict_rows,reviewer_conflict_hash_verified_rows,local_reviewer_conflict_rows,nonlocal_reviewer_conflict_rows,local_upstream_evidence_artifact_rows,local_upstream_execution_artifact_rows,local_upstream_attestation_artifact_rows,local_upstream_identity_artifact_rows,local_upstream_artifact_rows,critical_hash_match_rows,metric_match_rows,review_ready_rows,review_approved_rows,real_source_declared_rows,non_fixture_declared_rows,source_import_contract_ready,source_import_verifier_ready,source_import_live_verifier_ready,source_import_independent_live_review_ready,source_import_authoritative_review_ready,source_import_public_registry_ready,source_import_live_registry_query_ready,source_import_live_registry_fetcher_ready,source_import_live_registry_fetch_ready,source_import_live_registry_network_proof_runner_ready,source_import_live_registry_network_proof_ready,source_import_real_verification_review_ready,source_import_real_verification_ready,source_import_official_authority_review_ready,source_import_official_authority_ready,source_import_verified,final_review_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08l,%d,%s,%s,%s,%s,%s,%s,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$evidence_source" \
    "$authenticity_source" \
    "$execution_source" \
    "$attestation_source" \
    "$attestor_identity_source" \
    "$REVIEW_SOURCE" \
    "$evaluator_execution_verified" \
    "$independent_attestation_verified" \
    "$attestor_identity_verified" \
    "$identity_action" \
    "$review_rows" \
    "$matched_attestation_rows" \
    "$review_artifact_rows" \
    "$review_hash_verified_rows" \
    "$local_final_review_artifact_rows" \
    "$nonlocal_final_review_artifact_rows" \
    "$reviewer_identity_rows" \
    "$reviewer_identity_hash_verified_rows" \
    "$local_reviewer_identity_rows" \
    "$nonlocal_reviewer_identity_rows" \
    "$reviewer_conflict_rows" \
    "$reviewer_conflict_hash_verified_rows" \
    "$local_reviewer_conflict_rows" \
    "$nonlocal_reviewer_conflict_rows" \
    "$local_upstream_evidence_artifact_rows" \
    "$local_upstream_execution_artifact_rows" \
    "$local_upstream_attestation_artifact_rows" \
    "$local_upstream_identity_artifact_rows" \
    "$local_upstream_artifact_rows" \
    "$critical_hash_match_rows" \
    "$metric_match_rows" \
    "$review_ready_rows" \
    "$review_approved_rows" \
    "$real_source_declared_rows" \
    "$non_fixture_declared_rows" \
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
    "$source_import_official_authority_review_ready" \
    "$source_import_official_authority_ready" \
    "$source_import_verified" \
    "$final_review_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "prior-attestor-identity,%s,verified=%d\n" \
    "$([[ "$attestor_identity_verified" == "1" ]] && echo pass || echo blocked)" \
    "$attestor_identity_verified"
  printf "review-rows,%s,review_rows=%d matched_rows=%d\n" \
    "$([[ "$review_rows" -eq "$benchmark_families" && "$matched_attestation_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$review_rows" \
    "$matched_attestation_rows"
  printf "review-artifact-hash,%s,artifact_rows=%d hash_rows=%d\n" \
    "$([[ "$review_artifact_rows" -eq "$benchmark_families" && "$review_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$review_artifact_rows" \
    "$review_hash_verified_rows"
  printf "reviewer-identity,%s,identity_rows=%d hash_rows=%d\n" \
    "$([[ "$reviewer_identity_rows" -eq "$benchmark_families" && "$reviewer_identity_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$reviewer_identity_rows" \
    "$reviewer_identity_hash_verified_rows"
  printf "reviewer-conflict-disclosure,%s,conflict_rows=%d hash_rows=%d\n" \
    "$([[ "$reviewer_conflict_rows" -eq "$benchmark_families" && "$reviewer_conflict_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$reviewer_conflict_rows" \
    "$reviewer_conflict_hash_verified_rows"
  printf "critical-hash-match,%s,match_rows=%d\n" \
    "$([[ "$critical_hash_match_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$critical_hash_match_rows"
  printf "metric-match,%s,metric_rows=%d\n" \
    "$([[ "$metric_match_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$metric_match_rows"
  printf "real-source-declaration,%s,real_rows=%d non_fixture_rows=%d\n" \
    "$([[ "$real_source_declared_rows" -eq "$benchmark_families" && "$non_fixture_declared_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$real_source_declared_rows" \
    "$non_fixture_declared_rows"
  printf "review-approval,%s,ready_rows=%d approved_rows=%d\n" \
    "$([[ "$review_ready_rows" -eq "$benchmark_families" && "$review_approved_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$review_ready_rows" \
    "$review_approved_rows"
  printf "local-final-review-artifact,%s,review_local=%d identity_local=%d conflict_local=%d\n" \
    "$([[ "$local_final_review_artifact_rows" -eq 0 && "$local_reviewer_identity_rows" -eq 0 && "$local_reviewer_conflict_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$local_final_review_artifact_rows" \
    "$local_reviewer_identity_rows" \
    "$local_reviewer_conflict_rows"
  printf "nonlocal-final-review-artifact,%s,review_nonlocal=%d identity_nonlocal=%d conflict_nonlocal=%d\n" \
    "$([[ "$nonlocal_final_review_artifact_rows" -eq "$benchmark_families" && "$nonlocal_reviewer_identity_rows" -eq "$benchmark_families" && "$nonlocal_reviewer_conflict_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$nonlocal_final_review_artifact_rows" \
    "$nonlocal_reviewer_identity_rows" \
    "$nonlocal_reviewer_conflict_rows"
  printf "local-upstream-artifact,%s,evidence_local=%d execution_local=%d attestation_local=%d identity_local=%d\n" \
    "$([[ "$local_upstream_artifact_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$local_upstream_evidence_artifact_rows" \
    "$local_upstream_execution_artifact_rows" \
    "$local_upstream_attestation_artifact_rows" \
    "$local_upstream_identity_artifact_rows"
  printf "source-import,%s,verified=%d contract_ready=%d verifier_ready=%d live_verifier_ready=%d live_review_ready=%d auth_review_ready=%d public_registry_ready=%d live_registry_query_ready=%d live_registry_fetcher_ready=%d live_registry_fetch_ready=%d live_registry_network_proof_runner_ready=%d live_registry_network_proof_ready=%d real_verification_review_ready=%d real_verification_ready=%d official_authority_review_ready=%d official_authority_ready=%d source_import_action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
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
    "$source_import_official_authority_review_ready" \
    "$source_import_official_authority_ready" \
    "$source_import_action"
  printf "real-external-benchmark,%s,action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
