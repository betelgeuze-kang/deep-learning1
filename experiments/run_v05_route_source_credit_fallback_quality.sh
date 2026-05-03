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

EPOCHS=16
CYCLES_PER_EPOCH=16
PROPOSAL_COUNT=30
PREFIX="v05_route_source_credit_fallback_quality"

if [[ "$MODE" == "smoke" ]]; then
  EPOCHS=8
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=20
  PREFIX="v05_route_source_credit_fallback_quality_smoke"
elif [[ "$MODE" == "full" ]]; then
  EPOCHS=28
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,arm,fallback_source,route_hint_agg,source_credit_apply_mode,key_count,seed,qacc,decode,primary_recall,fallback_used,fallback_recall,fallback_qacc,fallback_success,fallback_hi_acc,fallback_lo_acc,fallback_route_margin,fallback_effective_strength,fallback_local_margin,fallback_hi_local_margin,fallback_lo_local_margin,candidate_top1,candidate_rank,correct_vote_share,vote_entropy,unique_values,vote_margin,vote_candidate_count,source_gap,selected_fallback,strength_mean,lookup_count,read_distance,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

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
    local key=$((29000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((29000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc key_region_route_decode_acc route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_route_margin_mean route_fallback_effective_strength_mean route_fallback_local_margin_against_route_mean route_fallback_hi_local_margin_against_route_mean route_fallback_lo_local_margin_against_route_mean route_candidate_top1_rate route_candidate_rank_mean route_hint_correct_value_vote_share_mean route_hint_vote_entropy_mean route_hint_unique_values_mean route_hint_vote_margin_mean route_hint_vote_candidate_count_mean route_source_credit_gap route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", names, " ")
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
  local arm="$1"
  local key_count="$2"
  local seed="$3"
  local fallback_source="$4"
  local route_hint_agg="$5"
  local source_apply_mode="$6"
  local source_credit_learning=0
  local scenario="${arm}-k${key_count}-s${seed}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n
  local metrics

  if [[ "$source_apply_mode" != "off" ]]; then
    source_credit_learning=1
  fi

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "fallback quality: ${scenario} source=${fallback_source} agg=${route_hint_agg} apply=${source_apply_mode}" >&2
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
    --route-hint-agg "$route_hint_agg" \
    --route-candidate-score recency \
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
    --route-fallback-source "$fallback_source" \
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
    --route-source-credit-learning "$source_credit_learning" \
    --route-source-credit-apply-mode "$source_apply_mode" \
    --route-source-credit-score-weight 1.0 \
    --route-source-credit-eta-reward 0.05 \
    --route-source-credit-eta-slash 0.10 \
    --route-source-credit-decay 0.0 \
    --route-source-credit-clip 2.0 \
    --csv "$csv_path"

  metrics="$(compute_metrics "$csv_path")"
  printf '%s,%s,%s,%s,%s,%d,%d,%s\n' \
    "$scenario" \
    "$arm" \
    "$fallback_source" \
    "$route_hint_agg" \
    "$source_apply_mode" \
    "$key_count" \
    "$seed" \
    "$metrics" >>"$SUMMARY_CSV"
}

run_arm_set() {
  local key_count="$1"
  local seed="$2"

  run_case "raw-vote-off" "$key_count" "$seed" raw-key vote off
  run_case "raw-weighted-off" "$key_count" "$seed" raw-key weighted-vote off
  run_case "raw-weighted-policy" "$key_count" "$seed" raw-key weighted-vote ranking-strength
  run_case "keyshape-vote-off" "$key_count" "$seed" key-shape vote off
  run_case "keyshape-weighted-off" "$key_count" "$seed" key-shape weighted-vote off
  run_case "keyshape-weighted-policy" "$key_count" "$seed" key-shape weighted-vote ranking-strength
}

run_smoke() {
  run_arm_set 128 1
}

run_standard() {
  for key_count in 64 128; do
    for seed in 1 2 3; do
      run_arm_set "$key_count" "$seed"
    done
  done
}

run_full() {
  for key_count in 64 128 256; do
    for seed in 1 2 3 4 5; do
      run_arm_set "$key_count" "$seed"
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
