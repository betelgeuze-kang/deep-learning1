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
EPOCHS=18
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30
PREFIX="v05_route_source_credit_policy"

if [[ "$MODE" == "smoke" ]]; then
  KEY_COUNT=32
  EPOCHS=8
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=20
  PREFIX="v05_route_source_credit_policy_smoke"
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNT=128
  EPOCHS=40
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_source_credit_learning,route_source_credit_apply_mode,route_plasticity_ledger,route_source_credit_score_weight,route_corrupt_preserve_correct,route_corrupt_candidate_rate,fixture_query_byte_acc,route_plasticity_ledger_size,route_plasticity_ledger_mean_abs_credit,route_source_credit_size,route_source_credit_primary_mean,route_source_credit_fallback_mean,route_source_credit_gap,route_source_credit_primary_slashed_rate,route_source_credit_fallback_rewarded_rate,route_source_credit_apply_active,route_source_credit_override_rate,route_source_credit_selected_fallback_rate,route_source_credit_strength_mean,route_hint_candidate_lookup_count,route_hint_value_read_distance_mean,routing_trigger_rate,active_jump_rate,route_primary_recall,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_fallback_hi_acc,route_fallback_lo_acc\n' >"$SUMMARY_CSV"

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
    local key=$((23000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((23000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc route_plasticity_ledger_size route_plasticity_ledger_mean_abs_credit route_source_credit_size route_source_credit_primary_mean route_source_credit_fallback_mean route_source_credit_gap route_source_credit_primary_slashed_rate route_source_credit_fallback_rewarded_rate route_source_credit_apply_active route_source_credit_override_rate route_source_credit_selected_fallback_rate route_source_credit_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc", names, " ")
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
  local scenario="$1"
  local source_learning="$2"
  local apply_mode="$3"
  local ledger="$4"
  local preserve_correct="$5"
  local corrupt_rate="$6"
  local fixture="$TMP_DIR/fixture.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n

  make_fixture "$fixture" "$KEY_COUNT"
  n="$(wc -c <"$fixture")"

  echo "source credit policy: ${scenario} learning=${source_learning} apply=${apply_mode} ledger=${ledger}" >&2
  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch "$CYCLES_PER_EPOCH" \
    --seed 1 \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count "$PROPOSAL_COUNT" \
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
    --route-corrupt-candidate-rate "$corrupt_rate" \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct "$preserve_correct" \
    --route-fallback-source key-shape \
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
    --route-plasticity-ledger "$ledger" \
    --route-plasticity-ledger-decay 0.0 \
    --route-source-credit-learning "$source_learning" \
    --route-source-credit-apply-mode "$apply_mode" \
    --route-source-credit-score-weight 1.0 \
    --route-source-credit-eta-reward 0.05 \
    --route-source-credit-eta-slash 0.10 \
    --route-source-credit-decay 0.0 \
    --route-source-credit-clip 2.0 \
    --csv "$csv_path"

  printf '%s,%d,%s,%d,1.000000,%d,%.6f,%s\n' \
    "$scenario" \
    "$source_learning" \
    "$apply_mode" \
    "$ledger" \
    "$preserve_correct" \
    "$corrupt_rate" \
    "$(compute_metrics "$csv_path")" >>"$SUMMARY_CSV"
}

run_smoke() {
  run_case "source-off-remove" 0 off 0 0 0.25
  run_case "source-learn-only-remove" 1 off 0 0 0.25
  run_case "source-ranking-remove" 1 ranking 0 0 0.25
  run_case "source-ranking-strength-remove" 1 ranking-strength 0 0 0.25
  run_case "source-ledger-ranking-strength-remove" 1 ranking-strength 1 0 0.25
  run_case "source-ranking-preserve" 1 ranking 0 1 0.25
}

run_full() {
  local preserve_correct
  local corrupt_rate
  local ledger
  local apply_mode

  for preserve_correct in 1 0; do
    for corrupt_rate in 0.10 0.25 0.50; do
      for ledger in 0 1; do
        for apply_mode in off ranking strength ranking-strength; do
          run_case "p${preserve_correct}-cr${corrupt_rate//./p}-l${ledger}-${apply_mode}" \
            1 "$apply_mode" "$ledger" "$preserve_correct" "$corrupt_rate"
        done
      done
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
    run_smoke
    ;;
esac

echo "wrote $SUMMARY_CSV"
