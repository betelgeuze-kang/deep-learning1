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
CONFIDENCE_THRESHOLD=0.75
FALLBACK_HI_MULT=5.0
FALLBACK_LO_75=7.5
FALLBACK_LO_10=10.0

ETA_REWARD=0.05
CREDIT_DECAY=0.0
CREDIT_CLIP=2.0

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_credit_calibration_smoke"
  KEY_COUNT=32
  EPOCHS=5
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=20
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_credit_calibration"
  KEY_COUNT=128
  EPOCHS=20
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
else
  PREFIX="v03_route_hint_kv_hash_route_code_credit_calibration"
  KEY_COUNT=64
  EPOCHS=12
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_credit_learning,route_credit_mode,route_credit_score_weight,route_credit_eta_reward,route_credit_eta_slash,route_credit_decay,route_credit_clip,route_fallback_source,route_fallback_strength_mode,route_fallback_strength_mult,route_fallback_hi_strength_mult,route_fallback_lo_strength_mult,route_fallback_channel_strength_mode,route_corrupt_preserve_correct,route_corrupt_candidate_rate,fixture_query_byte_acc,route_credit_correct_mean,route_credit_wrong_mean,route_credit_gap,route_credit_rewarded_rate,route_credit_slashed_rate,route_credit_top1_rate,route_credit_qacc,route_value_top_correct_rate,route_hint_correct_value_vote_share_mean,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_fallback_hi_acc,route_fallback_lo_acc,route_fallback_effective_strength_mean,route_fallback_hi_effective_strength_mean,route_fallback_lo_effective_strength_mean,route_lowconf_query_rate,route_highconf_query_rate,route_lowconf_qacc,route_highconf_qacc,route_lowconf_candidate_recall,route_highconf_candidate_recall,route_lowconf_top1,route_highconf_top1\n' >"$SUMMARY_CSV"

value_for_index() {
  local index="$1"
  local ascii=$((65 + (index % 26)))
  printf "\\$(printf '%03o' "$ascii")"
}

fmt_label_num() {
  local value="$1"
  case "$value" in
    10.0) printf '10' ;;
    *) printf '%s' "${value//./p}" ;;
  esac
}

make_label() {
  local credit_mode="$1"
  local preserve_correct="$2"
  local lo_mult="$3"
  local score_weight="$4"
  local eta_slash="$5"
  local corrupt_rate="$6"
  local preserve_label="remove"

  if [[ "$preserve_correct" == "1" ]]; then
    preserve_label="preserve"
  fi

  printf '%s-%s-lo%s-sw%s-sl%s-cr%s' \
    "$credit_mode" \
    "$preserve_label" \
    "$(fmt_label_num "$lo_mult")" \
    "$(fmt_label_num "$score_weight")" \
    "$(fmt_label_num "$eta_slash")" \
    "$(fmt_label_num "$corrupt_rate")"
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

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_value_top_correct_rate route_hint_correct_value_vote_share_mean route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        idx[$i] = i
      }
      for (i = 1; i <= length(names); i++) {
        if (!(names[i] in idx)) {
          printf "missing column: %s in %s\n", names[i], FILENAME > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    {
      rows[++row_count] = $0
    }
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

run_dmv02() {
  local fixture="$1"
  local csv_path="$2"
  local credit_mode="$3"
  local score_weight="$4"
  local eta_slash="$5"
  local lo_mult="$6"
  local preserve_correct="$7"
  local corrupt_rate="$8"
  local credit_learning=1
  local n

  n="$(wc -c <"$fixture")"
  if [[ "$credit_mode" == "off" ]]; then
    credit_learning=0
  fi

  echo "credit calibration: mode=${credit_mode} weight=${score_weight} slash=${eta_slash} lo=${lo_mult} preserve=${preserve_correct} corrupt=${corrupt_rate}" >&2
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
    --route-corrupt-candidate-rate "$corrupt_rate" \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct "$preserve_correct" \
    --route-fallback-source key-shape \
    --route-fallback-strength-mode fixed \
    --route-fallback-strength-mult 1.0 \
    --route-fallback-hi-strength-mult "$FALLBACK_HI_MULT" \
    --route-fallback-lo-strength-mult "$lo_mult" \
    --route-fallback-channel-strength-mode fixed \
    --route-credit-learning "$credit_learning" \
    --route-credit-mode "$credit_mode" \
    --route-credit-score-weight "$score_weight" \
    --route-credit-eta-reward "$ETA_REWARD" \
    --route-credit-eta-slash "$eta_slash" \
    --route-credit-decay "$CREDIT_DECAY" \
    --route-credit-clip "$CREDIT_CLIP" \
    --csv "$csv_path"
}

append_summary() {
  local scenario="$1"
  local credit_mode="$2"
  local score_weight="$3"
  local eta_slash="$4"
  local lo_mult="$5"
  local preserve_correct="$6"
  local corrupt_rate="$7"
  local csv_path="$8"
  local metrics
  local credit_learning=1

  metrics="$(compute_metrics "$csv_path")"
  if [[ "$credit_mode" == "off" ]]; then
    credit_learning=0
  fi
  printf '%s,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,key-shape,fixed,1.0,%.6f,%.6f,fixed,%d,%.6f,%s\n' \
    "$scenario" \
    "$credit_learning" \
    "$credit_mode" \
    "$score_weight" \
    "$ETA_REWARD" \
    "$eta_slash" \
    "$CREDIT_DECAY" \
    "$CREDIT_CLIP" \
    "$FALLBACK_HI_MULT" \
    "$lo_mult" \
    "$preserve_correct" \
    "$corrupt_rate" \
    "$metrics" >>"$SUMMARY_CSV"
}

run_case() {
  local credit_mode="$1"
  local score_weight="$2"
  local eta_slash="$3"
  local lo_mult="$4"
  local preserve_correct="$5"
  local corrupt_rate="$6"
  local fixture="$TMP_DIR/fixture.txt"
  local scenario
  local csv_path

  scenario="$(make_label "$credit_mode" "$preserve_correct" "$lo_mult" "$score_weight" "$eta_slash" "$corrupt_rate")"
  csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"

  make_fixture "$fixture" "$KEY_COUNT"
  run_dmv02 "$fixture" "$csv_path" "$credit_mode" "$score_weight" "$eta_slash" "$lo_mult" "$preserve_correct" "$corrupt_rate"
  append_summary "$scenario" "$credit_mode" "$score_weight" "$eta_slash" "$lo_mult" "$preserve_correct" "$corrupt_rate" "$csv_path"
}

run_smoke() {
  run_case "off" 1.0 0.10 7.5 0 0.10
  run_case "off" 1.0 0.10 10.0 0 0.25
  run_case "value-pos" 1.0 0.10 7.5 1 0.10
  run_case "value-pos" 1.0 0.20 10.0 0 0.25
  run_case "value-pos" 2.0 0.10 10.0 1 0.25
  run_case "value-pos" 2.0 0.20 7.5 0 0.10
  run_case "query-value" 1.0 0.20 7.5 1 0.25
  run_case "query-value" 1.0 0.10 10.0 0 0.10
  run_case "query-value" 2.0 0.20 10.0 1 0.10
  run_case "query-value" 2.0 0.10 7.5 0 0.25
}

run_full() {
  local credit_mode
  local score_weight
  local eta_slash
  local lo_mult
  local preserve_correct
  local corrupt_rate

  for credit_mode in value-pos query-value; do
    for preserve_correct in 1 0; do
      for lo_mult in "$FALLBACK_LO_75" "$FALLBACK_LO_10"; do
        for score_weight in 0.5 1.0 2.0 4.0; do
          for eta_slash in 0.10 0.20 0.40; do
            for corrupt_rate in 0.10 0.25 0.50; do
              run_case "$credit_mode" "$score_weight" "$eta_slash" "$lo_mult" "$preserve_correct" "$corrupt_rate"
            done
          done
        done
      done
    done
  done
  for preserve_correct in 1 0; do
    for lo_mult in "$FALLBACK_LO_75" "$FALLBACK_LO_10"; do
      for corrupt_rate in 0.10 0.25 0.50; do
        run_case "off" 1.0 0.10 "$lo_mult" "$preserve_correct" "$corrupt_rate"
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
