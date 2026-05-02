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

CORRUPT_RATE=0.25
CONFIDENCE_THRESHOLD=0.75
FALLBACK_HI_MULT=5.0

BASE_SCORE_WEIGHT=1.0
BASE_ETA_REWARD=0.05
BASE_ETA_SLASH=0.10
BASE_DECAY=0.001
BASE_CLIP=4.0

STRONG_SCORE_WEIGHT=2.0
STRONG_ETA_REWARD=0.05
STRONG_ETA_SLASH=0.20
STRONG_DECAY=0.0
STRONG_CLIP=2.0

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_credit_fallback_factorial_smoke"
  KEY_COUNT=32
  EPOCHS=5
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=20
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_credit_fallback_factorial"
  KEY_COUNT=128
  EPOCHS=20
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
else
  PREFIX="v03_route_hint_kv_hash_route_code_credit_fallback_factorial"
  KEY_COUNT=64
  EPOCHS=12
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,credit_variant,route_credit_learning,route_credit_mode,route_credit_score_weight,route_credit_eta_reward,route_credit_eta_slash,route_credit_decay,route_credit_clip,route_fallback_source,route_fallback_hi_strength_mult,route_fallback_lo_strength_mult,route_corrupt_preserve_correct,route_corrupt_candidate_rate,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_candidate_corrupt_rate,route_primary_recall,route_primary_lowconf_rate,route_credit_correct_mean,route_credit_wrong_mean,route_credit_gap,route_credit_rewarded_rate,route_credit_slashed_rate,route_credit_top1_rate,route_credit_qacc,route_value_top_correct_rate,route_hint_correct_value_vote_share_mean,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_fallback_hi_acc,route_fallback_lo_acc,route_fallback_effective_strength_mean,route_fallback_hi_effective_strength_mean,route_fallback_lo_effective_strength_mean,route_lowconf_query_rate,route_highconf_query_rate,route_lowconf_qacc,route_highconf_qacc,route_lowconf_candidate_recall,route_highconf_candidate_recall,route_lowconf_top1,route_highconf_top1,route_agg_policy_vote_rate,route_agg_policy_weighted_rate,route_abstain_rate\n' >"$SUMMARY_CSV"

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

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc route_candidate_corrupt_rate route_primary_recall route_primary_lowconf_rate route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_value_top_correct_rate route_hint_correct_value_vote_share_mean route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1 route_agg_policy_vote_rate route_agg_policy_weighted_rate route_abstain_rate", names, " ")
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

run_dmv02() {
  local fixture="$1"
  local csv_path="$2"
  local credit_learning="$3"
  local credit_mode="$4"
  local score_weight="$5"
  local eta_reward="$6"
  local eta_slash="$7"
  local decay="$8"
  local clip="$9"
  local lo_mult="${10}"
  local preserve_correct="${11}"
  local candidate_rate="${12}"
  local n

  n="$(wc -c <"$fixture")"

  echo "credit×fallback factorial: mode=${credit_mode} learning=${credit_learning} lo=${lo_mult} preserve=${preserve_correct}" >&2
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
    --route-corrupt-candidate-rate "$candidate_rate" \
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
    --route-credit-eta-reward "$eta_reward" \
    --route-credit-eta-slash "$eta_slash" \
    --route-credit-decay "$decay" \
    --route-credit-clip "$clip" \
    --csv "$csv_path"
}

append_summary() {
  local scenario="$1"
  local credit_variant="$2"
  local credit_learning="$3"
  local credit_mode="$4"
  local score_weight="$5"
  local eta_reward="$6"
  local eta_slash="$7"
  local decay="$8"
  local clip="$9"
  local lo_mult="${10}"
  local preserve_correct="${11}"
  local candidate_rate="${12}"
  local clean_reference="${13}"
  local csv_path="${14}"
  local metrics
  local qacc
  local rest_metrics

  metrics="$(compute_metrics "$csv_path")"
  qacc="${metrics%%,*}"
  rest_metrics="${metrics#*,}"
  printf '%s,%s,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,key-shape,%.6f,%.6f,%d,%.6f,%s,%.6f,%.6f,%s\n' \
    "$scenario" \
    "$credit_variant" \
    "$credit_learning" \
    "$credit_mode" \
    "$score_weight" \
    "$eta_reward" \
    "$eta_slash" \
    "$decay" \
    "$clip" \
    "$FALLBACK_HI_MULT" \
    "$lo_mult" \
    "$preserve_correct" \
    "$candidate_rate" \
    "$qacc" \
    "$clean_reference" \
    "$(awk -v clean="$clean_reference" -v qacc="$qacc" 'BEGIN { printf "%.6f", clean - qacc }')" \
    "$rest_metrics" >>"$SUMMARY_CSV"
}

get_clean_reference() {
  local cache_file="$TMP_DIR/clean_reference.qacc"

  if [[ ! -f "$cache_file" ]]; then
    local fixture="$TMP_DIR/clean_reference.txt"
    local csv_path="$TMP_DIR/clean_reference.csv"
    make_fixture "$fixture" "$KEY_COUNT"
    run_dmv02 \
      "$fixture" "$csv_path" 0 "off" \
      "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" \
      7.5 1 0.0
    compute_metrics "$csv_path" | cut -d, -f1 >"$cache_file"
  fi

  cat "$cache_file"
}

run_case() {
  local credit_variant="$1"
  local lo_label="$2"
  local lo_mult="$3"
  local preserve_correct="$4"
  local credit_learning
  local credit_mode
  local score_weight
  local eta_reward
  local eta_slash
  local decay
  local clip
  local pc_label
  local scenario
  local fixture
  local csv_path
  local clean_reference

  if [[ "$credit_variant" == "off" ]]; then
    credit_learning=0
    credit_mode="off"
    score_weight="$BASE_SCORE_WEIGHT"
    eta_reward="$BASE_ETA_REWARD"
    eta_slash="$BASE_ETA_SLASH"
    decay="$BASE_DECAY"
    clip="$BASE_CLIP"
  elif [[ "$credit_variant" == "value-pos" ]]; then
    credit_learning=1
    credit_mode="value-pos"
    score_weight="$STRONG_SCORE_WEIGHT"
    eta_reward="$STRONG_ETA_REWARD"
    eta_slash="$STRONG_ETA_SLASH"
    decay="$STRONG_DECAY"
    clip="$STRONG_CLIP"
  elif [[ "$credit_variant" == "query-value" ]]; then
    credit_learning=1
    credit_mode="query-value"
    score_weight="$STRONG_SCORE_WEIGHT"
    eta_reward="$STRONG_ETA_REWARD"
    eta_slash="$STRONG_ETA_SLASH"
    decay="$STRONG_DECAY"
    clip="$STRONG_CLIP"
  else
    echo "unknown credit variant: $credit_variant" >&2
    exit 2
  fi

  pc_label="remove"
  if [[ "$preserve_correct" -eq 1 ]]; then
    pc_label="preserve"
  fi

  scenario="${pc_label}_${lo_label}_${credit_variant}"
  scenario="${scenario//-/_}"
  fixture="$TMP_DIR/${scenario}.txt"
  csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  make_fixture "$fixture" "$KEY_COUNT"
  rm -f "$csv_path"

  run_dmv02 \
    "$fixture" "$csv_path" "$credit_learning" "$credit_mode" \
    "$score_weight" "$eta_reward" "$eta_slash" "$decay" "$clip" \
    "$lo_mult" "$preserve_correct" "$CORRUPT_RATE"
  clean_reference="$(get_clean_reference)"
  append_summary \
    "$scenario" "$credit_variant" "$credit_learning" "$credit_mode" \
    "$score_weight" "$eta_reward" "$eta_slash" "$decay" "$clip" \
    "$lo_mult" "$preserve_correct" "$CORRUPT_RATE" "$clean_reference" "$csv_path"
}

run_grid() {
  local preserve
  local lo
  local lo_label
  local variant

  for preserve in 1 0; do
    for lo in 7.5 10.0 15.0; do
      lo_label="lo${lo}"
      lo_label="${lo_label//./p}"
      for variant in off value-pos query-value; do
        run_case "$variant" "$lo_label" "$lo" "$preserve"
      done
    done
  done
}

run_grid

echo "wrote $SUMMARY_CSV"
