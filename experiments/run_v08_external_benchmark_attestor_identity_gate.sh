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

PREFIX="v08_external_benchmark_attestor_identity_gate"
ATTESTATION_PREFIX="v08_external_benchmark_attestation_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_attestor_identity_gate_smoke"
  ATTESTATION_PREFIX="v08_external_benchmark_attestation_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_attestation_gate.sh" "${RUN_ARGS[@]}" >/dev/null

ATTESTATION_CSV="$RESULTS_DIR/${ATTESTATION_PREFIX}_attestation.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV:-}" ]]; then
  ATTESTATION_CSV="$V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV"
fi

IDENTITY_CSV="$RESULTS_DIR/${PREFIX}_identity.csv"
IDENTITY_SOURCE="pending-fixture"
if [[ -n "${V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV:-}" ]]; then
  IDENTITY_CSV="$V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV"
  IDENTITY_SOURCE="provided-csv"
  if [[ ! -s "$IDENTITY_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  awk -F, -v out="$IDENTITY_CSV" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family attestation_id attestor_name attestor_org", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          print "missing v08 attestor identity pending fixture attestation column: " required[i] > "/dev/stderr"
          exit 2
        }
      }
      print "benchmark_family,attestation_id,attestor_name,attestor_org,attestor_identity_uri,attestor_identity_hash,attestor_registry_id,attestor_registry_uri,attestor_registry_hash,attestor_contact_domain,conflict_disclosure_uri,conflict_disclosure_hash,independence_basis,relationship_to_project,funding_conflict_declared,attestor_identity_ready,attestor_registry_ready,conflict_disclosure_ready,independence_provenance_ready,routing_trigger_rate,active_jump_rate" > out
      next
    }
    {
      printf "%s,%s,%s,%s,pending,pending,pending,pending,pending,pending,pending,pending,pending,pending,1,0,0,0,0,0,0\n",
        $idx["benchmark_family"],
        $idx["attestation_id"],
        $idx["attestor_name"],
        $idx["attestor_org"] >> out
    }
  ' "$ATTESTATION_CSV"
fi

ATTESTATION_SUMMARY_CSV="$RESULTS_DIR/${ATTESTATION_PREFIX}_summary.csv"
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

ATTESTATION_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families evidence_source authenticity_source execution_source attestation_source evaluator_execution_verified independent_attestation_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 attestor identity attestation summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%s,%s,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["evidence_source"],
        $idx["authenticity_source"],
        $idx["execution_source"],
        $idx["attestation_source"],
        $idx["evaluator_execution_verified"] + 0,
        $idx["independent_attestation_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08 attestor identity attestation summary row", 3)
    }
  ' "$ATTESTATION_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families evidence_source authenticity_source execution_source attestation_source evaluator_execution_verified independent_attestation_verified attestation_action summary_routing summary_jump <<<"$ATTESTATION_VALUES"

declare -A attestation_id_by_family
declare -A attestor_name_by_family
declare -A attestor_org_by_family
attestation_rows=0

while IFS=$'\t' read -r benchmark_family attestation_id attestor_name attestor_org; do
  ((attestation_rows += 1))
  attestation_id_by_family["$benchmark_family"]="$attestation_id"
  attestor_name_by_family["$benchmark_family"]="$attestor_name"
  attestor_org_by_family["$benchmark_family"]="$attestor_org"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family attestation_id attestor_name attestor_org", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 attestor identity attestation column: " required[i], 4)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["attestation_id"],
        $idx["attestor_name"],
        $idx["attestor_org"]
    }
  ' "$ATTESTATION_CSV"
)

identity_rows=0
matched_attestation_rows=0
identity_ready_rows=0
identity_artifact_rows=0
identity_hash_verified_rows=0
registry_artifact_rows=0
registry_hash_verified_rows=0
conflict_disclosure_rows=0
conflict_disclosure_hash_verified_rows=0
independence_basis_rows=0
no_declared_conflict_rows=0
identity_routing="0.000000"
identity_jump="0.000000"
declare -A identity_seen

while IFS=$'\t' read -r benchmark_family attestation_id attestor_name attestor_org attestor_identity_uri attestor_identity_hash attestor_registry_id attestor_registry_uri attestor_registry_hash attestor_contact_domain conflict_disclosure_uri conflict_disclosure_hash independence_basis relationship_to_project funding_conflict_declared attestor_identity_ready attestor_registry_ready conflict_disclosure_ready independence_provenance_ready routing_trigger_rate active_jump_rate; do
  ((identity_rows += 1))
  if [[ -n "${identity_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08 attestor identity family: $benchmark_family" >&2
    exit 5
  fi
  identity_seen["$benchmark_family"]=1

  if [[ -n "${attestation_id_by_family[$benchmark_family]:-}" &&
        "${attestation_id_by_family[$benchmark_family]}" == "$attestation_id" &&
        "${attestor_name_by_family[$benchmark_family]}" == "$attestor_name" &&
        "${attestor_org_by_family[$benchmark_family]}" == "$attestor_org" ]] &&
      is_present "$attestation_id"; then
    ((matched_attestation_rows += 1))
  fi

  if [[ "$attestor_identity_ready" == "1" &&
        "$attestor_registry_ready" == "1" &&
        "$conflict_disclosure_ready" == "1" &&
        "$independence_provenance_ready" == "1" ]] &&
      is_present "$attestor_identity_uri" &&
      is_present "$attestor_registry_id" &&
      is_present "$attestor_registry_uri" &&
      is_present "$attestor_contact_domain" &&
      is_present "$conflict_disclosure_uri" &&
      is_present "$independence_basis"; then
    ((identity_ready_rows += 1))
  fi

  if identity_path="$(uri_to_local_path "$attestor_identity_uri")"; then
    ((identity_artifact_rows += 1))
    if hash_matches "$identity_path" "$attestor_identity_hash"; then
      ((identity_hash_verified_rows += 1))
    fi
  fi

  if registry_path="$(uri_to_local_path "$attestor_registry_uri")"; then
    ((registry_artifact_rows += 1))
    if hash_matches "$registry_path" "$attestor_registry_hash"; then
      ((registry_hash_verified_rows += 1))
    fi
  fi

  if disclosure_path="$(uri_to_local_path "$conflict_disclosure_uri")"; then
    ((conflict_disclosure_rows += 1))
    if hash_matches "$disclosure_path" "$conflict_disclosure_hash"; then
      ((conflict_disclosure_hash_verified_rows += 1))
    fi
  fi

  if is_present "$independence_basis" &&
      [[ "$relationship_to_project" == "none" ]]; then
    ((independence_basis_rows += 1))
  fi

  if [[ "$relationship_to_project" == "none" &&
        "$funding_conflict_declared" == "0" ]]; then
    ((no_declared_conflict_rows += 1))
  fi

  identity_routing="$(awk -v a="$identity_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  identity_jump="$(awk -v a="$identity_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family attestation_id attestor_name attestor_org attestor_identity_uri attestor_identity_hash attestor_registry_id attestor_registry_uri attestor_registry_hash attestor_contact_domain conflict_disclosure_uri conflict_disclosure_hash independence_basis relationship_to_project funding_conflict_declared attestor_identity_ready attestor_registry_ready conflict_disclosure_ready independence_provenance_ready routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 attestor identity column: " required[i], 6)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["benchmark_family"],
        $idx["attestation_id"],
        $idx["attestor_name"],
        $idx["attestor_org"],
        $idx["attestor_identity_uri"],
        $idx["attestor_identity_hash"],
        $idx["attestor_registry_id"],
        $idx["attestor_registry_uri"],
        $idx["attestor_registry_hash"],
        $idx["attestor_contact_domain"],
        $idx["conflict_disclosure_uri"],
        $idx["conflict_disclosure_hash"],
        $idx["independence_basis"],
        $idx["relationship_to_project"],
        $idx["funding_conflict_declared"],
        $idx["attestor_identity_ready"] + 0,
        $idx["attestor_registry_ready"] + 0,
        $idx["conflict_disclosure_ready"] + 0,
        $idx["independence_provenance_ready"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$IDENTITY_CSV"
)

attestor_identity_verified=0
if [[ "$independent_attestation_verified" == "1" &&
      "$identity_rows" -eq "$benchmark_families" &&
      "$matched_attestation_rows" -eq "$benchmark_families" &&
      "$identity_ready_rows" -eq "$benchmark_families" &&
      "$identity_artifact_rows" -eq "$benchmark_families" &&
      "$identity_hash_verified_rows" -eq "$benchmark_families" &&
      "$registry_artifact_rows" -eq "$benchmark_families" &&
      "$registry_hash_verified_rows" -eq "$benchmark_families" &&
      "$conflict_disclosure_rows" -eq "$benchmark_families" &&
      "$conflict_disclosure_hash_verified_rows" -eq "$benchmark_families" &&
      "$independence_basis_rows" -eq "$benchmark_families" &&
      "$no_declared_conflict_rows" -eq "$benchmark_families" &&
      "$identity_routing" == "0.000000" &&
      "$identity_jump" == "0.000000" ]]; then
  attestor_identity_verified=1
fi

real_external_benchmark_verified=0
action="external-benchmark-independent-attestation-missing"
if [[ "$independent_attestation_verified" == "1" ]]; then
  if [[ "$identity_rows" -ne "$benchmark_families" ||
        "$matched_attestation_rows" -ne "$benchmark_families" ||
        "$identity_ready_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestor-identity-missing"
  elif [[ "$identity_artifact_rows" -ne "$benchmark_families" ||
          "$identity_hash_verified_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestor-identity-hash-mismatch"
  elif [[ "$registry_artifact_rows" -ne "$benchmark_families" ||
          "$registry_hash_verified_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestor-registry-missing"
  elif [[ "$conflict_disclosure_rows" -ne "$benchmark_families" ||
          "$conflict_disclosure_hash_verified_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestor-conflict-disclosure-missing"
  elif [[ "$independence_basis_rows" -ne "$benchmark_families" ||
          "$no_declared_conflict_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestor-independence-provenance-missing"
  elif [[ "$attestor_identity_verified" == "1" ]]; then
    action="external-benchmark-final-review-missing"
  fi
fi

total_routing="$(awk -v a="$summary_routing" -v b="$identity_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$summary_jump" -v b="$identity_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,evidence_source,authenticity_source,execution_source,attestation_source,attestor_identity_source,evaluator_execution_verified,independent_attestation_verified,attestation_action,identity_rows,matched_attestation_rows,identity_artifact_rows,identity_hash_verified_rows,registry_artifact_rows,registry_hash_verified_rows,conflict_disclosure_rows,conflict_disclosure_hash_verified_rows,independence_basis_rows,no_declared_conflict_rows,attestor_identity_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08k,%d,%s,%s,%s,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$evidence_source" \
    "$authenticity_source" \
    "$execution_source" \
    "$attestation_source" \
    "$IDENTITY_SOURCE" \
    "$evaluator_execution_verified" \
    "$independent_attestation_verified" \
    "$attestation_action" \
    "$identity_rows" \
    "$matched_attestation_rows" \
    "$identity_artifact_rows" \
    "$identity_hash_verified_rows" \
    "$registry_artifact_rows" \
    "$registry_hash_verified_rows" \
    "$conflict_disclosure_rows" \
    "$conflict_disclosure_hash_verified_rows" \
    "$independence_basis_rows" \
    "$no_declared_conflict_rows" \
    "$attestor_identity_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "prior-independent-attestation,%s,verified=%d\n" \
    "$([[ "$independent_attestation_verified" == "1" ]] && echo pass || echo blocked)" \
    "$independent_attestation_verified"
  printf "identity-rows,%s,identity_rows=%d matched_rows=%d\n" \
    "$([[ "$identity_rows" -eq "$benchmark_families" && "$matched_attestation_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$identity_rows" \
    "$matched_attestation_rows"
  printf "identity-artifact-hash,%s,artifact_rows=%d hash_rows=%d\n" \
    "$([[ "$identity_artifact_rows" -eq "$benchmark_families" && "$identity_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$identity_artifact_rows" \
    "$identity_hash_verified_rows"
  printf "registry-artifact-hash,%s,artifact_rows=%d hash_rows=%d\n" \
    "$([[ "$registry_artifact_rows" -eq "$benchmark_families" && "$registry_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$registry_artifact_rows" \
    "$registry_hash_verified_rows"
  printf "conflict-disclosure,%s,rows=%d hash_rows=%d\n" \
    "$([[ "$conflict_disclosure_rows" -eq "$benchmark_families" && "$conflict_disclosure_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$conflict_disclosure_rows" \
    "$conflict_disclosure_hash_verified_rows"
  printf "independence-provenance,%s,basis_rows=%d no_conflict_rows=%d\n" \
    "$([[ "$independence_basis_rows" -eq "$benchmark_families" && "$no_declared_conflict_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$independence_basis_rows" \
    "$no_declared_conflict_rows"
  printf "attestor-identity,%s,verified=%d\n" \
    "$([[ "$attestor_identity_verified" == "1" ]] && echo pass || echo blocked)" \
    "$attestor_identity_verified"
  printf "real-external-benchmark,%s,action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
