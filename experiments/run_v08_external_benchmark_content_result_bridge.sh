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

PREFIX="v08_external_benchmark_content_result_bridge"
AA_PREFIX="v08_external_benchmark_source_acquisition_content_verifier"
AB_PREFIX="v08_external_benchmark_codebase_mini"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_content_result_bridge_smoke"
  AA_PREFIX="v08_external_benchmark_source_acquisition_content_verifier_smoke"
  AB_PREFIX="v08_external_benchmark_codebase_mini_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_content_result_bridge_full"
  AA_PREFIX="v08_external_benchmark_source_acquisition_content_verifier_full"
  AB_PREFIX="v08_external_benchmark_codebase_mini_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_content_verifier.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v08_external_benchmark_codebase_mini.sh" "${RUN_ARGS[@]}" >/dev/null

AA_SUMMARY_CSV="$RESULTS_DIR/${AA_PREFIX}_summary.csv"
AA_CONTENT_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV:-$RESULTS_DIR/${AA_PREFIX}_content.csv}"
AB_SUMMARY_CSV="$RESULTS_DIR/${AB_PREFIX}_summary.csv"
BRIDGE_CSV="$RESULTS_DIR/${PREFIX}_bridge.csv"
BRIDGE_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_bridge_header() {
  echo "benchmark_family,acquisition_id,content_summary_uri,content_summary_hash,codebase_artifact_dir,result_artifact_uri,result_artifact_hash,baseline_artifact_uri,baseline_artifact_hash,dataset_uri,dataset_hash,run_manifest_uri,run_manifest_hash,evaluator_output_uri,evaluator_output_hash,source_content_bound,result_artifact_bound,baseline_bound,dataset_bound,independent_bridge_review,real_bridge_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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

hash_matches_uri() {
  local uri="$1"
  local expected="$2"
  local path
  local expected_hex
  local actual_hex

  is_sha256 "$expected" || return 1
  path="$(uri_to_local_path "$uri")" || return 1
  [[ -f "$path" ]] || return 1
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

csv_value() {
  local file="$1"
  local column="$2"
  awk -F, -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(column in idx)) {
        print "missing v08-ac column: " column > "/dev/stderr"
        exit 11
      }
      next
    }
    NR == 2 {
      print $idx[column]
      found = 1
      exit
    }
    END {
      if (!found) {
        print "missing v08-ac summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_CONTENT_RESULT_BRIDGE_CSV:-}" ]]; then
  BRIDGE_CSV="$V08_EXTERNAL_BENCHMARK_CONTENT_RESULT_BRIDGE_CSV"
  BRIDGE_SOURCE="provided-csv"
  if [[ ! -s "$BRIDGE_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_CONTENT_RESULT_BRIDGE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_bridge_header >"$BRIDGE_CSV"
fi

source_content_ready="$(csv_value "$AA_SUMMARY_CSV" "external_benchmark_source_acquisition_content_ready")"
source_content_rows="$(csv_value "$AA_SUMMARY_CSV" "content_rows")"
source_content_expected_rows="$(csv_value "$AA_SUMMARY_CSV" "expected_content_rows")"
source_content_real_external="$(csv_value "$AA_SUMMARY_CSV" "real_external_benchmark_verified")"
source_content_action="$(csv_value "$AA_SUMMARY_CSV" "action")"
source_content_routing="$(csv_value "$AA_SUMMARY_CSV" "routing_trigger_rate")"
source_content_jump="$(csv_value "$AA_SUMMARY_CSV" "active_jump_rate")"

codebase_mini_source_ready="$(csv_value "$AB_SUMMARY_CSV" "codebase_mini_source_ready")"
codebase_result_artifact_verified="$(csv_value "$AB_SUMMARY_CSV" "benchmark_result_artifact_verified")"
codebase_baseline_comparison_ready="$(csv_value "$AB_SUMMARY_CSV" "baseline_comparison_ready")"
codebase_real_external="$(csv_value "$AB_SUMMARY_CSV" "real_external_benchmark_verified")"
codebase_artifact_dir="$(csv_value "$AB_SUMMARY_CSV" "artifact_dir")"
codebase_span_exact="$(csv_value "$AB_SUMMARY_CSV" "span_exact")"
codebase_chunk_exact="$(csv_value "$AB_SUMMARY_CSV" "chunk_exact")"
codebase_missing_abstain="$(csv_value "$AB_SUMMARY_CSV" "missing_abstain")"
codebase_wrong_answer_rate="$(csv_value "$AB_SUMMARY_CSV" "wrong_answer_rate")"
codebase_routing="$(csv_value "$AB_SUMMARY_CSV" "routing_trigger_rate")"
codebase_jump="$(csv_value "$AB_SUMMARY_CSV" "active_jump_rate")"

codebase_acquisition_id=""
if [[ -s "$AA_CONTENT_CSV" ]]; then
  codebase_acquisition_id="$(
    awk -F, '
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        next
      }
      $idx["benchmark_family"] == "codebase-retrieval" {
        print $idx["acquisition_id"]
        found = 1
        exit
      }
      END {
        if (!found) print ""
      }
    ' "$AA_CONTENT_CSV"
  )"
fi

bridge_rows=0
matched_codebase_family_rows=0
acquisition_id_match_rows=0
content_summary_hash_verified_rows=0
artifact_dir_match_rows=0
required_bridge_hash_fields=0
bridge_hash_verified_fields=0
source_content_bound_rows=0
result_artifact_bound_rows=0
baseline_bound_rows=0
dataset_bound_rows=0
independent_bridge_review_rows=0
declared_real_bridge_rows=0
non_fixture_declared_rows=0
local_artifact_uri_fields=0
bridge_routing="0.000000"
bridge_jump="0.000000"
declare -A bridge_family_seen=()

BRIDGE_TSV="$TMP_DIR/content_result_bridge.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id content_summary_uri content_summary_hash codebase_artifact_dir result_artifact_uri result_artifact_hash baseline_artifact_uri baseline_artifact_hash dataset_uri dataset_hash run_manifest_uri run_manifest_hash evaluator_output_uri evaluator_output_hash source_content_bound result_artifact_bound baseline_bound dataset_bound independent_bridge_review real_bridge_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ac bridge column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ac bridge row has wrong column count", 14)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$BRIDGE_CSV" >"$BRIDGE_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id content_summary_uri content_summary_hash codebase_artifact_dir_uri result_artifact_uri result_artifact_hash baseline_artifact_uri baseline_artifact_hash dataset_uri dataset_hash run_manifest_uri run_manifest_hash evaluator_output_uri evaluator_output_hash source_content_bound result_artifact_bound baseline_bound dataset_bound independent_bridge_review real_bridge_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((bridge_rows += 1))
  bridge_family_seen["$benchmark_family"]=1

  if [[ "$benchmark_family" == "codebase-retrieval" ]]; then
    ((matched_codebase_family_rows += 1))
  fi
  if [[ "$benchmark_family" == "codebase-retrieval" &&
        -n "$codebase_acquisition_id" &&
        "$acquisition_id" == "$codebase_acquisition_id" ]]; then
    ((acquisition_id_match_rows += 1))
  fi
  if hash_matches_uri "$content_summary_uri" "$content_summary_hash"; then
    ((content_summary_hash_verified_rows += 1))
  fi
  if [[ "$codebase_artifact_dir_uri" == "file://$codebase_artifact_dir" ]]; then
    ((artifact_dir_match_rows += 1))
  fi

  for pair in \
    "$result_artifact_uri|$result_artifact_hash" \
    "$baseline_artifact_uri|$baseline_artifact_hash" \
    "$dataset_uri|$dataset_hash" \
    "$run_manifest_uri|$run_manifest_hash" \
    "$evaluator_output_uri|$evaluator_output_hash"; do
    ((required_bridge_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if hash_matches_uri "$uri" "$hash"; then
      ((bridge_hash_verified_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_artifact_uri_fields += 1))
    fi
  done

  [[ "$source_content_bound" == "1" ]] && ((source_content_bound_rows += 1))
  [[ "$result_artifact_bound" == "1" ]] && ((result_artifact_bound_rows += 1))
  [[ "$baseline_bound" == "1" ]] && ((baseline_bound_rows += 1))
  [[ "$dataset_bound" == "1" ]] && ((dataset_bound_rows += 1))
  [[ "$independent_bridge_review" == "1" ]] && ((independent_bridge_review_rows += 1))
  [[ "$real_bridge_declared" == "1" ]] && ((declared_real_bridge_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((non_fixture_declared_rows += 1))
  bridge_routing="$(awk -v a="$bridge_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  bridge_jump="$(awk -v a="$bridge_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$BRIDGE_TSV"

bridge_family_coverage=0
for _family in "${!bridge_family_seen[@]}"; do
  ((bridge_family_coverage += 1))
done

expected_external_families=4
codebase_content_result_bridge_ready=0
if [[ "$source_content_ready" == "1" &&
      "$codebase_mini_source_ready" == "1" &&
      "$codebase_result_artifact_verified" == "1" &&
      "$codebase_baseline_comparison_ready" == "1" &&
      "$bridge_rows" -eq 1 &&
      "$matched_codebase_family_rows" -eq 1 &&
      "$acquisition_id_match_rows" -eq 1 &&
      "$content_summary_hash_verified_rows" -eq 1 &&
      "$artifact_dir_match_rows" -eq 1 &&
      "$required_bridge_hash_fields" -eq 5 &&
      "$bridge_hash_verified_fields" -eq 5 &&
      "$source_content_bound_rows" -eq 1 &&
      "$result_artifact_bound_rows" -eq 1 &&
      "$baseline_bound_rows" -eq 1 &&
      "$dataset_bound_rows" -eq 1 &&
      "$independent_bridge_review_rows" -eq 1 &&
      "$declared_real_bridge_rows" -eq 1 &&
      "$non_fixture_declared_rows" -eq 1 &&
      "$bridge_routing" == "0.000000" &&
      "$bridge_jump" == "0.000000" ]]; then
  codebase_content_result_bridge_ready=1
fi

external_benchmark_result_bridge_ready=0
if [[ "$codebase_content_result_bridge_ready" == "1" &&
      "$bridge_family_coverage" -ge "$expected_external_families" &&
      "$local_artifact_uri_fields" -eq 0 ]]; then
  external_benchmark_result_bridge_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$source_content_routing" -v b="$codebase_routing" -v c="$bridge_routing" 'BEGIN { printf "%.6f", a + b + c }')"
active_jump_rate="$(awk -v a="$source_content_jump" -v b="$codebase_jump" -v c="$bridge_jump" 'BEGIN { printf "%.6f", a + b + c }')"
action="external-benchmark-source-acquisition-content-not-ready"
if [[ "$source_content_ready" != "1" ]]; then
  action="external-benchmark-source-acquisition-content-not-ready"
elif [[ "$codebase_mini_source_ready" != "1" ||
        "$codebase_result_artifact_verified" != "1" ||
        "$codebase_baseline_comparison_ready" != "1" ]]; then
  action="external-benchmark-codebase-mini-result-not-ready"
elif [[ "$bridge_rows" -eq 0 ]]; then
  action="external-benchmark-content-result-bridge-missing"
elif [[ "$bridge_rows" -ne 1 ||
        "$matched_codebase_family_rows" -ne 1 ]]; then
  action="external-benchmark-content-result-bridge-family-mismatch"
elif [[ "$acquisition_id_match_rows" -ne 1 ]]; then
  action="external-benchmark-content-result-bridge-acquisition-mismatch"
elif [[ "$content_summary_hash_verified_rows" -ne 1 ||
        "$artifact_dir_match_rows" -ne 1 ||
        "$bridge_hash_verified_fields" -ne "$required_bridge_hash_fields" ]]; then
  action="external-benchmark-content-result-bridge-hash-mismatch"
elif [[ "$source_content_bound_rows" -ne 1 ||
        "$result_artifact_bound_rows" -ne 1 ||
        "$baseline_bound_rows" -ne 1 ||
        "$dataset_bound_rows" -ne 1 ]]; then
  action="external-benchmark-content-result-bridge-binding-missing"
elif [[ "$independent_bridge_review_rows" -ne 1 ]]; then
  action="external-benchmark-content-result-bridge-review-missing"
elif [[ "$declared_real_bridge_rows" -ne 1 ||
        "$non_fixture_declared_rows" -ne 1 ]]; then
  action="external-benchmark-content-result-bridge-fixture-only"
elif [[ "$codebase_content_result_bridge_ready" == "1" &&
        "$external_benchmark_result_bridge_ready" != "1" ]]; then
  action="external-benchmark-content-result-bridge-ready-await-external-family-results"
elif [[ "$external_benchmark_result_bridge_ready" == "1" ]]; then
  action="external-benchmark-result-bridge-ready-await-final-review"
fi

{
  echo "benchmark_scope,bridge_source,source_content_ready,source_content_rows,source_content_expected_rows,source_content_real_external,source_content_action,codebase_mini_source_ready,codebase_result_artifact_verified,codebase_baseline_comparison_ready,codebase_real_external,codebase_span_exact,codebase_chunk_exact,codebase_missing_abstain,codebase_wrong_answer_rate,bridge_rows,matched_codebase_family_rows,acquisition_id_match_rows,content_summary_hash_verified_rows,artifact_dir_match_rows,required_bridge_hash_fields,bridge_hash_verified_fields,source_content_bound_rows,result_artifact_bound_rows,baseline_bound_rows,dataset_bound_rows,independent_bridge_review_rows,declared_real_bridge_rows,non_fixture_declared_rows,local_artifact_uri_fields,bridge_family_coverage,expected_external_families,codebase_content_result_bridge_ready,external_benchmark_result_bridge_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ac,%s,%d,%d,%d,%d,%s,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$BRIDGE_SOURCE" \
    "$source_content_ready" \
    "$source_content_rows" \
    "$source_content_expected_rows" \
    "$source_content_real_external" \
    "$source_content_action" \
    "$codebase_mini_source_ready" \
    "$codebase_result_artifact_verified" \
    "$codebase_baseline_comparison_ready" \
    "$codebase_real_external" \
    "$codebase_span_exact" \
    "$codebase_chunk_exact" \
    "$codebase_missing_abstain" \
    "$codebase_wrong_answer_rate" \
    "$bridge_rows" \
    "$matched_codebase_family_rows" \
    "$acquisition_id_match_rows" \
    "$content_summary_hash_verified_rows" \
    "$artifact_dir_match_rows" \
    "$required_bridge_hash_fields" \
    "$bridge_hash_verified_fields" \
    "$source_content_bound_rows" \
    "$result_artifact_bound_rows" \
    "$baseline_bound_rows" \
    "$dataset_bound_rows" \
    "$independent_bridge_review_rows" \
    "$declared_real_bridge_rows" \
    "$non_fixture_declared_rows" \
    "$local_artifact_uri_fields" \
    "$bridge_family_coverage" \
    "$expected_external_families" \
    "$codebase_content_result_bridge_ready" \
    "$external_benchmark_result_bridge_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-acquisition-content,%s,ready=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$source_content_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_content_ready" \
    "$source_content_rows" \
    "$source_content_expected_rows" \
    "$source_content_real_external" \
    "$source_content_action"
  printf "codebase-mini-result,%s,source=%d result=%d baseline=%d real=%d\n" \
    "$([[ "$codebase_mini_source_ready" == "1" && "$codebase_result_artifact_verified" == "1" && "$codebase_baseline_comparison_ready" == "1" ]] && echo pass || echo blocked)" \
    "$codebase_mini_source_ready" \
    "$codebase_result_artifact_verified" \
    "$codebase_baseline_comparison_ready" \
    "$codebase_real_external"
  printf "content-result-bridge,%s,rows=%d family=%d acq=%d summary_hash=%d artifact_dir=%d hashes=%d/%d\n" \
    "$([[ "$codebase_content_result_bridge_ready" == "1" ]] && echo pass || echo blocked)" \
    "$bridge_rows" \
    "$matched_codebase_family_rows" \
    "$acquisition_id_match_rows" \
    "$content_summary_hash_verified_rows" \
    "$artifact_dir_match_rows" \
    "$bridge_hash_verified_fields" \
    "$required_bridge_hash_fields"
  printf "bridge-review,%s,bound=%d/%d/%d/%d review=%d real=%d non_fixture=%d\n" \
    "$([[ "$source_content_bound_rows" -eq 1 && "$result_artifact_bound_rows" -eq 1 && "$baseline_bound_rows" -eq 1 && "$dataset_bound_rows" -eq 1 && "$independent_bridge_review_rows" -eq 1 && "$declared_real_bridge_rows" -eq 1 && "$non_fixture_declared_rows" -eq 1 ]] && echo pass || echo blocked)" \
    "$source_content_bound_rows" \
    "$result_artifact_bound_rows" \
    "$baseline_bound_rows" \
    "$dataset_bound_rows" \
    "$independent_bridge_review_rows" \
    "$declared_real_bridge_rows" \
    "$non_fixture_declared_rows"
  printf "external-family-coverage,%s,coverage=%d/%d local_artifact_uri_fields=%d\n" \
    "$([[ "$external_benchmark_result_bridge_ready" == "1" ]] && echo pass || echo blocked)" \
    "$bridge_family_coverage" \
    "$expected_external_families" \
    "$local_artifact_uri_fields"
  printf "real-external-benchmark,%s,real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
  printf "jump-guardrail,%s,routing=%s active_jump=%s\n" \
    "$([[ "$routing_trigger_rate" == "0.000000" && "$active_jump_rate" == "0.000000" ]] && echo pass || echo blocked)" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$DECISION_CSV"

echo "bridge: $BRIDGE_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
