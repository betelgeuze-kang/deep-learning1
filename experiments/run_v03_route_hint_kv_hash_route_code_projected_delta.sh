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
  PREFIX="v03_route_hint_kv_hash_route_code_projected_delta_smoke"
  EPOCHS=10
else
  PREFIX="v03_route_hint_kv_hash_route_code_projected_delta"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_corrupt_preserve_correct,route_corrupt_candidate_rate,route_delta_mode,route_pull_scale,route_push_scale,route_fallback_source,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_candidate_corrupt_rate,route_primary_recall,route_primary_lowconf_rate,route_fallback_used_rate,route_fallback_recall,route_fallback_qacc,route_fallback_success_rate,route_abstain_rate,route_lowconf_query_rate,route_highconf_query_rate,route_lowconf_qacc,route_highconf_qacc,route_lowconf_candidate_recall,route_highconf_candidate_recall,route_lowconf_top1,route_highconf_top1,route_fallback_hi_acc,route_fallback_lo_acc,route_fallback_route_margin_mean,route_fallback_effective_strength_mean\n' >"$SUMMARY_CSV"

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
  local preserve_correct="$7"
  local corrupt_rate="$8"
  local n

  n="$(wc -c <"$fixture")"

  echo "route-code projected delta: ${delta_mode} pull=${pull_scale} push=${push_scale} fallback=${fallback_source} (pc=${preserve_correct}, cr=${corrupt_rate})" >&2
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
  local fallback_source="$2"
  local pull_scale="$3"
  local push_scale="$4"
  local safe_pull="${pull_scale//./p}"
  local safe_push="${push_scale//./p}"
  local cache_key="${delta_mode}_${fallback_source}_pull${safe_pull}_push${safe_push}"
  local cache_file="$TMP_DIR/clean_reference_${cache_key}.qacc"

  if [[ ! -f "$cache_file" ]]; then
    local fixture="$TMP_DIR/clean_reference_${cache_key}.txt"
    local csv_path="$TMP_DIR/clean_reference_${cache_key}.csv"
    make_fixture "$fixture" "$KEY_COUNT"
    run_dmv02 "$fixture" "$csv_path" "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source" 1 0.0
    last5_mean "$csv_path" fixture_query_byte_acc >"$cache_file"
  fi

  cat "$cache_file"
}

append_summary() {
  local scenario="$1"
  local preserve_correct="$2"
  local corrupt_rate="$3"
  local delta_mode="$4"
  local pull_scale="$5"
  local push_scale="$6"
  local fallback_source="$7"
  local clean_reference="$8"
  local csv_path="$9"

  awk -F, \
    -v scenario="$scenario" \
    -v preserve_correct="$preserve_correct" \
    -v corrupt_rate="$corrupt_rate" \
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
          if (name in idx) {
            opt_sum[name] += row[idx[name]] + 0
          }
        }
      }
      qacc = sum["fixture_query_byte_acc"] / count
      damage = clean_reference - qacc
      printf "%s,%s,%.6f,%s,%.6f,%.6f,%s,%.6f,%.6f,%.6f", scenario, preserve_correct, corrupt_rate, delta_mode, pull_scale, push_scale, fallback_source, qacc, clean_reference, damage
      for (i = 2; i <= length(core_names); i++) {
        name = core_names[i]
        printf ",%.6f", sum[name] / count
      }
      for (i = 1; i <= length(optional_names); i++) {
        name = optional_names[i]
        if (name in idx) {
          printf ",%.6f", opt_sum[name] / count
        } else {
          printf ","
        }
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
  local preserve_correct="$6"
  local corrupt_rate="$7"
  local safe_pull="${pull_scale//./p}"
  local safe_push="${push_scale//./p}"
  local safe_rate="${corrupt_rate//./p}"
  local label="${scenario}_${delta_mode}_pull${safe_pull}_push${safe_push}_${fallback_source}_pc${preserve_correct}_cr${safe_rate}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local clean_reference

  make_fixture "$fixture" "$KEY_COUNT"
  clean_reference="$(get_clean_reference "$delta_mode" "$fallback_source" "$pull_scale" "$push_scale")"
  run_dmv02 "$fixture" "$csv_path" "$delta_mode" "$pull_scale" "$push_scale" "$fallback_source" "$preserve_correct" "$corrupt_rate"
  append_summary \
    "$scenario" \
    "$preserve_correct" \
    "$corrupt_rate" \
    "$delta_mode" \
    "$pull_scale" \
    "$push_scale" \
    "$fallback_source" \
    "$clean_reference" \
    "$csv_path"
}

run_smoke() {
  # Compare target-only vs projected at the expected parity setting first, then
  # keep projected pull=2.0/push=1.0 as the actual smoke intervention.
  run_case preserve-off-target-only target-only 1.0 1.0 off 1 "$CORRUPT_RATE_SMOKE"
  run_case preserve-off-projected projected 1.0 1.0 off 1 "$CORRUPT_RATE_SMOKE"
  run_case preserve-off-projected-pull2 projected 2.0 1.0 off 1 "$CORRUPT_RATE_SMOKE"
  run_case remove-key-shape-target-only target-only 1.0 1.0 key-shape 0 "$CORRUPT_RATE_SMOKE"
  run_case remove-key-shape-projected projected 1.0 1.0 key-shape 0 "$CORRUPT_RATE_SMOKE"
  run_case remove-key-shape-projected-pull2 projected 2.0 1.0 key-shape 0 "$CORRUPT_RATE_SMOKE"
}

run_scale_sweep() {
  local pull_scales=()
  local push_scales=()

  if [[ "$MODE" == "full" ]]; then
    pull_scales=(0.25 0.5 1.0 1.5 2.0)
    push_scales=(0.25 0.5 1.0 1.5)
  else
    pull_scales=(0.5 1.0 1.5 2.0)
    push_scales=(0.5 1.0 1.5)
  fi

  for pull_scale in "${pull_scales[@]}"; do
    for push_scale in "${push_scales[@]}"; do
      run_case remove-key-shape-sweep projected "$pull_scale" "$push_scale" key-shape 0 "$CORRUPT_RATE_SMOKE"
    done
  done
}

if [[ "$MODE" == "smoke" ]]; then
  run_smoke
else
  run_smoke
  run_scale_sweep
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
