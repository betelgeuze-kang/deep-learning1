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
  PREFIX="v03_route_hint_kv_hash_route_code_dynamics_smoke"
  EPOCHS=10
else
  PREFIX="v03_route_hint_kv_hash_route_code_dynamics"
  EPOCHS=12
fi
if [[ "$MODE" == "full" ]]; then
  EPOCHS=16
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
printf 'scenario,key_count,hash_bits,K_route,lambda_route,cycles_per_epoch,proposal_count,route_target_proposals,fixture_query_byte_acc,fixture_query_hi_acc,fixture_query_lo_acc,route_candidate_recall_rate,route_candidate_top1_rate,key_region_route_decode_acc,query_route_hint_margin_mean,query_local_margin_against_route_mean,query_effective_route_margin_mean,route_hint_applied_rate,route_hint_strength_mean,changed,downhill_accepts,uphill_accepts,rejected\n' >"$SUMMARY_CSV"

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
    local key=$((5000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((5000 + i))
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
  local lambda_route="$5"
  local cycles_per_epoch="$6"
  local proposal_count="$7"
  local route_target_proposals="$8"
  local csv_path="$9"

  awk -F, \
    -v scenario="$scenario" \
    -v key_count="$key_count" \
    -v hash_bits="$hash_bits" \
    -v k_route="$k_route" \
    -v lambda_route="$lambda_route" \
    -v cycles_per_epoch="$cycles_per_epoch" \
    -v proposal_count="$proposal_count" \
    -v route_target_proposals="$route_target_proposals" '
    BEGIN {
      split("fixture_query_byte_acc fixture_query_hi_acc fixture_query_lo_acc route_candidate_recall_rate route_candidate_top1_rate key_region_route_decode_acc query_route_hint_margin_mean query_local_margin_against_route_mean query_effective_route_margin_mean route_hint_applied_rate route_hint_strength_mean changed downhill_accepts uphill_accepts rejected", names, " ")
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
      printf "%s,%d,%d,%d,%s,%d,%d,%d", scenario, key_count, hash_bits, k_route, lambda_route, cycles_per_epoch, proposal_count, route_target_proposals
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
  local lambda_route="$5"
  local cycles_per_epoch="$6"
  local proposal_count="$7"
  local route_target_proposals="$8"
  local safe_lambda="${lambda_route//./p}"
  local label="${scenario}_k${key_count}_bits${hash_bits}_kr${k_route}_lr${safe_lambda}_c${cycles_per_epoch}_p${proposal_count}_rt${route_target_proposals}"
  local fixture="$TMP_DIR/${label}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"
  local n

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "route-code dynamics: ${label}"
  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch "$cycles_per_epoch" \
    --seed 1 \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count "$proposal_count" \
    --route-mode hint-kv-hash \
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --K-route "$k_route" \
    --route-hash-bits "$hash_bits" \
    --route-hint-agg vote \
    --route-target-proposals "$route_target_proposals" \
    --lambda-route "$lambda_route" \
    --csv "$csv_path"

  append_summary \
    "$scenario" \
    "$key_count" \
    "$hash_bits" \
    "$k_route" \
    "$lambda_route" \
    "$cycles_per_epoch" \
    "$proposal_count" \
    "$route_target_proposals" \
    "$csv_path"
}

if [[ "$MODE" == "smoke" ]]; then
  run_case "smoke" 4 16 1 5.0 20 30 0
elif [[ "$MODE" == "full" ]]; then
  for lambda_route in 0.5 1.0 2.0 5.0 10.0; do
    run_case "lambda" 128 16 4 "$lambda_route" 20 30 0
  done
  for cycles in 10 20 40 80; do
    run_case "cycles" 128 16 4 5.0 "$cycles" 30 0
  done
  for proposal_count in 4 8 30; do
    for route_target_proposals in 0 1; do
      run_case "proposal" 128 16 4 5.0 20 "$proposal_count" "$route_target_proposals"
    done
  done
else
  for lambda_route in 0.5 2.0 5.0 10.0; do
    run_case "lambda" 128 16 4 "$lambda_route" 20 30 0
  done
  for cycles in 10 20 40; do
    run_case "cycles" 128 16 4 5.0 "$cycles" 30 0
  done
  for route_target_proposals in 0 1; do
    run_case "proposal" 128 16 4 5.0 20 8 "$route_target_proposals"
  done
fi

echo
column -s, -t "$SUMMARY_CSV" 2>/dev/null || cat "$SUMMARY_CSV"
