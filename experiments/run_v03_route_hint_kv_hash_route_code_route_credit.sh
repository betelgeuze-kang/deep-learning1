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
CORRUPT_RATE=0.25
CONFIDENCE_THRESHOLD=0.75

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_route_credit_smoke"
  EPOCHS=12
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_route_credit"
  EPOCHS=24
else
  PREFIX="v03_route_hint_kv_hash_route_code_route_credit"
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_credit_learning,route_plasticity_ledger,fixture_query_byte_acc,route_credit_correct_mean,route_credit_wrong_mean,route_credit_gap,route_credit_rewarded_rate,route_credit_slashed_rate,route_credit_top1_rate,route_credit_qacc,route_plasticity_ledger_size,route_plasticity_ledger_mean_abs_credit,route_value_top_correct_rate,route_hint_correct_value_vote_share_mean\n' >"$SUMMARY_CSV"

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
    local key=$((17000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((17000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

run_dmv02() {
  local fixture="$1"
  local csv_path="$2"
  local credit_learning="$3"
  local plasticity_ledger="$4"
  local n

  n="$(wc -c <"$fixture")"

  echo "route-code route-credit: learning=${credit_learning}" >&2
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
    --route-delta-mode target-only \
    --route-pull-scale 1.0 \
    --route-push-scale 1.0 \
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-confidence-power 1.0 \
    --route-min-confidence 0.0 \
    --route-strength-confidence weight \
    --route-corrupt-candidate-rate "$CORRUPT_RATE" \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct 1 \
    --route-credit-learning "$credit_learning" \
    --route-credit-mode value-pos \
    --route-credit-score-weight 1.0 \
    --route-credit-eta-reward 0.05 \
    --route-credit-eta-slash 0.10 \
    --route-credit-decay 0.001 \
    --route-credit-clip 4.0 \
    --route-plasticity-ledger "$plasticity_ledger" \
    --csv "$csv_path"
}

append_summary() {
  local scenario="$1"
  local credit_learning="$2"
  local plasticity_ledger="$3"
  local csv_path="$4"

  awk -F, \
    -v scenario="$scenario" \
    -v credit_learning="$credit_learning" \
    -v plasticity_ledger="$plasticity_ledger" '
    BEGIN {
      split("fixture_query_byte_acc route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_plasticity_ledger_size route_plasticity_ledger_mean_abs_credit route_value_top_correct_rate route_hint_correct_value_vote_share_mean", names, " ")
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
      printf "%s,%d,%d", scenario, credit_learning, plasticity_ledger
      for (n = 1; n <= length(names); n++) {
        name = names[n]
        sum = 0.0
        for (r = start; r <= row_count; r++) {
          split(rows[r], row, FS)
          sum += row[idx[name]] + 0
        }
        printf ",%.6f", sum / count
      }
      printf "\n"
    }
  ' "$csv_path" >>"$SUMMARY_CSV"
}

run_case() {
  local scenario="$1"
  local credit_learning="$2"
  local plasticity_ledger="$3"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"

  make_fixture "$fixture" "$KEY_COUNT"
  run_dmv02 "$fixture" "$csv_path" "$credit_learning" "$plasticity_ledger"
  append_summary "$scenario" "$credit_learning" "$plasticity_ledger" "$csv_path"
}

run_case "credit_off" 0 0
run_case "credit_on" 1 1

echo "wrote $SUMMARY_CSV"
