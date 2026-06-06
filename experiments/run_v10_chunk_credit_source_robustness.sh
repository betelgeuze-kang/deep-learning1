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

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" >/dev/null
cmake --build "$BUILD_DIR" --target dmv02 -j2 >/dev/null

PREFIX="v10_chunk_credit_source_robustness"
KEY_COUNTS=(32 64)
SEEDS=(1)
VALUE_LEN=5
EPOCHS=8
CYCLES_PER_EPOCH=16
PROPOSAL_COUNT=24
CHUNK_CREDIT_WEIGHT=2.0
K_ROUTE=16
ROUTE_HASH_BITS=16

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_chunk_credit_source_robustness_smoke"
  KEY_COUNTS=(16)
  SEEDS=(1)
  EPOCHS=6
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=16
  K_ROUTE=16
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(32 64 128)
  SEEDS=(1 2)
  VALUE_LEN=8
  EPOCHS=10
  CYCLES_PER_EPOCH=20
  PROPOSAL_COUNT=30
  CHUNK_CREDIT_WEIGHT=2.5
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

value_for_index() {
  local index="$1"
  local len="$2"
  local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
  local out=""
  local alphabet_len="${#alphabet}"
  for ((j = 0; j < len; j++)); do
    local pos=$(((index * 13 + j * 7 + j * index) % alphabet_len))
    out+="${alphabet:pos:1}"
  done
  printf "%s" "$out"
}

make_fixture() {
  local path="$1"
  local key_count="$2"
  local value_len="$3"

  : >"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((79000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((79000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc route_span_exact_match_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_top_key_correct_rate route_span_candidate_coherent_wrong_top_key_rate route_credit_gap route_credit_top1_rate route_chunk_credit_gap route_chunk_credit_top1_rate route_fallback_recall route_fallback_qacc route_source_credit_gap route_noisy_source_used_rate route_noisy_source_selected_rate route_source_retry_used_rate route_source_retry_success_rate route_source_retry_raw_selected_rate route_source_retry_keyshape_selected_rate route_source_retry_noisy_selected_rate routing_trigger_rate active_jump_rate", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      for (i = 1; i <= length(names); i++) {
        if (!(names[i] in idx)) {
          printf "missing v10 joint robustness metric column: %s\n", names[i] > "/dev/stderr"
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
        for (i = 1; i <= length(names); i++) {
          name = names[i]
          sum[name] += row[idx[name]] + 0
        }
      }
      for (i = 1; i <= length(names); i++) {
        if (i > 1) printf ","
        name = names[i]
        printf "%.6f", sum[name] / count
      }
    }
  ' "$csv_path"
}

run_case() {
  local arm="$1"
  local fixture="$2"
  local n_bytes="$3"
  local key_count="$4"
  local seed="$5"
  local score="$6"
  local credit_enabled="$7"
  local retry_tiebreak="$8"
  local retry_priorities_csv="$9"
  local retry_priorities_label="${10}"
  local csv_path="$RESULTS_DIR/${PREFIX}_${arm}_k${key_count}_s${seed}.csv"
  local credit_args=()

  if [[ "$credit_enabled" == "1" ]]; then
    credit_args=(
      --route-credit-learning 1
      --route-credit-mode query-value
      --route-credit-score-weight "$CHUNK_CREDIT_WEIGHT"
      --route-credit-eta-reward 0.10
      --route-credit-eta-slash 0.20
      --route-credit-decay 0.0
      --route-credit-clip 4.0
      --route-credit-learn-after-epoch 0
      --route-credit-apply-after-epoch 1
    )
  fi

  echo "v10-chunk-credit-source-robustness: ${arm} k=${key_count} seed=${seed}" >&2
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
    --route-span-hints 1 \
    --route-hash-source route-code-key \
    --route-code-aux 1 \
    --route-code-key-region-only 1 \
    --route-code-key-region-keep-prob 0.25 \
    --route-code-aux-noise-rate 0.75 \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --route-hash-bits "$ROUTE_HASH_BITS" \
    --K-route "$K_ROUTE" \
    --route-hint-agg weighted-vote \
    --route-candidate-score "$score" \
    --route-confidence-threshold 0.75 \
    --route-lowconf-policy aggregate \
    --route-lowconf-agg weighted-vote \
    --route-highconf-agg weighted-vote \
    --route-aggregation-confidence agreement \
    --route-delta-mode target-only \
    --lambda-route 5.0 \
    --route-strength-mode margin \
    --lambda-route-base 0.5 \
    --lambda-route-max 10.0 \
    --route-margin-alpha 1.5 \
    --route-strength-confidence weight \
    --route-corrupt-candidate-rate 0.0 \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct 1 \
    --route-fallback-source noisy-route-code \
    --route-source-retry-source off \
    --route-source-retry-policy source-credit \
    --route-source-retry-tiebreak "$retry_tiebreak" \
    --route-source-retry-priorities "$retry_priorities_csv" \
    --route-source-retry-candidates raw-key,key-shape,noisy-route-code \
    --route-source-retry-per-source-limit 1 \
    --route-noisy-source-rate 1.0 \
    --route-fallback-strength-mode fixed \
    --route-fallback-strength-mult 1.0 \
    --route-fallback-hi-strength-mult 5.0 \
    --route-fallback-lo-strength-mult 10.0 \
    --route-fallback-channel-strength-mode fixed \
    --route-plasticity-ledger 0 \
    --route-plasticity-ledger-decay 0.0 \
    --route-source-credit-learning 1 \
    --route-source-credit-apply-mode ranking-strength \
    --route-source-credit-score-weight 1.0 \
    --route-source-credit-eta-reward 0.05 \
    --route-source-credit-eta-slash 0.10 \
    --route-source-credit-decay 0.0 \
    --route-source-credit-clip 2.0 \
    --route-source-filter-mode negative-credit \
    --route-source-filter-threshold 0.0 \
    "${credit_args[@]}" \
    --csv "$csv_path" >/dev/null

  local metrics
  metrics="$(metric_line "$csv_path")"
  awk -F, -v arm="$arm" -v key_count="$key_count" -v seed="$seed" \
    -v value_len="$VALUE_LEN" -v score="$score" \
    -v credit_enabled="$credit_enabled" -v retry_tiebreak="$retry_tiebreak" \
    -v retry_priorities="$retry_priorities_label" -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%d,%d,%d,%s,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        arm, key_count, seed, value_len, score, credit_enabled,
        retry_tiebreak, retry_priorities,
        m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8],
        m[9], m[10], m[11], m[12], m[13], m[14], m[15], m[16],
        m[17], m[18], m[19], m[20], m[21], m[22]
    }
  ' >>"$SUMMARY_CSV"
}

printf 'arm,key_count,seed,value_len,score,credit_enabled,retry_tiebreak,retry_priorities,qacc,chunk_exact,span_all_recall,span_all_top1,top_key_correct,coherent_wrong_top_key,route_credit_gap,route_credit_top1,chunk_credit_gap,chunk_credit_top1,fallback_recall,fallback_qacc,source_gap,noisy_used,noisy_selected,source_retry_used,source_retry_success,retry_raw_selected,retry_keyshape_selected,retry_noisy_selected,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  fixture="$TMP_DIR/chunk_credit_source_robustness_k${key_count}.txt"
  make_fixture "$fixture" "$key_count" "$VALUE_LEN"
  n_bytes="$(wc -c <"$fixture")"
  for seed in "${SEEDS[@]}"; do
    run_case local-energy-source "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy 0 source-order \
      "raw-key:0.0,key-shape:0.0,noisy-route-code:0.0" \
      "raw-key:0.0+key-shape:0.0+noisy-route-code:0.0"
    run_case chunk-credit-source-order "$fixture" "$n_bytes" "$key_count" "$seed" span-chunk-credit 1 source-order \
      "raw-key:0.0,key-shape:0.0,noisy-route-code:0.0" \
      "raw-key:0.0+key-shape:0.0+noisy-route-code:0.0"
    if [[ "$MODE" != "smoke" ]]; then
      run_case chunk-credit-keyshape-prior "$fixture" "$n_bytes" "$key_count" "$seed" span-chunk-credit 1 source-prior \
        "key-shape:0.2,raw-key:0.0,noisy-route-code:0.0" \
        "key-shape:0.2+raw-key:0.0+noisy-route-code:0.0"
      run_case chunk-credit-noisy-penalty "$fixture" "$n_bytes" "$key_count" "$seed" span-chunk-credit 1 source-prior \
        "key-shape:0.2,raw-key:0.0,noisy-route-code:-1.0" \
        "key-shape:0.2+raw-key:0.0+noisy-route-code:-1.0"
    fi
    run_case keyshape-source "$fixture" "$n_bytes" "$key_count" "$seed" key-shape 0 source-order \
      "raw-key:0.0,key-shape:0.0,noisy-route-code:0.0" \
      "raw-key:0.0+key-shape:0.0+noisy-route-code:0.0"
  done
done

awk -F, -v agg_csv="$AGG_CSV" '
  function safe_candidate(arm, noisy_selected, retry_noisy, eps) {
    if (arm !~ /^chunk-credit-/) return 0
    if (noisy_selected > eps || retry_noisy > eps) return 0
    return 1
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    arm = $idx["arm"]
    counts[arm]++
    qacc[arm] += $idx["qacc"] + 0
    chunk[arm] += $idx["chunk_exact"] + 0
    recall[arm] += $idx["span_all_recall"] + 0
    top1[arm] += $idx["span_all_top1"] + 0
    wrong[arm] += $idx["coherent_wrong_top_key"] + 0
    route_credit_gap[arm] += $idx["route_credit_gap"] + 0
    route_credit_top1[arm] += $idx["route_credit_top1"] + 0
    chunk_credit_gap[arm] += $idx["chunk_credit_gap"] + 0
    chunk_credit_top1[arm] += $idx["chunk_credit_top1"] + 0
    fallback_recall[arm] += $idx["fallback_recall"] + 0
    fallback_qacc[arm] += $idx["fallback_qacc"] + 0
    source_gap[arm] += $idx["source_gap"] + 0
    noisy_used[arm] += $idx["noisy_used"] + 0
    noisy[arm] += $idx["noisy_selected"] + 0
    retry_used[arm] += $idx["source_retry_used"] + 0
    retry_success[arm] += $idx["source_retry_success"] + 0
    retry_raw[arm] += $idx["retry_raw_selected"] + 0
    retry_keyshape[arm] += $idx["retry_keyshape_selected"] + 0
    retry_noisy[arm] += $idx["retry_noisy_selected"] + 0
    routing[arm] += $idx["routing_trigger_rate"] + 0
    jump[arm] += $idx["active_jump_rate"] + 0
  }
  END {
    required_count = split("local-energy-source chunk-credit-source-order keyshape-source", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (counts[required[i]] <= 0) {
        printf "missing v10 joint robustness arm: %s\n", required[i] > "/dev/stderr"
        exit 4
      }
    }

    local_chunk = chunk["local-energy-source"] / counts["local-energy-source"]
    local_qacc = qacc["local-energy-source"] / counts["local-energy-source"]
    local_wrong = wrong["local-energy-source"] / counts["local-energy-source"]
    keyshape_chunk = chunk["keyshape-source"] / counts["keyshape-source"]
    best_arm = ""
    eps = 0.0000005

    candidate_count = split("chunk-credit-source-order chunk-credit-keyshape-prior chunk-credit-noisy-penalty", candidates, " ")
    for (i = 1; i <= candidate_count; i++) {
      arm = candidates[i]
      if (counts[arm] <= 0) continue
      arm_qacc = qacc[arm] / counts[arm]
      arm_chunk = chunk[arm] / counts[arm]
      arm_wrong = wrong[arm] / counts[arm]
      arm_noisy = noisy[arm] / counts[arm]
      arm_retry_noisy = retry_noisy[arm] / counts[arm]
      if (!safe_candidate(arm, arm_noisy, arm_retry_noisy, eps)) continue
      if (best_arm == "" ||
          arm_chunk > best_chunk + eps ||
          (arm_chunk >= best_chunk - eps && arm_wrong < best_wrong - eps) ||
          (arm_chunk >= best_chunk - eps && arm_wrong <= best_wrong + eps && arm_qacc > best_qacc + eps)) {
        best_arm = arm
        best_qacc = arm_qacc
        best_chunk = arm_chunk
        best_wrong = arm_wrong
      }
    }
    if (best_arm == "") {
      printf "no safe v10 joint robustness candidate\n" > "/dev/stderr"
      exit 5
    }

    best_recall = recall[best_arm] / counts[best_arm]
    best_top1 = top1[best_arm] / counts[best_arm]
    best_route_credit_gap = route_credit_gap[best_arm] / counts[best_arm]
    best_route_credit_top1 = route_credit_top1[best_arm] / counts[best_arm]
    best_chunk_credit_gap = chunk_credit_gap[best_arm] / counts[best_arm]
    best_chunk_credit_top1 = chunk_credit_top1[best_arm] / counts[best_arm]
    best_fallback_recall = fallback_recall[best_arm] / counts[best_arm]
    best_fallback_qacc = fallback_qacc[best_arm] / counts[best_arm]
    best_source_gap = source_gap[best_arm] / counts[best_arm]
    best_noisy_used = noisy_used[best_arm] / counts[best_arm]
    best_noisy = noisy[best_arm] / counts[best_arm]
    best_retry_used = retry_used[best_arm] / counts[best_arm]
    best_retry_success = retry_success[best_arm] / counts[best_arm]
    best_retry_raw = retry_raw[best_arm] / counts[best_arm]
    best_retry_keyshape = retry_keyshape[best_arm] / counts[best_arm]
    best_retry_noisy = retry_noisy[best_arm] / counts[best_arm]
    best_routing = routing[best_arm] / counts[best_arm]
    best_jump = jump[best_arm] / counts[best_arm]
    keyshape_gap = keyshape_chunk - best_chunk
    top1_recall_gap = best_recall - best_top1

    chunk_ready = best_chunk >= 0.90 &&
      best_wrong <= 0.05 &&
      top1_recall_gap <= 0.05 &&
      keyshape_gap <= 0.05 &&
      best_chunk_credit_top1 >= 0.99 &&
      best_routing == 0.0 &&
      best_jump == 0.0 ? 1 : 0
    source_safe = best_qacc >= 0.90 &&
      best_noisy_used > 0.0 &&
      best_noisy == 0.0 &&
      best_retry_noisy == 0.0 &&
      best_routing == 0.0 &&
      best_jump == 0.0 ? 1 : 0
    fallback_not_keyshape_only = best_retry_keyshape < 0.50 || best_retry_raw > 0.0 ? 1 : 0
    fallback_retry_exercised = best_retry_used > 0.0 || best_fallback_recall > 0.0 ? 1 : 0
    joint_chunk_source_ready = chunk_ready && source_safe &&
      fallback_not_keyshape_only && fallback_retry_exercised ? 1 : 0
    recommendation = joint_chunk_source_ready ? "joint-ready-diagnostic" : "noisy-clean-fallback-unexercised"

    print "rows,groups,best_joint_arm,local_energy_qacc,best_joint_qacc,keyshape_qacc,local_energy_chunk_exact,best_joint_chunk_exact,keyshape_chunk_exact,best_qacc_delta_vs_local_energy,best_chunk_delta_vs_local_energy,best_wrong_delta_vs_local_energy,keyshape_chunk_gap,top1_recall_gap,chunk_ready,source_safe,fallback_not_keyshape_only,fallback_retry_exercised,joint_chunk_source_ready,recommendation,route_credit_gap,route_credit_top1,chunk_credit_gap,chunk_credit_top1,fallback_recall,fallback_qacc,source_gap,noisy_used,noisy_selected,source_retry_used,source_retry_success,retry_raw_selected,retry_keyshape_selected,retry_noisy_selected,routing_trigger_rate,active_jump_rate" > agg_csv
    printf "%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      counts[best_arm],
      best_arm,
      local_qacc,
      best_qacc,
      qacc["keyshape-source"] / counts["keyshape-source"],
      local_chunk,
      best_chunk,
      keyshape_chunk,
      best_qacc - local_qacc,
      best_chunk - local_chunk,
      best_wrong - local_wrong,
      keyshape_gap,
      top1_recall_gap,
      chunk_ready,
      source_safe,
      fallback_not_keyshape_only,
      fallback_retry_exercised,
      joint_chunk_source_ready,
      recommendation,
      best_route_credit_gap,
      best_route_credit_top1,
      best_chunk_credit_gap,
      best_chunk_credit_top1,
      best_fallback_recall,
      best_fallback_qacc,
      best_source_gap,
      best_noisy_used,
      best_noisy,
      best_retry_used,
      best_retry_success,
      best_retry_raw,
      best_retry_keyshape,
      best_retry_noisy,
      best_routing,
      best_jump >> agg_csv
  }
' "$SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "aggregate: $AGG_CSV"
