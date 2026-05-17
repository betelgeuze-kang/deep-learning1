#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_exact_scale_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_exact_scale_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v06_route_memory_span_exact_scale.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("scenario key_count value_len arm span_hints expected_query_count kv_record_count kv_query_count kv_query_hit_rate route_hint_query_count route_hint_applied_rate read_distance qacc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span-scale summary column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    if (metric("key_count") != 2 || metric("value_len") != 5) {
      die("span-scale smoke should use key_count=2 value_len=5", 3)
    }
    if (metric("kv_record_count") != 2) {
      die("span-scale smoke should see two records", 4)
    }
    if (metric("kv_query_hit_rate") < 0.999999 ||
        metric("route_hint_applied_rate") < 0.999999) {
      die("span-scale exact hints should hit and apply", 5)
    }
    if (metric("read_distance") <= 0) {
      die("span-scale read distance should be populated", 6)
    }
    if (metric("routing_trigger_rate") != 0 || metric("active_jump_rate") != 0) {
      die("span-scale must not activate jump-neighbor routing", 7)
    }
    if ($idx["arm"] == "first-byte") {
      first_seen = 1
      if (metric("span_hints") != 0 ||
          metric("route_hint_query_count") != 2 ||
          metric("expected_query_count") != 2) {
        die("first-byte arm should expose one hint per key", 8)
      }
    } else if ($idx["arm"] == "span") {
      span_seen = 1
      if (metric("span_hints") != 1 ||
          metric("route_hint_query_count") != 10 ||
          metric("expected_query_count") != 10 ||
          metric("qacc") < 0.80) {
        die("span arm should expose and solve most value-span offsets", 9)
      }
    }
  }
  END {
    if (rows != 2 || !first_seen || !span_seen) {
      die("span-scale smoke expected first-byte and span rows", 10)
    }
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("rows first_byte_rows span_rows first_byte_qacc_mean span_qacc_mean qacc_delta_mean first_byte_query_count_mean span_query_count_mean span_expected_match_rate span_hit_rate_mean span_applied_rate_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing aggregate span-scale column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 2 ||
        metric("first_byte_rows") != 1 ||
        metric("span_rows") != 1) {
      die("aggregate span-scale row counts mismatch", 21)
    }
    if (metric("first_byte_query_count_mean") != 2 ||
        metric("span_query_count_mean") != 10 ||
        metric("span_expected_match_rate") < 0.999999) {
      die("aggregate span-scale query expansion mismatch", 22)
    }
    if (metric("span_hit_rate_mean") < 0.999999 ||
        metric("span_applied_rate_mean") < 0.999999) {
      die("aggregate span-scale should hit and apply", 23)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("aggregate span-scale should preserve jump-neighbor inactivity", 24)
    }
  }
  END {
    if (rows != 1) {
      die("expected one aggregate span-scale row, found " rows, 25)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span exact scale smoke passed"
