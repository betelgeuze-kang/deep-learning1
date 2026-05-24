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

PREFIX="v08_external_benchmark_attestation_gate"
EXECUTION_PREFIX="v08_external_benchmark_execution_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_attestation_gate_smoke"
  EXECUTION_PREFIX="v08_external_benchmark_execution_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_execution_gate.sh" "${RUN_ARGS[@]}" >/dev/null

EXECUTION_CSV="$RESULTS_DIR/${EXECUTION_PREFIX}_execution.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EXECUTION_CSV:-}" ]]; then
  EXECUTION_CSV="$V08_EXTERNAL_BENCHMARK_EXECUTION_CSV"
fi

ATTESTATION_CSV="$RESULTS_DIR/${PREFIX}_attestation.csv"
ATTESTATION_SOURCE="pending-fixture"
if [[ -n "${V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV:-}" ]]; then
  ATTESTATION_CSV="$V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV"
  ATTESTATION_SOURCE="provided-csv"
  if [[ ! -s "$ATTESTATION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  awk -F, -v out="$ATTESTATION_CSV" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family execution_id evaluator_output_hash run_log_hash metric_value", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          print "missing v08 attestation pending fixture execution column: " required[i] > "/dev/stderr"
          exit 2
        }
      }
      print "benchmark_family,execution_id,attestation_id,attestation_uri,attestation_hash,attestor_name,attestor_org,attestor_role,attestor_independent,attested_evaluator_output_hash,attested_run_log_hash,attested_metric_value,attestation_ready,attestor_ready,execution_hash_attested,metric_attested,routing_trigger_rate,active_jump_rate" > out
      next
    }
    {
      printf "%s,%s,pending,pending,pending,pending,pending,pending,0,%s,%s,%s,0,0,0,0,0,0\n",
        $idx["benchmark_family"],
        $idx["execution_id"],
        $idx["evaluator_output_hash"],
        $idx["run_log_hash"],
        $idx["metric_value"] >> out
    }
  ' "$EXECUTION_CSV"
fi

EXECUTION_SUMMARY_CSV="$RESULTS_DIR/${EXECUTION_PREFIX}_summary.csv"
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

EXECUTION_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families evidence_source authenticity_source execution_source benchmark_authenticity_verified evaluator_execution_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 attestation execution summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%s,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["evidence_source"],
        $idx["authenticity_source"],
        $idx["execution_source"],
        $idx["benchmark_authenticity_verified"] + 0,
        $idx["evaluator_execution_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08 attestation execution summary row", 3)
    }
  ' "$EXECUTION_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families evidence_source authenticity_source execution_source benchmark_authenticity_verified evaluator_execution_verified execution_action summary_routing summary_jump <<<"$EXECUTION_VALUES"

declare -A execution_id_by_family
declare -A evaluator_output_hash_by_family
declare -A run_log_hash_by_family
declare -A metric_value_by_family
execution_rows=0
execution_family_rows=0

while IFS=$'\t' read -r benchmark_family execution_id evaluator_output_hash run_log_hash metric_value; do
  ((execution_rows += 1))
  case "$benchmark_family" in
    RULER|LongBench|codebase-retrieval|real-document-qa)
      ((execution_family_rows += 1))
      ;;
  esac
  execution_id_by_family["$benchmark_family"]="$execution_id"
  evaluator_output_hash_by_family["$benchmark_family"]="$evaluator_output_hash"
  run_log_hash_by_family["$benchmark_family"]="$run_log_hash"
  metric_value_by_family["$benchmark_family"]="$metric_value"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family execution_id evaluator_output_hash run_log_hash metric_value", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 attestation execution column: " required[i], 4)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["execution_id"],
        $idx["evaluator_output_hash"],
        $idx["run_log_hash"],
        $idx["metric_value"]
    }
  ' "$EXECUTION_CSV"
)

attestation_rows=0
matched_family_rows=0
execution_id_match_rows=0
attestation_ready_rows=0
independent_attestor_rows=0
attestation_artifact_rows=0
attestation_hash_verified_rows=0
execution_hash_attested_rows=0
metric_attested_rows=0
attestation_routing="0.000000"
attestation_jump="0.000000"
declare -A attestation_seen

while IFS=$'\t' read -r benchmark_family execution_id attestation_id attestation_uri attestation_hash attestor_name attestor_org attestor_role attestor_independent attested_evaluator_output_hash attested_run_log_hash attested_metric_value attestation_ready attestor_ready execution_hash_attested metric_attested routing_trigger_rate active_jump_rate; do
  ((attestation_rows += 1))
  if [[ -n "${attestation_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08 attestation family: $benchmark_family" >&2
    exit 5
  fi
  attestation_seen["$benchmark_family"]=1

  case "$benchmark_family" in
    RULER|LongBench|codebase-retrieval|real-document-qa)
      if [[ -n "${execution_id_by_family[$benchmark_family]:-}" ]]; then
        ((matched_family_rows += 1))
      fi
      ;;
  esac

  if [[ -n "${execution_id_by_family[$benchmark_family]:-}" &&
        "${execution_id_by_family[$benchmark_family]}" == "$execution_id" ]] &&
      is_present "$execution_id"; then
    ((execution_id_match_rows += 1))
  fi

  if [[ "$attestation_ready" == "1" ]] &&
      is_present "$attestation_uri" &&
      is_present "$attestation_id" &&
      is_present "$attestor_name" &&
      is_present "$attestor_org" &&
      is_present "$attestor_role"; then
    ((attestation_ready_rows += 1))
  fi

  if attestation_path="$(uri_to_local_path "$attestation_uri")"; then
    ((attestation_artifact_rows += 1))
    if hash_matches "$attestation_path" "$attestation_hash"; then
      ((attestation_hash_verified_rows += 1))
    fi
  fi

  if [[ "$attestor_independent" == "1" &&
        "$attestor_ready" == "1" ]] &&
      is_present "$attestation_uri" &&
      [[ "$attestation_uri" != fixture://* ]] &&
      is_present "$attestation_id" &&
      is_present "$attestor_name" &&
      is_present "$attestor_org" &&
      is_present "$attestor_role"; then
    ((independent_attestor_rows += 1))
  fi

  if [[ -n "${evaluator_output_hash_by_family[$benchmark_family]:-}" &&
        "$execution_hash_attested" == "1" &&
        "$attested_evaluator_output_hash" == "${evaluator_output_hash_by_family[$benchmark_family]}" &&
        "$attested_run_log_hash" == "${run_log_hash_by_family[$benchmark_family]}" ]] &&
      is_sha256 "$attested_evaluator_output_hash" &&
      is_sha256 "$attested_run_log_hash"; then
    ((execution_hash_attested_rows += 1))
  fi

  if [[ -n "${metric_value_by_family[$benchmark_family]:-}" &&
        "$metric_attested" == "1" &&
        "$attested_metric_value" == "${metric_value_by_family[$benchmark_family]}" ]] &&
      is_present "$attested_metric_value"; then
    ((metric_attested_rows += 1))
  fi

  attestation_routing="$(awk -v a="$attestation_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  attestation_jump="$(awk -v a="$attestation_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family execution_id attestation_id attestation_uri attestation_hash attestor_name attestor_org attestor_role attestor_independent attested_evaluator_output_hash attested_run_log_hash attested_metric_value attestation_ready attestor_ready execution_hash_attested metric_attested routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 attestation column: " required[i], 6)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["benchmark_family"],
        $idx["execution_id"],
        $idx["attestation_id"],
        $idx["attestation_uri"],
        $idx["attestation_hash"],
        $idx["attestor_name"],
        $idx["attestor_org"],
        $idx["attestor_role"],
        $idx["attestor_independent"] + 0,
        $idx["attested_evaluator_output_hash"],
        $idx["attested_run_log_hash"],
        $idx["attested_metric_value"],
        $idx["attestation_ready"] + 0,
        $idx["attestor_ready"] + 0,
        $idx["execution_hash_attested"] + 0,
        $idx["metric_attested"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$ATTESTATION_CSV"
)

independent_attestation_verified=0
if [[ "$evaluator_execution_verified" == "1" &&
      "$attestation_rows" -eq "$benchmark_families" &&
      "$matched_family_rows" -eq "$benchmark_families" &&
      "$execution_id_match_rows" -eq "$benchmark_families" &&
      "$attestation_ready_rows" -eq "$benchmark_families" &&
      "$attestation_artifact_rows" -eq "$benchmark_families" &&
      "$attestation_hash_verified_rows" -eq "$benchmark_families" &&
      "$independent_attestor_rows" -eq "$benchmark_families" &&
      "$execution_hash_attested_rows" -eq "$benchmark_families" &&
      "$metric_attested_rows" -eq "$benchmark_families" &&
      "$attestation_routing" == "0.000000" &&
      "$attestation_jump" == "0.000000" ]]; then
  independent_attestation_verified=1
fi

real_external_benchmark_verified=0
action="benchmark-execution-missing"
if [[ "$evaluator_execution_verified" == "1" ]]; then
  if [[ "$attestation_rows" -ne "$benchmark_families" ||
        "$matched_family_rows" -ne "$benchmark_families" ||
        "$execution_id_match_rows" -ne "$benchmark_families" ||
        "$attestation_ready_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestation-missing"
  elif [[ "$attestation_artifact_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestation-artifact-missing"
  elif [[ "$attestation_hash_verified_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-attestation-hash-mismatch"
  elif [[ "$execution_hash_attested_rows" -ne "$benchmark_families" ||
          "$metric_attested_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-execution-attestation-missing"
  elif [[ "$independent_attestor_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-independent-attestor-missing"
  elif [[ "$independent_attestation_verified" == "1" ]]; then
    action="external-benchmark-final-review-missing"
  fi
fi

total_routing="$(awk -v a="$summary_routing" -v b="$attestation_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$summary_jump" -v b="$attestation_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,evidence_source,authenticity_source,execution_source,attestation_source,benchmark_authenticity_verified,evaluator_execution_verified,execution_action,attestation_rows,matched_family_rows,attestation_artifact_rows,attestation_hash_verified_rows,independent_attestor_rows,execution_hash_attested_rows,metric_attested_rows,independent_attestation_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08j,%d,%s,%s,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$evidence_source" \
    "$authenticity_source" \
    "$execution_source" \
    "$ATTESTATION_SOURCE" \
    "$benchmark_authenticity_verified" \
    "$evaluator_execution_verified" \
    "$execution_action" \
    "$attestation_rows" \
    "$matched_family_rows" \
    "$attestation_artifact_rows" \
    "$attestation_hash_verified_rows" \
    "$independent_attestor_rows" \
    "$execution_hash_attested_rows" \
    "$metric_attested_rows" \
    "$independent_attestation_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "evaluator-execution,%s,verified=%d\n" \
    "$([[ "$evaluator_execution_verified" == "1" ]] && echo pass || echo blocked)" \
    "$evaluator_execution_verified"
  printf "attestation-rows,%s,rows=%d\n" \
    "$([[ "$attestation_rows" -eq "$benchmark_families" && "$matched_family_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$attestation_rows"
  printf "execution-id-match,%s,matched_rows=%d\n" \
    "$([[ "$execution_id_match_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$execution_id_match_rows"
  printf "attestation-ready,%s,ready_rows=%d\n" \
    "$([[ "$attestation_ready_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$attestation_ready_rows"
  printf "attestation-hashes,%s,hash_rows=%d artifact_hash_rows=%d\n" \
    "$([[ "$attestation_hash_verified_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$attestation_hash_verified_rows" \
    "$attestation_hash_verified_rows"
  printf "independent-attestor,%s,independent_rows=%d\n" \
    "$([[ "$independent_attestor_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$independent_attestor_rows"
  printf "execution-attested,%s,hash_rows=%d metric_rows=%d\n" \
    "$([[ "$execution_hash_attested_rows" -eq "$benchmark_families" && "$metric_attested_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$execution_hash_attested_rows" \
    "$metric_attested_rows"
  printf "independent-attestation,%s,verified=%d\n" \
    "$([[ "$independent_attestation_verified" == "1" ]] && echo pass || echo blocked)" \
    "$independent_attestation_verified"
  printf "real-external-benchmark,%s,action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
