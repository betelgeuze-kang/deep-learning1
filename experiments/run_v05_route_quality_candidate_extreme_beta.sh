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

EPOCHS=10
CYCLES_PER_EPOCH=10
PROPOSAL_COUNT=22
PREFIX="v05_route_quality_candidate_extreme_beta"
KEY_COUNTS=(128 256)
SEEDS=(1 2 3)
NOISY_RATES=(0.25 0.50)
ARMS=(
  "candidate-b5p00-cap6p0:5.00:6.0"
  "candidate-b6p00-cap6p0:6.00:6.0"
  "candidate-b6p00-cap8p0:6.00:8.0"
  "candidate-b6p00-cap12p0:6.00:12.0"
  "candidate-b8p00-cap8p0:8.00:8.0"
  "candidate-b8p00-cap12p0:8.00:12.0"
)

if [[ "$MODE" == "smoke" ]]; then
  EPOCHS=6
  CYCLES_PER_EPOCH=6
  PROPOSAL_COUNT=18
  PREFIX="v05_route_quality_candidate_extreme_beta_smoke"
  KEY_COUNTS=(128)
  SEEDS=(1)
  NOISY_RATES=(0.25)
  ARMS=(
    "candidate-b5p00-cap6p0:5.00:6.0"
    "candidate-b6p00-cap8p0:6.00:8.0"
    "candidate-b8p00-cap12p0:8.00:12.0"
  )
elif [[ "$MODE" == "full" ]]; then
  EPOCHS=16
  CYCLES_PER_EPOCH=14
  PROPOSAL_COUNT=28
  KEY_COUNTS=(64 128 256)
  SEEDS=(1 2 3 4 5)
  NOISY_RATES=(0.10 0.25 0.50)
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"
BY_KEY_CSV="$RESULTS_DIR/${PREFIX}_by_key_noise.csv"
printf 'scenario,arm,candidate_beta,candidate_min,candidate_max,key_count,seed,noisy_source_rate,qacc,route_quality_apply_active,route_quality_candidate_weight_beta,route_quality_candidate_weight_factor_mean,route_quality_candidate_weight_factor_correct_mean,route_quality_candidate_weight_factor_wrong_mean,route_quality_candidate_weight_factor_gap,route_quality_candidate_weight_factor_p90,route_quality_candidate_weight_factor_max,route_quality_candidate_weight_entropy_mean,route_quality_candidate_weight_top_share_mean,route_quality_candidate_weight_correct_mean,route_quality_candidate_weight_wrong_mean,route_quality_candidate_weight_gap,route_quality_candidate_best_correct_rate,route_quality_selected_noisy_rate,route_quality_selected_raw_qacc,route_wrong_hint_strength_mean,route_correct_hint_strength_mean,lookup_count,read_distance,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

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
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

compute_metrics() {
  local csv_path="$1"

  awk -F, '
    BEGIN {
      name_count = split("fixture_query_byte_acc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_correct_mean route_quality_candidate_weight_factor_wrong_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_p90 route_quality_candidate_weight_factor_max route_quality_candidate_weight_entropy_mean route_quality_candidate_weight_top_share_mean route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_noisy_rate route_quality_selected_raw_qacc route_wrong_hint_strength_mean route_correct_hint_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      for (i = 1; i <= name_count; i++) {
        if (!(names[i] in idx)) {
          printf "missing column: %s in %s\n", names[i], FILENAME > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    { rows[++row_count] = $0 }
    END {
      if (row_count < 1) {
        printf "no data rows in %s\n", FILENAME > "/dev/stderr"
        exit 3
      }
      start = (row_count > 5 ? row_count - 4 : 1)
      count = row_count - start + 1
      for (r = start; r <= row_count; r++) {
        split(rows[r], row, FS)
        for (i = 1; i <= name_count; i++) {
          name = names[i]
          sum[name] += row[idx[name]] + 0
        }
      }
      for (i = 1; i <= name_count; i++) {
        if (i > 1) printf ","
        name = names[i]
        printf "%.6f", sum[name] / count
      }
    }
  ' "$csv_path"
}

emit_aggregate() {
  awk -F, '
    function mean(name, arm) { return sums[arm, name] / counts[arm] }
    function stddev(name, arm, avg, var) {
      avg = mean(name, arm)
      if (counts[arm] <= 1) return 0
      var = (sums_sq[arm, name] / counts[arm]) - (avg * avg)
      return sqrt(var < 0 ? 0 : var)
    }
    BEGIN {
      metric_count = split("qacc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_correct_mean route_quality_candidate_weight_factor_wrong_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_p90 route_quality_candidate_weight_factor_max route_quality_candidate_weight_entropy_mean route_quality_candidate_weight_top_share_mean route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_selected_noisy_rate route_quality_selected_raw_qacc route_wrong_hint_strength_mean route_correct_hint_strength_mean lookup_count read_distance routing_trigger_rate active_jump_rate", metrics, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      printf "arm,rows"
      for (i = 1; i <= metric_count; i++) {
        printf ",%s_mean,%s_std", metrics[i], metrics[i]
      }
      printf "\n"
      next
    }
    {
      arm = $idx["arm"]
      if (!(arm in seen)) {
        seen[arm] = 1
        arms[++arm_count] = arm
      }
      counts[arm]++
      for (i = 1; i <= metric_count; i++) {
        metric = metrics[i]
        value = $idx[metric] + 0
        sums[arm, metric] += value
        sums_sq[arm, metric] += value * value
      }
    }
    END {
      for (a = 1; a <= arm_count; a++) {
        arm = arms[a]
        printf "%s,%d", arm, counts[arm]
        for (i = 1; i <= metric_count; i++) {
          metric = metrics[i]
          printf ",%.6f,%.6f", mean(metric, arm), stddev(metric, arm)
        }
        printf "\n"
      }
    }
  ' "$SUMMARY_CSV" >"$AGG_CSV"

  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      print "arm,key_count,noisy_source_rate,rows,qacc_mean,qacc_std,top_share_mean,entropy_mean,factor_max_mean,wrong_strength_mean,selected_noisy_rate_mean,active_jump_rate_mean"
      next
    }
    {
      key = $idx["arm"] "," $idx["key_count"] "," $idx["noisy_source_rate"]
      if (!(key in seen)) {
        seen[key] = 1
        keys[++key_count_seen] = key
      }
      count[key]++
      q = $idx["qacc"] + 0
      sum_q[key] += q
      sum_q_sq[key] += q * q
      sum_top[key] += $idx["route_quality_candidate_weight_top_share_mean"] + 0
      sum_entropy[key] += $idx["route_quality_candidate_weight_entropy_mean"] + 0
      sum_fmax[key] += $idx["route_quality_candidate_weight_factor_max"] + 0
      sum_wrong[key] += $idx["route_wrong_hint_strength_mean"] + 0
      sum_noisy[key] += $idx["route_quality_selected_noisy_rate"] + 0
      sum_jump[key] += $idx["active_jump_rate"] + 0
    }
    END {
      for (i = 1; i <= key_count_seen; i++) {
        key = keys[i]
        split(key, parts, ",")
        mean_q = sum_q[key] / count[key]
        var_q = (sum_q_sq[key] / count[key]) - (mean_q * mean_q)
        printf "%s,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
          parts[1], parts[2], parts[3], count[key], mean_q,
          sqrt(var_q < 0 ? 0 : var_q), sum_top[key] / count[key],
          sum_entropy[key] / count[key], sum_fmax[key] / count[key],
          sum_wrong[key] / count[key], sum_noisy[key] / count[key],
          sum_jump[key] / count[key]
      }
    }
  ' "$SUMMARY_CSV" >"$BY_KEY_CSV"
}

run_case() {
  local arm="$1"
  local candidate_beta="$2"
  local candidate_max="$3"
  local key_count="$4"
  local seed="$5"
  local noisy_rate="$6"

  local scenario="${arm}-k${key_count}-s${seed}-n${noisy_rate//./p}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n
  local metrics

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "quality-candidate-extreme-beta: ${scenario} beta=${candidate_beta} cap=${candidate_max}" >&2
  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n" \
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
    --route-quality-diagnostics 1 \
    --route-quality-feature-set value-only \
    --route-quality-apply candidate-weight \
    --route-quality-candidate-weight-beta "$candidate_beta" \
    --route-quality-candidate-weight-min 0.5 \
    --route-quality-candidate-weight-max "$candidate_max" \
    --route-quality-source-normalization none \
    --route-quality-eps 1e-4 \
    --route-channel-tension-diagnostics 1 \
    --route-channel-tension-mode margin \
    --route-quality-score 1 \
    --route-quality-logdet-weight 0.1 \
    --route-quality-entropy-weight 0.5 \
    --route-quality-vote-margin-weight 1.0 \
    --route-quality-top-share-weight 1.0 \
    --route-quality-source-credit-weight 0.5 \
    --route-quality-edge-credit-weight 0.5 \
    --route-quality-channel-weight -0.1 \
    --csv "$csv_path"

  metrics="$(compute_metrics "$csv_path")"
  printf '%s,%s,%s,%s,%s,%d,%d,%s,%s\n' \
    "$scenario" \
    "$arm" \
    "$candidate_beta" \
    "0.5" \
    "$candidate_max" \
    "$key_count" \
    "$seed" \
    "$noisy_rate" \
    "$metrics" >>"$SUMMARY_CSV"
}

for key_count in "${KEY_COUNTS[@]}"; do
  for seed in "${SEEDS[@]}"; do
    for noisy_rate in "${NOISY_RATES[@]}"; do
      for arm_spec in "${ARMS[@]}"; do
        IFS=: read -r arm candidate_beta candidate_max <<<"$arm_spec"
        run_case "$arm" "$candidate_beta" "$candidate_max" \
          "$key_count" "$seed" "$noisy_rate"
      done
    done
  done
done

emit_aggregate

echo "wrote $SUMMARY_CSV"
echo "wrote $AGG_CSV"
echo "wrote $BY_KEY_CSV"
