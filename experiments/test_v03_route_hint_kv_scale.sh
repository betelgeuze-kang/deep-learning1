#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v03_route_hint_kv_scale.sh" --smoke >/tmp/v03_kv_scale_smoke.log

DISTANCE_CSV="$RESULTS_DIR/v03_route_hint_kv_scale_smoke_distance_d64.csv"
KEYS_CSV="$RESULTS_DIR/v03_route_hint_kv_scale_smoke_keys_k4.csv"
DUP_CSV="$RESULTS_DIR/v03_route_hint_kv_scale_smoke_duplicate_latest.csv"
MISSING_CSV="$RESULTS_DIR/v03_route_hint_kv_scale_smoke_missing_key.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    split("kv_query_hit_rate kv_duplicate_key_rate kv_missing_key_rate route_hint_value_read_distance_mean fixture_query_byte_acc", required, " ")
    for (i = 1; i <= length(required); i++) {
      if (!(required[i] in idx)) {
        printf "missing column: %s\n", required[i] > "/dev/stderr"
        exit 2
      }
    }
    next
  }
  { last = $0 }
  END {
    split(last, row, FS)
    if (row[idx["kv_query_hit_rate"]] + 0 < 0.99) {
      print "distance smoke expected kv hit rate near one" > "/dev/stderr"
      exit 3
    }
    if (row[idx["route_hint_value_read_distance_mean"]] + 0 <= 0) {
      print "distance smoke expected positive read distance" > "/dev/stderr"
      exit 4
    }
  }
' "$DISTANCE_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    next
  }
  { last = $0 }
  END {
    split(last, row, FS)
    if (row[idx["kv_query_hit_rate"]] + 0 < 0.99) {
      print "keys smoke expected kv hit rate near one" > "/dev/stderr"
      exit 5
    }
    if (row[idx["kv_query_count"]] + 0 != 4) {
      printf "keys smoke expected 4 queries, got %s\n", row[idx["kv_query_count"]] > "/dev/stderr"
      exit 6
    }
  }
' "$KEYS_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    next
  }
  { last = $0 }
  END {
    split(last, row, FS)
    if (row[idx["kv_duplicate_key_rate"]] + 0 <= 0) {
      print "duplicate smoke expected duplicate key rate > 0" > "/dev/stderr"
      exit 7
    }
    if (row[idx["fixture_query_byte_acc"]] + 0 < 0.99) {
      print "duplicate smoke expected latest-record value to solve query" > "/dev/stderr"
      exit 8
    }
  }
' "$DUP_CSV"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      idx[$i] = i
    }
    next
  }
  { last = $0 }
  END {
    split(last, row, FS)
    if (row[idx["kv_missing_key_rate"]] + 0 <= 0) {
      print "missing smoke expected missing key rate > 0" > "/dev/stderr"
      exit 9
    }
    if (row[idx["route_hint_applied_rate"]] + 0 != 0) {
      print "missing smoke expected no hint to be applied" > "/dev/stderr"
      exit 10
    }
  }
' "$MISSING_CSV"

echo "route hint kv scale smoke passed"
