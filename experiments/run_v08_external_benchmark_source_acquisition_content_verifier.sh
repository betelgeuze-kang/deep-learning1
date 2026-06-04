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

PREFIX="v08_external_benchmark_source_acquisition_content_verifier"
ACQUISITION_PREFIX="v08_external_benchmark_source_acquisition_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_acquisition_content_verifier_smoke"
  ACQUISITION_PREFIX="v08_external_benchmark_source_acquisition_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_acquisition_gate.sh" "${RUN_ARGS[@]}" >/dev/null

ACQUISITION_CSV="${V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV:-$RESULTS_DIR/${ACQUISITION_PREFIX}_acquisition.csv}"
ACQUISITION_SUMMARY_CSV="$RESULTS_DIR/${ACQUISITION_PREFIX}_summary.csv"
CONTENT_CSV="$RESULTS_DIR/${PREFIX}_content.csv"
CONTENT_SOURCE="pending-fixture"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

write_content_header() {
  echo "benchmark_family,acquisition_id,source_landing_uri,source_landing_cache_uri,source_landing_hash,dataset_artifact_uri,dataset_artifact_cache_uri,dataset_artifact_hash,benchmark_card_uri,benchmark_card_cache_uri,benchmark_card_hash,split_manifest_uri,split_manifest_cache_uri,split_manifest_hash,license_uri,license_cache_uri,license_hash,metric_spec_uri,metric_spec_cache_uri,metric_spec_hash,fetch_tool,content_hash_algorithm,fetch_manifest_ready,content_cache_ready,independent_content_review,real_content_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
}

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

is_present() {
  local value="$1"
  [[ "$value" != "" && "$value" != "pending" ]]
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

  if ! is_sha256 "$expected"; then
    return 1
  fi
  if ! path="$(uri_to_local_path "$uri")"; then
    return 1
  fi
  if [[ ! -f "$path" ]]; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

if [[ -n "${V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV:-}" ]]; then
  CONTENT_CSV="$V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV"
  CONTENT_SOURCE="provided-csv"
  if [[ ! -s "$CONTENT_CSV" ]]; then
    echo "V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  write_content_header >"$CONTENT_CSV"
fi

ACQUISITION_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families expected_acquisition_rows acquisition_rows external_benchmark_source_acquisition_review_ready external_benchmark_source_acquisition_ready real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-aa acquisition summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["expected_acquisition_rows"] + 0,
        $idx["acquisition_rows"] + 0,
        $idx["external_benchmark_source_acquisition_review_ready"] + 0,
        $idx["external_benchmark_source_acquisition_ready"] + 0,
        $idx["real_external_benchmark_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-aa acquisition summary row", 3)
    }
  ' "$ACQUISITION_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families expected_acquisition_rows acquisition_rows source_acquisition_review_ready source_acquisition_ready acquisition_real_verified acquisition_action acquisition_routing acquisition_jump <<<"$ACQUISITION_VALUES"

declare -A acq_id
declare -A acq_source_landing_uri
declare -A acq_source_landing_hash
declare -A acq_dataset_artifact_uri
declare -A acq_dataset_artifact_hash
declare -A acq_benchmark_card_uri
declare -A acq_benchmark_card_hash
declare -A acq_split_manifest_uri
declare -A acq_split_manifest_hash
declare -A acq_license_uri
declare -A acq_license_hash
declare -A acq_metric_spec_uri
declare -A acq_metric_spec_hash
declare -A acq_seen
acq_rows_seen=0
ACQUISITION_TSV="$TMP_DIR/source_acquisition.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id source_landing_uri source_landing_hash dataset_artifact_uri dataset_artifact_hash benchmark_card_uri benchmark_card_hash split_manifest_uri split_manifest_hash license_uri license_hash metric_spec_uri metric_spec_hash", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-aa acquisition column: " required[i], 4)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-aa acquisition row has wrong column count", 5)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$ACQUISITION_CSV" >"$ACQUISITION_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id source_landing_uri source_landing_hash dataset_artifact_uri dataset_artifact_hash benchmark_card_uri benchmark_card_hash split_manifest_uri split_manifest_hash license_uri license_hash metric_spec_uri metric_spec_hash; do
  ((acq_rows_seen += 1))
  if [[ -n "${acq_seen[$benchmark_family]:-}" ]]; then
    echo "duplicate v08-aa source acquisition family: $benchmark_family" >&2
    exit 6
  fi
  acq_seen["$benchmark_family"]=1
  acq_id["$benchmark_family"]="$acquisition_id"
  acq_source_landing_uri["$benchmark_family"]="$source_landing_uri"
  acq_source_landing_hash["$benchmark_family"]="$source_landing_hash"
  acq_dataset_artifact_uri["$benchmark_family"]="$dataset_artifact_uri"
  acq_dataset_artifact_hash["$benchmark_family"]="$dataset_artifact_hash"
  acq_benchmark_card_uri["$benchmark_family"]="$benchmark_card_uri"
  acq_benchmark_card_hash["$benchmark_family"]="$benchmark_card_hash"
  acq_split_manifest_uri["$benchmark_family"]="$split_manifest_uri"
  acq_split_manifest_hash["$benchmark_family"]="$split_manifest_hash"
  acq_license_uri["$benchmark_family"]="$license_uri"
  acq_license_hash["$benchmark_family"]="$license_hash"
  acq_metric_spec_uri["$benchmark_family"]="$metric_spec_uri"
  acq_metric_spec_hash["$benchmark_family"]="$metric_spec_hash"
done <"$ACQUISITION_TSV"

content_rows=0
matched_acquisition_rows=0
acquisition_id_match_rows=0
remote_uri_match_rows=0
hash_manifest_match_rows=0
required_content_fields=0
cache_uri_fields=0
content_hash_verified_fields=0
fetch_manifest_ready_rows=0
content_cache_ready_rows=0
independent_content_review_rows=0
declared_real_content_rows=0
non_fixture_declared_rows=0
content_routing="0.000000"
content_jump="0.000000"
CONTENT_TSV="$TMP_DIR/source_acquisition_content.tsv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_family acquisition_id source_landing_uri source_landing_cache_uri source_landing_hash dataset_artifact_uri dataset_artifact_cache_uri dataset_artifact_hash benchmark_card_uri benchmark_card_cache_uri benchmark_card_hash split_manifest_uri split_manifest_cache_uri split_manifest_hash license_uri license_cache_uri license_hash metric_spec_uri metric_spec_cache_uri metric_spec_hash fetch_tool content_hash_algorithm fetch_manifest_ready content_cache_ready independent_content_review real_content_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08-aa content verifier column: " required[i], 7)
    }
    next
  }
  {
    if (NF != header_fields) die("v08-aa content verifier row has wrong column count", 8)
    printf "%s", $idx["benchmark_family"]
    for (i = 2; i <= required_count; i++) {
      printf "\t%s", $idx[required[i]]
    }
    printf "\n"
  }
' "$CONTENT_CSV" >"$CONTENT_TSV"

while IFS=$'\t' read -r benchmark_family acquisition_id source_landing_uri source_landing_cache_uri source_landing_hash dataset_artifact_uri dataset_artifact_cache_uri dataset_artifact_hash benchmark_card_uri benchmark_card_cache_uri benchmark_card_hash split_manifest_uri split_manifest_cache_uri split_manifest_hash license_uri license_cache_uri license_hash metric_spec_uri metric_spec_cache_uri metric_spec_hash fetch_tool content_hash_algorithm fetch_manifest_ready content_cache_ready independent_content_review real_content_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((content_rows += 1))

  if [[ -n "${acq_seen[$benchmark_family]:-}" ]]; then
    ((matched_acquisition_rows += 1))
  fi
  if [[ "${acq_id[$benchmark_family]:-}" == "$acquisition_id" ]]; then
    ((acquisition_id_match_rows += 1))
  fi
  if [[ "${acq_source_landing_uri[$benchmark_family]:-}" == "$source_landing_uri" &&
        "${acq_dataset_artifact_uri[$benchmark_family]:-}" == "$dataset_artifact_uri" &&
        "${acq_benchmark_card_uri[$benchmark_family]:-}" == "$benchmark_card_uri" &&
        "${acq_split_manifest_uri[$benchmark_family]:-}" == "$split_manifest_uri" &&
        "${acq_license_uri[$benchmark_family]:-}" == "$license_uri" &&
        "${acq_metric_spec_uri[$benchmark_family]:-}" == "$metric_spec_uri" ]]; then
    ((remote_uri_match_rows += 1))
  fi
  if [[ "${acq_source_landing_hash[$benchmark_family]:-}" == "$source_landing_hash" &&
        "${acq_dataset_artifact_hash[$benchmark_family]:-}" == "$dataset_artifact_hash" &&
        "${acq_benchmark_card_hash[$benchmark_family]:-}" == "$benchmark_card_hash" &&
        "${acq_split_manifest_hash[$benchmark_family]:-}" == "$split_manifest_hash" &&
        "${acq_license_hash[$benchmark_family]:-}" == "$license_hash" &&
        "${acq_metric_spec_hash[$benchmark_family]:-}" == "$metric_spec_hash" ]]; then
    ((hash_manifest_match_rows += 1))
  fi

  for uri in "$source_landing_cache_uri" "$dataset_artifact_cache_uri" "$benchmark_card_cache_uri" "$split_manifest_cache_uri" "$license_cache_uri" "$metric_spec_cache_uri"; do
    ((required_content_fields += 1))
    if uri_to_local_path "$uri" >/dev/null; then
      ((cache_uri_fields += 1))
    fi
  done

  if hash_matches_uri "$source_landing_cache_uri" "$source_landing_hash"; then
    ((content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$dataset_artifact_cache_uri" "$dataset_artifact_hash"; then
    ((content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$benchmark_card_cache_uri" "$benchmark_card_hash"; then
    ((content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$split_manifest_cache_uri" "$split_manifest_hash"; then
    ((content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$license_cache_uri" "$license_hash"; then
    ((content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$metric_spec_cache_uri" "$metric_spec_hash"; then
    ((content_hash_verified_fields += 1))
  fi

  if is_present "$fetch_tool" &&
      is_present "$content_hash_algorithm" &&
      [[ "$content_hash_algorithm" == "sha256" &&
         "$fetch_tool" != "local" &&
         "$fetch_tool" != "fixture" &&
         "$fetch_tool" != "pending" &&
         "$fetch_manifest_ready" == "1" ]]; then
    ((fetch_manifest_ready_rows += 1))
  fi
  if [[ "$content_cache_ready" == "1" ]]; then
    ((content_cache_ready_rows += 1))
  fi
  if [[ "$independent_content_review" == "1" ]]; then
    ((independent_content_review_rows += 1))
  fi
  if [[ "$real_content_declared" == "1" ]]; then
    ((declared_real_content_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi
  content_routing="$(awk -v a="$content_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  content_jump="$(awk -v a="$content_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$CONTENT_TSV"

expected_content_rows="$expected_acquisition_rows"
expected_content_fields=$((expected_content_rows * 6))
external_benchmark_source_acquisition_content_ready=0
if [[ "$source_acquisition_ready" == "1" &&
      "$content_rows" -eq "$expected_content_rows" &&
      "$matched_acquisition_rows" -eq "$expected_content_rows" &&
      "$acquisition_id_match_rows" -eq "$expected_content_rows" &&
      "$remote_uri_match_rows" -eq "$expected_content_rows" &&
      "$hash_manifest_match_rows" -eq "$expected_content_rows" &&
      "$required_content_fields" -eq "$expected_content_fields" &&
      "$cache_uri_fields" -eq "$expected_content_fields" &&
      "$content_hash_verified_fields" -eq "$expected_content_fields" &&
      "$fetch_manifest_ready_rows" -eq "$expected_content_rows" &&
      "$content_cache_ready_rows" -eq "$expected_content_rows" &&
      "$independent_content_review_rows" -eq "$expected_content_rows" &&
      "$declared_real_content_rows" -eq "$expected_content_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_content_rows" &&
      "$content_routing" == "0.000000" &&
      "$content_jump" == "0.000000" ]]; then
  external_benchmark_source_acquisition_content_ready=1
fi

real_external_benchmark_verified=0
action="external-benchmark-source-acquisition-not-ready"
if [[ "$source_acquisition_ready" != "1" ]]; then
  action="external-benchmark-source-acquisition-not-ready"
elif [[ "$content_rows" -eq 0 ]]; then
  action="external-benchmark-source-acquisition-content-missing"
elif [[ "$content_rows" -ne "$expected_content_rows" ||
        "$matched_acquisition_rows" -ne "$expected_content_rows" ]]; then
  action="external-benchmark-source-acquisition-content-row-mismatch"
elif [[ "$acquisition_id_match_rows" -ne "$expected_content_rows" ]]; then
  action="external-benchmark-source-acquisition-content-id-mismatch"
elif [[ "$remote_uri_match_rows" -ne "$expected_content_rows" ]]; then
  action="external-benchmark-source-acquisition-content-uri-mismatch"
elif [[ "$hash_manifest_match_rows" -ne "$expected_content_rows" ]]; then
  action="external-benchmark-source-acquisition-content-hash-manifest-mismatch"
elif [[ "$cache_uri_fields" -ne "$expected_content_fields" ]]; then
  action="external-benchmark-source-acquisition-content-cache-missing"
elif [[ "$content_hash_verified_fields" -ne "$expected_content_fields" ]]; then
  action="external-benchmark-source-acquisition-content-cache-hash-mismatch"
elif [[ "$fetch_manifest_ready_rows" -ne "$expected_content_rows" ||
        "$content_cache_ready_rows" -ne "$expected_content_rows" ]]; then
  action="external-benchmark-source-acquisition-content-cache-not-ready"
elif [[ "$independent_content_review_rows" -ne "$expected_content_rows" ]]; then
  action="external-benchmark-source-acquisition-content-review-missing"
elif [[ "$declared_real_content_rows" -ne "$expected_content_rows" ||
        "$non_fixture_declared_rows" -ne "$expected_content_rows" ]]; then
  action="external-benchmark-source-acquisition-content-fixture-only"
elif [[ "$external_benchmark_source_acquisition_content_ready" == "1" ]]; then
  action="external-benchmark-source-acquisition-content-ready-await-import"
fi

{
  echo "benchmark_scope,benchmark_families,source_acquisition_review_ready,source_acquisition_ready,source_acquisition_content_source,expected_content_rows,content_rows,matched_acquisition_rows,acquisition_id_match_rows,remote_uri_match_rows,hash_manifest_match_rows,required_content_fields,cache_uri_fields,content_hash_verified_fields,fetch_manifest_ready_rows,content_cache_ready_rows,independent_content_review_rows,declared_real_content_rows,non_fixture_declared_rows,external_benchmark_source_acquisition_content_ready,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08aa,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$source_acquisition_review_ready" \
    "$source_acquisition_ready" \
    "$CONTENT_SOURCE" \
    "$expected_content_rows" \
    "$content_rows" \
    "$matched_acquisition_rows" \
    "$acquisition_id_match_rows" \
    "$remote_uri_match_rows" \
    "$hash_manifest_match_rows" \
    "$required_content_fields" \
    "$cache_uri_fields" \
    "$content_hash_verified_fields" \
    "$fetch_manifest_ready_rows" \
    "$content_cache_ready_rows" \
    "$independent_content_review_rows" \
    "$declared_real_content_rows" \
    "$non_fixture_declared_rows" \
    "$external_benchmark_source_acquisition_content_ready" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$content_routing" \
    "$content_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-acquisition,%s,review_ready=%d acquisition_ready=%d acquisition_rows=%d/%d\n" \
    "$([[ "$source_acquisition_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_acquisition_review_ready" \
    "$source_acquisition_ready" \
    "$acquisition_rows" \
    "$expected_acquisition_rows"
  printf "content-manifest,%s,rows=%d/%d matched=%d/%d id=%d/%d uri=%d/%d hash=%d/%d\n" \
    "$([[ "$content_rows" -eq "$expected_content_rows" && "$matched_acquisition_rows" -eq "$expected_content_rows" && "$acquisition_id_match_rows" -eq "$expected_content_rows" && "$remote_uri_match_rows" -eq "$expected_content_rows" && "$hash_manifest_match_rows" -eq "$expected_content_rows" && "$expected_content_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$content_rows" "$expected_content_rows" \
    "$matched_acquisition_rows" "$expected_content_rows" \
    "$acquisition_id_match_rows" "$expected_content_rows" \
    "$remote_uri_match_rows" "$expected_content_rows" \
    "$hash_manifest_match_rows" "$expected_content_rows"
  printf "content-cache,%s,cache_uri=%d/%d hash_verified=%d/%d\n" \
    "$([[ "$cache_uri_fields" -eq "$expected_content_fields" && "$content_hash_verified_fields" -eq "$expected_content_fields" && "$expected_content_fields" -gt 0 ]] && echo pass || echo blocked)" \
    "$cache_uri_fields" "$expected_content_fields" \
    "$content_hash_verified_fields" "$expected_content_fields"
  printf "content-review,%s,fetch=%d/%d cache=%d/%d review=%d/%d\n" \
    "$([[ "$fetch_manifest_ready_rows" -eq "$expected_content_rows" && "$content_cache_ready_rows" -eq "$expected_content_rows" && "$independent_content_review_rows" -eq "$expected_content_rows" && "$expected_content_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$fetch_manifest_ready_rows" "$expected_content_rows" \
    "$content_cache_ready_rows" "$expected_content_rows" \
    "$independent_content_review_rows" "$expected_content_rows"
  printf "content-declaration,%s,real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$declared_real_content_rows" -eq "$expected_content_rows" && "$non_fixture_declared_rows" -eq "$expected_content_rows" && "$expected_content_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$declared_real_content_rows" "$expected_content_rows" \
    "$non_fixture_declared_rows" "$expected_content_rows"
  printf "source-acquisition-content,%s,content_ready=%d real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$external_benchmark_source_acquisition_content_ready" == "1" ]] && echo pass || echo blocked)" \
    "$external_benchmark_source_acquisition_content_ready" \
    "$real_external_benchmark_verified" \
    "$action"
  printf "real-external-benchmark-verification,%s,real_external_benchmark_verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "content: $CONTENT_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
