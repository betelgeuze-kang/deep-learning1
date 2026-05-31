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

PREFIX="v08_external_benchmark_artifact_verifier"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
REAL_EVIDENCE_PREFIX="v08_external_benchmark_real_evidence_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_artifact_verifier_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  REAL_EVIDENCE_PREFIX="v08_external_benchmark_real_evidence_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_real_evidence_gate.sh" "${RUN_ARGS[@]}" >/dev/null

EVIDENCE_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV"
fi
REAL_EVIDENCE_SUMMARY_CSV="$RESULTS_DIR/${REAL_EVIDENCE_PREFIX}_summary.csv"

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

REAL_SUMMARY_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families evidence_source real_evidence_format_ready routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 artifact verifier summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%d,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["evidence_source"],
        $idx["real_evidence_format_ready"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08 artifact verifier real-evidence summary row", 3)
    }
  ' "$REAL_EVIDENCE_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families evidence_source real_evidence_format_ready summary_routing summary_jump <<<"$REAL_SUMMARY_VALUES"

evidence_rows=0
local_dataset_uri_rows=0
local_result_uri_rows=0
nonlocal_dataset_uri_rows=0
nonlocal_result_uri_rows=0
source_hash_verified_rows=0
provenance_hash_verified_rows=0
evidence_routing="0.000000"
evidence_jump="0.000000"

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

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

hash_matches() {
  local path="$1"
  local expected="$2"
  local expected_hex
  local actual_hex

  if ! is_sha256 "$expected" || [[ ! -f "$path" ]]; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

while IFS=$'\t' read -r benchmark_family dataset_uri source_hash result_uri provenance_hash routing_trigger_rate active_jump_rate source_hash_attested provenance_hash_attested; do
  ((evidence_rows += 1))

  if dataset_path="$(uri_to_local_path "$dataset_uri")"; then
    ((local_dataset_uri_rows += 1))
    if hash_matches "$dataset_path" "$source_hash"; then
      ((source_hash_verified_rows += 1))
    fi
  elif is_https_uri "$dataset_uri" &&
       [[ "$source_hash_attested" == "1" ]] &&
       is_sha256 "$source_hash"; then
    ((nonlocal_dataset_uri_rows += 1))
    ((source_hash_verified_rows += 1))
  fi

  if result_path="$(uri_to_local_path "$result_uri")"; then
    ((local_result_uri_rows += 1))
    if hash_matches "$result_path" "$provenance_hash"; then
      ((provenance_hash_verified_rows += 1))
    fi
  elif is_https_uri "$result_uri" &&
       [[ "$provenance_hash_attested" == "1" ]] &&
       is_sha256 "$provenance_hash"; then
    ((nonlocal_result_uri_rows += 1))
    ((provenance_hash_verified_rows += 1))
  fi

  evidence_routing="$(awk -v a="$evidence_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  evidence_jump="$(awk -v a="$evidence_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family dataset_uri source_hash result_uri provenance_hash routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 artifact verifier evidence column: " required[i], 4)
      }
      source_hash_attested_idx = ("source_hash_attested" in idx) ? idx["source_hash_attested"] : 0
      provenance_hash_attested_idx = ("provenance_hash_attested" in idx) ? idx["provenance_hash_attested"] : 0
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%.6f\t%.6f\t%d\t%d\n",
        $idx["benchmark_family"],
        $idx["dataset_uri"],
        $idx["source_hash"],
        $idx["result_uri"],
        $idx["provenance_hash"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0,
        source_hash_attested_idx ? $source_hash_attested_idx + 0 : 0,
        provenance_hash_attested_idx ? $provenance_hash_attested_idx + 0 : 0
    }
  ' "$EVIDENCE_CSV"
)

dataset_artifact_rows=$((local_dataset_uri_rows + nonlocal_dataset_uri_rows))
result_artifact_rows=$((local_result_uri_rows + nonlocal_result_uri_rows))

artifact_verifier_ready=0
if [[ "$real_evidence_format_ready" == "1" &&
      "$evidence_rows" -eq "$benchmark_families" &&
      "$dataset_artifact_rows" -eq "$benchmark_families" &&
      "$result_artifact_rows" -eq "$benchmark_families" &&
      "$source_hash_verified_rows" -eq "$benchmark_families" &&
      "$provenance_hash_verified_rows" -eq "$benchmark_families" &&
      "$evidence_routing" == "0.000000" &&
      "$evidence_jump" == "0.000000" ]]; then
  artifact_verifier_ready=1
fi

real_external_benchmark_verified=0
action="real-evidence-format-missing"
if [[ "$real_evidence_format_ready" == "1" && "$artifact_verifier_ready" == "0" ]]; then
  if [[ "$dataset_artifact_rows" -ne "$benchmark_families" ||
        "$result_artifact_rows" -ne "$benchmark_families" ]]; then
    action="external-fetcher-missing"
  else
    action="artifact-hash-mismatch"
  fi
elif [[ "$artifact_verifier_ready" == "1" ]]; then
  action="benchmark-authenticity-verifier-missing"
fi

total_routing="$(awk -v a="$summary_routing" -v b="$evidence_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$summary_jump" -v b="$evidence_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,evidence_source,real_evidence_format_ready,evidence_rows,dataset_artifact_rows,local_dataset_uri_rows,nonlocal_dataset_uri_rows,result_artifact_rows,local_result_uri_rows,nonlocal_result_uri_rows,source_hash_verified_rows,provenance_hash_verified_rows,artifact_verifier_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08g,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$evidence_source" \
    "$real_evidence_format_ready" \
    "$evidence_rows" \
    "$dataset_artifact_rows" \
    "$local_dataset_uri_rows" \
    "$nonlocal_dataset_uri_rows" \
    "$result_artifact_rows" \
    "$local_result_uri_rows" \
    "$nonlocal_result_uri_rows" \
    "$source_hash_verified_rows" \
    "$provenance_hash_verified_rows" \
    "$artifact_verifier_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "real-evidence-format,%s,format_ready=%d\n" \
    "$([[ "$real_evidence_format_ready" == "1" ]] && echo pass || echo blocked)" \
    "$real_evidence_format_ready"
  printf "artifact-presence,%s,dataset_rows=%d result_rows=%d\n" \
    "$([[ "$dataset_artifact_rows" -eq "$benchmark_families" && "$result_artifact_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$dataset_artifact_rows" \
    "$result_artifact_rows"
  printf "local-artifacts,%s,dataset_local=%d result_local=%d\n" \
    "$([[ "$local_dataset_uri_rows" -eq "$benchmark_families" && "$local_result_uri_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$local_dataset_uri_rows" \
    "$local_result_uri_rows"
  printf "nonlocal-artifacts,%s,dataset_nonlocal=%d result_nonlocal=%d\n" \
    "$([[ "$nonlocal_dataset_uri_rows" -eq "$benchmark_families" && "$nonlocal_result_uri_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$nonlocal_dataset_uri_rows" \
    "$nonlocal_result_uri_rows"
  printf "source-hash,%s,verified_rows=%d\n" \
    "$([[ "$source_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$source_hash_verified_rows"
  printf "provenance-hash,%s,verified_rows=%d\n" \
    "$([[ "$provenance_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$provenance_hash_verified_rows"
  printf "artifact-verifier,%s,ready=%d\n" \
    "$([[ "$artifact_verifier_ready" == "1" ]] && echo pass || echo blocked)" \
    "$artifact_verifier_ready"
  printf "real-external-benchmark,%s,action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
