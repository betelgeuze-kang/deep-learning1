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

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_gated_agg_smoke"
  EPOCHS=10
else
  PREFIX="v03_route_hint_kv_hash_route_code_gated_agg"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_hint_agg,route_strength_confidence,route_aggregation_confidence,route_confidence_threshold,route_corrupt_candidate_rate,route_corrupt_preserve_correct,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_candidate_corrupt_rate,route_lowconf_query_rate,route_highconf_query_rate,route_lowconf_qacc,route_highconf_qacc,route_lowconf_wrong_strength_mean,route_highconf_wrong_strength_mean,route_agg_policy_vote_rate,route_agg_policy_weighted_rate,route_wrong_hint_strength_mean,route_correct_hint_strength_mean,route_strength_mean\n' >"$SUMMARY_CSV"

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
    local key=$((13000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((13000 + i))
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

append_summary() {
  local scenario="$1"
  local route_hint_agg="$2"
  local route_strength_confidence="$3"
  local route_aggregation_confidence="$4"
  local confidence_threshold="$5"
  local corrupt_rate="$6"
  local preserve_correct="$7"
  local clean_reference="$8"
  local csv_path="$9"

  awk -F, \
    -v scenario="$scenario" \
    -v route_hint_agg="$route_hint_agg" \
    -v route_strength_confidence="$route_strength_confidence" \
    -v route_aggregation_confidence="$route_aggregation_confidence" \
    -v confidence_threshold="$confidence_threshold" \
    -v corrupt_rate="$corrupt_rate" \
    -v preserve_correct="$preserve_correct" \
    -v clean_reference="$clean_reference" '
    BEGIN {
      split("fixture_query_byte_acc route_candidate_corrupt_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_wrong_strength_mean route_highconf_wrong_strength_mean route_agg_policy_vote_rate route_agg_policy_weighted_rate route_wrong_hint_strength_mean route_correct_hint_strength_mean route_strength_mean", names, " ")
    }
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
        for (n = 1; n <= length(names); n++) {
          name = names[n]
          sum[name] += row[idx[name]] + 0
        }
      }
      qacc = sum["fixture_query_byte_acc"] / count
      printf "%s,%s,%s,%s,%s,%s,%s,%.6f,%.6f,%.6f", scenario, route_hint_agg, route_strength_confidence, route_aggregation_confidence, confidence_threshold, corrupt_rate, preserve_correct, qacc, clean_reference, clean_reference - qacc
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
  local route_hint_agg="$2"
  local route_strength_confidence="$3"
  local route_aggregation_confidence="$4"
  local confidence_threshold="$5"
  local key_count="$6"
  local corrupt_rate="$7"
  local preserve_correct="$8"
  local clean_reference="$9"
  local safe_rate="${corrupt_rate//./p}"
  local label="${scenario}_k${key_count}_${route_hint_agg}_${route_strength_confidence}_cr${safe_rate}_pc${preserve_correct}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local n

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "route-code gated aggregation: ${label}"
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
    --route-hint-agg "$route_hint_agg" \
    --route-candidate-score recency \
    --route-confidence-threshold "$confidence_threshold" \
    --route-lowconf-agg vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence "$route_aggregation_confidence" \
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-confidence-power 1.0 \
    --route-min-confidence 0.0 \
    --route-strength-confidence "$route_strength_confidence" \
    --route-corrupt-candidate-rate "$corrupt_rate" \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct "$preserve_correct" \
    --csv "$csv_path"

  if [[ "$scenario" == "clean-reference" ]]; then
    clean_reference="$(last5_mean "$csv_path" fixture_query_byte_acc)"
    echo "$clean_reference" >"$TMP_DIR/clean_reference_pc${preserve_correct}.txt"
  fi
  append_summary "$scenario" "$route_hint_agg" "$route_strength_confidence" "$route_aggregation_confidence" "$confidence_threshold" "$corrupt_rate" "$preserve_correct" "$clean_reference" "$csv_path"
}

run_set() {
  local key_count="$1"
  local corrupt_rate="$2"
  local preserve_correct="$3"
  local threshold=0.75

  run_case clean-reference vote weight agreement "$threshold" "$key_count" 0.0 "$preserve_correct" 0.0
  local clean_reference
  clean_reference="$(cat "$TMP_DIR/clean_reference_pc${preserve_correct}.txt")"
  run_case corrupt-unscaled vote weight agreement "$threshold" "$key_count" "$corrupt_rate" "$preserve_correct" "$clean_reference"
  run_case corrupt-valueconf vote value-support agreement "$threshold" "$key_count" "$corrupt_rate" "$preserve_correct" "$clean_reference"
  run_case corrupt-agreement vote agreement agreement "$threshold" "$key_count" "$corrupt_rate" "$preserve_correct" "$clean_reference"
  run_case corrupt-gated-agg confidence-gated weight agreement "$threshold" "$key_count" "$corrupt_rate" "$preserve_correct" "$clean_reference"
}

if [[ "$MODE" == "smoke" ]]; then
  run_set 128 0.25 1
elif [[ "$MODE" == "full" ]]; then
  for preserve_correct in 1 0; do
    for corrupt_rate in 0.10 0.25 0.50; do
      run_set 128 "$corrupt_rate" "$preserve_correct"
    done
  done
else
  for corrupt_rate in 0.10 0.25; do
    run_set 128 "$corrupt_rate" 1
  done
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
