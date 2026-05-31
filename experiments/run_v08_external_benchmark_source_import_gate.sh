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

PREFIX="v08_external_benchmark_source_import_gate"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
EXECUTION_PREFIX="v08_external_benchmark_execution_gate"
IDENTITY_PREFIX="v08_external_benchmark_attestor_identity_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_gate_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  EXECUTION_PREFIX="v08_external_benchmark_execution_gate_smoke"
  IDENTITY_PREFIX="v08_external_benchmark_attestor_identity_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_attestor_identity_gate.sh" "${RUN_ARGS[@]}" >/dev/null

EVIDENCE_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv"
EXECUTION_CSV="$RESULTS_DIR/${EXECUTION_PREFIX}_execution.csv"
if [[ -n "${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV"
fi
if [[ -n "${V08_EXTERNAL_BENCHMARK_EXECUTION_CSV:-}" ]]; then
  EXECUTION_CSV="$V08_EXTERNAL_BENCHMARK_EXECUTION_CSV"
fi

SOURCE_IMPORT_CSV=""
SOURCE_IMPORT_SOURCE="pending-fixture"
if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV:-}" ]]; then
  SOURCE_IMPORT_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV"
  SOURCE_IMPORT_SOURCE="provided-csv"
  if [[ ! -s "$SOURCE_IMPORT_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
fi

IDENTITY_SUMMARY_CSV="$RESULTS_DIR/${IDENTITY_PREFIX}_summary.csv"
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
      required_count = split("benchmark_families evidence_source execution_source attestor_identity_source attestor_identity_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 source import identity summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%s,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["evidence_source"],
        $idx["execution_source"],
        $idx["attestor_identity_source"],
        $idx["attestor_identity_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08 source import identity summary row", 3)
    }
  ' "$IDENTITY_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families evidence_source execution_source attestor_identity_source attestor_identity_verified identity_action summary_routing summary_jump <<<"$IDENTITY_VALUES"

declare -A dataset_uri_by_family
declare -A result_uri_by_family
declare -A source_hash_by_family
declare -A provenance_hash_by_family

while IFS=$'\t' read -r benchmark_family dataset_uri result_uri source_hash provenance_hash; do
  dataset_uri_by_family["$benchmark_family"]="$dataset_uri"
  result_uri_by_family["$benchmark_family"]="$result_uri"
  source_hash_by_family["$benchmark_family"]="$source_hash"
  provenance_hash_by_family["$benchmark_family"]="$provenance_hash"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family dataset_uri result_uri source_hash provenance_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 source import evidence column: " required[i], 4)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["dataset_uri"],
        $idx["result_uri"],
        $idx["source_hash"],
        $idx["provenance_hash"]
    }
  ' "$EVIDENCE_CSV"
)

declare -A evaluator_output_uri_by_family
declare -A run_log_uri_by_family
declare -A evaluator_output_hash_by_family
declare -A run_log_hash_by_family

while IFS=$'\t' read -r benchmark_family evaluator_output_uri run_log_uri evaluator_output_hash run_log_hash; do
  evaluator_output_uri_by_family["$benchmark_family"]="$evaluator_output_uri"
  run_log_uri_by_family["$benchmark_family"]="$run_log_uri"
  evaluator_output_hash_by_family["$benchmark_family"]="$evaluator_output_hash"
  run_log_hash_by_family["$benchmark_family"]="$run_log_hash"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family evaluator_output_uri run_log_uri evaluator_output_hash run_log_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08 source import execution column: " required[i], 5)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\n",
        $idx["benchmark_family"],
        $idx["evaluator_output_uri"],
        $idx["run_log_uri"],
        $idx["evaluator_output_hash"],
        $idx["run_log_hash"]
    }
  ' "$EXECUTION_CSV"
)

source_import_rows=0
artifact_uri_match_rows=0
critical_hash_match_rows=0
import_ready_rows=0
import_artifact_rows=0
import_hash_verified_rows=0
local_import_artifact_rows=0
nonlocal_import_artifact_rows=0
live_network_import_rows=0
offline_replay_rows=0
real_source_import_declared_rows=0
non_fixture_declared_rows=0
independent_import_reviewed_rows=0
source_import_routing="0.000000"
source_import_jump="0.000000"
declare -A source_import_seen

if [[ -n "$SOURCE_IMPORT_CSV" ]]; then
  while IFS=$'\t' read -r benchmark_family source_import_id dataset_uri result_uri evaluator_output_uri run_log_uri source_hash provenance_hash evaluator_output_hash run_log_hash import_manifest_uri import_manifest_hash import_fetch_log_uri import_fetch_log_hash import_reviewer_identity_uri import_reviewer_identity_hash source_import_protocol_version live_network_import_performed offline_replay_used real_source_import_declared fixture_or_synthetic_declared independent_source_import_reviewed routing_trigger_rate active_jump_rate import_manifest_hash_attested import_fetch_log_hash_attested import_reviewer_identity_hash_attested; do
    ((source_import_rows += 1))
    if [[ -n "${source_import_seen[$benchmark_family]:-}" ]]; then
      echo "duplicate v08 source import family: $benchmark_family" >&2
      exit 6
    fi
    source_import_seen["$benchmark_family"]=1

    if is_present "$source_import_id" &&
        is_present "$import_manifest_uri" &&
        is_present "$import_fetch_log_uri" &&
        is_present "$import_reviewer_identity_uri" &&
        is_present "$source_import_protocol_version"; then
      ((import_ready_rows += 1))
    fi

    if [[ -n "${dataset_uri_by_family[$benchmark_family]:-}" &&
          -n "${result_uri_by_family[$benchmark_family]:-}" &&
          -n "${evaluator_output_uri_by_family[$benchmark_family]:-}" &&
          -n "${run_log_uri_by_family[$benchmark_family]:-}" &&
          "$dataset_uri" == "${dataset_uri_by_family[$benchmark_family]}" &&
          "$result_uri" == "${result_uri_by_family[$benchmark_family]}" &&
          "$evaluator_output_uri" == "${evaluator_output_uri_by_family[$benchmark_family]}" &&
          "$run_log_uri" == "${run_log_uri_by_family[$benchmark_family]}" ]]; then
      ((artifact_uri_match_rows += 1))
    fi

    if [[ -n "${source_hash_by_family[$benchmark_family]:-}" &&
          -n "${provenance_hash_by_family[$benchmark_family]:-}" &&
          -n "${evaluator_output_hash_by_family[$benchmark_family]:-}" &&
          -n "${run_log_hash_by_family[$benchmark_family]:-}" &&
          "$source_hash" == "${source_hash_by_family[$benchmark_family]}" &&
          "$provenance_hash" == "${provenance_hash_by_family[$benchmark_family]}" &&
          "$evaluator_output_hash" == "${evaluator_output_hash_by_family[$benchmark_family]}" &&
          "$run_log_hash" == "${run_log_hash_by_family[$benchmark_family]}" ]] &&
        is_sha256 "$source_hash" &&
        is_sha256 "$provenance_hash" &&
        is_sha256 "$evaluator_output_hash" &&
        is_sha256 "$run_log_hash"; then
      ((critical_hash_match_rows += 1))
    fi

    if manifest_path="$(uri_to_local_path "$import_manifest_uri")"; then
      ((local_import_artifact_rows += 1))
      ((import_artifact_rows += 1))
      if hash_matches "$manifest_path" "$import_manifest_hash"; then
        ((import_hash_verified_rows += 1))
      fi
    elif is_https_uri "$import_manifest_uri" &&
         [[ "$import_manifest_hash_attested" == "1" ]] &&
         is_sha256 "$import_manifest_hash"; then
      ((nonlocal_import_artifact_rows += 1))
      ((import_artifact_rows += 1))
      ((import_hash_verified_rows += 1))
    fi

    if fetch_log_path="$(uri_to_local_path "$import_fetch_log_uri")"; then
      ((local_import_artifact_rows += 1))
      ((import_artifact_rows += 1))
      if hash_matches "$fetch_log_path" "$import_fetch_log_hash"; then
        ((import_hash_verified_rows += 1))
      fi
    elif is_https_uri "$import_fetch_log_uri" &&
         [[ "$import_fetch_log_hash_attested" == "1" ]] &&
         is_sha256 "$import_fetch_log_hash"; then
      ((nonlocal_import_artifact_rows += 1))
      ((import_artifact_rows += 1))
      ((import_hash_verified_rows += 1))
    fi

    if reviewer_path="$(uri_to_local_path "$import_reviewer_identity_uri")"; then
      ((local_import_artifact_rows += 1))
      ((import_artifact_rows += 1))
      if hash_matches "$reviewer_path" "$import_reviewer_identity_hash"; then
        ((import_hash_verified_rows += 1))
      fi
    elif is_https_uri "$import_reviewer_identity_uri" &&
         [[ "$import_reviewer_identity_hash_attested" == "1" ]] &&
         is_sha256 "$import_reviewer_identity_hash"; then
      ((nonlocal_import_artifact_rows += 1))
      ((import_artifact_rows += 1))
      ((import_hash_verified_rows += 1))
    fi

    if [[ "$live_network_import_performed" == "1" ]]; then
      ((live_network_import_rows += 1))
    fi

    if [[ "$offline_replay_used" == "1" ]]; then
      ((offline_replay_rows += 1))
    fi

    if [[ "$real_source_import_declared" == "1" ]]; then
      ((real_source_import_declared_rows += 1))
    fi

    if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
      ((non_fixture_declared_rows += 1))
    fi

    if [[ "$independent_source_import_reviewed" == "1" ]]; then
      ((independent_import_reviewed_rows += 1))
    fi

    source_import_routing="$(awk -v a="$source_import_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
    source_import_jump="$(awk -v a="$source_import_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
  done < <(
    awk -F, '
      function die(message, code) {
        print message > "/dev/stderr"
        exit code
      }
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("benchmark_family source_import_id dataset_uri result_uri evaluator_output_uri run_log_uri source_hash provenance_hash evaluator_output_hash run_log_hash import_manifest_uri import_manifest_hash import_fetch_log_uri import_fetch_log_hash import_reviewer_identity_uri import_reviewer_identity_hash source_import_protocol_version live_network_import_performed offline_replay_used real_source_import_declared fixture_or_synthetic_declared independent_source_import_reviewed routing_trigger_rate active_jump_rate", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing v08 source import column: " required[i], 7)
        }
        import_manifest_hash_attested_idx = ("import_manifest_hash_attested" in idx) ? idx["import_manifest_hash_attested"] : 0
        import_fetch_log_hash_attested_idx = ("import_fetch_log_hash_attested" in idx) ? idx["import_fetch_log_hash_attested"] : 0
        import_reviewer_identity_hash_attested_idx = ("import_reviewer_identity_hash_attested" in idx) ? idx["import_reviewer_identity_hash_attested"] : 0
        next
      }
      {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%d\t%d\t%d\n",
          $idx["benchmark_family"],
          $idx["source_import_id"],
          $idx["dataset_uri"],
          $idx["result_uri"],
          $idx["evaluator_output_uri"],
          $idx["run_log_uri"],
          $idx["source_hash"],
          $idx["provenance_hash"],
          $idx["evaluator_output_hash"],
          $idx["run_log_hash"],
          $idx["import_manifest_uri"],
          $idx["import_manifest_hash"],
          $idx["import_fetch_log_uri"],
          $idx["import_fetch_log_hash"],
          $idx["import_reviewer_identity_uri"],
          $idx["import_reviewer_identity_hash"],
          $idx["source_import_protocol_version"],
          $idx["live_network_import_performed"] + 0,
          $idx["offline_replay_used"] + 0,
          $idx["real_source_import_declared"] + 0,
          $idx["fixture_or_synthetic_declared"] + 0,
          $idx["independent_source_import_reviewed"] + 0,
          $idx["routing_trigger_rate"] + 0,
          $idx["active_jump_rate"] + 0,
          import_manifest_hash_attested_idx ? $import_manifest_hash_attested_idx + 0 : 0,
          import_fetch_log_hash_attested_idx ? $import_fetch_log_hash_attested_idx + 0 : 0,
          import_reviewer_identity_hash_attested_idx ? $import_reviewer_identity_hash_attested_idx + 0 : 0
      }
    ' "$SOURCE_IMPORT_CSV"
  )
fi

expected_import_artifacts=$((benchmark_families * 3))
source_import_contract_ready=0
if [[ "$attestor_identity_verified" == "1" &&
      "$source_import_rows" -eq "$benchmark_families" &&
      "$artifact_uri_match_rows" -eq "$benchmark_families" &&
      "$critical_hash_match_rows" -eq "$benchmark_families" &&
      "$import_ready_rows" -eq "$benchmark_families" &&
      "$import_artifact_rows" -eq "$expected_import_artifacts" &&
      "$import_hash_verified_rows" -eq "$expected_import_artifacts" &&
      "$local_import_artifact_rows" -eq 0 &&
      "$live_network_import_rows" -eq "$benchmark_families" &&
      "$offline_replay_rows" -eq 0 &&
      "$real_source_import_declared_rows" -eq "$benchmark_families" &&
      "$non_fixture_declared_rows" -eq "$benchmark_families" &&
      "$independent_import_reviewed_rows" -eq "$benchmark_families" &&
      "$source_import_routing" == "0.000000" &&
      "$source_import_jump" == "0.000000" ]]; then
  source_import_contract_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$identity_action"
if [[ "$attestor_identity_verified" == "1" ]]; then
  if [[ "$source_import_rows" -ne "$benchmark_families" ||
        "$import_ready_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-source-import-evidence-missing"
  elif [[ "$artifact_uri_match_rows" -ne "$benchmark_families" ||
          "$critical_hash_match_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-source-import-chain-mismatch"
  elif [[ "$import_artifact_rows" -ne "$expected_import_artifacts" ||
          "$import_hash_verified_rows" -ne "$expected_import_artifacts" ]]; then
    action="external-benchmark-source-import-artifact-hash-mismatch"
  elif [[ "$local_import_artifact_rows" -gt 0 ]]; then
    action="external-benchmark-local-source-import-artifact"
  elif [[ "$live_network_import_rows" -ne "$benchmark_families" ||
          "$offline_replay_rows" -ne 0 ]]; then
    action="external-benchmark-source-import-live-network-missing"
  elif [[ "$real_source_import_declared_rows" -ne "$benchmark_families" ||
          "$non_fixture_declared_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-source-import-real-declaration-missing"
  elif [[ "$independent_import_reviewed_rows" -ne "$benchmark_families" ]]; then
    action="external-benchmark-source-import-review-missing"
  elif [[ "$source_import_contract_ready" == "1" ]]; then
    action="external-benchmark-source-import-real-verifier-missing"
  fi
fi

total_routing="$(awk -v a="$summary_routing" -v b="$source_import_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$summary_jump" -v b="$source_import_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "benchmark_scope,benchmark_families,evidence_source,execution_source,attestor_identity_source,source_import_source,attestor_identity_verified,identity_action,source_import_rows,artifact_uri_match_rows,critical_hash_match_rows,import_ready_rows,import_artifact_rows,import_hash_verified_rows,local_import_artifact_rows,nonlocal_import_artifact_rows,live_network_import_rows,offline_replay_rows,real_source_import_declared_rows,non_fixture_declared_rows,independent_import_reviewed_rows,source_import_contract_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08m,%d,%s,%s,%s,%s,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$evidence_source" \
    "$execution_source" \
    "$attestor_identity_source" \
    "$SOURCE_IMPORT_SOURCE" \
    "$attestor_identity_verified" \
    "$identity_action" \
    "$source_import_rows" \
    "$artifact_uri_match_rows" \
    "$critical_hash_match_rows" \
    "$import_ready_rows" \
    "$import_artifact_rows" \
    "$import_hash_verified_rows" \
    "$local_import_artifact_rows" \
    "$nonlocal_import_artifact_rows" \
    "$live_network_import_rows" \
    "$offline_replay_rows" \
    "$real_source_import_declared_rows" \
    "$non_fixture_declared_rows" \
    "$independent_import_reviewed_rows" \
    "$source_import_contract_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "prior-attestor-identity,%s,verified=%d action=%s\n" \
    "$([[ "$attestor_identity_verified" == "1" ]] && echo pass || echo blocked)" \
    "$attestor_identity_verified" \
    "$identity_action"
  printf "source-import-rows,%s,rows=%d/%d ready=%d\n" \
    "$([[ "$source_import_rows" -eq "$benchmark_families" && "$import_ready_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$source_import_rows" \
    "$benchmark_families" \
    "$import_ready_rows"
  printf "source-import-chain,%s,uri_match=%d hash_match=%d\n" \
    "$([[ "$artifact_uri_match_rows" -eq "$benchmark_families" && "$critical_hash_match_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$artifact_uri_match_rows" \
    "$critical_hash_match_rows"
  printf "source-import-artifact-hash,%s,artifact_rows=%d/%d hash_rows=%d/%d\n" \
    "$([[ "$import_artifact_rows" -eq "$expected_import_artifacts" && "$import_hash_verified_rows" -eq "$expected_import_artifacts" ]] && echo pass || echo blocked)" \
    "$import_artifact_rows" \
    "$expected_import_artifacts" \
    "$import_hash_verified_rows" \
    "$expected_import_artifacts"
  printf "local-source-import-artifact,%s,local=%d nonlocal=%d\n" \
    "$([[ "$local_import_artifact_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$local_import_artifact_rows" \
    "$nonlocal_import_artifact_rows"
  printf "live-network-source-import,%s,live=%d/%d replay=%d\n" \
    "$([[ "$live_network_import_rows" -eq "$benchmark_families" && "$offline_replay_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$live_network_import_rows" \
    "$benchmark_families" \
    "$offline_replay_rows"
  printf "real-source-import-declaration,%s,real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$real_source_import_declared_rows" -eq "$benchmark_families" && "$non_fixture_declared_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$real_source_import_declared_rows" \
    "$benchmark_families" \
    "$non_fixture_declared_rows" \
    "$benchmark_families"
  printf "independent-source-import-review,%s,reviewed=%d/%d\n" \
    "$([[ "$independent_import_reviewed_rows" -eq "$benchmark_families" ]] && echo pass || echo blocked)" \
    "$independent_import_reviewed_rows" \
    "$benchmark_families"
  printf "source-import-contract,%s,ready=%d\n" \
    "$([[ "$source_import_contract_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_contract_ready"
  printf "source-import-verification,%s,verified=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
