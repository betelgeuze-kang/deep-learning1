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
  PREFIX="v03_route_hint_kv_hash_route_code_lowconf_diagnostics_smoke"
  EPOCHS=10
else
  PREFIX="v03_route_hint_kv_hash_route_code_lowconf_diagnostics"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_corrupt_preserve_correct,route_corrupt_candidate_rate,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_candidate_corrupt_rate,route_lowconf_query_rate,route_highconf_query_rate,route_lowconf_qacc,route_highconf_qacc,route_lowconf_candidate_recall,route_highconf_candidate_recall,route_lowconf_top1,route_highconf_top1,route_lowconf_correct_value_vote_share,route_highconf_correct_value_vote_share,route_lowconf_unique_values,route_highconf_unique_values,route_lowconf_vote_entropy,route_highconf_vote_entropy,route_lowconf_route_margin,route_highconf_route_margin,route_lowconf_local_margin,route_highconf_local_margin,route_lowconf_hi_acc,route_highconf_hi_acc,route_lowconf_lo_acc,route_highconf_lo_acc,route_lowconf_wrong_strength_mean,route_highconf_wrong_strength_mean,route_agg_policy_vote_rate,route_agg_policy_weighted_rate\n' >"$SUMMARY_CSV"

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
  local preserve_correct="$2"
  local corrupt_rate="$3"
  local clean_reference="$4"
  local csv_path="$5"

  awk -F, \
    -v scenario="$scenario" \
    -v preserve_correct="$preserve_correct" \
    -v corrupt_rate="$corrupt_rate" \
    -v clean_reference="$clean_reference" '
    BEGIN {
      split("fixture_query_byte_acc route_candidate_corrupt_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1 route_lowconf_correct_value_vote_share route_highconf_correct_value_vote_share route_lowconf_unique_values route_highconf_unique_values route_lowconf_vote_entropy route_highconf_vote_entropy route_lowconf_route_margin route_highconf_route_margin route_lowconf_local_margin route_highconf_local_margin route_lowconf_hi_acc route_highconf_hi_acc route_lowconf_lo_acc route_highconf_lo_acc route_lowconf_wrong_strength_mean route_highconf_wrong_strength_mean route_agg_policy_vote_rate route_agg_policy_weighted_rate", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      for (n = 1; n <= length(names); n++) {
        if (!(names[n] in idx)) {
          printf "missing column %s in %s\n", names[n], FILENAME > "/dev/stderr"
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
      printf "%s,%s,%s,%.6f,%.6f,%.6f", scenario, preserve_correct, corrupt_rate, qacc, clean_reference, clean_reference - qacc
      for (n = 2; n <= length(names); n++) {
        name = names[n]
        printf ",%.6f", sum[name] / count
      }
      printf "\n"
    }
  ' "$csv_path" >>"$SUMMARY_CSV"
}

run_dmv02() {
  local fixture="$1"
  local csv_path="$2"
  local corrupt_rate="$3"
  local preserve_correct="$4"
  local n
  n="$(wc -c <"$fixture")"

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
    --route-confidence-threshold 0.75 \
    --route-lowconf-agg vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence agreement \
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

run_case() {
  local scenario="$1"
  local key_count="$2"
  local corrupt_rate="$3"
  local preserve_correct="$4"
  local clean_reference="$5"
  local safe_rate="${corrupt_rate//./p}"
  local label="${scenario}_k${key_count}_cr${safe_rate}_pc${preserve_correct}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"

  make_fixture "$fixture" "$key_count"
  echo "route-code lowconf diagnostics: ${label}"
  run_dmv02 "$fixture" "$csv_path" "$corrupt_rate" "$preserve_correct"
  append_summary "$scenario" "$preserve_correct" "$corrupt_rate" "$clean_reference" "$csv_path"
}

run_set() {
  local key_count="$1"
  local corrupt_rate="$2"
  local clean_fixture="$TMP_DIR/clean_k${key_count}.txt"
  local clean_csv="$RESULTS_DIR/${PREFIX}_clean_k${key_count}.csv"
  make_fixture "$clean_fixture" "$key_count"
  echo "route-code lowconf diagnostics: clean-reference_k${key_count}"
  run_dmv02 "$clean_fixture" "$clean_csv" 0.0 1
  local clean_reference
  clean_reference="$(last5_mean "$clean_csv" fixture_query_byte_acc)"

  run_case preserve-correct "$key_count" "$corrupt_rate" 1 "$clean_reference"
  run_case remove-correct "$key_count" "$corrupt_rate" 0 "$clean_reference"
}

if [[ "$MODE" == "smoke" ]]; then
  run_set 128 0.25
elif [[ "$MODE" == "full" ]]; then
  for corrupt_rate in 0.10 0.25 0.50; do
    run_set 128 "$corrupt_rate"
  done
else
  for corrupt_rate in 0.10 0.25; do
    run_set 128 "$corrupt_rate"
  done
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
