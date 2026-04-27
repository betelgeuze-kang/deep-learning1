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
  PREFIX="v03_route_hint_kv_hash_smoke"
  KEY_COUNT=4
  EPOCHS=8
  HASH_BITS=(16)
  K_ROUTES=(1)
  AGGS=(top1)
  SCORES=(insertion)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_hash_full"
  KEY_COUNT=64
  EPOCHS=10
  HASH_BITS=(2 4 6 8 10 16)
  K_ROUTES=(1 2 4 8)
  AGGS=(top1 vote weighted-vote top1)
  SCORES=(insertion insertion value-vote key-shape)
else
  PREFIX="v03_route_hint_kv_hash"
  KEY_COUNT=32
  EPOCHS=8
  HASH_BITS=(4 6 8 16)
  K_ROUTES=(1 4)
  AGGS=(top1 vote weighted-vote top1)
  SCORES=(insertion insertion value-vote key-shape)
fi

LAMBDA_ROUTE="5.0"

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
    local key=$((3000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 64; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((3000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

run_case() {
  local hash_bits="$1"
  local k_route="$2"
  local agg="$3"
  local score="$4"
  local fixture="$TMP_DIR/kv_hash_k${KEY_COUNT}.txt"
  local label="$5"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local n
  n="$(wc -c <"$fixture")"

  echo "kv hash: keys=${KEY_COUNT} bits=${hash_bits} K-route=${k_route} agg=${agg} score=${score}"
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
    --K-route "$k_route" \
    --route-hash-bits "$hash_bits" \
    --route-hint-agg "$agg" \
    --route-candidate-score "$score" \
    --lambda-route "$LAMBDA_ROUTE" \
    --csv "$csv_path"
}

print_summary() {
  local label="$1"
  local csv_path="$2"

  awk -F, -v label="$label" '
    BEGIN {
      split("byte_acc fixture_query_byte_acc route_hint_applied_rate route_hint_candidate_hit_rate route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean route_bucket_load_mean route_bucket_load_max route_bucket_collision_rate route_hint_value_read_distance_mean route_hint_vote_candidate_count_mean route_hint_vote_margin_mean route_hint_correct_value_vote_share_mean route_hint_vote_entropy_mean route_hint_unique_values_mean", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        idx[$i] = i
      }
      next
    }
    { rows[++row_count] = $0 }
    END {
      if (row_count == 0) {
        printf "%-18s no-data\n", label
        exit 0
      }
      start = (row_count > 5 ? row_count - 4 : 1)
      count = row_count - start + 1
      for (r = start; r <= row_count; r++) {
        split(rows[r], row, FS)
        for (n = 1; n <= length(names); n++) {
          name = names[n]
          if (name in idx) {
            sum[name] += row[idx[name]] + 0
          }
        }
      }
      printf "%-18s last-5", label
      for (n = 1; n <= length(names); n++) {
        name = names[n]
        if (name in idx) {
          printf " %s=%.6f", name, sum[name] / count
        }
      }
      printf "\n"
    }
  ' "$csv_path"
}

FIXTURE_PATH="$TMP_DIR/kv_hash_k${KEY_COUNT}.txt"
make_fixture "$FIXTURE_PATH" "$KEY_COUNT"

LABELS=()
for hash_bits in "${HASH_BITS[@]}"; do
  for k_route in "${K_ROUTES[@]}"; do
    for index in "${!AGGS[@]}"; do
      agg="${AGGS[$index]}"
      score="${SCORES[$index]}"
      if [[ "$score" == "key-shape" ]]; then
        label="bits${hash_bits}_kr${k_route}_key_shape"
      elif [[ "$agg" == "weighted-vote" ]]; then
        label="bits${hash_bits}_kr${k_route}_weighted_value"
      else
        label="bits${hash_bits}_kr${k_route}_${agg}"
      fi
      run_case "$hash_bits" "$k_route" "$agg" "$score" "$label"
      LABELS+=("$label")
    done
  done
done

echo
for label in "${LABELS[@]}"; do
  print_summary "$label" "$RESULTS_DIR/${PREFIX}_${label}.csv"
done
