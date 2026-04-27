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

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_hash_route_code_adaptive_smoke"
  EPOCHS=10
else
  PREFIX="v03_route_hint_kv_hash_route_code_adaptive"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_strength_mode,key_count,lambda_route,lambda_route_base,lambda_route_max,route_margin_alpha,route_confidence_power,route_min_confidence,fixture_query_byte_acc,fixture_query_hi_acc,fixture_query_lo_acc,route_candidate_recall_rate,route_candidate_top1_rate,key_region_route_decode_acc,query_effective_route_margin_mean,route_strength_mean,route_strength_p50,route_strength_p90,route_strength_max,route_hint_applied_rate\n' >"$SUMMARY_CSV"

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
    local key=$((7000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((7000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

append_summary() {
  local scenario="$1"
  local route_strength_mode="$2"
  local key_count="$3"
  local lambda_route="$4"
  local lambda_route_base="$5"
  local lambda_route_max="$6"
  local route_margin_alpha="$7"
  local route_confidence_power="$8"
  local route_min_confidence="$9"
  local csv_path="${10}"

  awk -F, \
    -v scenario="$scenario" \
    -v route_strength_mode="$route_strength_mode" \
    -v key_count="$key_count" \
    -v lambda_route="$lambda_route" \
    -v lambda_route_base="$lambda_route_base" \
    -v lambda_route_max="$lambda_route_max" \
    -v route_margin_alpha="$route_margin_alpha" \
    -v route_confidence_power="$route_confidence_power" \
    -v route_min_confidence="$route_min_confidence" '
    BEGIN {
      split("fixture_query_byte_acc fixture_query_hi_acc fixture_query_lo_acc route_candidate_recall_rate route_candidate_top1_rate key_region_route_decode_acc query_effective_route_margin_mean route_strength_mean route_strength_p50 route_strength_p90 route_strength_max route_hint_applied_rate", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        idx[$i] = i
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
      printf "%s,%s,%d,%s,%s,%s,%s,%s,%s", scenario, route_strength_mode, key_count, lambda_route, lambda_route_base, lambda_route_max, route_margin_alpha, route_confidence_power, route_min_confidence
      for (n = 1; n <= length(names); n++) {
        name = names[n]
        printf ",%.6f", sum[name] / count
      }
      printf "\n"
    }
  ' "$csv_path" >>"$SUMMARY_CSV"
}

run_case() {
  local scenario="$1"
  local route_strength_mode="$2"
  local key_count="$3"
  local lambda_route="$4"
  local lambda_route_base="$5"
  local lambda_route_max="$6"
  local route_margin_alpha="$7"
  local route_confidence_power="$8"
  local route_min_confidence="$9"
  local safe_lambda="${lambda_route//./p}"
  local safe_base="${lambda_route_base//./p}"
  local safe_alpha="${route_margin_alpha//./p}"
  local label="${scenario}_k${key_count}_${route_strength_mode}_lr${safe_lambda}_base${safe_base}_a${safe_alpha}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local n

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "route-code adaptive: ${label}"
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
    --route-hint-agg vote \
    --lambda-route "$lambda_route" \
    --route-strength-mode "$route_strength_mode" \
    --lambda-route-base "$lambda_route_base" \
    --lambda-route-max "$lambda_route_max" \
    --route-margin-alpha "$route_margin_alpha" \
    --route-confidence-power "$route_confidence_power" \
    --route-min-confidence "$route_min_confidence" \
    --csv "$csv_path"

  append_summary \
    "$scenario" \
    "$route_strength_mode" \
    "$key_count" \
    "$lambda_route" \
    "$lambda_route_base" \
    "$lambda_route_max" \
    "$route_margin_alpha" \
    "$route_confidence_power" \
    "$route_min_confidence" \
    "$csv_path"
}

run_triplet() {
  local key_count="$1"
  run_case fixed-low fixed "$key_count" 0.5 0.0 10.0 1.0 1.0 0.0
  run_case fixed-strong fixed "$key_count" 10.0 0.0 10.0 1.0 1.0 0.0
  run_case adaptive-margin margin "$key_count" 0.5 0.5 10.0 1.5 1.0 0.0
}

if [[ "$MODE" == "smoke" ]]; then
  run_triplet 128
elif [[ "$MODE" == "full" ]]; then
  for key_count in 64 128 256; do
    run_triplet "$key_count"
  done
  for alpha in 0.5 1.0 1.5 2.0; do
    run_case "alpha" margin 128 0.5 0.5 10.0 "$alpha" 1.0 0.0
  done
else
  run_triplet 128
  for alpha in 1.0 1.5 2.0; do
    run_case "alpha" margin 128 0.5 0.5 10.0 "$alpha" 1.0 0.0
  done
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
