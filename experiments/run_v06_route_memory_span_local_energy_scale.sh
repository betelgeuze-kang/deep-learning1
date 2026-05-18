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

PREFIX="v06_route_memory_span_local_energy_scale"
KEY_COUNTS=(32 64)
SEEDS=(1 2)
VALUE_LEN=5
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_local_energy_scale_smoke"
  KEY_COUNTS=(32)
  SEEDS=(1)
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(32 64 128)
  SEEDS=(1 2 3)
  VALUE_LEN=8
  EPOCHS=8
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
    local key=$((73000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((73000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("fixture_query_byte_acc route_span_exact_match_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_correct_key_share_mean route_span_candidate_key_entropy_mean route_span_candidate_coherent_wrong_top_key_rate routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span local-energy scale metric column: %s\n", required[i] > "/dev/stderr"
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
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_span_exact_match_rate"]] + 0,
        row[idx["route_span_candidate_all_recall_rate"]] + 0,
        row[idx["route_span_candidate_all_top1_rate"]] + 0,
        row[idx["route_span_candidate_correct_key_share_mean"]] + 0,
        row[idx["route_span_candidate_key_entropy_mean"]] + 0,
        row[idx["route_span_candidate_coherent_wrong_top_key_rate"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local scenario="$1"
  local fixture="$2"
  local n_bytes="$3"
  local key_count="$4"
  local seed="$5"
  local score="$6"
  local csv_path="$RESULTS_DIR/${PREFIX}_${scenario}_k${key_count}_s${seed}.csv"

  echo "v06-span-local-energy-scale: ${scenario} k=${key_count} seed=${seed}" >&2
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
    --route-candidate-score "$score" \
    --lambda-route 5.0 \
    --csv "$csv_path" >/dev/null

  local metrics
  metrics="$(metric_line "$csv_path")"
  awk -F, -v scenario="$scenario" -v key_count="$key_count" \
    -v seed="$seed" -v value_len="$VALUE_LEN" -v score="$score" \
    -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%d,%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        scenario, key_count, seed, value_len, score,
        m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
    }
  ' >>"$SUMMARY_CSV"
}

printf 'scenario,key_count,seed,value_len,score,qacc,span_exact,span_all_recall,span_all_top1,correct_key_share,key_entropy,coherent_wrong_top_key,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  fixture="$TMP_DIR/span_local_energy_scale_k${key_count}.txt"
  make_fixture "$fixture" "$key_count" "$VALUE_LEN"
  n_bytes="$(wc -c <"$fixture")"
  for seed in "${SEEDS[@]}"; do
    run_case weak "$fixture" "$n_bytes" "$key_count" "$seed" insertion
    run_case span-local-energy "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy
    run_case keyshape "$fixture" "$n_bytes" "$key_count" "$seed" key-shape
  done
done

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "rows,groups,weak_qacc_mean,local_energy_qacc_mean,keyshape_qacc_mean,local_energy_qacc_delta_mean,weak_span_exact_mean,local_energy_span_exact_mean,keyshape_span_exact_mean,local_energy_span_exact_delta_mean,weak_all_recall_mean,local_energy_all_recall_mean,weak_all_top1_mean,local_energy_all_top1_mean,keyshape_all_top1_mean,weak_correct_key_share_mean,local_energy_correct_key_share_mean,keyshape_correct_key_share_mean,weak_key_entropy_mean,local_energy_key_entropy_mean,keyshape_key_entropy_mean,weak_coherent_wrong_mean,local_energy_coherent_wrong_mean,routing_trigger_rate_mean,active_jump_rate_mean"
    next
  }
  {
    rows++
    key = $idx["key_count"] ":" $idx["seed"]
    groups[key] = 1
    scenario = $idx["scenario"]
    qacc[scenario] += $idx["qacc"] + 0
    span_exact[scenario] += $idx["span_exact"] + 0
    all_recall[scenario] += $idx["span_all_recall"] + 0
    all_top1[scenario] += $idx["span_all_top1"] + 0
    correct_share[scenario] += $idx["correct_key_share"] + 0
    entropy[scenario] += $idx["key_entropy"] + 0
    coherent_wrong[scenario] += $idx["coherent_wrong_top_key"] + 0
    counts[scenario] += 1
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    group_count = 0
    for (key in groups) {
      group_count++
    }
    if (group_count <= 0 || counts["weak"] <= 0 ||
        counts["span-local-energy"] <= 0 || counts["keyshape"] <= 0) {
      printf "invalid span local-energy scale rows\n" > "/dev/stderr"
      exit 4
    }
    printf "%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      group_count,
      qacc["weak"] / counts["weak"],
      qacc["span-local-energy"] / counts["span-local-energy"],
      qacc["keyshape"] / counts["keyshape"],
      qacc["span-local-energy"] / counts["span-local-energy"] - qacc["weak"] / counts["weak"],
      span_exact["weak"] / counts["weak"],
      span_exact["span-local-energy"] / counts["span-local-energy"],
      span_exact["keyshape"] / counts["keyshape"],
      span_exact["span-local-energy"] / counts["span-local-energy"] - span_exact["weak"] / counts["weak"],
      all_recall["weak"] / counts["weak"],
      all_recall["span-local-energy"] / counts["span-local-energy"],
      all_top1["weak"] / counts["weak"],
      all_top1["span-local-energy"] / counts["span-local-energy"],
      all_top1["keyshape"] / counts["keyshape"],
      correct_share["weak"] / counts["weak"],
      correct_share["span-local-energy"] / counts["span-local-energy"],
      correct_share["keyshape"] / counts["keyshape"],
      entropy["weak"] / counts["weak"],
      entropy["span-local-energy"] / counts["span-local-energy"],
      entropy["keyshape"] / counts["keyshape"],
      coherent_wrong["weak"] / counts["weak"],
      coherent_wrong["span-local-energy"] / counts["span-local-energy"],
      routing / rows,
      jump / rows
  }
' "$SUMMARY_CSV" >"$AGG_CSV"

echo "summary: $SUMMARY_CSV"
echo "aggregate: $AGG_CSV"
