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
elif [[ "${1:-}" == "--strong" ]]; then
  MODE="strong"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--strong|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" --target dmv02 -j

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v03_route_hint_kv_scale_smoke"
  LAMBDA_ROUTE="5.0"
  EPOCHS=8
  DISTANCES=(64)
  KEY_COUNTS=(4)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v03_route_hint_kv_scale_full"
  LAMBDA_ROUTE="0.50"
  EPOCHS=12
  DISTANCES=(64 256 1024 4096 16384)
  KEY_COUNTS=(1 4 16 64 256)
elif [[ "$MODE" == "strong" ]]; then
  PREFIX="v03_route_hint_kv_scale_strong"
  LAMBDA_ROUTE="5.0"
  EPOCHS=8
  DISTANCES=()
  KEY_COUNTS=(64)
else
  PREFIX="v03_route_hint_kv_scale"
  LAMBDA_ROUTE="0.50"
  EPOCHS=12
  DISTANCES=(64 256 1024 4096)
  KEY_COUNTS=(1 4 16 64)
fi

COMMON_ARGS=(
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
  --proposal-count 30
  --route-mode hint-kv-exact
  --lambda-route "$LAMBDA_ROUTE"
)

value_for_index() {
  local index="$1"
  local ascii=$((65 + (index % 26)))
  printf "\\$(printf '%03o' "$ascii")"
}

append_filler() {
  local path="$1"
  local count="$2"
  local style="$3"

  awk -v n="$count" -v style="$style" '
    BEGIN {
      for (i = 0; i < n; i++) {
        if (style == "mixed") {
          c = 33 + ((i * 17 + 11) % 90)
          if (c == 64 || c == 63) {
            c = 46
          }
          printf "%c", c
        } else if (style == "repeat") {
          text = "the quick brown fox jumps over the lazy dog "
          printf "%s", substr(text, (i % length(text)) + 1, 1)
        } else {
          printf "."
        }
      }
      printf "\n"
    }
  ' >> "$path"
}

make_distance_fixture() {
  local path="$1"
  local distance="$2"
  local key_count="$3"
  local filler_style="$4"

  : > "$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((1000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;' "$key" "$value" >> "$path"
    append_filler "$path" "$distance" "$filler_style"
    printf '?%d=%s.\n' "$key" "$value" >> "$path"
  done
}

make_keys_fixture() {
  local path="$1"
  local key_count="$2"
  local filler_style="$3"

  : > "$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((2000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;' "$key" "$value" >> "$path"
    append_filler "$path" 64 "$filler_style"
    printf '?%d=%s.\n' "$key" "$value" >> "$path"
  done
}

make_duplicate_fixture() {
  local path="$1"

  : > "$path"
  printf '@17=A;' >> "$path"
  append_filler "$path" 64 "plain"
  printf '@17=Q;' >> "$path"
  append_filler "$path" 64 "plain"
  printf '?17=Q.\n' >> "$path"
}

make_missing_fixture() {
  local path="$1"

  : > "$path"
  printf '@17=Q;' >> "$path"
  append_filler "$path" 64 "plain"
  printf '?99=X.\n' >> "$path"
}

run_fixture() {
  local label="$1"
  local path="$2"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local n
  n="$(wc -c < "$path")"

  echo "kv scale: ${label} N=${n} lambda-route=${LAMBDA_ROUTE}"
  "$BUILD_DIR/dmv02" \
    --input "$path" \
    --N "$n" \
    --epochs "$EPOCHS" \
    "${COMMON_ARGS[@]}" \
    --csv "$csv_path"
}

print_summary() {
  local label="$1"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"

  awk -F, -v label="$label" '
    BEGIN {
      split("byte_acc field_byte_acc joint_byte_acc kv_record_count kv_query_count kv_query_hit_rate kv_duplicate_key_rate kv_missing_key_rate route_hint_applied_rate route_hint_candidate_lookup_count route_hint_candidate_hit_rate route_hint_value_read_distance_mean fixture_query_byte_acc", names, " ")
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
        printf "%-28s no-data\n", label
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

      printf "%-28s last-5", label
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

LABELS=()

for distance in "${DISTANCES[@]}"; do
  fixture="$TMP_DIR/distance_d${distance}.txt"
  label="distance_d${distance}"
  make_distance_fixture "$fixture" "$distance" 4 "plain"
  run_fixture "$label" "$fixture"
  LABELS+=("$label")
done

for key_count in "${KEY_COUNTS[@]}"; do
  fixture="$TMP_DIR/keys_k${key_count}.txt"
  label="keys_k${key_count}"
  make_keys_fixture "$fixture" "$key_count" "plain"
  run_fixture "$label" "$fixture"
  LABELS+=("$label")
done

duplicate_fixture="$TMP_DIR/duplicate_latest.txt"
make_duplicate_fixture "$duplicate_fixture"
run_fixture "duplicate_latest" "$duplicate_fixture"
LABELS+=("duplicate_latest")

missing_fixture="$TMP_DIR/missing_key.txt"
make_missing_fixture "$missing_fixture"
run_fixture "missing_key" "$missing_fixture"
LABELS+=("missing_key")

noise_fixture="$TMP_DIR/noisy_mixed.txt"
make_distance_fixture "$noise_fixture" 256 8 "mixed"
run_fixture "noisy_mixed" "$noise_fixture"
LABELS+=("noisy_mixed")

echo
for label in "${LABELS[@]}"; do
  print_summary "$label"
done
