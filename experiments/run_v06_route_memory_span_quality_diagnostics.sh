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

PREFIX="v06_route_memory_span_quality_diagnostics"
KEY_COUNT=32
VALUE_LEN=5
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_quality_diagnostics_smoke"
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
    local key=$((72000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((72000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("route_hint_query_count route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean route_bucket_collision_rate fixture_query_byte_acc route_span_group_count route_span_mean_query_count route_span_exact_match_rate route_span_selected_key_consistency_rate route_span_selected_correct_key_rate route_span_candidate_all_recall_rate route_span_candidate_all_top1_rate route_span_candidate_offset_recall_rate route_span_candidate_offset_top1_rate key_region_route_decode_acc route_key_unique_count route_signature_collision_rate routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span quality metric column: %s\n", required[i] > "/dev/stderr"
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
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["route_hint_query_count"]] + 0,
        row[idx["route_candidate_query_count"]] + 0,
        row[idx["route_candidate_recall_rate"]] + 0,
        row[idx["route_candidate_top1_rate"]] + 0,
        row[idx["route_candidate_rank_mean"]] + 0,
        row[idx["route_bucket_collision_rate"]] + 0,
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["route_span_group_count"]] + 0,
        row[idx["route_span_mean_query_count"]] + 0,
        row[idx["route_span_exact_match_rate"]] + 0,
        row[idx["route_span_selected_key_consistency_rate"]] + 0,
        row[idx["route_span_selected_correct_key_rate"]] + 0,
        row[idx["route_span_candidate_all_recall_rate"]] + 0,
        row[idx["route_span_candidate_all_top1_rate"]] + 0,
        row[idx["route_span_candidate_offset_recall_rate"]] + 0,
        row[idx["route_span_candidate_offset_top1_rate"]] + 0,
        row[idx["key_region_route_decode_acc"]] + 0,
        row[idx["route_key_unique_count"]] + 0,
        row[idx["route_signature_collision_rate"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local label="$1"
  local keep_prob="$2"
  local aux_noise="$3"
  local k_route="$4"
  local score="$5"
  local preset="$6"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"

  local preset_args=()
  if [[ "$preset" != "none" ]]; then
    preset_args=(--route-quality-candidate-weight-preset "$preset")
  fi

  echo "v06-span-quality: ${label}" >&2
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
    --route-code-key-region-keep-prob "$keep_prob" \
    --route-code-aux-noise-rate "$aux_noise" \
    --eta-route-code 0.25 \
    --lambda-route-code-id 1.0 \
    --route-hash-bits 16 \
    --K-route "$k_route" \
    --route-hint-agg weighted-vote \
    --route-candidate-score "$score" \
    --lambda-route 5.0 \
    "${preset_args[@]}" \
    --csv "$csv_path" >/dev/null

  local metrics
  metrics="$(metric_line "$csv_path")"
  awk -F, -v label="$label" -v key_count="$KEY_COUNT" \
    -v value_len="$VALUE_LEN" -v keep_prob="$keep_prob" \
    -v aux_noise="$aux_noise" -v k_route="$k_route" \
    -v score="$score" -v preset="$preset" \
    -v expected="$EXPECTED_QUERY_COUNT" -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%d,%d,%s,%s,%d,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        label, key_count, value_len, keep_prob, aux_noise, k_route, score, preset,
        expected, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9],
        m[10], m[11], m[12], m[13], m[14], m[15], m[16], m[17], m[18],
        m[19], m[20], m[21]
    }
  ' >>"$SUMMARY_CSV"
}

FIXTURE="$TMP_DIR/span_quality.txt"
make_fixture "$FIXTURE" "$KEY_COUNT" "$VALUE_LEN"
N_BYTES="$(wc -c <"$FIXTURE")"
EXPECTED_QUERY_COUNT=$((KEY_COUNT * VALUE_LEN))

printf 'scenario,key_count,value_len,keep_prob,aux_noise,K_route,score,preset,expected_query_count,route_hint_query_count,route_candidate_query_count,recall,top1,rank,collision,qacc,span_group_count,span_mean_query_count,span_exact,span_selected_key_consistency,span_selected_correct_key,span_all_recall,span_all_top1,span_offset_recall,span_offset_top1,route_decode,route_unique,route_signature_collision,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

run_case clean-route-code-span 1.0 0.0 4 insertion none
run_case weak-k4 0.25 0.75 4 insertion none
run_case weak-k16 0.25 0.75 16 insertion none
run_case weak-quality 0.25 0.75 16 insertion base-default
run_case weak-keyshape 0.25 0.75 16 key-shape none

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "rows,clean_qacc,weak_k4_qacc,weak_k16_qacc,weak_quality_qacc,weak_keyshape_qacc,clean_span_exact,weak_k4_span_exact,weak_k16_span_exact,weak_quality_span_exact,weak_keyshape_span_exact,clean_all_recall,weak_k4_all_recall,weak_k16_all_recall,weak_quality_all_recall,weak_keyshape_all_recall,clean_all_top1,weak_k4_all_top1,weak_k16_all_top1,weak_quality_all_top1,weak_keyshape_all_top1,quality_span_exact_delta,keyshape_span_exact_delta,routing_trigger_rate_mean,active_jump_rate_mean"
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    qacc[scenario] = $idx["qacc"] + 0
    span_exact[scenario] = $idx["span_exact"] + 0
    all_recall[scenario] = $idx["span_all_recall"] + 0
    all_top1[scenario] = $idx["span_all_top1"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 5) {
      printf "invalid span quality rows\n" > "/dev/stderr"
      exit 4
    }
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      qacc["clean-route-code-span"],
      qacc["weak-k4"],
      qacc["weak-k16"],
      qacc["weak-quality"],
      qacc["weak-keyshape"],
      span_exact["clean-route-code-span"],
      span_exact["weak-k4"],
      span_exact["weak-k16"],
      span_exact["weak-quality"],
      span_exact["weak-keyshape"],
      all_recall["clean-route-code-span"],
      all_recall["weak-k4"],
      all_recall["weak-k16"],
      all_recall["weak-quality"],
      all_recall["weak-keyshape"],
      all_top1["clean-route-code-span"],
      all_top1["weak-k4"],
      all_top1["weak-k16"],
      all_top1["weak-quality"],
      all_top1["weak-keyshape"],
      span_exact["weak-quality"] - span_exact["weak-k16"],
      span_exact["weak-keyshape"] - span_exact["weak-k16"],
      routing / rows,
      jump / rows
  }
' "$SUMMARY_CSV" >"$AGG_CSV"

echo "wrote $SUMMARY_CSV"
echo "wrote $AGG_CSV"
