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

EPOCHS=14
CYCLES_PER_EPOCH=14
PROPOSAL_COUNT=24
PREFIX="v05_route_source_credit_noisy_scale"
KEY_COUNTS=(64 128)
SEEDS=(1 2 3)
NOISE_RATES=(0.25 0.50)

if [[ "$MODE" == "smoke" ]]; then
  EPOCHS=6
  CYCLES_PER_EPOCH=6
  PROPOSAL_COUNT=16
  PREFIX="v05_route_source_credit_noisy_scale_smoke"
  KEY_COUNTS=(32 64)
  SEEDS=(1 2)
  NOISE_RATES=(0.50 1.00)
elif [[ "$MODE" == "full" ]]; then
  EPOCHS=24
  CYCLES_PER_EPOCH=18
  PROPOSAL_COUNT=30
  KEY_COUNTS=(64 128 256)
  SEEDS=(1 2 3 4 5)
  NOISE_RATES=(0.10 0.25 0.50 1.00)
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,branch,key_count,seed,route_noisy_source_rate,route_hash_source,route_fallback_source,route_source_credit_apply_mode,route_plasticity_ledger,fixture_query_byte_acc,route_source_credit_size,route_source_credit_primary_mean,route_source_credit_fallback_mean,route_source_credit_noisy_mean,route_source_credit_gap,route_source_credit_primary_slashed_rate,route_source_credit_fallback_rewarded_rate,route_source_credit_noisy_slashed_rate,route_noisy_source_used_rate,route_noisy_source_selected_rate,route_source_credit_apply_active,route_source_credit_selected_fallback_rate,route_source_credit_strength_mean,route_hint_candidate_lookup_count,route_hint_value_read_distance_mean,routing_trigger_rate,active_jump_rate,route_primary_recall,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate\n' >"$SUMMARY_CSV"

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
    local key=$((25000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((25000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_noisy_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_source_credit_noisy_slashed_rate route_noisy_source_used_rate route_noisy_source_selected_rate route_source_credit_apply_active route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      for (i = 1; i <= length(names); i++) {
        if (!(names[i] in idx)) {
          printf "missing column: %s in %s\n", names[i], FILENAME > "/dev/stderr"
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
        for (i = 1; i <= length(names); i++) {
          name = names[i]
          sum[name] += row[idx[name]] + 0
        }
      }
      for (i = 1; i <= length(names); i++) {
        if (i > 1) printf ","
        name = names[i]
        printf "%.6f", sum[name] / count
      }
    }
  ' "$csv_path"
}

run_case() {
  local branch="$1"
  local key_count="$2"
  local seed="$3"
  local noisy_rate="$4"
  local hash_source="$5"
  local fallback_source="$6"
  local scenario="${branch}-k${key_count}-s${seed}-n${noisy_rate//./p}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "source noisy scale: ${scenario} hash=${hash_source} fallback=${fallback_source}" >&2
  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch "$CYCLES_PER_EPOCH" \
    --seed "$seed" \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count "$PROPOSAL_COUNT" \
    --route-mode hint-kv-hash \
    --route-hash-source "$hash_source" \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --K-route 4 \
    --route-hash-bits 16 \
    --route-hint-agg confidence-gated \
    --route-candidate-score recency \
    --route-confidence-threshold 0.75 \
    --route-lowconf-policy aggregate \
    --route-lowconf-agg vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence agreement \
    --route-delta-mode target-only \
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-strength-confidence weight \
    --route-corrupt-candidate-rate 0.25 \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct 0 \
    --route-fallback-source "$fallback_source" \
    --route-noisy-source-rate "$noisy_rate" \
    --route-fallback-strength-mode fixed \
    --route-fallback-strength-mult 1.0 \
    --route-fallback-hi-strength-mult 5.0 \
    --route-fallback-lo-strength-mult 10.0 \
    --route-fallback-channel-strength-mode fixed \
    --route-credit-learning 1 \
    --route-credit-mode query-value \
    --route-credit-score-weight 2.0 \
    --route-credit-eta-reward 0.05 \
    --route-credit-eta-slash 0.20 \
    --route-credit-decay 0.0 \
    --route-credit-clip 2.0 \
    --route-plasticity-ledger 0 \
    --route-plasticity-ledger-decay 0.0 \
    --route-source-credit-learning 1 \
    --route-source-credit-apply-mode ranking-strength \
    --route-source-credit-score-weight 1.0 \
    --route-source-credit-eta-reward 0.05 \
    --route-source-credit-eta-slash 0.10 \
    --route-source-credit-decay 0.0 \
    --route-source-credit-clip 2.0 \
    --csv "$csv_path"

  printf '%s,%s,%d,%d,%.6f,%s,%s,ranking-strength,0,%s\n' \
    "$scenario" \
    "$branch" \
    "$key_count" \
    "$seed" \
    "$noisy_rate" \
    "$hash_source" \
    "$fallback_source" \
    "$(compute_metrics "$csv_path")" >>"$SUMMARY_CSV"
}

run_smoke() {
  local key_count
  local seed
  local noisy_rate
  for key_count in "${KEY_COUNTS[@]}"; do
    for seed in "${SEEDS[@]}"; do
      run_case "joint-good" "$key_count" "$seed" 0.0 joint-code-key key-shape
      for noisy_rate in "${NOISE_RATES[@]}"; do
        run_case "noisy-bad" "$key_count" "$seed" "$noisy_rate" route-code-key noisy-route-code
      done
    done
  done
}

run_smoke

echo "wrote $SUMMARY_CSV"
