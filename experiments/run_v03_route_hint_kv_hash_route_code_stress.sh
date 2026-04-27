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
  PREFIX="v03_route_hint_kv_hash_route_code_stress_smoke"
  EPOCHS=12
else
  PREFIX="v03_route_hint_kv_hash_route_code_stress"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,key_count,hash_bits,K_route,eta_route_code,key_region_only,filler,fixture_query_byte_acc,route_candidate_recall_rate,route_candidate_top1_rate,route_candidate_rank_mean,route_bucket_load_mean,route_bucket_collision_rate,key_region_route_decode_acc,route_key_unique_count,route_signature_collision_rate,route_vs_raw_candidate_overlap_rate\n' >"$SUMMARY_CSV"

value_for_index() {
  local index="$1"
  local ascii=$((65 + (index % 26)))
  printf "\\$(printf '%03o' "$ascii")"
}

make_filler() {
  local filler="$1"
  local count="$2"
  if [[ "$filler" == "noisy" ]]; then
    awk -v count="$count" 'BEGIN {
      alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!?.-_"
      for (i = 0; i < count; i++) {
        idx = ((i * 17 + 11) % length(alphabet)) + 1
        printf "%s", substr(alphabet, idx, 1)
      }
      printf "\n"
    }'
  elif [[ "$filler" == "repeat" ]]; then
    awk -v count="$count" 'BEGIN {
      text = "the quick brown fox jumps over the lazy dog. "
      for (i = 0; i < count; i++) {
        idx = (i % length(text)) + 1
        printf "%s", substr(text, idx, 1)
      }
      printf "\n"
    }'
  else
    awk -v count="$count" 'BEGIN { for (i = 0; i < count; i++) printf "."; printf "\n" }'
  fi
}

make_fixture() {
  local path="$1"
  local key_count="$2"
  local filler="$3"

  : >"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((3000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  make_filler "$filler" 128 >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((3000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

append_summary() {
  local scenario="$1"
  local key_count="$2"
  local hash_bits="$3"
  local k_route="$4"
  local eta_route_code="$5"
  local key_region_only="$6"
  local filler="$7"
  local csv_path="$8"

  awk -F, \
    -v scenario="$scenario" \
    -v key_count="$key_count" \
    -v hash_bits="$hash_bits" \
    -v k_route="$k_route" \
    -v eta_route_code="$eta_route_code" \
    -v key_region_only="$key_region_only" \
    -v filler="$filler" '
    BEGIN {
      split("fixture_query_byte_acc route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean route_bucket_load_mean route_bucket_collision_rate key_region_route_decode_acc route_key_unique_count route_signature_collision_rate route_vs_raw_candidate_overlap_rate", names, " ")
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
      printf "%s,%d,%d,%d,%s,%d,%s", scenario, key_count, hash_bits, k_route, eta_route_code, key_region_only, filler
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
  local key_count="$2"
  local hash_bits="$3"
  local k_route="$4"
  local eta_route_code="$5"
  local key_region_only="$6"
  local filler="$7"
  local safe_eta="${eta_route_code//./p}"
  local label="${scenario}_k${key_count}_bits${hash_bits}_kr${k_route}_eta${safe_eta}_keyonly${key_region_only}_${filler}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local n

  make_fixture "$fixture" "$key_count" "$filler"
  n="$(wc -c <"$fixture")"

  echo "route-code stress: ${label}"
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
    --route-code-key-region-only "$key_region_only" \
    --eta-route-code "$eta_route_code" \
    --lambda-route-code-id 1.0 \
    --K-route "$k_route" \
    --route-hash-bits "$hash_bits" \
    --route-hint-agg vote \
    --lambda-route 5.0 \
    --csv "$csv_path"

  append_summary "$scenario" "$key_count" "$hash_bits" "$k_route" "$eta_route_code" "$key_region_only" "$filler" "$csv_path"
}

if [[ "$MODE" == "smoke" ]]; then
  run_case "smoke" 4 16 1 0.25 1 clean
elif [[ "$MODE" == "full" ]]; then
  for key_count in 32 64 128 256; do
    run_case "keycount" "$key_count" 16 4 0.25 1 clean
  done
  for hash_bits in 4 6 8 12 16; do
    for k_route in 1 4 8; do
      run_case "hashK" 64 "$hash_bits" "$k_route" 0.25 1 clean
    done
  done
  for eta in 0.001 0.005 0.01 0.05 0.25; do
    run_case "eta" 64 16 4 "$eta" 1 clean
  done
  for key_region_only in 1 0; do
    run_case "scope" 64 16 4 0.25 "$key_region_only" clean
  done
  for filler in clean noisy repeat; do
    run_case "filler" 64 16 4 0.25 1 "$filler"
  done
else
  for key_count in 32 64 128; do
    run_case "keycount" "$key_count" 16 4 0.25 1 clean
  done
  for hash_bits in 4 6 16; do
    for k_route in 1 4; do
      run_case "hashK" 32 "$hash_bits" "$k_route" 0.25 1 clean
    done
  done
  for eta in 0.005 0.05 0.25; do
    run_case "eta" 32 16 4 "$eta" 1 clean
  done
  for key_region_only in 1 0; do
    run_case "scope" 32 16 4 0.25 "$key_region_only" clean
  done
  for filler in noisy repeat; do
    run_case "filler" 32 16 4 0.25 1 "$filler"
  done
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
