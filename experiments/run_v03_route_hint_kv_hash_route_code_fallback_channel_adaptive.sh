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
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_channel_adaptive_smoke"
  EPOCHS=10
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_channel_adaptive"
  EPOCHS=16
else
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_channel_adaptive"
  EPOCHS=12
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_fallback_channel_strength_mode,route_fallback_hi_margin_alpha,route_fallback_lo_margin_alpha,route_fallback_hi_lambda_max,route_fallback_lo_lambda_max,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_primary_recall,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_fallback_hi_acc,route_fallback_lo_acc,route_fallback_effective_strength_mean,route_fallback_hi_effective_strength_mean,route_fallback_lo_effective_strength_mean,route_fallback_hi_local_margin_against_route_mean,route_fallback_lo_local_margin_against_route_mean\n' >"$SUMMARY_CSV"

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
    local key=$((16000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((16000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

last5_mean() {
  local csv_path="$1"
  local column="$2"
  awk -F, -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    { rows[++row_count] = $0 }
    END {
      start = (row_count > 5 ? row_count - 4 : 1)
      count = row_count - start + 1
      for (r = start; r <= row_count; r++) {
        split(rows[r], row, FS)
        sum += row[idx[column]] + 0
      }
      printf "%.6f", sum / count
    }
  ' "$csv_path"
}

run_dmv02() {
  local fixture="$1"
  local csv_path="$2"
  local channel_mode="$3"
  local hi_alpha="$4"
  local lo_alpha="$5"
  local hi_max="$6"
  local lo_max="$7"
  local fallback_mult="$8"
  local fallback_hi_mult="$9"
  local fallback_lo_mult="${10}"
  local preserve_correct="${11}"
  local corrupt_rate="${12}"
  local n

  n="$(wc -c <"$fixture")"

  echo "route-code fallback channel adaptive: mode=${channel_mode} hi_a=${hi_alpha} lo_a=${lo_alpha} hi_max=${hi_max} lo_max=${lo_max}" >&2
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
    --route-fallback-source key-shape \
    --route-fallback-strength-mode fixed \
    --route-fallback-strength-mult "$fallback_mult" \
    --route-fallback-hi-strength-mult "$fallback_hi_mult" \
    --route-fallback-lo-strength-mult "$fallback_lo_mult" \
    --route-fallback-channel-strength-mode "$channel_mode" \
    --route-fallback-hi-margin-alpha "$hi_alpha" \
    --route-fallback-lo-margin-alpha "$lo_alpha" \
    --route-fallback-hi-lambda-max "$hi_max" \
    --route-fallback-lo-lambda-max "$lo_max" \
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
    --csv "$csv_path"
}

get_clean_reference() {
  local cache_file="$TMP_DIR/clean_reference.qacc"

  if [[ ! -f "$cache_file" ]]; then
    local fixture="$TMP_DIR/clean_reference.txt"
    local csv_path="$TMP_DIR/clean_reference.csv"
    make_fixture "$fixture" "$KEY_COUNT"
    run_dmv02 "$fixture" "$csv_path" fixed 0.0 0.0 50.0 50.0 5.0 1.0 1.0 1 0.0
    last5_mean "$csv_path" fixture_query_byte_acc >"$cache_file"
  fi

  cat "$cache_file"
}

append_summary() {
  local scenario="$1"
  local channel_mode="$2"
  local hi_alpha="$3"
  local lo_alpha="$4"
  local hi_max="$5"
  local lo_max="$6"
  local clean_reference="$7"
  local csv_path="$8"

  awk -F, \
    -v scenario="$scenario" \
    -v channel_mode="$channel_mode" \
    -v hi_alpha="$hi_alpha" \
    -v lo_alpha="$lo_alpha" \
    -v hi_max="$hi_max" \
    -v lo_max="$lo_max" \
    -v clean_reference="$clean_reference" '
    BEGIN {
      split("fixture_query_byte_acc route_primary_recall route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_fallback_hi_acc route_fallback_lo_acc route_fallback_effective_strength_mean route_fallback_hi_effective_strength_mean route_fallback_lo_effective_strength_mean route_fallback_hi_local_margin_against_route_mean route_fallback_lo_local_margin_against_route_mean", names, " ")
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
      for (r = start; r <= row_count; r++) {
        split(rows[r], row, FS)
        for (n = 1; n <= length(names); n++) {
          name = names[n]
          sum[name] += row[idx[name]] + 0
        }
      }
      qacc = sum["fixture_query_byte_acc"] / count
      printf "%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f", scenario, channel_mode, hi_alpha, lo_alpha, hi_max, lo_max, qacc, clean_reference, clean_reference - qacc
      for (n = 2; n <= length(names); n++) {
        name = names[n]
        printf ",%.6f", sum[name] / count
      }
      printf "\n"
    }
  ' "$csv_path" >>"$SUMMARY_CSV"
}

run_case() {
  local scenario="$1"
  local channel_mode="$2"
  local hi_alpha="$3"
  local lo_alpha="$4"
  local hi_max="$5"
  local lo_max="$6"
  local fallback_mult="$7"
  local fallback_hi_mult="$8"
  local fallback_lo_mult="$9"
  local preserve_correct="${10}"
  local corrupt_rate="${11}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local clean_reference

  make_fixture "$fixture" "$KEY_COUNT"
  clean_reference="$(get_clean_reference)"
  run_dmv02 "$fixture" "$csv_path" "$channel_mode" "$hi_alpha" "$lo_alpha" "$hi_max" "$lo_max" "$fallback_mult" "$fallback_hi_mult" "$fallback_lo_mult" "$preserve_correct" "$corrupt_rate"
  append_summary "$scenario" "$channel_mode" "$hi_alpha" "$lo_alpha" "$hi_max" "$lo_max" "$clean_reference" "$csv_path"
}

run_case "fixed-lo-boost" fixed 0.0 0.0 50.0 50.0 5.0 1.0 2.0 0 "$CORRUPT_RATE"
run_case "margin-balanced" margin 6.0 6.0 40.0 40.0 1.0 1.0 1.0 0 "$CORRUPT_RATE"
run_case "margin-lo-biased" margin 6.0 10.0 40.0 40.0 1.0 1.0 1.0 0 "$CORRUPT_RATE"
if [[ "$MODE" != "smoke" ]]; then
  run_case "margin-lo-strong" margin 6.0 14.0 40.0 40.0 1.0 1.0 1.0 0 "$CORRUPT_RATE"
fi

echo "wrote $SUMMARY_CSV"
