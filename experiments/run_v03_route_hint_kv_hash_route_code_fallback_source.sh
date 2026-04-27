#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" --target dmv02 -j

KEY_COUNT=128
CORRUPT_RATE_SMOKE=0.25
CONFIDENCE_THRESHOLD=0.75

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_source_smoke"
  EPOCHS=10
else
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_source"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_corrupt_preserve_correct,route_corrupt_candidate_rate,route_fallback_source,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_candidate_corrupt_rate,route_primary_recall,route_primary_lowconf_rate,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_abstain_rate,route_lowconf_query_rate,route_highconf_query_rate,route_lowconf_qacc,route_highconf_qacc,route_lowconf_candidate_recall,route_highconf_candidate_recall,route_lowconf_top1,route_highconf_top1\n' >"$SUMMARY_CSV"

value_for_index() {
  local index="$1"
  local ascii=$((65 + (index % 26)))
  printf "\\$(printf '%03o' "$ascii")"
}

make_fixture() {
  local path="$1"
  local key_count="$2"

  : >"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((14000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((14000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

last5_mean() {
  local csv_path="$1"
  local column="$2"
  awk -F, -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    { rows[++row_count] = $0 }
    END {
      start = (row_count > 5 ? row_count - 4 : 1)
      count = row_count - start + 1
      for (r = start; r <= row_count; r++) {
        split(rows[r], row, FS)
        sum += row[idx[column]] + 0
      }
      printf "%.6f", sum / count
    }
  ' "$csv_path"
}

run_dmv02() {
  local fixture="$1"
  local csv_path="$2"
  local fallback_source="$3"
  local preserve_correct="$4"
  local corrupt_rate="$5"
  local n

  n="$(wc -c <"$fixture")"

  echo "route-code fallback source: ${fallback_source} (pc=${preserve_correct}, cr=${corrupt_rate})" >&2
  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch 20 \
    --seed 1 \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count 30 \
    --route-mode hint-kv-hash \
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --K-route 4 \
    --route-hash-bits 16 \
    --route-hint-agg confidence-gated \
    --route-candidate-score recency \
    --route-confidence-threshold "$CONFIDENCE_THRESHOLD" \
    --route-lowconf-policy aggregate \
    --route-lowconf-agg vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence agreement \
    --route-fallback-source "$fallback_source" \
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-confidence-power 1.0 \
    --route-min-confidence 0.0 \
    --route-strength-confidence weight \
    --route-corrupt-candidate-rate "$corrupt_rate" \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct "$preserve_correct" \
    --csv "$csv_path"
}

get_clean_reference() {
  local fallback_source="$1"
  local cache_file="$TMP_DIR/clean_reference_${fallback_source}.qacc"

  if [[ ! -f "$cache_file" ]]; then
    local fixture="$TMP_DIR/clean_reference_${fallback_source}.txt"
    local csv_path="$TMP_DIR/clean_reference_${fallback_source}.csv"
    make_fixture "$fixture" "$KEY_COUNT"
    run_dmv02 "$fixture" "$csv_path" "$fallback_source" 1 0.0
    last5_mean "$csv_path" fixture_query_byte_acc >"$cache_file"
  fi

  cat "$cache_file"
}

append_summary() {
  local scenario="$1"
  local preserve_correct="$2"
  local corrupt_rate="$3"
  local fallback_source="$4"
  local clean_reference="$5"
  local csv_path="$6"

  awk -F, \
    -v scenario="$scenario" \
    -v preserve_correct="$preserve_correct" \
    -v corrupt_rate="$corrupt_rate" \
    -v fallback_source="$fallback_source" \
    -v clean_reference="$clean_reference" '
    BEGIN {
      split("fixture_query_byte_acc route_candidate_corrupt_rate route_primary_recall route_primary_lowconf_rate route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_abstain_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      for (n = 1; n <= length(names); n++) {
        if (!(names[n] in idx)) {
          printf "missing column: %s in %s\n", names[n], FILENAME > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    { rows[++row_count] = $0 }
    END {
      start = (row_count > 5 ? row_count - 4 : 1)
      count = row_count - start + 1
      for (r = start; r <= row_count; r++) {
        split(rows[r], row, FS)
        for (n = 1; n <= length(names); n++) {
          name = names[n]
          sum[name] += row[idx[name]] + 0
        }
      }
      qacc = sum["fixture_query_byte_acc"] / count
      printf "%s,%s,%.6f,%s,%.6f,%.6f,%.6f", scenario, preserve_correct, corrupt_rate, fallback_source, qacc, clean_reference, clean_reference - qacc
      for (n = 2; n <= length(names); n++) {
        name = names[n]
        printf ",%.6f", sum[name] / count
      }
      printf "\n"
    }
  ' "$csv_path" >>"$SUMMARY_CSV"
}

run_case() {
  local scenario="$1"
  local fallback_source="$2"
  local preserve_correct="$3"
  local corrupt_rate="$4"
  local clean_reference
  local safe_rate="${corrupt_rate//./p}"
  local label="${scenario}_k${KEY_COUNT}_${fallback_source}_cr${safe_rate}_pc${preserve_correct}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"

  make_fixture "$fixture" "$KEY_COUNT"
  clean_reference="$(get_clean_reference "$fallback_source")"
  run_dmv02 "$fixture" "$csv_path" "$fallback_source" "$preserve_correct" "$corrupt_rate"
  append_summary "$scenario" "$preserve_correct" "$corrupt_rate" "$fallback_source" "$clean_reference" "$csv_path"
}

run_group() {
  local preserve_label="$1"
  local preserve_correct="$2"
  local corrupt_rate="$3"
  run_case "${preserve_label}-off" off "$preserve_correct" "$corrupt_rate"
  run_case "${preserve_label}-key-shape" key-shape "$preserve_correct" "$corrupt_rate"
  if [[ "$MODE" != "smoke" ]]; then
    run_case "${preserve_label}-raw-key" raw-key "$preserve_correct" "$corrupt_rate"
  fi
}

if [[ "$MODE" == "smoke" ]]; then
  run_group preserve 1 "$CORRUPT_RATE_SMOKE"
  run_group remove 0 "$CORRUPT_RATE_SMOKE"
elif [[ "$MODE" == "full" ]]; then
  for corrupt_rate in 0.10 0.25 0.50; do
    run_group preserve 1 "$corrupt_rate"
    run_group remove 0 "$corrupt_rate"
  done
else
  for corrupt_rate in 0.10 0.25; do
    run_group preserve 1 "$corrupt_rate"
    run_group remove 0 "$corrupt_rate"
  done
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
