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
PREFIX="v05_route_quality_candidate_feature_calibration"
KEY_COUNTS=(64 128)
SEEDS=(1 2 3)
NOISY_RATES=(0.25 0.50)
ARMS=(
  "base-default:base:1.0:1.0:0.5:0.1:-0.1:0.5:0.5"
  "feature-default:quality-score:1.0:1.0:0.5:0.1:-0.1:0.5:0.5"
  "feature-value:quality-score:1.0:1.0:0.0:0.0:0.0:0.0:0.0"
  "feature-share:quality-score:0.0:1.0:0.0:0.0:0.0:0.0:0.0"
  "feature-margin:quality-score:1.0:0.0:0.0:0.0:0.0:0.0:0.0"
)

if [[ "$MODE" == "smoke" ]]; then
  EPOCHS=6
  CYCLES_PER_EPOCH=6
  PROPOSAL_COUNT=18
  PREFIX="v05_route_quality_candidate_feature_calibration_smoke"
  KEY_COUNTS=(128)
  SEEDS=(1)
  NOISY_RATES=(0.25)
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
printf 'scenario,arm,candidate_basis,vote_margin_weight,top_share_weight,entropy_weight,logdet_weight,channel_weight,source_credit_weight,edge_credit_weight,key_count,seed,noisy_source_rate,qacc,route_quality_apply_active,route_quality_candidate_weight_beta,route_quality_candidate_weight_factor_mean,route_quality_candidate_weight_factor_correct_mean,route_quality_candidate_weight_factor_wrong_mean,route_quality_candidate_weight_factor_gap,route_quality_candidate_weight_factor_p90,route_quality_candidate_weight_factor_max,route_quality_candidate_weight_entropy_mean,route_quality_candidate_weight_top_share_mean,route_quality_candidate_weight_correct_mean,route_quality_candidate_weight_wrong_mean,route_quality_candidate_weight_gap,route_quality_candidate_best_correct_rate,route_quality_score_mean,route_quality_score_correct_mean,route_quality_score_wrong_mean,route_quality_score_gap,route_quality_selected_noisy_rate,route_quality_selected_raw_qacc,route_wrong_hint_strength_mean,route_correct_hint_strength_mean,lookup_count,read_distance,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

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
      name_count = split("fixture_query_byte_acc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_correct_mean route_quality_candidate_weight_factor_wrong_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_p90 route_quality_candidate_weight_factor_max route_quality_candidate_weight_entropy_mean route_quality_candidate_weight_top_share_mean route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_score_mean route_quality_score_correct_mean route_quality_score_wrong_mean route_quality_score_gap route_quality_selected_noisy_rate route_quality_selected_raw_qacc route_wrong_hint_strength_mean route_correct_hint_strength_mean route_hint_candidate_lookup_count route_hint_value_read_distance_mean routing_trigger_rate active_jump_rate", names, " ")
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
      metric_count = split("qacc route_quality_apply_active route_quality_candidate_weight_beta route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_correct_mean route_quality_candidate_weight_factor_wrong_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_p90 route_quality_candidate_weight_factor_max route_quality_candidate_weight_entropy_mean route_quality_candidate_weight_top_share_mean route_quality_candidate_weight_correct_mean route_quality_candidate_weight_wrong_mean route_quality_candidate_weight_gap route_quality_candidate_best_correct_rate route_quality_score_mean route_quality_score_correct_mean route_quality_score_wrong_mean route_quality_score_gap route_quality_selected_noisy_rate route_quality_selected_raw_qacc route_wrong_hint_strength_mean route_correct_hint_strength_mean lookup_count read_distance routing_trigger_rate active_jump_rate", metrics, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      printf "arm,candidate_basis,rows"
      for (i = 1; i <= metric_count; i++) {
        printf ",%s_mean,%s_std", metrics[i], metrics[i]
      }
      printf "\n"
      next
    }
    {
      arm = $idx["arm"]
      basis[arm] = $idx["candidate_basis"]
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
        printf "%s,%s,%d", arm, basis[arm], counts[arm]
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
      print "arm,candidate_basis,key_count,noisy_source_rate,rows,qacc_mean,qacc_std,factor_gap_mean,factor_max_mean,top_share_mean,entropy_mean,quality_score_gap_mean,wrong_strength_mean,selected_noisy_rate_mean,active_jump_rate_mean"
      next
    }
    {
      key = $idx["arm"] "," $idx["candidate_basis"] "," $idx["key_count"] "," $idx["noisy_source_rate"]
      if (!(key in seen)) {
        seen[key] = 1
        keys[++key_count_seen] = key
      }
      count[key]++
      q = $idx["qacc"] + 0
      sum_q[key] += q
      sum_q_sq[key] += q * q
      sum_gap[key] += $idx["route_quality_candidate_weight_factor_gap"] + 0
      sum_fmax[key] += $idx["route_quality_candidate_weight_factor_max"] + 0
      sum_top[key] += $idx["route_quality_candidate_weight_top_share_mean"] + 0
      sum_entropy[key] += $idx["route_quality_candidate_weight_entropy_mean"] + 0
      sum_qgap[key] += $idx["route_quality_score_gap"] + 0
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
        printf "%s,%s,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
          parts[1], parts[2], parts[3], parts[4], count[key], mean_q,
          sqrt(var_q < 0 ? 0 : var_q), sum_gap[key] / count[key],
          sum_fmax[key] / count[key], sum_top[key] / count[key],
          sum_entropy[key] / count[key], sum_qgap[key] / count[key],
          sum_wrong[key] / count[key], sum_noisy[key] / count[key],
          sum_jump[key] / count[key]
      }
    }
  ' "$SUMMARY_CSV" >"$BY_KEY_CSV"
}

run_case() {
  local arm="$1"
  local candidate_basis="$2"
  local vote_margin_weight="$3"
  local top_share_weight="$4"
  local entropy_weight="$5"
  local logdet_weight="$6"
  local channel_weight="$7"
  local source_credit_weight="$8"
  local edge_credit_weight="$9"
  local key_count="${10}"
  local seed="${11}"
  local noisy_rate="${12}"

  local scenario="${arm}-k${key_count}-s${seed}-n${noisy_rate//./p}"
  local fixture="$TMP_DIR/${scenario}.txt"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
  local n
  local metrics

  make_fixture "$fixture" "$key_count"
  n="$(wc -c <"$fixture")"

  echo "quality-candidate-feature-calibration: ${scenario} basis=${candidate_basis} vote=${vote_margin_weight} top=${top_share_weight}" >&2
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
    --route-quality-candidate-weight-beta 8.0 \
    --route-quality-candidate-weight-min 0.5 \
    --route-quality-candidate-weight-max 8.0 \
    --route-quality-candidate-weight-basis "$candidate_basis" \
    --route-quality-source-normalization none \
    --route-quality-eps 1e-4 \
    --route-channel-tension-diagnostics 1 \
    --route-channel-tension-mode margin \
    --route-quality-score 1 \
    --route-quality-logdet-weight "$logdet_weight" \
    --route-quality-entropy-weight "$entropy_weight" \
    --route-quality-vote-margin-weight "$vote_margin_weight" \
    --route-quality-top-share-weight "$top_share_weight" \
    --route-quality-source-credit-weight "$source_credit_weight" \
    --route-quality-edge-credit-weight "$edge_credit_weight" \
    --route-quality-channel-weight "$channel_weight" \
    --csv "$csv_path"

  metrics="$(compute_metrics "$csv_path")"
  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%s,%s\n' \
    "$scenario" \
    "$arm" \
    "$candidate_basis" \
    "$vote_margin_weight" \
    "$top_share_weight" \
    "$entropy_weight" \
    "$logdet_weight" \
    "$channel_weight" \
    "$source_credit_weight" \
    "$edge_credit_weight" \
    "$key_count" \
    "$seed" \
    "$noisy_rate" \
    "$metrics" >>"$SUMMARY_CSV"
}

for key_count in "${KEY_COUNTS[@]}"; do
  for seed in "${SEEDS[@]}"; do
    for noisy_rate in "${NOISY_RATES[@]}"; do
      for arm_spec in "${ARMS[@]}"; do
        IFS=: read -r arm candidate_basis vote_margin_weight top_share_weight entropy_weight logdet_weight channel_weight source_credit_weight edge_credit_weight <<<"$arm_spec"
        run_case "$arm" "$candidate_basis" "$vote_margin_weight" "$top_share_weight" \
          "$entropy_weight" "$logdet_weight" "$channel_weight" \
          "$source_credit_weight" "$edge_credit_weight" \
          "$key_count" "$seed" "$noisy_rate"
      done
    done
  done
done

emit_aggregate

echo "wrote $SUMMARY_CSV"
echo "wrote $AGG_CSV"
echo "wrote $BY_KEY_CSV"
