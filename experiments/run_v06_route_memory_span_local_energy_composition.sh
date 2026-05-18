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

PREFIX="v06_route_memory_span_local_energy_composition"
KEY_COUNT=32
VALUE_LEN=5
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_local_energy_composition_smoke"
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNT=64
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
      required_count = split("fixture_query_byte_acc route_span_exact_match_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_correct_key_share_mean route_span_candidate_key_entropy_mean route_span_candidate_coherent_wrong_top_key_rate route_quality_candidate_weight_factor_mean route_quality_candidate_weight_factor_max routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span local-energy composition metric column: %s\n", required[i] > "/dev/stderr"
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
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_span_exact_match_rate"]] + 0,
        row[idx["route_span_candidate_all_recall_rate"]] + 0,
        row[idx["route_span_candidate_all_top1_rate"]] + 0,
        row[idx["route_span_candidate_correct_key_share_mean"]] + 0,
        row[idx["route_span_candidate_key_entropy_mean"]] + 0,
        row[idx["route_span_candidate_coherent_wrong_top_key_rate"]] + 0,
        row[idx["route_quality_candidate_weight_factor_mean"]] + 0,
        row[idx["route_quality_candidate_weight_factor_max"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local label="$1"
  local score="$2"
  local preset="$3"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"

  local preset_args=()
  if [[ "$preset" != "none" ]]; then
    preset_args=(--route-quality-candidate-weight-preset "$preset")
  fi

  echo "v06-span-local-energy-composition: ${label}" >&2
  "$BUILD_DIR/dmv02" \
    --input "$FIXTURE" \
    --N "$N_BYTES" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch "$CYCLES_PER_EPOCH" \
    --seed 1 \
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
    "${preset_args[@]}" \
    --csv "$csv_path" >/dev/null

  local metrics
  metrics="$(metric_line "$csv_path")"
  awk -F, -v label="$label" -v key_count="$KEY_COUNT" \
    -v value_len="$VALUE_LEN" -v score="$score" -v preset="$preset" \
    -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%d,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        label, key_count, value_len, score, preset,
        m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]
    }
  ' >>"$SUMMARY_CSV"
}

FIXTURE="$TMP_DIR/span_local_energy_composition.txt"
make_fixture "$FIXTURE" "$KEY_COUNT" "$VALUE_LEN"
N_BYTES="$(wc -c <"$FIXTURE")"

printf 'scenario,key_count,value_len,score,preset,qacc,span_exact,span_all_recall,span_all_top1,correct_key_share,key_entropy,coherent_wrong_top_key,factor_mean,factor_max,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

run_case weak insertion none
run_case local-energy span-local-energy none
run_case local-energy-base span-local-energy base-default
run_case local-energy-hybrid span-local-energy hybrid-safe
run_case keyshape key-shape none

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "rows,weak_qacc,local_energy_qacc,local_energy_base_qacc,local_energy_hybrid_qacc,keyshape_qacc,weak_span_exact,local_energy_span_exact,local_energy_base_span_exact,local_energy_hybrid_span_exact,keyshape_span_exact,weak_all_top1,local_energy_all_top1,local_energy_base_all_top1,local_energy_hybrid_all_top1,keyshape_all_top1,weak_correct_key_share,local_energy_correct_key_share,local_energy_base_correct_key_share,local_energy_hybrid_correct_key_share,keyshape_correct_key_share,weak_key_entropy,local_energy_key_entropy,local_energy_base_key_entropy,local_energy_hybrid_key_entropy,keyshape_key_entropy,local_energy_delta,local_energy_base_delta,local_energy_hybrid_delta,routing_trigger_rate_mean,active_jump_rate_mean"
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    qacc[scenario] = $idx["qacc"] + 0
    span_exact[scenario] = $idx["span_exact"] + 0
    all_top1[scenario] = $idx["span_all_top1"] + 0
    correct_share[scenario] = $idx["correct_key_share"] + 0
    entropy[scenario] = $idx["key_entropy"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 5) {
      printf "invalid span local-energy composition rows\n" > "/dev/stderr"
      exit 4
    }
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      qacc["weak"],
      qacc["local-energy"],
      qacc["local-energy-base"],
      qacc["local-energy-hybrid"],
      qacc["keyshape"],
      span_exact["weak"],
      span_exact["local-energy"],
      span_exact["local-energy-base"],
      span_exact["local-energy-hybrid"],
      span_exact["keyshape"],
      all_top1["weak"],
      all_top1["local-energy"],
      all_top1["local-energy-base"],
      all_top1["local-energy-hybrid"],
      all_top1["keyshape"],
      correct_share["weak"],
      correct_share["local-energy"],
      correct_share["local-energy-base"],
      correct_share["local-energy-hybrid"],
      correct_share["keyshape"],
      entropy["weak"],
      entropy["local-energy"],
      entropy["local-energy-base"],
      entropy["local-energy-hybrid"],
      entropy["keyshape"],
      qacc["local-energy"] - qacc["weak"],
      qacc["local-energy-base"] - qacc["weak"],
      qacc["local-energy-hybrid"] - qacc["weak"],
      routing / rows,
      jump / rows
  }
' "$SUMMARY_CSV" >"$AGG_CSV"

echo "summary: $SUMMARY_CSV"
echo "aggregate: $AGG_CSV"
