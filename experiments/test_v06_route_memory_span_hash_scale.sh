#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_hash_scale_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_hash_scale_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v06_route_memory_span_hash_scale.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("scenario key_count value_len hash_bits expected_query_count kv_record_count kv_query_count kv_query_hit_rate route_hint_query_count route_hint_applied_rate route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_bucket_load_mean route_bucket_collision_rate read_distance qacc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span-hash-scale summary column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    if (metric("key_count") != 2 ||
        metric("value_len") != 5 ||
        metric("hash_bits") != 16) {
      die("span-hash-scale smoke should use key_count=2 value_len=5 hash_bits=16", 3)
    }
    if (metric("kv_record_count") != 2 ||
        metric("kv_query_count") != 10 ||
        metric("route_hint_query_count") != 10 ||
        metric("route_candidate_query_count") != 10 ||
        metric("expected_query_count") != 10) {
      die("span-hash-scale smoke should expose one candidate query per offset", 4)
    }
    if (metric("kv_query_hit_rate") < 0.999999 ||
        metric("route_hint_applied_rate") < 0.999999 ||
        metric("route_candidate_recall_rate") < 0.999999 ||
        metric("route_candidate_top1_rate") < 0.999999) {
      die("span-hash-scale smoke should have exact candidate recall/top1", 5)
    }
    if (metric("route_bucket_load_mean") <= 0 ||
        metric("read_distance") <= 0 ||
        metric("qacc") < 0.80) {
      die("span-hash-scale smoke should populate bucket/read diagnostics and solve most query bytes", 6)
    }
    if (metric("route_bucket_collision_rate") != 0 ||
        metric("routing_trigger_rate") != 0 ||
        metric("active_jump_rate") != 0) {
      die("span-hash-scale smoke should stay collision-free and non-topological", 7)
    }
  }
  END {
    if (rows != 1) {
      die("span-hash-scale smoke expected one summary row", 8)
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
    required_count = split("rows qacc_mean query_count_mean expected_match_rate hit_rate_mean applied_rate_mean recall_mean top1_mean bucket_load_mean collision_rate_mean read_distance_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span-hash-scale aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 1 ||
        metric("query_count_mean") != 10 ||
        metric("expected_match_rate") < 0.999999 ||
        metric("hit_rate_mean") < 0.999999 ||
        metric("applied_rate_mean") < 0.999999 ||
        metric("recall_mean") < 0.999999 ||
        metric("top1_mean") < 0.999999 ||
        metric("qacc_mean") < 0.80) {
      die("span-hash-scale aggregate smoke mismatch", 21)
    }
    if (metric("collision_rate_mean") != 0 ||
        metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0 ||
        metric("bucket_load_mean") <= 0 ||
        metric("read_distance_mean") <= 0) {
      die("span-hash-scale aggregate should stay non-topological and populated", 22)
    }
  }
  END {
    if (rows != 1) {
      die("span-hash-scale aggregate expected one row", 23)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span hash scale smoke passed"
