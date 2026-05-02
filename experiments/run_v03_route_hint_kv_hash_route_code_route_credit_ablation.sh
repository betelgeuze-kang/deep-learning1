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
WEAK_SCORE_WEIGHT=0.5
HEAVY_SCORE_WEIGHT=4.0
FALLBACK_HI_MULT=5.0
FALLBACK_LO_5=5.0
FALLBACK_LO_75=7.5
FALLBACK_LO_10=10.0
FALLBACK_LO_15=15.0

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_route_credit_ablation_smoke"
  KEY_COUNT=32
  EPOCHS=6
  CYCLES_PER_EPOCH=10
  PROPOSAL_COUNT=20
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_route_credit_ablation"
  KEY_COUNT=128
  EPOCHS=24
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
else
  PREFIX="v03_route_hint_kv_hash_route_code_route_credit_ablation"
  KEY_COUNT=64
  EPOCHS=16
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_credit_status,route_credit_blocker,route_credit_learning,route_credit_mode,route_credit_score_weight,route_credit_eta_reward,route_credit_eta_slash,route_credit_decay,route_credit_clip,route_fallback_source,route_fallback_strength_mode,route_fallback_strength_mult,route_fallback_hi_strength_mult,route_fallback_lo_strength_mult,route_fallback_channel_strength_mode,route_corrupt_preserve_correct,route_corrupt_candidate_rate,fixture_query_byte_acc,route_credit_correct_mean,route_credit_wrong_mean,route_credit_gap,route_credit_rewarded_rate,route_credit_slashed_rate,route_credit_top1_rate,route_credit_qacc,route_value_top_correct_rate,route_hint_correct_value_vote_share_mean,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_fallback_hi_acc,route_fallback_lo_acc,route_fallback_effective_strength_mean,route_fallback_hi_effective_strength_mean,route_fallback_lo_effective_strength_mean\n' >"$SUMMARY_CSV"

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
      split("fixture_query_byte_acc route_credit_correct_mean route_credit_wrong_mean route_credit_gap route_credit_rewarded_rate route_credit_slashed_rate route_credit_top1_rate route_credit_qacc route_value_top_correct_rate route_hint_correct_value_vote_share_mean route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean", names, " ")
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
        if (i > 1) {
          printf ","
        }
        name = names[i]
        printf "%.6f", sum[name] / count
      }
    }
  ' "$csv_path"
}

sanitize_blocker() {
  tr '\n' ' ' | tr -s ' ' | sed 's/,/; /g; s/^ //; s/ $//'
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
  local fallback_source="${10}"
  local fallback_strength_mode="${11}"
  local fallback_strength_mult="${12}"
  local fallback_hi_mult="${13}"
  local fallback_lo_mult="${14}"
  local fallback_channel_mode="${15}"
  local preserve_correct="${16}"
  local candidate_rate="${17}"
  local n

  n="$(wc -c <"$fixture")"

  echo "route-code route-credit ablation: mode=${credit_mode} weight=${score_weight} fallback=${fallback_source} preserve=${preserve_correct}" >&2
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
    --route-fallback-source "$fallback_source" \
    --route-fallback-strength-mode "$fallback_strength_mode" \
    --route-fallback-strength-mult "$fallback_strength_mult" \
    --route-fallback-hi-strength-mult "$fallback_hi_mult" \
    --route-fallback-lo-strength-mult "$fallback_lo_mult" \
    --route-fallback-channel-strength-mode "$fallback_channel_mode" \
    --route-credit-learning "$credit_learning" \
    --route-credit-mode "$credit_mode" \
    --route-credit-score-weight "$score_weight" \
    --route-credit-eta-reward "$eta_reward" \
    --route-credit-eta-slash "$eta_slash" \
    --route-credit-decay "$decay" \
    --route-credit-clip "$clip" \
    --csv "$csv_path"
}

append_run_summary() {
  local scenario="$1"
  local credit_learning="$2"
  local credit_mode="$3"
  local score_weight="$4"
  local eta_reward="$5"
  local eta_slash="$6"
  local decay="$7"
  local clip="$8"
  local fallback_source="$9"
  local fallback_strength_mode="${10}"
  local fallback_strength_mult="${11}"
  local fallback_hi_mult="${12}"
  local fallback_lo_mult="${13}"
  local fallback_channel_mode="${14}"
  local preserve_correct="${15}"
  local candidate_rate="${16}"
  local csv_path="${17}"
  local metrics

  metrics="$(compute_metrics "$csv_path")"
  printf '%s,run,-,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%s,%.6f,%.6f,%.6f,%s,%d,%.6f,%s\n' \
    "$scenario" \
    "$credit_learning" \
    "$credit_mode" \
    "$score_weight" \
    "$eta_reward" \
    "$eta_slash" \
    "$decay" \
    "$clip" \
    "$fallback_source" \
    "$fallback_strength_mode" \
    "$fallback_strength_mult" \
    "$fallback_hi_mult" \
    "$fallback_lo_mult" \
    "$fallback_channel_mode" \
    "$preserve_correct" \
    "$candidate_rate" \
    "$metrics" >>"$SUMMARY_CSV"
}

append_blocked_summary() {
  local scenario="$1"
  local blocker="$2"
  local credit_learning="$3"
  local credit_mode="$4"
  local score_weight="$5"
  local eta_reward="$6"
  local eta_slash="$7"
  local decay="$8"
  local clip="$9"
  local fallback_source="${10}"
  local fallback_strength_mode="${11}"
  local fallback_strength_mult="${12}"
  local fallback_hi_mult="${13}"
  local fallback_lo_mult="${14}"
  local fallback_channel_mode="${15}"
  local preserve_correct="${16}"
  local candidate_rate="${17}"
  local na_metrics

  na_metrics="$(printf 'NA,%.0s' {1..19})"
  na_metrics="${na_metrics%,}"
  printf '%s,blocked,%s,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%s,%.6f,%.6f,%.6f,%s,%d,%.6f,%s\n' \
    "$scenario" \
    "$blocker" \
    "$credit_learning" \
    "$credit_mode" \
    "$score_weight" \
    "$eta_reward" \
    "$eta_slash" \
    "$decay" \
    "$clip" \
    "$fallback_source" \
    "$fallback_strength_mode" \
    "$fallback_strength_mult" \
    "$fallback_hi_mult" \
    "$fallback_lo_mult" \
    "$fallback_channel_mode" \
    "$preserve_correct" \
    "$candidate_rate" \
    "$na_metrics" >>"$SUMMARY_CSV"
}

run_case() {
  local scenario="$1"
  local credit_learning="$2"
  local credit_mode="$3"
  local score_weight="$4"
  local eta_reward="$5"
  local eta_slash="$6"
  local decay="$7"
  local clip="$8"
  local fallback_source="$9"
  local fallback_strength_mode="${10}"
  local fallback_strength_mult="${11}"
  local fallback_hi_mult="${12}"
  local fallback_lo_mult="${13}"
  local fallback_channel_mode="${14}"
  local preserve_correct="${15}"
  local candidate_rate="${16}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local stderr_path="$TMP_DIR/${scenario}.stderr"
  local rc
  local blocker

  make_fixture "$fixture" "$KEY_COUNT"
  rm -f "$csv_path" "$stderr_path"

  if [[ "$credit_mode" == "query-value" ]]; then
    set +e
    run_dmv02 \
      "$fixture" "$csv_path" "$credit_learning" "$credit_mode" \
      "$score_weight" "$eta_reward" "$eta_slash" "$decay" "$clip" \
      "$fallback_source" "$fallback_strength_mode" "$fallback_strength_mult" \
      "$fallback_hi_mult" "$fallback_lo_mult" "$fallback_channel_mode" \
      "$preserve_correct" "$candidate_rate" \
      >"$TMP_DIR/${scenario}.stdout" 2>"$stderr_path"
    rc=$?
    set -e
    if [[ "$rc" -eq 0 ]]; then
      append_run_summary \
        "$scenario" "$credit_learning" "$credit_mode" "$score_weight" \
        "$eta_reward" "$eta_slash" "$decay" "$clip" "$fallback_source" \
        "$fallback_strength_mode" "$fallback_strength_mult" \
        "$fallback_hi_mult" "$fallback_lo_mult" "$fallback_channel_mode" \
        "$preserve_correct" "$candidate_rate" "$csv_path"
    else
      rm -f "$csv_path"
      if [[ -f "$stderr_path" ]]; then
        blocker="$(sanitize_blocker <"$stderr_path")"
      else
        blocker=""
      fi
      [[ -n "$blocker" ]] || blocker="query-value mode is not supported by the current C++ build"
      append_blocked_summary \
        "$scenario" "$blocker" "$credit_learning" "$credit_mode" \
        "$score_weight" "$eta_reward" "$eta_slash" "$decay" "$clip" \
        "$fallback_source" "$fallback_strength_mode" "$fallback_strength_mult" \
        "$fallback_hi_mult" "$fallback_lo_mult" "$fallback_channel_mode" \
        "$preserve_correct" "$candidate_rate"
      echo "query-value mode blocked: $blocker" >&2
    fi
    return 0
  fi

  run_dmv02 \
    "$fixture" "$csv_path" "$credit_learning" "$credit_mode" \
    "$score_weight" "$eta_reward" "$eta_slash" "$decay" "$clip" \
    "$fallback_source" "$fallback_strength_mode" "$fallback_strength_mult" \
    "$fallback_hi_mult" "$fallback_lo_mult" "$fallback_channel_mode" \
    "$preserve_correct" "$candidate_rate"
  append_run_summary \
    "$scenario" "$credit_learning" "$credit_mode" "$score_weight" \
    "$eta_reward" "$eta_slash" "$decay" "$clip" "$fallback_source" \
    "$fallback_strength_mode" "$fallback_strength_mult" "$fallback_hi_mult" \
    "$fallback_lo_mult" "$fallback_channel_mode" "$preserve_correct" \
    "$candidate_rate" "$csv_path"
}

run_smoke() {
  run_case "value-pos-base" 0 "value-pos" "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
  run_case "value-pos-strong-slash" 1 "value-pos" "$STRONG_SCORE_WEIGHT" "$STRONG_ETA_REWARD" "$STRONG_ETA_SLASH" "$STRONG_DECAY" "$STRONG_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
  run_case "fallback-lo7p5-off" 0 "value-pos" "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "key-shape" "fixed" 1.0 "$FALLBACK_HI_MULT" "$FALLBACK_LO_75" "fixed" 0 0.25
  run_case "fallback-lo10-on" 1 "value-pos" "$STRONG_SCORE_WEIGHT" "$STRONG_ETA_REWARD" "$STRONG_ETA_SLASH" "$STRONG_DECAY" "$STRONG_CLIP" "key-shape" "fixed" 1.0 "$FALLBACK_HI_MULT" "$FALLBACK_LO_10" "fixed" 0 0.25
  run_case "query-value-probe" 1 "query-value" "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
}

run_full() {
  run_case "value-pos-base" 0 "value-pos" "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
  run_case "value-pos-weight0p5" 1 "value-pos" "$WEAK_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
  run_case "value-pos-strong-slash" 1 "value-pos" "$STRONG_SCORE_WEIGHT" "$STRONG_ETA_REWARD" "$STRONG_ETA_SLASH" "$STRONG_DECAY" "$STRONG_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
  run_case "value-pos-weight4" 1 "value-pos" "$HEAVY_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
  run_case "fallback-lo5-off" 0 "value-pos" "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "key-shape" "fixed" 1.0 "$FALLBACK_HI_MULT" "$FALLBACK_LO_5" "fixed" 0 0.25
  run_case "fallback-lo7p5-off" 0 "value-pos" "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "key-shape" "fixed" 1.0 "$FALLBACK_HI_MULT" "$FALLBACK_LO_75" "fixed" 0 0.25
  run_case "fallback-lo10-on" 1 "value-pos" "$STRONG_SCORE_WEIGHT" "$STRONG_ETA_REWARD" "$STRONG_ETA_SLASH" "$STRONG_DECAY" "$STRONG_CLIP" "key-shape" "fixed" 1.0 "$FALLBACK_HI_MULT" "$FALLBACK_LO_10" "fixed" 0 0.25
  run_case "fallback-lo15-on" 1 "value-pos" "$STRONG_SCORE_WEIGHT" "$STRONG_ETA_REWARD" "$STRONG_ETA_SLASH" "$STRONG_DECAY" "$STRONG_CLIP" "key-shape" "fixed" 1.0 "$FALLBACK_HI_MULT" "$FALLBACK_LO_15" "fixed" 0 0.25
  run_case "query-value-probe" 1 "query-value" "$BASE_SCORE_WEIGHT" "$BASE_ETA_REWARD" "$BASE_ETA_SLASH" "$BASE_DECAY" "$BASE_CLIP" "off" "fixed" 1.0 1.0 1.0 "fixed" 1 0.25
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
