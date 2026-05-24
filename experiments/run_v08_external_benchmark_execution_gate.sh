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

PREFIX="v08_external_benchmark_execution_gate"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
AUTHENTICITY_PREFIX="v08_external_benchmark_authenticity_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_execution_gate_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  AUTHENTICITY_PREFIX="v08_external_benchmark_authenticity_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_authenticity_gate.sh" "${RUN_ARGS[@]}" >/dev/null

EVIDENCE_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV"
fi

EXECUTION_CSV="$RESULTS_DIR/${PREFIX}_execution.csv"
EXECUTION_SOURCE="pending-fixture"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EXECUTION_CSV:-}" ]]; then
  EXECUTION_CSV="$V08_EXTERNAL_BENCHMARK_EXECUTION_CSV"
  EXECUTION_SOURCE="provided-csv"
  if [[ ! -s "$EXECUTION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_EXECUTION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  awk -F, -v out="$EXECUTION_CSV" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!("benchmark_family" in idx)) {
        print "missing benchmark_family in v08 execution pending fixture" > "/dev/stderr"
        exit 2
      }
      print "benchmark_family,execution_id,evaluator_output_uri,evaluator_output_hash,run_log_uri,run_log_hash,metric_value,sample_count,execution_ready,evaluator_output_ready,run_log_ready,metric_output_ready,routing_trigger_rate,active_jump_rate" > out
      next
    }
    {
      printf "%s,pending,pending,pending,pending,pending,pending,0,0,0,0,0,0,0\n", $idx["benchmark_family"] >> out
    }
  ' "$EVIDENCE_CSV"
fi

AUTHENTICITY_SUMMARY_CSV="$RESULTS_DIR/${AUTHENTICITY_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

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

  if [[ "$expected" != sha256:* || ! -f "$path" ]]; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  if [[ ${#expected_hex} -ne 64 || "$expected_hex" =~ [^0-9a-fA-F] ]]; then
    return 1
  fi
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

AUTH_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families evidence_source authenticity_source benchmark_authenticity_verified real_external_benchmark_verified routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 execution authenticity summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%d,%d,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["evidence_source"],
        $idx["authenticity_source"],
        $idx["benchmark_authenticity_verified"] + 0,
        $idx["real_external_benchmark_verified"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08 execution authenticity summary row", 3)
    }
  ' "$AUTHENTICITY_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families evidence_source authenticity_source benchmark_authenticity_verified prior_real_external_benchmark_verified summary_routing summary_jump <<<"$AUTH_VALUES"

execution_rows=0
matched_family_rows=0
output_artifact_rows=0
run_log_artifact_rows=0
output_hash_verified_rows=0
run_log_hash_verified_rows=0
execution_ready_rows=0
metric_output_rows=0
execution_routing="0.000000"
execution_jump="0.000000"

while IFS=$'\t' read -r benchmark_family execution_id evaluator_output_uri evaluator_output_hash run_log_uri run_log_hash metric_value sample_count execution_ready evaluator_output_ready run_log_ready metric_output_ready routing_trigger_rate active_jump_rate; do
  ((execution_rows += 1))
  case "$benchmark_family" in
    RULER|LongBench|codebase-retrieval|real-document-qa)
      ((matched_family_rows += 1))
      ;;
  esac

  if output_path="$(uri_to_local_path "$evaluator_output_uri")"; then
    ((output_artifact_rows += 1))
    if hash_matches "$output_path" "$evaluator_output_hash"; then
      ((output_hash_verified_rows += 1))
    fi
  fi

  if log_path="$(uri_to_local_path "$run_log_uri")"; then
    ((run_log_artifact_rows += 1))
    if hash_matches "$log_path" "$run_log_hash"; then
      ((run_log_hash_verified_rows += 1))
    fi
  fi

  if [[ "$execution_ready" == "1" &&
        "$evaluator_output_ready" == "1" &&
        "$run_log_ready" == "1" &&
        "$execution_id" != "" &&
        "$execution_id" != "pending" ]]; then
    ((execution_ready_rows += 1))
  fi

  if [[ "$metric_output_ready" == "1" &&
        "$metric_value" != "" &&
        "$metric_value" != "pending" &&
        "$sample_count" =~ ^[0-9]+$ &&
        "$sample_count" -gt 0 ]]; then
    ((metric_output_rows += 1))
  fi

  execution_routing="$(awk -v a="$execution_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  execution_jump="$(awk -v a="$execution_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family execution_id evaluator_output_uri evaluator_output_hash run_log_uri run_log_hash metric_value sample_count execution_ready evaluator_output_ready run_log_ready metric_output_ready routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 execution column: " required[i], 4)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["benchmark_family"],
        $idx["execution_id"],
        $idx["evaluator_output_uri"],
        $idx["evaluator_output_hash"],
        $idx["run_log_uri"],
        $idx["run_log_hash"],
        $idx["metric_value"],
        $idx["sample_count"],
        $idx["execution_ready"] + 0,
        $idx["evaluator_output_ready"] + 0,
        $idx["run_log_ready"] + 0,
        $idx["metric_output_ready"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$EXECUTION_CSV"
)

evaluator_execution_verified=0
if [[ "$benchmark_authenticity_verified" == "1" &&
      "$execution_rows" -eq "$benchmark_families" &&
      "$matched_family_rows" -eq "$benchmark_families" &&
      "$output_artifact_rows" -eq "$benchmark_families" &&
      "$run_log_artifact_rows" -eq "$benchmark_families" &&
      "$output_hash_verified_rows" -eq "$benchmark_families" &&
      "$run_log_hash_verified_rows" -eq "$benchmark_families" &&
      "$execution_ready_rows" -eq "$benchmark_families" &&
      "$metric_output_rows" -eq "$benchmark_families" &&
      "$execution_routing" == "0.000000" &&
      "$execution_jump" == "0.000000" ]]; then
  evaluator_execution_verified=1
fi

real_external_benchmark_verified=0
action="benchmark-authenticity-missing"
if [[ "$benchmark_authenticity_verified" == "1" && "$evaluator_execution_verified" == "0" ]]; then
  action="external-benchmark-execution-evidence-missing"
elif [[ "$evaluator_execution_verified" == "1" ]]; then
  action="external-benchmark-attestation-missing"
fi

total_routing="$(awk -v a="$summary_routing" -v b="$execution_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$summary_jump" -v b="$execution_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,evidence_source,authenticity_source,execution_source,benchmark_authenticity_verified,execution_rows,matched_family_rows,output_artifact_rows,run_log_artifact_rows,output_hash_verified_rows,run_log_hash_verified_rows,execution_ready_rows,metric_output_rows,evaluator_execution_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08i,%d,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$evidence_source" \
    "$authenticity_source" \
    "$EXECUTION_SOURCE" \
    "$benchmark_authenticity_verified" \
    "$execution_rows" \
    "$matched_family_rows" \
    "$output_artifact_rows" \
    "$run_log_artifact_rows" \
    "$output_hash_verified_rows" \
    "$run_log_hash_verified_rows" \
    "$execution_ready_rows" \
    "$metric_output_rows" \
    "$evaluator_execution_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "benchmark-authenticity,%s,verified=%d\n" \
    "$([[ "$benchmark_authenticity_verified" == "1" ]] && echo pass || echo blocked)" \
    "$benchmark_authenticity_verified"
  printf "execution-artifacts,%s,output_rows=%d log_rows=%d\n" \
    "$([[ "$output_artifact_rows" -eq "$benchmark_families" && "$run_log_artifact_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$output_artifact_rows" \
    "$run_log_artifact_rows"
  printf "execution-hashes,%s,output_hash_rows=%d log_hash_rows=%d\n" \
    "$([[ "$output_hash_verified_rows" -eq "$benchmark_families" && "$run_log_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$output_hash_verified_rows" \
    "$run_log_hash_verified_rows"
  printf "metric-output,%s,metric_rows=%d\n" \
    "$([[ "$metric_output_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$metric_output_rows"
  printf "evaluator-execution,%s,verified=%d\n" \
    "$([[ "$evaluator_execution_verified" == "1" ]] && echo pass || echo blocked)" \
    "$evaluator_execution_verified"
  printf "real-external-benchmark,%s,action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
