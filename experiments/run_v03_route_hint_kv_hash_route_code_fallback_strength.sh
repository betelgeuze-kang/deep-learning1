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
CORRUPT_RATE_SMOKE=0.25
CONFIDENCE_THRESHOLD=0.75

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_strength_smoke"
  EPOCHS=10
  REMOVE_MULTS=(1.0 2.0 5.0 10.0)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_strength"
  EPOCHS=16
  REMOVE_MULTS=(0.5 1.0 2.0 5.0 10.0 20.0)
else
  PREFIX="v03_route_hint_kv_hash_route_code_fallback_strength"
  EPOCHS=12
  REMOVE_MULTS=(1.0 2.0 5.0 10.0)
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_corrupt_preserve_correct,route_corrupt_candidate_rate,route_fallback_strength_mult,route_delta_mode,route_pull_scale,route_push_scale,route_fallback_source,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_candidate_corrupt_rate,route_primary_recall,route_primary_lowconf_rate,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_abstain_rate,route_lowconf_query_rate,route_highconf_query_rate,route_lowconf_qacc,route_highconf_qacc,route_lowconf_candidate_recall,route_highconf_candidate_recall,route_lowconf_top1,route_highconf_top1,route_fallback_hi_acc,route_fallback_lo_acc,route_fallback_route_margin_mean,route_fallback_effective_strength_mean\n' >"$SUMMARY_CSV"

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
    local key=$((14000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((14000 + i))
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
  local delta_mode="$3"
  local pull_scale="$4"
  local push_scale="$5"
  local fallback_source="$6"
  local fallback_strength_mult="$7"
  local preserve_correct="$8"
  local corrupt_rate="$9"
  local n

  n="$(wc -c <"$fixture")"

  echo "route-code fallback strength: ${delta_mode} pull=${pull_scale} push=${push_scale} fallback=${fallback_source} mult=${fallback_strength_mult} (pc=${preserve_correct}, cr=${corrupt_rate})" >&2
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
    --route-fallback-source "$fallback_source" \
    --route-fallback-strength-mult "$fallback_strength_mult" \
    --route-delta-mode "$delta_mode" \
    --route-pull-scale "$pull_scale" \
    --route-push-scale "$push_scale" \
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
  local delta_mode="$1"
  local pull_scale="$2"
  local push_scale="$3"
  local fallback_source="$4"
  local cache_key="${delta_mode}_${fallback_source}_pull${pull_scale//./p}_push${push_scale//./p}"
  local cache_file="$TMP_DIR/clean_reference_${cache_key}.qacc"

  if [[ ! -f "$cache_file" ]]; then
    local fixture="$TMP_DIR/clean_reference_${cache_key}.txt"
    local csv_path="$TMP_DIR/clean_reference_${cache_key}.csv"
    make_fixture "$fixture" "$KEY_COUNT"
    run_dmv02 "$fixture" "$csv_path" "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source" 1.0 1 0.0
    last5_mean "$csv_path" fixture_query_byte_acc >"$cache_file"
  fi

  cat "$cache_file"
}

append_summary() {
  local scenario="$1"
  local preserve_correct="$2"
  local corrupt_rate="$3"
  local fallback_strength_mult="$4"
  local delta_mode="$5"
  local pull_scale="$6"
  local push_scale="$7"
  local fallback_source="$8"
  local clean_reference="$9"
  local csv_path="${10}"

  awk -F, \
    -v scenario="$scenario" \
    -v preserve_correct="$preserve_correct" \
    -v corrupt_rate="$corrupt_rate" \
    -v fallback_strength_mult="$fallback_strength_mult" \
    -v delta_mode="$delta_mode" \
    -v pull_scale="$pull_scale" \
    -v push_scale="$push_scale" \
    -v fallback_source="$fallback_source" \
    -v clean_reference="$clean_reference" '
    BEGIN {
      split("fixture_query_byte_acc route_candidate_corrupt_rate route_primary_recall route_primary_lowconf_rate route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_abstain_rate route_lowconf_query_rate route_highconf_query_rate route_lowconf_qacc route_highconf_qacc route_lowconf_candidate_recall route_highconf_candidate_recall route_lowconf_top1 route_highconf_top1", core_names, " ")
      split("route_fallback_hi_acc route_fallback_lo_acc route_fallback_route_margin_mean route_fallback_effective_strength_mean", optional_names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        idx[$i] = i
      }
      for (i = 1; i <= length(core_names); i++) {
        if (!(core_names[i] in idx)) {
          printf "missing column: %s in %s\n", core_names[i], FILENAME > "/dev/stderr"
          exit 2
        }
      }
      for (i = 1; i <= length(optional_names); i++) {
        if (!(optional_names[i] in idx)) {
          printf "missing column: %s in %s\n", optional_names[i], FILENAME > "/dev/stderr"
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
        for (i = 1; i <= length(core_names); i++) {
          name = core_names[i]
          sum[name] += row[idx[name]] + 0
        }
        for (i = 1; i <= length(optional_names); i++) {
          name = optional_names[i]
          opt_sum[name] += row[idx[name]] + 0
        }
      }
      qacc = sum["fixture_query_byte_acc"] / count
      damage = clean_reference - qacc
      printf "%s,%s,%.6f,%.6f,%s,%.6f,%.6f,%s,%.6f,%.6f,%.6f", scenario, preserve_correct, corrupt_rate, fallback_strength_mult, delta_mode, pull_scale, push_scale, fallback_source, qacc, clean_reference, damage
      for (i = 2; i <= length(core_names); i++) {
        name = core_names[i]
        printf ",%.6f", sum[name] / count
      }
      for (i = 1; i <= length(optional_names); i++) {
        name = optional_names[i]
        printf ",%.6f", opt_sum[name] / count
      }
      printf "\n"
    }
  ' "$csv_path" >>"$SUMMARY_CSV"
}

run_case() {
  local scenario="$1"
  local delta_mode="$2"
  local pull_scale="$3"
  local push_scale="$4"
  local fallback_source="$5"
  local fallback_strength_mult="$6"
  local preserve_correct="$7"
  local corrupt_rate="$8"
  local safe_pull="${pull_scale//./p}"
  local safe_push="${push_scale//./p}"
  local safe_mult="${fallback_strength_mult//./p}"
  local safe_rate="${corrupt_rate//./p}"
  local label="${scenario}_${delta_mode}_pull${safe_pull}_push${safe_push}_${fallback_source}_m${safe_mult}_pc${preserve_correct}_cr${safe_rate}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local clean_reference

  make_fixture "$fixture" "$KEY_COUNT"
  clean_reference="$(get_clean_reference "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source")"
  run_dmv02 "$fixture" "$csv_path" "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source" "$fallback_strength_mult" "$preserve_correct" "$corrupt_rate"
  append_summary "$scenario" "$preserve_correct" "$corrupt_rate" "$fallback_strength_mult" "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source" "$clean_reference" "$csv_path"
}

run_mode_group() {
  local label_prefix="$1"
  local delta_mode="$2"
  local pull_scale="$3"
  local push_scale="$4"
  local fallback_source="$5"
  local corrupt_rate="$6"

  run_case "preserve-${label_prefix}" "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source" 1.0 1 "$corrupt_rate"
  for fallback_strength_mult in "${REMOVE_MULTS[@]}"; do
    local safe_mult="${fallback_strength_mult//./p}"
    run_case "remove-${label_prefix}-m${safe_mult}" "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source" "$fallback_strength_mult" 0 "$corrupt_rate"
  done
}

run_sweep() {
  run_mode_group target-only target-only 1.0 1.0 key-shape "$CORRUPT_RATE_SMOKE"
  run_mode_group projected-pull2 projected 2.0 1.0 key-shape "$CORRUPT_RATE_SMOKE"
}

run_sweep

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
