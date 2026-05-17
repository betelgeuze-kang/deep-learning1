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

PREFIX="v06_route_memory_span_exact_scale"
KEY_COUNTS=(2 4)
VALUE_LENS=(3 5)
EPOCHS=6
CYCLES_PER_EPOCH=20
PROPOSAL_COUNT=30

if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_span_exact_scale_smoke"
  KEY_COUNTS=(2)
  VALUE_LENS=(5)
elif [[ "$MODE" == "full" ]]; then
  KEY_COUNTS=(2 4 8)
  VALUE_LENS=(3 5 8)
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
      required_count = split("kv_record_count kv_query_count kv_query_hit_rate route_hint_query_count route_hint_applied_rate route_hint_value_read_distance_mean fixture_query_byte_acc routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          printf "missing span-scale metric column: %s\n", required[i] > "/dev/stderr"
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
        row[idx["kv_record_count"]] + 0,
        row[idx["kv_query_count"]] + 0,
        row[idx["kv_query_hit_rate"]] + 0,
        row[idx["route_hint_query_count"]] + 0,
        row[idx["route_hint_applied_rate"]] + 0,
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
  local span_hints="$4"

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
    --route-mode hint-kv-exact \
    --route-span-hints "$span_hints" \
    --lambda-route 5.0 \
    --csv "$csv_path" >/dev/null
}

printf 'scenario,key_count,value_len,arm,span_hints,expected_query_count,kv_record_count,kv_query_count,kv_query_hit_rate,route_hint_query_count,route_hint_applied_rate,read_distance,qacc,routing_trigger_rate,active_jump_rate\n' >"$SUMMARY_CSV"

for key_count in "${KEY_COUNTS[@]}"; do
  for value_len in "${VALUE_LENS[@]}"; do
    fixture="$TMP_DIR/span_scale_k${key_count}_l${value_len}.txt"
    make_fixture "$fixture" "$key_count" "$value_len"
    n_bytes="$(wc -c <"$fixture")"

    for arm in first-byte span; do
      if [[ "$arm" == "first-byte" ]]; then
        span_hints=0
        expected=$key_count
      else
        span_hints=1
        expected=$((key_count * value_len))
      fi
      scenario="${arm}-k${key_count}-l${value_len}"
      csv_path="$RESULTS_DIR/${PREFIX}_${scenario}.csv"
      echo "v06-span-exact-scale: ${scenario}" >&2
      run_case "$csv_path" "$fixture" "$n_bytes" "$span_hints"
      metrics="$(metric_line "$csv_path")"
      awk -F, -v scenario="$scenario" -v key_count="$key_count" \
        -v value_len="$value_len" -v arm="$arm" -v span_hints="$span_hints" \
        -v expected="$expected" -v metrics="$metrics" '
        BEGIN {
          split(metrics, m, ",")
          printf "%s,%d,%d,%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
            scenario, key_count, value_len, arm, span_hints, expected,
            m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
        }
      ' >>"$SUMMARY_CSV"
    done
  done
done

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print "rows,first_byte_rows,span_rows,first_byte_qacc_mean,span_qacc_mean,qacc_delta_mean,first_byte_query_count_mean,span_query_count_mean,span_expected_match_rate,span_hit_rate_mean,span_applied_rate_mean,read_distance_mean,routing_trigger_rate_mean,active_jump_rate_mean"
    next
  }
  {
    rows++
    read_distance += $idx["read_distance"] + 0
    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
    if ($idx["arm"] == "first-byte") {
      first_rows++
      first_qacc += $idx["qacc"] + 0
      first_queries += $idx["route_hint_query_count"] + 0
    } else if ($idx["arm"] == "span") {
      span_rows++
      span_qacc += $idx["qacc"] + 0
      span_queries += $idx["route_hint_query_count"] + 0
      span_hit += $idx["kv_query_hit_rate"] + 0
      span_applied += $idx["route_hint_applied_rate"] + 0
      if (($idx["route_hint_query_count"] + 0) == ($idx["expected_query_count"] + 0)) {
        span_expected_matches++
      }
    }
  }
  END {
    if (rows < 1 || first_rows != span_rows || span_rows < 1) {
      printf "invalid span exact scale rows\n" > "/dev/stderr"
      exit 4
    }
    printf "%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      rows, first_rows, span_rows,
      first_qacc / first_rows,
      span_qacc / span_rows,
      (span_qacc / span_rows) - (first_qacc / first_rows),
      first_queries / first_rows,
      span_queries / span_rows,
      span_expected_matches / span_rows,
      span_hit / span_rows,
      span_applied / span_rows,
      read_distance / rows,
      routing / rows,
      jump / rows
  }
' "$SUMMARY_CSV" >"$AGG_CSV"

echo "wrote $SUMMARY_CSV"
echo "wrote $AGG_CSV"
