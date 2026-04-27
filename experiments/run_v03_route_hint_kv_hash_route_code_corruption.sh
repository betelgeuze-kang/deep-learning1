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
  PREFIX="v03_route_hint_kv_hash_route_code_corruption_smoke"
  EPOCHS=10
else
  PREFIX="v03_route_hint_kv_hash_route_code_corruption"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,route_corrupt_candidate_rate,route_corrupt_confidence,route_min_confidence,fixture_query_byte_acc,clean_reference_qacc,damage_vs_clean,route_candidate_corrupt_rate,route_correct_candidate_rate,route_wrong_hint_applied_rate,route_wrong_hint_strength_mean,route_correct_hint_strength_mean,route_strength_mean,route_strength_p90,route_strength_max\n' >"$SUMMARY_CSV"

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
    local key=$((9000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((9000 + i))
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
        sum += row[idx[column]] + 0
      }
      printf "%.6f", sum / count
    }
  ' "$csv_path"
}

append_summary() {
  local scenario="$1"
  local corrupt_rate="$2"
  local corrupt_confidence="$3"
  local min_confidence="$4"
  local clean_reference="$5"
  local csv_path="$6"

  awk -F, \
    -v scenario="$scenario" \
    -v corrupt_rate="$corrupt_rate" \
    -v corrupt_confidence="$corrupt_confidence" \
    -v min_confidence="$min_confidence" \
    -v clean_reference="$clean_reference" '
    BEGIN {
      split("fixture_query_byte_acc route_candidate_corrupt_rate route_correct_candidate_rate route_wrong_hint_applied_rate route_wrong_hint_strength_mean route_correct_hint_strength_mean route_strength_mean route_strength_p90 route_strength_max", names, " ")
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
      qacc = sum["fixture_query_byte_acc"] / count
      printf "%s,%s,%s,%s,%.6f,%.6f,%.6f", scenario, corrupt_rate, corrupt_confidence, min_confidence, qacc, clean_reference, clean_reference - qacc
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
  local key_count="$2"
  local corrupt_rate="$3"
  local corrupt_confidence="$4"
  local corrupt_confidence_value="$5"
  local min_confidence="$6"
  local clean_reference="$7"
  local safe_rate="${corrupt_rate//./p}"
  local label="${scenario}_k${key_count}_cr${safe_rate}_${corrupt_confidence}_min${min_confidence//./p}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local n

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "route-code corruption: ${label}"
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
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-confidence-power 1.0 \
    --route-min-confidence "$min_confidence" \
    --route-corrupt-candidate-rate "$corrupt_rate" \
    --route-corrupt-confidence "$corrupt_confidence" \
    --route-corrupt-confidence-value "$corrupt_confidence_value" \
    --csv "$csv_path"

  if [[ "$scenario" == "clean-adaptive" ]]; then
    clean_reference="$(last5_mean "$csv_path" fixture_query_byte_acc)"
  fi
  append_summary "$scenario" "$corrupt_rate" "$corrupt_confidence" "$min_confidence" "$clean_reference" "$csv_path"
  if [[ "$scenario" == "clean-adaptive" ]]; then
    echo "$clean_reference" >"$TMP_DIR/clean_reference.txt"
  fi
}

run_triplet() {
  local key_count="$1"
  local corrupt_rate="$2"

  run_case clean-adaptive "$key_count" 0.0 keep 0.1 0.0 0.0
  local clean_reference
  clean_reference="$(cat "$TMP_DIR/clean_reference.txt")"
  run_case corrupt-keep "$key_count" "$corrupt_rate" keep 0.1 0.0 "$clean_reference"
  run_case corrupt-lowconf "$key_count" "$corrupt_rate" low 0.1 0.5 "$clean_reference"
}

if [[ "$MODE" == "smoke" ]]; then
  run_triplet 128 0.25
elif [[ "$MODE" == "full" ]]; then
  for corrupt_rate in 0.05 0.10 0.25 0.50; do
    run_triplet 128 "$corrupt_rate"
  done
else
  for corrupt_rate in 0.10 0.25; do
    run_triplet 128 "$corrupt_rate"
  done
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
