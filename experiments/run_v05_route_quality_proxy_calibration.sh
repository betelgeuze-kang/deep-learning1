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

EPOCHS=10
CYCLES_PER_EPOCH=10
PROPOSAL_COUNT=22
PREFIX="v05_route_quality_proxy_calibration"
KEY_COUNTS=(128)
SEEDS=(1 2)

if [[ "$MODE" == "smoke" ]]; then
  EPOCHS=6
  CYCLES_PER_EPOCH=6
  PROPOSAL_COUNT=18
  PREFIX="v05_route_quality_proxy_calibration_smoke"
  KEY_COUNTS=(128)
  SEEDS=(1)
elif [[ "$MODE" == "full" ]]; then
  EPOCHS=16
  CYCLES_PER_EPOCH=14
  PROPOSAL_COUNT=28
  KEY_COUNTS=(64 128 256)
  SEEDS=(1 2 3)
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,arm,quality_beta,logdet_weight,entropy_weight,vote_margin_weight,top_share_weight,channel_weight,key_count,seed,qacc,route_quality_source_ranking_delta_mean,route_quality_selected_raw_rate,route_quality_selected_keyshape_rate,route_quality_selected_noisy_rate,route_quality_retry_raw_proxy_mean,route_quality_retry_keyshape_proxy_mean,route_quality_retry_noisy_proxy_mean,route_quality_retry_raw_delta_mean,route_quality_retry_keyshape_delta_mean,route_quality_retry_noisy_delta_mean,route_quality_selected_raw_qacc,route_quality_selected_keyshape_qacc,route_quality_selected_noisy_qacc,lookup_count,read_distance,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

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
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      name_count = split("fixture_query_byte_acc route_quality_source_ranking_delta_mean route_quality_selected_raw_rate route_quality_selected_keyshape_rate route_quality_selected_noisy_rate route_quality_retry_raw_proxy_mean route_quality_retry_keyshape_proxy_mean route_quality_retry_noisy_proxy_mean route_quality_retry_raw_delta_mean route_quality_retry_keyshape_delta_mean route_quality_retry_noisy_delta_mean route_quality_selected_raw_qacc route_quality_selected_keyshape_qacc route_quality_selected_noisy_qacc route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      for (i = 1; i <= name_count; i++) {
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
        for (i = 1; i <= name_count; i++) {
          name = names[i]
          sum[name] += row[idx[name]] + 0
        }
      }
      for (i = 1; i <= name_count; i++) {
        if (i > 1) printf ","
        name = names[i]
        printf "%.6f", sum[name] / count
      }
    }
  ' "$csv_path"
}

run_case() {
  local arm="$1"
  local key_count="$2"
  local seed="$3"
  local beta="$4"
  local logdet_weight="$5"
  local entropy_weight="$6"
  local vote_margin_weight="$7"
  local top_share_weight="$8"
  local channel_weight="$9"
  local scenario="${arm}-k${key_count}-s${seed}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n
  local metrics

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "quality-proxy-calibration: ${scenario} beta=${beta} logdet=${logdet_weight} entropy=${entropy_weight} vote=${vote_margin_weight} top=${top_share_weight} channel=${channel_weight}" >&2
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
    --route-code-key-region-keep-prob 0.25 \
    --route-code-aux-noise-rate 0.75 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --K-route 4 \
    --route-hash-bits 16 \
    --route-hint-agg weighted-vote \
    --route-candidate-score recency \
    --route-confidence-threshold 0.75 \
    --route-lowconf-policy aggregate \
    --route-lowconf-agg weighted-vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence agreement \
    --route-delta-mode target-only \
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-strength-confidence weight \
    --route-fallback-source noisy-route-code \
    --route-noisy-source-rate 1.0 \
    --route-source-retry-source off \
    --route-source-retry-policy source-credit \
    --route-source-retry-tiebreak source-order \
    --route-source-retry-priorities raw-key:0.0,key-shape:0.0,noisy-route-code:0.0 \
    --route-source-retry-prior-mode static \
    --route-source-retry-candidates raw-key,key-shape,noisy-route-code \
    --route-source-retry-per-source-limit 4 \
    --route-fallback-strength-mode fixed \
    --route-fallback-strength-mult 1.0 \
    --route-fallback-hi-strength-mult 5.0 \
    --route-fallback-lo-strength-mult 10.0 \
    --route-fallback-channel-strength-mode fixed \
    --route-quality-diagnostics 1 \
    --route-quality-feature-set value-only \
    --route-quality-apply source-ranking \
    --route-quality-source-ranking-beta "$beta" \
    --route-quality-eps 1e-4 \
    --route-channel-tension-diagnostics 1 \
    --route-channel-tension-mode margin \
    --route-quality-score 1 \
    --route-quality-logdet-weight "$logdet_weight" \
    --route-quality-entropy-weight "$entropy_weight" \
    --route-quality-vote-margin-weight "$vote_margin_weight" \
    --route-quality-top-share-weight "$top_share_weight" \
    --route-quality-source-credit-weight 0.5 \
    --route-quality-edge-credit-weight 0.5 \
    --route-quality-channel-weight "$channel_weight" \
    --csv "$csv_path"

  metrics="$(compute_metrics "$csv_path")"
  printf '%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%s\n' \
    "$scenario" \
    "$arm" \
    "$beta" \
    "$logdet_weight" \
    "$entropy_weight" \
    "$vote_margin_weight" \
    "$top_share_weight" \
    "$channel_weight" \
    "$key_count" \
    "$seed" \
    "$metrics" >>"$SUMMARY_CSV"
}

run_arm_set() {
  local key_count="$1"
  local seed="$2"

  run_case proxy-default "$key_count" "$seed" 0.10 0.1 0.5 1.0 1.0 0.1
  run_case logdet-sign-flip "$key_count" "$seed" 0.10 -0.1 0.5 1.0 1.0 0.1
  run_case entropy-sign-flip "$key_count" "$seed" 0.10 0.1 -0.5 1.0 1.0 0.1
  run_case vote-margin-sign-flip "$key_count" "$seed" 0.10 0.1 0.5 -1.0 1.0 0.1
  run_case top-share-sign-flip "$key_count" "$seed" 0.10 0.1 0.5 1.0 -1.0 0.1
  run_case channel-sign-flip "$key_count" "$seed" 0.10 0.1 0.5 1.0 1.0 -0.1
}

for key_count in "${KEY_COUNTS[@]}"; do
  for seed in "${SEEDS[@]}"; do
    run_arm_set "$key_count" "$seed"
  done
done

echo "wrote $SUMMARY_CSV"
