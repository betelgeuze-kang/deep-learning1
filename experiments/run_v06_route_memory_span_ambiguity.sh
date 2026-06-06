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

PREFIX="v06_route_memory_span_ambiguity"
KEY_COUNT=32
VALUE_LEN=5
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_ambiguity_smoke"
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
    local key=$((61000 + i * 17))
    printf '@%d=%s;\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 128; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((61000 + i * 17))
    printf '?%d=%s.\n' "$key" "$(value_for_index "$i" "$value_len")" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("kv_record_count kv_query_count kv_query_hit_rate route_hint_query_count route_hint_applied_rate route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean route_bucket_load_mean route_bucket_load_max route_bucket_collision_rate route_hint_vote_candidate_count_mean route_hint_vote_margin_mean route_hint_correct_value_vote_share_mean route_hint_vote_entropy_mean route_hint_unique_values_mean route_quality_candidate_weight_factor_gap route_quality_candidate_weight_factor_max route_hint_value_read_distance_mean fixture_query_byte_acc routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span-ambiguity metric column: %s\n", required[i] > "/dev/stderr"
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
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        row[idx["kv_record_count"]] + 0,
        row[idx["kv_query_count"]] + 0,
        row[idx["kv_query_hit_rate"]] + 0,
        row[idx["route_hint_query_count"]] + 0,
        row[idx["route_hint_applied_rate"]] + 0,
        row[idx["route_candidate_query_count"]] + 0,
        row[idx["route_candidate_recall_rate"]] + 0,
        row[idx["route_candidate_top1_rate"]] + 0,
        row[idx["route_candidate_rank_mean"]] + 0,
        row[idx["route_bucket_load_mean"]] + 0,
        row[idx["route_bucket_load_max"]] + 0,
        row[idx["route_bucket_collision_rate"]] + 0,
        row[idx["route_hint_vote_candidate_count_mean"]] + 0,
        row[idx["route_hint_vote_margin_mean"]] + 0,
        row[idx["route_hint_correct_value_vote_share_mean"]] + 0,
        row[idx["route_hint_vote_entropy_mean"]] + 0,
        row[idx["route_hint_unique_values_mean"]] + 0,
        row[idx["route_quality_candidate_weight_factor_gap"]] + 0,
        row[idx["route_quality_candidate_weight_factor_max"]] + 0,
        row[idx["route_hint_value_read_distance_mean"]] + 0,
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local label="$1"
  local hash_bits="$2"
  local k_route="$3"
  local agg="$4"
  local score="$5"
  local preset="$6"
  local csv_path="$RESULTS_DIR/${PREFIX}_${label}.csv"

  local preset_args=()
  if [[ "$preset" != "none" ]]; then
    preset_args=(--route-quality-candidate-weight-preset "$preset")
  fi

  echo "v06-span-ambiguity: ${label}" >&2
  "$BUILD_DIR/dmv02" \
    --input "$FIXTURE" \
    --N "$N_BYTES" \
    --epochs "$EPOCHS" \
    --cycles-per-epoch "$CYCLES_PER_EPOCH" \
    --seed 1 \
    --lambda-v 0 \
    --lambda-b 0 \
    --eta-b 0 \
    --eta-h 0 \
    --proposal-count "$PROPOSAL_COUNT" \
    --route-mode hint-kv-hash \
    --route-span-hints 1 \
    --route-hash-bits "$hash_bits" \
    --K-route "$k_route" \
    --route-hint-agg "$agg" \
    --route-candidate-score "$score" \
    --lambda-route 5.0 \
    "${preset_args[@]}" \
    --csv "$csv_path" >/dev/null

  local metrics
  metrics="$(metric_line "$csv_path")"
  awk -F, -v label="$label" -v key_count="$KEY_COUNT" \
    -v value_len="$VALUE_LEN" -v hash_bits="$hash_bits" \
    -v k_route="$k_route" -v agg="$agg" -v score="$score" \
    -v preset="$preset" -v expected="$EXPECTED_QUERY_COUNT" \
    -v metrics="$metrics" '
    BEGIN {
      split(metrics, m, ",")
      printf "%s,%d,%d,%d,%d,%s,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
        label, key_count, value_len, hash_bits, k_route, agg, score, preset,
        expected, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9],
        m[10], m[11], m[12], m[13], m[14], m[15], m[16], m[17], m[18],
        m[19], m[20], m[21], m[22], m[23]
    }
  ' >>"$SUMMARY_CSV"
}

FIXTURE="$TMP_DIR/span_ambiguity.txt"
make_fixture "$FIXTURE" "$KEY_COUNT" "$VALUE_LEN"
N_BYTES="$(wc -c <"$FIXTURE")"
EXPECTED_QUERY_COUNT=$((KEY_COUNT * VALUE_LEN))

printf 'scenario,key_count,value_len,hash_bits,K_route,agg,score,preset,expected_query_count,kv_record_count,kv_query_count,kv_query_hit_rate,route_hint_query_count,route_hint_applied_rate,route_candidate_query_count,route_candidate_recall_rate,route_candidate_top1_rate,route_candidate_rank_mean,route_bucket_load_mean,route_bucket_load_max,route_bucket_collision_rate,vote_candidate_count,vote_margin,correct_value_vote_share,vote_entropy,unique_values,factor_gap,factor_max,read_distance,qacc,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

run_case high-bits-control 16 4 weighted-vote insertion none
run_case low-bits-k4 2 4 weighted-vote insertion none
run_case low-bits-k16 2 16 weighted-vote insertion none
run_case low-bits-keyshape 2 16 weighted-vote key-shape none
run_case low-bits-quality 2 16 weighted-vote insertion base-default

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "rows,high_qacc,low_k4_qacc,low_k16_qacc,keyshape_qacc,quality_qacc,high_collision,low_collision,high_top1,low_k4_top1,low_k16_top1,keyshape_top1,quality_top1,high_recall,low_k4_recall,low_k16_recall,keyshape_recall,quality_recall,keyshape_top1_delta,quality_qacc_delta,routing_trigger_rate_mean,active_jump_rate_mean"
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    qacc[scenario] = $idx["qacc"] + 0
    collision[scenario] = $idx["route_bucket_collision_rate"] + 0
    top1[scenario] = $idx["route_candidate_top1_rate"] + 0
    recall[scenario] = $idx["route_candidate_recall_rate"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 5) {
      printf "invalid span ambiguity rows\n" > "/dev/stderr"
      exit 4
    }
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      qacc["high-bits-control"],
      qacc["low-bits-k4"],
      qacc["low-bits-k16"],
      qacc["low-bits-keyshape"],
      qacc["low-bits-quality"],
      collision["high-bits-control"],
      collision["low-bits-k4"],
      top1["high-bits-control"],
      top1["low-bits-k4"],
      top1["low-bits-k16"],
      top1["low-bits-keyshape"],
      top1["low-bits-quality"],
      recall["high-bits-control"],
      recall["low-bits-k4"],
      recall["low-bits-k16"],
      recall["low-bits-keyshape"],
      recall["low-bits-quality"],
      top1["low-bits-keyshape"] - top1["low-bits-k16"],
      qacc["low-bits-quality"] - qacc["low-bits-k16"],
      routing / rows,
      jump / rows
  }
' "$SUMMARY_CSV" >"$AGG_CSV"

echo "wrote $SUMMARY_CSV"
echo "wrote $AGG_CSV"
