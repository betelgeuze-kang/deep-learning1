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

PREFIX="v08_external_benchmark_family_result_bridge"
AA_PREFIX="v08_external_benchmark_source_acquisition_content_verifier"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_family_result_bridge_smoke"
  AA_PREFIX="v08_external_benchmark_source_acquisition_content_verifier_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_family_result_bridge_full"
  AA_PREFIX="v08_external_benchmark_source_acquisition_content_verifier_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_content_verifier.sh" "${RUN_ARGS[@]}" >/dev/null

AA_SUMMARY_CSV="$RESULTS_DIR/${AA_PREFIX}_summary.csv"
AA_CONTENT_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV:-$RESULTS_DIR/${AA_PREFIX}_content.csv}"
BRIDGE_CSV="$RESULTS_DIR/${PREFIX}_bridge.csv"
BRIDGE_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
RESULT_HASH_FIELDS_PER_ROW=7

write_bridge_header() {
  echo "benchmark_family,acquisition_id,content_summary_uri,content_summary_hash,result_artifact_uri,result_artifact_hash,baseline_artifact_uri,baseline_artifact_hash,dataset_uri,dataset_hash,run_manifest_uri,run_manifest_hash,evaluator_output_uri,evaluator_output_hash,result_authority_uri,result_authority_hash,publication_package_uri,publication_package_hash,source_content_bound,result_artifact_bound,baseline_bound,dataset_bound,result_authority_bound,publication_bound,independent_bridge_review,real_bridge_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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

is_expected_family() {
  local family="$1"
  local expected

  for expected in "${EXPECTED_FAMILIES[@]}"; do
    [[ "$family" == "$expected" ]] && return 0
  done
  return 1
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
        print "missing v08-ad column: " column > "/dev/stderr"
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
        print "missing v08-ad summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV:-}" ]]; then
  BRIDGE_CSV="$V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV"
  BRIDGE_SOURCE="provided-csv"
  if [[ ! -s "$BRIDGE_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV must point to a non-empty CSV" >&2
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

declare -A content_acquisition_id=()
declare -A content_family_seen=()
content_family_expected_rows=0
CONTENT_TSV="$TMP_DIR/source_content.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ad content column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ad content row has wrong column count", 14)
    printf "%s\t%s\n", $idx["benchmark_family"], $idx["acquisition_id"]
  }
' "$AA_CONTENT_CSV" >"$CONTENT_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id; do
  content_acquisition_id["$benchmark_family"]="$acquisition_id"
  content_family_seen["$benchmark_family"]=1
done <"$CONTENT_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${content_family_seen[$family]:-}" ]]; then
    ((content_family_expected_rows += 1))
  fi
done

bridge_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_source_content_family_rows=0
acquisition_id_match_rows=0
content_summary_hash_verified_rows=0
required_result_hash_fields=0
result_hash_attested_fields=0
nonlocal_result_uri_fields=0
local_result_uri_fields=0
source_content_bound_rows=0
result_artifact_bound_rows=0
baseline_bound_rows=0
dataset_bound_rows=0
result_authority_bound_rows=0
publication_bound_rows=0
independent_bridge_review_rows=0
declared_real_bridge_rows=0
non_fixture_declared_rows=0
bridge_routing="0.000000"
bridge_jump="0.000000"
declare -A bridge_family_seen=()

BRIDGE_TSV="$TMP_DIR/family_result_bridge.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id content_summary_uri content_summary_hash result_artifact_uri result_artifact_hash baseline_artifact_uri baseline_artifact_hash dataset_uri dataset_hash run_manifest_uri run_manifest_hash evaluator_output_uri evaluator_output_hash result_authority_uri result_authority_hash publication_package_uri publication_package_hash source_content_bound result_artifact_bound baseline_bound dataset_bound result_authority_bound publication_bound independent_bridge_review real_bridge_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ad bridge column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ad bridge row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$BRIDGE_CSV" >"$BRIDGE_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id content_summary_uri content_summary_hash result_artifact_uri result_artifact_hash baseline_artifact_uri baseline_artifact_hash dataset_uri dataset_hash run_manifest_uri run_manifest_hash evaluator_output_uri evaluator_output_hash result_authority_uri result_authority_hash publication_package_uri publication_package_hash source_content_bound result_artifact_bound baseline_bound dataset_bound result_authority_bound publication_bound independent_bridge_review real_bridge_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((bridge_rows += 1))

  if [[ -n "${bridge_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  bridge_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${content_acquisition_id[$benchmark_family]:-}" ]]; then
    ((matched_source_content_family_rows += 1))
  fi
  if [[ -n "${content_acquisition_id[$benchmark_family]:-}" &&
        "$acquisition_id" == "${content_acquisition_id[$benchmark_family]}" ]]; then
    ((acquisition_id_match_rows += 1))
  fi
  if hash_matches_uri "$content_summary_uri" "$content_summary_hash"; then
    ((content_summary_hash_verified_rows += 1))
  fi

  for pair in \
    "$result_artifact_uri|$result_artifact_hash" \
    "$baseline_artifact_uri|$baseline_artifact_hash" \
    "$dataset_uri|$dataset_hash" \
    "$run_manifest_uri|$run_manifest_hash" \
    "$evaluator_output_uri|$evaluator_output_hash" \
    "$result_authority_uri|$result_authority_hash" \
    "$publication_package_uri|$publication_package_hash"; do
    ((required_result_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((result_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_result_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_result_uri_fields += 1))
    fi
  done

  [[ "$source_content_bound" == "1" ]] && ((source_content_bound_rows += 1))
  [[ "$result_artifact_bound" == "1" ]] && ((result_artifact_bound_rows += 1))
  [[ "$baseline_bound" == "1" ]] && ((baseline_bound_rows += 1))
  [[ "$dataset_bound" == "1" ]] && ((dataset_bound_rows += 1))
  [[ "$result_authority_bound" == "1" ]] && ((result_authority_bound_rows += 1))
  [[ "$publication_bound" == "1" ]] && ((publication_bound_rows += 1))
  [[ "$independent_bridge_review" == "1" ]] && ((independent_bridge_review_rows += 1))
  [[ "$real_bridge_declared" == "1" ]] && ((declared_real_bridge_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((non_fixture_declared_rows += 1))
  bridge_routing="$(awk -v a="$bridge_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  bridge_jump="$(awk -v a="$bridge_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$BRIDGE_TSV"

bridge_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${bridge_family_seen[$family]:-}" ]]; then
    ((bridge_family_coverage += 1))
  fi
done

expected_result_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * RESULT_HASH_FIELDS_PER_ROW))
family_result_bridge_review_ready=0
if [[ "$source_content_ready" == "1" &&
      "$content_family_expected_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$bridge_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$bridge_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_source_content_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$acquisition_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$content_summary_hash_verified_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_result_hash_fields" -eq "$expected_result_hash_fields" &&
      "$result_hash_attested_fields" -eq "$expected_result_hash_fields" &&
      "$nonlocal_result_uri_fields" -eq "$expected_result_hash_fields" &&
      "$local_result_uri_fields" -eq 0 &&
      "$source_content_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_artifact_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$baseline_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$dataset_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$publication_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_bridge_review_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$declared_real_bridge_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$bridge_routing" == "0.000000" &&
      "$bridge_jump" == "0.000000" ]]; then
  family_result_bridge_review_ready=1
fi

external_benchmark_result_bridge_ready="$family_result_bridge_review_ready"
real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$source_content_routing" -v b="$bridge_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$source_content_jump" -v b="$bridge_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-source-acquisition-content-not-ready"
if [[ "$source_content_ready" != "1" ]]; then
  action="external-benchmark-source-acquisition-content-not-ready"
elif [[ "$bridge_rows" -eq 0 ]]; then
  action="external-benchmark-family-result-bridge-missing"
elif [[ "$bridge_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$bridge_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-family-result-bridge-coverage-incomplete"
elif [[ "$matched_source_content_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$acquisition_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-family-result-bridge-acquisition-mismatch"
elif [[ "$content_summary_hash_verified_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-family-result-bridge-content-summary-hash-mismatch"
elif [[ "$required_result_hash_fields" -ne "$expected_result_hash_fields" ||
        "$result_hash_attested_fields" -ne "$expected_result_hash_fields" ]]; then
  action="external-benchmark-family-result-bridge-hash-attestation-missing"
elif [[ "$nonlocal_result_uri_fields" -ne "$expected_result_hash_fields" ||
        "$local_result_uri_fields" -ne 0 ]]; then
  action="external-benchmark-family-result-bridge-local-result-artifact-uri"
elif [[ "$source_content_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_artifact_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$baseline_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$dataset_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$result_authority_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$publication_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-family-result-bridge-binding-missing"
elif [[ "$independent_bridge_review_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-family-result-bridge-review-missing"
elif [[ "$declared_real_bridge_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-family-result-bridge-fixture-only"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-family-result-bridge-jump-guardrail-violated"
elif [[ "$family_result_bridge_review_ready" == "1" ]]; then
  action="external-benchmark-family-result-bridge-ready-await-independent-reproduction"
fi

{
  echo "benchmark_scope,bridge_source,source_content_ready,source_content_rows,source_content_expected_rows,source_content_family_rows,source_content_real_external,source_content_action,bridge_rows,expected_family_rows,duplicate_family_rows,matched_source_content_family_rows,acquisition_id_match_rows,content_summary_hash_verified_rows,required_result_hash_fields,result_hash_attested_fields,nonlocal_result_uri_fields,local_result_uri_fields,source_content_bound_rows,result_artifact_bound_rows,baseline_bound_rows,dataset_bound_rows,result_authority_bound_rows,publication_bound_rows,independent_bridge_review_rows,declared_real_bridge_rows,non_fixture_declared_rows,bridge_family_coverage,expected_external_families,family_result_bridge_review_ready,external_benchmark_result_bridge_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ad,%s,%d,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$BRIDGE_SOURCE" \
    "$source_content_ready" \
    "$source_content_rows" \
    "$source_content_expected_rows" \
    "$content_family_expected_rows" \
    "$source_content_real_external" \
    "$source_content_action" \
    "$bridge_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_source_content_family_rows" \
    "$acquisition_id_match_rows" \
    "$content_summary_hash_verified_rows" \
    "$required_result_hash_fields" \
    "$result_hash_attested_fields" \
    "$nonlocal_result_uri_fields" \
    "$local_result_uri_fields" \
    "$source_content_bound_rows" \
    "$result_artifact_bound_rows" \
    "$baseline_bound_rows" \
    "$dataset_bound_rows" \
    "$result_authority_bound_rows" \
    "$publication_bound_rows" \
    "$independent_bridge_review_rows" \
    "$declared_real_bridge_rows" \
    "$non_fixture_declared_rows" \
    "$bridge_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$family_result_bridge_review_ready" \
    "$external_benchmark_result_bridge_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-acquisition-content,%s,ready=%d rows=%d/%d family_rows=%d real=%d action=%s\n" \
    "$([[ "$source_content_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_content_ready" \
    "$source_content_rows" \
    "$source_content_expected_rows" \
    "$content_family_expected_rows" \
    "$source_content_real_external" \
    "$source_content_action"
  printf "family-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$bridge_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$bridge_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$bridge_rows" \
    "$expected_family_rows" \
    "$bridge_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "source-content-binding,%s,matched=%d acq=%d summary_hash=%d/%d\n" \
    "$([[ "$matched_source_content_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$acquisition_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$content_summary_hash_verified_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_source_content_family_rows" \
    "$acquisition_id_match_rows" \
    "$content_summary_hash_verified_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "result-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_result_hash_fields" -eq "$expected_result_hash_fields" && "$result_hash_attested_fields" -eq "$expected_result_hash_fields" ]] && echo pass || echo blocked)" \
    "$result_hash_attested_fields" \
    "$expected_result_hash_fields"
  printf "nonlocal-result-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$nonlocal_result_uri_fields" -eq "$expected_result_hash_fields" && "$local_result_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_result_uri_fields" \
    "$expected_result_hash_fields" \
    "$local_result_uri_fields"
  printf "bridge-bindings,%s,bound=%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$source_content_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_artifact_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$baseline_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$dataset_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_authority_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$publication_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$source_content_bound_rows" \
    "$result_artifact_bound_rows" \
    "$baseline_bound_rows" \
    "$dataset_bound_rows" \
    "$result_authority_bound_rows" \
    "$publication_bound_rows"
  printf "bridge-review,%s,review=%d real=%d non_fixture=%d\n" \
    "$([[ "$independent_bridge_review_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$declared_real_bridge_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$independent_bridge_review_rows" \
    "$declared_real_bridge_rows" \
    "$non_fixture_declared_rows"
  printf "external-result-bridge,%s,ready=%d action=%s\n" \
    "$([[ "$external_benchmark_result_bridge_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_result_bridge_ready" \
    "$action"
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
