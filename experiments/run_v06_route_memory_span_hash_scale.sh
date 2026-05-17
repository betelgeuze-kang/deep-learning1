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

PREFIX="v06_route_memory_span_hash_scale"
KEY_COUNTS=(2 4)
VALUE_LENS=(3 5)
HASH_BITS=(16 6)
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_hash_scale_smoke"
  KEY_COUNTS=(2)
  VALUE_LENS=(5)
  HASH_BITS=(16)
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(2 4 8)
  VALUE_LENS=(3 5 8)
  HASH_BITS=(16 8 4)
  EPOCHS=8
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
AGG_CSV="$RESULTS_DIR/${PREFIX}_aggregate.csv"

value_for_index() {
  local index="$1"
  local len="$2"
  local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local out=""
  for ((j = 0; j < len; j++)); do
    local pos=$(((index * 7 + j) % 26))
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
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i" "$value_len")"
    printf '@%d=%s;\n' "$key" "$value" >>"$path"
  done
  awk 'BEGIN { for (i = 0; i < 96; i++) printf "."; printf "\n" }' >>"$path"
  for ((i = 0; i < key_count; i++)); do
    local key=$((37000 + i))
    local value
    value="$(value_for_index "$i" "$value_len")"
    printf '?%d=%s.\n' "$key" "$value" >>"$path"
  done
}

metric_line() {
  local csv_path="$1"
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("kv_record_count kv_query_count kv_query_hit_rate route_hint_query_count route_hint_applied_rate route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean route_bucket_load_mean route_bucket_load_max route_bucket_collision_rate route_hint_value_read_distance_mean fixture_query_byte_acc routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span-hash-scale metric column: %s\n", required[i] > "/dev/stderr"
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
      printf "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
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
        row[idx["route_hint_value_read_distance_mean"]] + 0,
        row[idx["fixture_query_byte_acc"]] + 0,
        row[idx["routing_trigger_rate"]] + 0,
        row[idx["active_jump_rate"]] + 0
    }
  ' "$csv_path"
}

run_case() {
  local csv_path="$1"
  local fixture="$2"
  local n_bytes="$3"
  local hash_bits="$4"

  "$BUILD_DIR/dmv02" \
    --input "$fixture" \
    --N "$n_bytes" \
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
    --K-route 4 \
    --lambda-route 5.0 \
    --csv "$csv_path" >/dev/null
}

printf 'scenario,key_count,value_len,hash_bits,expected_query_count,kv_record_count,kv_query_count,kv_query_hit_rate,route_hint_query_count,route_hint_applied_rate,route_candidate_query_count,route_candidate_recall_rate,route_candidate_top1_rate,route_candidate_rank_mean,route_bucket_load_mean,route_bucket_load_max,route_bucket_collision_rate,read_distance,qacc,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  for value_len in "${VALUE_LENS[@]}"; do
    fixture="$TMP_DIR/span_hash_scale_k${key_count}_l${value_len}.txt"
    make_fixture "$fixture" "$key_count" "$value_len"
    n_bytes="$(wc -c <"$fixture")"
    expected=$((key_count * value_len))

    for hash_bits in "${HASH_BITS[@]}"; do
      scenario="span-hash-b${hash_bits}-k${key_count}-l${value_len}"
      csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
      echo "v06-span-hash-scale: ${scenario}" >&2
      run_case "$csv_path" "$fixture" "$n_bytes" "$hash_bits"
      metrics="$(metric_line "$csv_path")"
      awk -F, -v scenario="$scenario" -v key_count="$key_count" \
        -v value_len="$value_len" -v hash_bits="$hash_bits" \
        -v expected="$expected" -v metrics="$metrics" '
        BEGIN {
          split(metrics, m, ",")
          printf "%s,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
            scenario, key_count, value_len, hash_bits, expected,
            m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9],
            m[10], m[11], m[12], m[13], m[14], m[15], m[16]
        }
      ' >>"$SUMMARY_CSV"
    done
  done
done

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "rows,qacc_mean,query_count_mean,expected_match_rate,hit_rate_mean,applied_rate_mean,recall_mean,top1_mean,rank_mean,bucket_load_mean,bucket_load_max_mean,collision_rate_mean,read_distance_mean,routing_trigger_rate_mean,active_jump_rate_mean"
    next
  }
  {
    rows++
    qacc += $idx["qacc"] + 0
    query_count += $idx["route_hint_query_count"] + 0
    if (($idx["route_hint_query_count"] + 0) == ($idx["expected_query_count"] + 0)) {
      expected_matches++
    }
    hit += $idx["kv_query_hit_rate"] + 0
    applied += $idx["route_hint_applied_rate"] + 0
    recall += $idx["route_candidate_recall_rate"] + 0
    top1 += $idx["route_candidate_top1_rate"] + 0
    rank += $idx["route_candidate_rank_mean"] + 0
    bucket_load += $idx["route_bucket_load_mean"] + 0
    bucket_max += $idx["route_bucket_load_max"] + 0
    collision += $idx["route_bucket_collision_rate"] + 0
    read_distance += $idx["read_distance"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 1) {
      printf "invalid span hash scale rows\n" > "/dev/stderr"
      exit 4
    }
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows,
      qacc / rows,
      query_count / rows,
      expected_matches / rows,
      hit / rows,
      applied / rows,
      recall / rows,
      top1 / rows,
      rank / rows,
      bucket_load / rows,
      bucket_max / rows,
      collision / rows,
      read_distance / rows,
      routing / rows,
      jump / rows
  }
' "$SUMMARY_CSV" >"$AGG_CSV"

echo "wrote $SUMMARY_CSV"
echo "wrote $AGG_CSV"
