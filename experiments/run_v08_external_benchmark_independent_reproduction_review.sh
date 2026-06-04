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

PREFIX="v08_external_benchmark_independent_reproduction_review"
AD_PREFIX="v08_external_benchmark_family_result_bridge"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_independent_reproduction_review_smoke"
  AD_PREFIX="v08_external_benchmark_family_result_bridge_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v08_external_benchmark_independent_reproduction_review_full"
  AD_PREFIX="v08_external_benchmark_family_result_bridge_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_family_result_bridge.sh" "${RUN_ARGS[@]}" >/dev/null

AD_SUMMARY_CSV="$RESULTS_DIR/${AD_PREFIX}_summary.csv"
AD_BRIDGE_CSV="${V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV:-$RESULTS_DIR/${AD_PREFIX}_bridge.csv}"
REPRODUCTION_CSV="$RESULTS_DIR/${PREFIX}_reproduction.csv"
REPRODUCTION_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPECTED_FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
EXPECTED_EXTERNAL_FAMILIES="${#EXPECTED_FAMILIES[@]}"
REPRODUCTION_HASH_FIELDS_PER_ROW=7

write_reproduction_header() {
  echo "benchmark_family,acquisition_id,reproduction_id,result_bridge_summary_uri,result_bridge_summary_hash,result_artifact_uri,result_artifact_hash,reproduction_report_uri,reproduction_report_hash,reproduction_run_log_uri,reproduction_run_log_hash,reviewer_identity_uri,reviewer_identity_hash,conflict_disclosure_uri,conflict_disclosure_hash,environment_manifest_uri,environment_manifest_hash,metric_recompute_uri,metric_recompute_hash,result_bridge_bound,reproduction_report_bound,run_log_bound,reviewer_identity_bound,conflict_disclosure_bound,environment_bound,metric_recompute_bound,result_match_declared,metric_match_declared,independent_runner_declared,non_author_conflict_clear,official_review_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
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
        print "missing v08-ae column: " column > "/dev/stderr"
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
        print "missing v08-ae summary row in " FILENAME > "/dev/stderr"
        exit 12
      }
    }
  ' "$file"
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV:-}" ]]; then
  REPRODUCTION_CSV="$V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV"
  REPRODUCTION_SOURCE="provided-csv"
  if [[ ! -s "$REPRODUCTION_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_reproduction_header >"$REPRODUCTION_CSV"
fi

family_result_bridge_review_ready="$(csv_value "$AD_SUMMARY_CSV" "family_result_bridge_review_ready")"
external_benchmark_result_bridge_ready="$(csv_value "$AD_SUMMARY_CSV" "external_benchmark_result_bridge_ready")"
result_bridge_rows="$(csv_value "$AD_SUMMARY_CSV" "bridge_rows")"
result_bridge_expected_families="$(csv_value "$AD_SUMMARY_CSV" "expected_external_families")"
result_bridge_real_external="$(csv_value "$AD_SUMMARY_CSV" "real_external_benchmark_verified")"
result_bridge_action="$(csv_value "$AD_SUMMARY_CSV" "action")"
result_bridge_routing="$(csv_value "$AD_SUMMARY_CSV" "routing_trigger_rate")"
result_bridge_jump="$(csv_value "$AD_SUMMARY_CSV" "active_jump_rate")"

declare -A bridge_acquisition_id=()
declare -A bridge_result_artifact_uri=()
declare -A bridge_result_artifact_hash=()
declare -A bridge_family_seen=()
bridge_family_rows=0
AD_BRIDGE_TSV="$TMP_DIR/family_result_bridge.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id result_artifact_uri result_artifact_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ae bridge column: " required[i], 13)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ae bridge row has wrong column count", 14)
    printf "%s\t%s\t%s\t%s\n",
      $idx["benchmark_family"],
      $idx["acquisition_id"],
      $idx["result_artifact_uri"],
      $idx["result_artifact_hash"]
  }
' "$AD_BRIDGE_CSV" >"$AD_BRIDGE_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id result_artifact_uri result_artifact_hash; do
  bridge_acquisition_id["$benchmark_family"]="$acquisition_id"
  bridge_result_artifact_uri["$benchmark_family"]="$result_artifact_uri"
  bridge_result_artifact_hash["$benchmark_family"]="$result_artifact_hash"
  bridge_family_seen["$benchmark_family"]=1
done <"$AD_BRIDGE_TSV"

for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${bridge_family_seen[$family]:-}" ]]; then
    ((bridge_family_rows += 1))
  fi
done

reproduction_rows=0
expected_family_rows=0
duplicate_family_rows=0
matched_bridge_family_rows=0
acquisition_id_match_rows=0
result_artifact_match_rows=0
result_bridge_summary_hash_verified_rows=0
required_reproduction_hash_fields=0
reproduction_hash_attested_fields=0
nonlocal_reproduction_uri_fields=0
local_reproduction_uri_fields=0
result_bridge_bound_rows=0
reproduction_report_bound_rows=0
run_log_bound_rows=0
reviewer_identity_bound_rows=0
conflict_disclosure_bound_rows=0
environment_bound_rows=0
metric_recompute_bound_rows=0
result_match_declared_rows=0
metric_match_declared_rows=0
independent_runner_declared_rows=0
non_author_conflict_clear_rows=0
official_review_declared_rows=0
non_fixture_declared_rows=0
reproduction_routing="0.000000"
reproduction_jump="0.000000"
declare -A reproduction_family_seen=()

REPRODUCTION_TSV="$TMP_DIR/independent_reproduction.tsv"
awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id reproduction_id result_bridge_summary_uri result_bridge_summary_hash result_artifact_uri result_artifact_hash reproduction_report_uri reproduction_report_hash reproduction_run_log_uri reproduction_run_log_hash reviewer_identity_uri reviewer_identity_hash conflict_disclosure_uri conflict_disclosure_hash environment_manifest_uri environment_manifest_hash metric_recompute_uri metric_recompute_hash result_bridge_bound reproduction_report_bound run_log_bound reviewer_identity_bound conflict_disclosure_bound environment_bound metric_recompute_bound result_match_declared metric_match_declared independent_runner_declared non_author_conflict_clear official_review_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-ae reproduction column: " required[i], 15)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-ae reproduction row has wrong column count", 16)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$REPRODUCTION_CSV" >"$REPRODUCTION_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id reproduction_id result_bridge_summary_uri result_bridge_summary_hash result_artifact_uri result_artifact_hash reproduction_report_uri reproduction_report_hash reproduction_run_log_uri reproduction_run_log_hash reviewer_identity_uri reviewer_identity_hash conflict_disclosure_uri conflict_disclosure_hash environment_manifest_uri environment_manifest_hash metric_recompute_uri metric_recompute_hash result_bridge_bound reproduction_report_bound run_log_bound reviewer_identity_bound conflict_disclosure_bound environment_bound metric_recompute_bound result_match_declared metric_match_declared independent_runner_declared non_author_conflict_clear official_review_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((reproduction_rows += 1))

  if [[ -n "${reproduction_family_seen[$benchmark_family]:-}" ]]; then
    ((duplicate_family_rows += 1))
  fi
  reproduction_family_seen["$benchmark_family"]=1

  if is_expected_family "$benchmark_family"; then
    ((expected_family_rows += 1))
  fi
  if [[ -n "${bridge_acquisition_id[$benchmark_family]:-}" ]]; then
    ((matched_bridge_family_rows += 1))
  fi
  if [[ -n "${bridge_acquisition_id[$benchmark_family]:-}" &&
        "$acquisition_id" == "${bridge_acquisition_id[$benchmark_family]}" ]]; then
    ((acquisition_id_match_rows += 1))
  fi
  if [[ -n "${bridge_result_artifact_uri[$benchmark_family]:-}" &&
        "$result_artifact_uri" == "${bridge_result_artifact_uri[$benchmark_family]}" &&
        "$result_artifact_hash" == "${bridge_result_artifact_hash[$benchmark_family]}" ]]; then
    ((result_artifact_match_rows += 1))
  fi
  if hash_matches_uri "$result_bridge_summary_uri" "$result_bridge_summary_hash"; then
    ((result_bridge_summary_hash_verified_rows += 1))
  fi

  for pair in \
    "$result_artifact_uri|$result_artifact_hash" \
    "$reproduction_report_uri|$reproduction_report_hash" \
    "$reproduction_run_log_uri|$reproduction_run_log_hash" \
    "$reviewer_identity_uri|$reviewer_identity_hash" \
    "$conflict_disclosure_uri|$conflict_disclosure_hash" \
    "$environment_manifest_uri|$environment_manifest_hash" \
    "$metric_recompute_uri|$metric_recompute_hash"; do
    ((required_reproduction_hash_fields += 1))
    uri="${pair%%|*}"
    hash="${pair#*|}"
    if is_sha256 "$hash"; then
      ((reproduction_hash_attested_fields += 1))
    fi
    if is_https_uri "$uri"; then
      ((nonlocal_reproduction_uri_fields += 1))
    fi
    if uri_to_local_path "$uri" >/dev/null; then
      ((local_reproduction_uri_fields += 1))
    fi
  done

  [[ "$result_bridge_bound" == "1" ]] && ((result_bridge_bound_rows += 1))
  [[ "$reproduction_report_bound" == "1" ]] && ((reproduction_report_bound_rows += 1))
  [[ "$run_log_bound" == "1" ]] && ((run_log_bound_rows += 1))
  [[ "$reviewer_identity_bound" == "1" ]] && ((reviewer_identity_bound_rows += 1))
  [[ "$conflict_disclosure_bound" == "1" ]] && ((conflict_disclosure_bound_rows += 1))
  [[ "$environment_bound" == "1" ]] && ((environment_bound_rows += 1))
  [[ "$metric_recompute_bound" == "1" ]] && ((metric_recompute_bound_rows += 1))
  [[ "$result_match_declared" == "1" ]] && ((result_match_declared_rows += 1))
  [[ "$metric_match_declared" == "1" ]] && ((metric_match_declared_rows += 1))
  [[ "$independent_runner_declared" == "1" ]] && ((independent_runner_declared_rows += 1))
  [[ "$non_author_conflict_clear" == "1" ]] && ((non_author_conflict_clear_rows += 1))
  [[ "$official_review_declared" == "1" ]] && ((official_review_declared_rows += 1))
  [[ "$fixture_or_synthetic_declared" == "0" ]] && ((non_fixture_declared_rows += 1))
  reproduction_routing="$(awk -v a="$reproduction_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  reproduction_jump="$(awk -v a="$reproduction_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$REPRODUCTION_TSV"

reproduction_family_coverage=0
for family in "${EXPECTED_FAMILIES[@]}"; do
  if [[ -n "${reproduction_family_seen[$family]:-}" ]]; then
    ((reproduction_family_coverage += 1))
  fi
done

expected_reproduction_hash_fields=$((EXPECTED_EXTERNAL_FAMILIES * REPRODUCTION_HASH_FIELDS_PER_ROW))
independent_reproduction_review_ready=0
if [[ "$family_result_bridge_review_ready" == "1" &&
      "$external_benchmark_result_bridge_ready" == "1" &&
      "$bridge_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$duplicate_family_rows" -eq 0 &&
      "$matched_bridge_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$acquisition_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_artifact_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_bridge_summary_hash_verified_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$required_reproduction_hash_fields" -eq "$expected_reproduction_hash_fields" &&
      "$reproduction_hash_attested_fields" -eq "$expected_reproduction_hash_fields" &&
      "$nonlocal_reproduction_uri_fields" -eq "$expected_reproduction_hash_fields" &&
      "$local_reproduction_uri_fields" -eq 0 &&
      "$result_bridge_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$run_log_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reviewer_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$conflict_disclosure_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$environment_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_recompute_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$result_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$metric_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$independent_runner_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_author_conflict_clear_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$official_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" &&
      "$reproduction_routing" == "0.000000" &&
      "$reproduction_jump" == "0.000000" ]]; then
  independent_reproduction_review_ready=1
fi

real_external_benchmark_verified=0
routing_trigger_rate="$(awk -v a="$result_bridge_routing" -v b="$reproduction_routing" 'BEGIN { printf "%.6f", a + b }')"
active_jump_rate="$(awk -v a="$result_bridge_jump" -v b="$reproduction_jump" 'BEGIN { printf "%.6f", a + b }')"

action="external-benchmark-family-result-bridge-not-ready"
if [[ "$family_result_bridge_review_ready" != "1" ||
      "$external_benchmark_result_bridge_ready" != "1" ]]; then
  action="external-benchmark-family-result-bridge-not-ready"
elif [[ "$reproduction_rows" -eq 0 ]]; then
  action="external-benchmark-independent-reproduction-missing"
elif [[ "$reproduction_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$expected_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_family_coverage" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$duplicate_family_rows" -ne 0 ]]; then
  action="external-benchmark-independent-reproduction-coverage-incomplete"
elif [[ "$matched_bridge_family_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$acquisition_id_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-reproduction-acquisition-mismatch"
elif [[ "$result_artifact_match_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-reproduction-result-artifact-mismatch"
elif [[ "$result_bridge_summary_hash_verified_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-reproduction-summary-hash-mismatch"
elif [[ "$required_reproduction_hash_fields" -ne "$expected_reproduction_hash_fields" ||
        "$reproduction_hash_attested_fields" -ne "$expected_reproduction_hash_fields" ]]; then
  action="external-benchmark-independent-reproduction-hash-attestation-missing"
elif [[ "$nonlocal_reproduction_uri_fields" -ne "$expected_reproduction_hash_fields" ||
        "$local_reproduction_uri_fields" -ne 0 ]]; then
  action="external-benchmark-independent-reproduction-local-artifact-uri"
elif [[ "$result_bridge_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reproduction_report_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$run_log_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$reviewer_identity_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$conflict_disclosure_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$environment_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$metric_recompute_bound_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-reproduction-binding-missing"
elif [[ "$result_match_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$metric_match_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$independent_runner_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$non_author_conflict_clear_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ||
        "$official_review_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-reproduction-review-missing"
elif [[ "$non_fixture_declared_rows" -ne "$EXPECTED_EXTERNAL_FAMILIES" ]]; then
  action="external-benchmark-independent-reproduction-fixture-only"
elif [[ "$routing_trigger_rate" != "0.000000" ||
        "$active_jump_rate" != "0.000000" ]]; then
  action="external-benchmark-independent-reproduction-jump-guardrail-violated"
elif [[ "$independent_reproduction_review_ready" == "1" ]]; then
  action="external-benchmark-independent-reproduction-ready-await-official-release-evidence"
fi

{
  echo "benchmark_scope,reproduction_source,family_result_bridge_review_ready,external_benchmark_result_bridge_ready,result_bridge_rows,result_bridge_expected_families,result_bridge_real_external,result_bridge_action,bridge_family_rows,reproduction_rows,expected_family_rows,duplicate_family_rows,matched_bridge_family_rows,acquisition_id_match_rows,result_artifact_match_rows,result_bridge_summary_hash_verified_rows,required_reproduction_hash_fields,reproduction_hash_attested_fields,nonlocal_reproduction_uri_fields,local_reproduction_uri_fields,result_bridge_bound_rows,reproduction_report_bound_rows,run_log_bound_rows,reviewer_identity_bound_rows,conflict_disclosure_bound_rows,environment_bound_rows,metric_recompute_bound_rows,result_match_declared_rows,metric_match_declared_rows,independent_runner_declared_rows,non_author_conflict_clear_rows,official_review_declared_rows,non_fixture_declared_rows,reproduction_family_coverage,expected_external_families,independent_reproduction_review_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08ae,%s,%d,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$REPRODUCTION_SOURCE" \
    "$family_result_bridge_review_ready" \
    "$external_benchmark_result_bridge_ready" \
    "$result_bridge_rows" \
    "$result_bridge_expected_families" \
    "$result_bridge_real_external" \
    "$result_bridge_action" \
    "$bridge_family_rows" \
    "$reproduction_rows" \
    "$expected_family_rows" \
    "$duplicate_family_rows" \
    "$matched_bridge_family_rows" \
    "$acquisition_id_match_rows" \
    "$result_artifact_match_rows" \
    "$result_bridge_summary_hash_verified_rows" \
    "$required_reproduction_hash_fields" \
    "$reproduction_hash_attested_fields" \
    "$nonlocal_reproduction_uri_fields" \
    "$local_reproduction_uri_fields" \
    "$result_bridge_bound_rows" \
    "$reproduction_report_bound_rows" \
    "$run_log_bound_rows" \
    "$reviewer_identity_bound_rows" \
    "$conflict_disclosure_bound_rows" \
    "$environment_bound_rows" \
    "$metric_recompute_bound_rows" \
    "$result_match_declared_rows" \
    "$metric_match_declared_rows" \
    "$independent_runner_declared_rows" \
    "$non_author_conflict_clear_rows" \
    "$official_review_declared_rows" \
    "$non_fixture_declared_rows" \
    "$reproduction_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$independent_reproduction_review_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "family-result-bridge,%s,bridge_ready=%d external_bridge=%d rows=%d/%d real=%d action=%s\n" \
    "$([[ "$family_result_bridge_review_ready" == "1" && "$external_benchmark_result_bridge_ready" == "1" ]] && echo pass || echo blocked)" \
    "$family_result_bridge_review_ready" \
    "$external_benchmark_result_bridge_ready" \
    "$result_bridge_rows" \
    "$result_bridge_expected_families" \
    "$result_bridge_real_external" \
    "$result_bridge_action"
  printf "reproduction-coverage,%s,rows=%d expected_rows=%d coverage=%d/%d duplicates=%d\n" \
    "$([[ "$reproduction_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$expected_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_family_coverage" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$duplicate_family_rows" -eq 0 ]] && echo pass || echo blocked)" \
    "$reproduction_rows" \
    "$expected_family_rows" \
    "$reproduction_family_coverage" \
    "$EXPECTED_EXTERNAL_FAMILIES" \
    "$duplicate_family_rows"
  printf "bridge-binding,%s,matched=%d acq=%d result_artifact=%d summary_hash=%d/%d\n" \
    "$([[ "$matched_bridge_family_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$acquisition_id_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_artifact_match_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$result_bridge_summary_hash_verified_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$matched_bridge_family_rows" \
    "$acquisition_id_match_rows" \
    "$result_artifact_match_rows" \
    "$result_bridge_summary_hash_verified_rows" \
    "$EXPECTED_EXTERNAL_FAMILIES"
  printf "reproduction-hash-attestation,%s,hashes=%d/%d\n" \
    "$([[ "$required_reproduction_hash_fields" -eq "$expected_reproduction_hash_fields" && "$reproduction_hash_attested_fields" -eq "$expected_reproduction_hash_fields" ]] && echo pass || echo blocked)" \
    "$reproduction_hash_attested_fields" \
    "$expected_reproduction_hash_fields"
  printf "nonlocal-reproduction-artifacts,%s,https=%d/%d local=%d\n" \
    "$([[ "$nonlocal_reproduction_uri_fields" -eq "$expected_reproduction_hash_fields" && "$local_reproduction_uri_fields" -eq 0 ]] && echo pass || echo blocked)" \
    "$nonlocal_reproduction_uri_fields" \
    "$expected_reproduction_hash_fields" \
    "$local_reproduction_uri_fields"
  printf "reproduction-bindings,%s,bound=%d/%d/%d/%d/%d/%d/%d\n" \
    "$([[ "$result_bridge_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reproduction_report_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$run_log_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$reviewer_identity_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$conflict_disclosure_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$environment_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$metric_recompute_bound_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$result_bridge_bound_rows" \
    "$reproduction_report_bound_rows" \
    "$run_log_bound_rows" \
    "$reviewer_identity_bound_rows" \
    "$conflict_disclosure_bound_rows" \
    "$environment_bound_rows" \
    "$metric_recompute_bound_rows"
  printf "reproduction-review,%s,result=%d metric=%d runner=%d conflict=%d official=%d non_fixture=%d\n" \
    "$([[ "$result_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$metric_match_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$independent_runner_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_author_conflict_clear_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$official_review_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" && "$non_fixture_declared_rows" -eq "$EXPECTED_EXTERNAL_FAMILIES" ]] && echo pass || echo blocked)" \
    "$result_match_declared_rows" \
    "$metric_match_declared_rows" \
    "$independent_runner_declared_rows" \
    "$non_author_conflict_clear_rows" \
    "$official_review_declared_rows" \
    "$non_fixture_declared_rows"
  printf "independent-reproduction,%s,ready=%d action=%s\n" \
    "$([[ "$independent_reproduction_review_ready" == "1" ]] && echo pass || echo blocked)" \
    "$independent_reproduction_review_ready" \
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

echo "reproduction: $REPRODUCTION_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
