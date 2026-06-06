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

PREFIX="v06_route_memory_chunk_code_similarity"
KEY_COUNTS=(32 64)
SEEDS=(1)
VALUE_LEN=5
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_chunk_code_similarity_smoke"
  KEY_COUNTS=(32)
  SEEDS=(1)
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(32 64 128)
  SEEDS=(1 2)
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
    local key=$((77000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((77000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("fixture_query_byte_acc route_span_exact_match_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_correct_key_share_mean route_span_candidate_key_entropy_mean route_span_candidate_top_key_consistency_rate route_span_candidate_top_key_correct_rate route_span_candidate_coherent_wrong_top_key_rate key_region_route_decode_acc route_signature_collision_rate routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing chunk code-similarity metric column: %s\n", required[i] > "/dev/stderr"
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
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_span_exact_match_rate"]] + 0,
        row[idx["route_span_candidate_all_recall_rate"]] + 0,
        row[idx["route_span_candidate_all_top1_rate"]] + 0,
        row[idx["route_span_candidate_correct_key_share_mean"]] + 0,
        row[idx["route_span_candidate_key_entropy_mean"]] + 0,
        row[idx["route_span_candidate_top_key_consistency_rate"]] + 0,
        row[idx["route_span_candidate_top_key_correct_rate"]] + 0,
        row[idx["route_span_candidate_coherent_wrong_top_key_rate"]] + 0,
        row[idx["key_region_route_decode_acc"]] + 0,
        row[idx["route_signature_collision_rate"]] + 0,
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

  echo "v06-chunk-code-similarity: ${scenario} k=${key_count} seed=${seed}" >&2
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
      printf "%s,%d,%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        scenario, key_count, seed, value_len, score, m[1], m[2], m[3], m[4],
        m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12], m[13]
    }
  ' >>"$SUMMARY_CSV"
}

printf 'scenario,key_count,seed,value_len,score,qacc,chunk_exact,span_all_recall,span_all_top1,correct_key_share,key_entropy,top_key_consistency,top_key_correct,coherent_wrong_top_key,route_decode,route_signature_collision,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  fixture="$TMP_DIR/chunk_code_similarity_k${key_count}.txt"
  make_fixture "$fixture" "$key_count" "$VALUE_LEN"
  n_bytes="$(wc -c <"$fixture")"
  for seed in "${SEEDS[@]}"; do
    run_case weak "$fixture" "$n_bytes" "$key_count" "$seed" insertion
    run_case span-local-energy "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy
    run_case span-route-code "$fixture" "$n_bytes" "$key_count" "$seed" span-route-code
    run_case span-local-energy-route-code "$fixture" "$n_bytes" "$key_count" "$seed" span-local-energy-route-code
    run_case keyshape "$fixture" "$n_bytes" "$key_count" "$seed" key-shape
  done
done

awk -F, -v agg_csv="$AGG_CSV" '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    counts[scenario]++
    qacc[scenario] += $idx["qacc"] + 0
    chunk[scenario] += $idx["chunk_exact"] + 0
    recall[scenario] += $idx["span_all_recall"] + 0
    top1[scenario] += $idx["span_all_top1"] + 0
    coherent_wrong[scenario] += $idx["coherent_wrong_top_key"] + 0
    route_decode += $idx["route_decode"] + 0
    route_collision += $idx["route_signature_collision"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    required_count = split("weak span-local-energy span-route-code span-local-energy-route-code keyshape", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (counts[required[i]] <= 0) {
        printf "missing chunk code-similarity scenario: %s\n", required[i] > "/dev/stderr"
        exit 4
      }
    }
    local_chunk = chunk["span-local-energy"] / counts["span-local-energy"]
    local_qacc = qacc["span-local-energy"] / counts["span-local-energy"]
    local_wrong = coherent_wrong["span-local-energy"] / counts["span-local-energy"]
    best_scenario = "span-local-energy"
    best_chunk = local_chunk
    best_qacc = local_qacc
    best_wrong = local_wrong
    candidate_count = split("span-route-code span-local-energy-route-code", candidates, " ")
    for (i = 1; i <= candidate_count; i++) {
      candidate = candidates[i]
      candidate_chunk = chunk[candidate] / counts[candidate]
      candidate_qacc = qacc[candidate] / counts[candidate]
      candidate_wrong = coherent_wrong[candidate] / counts[candidate]
      if (candidate_chunk > best_chunk ||
          (candidate_chunk == best_chunk && candidate_wrong < best_wrong) ||
          (candidate_chunk == best_chunk && candidate_wrong == best_wrong && candidate_qacc > best_qacc)) {
        best_scenario = candidate
        best_chunk = candidate_chunk
        best_qacc = candidate_qacc
        best_wrong = candidate_wrong
      }
    }
    print "rows,groups,weak_qacc,local_energy_qacc,route_code_qacc,local_energy_route_code_qacc,keyshape_qacc,weak_chunk_exact,local_energy_chunk_exact,route_code_chunk_exact,local_energy_route_code_chunk_exact,keyshape_chunk_exact,weak_top1_recall_gap,local_energy_top1_recall_gap,route_code_top1_recall_gap,local_energy_route_code_top1_recall_gap,weak_coherent_wrong,local_energy_coherent_wrong,route_code_coherent_wrong,local_energy_route_code_coherent_wrong,best_non_keyshape_scorer,best_non_keyshape_chunk_exact,best_qacc_delta_vs_local_energy,best_chunk_delta_vs_local_energy,best_wrong_delta_vs_local_energy,keyshape_chunk_gap,route_decode_mean,route_signature_collision_mean,routing_trigger_rate_mean,active_jump_rate_mean" > agg_csv
    printf "%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      counts["weak"],
      qacc["weak"] / counts["weak"],
      local_qacc,
      qacc["span-route-code"] / counts["span-route-code"],
      qacc["span-local-energy-route-code"] / counts["span-local-energy-route-code"],
      qacc["keyshape"] / counts["keyshape"],
      chunk["weak"] / counts["weak"],
      local_chunk,
      chunk["span-route-code"] / counts["span-route-code"],
      chunk["span-local-energy-route-code"] / counts["span-local-energy-route-code"],
      chunk["keyshape"] / counts["keyshape"],
      recall["weak"] / counts["weak"] - top1["weak"] / counts["weak"],
      recall["span-local-energy"] / counts["span-local-energy"] - top1["span-local-energy"] / counts["span-local-energy"],
      recall["span-route-code"] / counts["span-route-code"] - top1["span-route-code"] / counts["span-route-code"],
      recall["span-local-energy-route-code"] / counts["span-local-energy-route-code"] - top1["span-local-energy-route-code"] / counts["span-local-energy-route-code"],
      coherent_wrong["weak"] / counts["weak"],
      local_wrong,
      coherent_wrong["span-route-code"] / counts["span-route-code"],
      coherent_wrong["span-local-energy-route-code"] / counts["span-local-energy-route-code"],
      best_scenario,
      best_chunk,
      best_qacc - local_qacc,
      best_chunk - local_chunk,
      best_wrong - local_wrong,
      chunk["keyshape"] / counts["keyshape"] - best_chunk,
      route_decode / rows,
      route_collision / rows,
      routing / rows,
      jump / rows >> agg_csv
  }
' "$SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "aggregate: $AGG_CSV"
