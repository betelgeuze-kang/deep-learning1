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

PREFIX="v05_route_quality_candidate_preset_policy"
EPOCHS=6
CYCLES_PER_EPOCH=6
PROPOSAL_COUNT=16
KEY_COUNTS=(64 128)
SEEDS=(1 2)
NOISY_RATES=(0.25 0.50)

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v05_route_quality_candidate_preset_policy_smoke"
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
POLICY_CSV="$RESULTS_DIR/${PREFIX}_policy.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"
QACC_TOLERANCE="${QACC_TOLERANCE:-0.001}"

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
          printf "missing preset policy metric column: %s\n", required[i] > "/dev/stderr"
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
  local preset="$6"

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
    --route-quality-candidate-weight-preset "$preset" \
    --csv "$csv_path" >/dev/null
}

printf 'scenario,key_count,seed,noisy_source_rate,arm,preset,qacc,apply_active,beta,factor_gap,factor_max,quality_score_gap,selected_noisy_rate,wrong_strength,lookup_count,read_distance,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  for seed in "${SEEDS[@]}"; do
    for noisy_rate in "${NOISY_RATES[@]}"; do
      fixture="$TMP_DIR/preset_policy_k${key_count}_s${seed}_n${noisy_rate//./p}.txt"
      make_fixture "$fixture" "$key_count"
      n_bytes="$(wc -c <"$fixture")"

      for arm in base-default hybrid-safe; do
        scenario="${arm}-k${key_count}-s${seed}-n${noisy_rate//./p}"
        arm_csv="$RESULTS_DIR/${PREFIX}_${scenario}.csv"

        echo "quality-candidate-preset-policy: ${scenario}" >&2
        run_case "$arm_csv" "$fixture" "$n_bytes" "$seed" "$noisy_rate" "$arm"

        metrics="$(metric_line "$arm_csv")"
        awk -F, -v scenario="$scenario" -v key_count="$key_count" \
          -v seed="$seed" -v noisy_rate="$noisy_rate" -v arm="$arm" \
          -v metrics="$metrics" '
          BEGIN {
            split(metrics, m, ",")
            printf "%s,%d,%d,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
              scenario, key_count, seed, noisy_rate, arm, arm,
              m[1], m[2], m[3], m[4], m[5], m[6],
              m[7], m[8], m[9], m[10], m[11], m[12]
          }
        ' >>"$SUMMARY_CSV"
      done
    done
  done
done

awk -F, -v qtol="$QACC_TOLERANCE" '
  function require(name) {
    if (!(name in idx)) {
      printf "missing preset-policy summary column: %s\n", name > "/dev/stderr"
      exit 4
    }
  }
  function recommendation(base_q, hybrid_q, base_gap, hybrid_gap, rec) {
    rec = "base-default"
    if (hybrid_q > base_q + qtol && hybrid_gap <= base_gap) {
      rec = "hybrid-safe-qacc"
    } else if (hybrid_q + qtol >= base_q && hybrid_gap < base_gap) {
      rec = "hybrid-safe"
    }
    return rec
  }
  BEGIN {
    print "scenario,key_count,seed,noisy_source_rate,base_qacc,hybrid_qacc,qacc_delta,base_factor_gap,hybrid_factor_gap,factor_gap_delta,base_factor_max,hybrid_factor_max,factor_max_delta,base_quality_score_gap,hybrid_quality_score_gap,quality_score_gap_delta,base_selected_noisy_rate,hybrid_selected_noisy_rate,base_wrong_strength,hybrid_wrong_strength,wrong_strength_delta,lookup_count_mean,read_distance_mean,routing_trigger_rate_mean,active_jump_rate_mean,recommendation"
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("key_count seed noisy_source_rate arm qacc factor_gap factor_max quality_score_gap selected_noisy_rate wrong_strength lookup_count read_distance routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) require(required[i])
    next
  }
  {
    key = $idx["key_count"] "," $idx["seed"] "," $idx["noisy_source_rate"]
    arm = $idx["arm"]
    if (arm != "base-default" && arm != "hybrid-safe") next
    if (!(key in seen)) {
      seen[key] = 1
      keys[++key_count_seen] = key
    }
    present[key, arm] = 1
    qacc[key, arm] = $idx["qacc"] + 0
    factor_gap[key, arm] = $idx["factor_gap"] + 0
    factor_max[key, arm] = $idx["factor_max"] + 0
    quality_gap[key, arm] = $idx["quality_score_gap"] + 0
    selected_noisy[key, arm] = $idx["selected_noisy_rate"] + 0
    wrong_strength[key, arm] = $idx["wrong_strength"] + 0
    lookup[key, arm] = $idx["lookup_count"] + 0
    read_distance[key, arm] = $idx["read_distance"] + 0
    routing[key, arm] = $idx["routing_trigger_rate"] + 0
    jump[key, arm] = $idx["active_jump_rate"] + 0
  }
  END {
    for (k = 1; k <= key_count_seen; k++) {
      key = keys[k]
      if (!present[key, "base-default"] || !present[key, "hybrid-safe"]) {
        printf "missing base/hybrid-safe pair for scenario: %s\n", key > "/dev/stderr"
        exit 5
      }
      split(key, parts, ",")
      rec = recommendation(qacc[key, "base-default"], qacc[key, "hybrid-safe"],
        factor_gap[key, "base-default"], factor_gap[key, "hybrid-safe"])
      printf "k%s-s%s-n%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s\n",
        parts[1], parts[2], parts[3], parts[1], parts[2], parts[3],
        qacc[key, "base-default"], qacc[key, "hybrid-safe"],
        qacc[key, "hybrid-safe"] - qacc[key, "base-default"],
        factor_gap[key, "base-default"], factor_gap[key, "hybrid-safe"],
        factor_gap[key, "hybrid-safe"] - factor_gap[key, "base-default"],
        factor_max[key, "base-default"], factor_max[key, "hybrid-safe"],
        factor_max[key, "hybrid-safe"] - factor_max[key, "base-default"],
        quality_gap[key, "base-default"], quality_gap[key, "hybrid-safe"],
        quality_gap[key, "hybrid-safe"] - quality_gap[key, "base-default"],
        selected_noisy[key, "base-default"], selected_noisy[key, "hybrid-safe"],
        wrong_strength[key, "base-default"], wrong_strength[key, "hybrid-safe"],
        wrong_strength[key, "hybrid-safe"] - wrong_strength[key, "base-default"],
        (lookup[key, "base-default"] + lookup[key, "hybrid-safe"]) / 2.0,
        (read_distance[key, "base-default"] + read_distance[key, "hybrid-safe"]) / 2.0,
        (routing[key, "base-default"] + routing[key, "hybrid-safe"]) / 2.0,
        (jump[key, "base-default"] + jump[key, "hybrid-safe"]) / 2.0,
        rec
    }
  }
' "$SUMMARY_CSV" >"$POLICY_CSV"

awk -F, '
  function require(name) {
    if (!(name in idx)) {
      printf "missing preset-policy column: %s\n", name > "/dev/stderr"
      exit 6
    }
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("base_qacc hybrid_qacc qacc_delta base_factor_gap hybrid_factor_gap factor_gap_delta base_factor_max hybrid_factor_max factor_max_delta base_quality_score_gap hybrid_quality_score_gap quality_score_gap_delta base_wrong_strength hybrid_wrong_strength wrong_strength_delta lookup_count_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean recommendation", required, " ")
    for (i = 1; i <= required_count; i++) require(required[i])
    print "rows,base_qacc_mean,hybrid_qacc_mean,qacc_delta_mean,base_factor_gap_mean,hybrid_factor_gap_mean,factor_gap_delta_mean,base_factor_max_mean,hybrid_factor_max_mean,factor_max_delta_mean,base_quality_score_gap_mean,hybrid_quality_score_gap_mean,quality_score_gap_delta_mean,base_wrong_strength_mean,hybrid_wrong_strength_mean,wrong_strength_delta_mean,lookup_count_mean,read_distance_mean,routing_trigger_rate_mean,active_jump_rate_mean,hybrid_recommended_rate"
    next
  }
  {
    rows++
    base_q += $idx["base_qacc"] + 0
    hybrid_q += $idx["hybrid_qacc"] + 0
    delta_q += $idx["qacc_delta"] + 0
    base_gap += $idx["base_factor_gap"] + 0
    hybrid_gap += $idx["hybrid_factor_gap"] + 0
    delta_gap += $idx["factor_gap_delta"] + 0
    base_fmax += $idx["base_factor_max"] + 0
    hybrid_fmax += $idx["hybrid_factor_max"] + 0
    delta_fmax += $idx["factor_max_delta"] + 0
    base_quality += $idx["base_quality_score_gap"] + 0
    hybrid_quality += $idx["hybrid_quality_score_gap"] + 0
    delta_quality += $idx["quality_score_gap_delta"] + 0
    base_wrong += $idx["base_wrong_strength"] + 0
    hybrid_wrong += $idx["hybrid_wrong_strength"] + 0
    delta_wrong += $idx["wrong_strength_delta"] + 0
    lookup += $idx["lookup_count_mean"] + 0
    read_distance += $idx["read_distance_mean"] + 0
    routing += $idx["routing_trigger_rate_mean"] + 0
    jump += $idx["active_jump_rate_mean"] + 0
    if ($idx["recommendation"] ~ /^hybrid-safe/) hybrid_recommended++
  }
  END {
    if (rows < 1) {
      printf "no preset policy rows found\n" > "/dev/stderr"
      exit 7
    }
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows, base_q / rows, hybrid_q / rows, delta_q / rows,
      base_gap / rows, hybrid_gap / rows, delta_gap / rows,
      base_fmax / rows, hybrid_fmax / rows, delta_fmax / rows,
      base_quality / rows, hybrid_quality / rows, delta_quality / rows,
      base_wrong / rows, hybrid_wrong / rows, delta_wrong / rows,
      lookup / rows, read_distance / rows, routing / rows, jump / rows,
      hybrid_recommended / rows
  }
' "$POLICY_CSV" >"$AGG_CSV"

echo "wrote $SUMMARY_CSV"
echo "wrote $POLICY_CSV"
echo "wrote $AGG_CSV"
