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

PREFIX="v11_pc_routelm_prototype_artifact_verifier"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v11_pc_routelm_prototype_artifact_verifier_smoke"
fi

PROTOTYPE_CSV="${V11_PC_ROUTELM_PROTOTYPE_CSV:-}"
ARTIFACT_CSV="$RESULTS_DIR/${PREFIX}_artifacts.csv"
ARTIFACT_SOURCE="pending-fixture"
if [[ -n "${V11_PC_ROUTELM_PROTOTYPE_ARTIFACT_CSV:-}" ]]; then
  ARTIFACT_CSV="$V11_PC_ROUTELM_PROTOTYPE_ARTIFACT_CSV"
  ARTIFACT_SOURCE="provided-csv"
  if [[ ! -s "$ARTIFACT_CSV" ]]; then
    echo "V11_PC_ROUTELM_PROTOTYPE_ARTIFACT_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  {
    echo "prototype_id,generator_model_uri,generator_model_hash,route_memory_store_uri,route_memory_store_hash,candidate_scoring_uri,candidate_scoring_hash,decoder_binding_uri,decoder_binding_hash,nlg_smoke_uri,nlg_smoke_hash,benchmark_result_uri,benchmark_result_hash,license_uri,license_hash,provenance_uri,provenance_hash,real_prototype_declared,fixture_or_synthetic_declared,artifact_bundle_ready,nlg_transcript_ready,benchmark_link_ready,license_ready,provenance_ready,routing_trigger_rate,active_jump_rate"
    if [[ -n "$PROTOTYPE_CSV" ]]; then
      awk -F, '
        NR == 1 {
          for (i = 1; i <= NF; i++) idx[$i] = i
          required_count = split("prototype_id generator_model_uri route_memory_store_uri nlg_smoke_uri benchmark_result_uri", required, " ")
          for (i = 1; i <= required_count; i++) {
            if (!(required[i] in idx)) {
              print "missing h11 pending prototype artifact column: " required[i] > "/dev/stderr"
              exit 2
            }
          }
          next
        }
        {
          printf "%s,%s,pending,%s,pending,pending,pending,pending,pending,%s,pending,%s,pending,pending,pending,pending,pending,0,1,0,0,0,0,0,0,0\n",
            $idx["prototype_id"],
            $idx["generator_model_uri"],
            $idx["route_memory_store_uri"],
            $idx["nlg_smoke_uri"],
            $idx["benchmark_result_uri"]
        }
      ' "$PROTOTYPE_CSV"
    fi
  } >"$ARTIFACT_CSV"
fi

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

is_local_fixture_path() {
  local path="$1"
  [[ "$path" == "$RESULTS_DIR"/* ]]
}

declare -A prototype_generator_uri_by_id
declare -A prototype_route_memory_uri_by_id
declare -A prototype_nlg_uri_by_id
declare -A prototype_benchmark_uri_by_id
prototype_rows=0

if [[ -n "$PROTOTYPE_CSV" ]]; then
  while IFS=$'\t' read -r prototype_id generator_model_uri route_memory_store_uri nlg_smoke_uri benchmark_result_uri; do
    if [[ -n "${prototype_generator_uri_by_id[$prototype_id]:-}" ]]; then
      echo "duplicate h11 prototype id: $prototype_id" >&2
      exit 5
    fi
    ((prototype_rows += 1))
    prototype_generator_uri_by_id["$prototype_id"]="$generator_model_uri"
    prototype_route_memory_uri_by_id["$prototype_id"]="$route_memory_store_uri"
    prototype_nlg_uri_by_id["$prototype_id"]="$nlg_smoke_uri"
    prototype_benchmark_uri_by_id["$prototype_id"]="$benchmark_result_uri"
  done < <(
    awk -F, '
      function die(message, code) {
        print message > "/dev/stderr"
        exit code
      }
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("prototype_id generator_model_uri route_memory_store_uri nlg_smoke_uri benchmark_result_uri", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing h11 prototype verifier column: " required[i], 6)
        }
        next
      }
      {
        printf "%s\t%s\t%s\t%s\t%s\n",
          $idx["prototype_id"],
          $idx["generator_model_uri"],
          $idx["route_memory_store_uri"],
          $idx["nlg_smoke_uri"],
          $idx["benchmark_result_uri"]
      }
    ' "$PROTOTYPE_CSV"
  )
fi

artifact_rows=0
matched_prototype_rows=0
generator_artifact_rows=0
generator_hash_verified_rows=0
route_memory_artifact_rows=0
route_memory_hash_verified_rows=0
candidate_scorer_artifact_rows=0
candidate_scorer_hash_verified_rows=0
decoder_binding_artifact_rows=0
decoder_binding_hash_verified_rows=0
nlg_smoke_artifact_rows=0
nlg_smoke_hash_verified_rows=0
benchmark_result_artifact_rows=0
benchmark_result_hash_verified_rows=0
license_artifact_rows=0
license_hash_verified_rows=0
provenance_artifact_rows=0
provenance_hash_verified_rows=0
ready_rows=0
local_fixture_uri_rows=0
real_prototype_declared_rows=0
non_fixture_declared_rows=0
artifact_routing="0.000000"
artifact_jump="0.000000"
declare -A artifact_seen

check_artifact() {
  local uri="$1"
  local expected_hash="$2"
  local rows_var="$3"
  local hash_rows_var="$4"
  local path

  if path="$(uri_to_local_path "$uri")"; then
    printf -v "$rows_var" '%d' "$((${!rows_var} + 1))"
    if is_local_fixture_path "$path"; then
      row_local_fixture=1
    fi
    if hash_matches "$path" "$expected_hash"; then
      printf -v "$hash_rows_var" '%d' "$((${!hash_rows_var} + 1))"
    fi
  fi
}

while IFS=$'\t' read -r prototype_id generator_model_uri generator_model_hash route_memory_store_uri route_memory_store_hash candidate_scoring_uri candidate_scoring_hash decoder_binding_uri decoder_binding_hash nlg_smoke_uri nlg_smoke_hash benchmark_result_uri benchmark_result_hash license_uri license_hash provenance_uri provenance_hash real_prototype_declared fixture_or_synthetic_declared artifact_bundle_ready nlg_transcript_ready benchmark_link_ready license_ready provenance_ready routing_trigger_rate active_jump_rate; do
  ((artifact_rows += 1))
  row_local_fixture=0
  if [[ -n "${artifact_seen[$prototype_id]:-}" ]]; then
    echo "duplicate h11 prototype artifact id: $prototype_id" >&2
    exit 7
  fi
  artifact_seen["$prototype_id"]=1

  if [[ -n "${prototype_generator_uri_by_id[$prototype_id]:-}" &&
        "${prototype_generator_uri_by_id[$prototype_id]}" == "$generator_model_uri" &&
        "${prototype_route_memory_uri_by_id[$prototype_id]}" == "$route_memory_store_uri" &&
        "${prototype_nlg_uri_by_id[$prototype_id]}" == "$nlg_smoke_uri" &&
        "${prototype_benchmark_uri_by_id[$prototype_id]}" == "$benchmark_result_uri" ]]; then
    ((matched_prototype_rows += 1))
  fi

  check_artifact "$generator_model_uri" "$generator_model_hash" generator_artifact_rows generator_hash_verified_rows
  check_artifact "$route_memory_store_uri" "$route_memory_store_hash" route_memory_artifact_rows route_memory_hash_verified_rows
  check_artifact "$candidate_scoring_uri" "$candidate_scoring_hash" candidate_scorer_artifact_rows candidate_scorer_hash_verified_rows
  check_artifact "$decoder_binding_uri" "$decoder_binding_hash" decoder_binding_artifact_rows decoder_binding_hash_verified_rows
  check_artifact "$nlg_smoke_uri" "$nlg_smoke_hash" nlg_smoke_artifact_rows nlg_smoke_hash_verified_rows
  check_artifact "$benchmark_result_uri" "$benchmark_result_hash" benchmark_result_artifact_rows benchmark_result_hash_verified_rows
  check_artifact "$license_uri" "$license_hash" license_artifact_rows license_hash_verified_rows
  check_artifact "$provenance_uri" "$provenance_hash" provenance_artifact_rows provenance_hash_verified_rows

  if [[ "$artifact_bundle_ready" == "1" &&
        "$nlg_transcript_ready" == "1" &&
        "$benchmark_link_ready" == "1" &&
        "$license_ready" == "1" &&
        "$provenance_ready" == "1" ]] &&
      is_present "$prototype_id" &&
      is_present "$generator_model_uri" &&
      is_present "$route_memory_store_uri" &&
      is_present "$candidate_scoring_uri" &&
      is_present "$decoder_binding_uri" &&
      is_present "$nlg_smoke_uri" &&
      is_present "$benchmark_result_uri" &&
      is_present "$license_uri" &&
      is_present "$provenance_uri"; then
    ((ready_rows += 1))
  fi

  if [[ "$row_local_fixture" == "1" ]]; then
    ((local_fixture_uri_rows += 1))
  fi
  if [[ "$real_prototype_declared" == "1" ]]; then
    ((real_prototype_declared_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  artifact_routing="$(awk -v a="$artifact_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  artifact_jump="$(awk -v a="$artifact_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("prototype_id generator_model_uri generator_model_hash route_memory_store_uri route_memory_store_hash candidate_scoring_uri candidate_scoring_hash decoder_binding_uri decoder_binding_hash nlg_smoke_uri nlg_smoke_hash benchmark_result_uri benchmark_result_hash license_uri license_hash provenance_uri provenance_hash real_prototype_declared fixture_or_synthetic_declared artifact_bundle_ready nlg_transcript_ready benchmark_link_ready license_ready provenance_ready routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h11 prototype artifact verifier column: " required[i], 8)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["prototype_id"],
        $idx["generator_model_uri"],
        $idx["generator_model_hash"],
        $idx["route_memory_store_uri"],
        $idx["route_memory_store_hash"],
        $idx["candidate_scoring_uri"],
        $idx["candidate_scoring_hash"],
        $idx["decoder_binding_uri"],
        $idx["decoder_binding_hash"],
        $idx["nlg_smoke_uri"],
        $idx["nlg_smoke_hash"],
        $idx["benchmark_result_uri"],
        $idx["benchmark_result_hash"],
        $idx["license_uri"],
        $idx["license_hash"],
        $idx["provenance_uri"],
        $idx["provenance_hash"],
        $idx["real_prototype_declared"] + 0,
        $idx["fixture_or_synthetic_declared"] + 0,
        $idx["artifact_bundle_ready"] + 0,
        $idx["nlg_transcript_ready"] + 0,
        $idx["benchmark_link_ready"] + 0,
        $idx["license_ready"] + 0,
        $idx["provenance_ready"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$ARTIFACT_CSV"
)

prototype_artifact_chain_verified=0
if [[ "$prototype_rows" -gt 0 &&
      "$artifact_rows" -eq "$prototype_rows" &&
      "$matched_prototype_rows" -eq "$artifact_rows" &&
      "$generator_artifact_rows" -eq "$artifact_rows" &&
      "$generator_hash_verified_rows" -eq "$artifact_rows" &&
      "$route_memory_artifact_rows" -eq "$artifact_rows" &&
      "$route_memory_hash_verified_rows" -eq "$artifact_rows" &&
      "$candidate_scorer_artifact_rows" -eq "$artifact_rows" &&
      "$candidate_scorer_hash_verified_rows" -eq "$artifact_rows" &&
      "$decoder_binding_artifact_rows" -eq "$artifact_rows" &&
      "$decoder_binding_hash_verified_rows" -eq "$artifact_rows" &&
      "$nlg_smoke_artifact_rows" -eq "$artifact_rows" &&
      "$nlg_smoke_hash_verified_rows" -eq "$artifact_rows" &&
      "$benchmark_result_artifact_rows" -eq "$artifact_rows" &&
      "$benchmark_result_hash_verified_rows" -eq "$artifact_rows" &&
      "$license_artifact_rows" -eq "$artifact_rows" &&
      "$license_hash_verified_rows" -eq "$artifact_rows" &&
      "$provenance_artifact_rows" -eq "$artifact_rows" &&
      "$provenance_hash_verified_rows" -eq "$artifact_rows" &&
      "$ready_rows" -eq "$artifact_rows" &&
      "$artifact_routing" == "0.000000" &&
      "$artifact_jump" == "0.000000" ]]; then
  prototype_artifact_chain_verified=1
fi

real_pc_routelm_artifact_verified=0
action="pc-routelm-components-missing"
if [[ "$prototype_rows" -gt 0 ]]; then
  if [[ "$artifact_rows" -eq 0 ||
        "$matched_prototype_rows" -ne "$artifact_rows" ||
        "$ready_rows" -ne "$artifact_rows" ]]; then
    action="pc-routelm-artifact-evidence-missing"
  elif [[ "$generator_hash_verified_rows" -ne "$artifact_rows" ||
          "$route_memory_hash_verified_rows" -ne "$artifact_rows" ||
          "$candidate_scorer_hash_verified_rows" -ne "$artifact_rows" ||
          "$decoder_binding_hash_verified_rows" -ne "$artifact_rows" ||
          "$nlg_smoke_hash_verified_rows" -ne "$artifact_rows" ||
          "$benchmark_result_hash_verified_rows" -ne "$artifact_rows" ]]; then
    action="pc-routelm-artifact-hash-mismatch"
  elif [[ "$license_hash_verified_rows" -ne "$artifact_rows" ||
          "$provenance_hash_verified_rows" -ne "$artifact_rows" ]]; then
    action="pc-routelm-artifact-provenance-missing"
  elif [[ "$real_prototype_declared_rows" -ne "$artifact_rows" ||
          "$non_fixture_declared_rows" -ne "$artifact_rows" ||
          "$local_fixture_uri_rows" -ne 0 ]]; then
    action="pc-routelm-real-artifact-review-missing"
  elif [[ "$prototype_artifact_chain_verified" == "1" ]]; then
    real_pc_routelm_artifact_verified=1
    action="pc-routelm-real-artifact-verified"
  fi
fi

{
  echo "prototype_artifact_scope,prototype_source,artifact_source,prototype_rows,artifact_rows,matched_prototype_rows,generator_artifact_rows,generator_hash_verified_rows,route_memory_artifact_rows,route_memory_hash_verified_rows,candidate_scorer_artifact_rows,candidate_scorer_hash_verified_rows,decoder_binding_artifact_rows,decoder_binding_hash_verified_rows,nlg_smoke_artifact_rows,nlg_smoke_hash_verified_rows,benchmark_result_artifact_rows,benchmark_result_hash_verified_rows,license_artifact_rows,license_hash_verified_rows,provenance_artifact_rows,provenance_hash_verified_rows,ready_rows,local_fixture_uri_rows,real_prototype_declared_rows,non_fixture_declared_rows,prototype_artifact_chain_verified,real_pc_routelm_artifact_verified,action,routing_trigger_rate,active_jump_rate"
  printf "h11b-pc-routelm-artifacts,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$([[ -n "$PROTOTYPE_CSV" ]] && echo provided-csv || echo pending-fixture)" \
    "$ARTIFACT_SOURCE" \
    "$prototype_rows" \
    "$artifact_rows" \
    "$matched_prototype_rows" \
    "$generator_artifact_rows" \
    "$generator_hash_verified_rows" \
    "$route_memory_artifact_rows" \
    "$route_memory_hash_verified_rows" \
    "$candidate_scorer_artifact_rows" \
    "$candidate_scorer_hash_verified_rows" \
    "$decoder_binding_artifact_rows" \
    "$decoder_binding_hash_verified_rows" \
    "$nlg_smoke_artifact_rows" \
    "$nlg_smoke_hash_verified_rows" \
    "$benchmark_result_artifact_rows" \
    "$benchmark_result_hash_verified_rows" \
    "$license_artifact_rows" \
    "$license_hash_verified_rows" \
    "$provenance_artifact_rows" \
    "$provenance_hash_verified_rows" \
    "$ready_rows" \
    "$local_fixture_uri_rows" \
    "$real_prototype_declared_rows" \
    "$non_fixture_declared_rows" \
    "$prototype_artifact_chain_verified" \
    "$real_pc_routelm_artifact_verified" \
    "$action" \
    "$artifact_routing" \
    "$artifact_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "prototype-evidence,%s,prototype_rows=%d artifact_rows=%d\n" \
    "$([[ "$prototype_rows" -gt 0 && "$artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$prototype_rows" \
    "$artifact_rows"
  printf "artifact-chain,%s,verified=%d\n" \
    "$([[ "$prototype_artifact_chain_verified" == "1" ]] && echo pass || echo blocked)" \
    "$prototype_artifact_chain_verified"
  printf "generator-artifact,%s,hash_rows=%d\n" \
    "$([[ "$generator_hash_verified_rows" -eq "$artifact_rows" && "$artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$generator_hash_verified_rows"
  printf "route-memory-artifact,%s,hash_rows=%d\n" \
    "$([[ "$route_memory_hash_verified_rows" -eq "$artifact_rows" && "$artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$route_memory_hash_verified_rows"
  printf "scoring-decoder-artifacts,%s,scorer_hash_rows=%d decoder_hash_rows=%d\n" \
    "$([[ "$candidate_scorer_hash_verified_rows" -eq "$artifact_rows" && "$decoder_binding_hash_verified_rows" -eq "$artifact_rows" && "$artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$candidate_scorer_hash_verified_rows" \
    "$decoder_binding_hash_verified_rows"
  printf "nlg-smoke-artifact,%s,hash_rows=%d\n" \
    "$([[ "$nlg_smoke_hash_verified_rows" -eq "$artifact_rows" && "$artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$nlg_smoke_hash_verified_rows"
  printf "benchmark-link-artifact,%s,hash_rows=%d\n" \
    "$([[ "$benchmark_result_hash_verified_rows" -eq "$artifact_rows" && "$artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$benchmark_result_hash_verified_rows"
  printf "license-provenance,%s,license_hash_rows=%d provenance_hash_rows=%d\n" \
    "$([[ "$license_hash_verified_rows" -eq "$artifact_rows" && "$provenance_hash_verified_rows" -eq "$artifact_rows" && "$artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$license_hash_verified_rows" \
    "$provenance_hash_verified_rows"
  printf "real-pc-routelm-artifacts,%s,action=%s\n" \
    "$([[ "$real_pc_routelm_artifact_verified" == "1" ]] && echo pass || echo blocked)" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
