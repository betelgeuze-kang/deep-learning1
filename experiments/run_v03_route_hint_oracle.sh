#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_PATH="$ROOT_DIR/data/route_hint_oracle_fixture.txt"
FIXTURE_N="$(wc -c < "$FIXTURE_PATH")"

mkdir -p "$RESULTS_DIR"

cmake -S "$ROOT_DIR" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR" --target dmv02 -j

run_case() {
  local csv_path="$1"
  shift
  "$BUILD_DIR/dmv02" "$@" --csv "$csv_path"
}

print_summary() {
  local label="$1"
  local csv_path="$2"

  awk -F, -v label="$label" '
    BEGIN {
      split("byte_acc field_byte_acc joint_byte_acc route_hint_query_count route_hint_applied_rate route_hint_weight_mean route_hint_strength_mean route_hint_value_match_rate fixture_query_byte_acc fixture_query_field_acc fixture_query_joint_acc", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        idx[$i] = i
      }
      next
    }
    {
      rows[++row_count] = $0
    }
    END {
      if (row_count == 0) {
        printf "%-24s no-data\n", label
        exit 0
      }

      start = (row_count > 10 ? row_count - 9 : 1)
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

      printf "%-24s last-10", label
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

COMMON_ARGS=(
  --cycles-per-epoch 20
  --seed 1
  --lambda-v 0
  --lambda-b 0.1
  --eta-b 0.02
  --proposal-count 30
)

FIXTURE_ARGS=(
  --input "$FIXTURE_PATH"
  --N "$FIXTURE_N"
  --epochs 20
)

REPEAT_ARGS=(
  --dataset repeating-text
  --N 128
  --epochs 80
)

echo "route-hint oracle: fixture off"
run_case "$RESULTS_DIR/v03_route_hint_fixture_off.csv" \
  "${FIXTURE_ARGS[@]}" "${COMMON_ARGS[@]}" --route-mode off

echo "route-hint oracle: repeating-text off"
run_case "$RESULTS_DIR/v03_route_hint_repeat_off.csv" \
  "${REPEAT_ARGS[@]}" "${COMMON_ARGS[@]}" --route-mode off

for lambda_route in 0.01 0.03 0.10 0.20 0.30 0.50; do
  tag="${lambda_route/./p}"

  echo "route-hint oracle: fixture lambda-route=${lambda_route}"
  run_case "$RESULTS_DIR/v03_route_hint_fixture_lr${tag}.csv" \
    "${FIXTURE_ARGS[@]}" "${COMMON_ARGS[@]}" \
    --route-mode hint-oracle --lambda-route "$lambda_route"

  echo "route-hint oracle: repeating-text lambda-route=${lambda_route}"
  run_case "$RESULTS_DIR/v03_route_hint_repeat_lr${tag}.csv" \
    "${REPEAT_ARGS[@]}" "${COMMON_ARGS[@]}" \
    --route-mode hint-oracle --lambda-route "$lambda_route"
done

echo
print_summary fixture-off "$RESULTS_DIR/v03_route_hint_fixture_off.csv"
for lambda_route in 0.01 0.03 0.10 0.20 0.30 0.50; do
  tag="${lambda_route/./p}"
  print_summary "fixture-lr${tag}" "$RESULTS_DIR/v03_route_hint_fixture_lr${tag}.csv"
done

print_summary repeat-off "$RESULTS_DIR/v03_route_hint_repeat_off.csv"
for lambda_route in 0.01 0.03 0.10 0.20 0.30 0.50; do
  tag="${lambda_route/./p}"
  print_summary "repeat-lr${tag}" "$RESULTS_DIR/v03_route_hint_repeat_lr${tag}.csv"
done
