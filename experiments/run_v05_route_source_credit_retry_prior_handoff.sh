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
CYCLES_PER_EPOCH=12
PROPOSAL_COUNT=24
PREFIX="v05_route_source_credit_retry_prior_handoff"
KEY_COUNTS=(128)
SEEDS=(1 2)

if [[ "$MODE" == "smoke" ]]; then
  EPOCHS=8
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=20
  PREFIX="v05_route_source_credit_retry_prior_handoff_smoke"
  KEY_COUNTS=(128)
  SEEDS=(1)
elif [[ "$MODE" == "full" ]]; then
  EPOCHS=20
  CYCLES_PER_EPOCH=16
  PROPOSAL_COUNT=30
  KEY_COUNTS=(64 128 256)
  SEEDS=(1 2 3 4 5)
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,arm,prior_mode,warmup_epochs,prior_decay,prior_label,key_count,seed,qacc,fallback_recall,fallback_qacc,source_gap,noisy_slashed,source_retry_used,source_retry_success,retry_raw_selected,retry_keyshape_selected,retry_noisy_selected,lookup_count,read_distance,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

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
    local key=$((36000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((36000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc route_fallback_recall route_fallback_qacc route_source_credit_gap route_source_credit_noisy_slashed_rate route_source_retry_used_rate route_source_retry_success_rate route_source_retry_raw_selected_rate route_source_retry_keyshape_selected_rate route_source_retry_noisy_selected_rate route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", names, " ")
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
  local retry_policy="$4"
  local retry_tiebreak="$5"
  local prior_mode="$6"
  local warmup_epochs="$7"
  local prior_decay="$8"
  local retry_priorities_csv="$9"
  local retry_priorities_label="${10}"
  local retry_source="${11}"
  local scenario="${arm}-k${key_count}-s${seed}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n
  local metrics

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "retry-prior-handoff: ${scenario} policy=${retry_policy} tiebreak=${retry_tiebreak} prior=${prior_mode} warmup=${warmup_epochs} decay=${prior_decay}" >&2
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
    --route-corrupt-candidate-rate 0.0 \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct 1 \
    --route-fallback-source noisy-route-code \
    --route-noisy-source-rate 1.0 \
    --route-source-retry-source "$retry_source" \
    --route-source-retry-policy "$retry_policy" \
    --route-source-retry-tiebreak "$retry_tiebreak" \
    --route-source-retry-priorities "$retry_priorities_csv" \
    --route-source-retry-prior-mode "$prior_mode" \
    --route-source-retry-prior-decay "$prior_decay" \
    --route-source-retry-prior-warmup-epochs "$warmup_epochs" \
    --route-source-retry-candidates raw-key,key-shape,noisy-route-code \
    --route-source-retry-per-source-limit 1 \
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
    --route-source-filter-mode negative-credit \
    --route-source-filter-threshold 0.0 \
    --csv "$csv_path"

  metrics="$(compute_metrics "$csv_path")"
  printf '%s,%s,%s,%d,%.6f,%s,%d,%d,%s\n' \
    "$scenario" \
    "$arm" \
    "$prior_mode" \
    "$warmup_epochs" \
    "$prior_decay" \
    "$retry_priorities_label" \
    "$key_count" \
    "$seed" \
    "$metrics" >>"$SUMMARY_CSV"
}

run_arm_set() {
  local key_count="$1"
  local seed="$2"

  run_case source-order "$key_count" "$seed" source-credit source-order none 0 1.0 \
    "raw-key:0.0,key-shape:0.0,noisy-route-code:0.0" \
    "raw-key:0.0+key-shape:0.0+noisy-route-code:0.0" \
    off
  run_case static-keyshape-prior "$key_count" "$seed" source-credit source-prior static 0 1.0 \
    "key-shape:0.2,raw-key:0.0,noisy-route-code:-1.0" \
    "key-shape:0.2+raw-key:0.0+noisy-route-code:-1.0" \
    off
  run_case warmup-short "$key_count" "$seed" source-credit source-prior warmup 2 1.0 \
    "key-shape:0.2,raw-key:0.0,noisy-route-code:-1.0" \
    "key-shape:0.2+raw-key:0.0+noisy-route-code:-1.0" \
    off
  run_case warmup-long "$key_count" "$seed" source-credit source-prior warmup "$EPOCHS" 1.0 \
    "key-shape:0.2,raw-key:0.0,noisy-route-code:-1.0" \
    "key-shape:0.2+raw-key:0.0+noisy-route-code:-1.0" \
    off
  run_case decay-fast "$key_count" "$seed" source-credit source-prior decay 0 0.20 \
    "key-shape:0.2,raw-key:0.0,noisy-route-code:-1.0" \
    "key-shape:0.2+raw-key:0.0+noisy-route-code:-1.0" \
    off
  run_case fixed-keyshape "$key_count" "$seed" fixed source-order none 0 1.0 \
    "raw-key:0.0,key-shape:0.0,noisy-route-code:0.0" \
    "raw-key:0.0+key-shape:0.0+noisy-route-code:0.0" \
    key-shape
}

for key_count in "${KEY_COUNTS[@]}"; do
  for seed in "${SEEDS[@]}"; do
    run_arm_set "$key_count" "$seed"
  done
done

echo "wrote $SUMMARY_CSV"
