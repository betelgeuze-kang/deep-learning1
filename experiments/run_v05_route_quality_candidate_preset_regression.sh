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

PREFIX="v05_route_quality_candidate_preset_regression"
EPOCHS=6
CYCLES_PER_EPOCH=6
PROPOSAL_COUNT=16
KEY_COUNTS=(64 128)
SEEDS=(1 2)
NOISY_RATES=(0.25 0.50)

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v05_route_quality_candidate_preset_regression_smoke"
  EPOCHS=4
  CYCLES_PER_EPOCH=4
  PROPOSAL_COUNT=12
  KEY_COUNTS=(64)
  SEEDS=(1)
  NOISY_RATES=(0.25)
elif [[ "$MODE" == "full" ]]; then
  EPOCHS=8
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=18
  KEY_COUNTS=(64 128 256)
  SEEDS=(1 2 3)
  NOISY_RATES=(0.10 0.25 0.50)
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

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
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 96; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("fixture_query_byte_acc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_max route_quality_score_gap route_quality_selected_noisy_rate route_wrong_hint_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing preset regression metric column: %s\n", required[i] > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    { last = $0 }
    END {
      if (last == "") {
        printf "no data rows in %s\n", FILENAME > "/dev/stderr"
        exit 3
      }
      split(last, row, FS)
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_quality_apply_active"]] + 0,
        row[idx["route_quality_candidate_weight_beta"]] + 0,
        row[idx["route_quality_candidate_weight_factor_gap"]] + 0,
        row[idx["route_quality_candidate_weight_factor_max"]] + 0,
        row[idx["route_quality_score_gap"]] + 0,
        row[idx["route_quality_selected_noisy_rate"]] + 0,
        row[idx["route_wrong_hint_strength_mean"]] + 0,
        row[idx["route_hint_candidate_lookup_count"]] + 0,
        row[idx["route_hint_value_read_distance_mean"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local csv_path="$1"
  local fixture="$2"
  local n_bytes="$3"
  local seed="$4"
  local noisy_rate="$5"
  shift 5

  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n_bytes" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch "$CYCLES_PER_EPOCH" \
    --seed "$seed" \
    --lambda-v 0 \
    --lambda-b 0.1 \
    --eta-b 0.02 \
    --proposal-count "$PROPOSAL_COUNT" \
    --route-mode hint-kv-hash \
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --route-code-key-region-keep-prob 0.25 \
    --route-code-aux-noise-rate 0.75 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --K-route 4 \
    --route-hash-bits 16 \
    --route-hint-agg weighted-vote \
    --route-candidate-score recency \
    --route-confidence-threshold 0.75 \
    --route-lowconf-policy aggregate \
    --route-lowconf-agg weighted-vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence agreement \
    --route-delta-mode target-only \
    --lambda-route 0.5 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-strength-confidence weight \
    --route-fallback-source noisy-route-code \
    --route-noisy-source-rate "$noisy_rate" \
    --route-source-retry-source off \
    --route-source-retry-policy source-credit \
    --route-source-retry-tiebreak source-order \
    --route-source-retry-priorities raw-key:0.0,key-shape:0.0,noisy-route-code:0.0 \
    --route-source-retry-prior-mode static \
    --route-source-retry-candidates raw-key,key-shape,noisy-route-code \
    --route-source-retry-per-source-limit 4 \
    --route-fallback-strength-mode fixed \
    --route-fallback-strength-mult 1.0 \
    --route-fallback-hi-strength-mult 5.0 \
    --route-fallback-lo-strength-mult 10.0 \
    --route-fallback-channel-strength-mode fixed \
    "$@" \
    --csv "$csv_path" >/dev/null
}

EXPLICIT_FLAGS=(
  --route-quality-diagnostics 1
  --route-quality-feature-set value-only
  --route-quality-apply candidate-weight
  --route-quality-candidate-weight-beta 8.0
  --route-quality-candidate-weight-min 0.5
  --route-quality-candidate-weight-max 8.0
  --route-quality-source-normalization none
  --route-quality-score 1
  --route-quality-logdet-weight 0.0
  --route-quality-entropy-weight 0.0
  --route-quality-vote-margin-weight 1.0
  --route-quality-top-share-weight 0.0
  --route-quality-source-credit-weight 0.0
  --route-quality-edge-credit-weight 0.0
  --route-quality-channel-weight 0.0
)

printf 'scenario,key_count,seed,noisy_source_rate,basis,explicit_qacc,preset_qacc,qacc_delta,explicit_apply_active,preset_apply_active,explicit_beta,preset_beta,explicit_factor_gap,preset_factor_gap,factor_gap_delta,explicit_factor_max,preset_factor_max,factor_max_delta,explicit_quality_score_gap,preset_quality_score_gap,quality_score_gap_delta,explicit_selected_noisy_rate,preset_selected_noisy_rate,explicit_wrong_strength,preset_wrong_strength,wrong_strength_delta,lookup_count_mean,read_distance_mean,routing_trigger_rate_mean,active_jump_rate_mean,equivalent\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  for seed in "${SEEDS[@]}"; do
    for noisy_rate in "${NOISY_RATES[@]}"; do
      fixture="$TMP_DIR/preset_regression_k${key_count}_s${seed}_n${noisy_rate//./p}.txt"
      make_fixture "$fixture" "$key_count"
      n_bytes="$(wc -c <"$fixture")"

      for basis in base hybrid; do
        if [[ "$basis" == "base" ]]; then
          explicit_basis_args=(--route-quality-candidate-weight-basis base --route-quality-candidate-weight-basis-mix 0.0)
          preset_args=(--route-quality-candidate-weight-preset base-default)
        else
          explicit_basis_args=(--route-quality-candidate-weight-basis hybrid --route-quality-candidate-weight-basis-mix 0.25)
          preset_args=(--route-quality-candidate-weight-preset hybrid-safe)
        fi

        scenario="${basis}-k${key_count}-s${seed}-n${noisy_rate//./p}"
        explicit_csv="$RESULTS_DIR/${PREFIX}_${scenario}_explicit.csv"
        preset_csv="$RESULTS_DIR/${PREFIX}_${scenario}_preset.csv"

        echo "quality-candidate-preset-regression: ${scenario}" >&2
        run_case "$explicit_csv" "$fixture" "$n_bytes" "$seed" "$noisy_rate" \
          "${EXPLICIT_FLAGS[@]}" "${explicit_basis_args[@]}"
        run_case "$preset_csv" "$fixture" "$n_bytes" "$seed" "$noisy_rate" \
          "${preset_args[@]}"

        explicit_metrics="$(metric_line "$explicit_csv")"
        preset_metrics="$(metric_line "$preset_csv")"
        awk -F, -v scenario="$scenario" -v key_count="$key_count" \
          -v seed="$seed" -v noisy_rate="$noisy_rate" -v basis="$basis" \
          -v explicit_metrics="$explicit_metrics" -v preset_metrics="$preset_metrics" '
          function abs(x) { return x < 0 ? -x : x }
          BEGIN {
            split(explicit_metrics, e, ",")
            split(preset_metrics, p, ",")
            eq = 1
            for (i = 1; i <= 12; i++) {
              if (abs(e[i] - p[i]) > 0.000002) eq = 0
            }
            lookup = (e[9] + p[9]) / 2.0
            read_distance = (e[10] + p[10]) / 2.0
            routing = (e[11] + p[11]) / 2.0
            jump = (e[12] + p[12]) / 2.0
            printf "%s,%d,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d\n",
              scenario, key_count, seed, noisy_rate, basis,
              e[1], p[1], p[1] - e[1],
              e[2], p[2], e[3], p[3],
              e[4], p[4], p[4] - e[4],
              e[5], p[5], p[5] - e[5],
              e[6], p[6], p[6] - e[6],
              e[7], p[7],
              e[8], p[8], p[8] - e[8],
              lookup, read_distance, routing, jump, eq
          }
        ' >>"$SUMMARY_CSV"
      done
    done
  done
done

awk -F, '
  function mean(name) { return sum[name] / rows }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "rows,equivalent_rate,qacc_delta_mean,factor_gap_delta_mean,factor_max_delta_mean,quality_score_gap_delta_mean,wrong_strength_delta_mean,lookup_count_mean,read_distance_mean,routing_trigger_rate_mean,active_jump_rate_mean"
    next
  }
  {
    rows++
    sum["equivalent"] += $idx["equivalent"] + 0
    sum["qacc_delta"] += $idx["qacc_delta"] + 0
    sum["factor_gap_delta"] += $idx["factor_gap_delta"] + 0
    sum["factor_max_delta"] += $idx["factor_max_delta"] + 0
    sum["quality_score_gap_delta"] += $idx["quality_score_gap_delta"] + 0
    sum["wrong_strength_delta"] += $idx["wrong_strength_delta"] + 0
    sum["lookup"] += $idx["lookup_count_mean"] + 0
    sum["read_distance"] += $idx["read_distance_mean"] + 0
    sum["routing"] += $idx["routing_trigger_rate_mean"] + 0
    sum["jump"] += $idx["active_jump_rate_mean"] + 0
  }
  END {
    if (rows < 1) {
      printf "no preset regression rows\n" > "/dev/stderr"
      exit 4
    }
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows, mean("equivalent"), mean("qacc_delta"), mean("factor_gap_delta"),
      mean("factor_max_delta"), mean("quality_score_gap_delta"),
      mean("wrong_strength_delta"), mean("lookup"), mean("read_distance"),
      mean("routing"), mean("jump")
  }
' "$SUMMARY_CSV" >"$AGG_CSV"

echo "wrote $SUMMARY_CSV"
echo "wrote $AGG_CSV"
