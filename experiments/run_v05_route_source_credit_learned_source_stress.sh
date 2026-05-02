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

EPOCHS=20
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30
PREFIX="v05_route_source_credit_learned_source_stress"

if [[ "$MODE" == "smoke" ]]; then
  EPOCHS=8
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=20
  PREFIX="v05_route_source_credit_learned_source_stress_smoke"
elif [[ "$MODE" == "full" ]]; then
  EPOCHS=36
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,branch,key_count,seed,route_hash_source,route_fallback_source,route_code_key_region_keep_prob,route_code_aux_noise_rate,eta_route_code,lambda_route_code_id,route_noisy_source_rate,fixture_query_byte_acc,key_region_route_decode_acc,route_key_unique_count,route_signature_collision_rate,route_bucket_collision_rate,route_primary_recall,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_source_credit_size,route_source_credit_primary_mean,route_source_credit_fallback_mean,route_source_credit_gap,route_source_credit_primary_slashed_rate,route_source_credit_fallback_rewarded_rate,route_source_credit_selected_fallback_rate,route_source_credit_strength_mean,route_hint_candidate_lookup_count,route_hint_value_read_distance_mean,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

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
    local key=$((26000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((26000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc key_region_route_decode_acc route_key_unique_count route_signature_collision_rate route_bucket_collision_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", names, " ")
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
      if (row_count < 1) {
        printf "no data rows in %s\n", FILENAME > "/dev/stderr"
        exit 3
      }
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
  local scenario="$1"
  local branch="$2"
  local key_count="$3"
  local seed="$4"
  local keep_prob="$5"
  local aux_noise_rate="$6"
  local eta_route_code="$7"
  local lambda_route_code_id="$8"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n
  local metrics

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "learned source stress: ${scenario} keys=${key_count} seed=${seed} keep=${keep_prob} aux_noise=${aux_noise_rate}" >&2
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
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --route-code-key-region-keep-prob "$keep_prob" \
    --route-code-aux-noise-rate "$aux_noise_rate" \
    --eta-route-code "$eta_route_code" \
    --lambda-route-code-id "$lambda_route_code_id" \
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
    --route-corrupt-candidate-rate 0.0 \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct 1 \
    --route-fallback-source key-shape \
    --route-noisy-source-rate 0.0 \
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

  metrics="$(compute_metrics "$csv_path")"
  printf '%s,%s,%d,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%s\n' \
    "$scenario" \
    "$branch" \
    "$key_count" \
    "$seed" \
    "route-code-key" \
    "key-shape" \
    "$keep_prob" \
    "$aux_noise_rate" \
    "$eta_route_code" \
    "$lambda_route_code_id" \
    "0.0" \
    "$metrics" >>"$SUMMARY_CSV"
}

run_pair() {
  local key_count="$1"
  local seed="$2"
  run_case "clean-k${key_count}-s${seed}" clean "$key_count" "$seed" 1.0 0.0 0.25 1.0
  run_case "weak-k${key_count}-s${seed}" weak "$key_count" "$seed" 0.25 0.75 0.25 1.0
}

run_smoke() {
  for key_count in 32 64; do
    for seed in 1 2; do
      run_pair "$key_count" "$seed"
    done
  done
}

run_standard() {
  for seed in 1 2 3; do
    run_pair 128 "$seed"
  done
}

run_full() {
  for key_count in 64 128 256; do
    for seed in 1 2 3 4 5; do
      run_case "clean-k${key_count}-s${seed}" clean "$key_count" "$seed" 1.0 0.0 0.25 1.0
      run_case "keep50-k${key_count}-s${seed}" weak "$key_count" "$seed" 0.50 0.0 0.25 1.0
      run_case "keep25-noise75-k${key_count}-s${seed}" weak "$key_count" "$seed" 0.25 0.75 0.25 1.0
      run_case "noise100-k${key_count}-s${seed}" weak "$key_count" "$seed" 1.0 1.0 0.25 1.0
      run_case "eta05-k${key_count}-s${seed}" weak "$key_count" "$seed" 1.0 0.0 0.05 1.0
      run_case "lambda10-k${key_count}-s${seed}" weak "$key_count" "$seed" 1.0 0.0 0.25 0.10
    done
  done
}

case "$MODE" in
  smoke)
    run_smoke
    ;;
  full)
    run_full
    ;;
  standard)
    run_standard
    ;;
esac

echo "wrote $SUMMARY_CSV"
