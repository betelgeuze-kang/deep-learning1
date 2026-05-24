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

PREFIX="v10_chunk_credit_fallback_retry_exercise"
KEY_COUNTS=(32)
SEEDS=(1)
VALUE_LEN=5
EPOCHS=8
CYCLES_PER_EPOCH=12
PROPOSAL_COUNT=20
CHUNK_CREDIT_WEIGHT=2.0

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_chunk_credit_fallback_retry_exercise_smoke"
  KEY_COUNTS=(16)
  EPOCHS=6
  CYCLES_PER_EPOCH=8
  PROPOSAL_COUNT=16
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(32 64)
  SEEDS=(1 2)
  VALUE_LEN=8
  EPOCHS=10
  CYCLES_PER_EPOCH=16
  PROPOSAL_COUNT=24
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
    local key=$((80000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((80000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    BEGIN {
      split("fixture_query_byte_acc route_span_exact_match_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_coherent_wrong_top_key_rate route_credit_gap route_credit_top1_rate route_chunk_credit_gap route_chunk_credit_top1_rate route_fallback_used_rate route_fallback_recall route_fallback_qacc route_fallback_success_rate route_source_retry_used_rate route_source_retry_success_rate route_source_retry_raw_selected_rate route_source_retry_keyshape_selected_rate route_source_retry_noisy_selected_rate route_noisy_source_used_rate route_noisy_source_selected_rate routing_trigger_rate active_jump_rate", names, " ")
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      for (i = 1; i <= length(names); i++) {
        if (!(names[i] in idx)) {
          printf "missing h10 fallback exercise metric column: %s\n", names[i] > "/dev/stderr"
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
  local fallback_source="$6"
  local retry_policy="$7"
  local retry_tiebreak="$8"
  local retry_priorities_csv="$9"
  local retry_priorities_label="${10}"
  local csv_path="$RESULTS_DIR/${PREFIX}_${arm}_k${key_count}_s${seed}.csv"

  echo "v10-chunk-credit-fallback-retry: ${arm} k=${key_count} seed=${seed}" >&2
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
    --route-hash-bits 16 \
    --K-route 16 \
    --route-hint-agg weighted-vote \
    --route-candidate-score span-chunk-credit \
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
    --route-corrupt-candidate-rate 1.0 \
    --route-corrupt-confidence keep \
    --route-corrupt-preserve-correct 0 \
    --route-fallback-source "$fallback_source" \
    --route-source-retry-source off \
    --route-source-retry-policy "$retry_policy" \
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
    --route-credit-learning 1 \
    --route-credit-mode query-value \
    --route-credit-score-weight "$CHUNK_CREDIT_WEIGHT" \
    --route-credit-eta-reward 0.10 \
    --route-credit-eta-slash 0.20 \
    --route-credit-decay 0.0 \
    --route-credit-clip 4.0 \
    --route-credit-learn-after-epoch 0 \
    --route-credit-apply-after-epoch 1 \
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
    --csv "$csv_path" >/dev/null

  local metrics
  metrics="$(metric_line "$csv_path")"
  awk -F, -v arm="$arm" -v key_count="$key_count" -v seed="$seed" \
    -v value_len="$VALUE_LEN" -v fallback_source="$fallback_source" \
    -v retry_policy="$retry_policy" -v retry_tiebreak="$retry_tiebreak" \
    -v retry_priorities="$retry_priorities_label" -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%d,%d,%d,%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        arm, key_count, seed, value_len, fallback_source, retry_policy,
        retry_tiebreak, retry_priorities,
        m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10],
        m[11], m[12], m[13], m[14], m[15], m[16], m[17], m[18], m[19],
        m[20], m[21], m[22]
    }
  ' >>"$SUMMARY_CSV"
}

printf 'arm,key_count,seed,value_len,fallback_source,retry_policy,retry_tiebreak,retry_priorities,qacc,chunk_exact,span_all_recall,span_all_top1,coherent_wrong_top_key,route_credit_gap,route_credit_top1,chunk_credit_gap,chunk_credit_top1,fallback_used,fallback_recall,fallback_qacc,fallback_success,source_retry_used,source_retry_success,retry_raw_selected,retry_keyshape_selected,retry_noisy_selected,noisy_used,noisy_selected,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  fixture="$TMP_DIR/chunk_credit_fallback_retry_k${key_count}.txt"
  make_fixture "$fixture" "$key_count" "$VALUE_LEN"
  n_bytes="$(wc -c <"$fixture")"
  for seed in "${SEEDS[@]}"; do
    run_case corrupt-no-retry "$fixture" "$n_bytes" "$key_count" "$seed" off fixed source-order \
      "raw-key:0.0,key-shape:0.0,noisy-route-code:0.0" \
      "raw-key:0.0+key-shape:0.0+noisy-route-code:0.0"
    run_case raw-retry "$fixture" "$n_bytes" "$key_count" "$seed" noisy-route-code source-credit source-order \
      "raw-key:0.0,key-shape:0.0,noisy-route-code:0.0" \
      "raw-key:0.0+key-shape:0.0+noisy-route-code:0.0"
    if [[ "$MODE" != "smoke" ]]; then
      run_case noisy-penalty-retry "$fixture" "$n_bytes" "$key_count" "$seed" noisy-route-code source-credit source-prior \
        "key-shape:0.2,raw-key:0.0,noisy-route-code:-1.0" \
        "key-shape:0.2+raw-key:0.0+noisy-route-code:-1.0"
    fi
  done
done

awk -F, -v agg_csv="$AGG_CSV" '
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
    wrong[arm] += $idx["coherent_wrong_top_key"] + 0
    route_credit_gap[arm] += $idx["route_credit_gap"] + 0
    chunk_credit_gap[arm] += $idx["chunk_credit_gap"] + 0
    chunk_credit_top1[arm] += $idx["chunk_credit_top1"] + 0
    fallback_used[arm] += $idx["fallback_used"] + 0
    fallback_recall[arm] += $idx["fallback_recall"] + 0
    fallback_qacc[arm] += $idx["fallback_qacc"] + 0
    fallback_success[arm] += $idx["fallback_success"] + 0
    retry_used[arm] += $idx["source_retry_used"] + 0
    retry_success[arm] += $idx["source_retry_success"] + 0
    retry_raw[arm] += $idx["retry_raw_selected"] + 0
    retry_keyshape[arm] += $idx["retry_keyshape_selected"] + 0
    retry_noisy[arm] += $idx["retry_noisy_selected"] + 0
    noisy_used[arm] += $idx["noisy_used"] + 0
    noisy[arm] += $idx["noisy_selected"] + 0
    routing[arm] += $idx["routing_trigger_rate"] + 0
    jump[arm] += $idx["active_jump_rate"] + 0
  }
  END {
    required_count = split("corrupt-no-retry raw-retry", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (counts[required[i]] <= 0) {
        printf "missing h10 fallback exercise arm: %s\n", required[i] > "/dev/stderr"
        exit 4
      }
    }
    baseline = "corrupt-no-retry"
    best = "raw-retry"
    if (counts["noisy-penalty-retry"] > 0) {
      noisy_penalty_qacc = qacc["noisy-penalty-retry"] / counts["noisy-penalty-retry"]
      best_current_qacc = qacc[best] / counts[best]
      if (noisy_penalty_qacc > best_current_qacc) {
        best = "noisy-penalty-retry"
      }
    }

    best_qacc = qacc[best] / counts[best]
    best_chunk = chunk[best] / counts[best]
    best_wrong = wrong[best] / counts[best]
    base_qacc = qacc[baseline] / counts[baseline]
    base_chunk = chunk[baseline] / counts[baseline]
    best_retry_used = retry_used[best] / counts[best]
    best_retry_success = retry_success[best] / counts[best]
    best_retry_raw = retry_raw[best] / counts[best]
    best_retry_keyshape = retry_keyshape[best] / counts[best]
    best_retry_noisy = retry_noisy[best] / counts[best]
    best_noisy = noisy[best] / counts[best]
    best_routing = routing[best] / counts[best]
    best_jump = jump[best] / counts[best]
    fallback_retry_exercised = 0
    if (best_retry_used > 0.0 && best_retry_success > 0.0) {
      fallback_retry_exercised = 1
    }
    fallback_not_keyshape_only = 0
    if (best_retry_keyshape < 0.50 || best_retry_raw > 0.0) {
      fallback_not_keyshape_only = 1
    }
    fallback_ready = 0
    if (fallback_retry_exercised &&
        fallback_not_keyshape_only &&
        best_retry_noisy == 0.0 &&
        best_noisy == 0.0 &&
        best_qacc > base_qacc &&
        best_routing == 0.0 &&
        best_jump == 0.0) {
      fallback_ready = 1
    }

    print "rows,groups,best_arm,baseline_qacc,best_qacc,baseline_chunk_exact,best_chunk_exact,best_qacc_delta_vs_corrupt,best_chunk_delta_vs_corrupt,best_coherent_wrong,route_credit_gap,chunk_credit_gap,chunk_credit_top1,fallback_used,fallback_recall,fallback_qacc,fallback_success,source_retry_used,source_retry_success,retry_raw_selected,retry_keyshape_selected,retry_noisy_selected,noisy_used,noisy_selected,fallback_retry_exercised,fallback_not_keyshape_only,fallback_ready,routing_trigger_rate,active_jump_rate" > agg_csv
    printf "%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%.6f,%.6f\n",
      rows,
      counts[best],
      best,
      base_qacc,
      best_qacc,
      base_chunk,
      best_chunk,
      best_qacc - base_qacc,
      best_chunk - base_chunk,
      best_wrong,
      route_credit_gap[best] / counts[best],
      chunk_credit_gap[best] / counts[best],
      chunk_credit_top1[best] / counts[best],
      fallback_used[best] / counts[best],
      fallback_recall[best] / counts[best],
      fallback_qacc[best] / counts[best],
      fallback_success[best] / counts[best],
      best_retry_used,
      best_retry_success,
      best_retry_raw,
      best_retry_keyshape,
      best_retry_noisy,
      noisy_used[best] / counts[best],
      best_noisy,
      fallback_retry_exercised,
      fallback_not_keyshape_only,
      fallback_ready,
      best_routing,
      best_jump >> agg_csv
  }
' "$SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "aggregate: $AGG_CSV"
