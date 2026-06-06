#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_ambiguity_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_ambiguity_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v06_route_memory_span_ambiguity.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("scenario key_count value_len hash_bits K_route agg score preset expected_query_count kv_record_count kv_query_count route_hint_query_count route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_candidate_rank_mean route_bucket_load_mean route_bucket_load_max route_bucket_collision_rate vote_candidate_count correct_value_vote_share vote_entropy unique_values qacc routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span-ambiguity summary column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    seen[scenario] = 1
    if (metric("key_count") != 32 ||
        metric("value_len") != 5 ||
        metric("expected_query_count") != 160 ||
        metric("kv_record_count") != 32 ||
        metric("kv_query_count") != 160 ||
        metric("route_hint_query_count") != 160 ||
        metric("route_candidate_query_count") != 160) {
      die("span-ambiguity smoke should expose all span offsets", 3)
    }
    if (metric("routing_trigger_rate") != 0 ||
        metric("active_jump_rate") != 0) {
      die("span-ambiguity must not activate jump-neighbor routing", 4)
    }
    collision[scenario] = metric("route_bucket_collision_rate")
    top1[scenario] = metric("route_candidate_top1_rate")
    recall[scenario] = metric("route_candidate_recall_rate")
    qacc[scenario] = metric("qacc")
    bucket_load[scenario] = metric("route_bucket_load_mean")
  }
  END {
    required_rows = split("high-bits-control low-bits-k4 low-bits-k16 low-bits-keyshape low-bits-quality", names, " ")
    if (rows != required_rows) {
      die("expected five span-ambiguity rows, found " rows, 5)
    }
    for (i = 1; i <= required_rows; i++) {
      if (!seen[names[i]]) {
        die("missing span-ambiguity row: " names[i], 6)
      }
    }
    if (collision["high-bits-control"] != 0) {
      die("high-bits control should remain collision-free", 7)
    }
    if (collision["low-bits-k4"] <= collision["high-bits-control"] ||
        bucket_load["low-bits-k4"] <= bucket_load["high-bits-control"]) {
      die("low hash bits should create span candidate ambiguity", 8)
    }
    if (top1["low-bits-k4"] >= top1["high-bits-control"] &&
        recall["low-bits-k4"] >= recall["high-bits-control"]) {
      die("low-bits-k4 should expose a recall or top1 degradation", 9)
    }
    if (recall["low-bits-k16"] < recall["low-bits-k4"]) {
      die("larger K_route should not reduce candidate recall in ambiguity smoke", 10)
    }
    if (top1["low-bits-keyshape"] < top1["low-bits-k16"]) {
      die("key-shape scorer should not reduce top1 in ambiguity smoke", 11)
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
    required_count = split("rows high_qacc low_k4_qacc low_k16_qacc keyshape_qacc quality_qacc high_collision low_collision high_top1 low_k4_top1 low_k16_top1 keyshape_top1 quality_top1 high_recall low_k4_recall low_k16_recall keyshape_recall quality_recall keyshape_top1_delta quality_qacc_delta routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span-ambiguity aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 5) {
      die("aggregate should summarize five span-ambiguity rows", 21)
    }
    if (metric("low_collision") <= metric("high_collision")) {
      die("aggregate collision signal missing", 22)
    }
    if (metric("low_k4_top1") >= metric("high_top1") &&
        metric("low_k4_recall") >= metric("high_recall")) {
      die("aggregate should show ambiguity degradation", 23)
    }
    if (metric("keyshape_top1_delta") < 0) {
      die("key-shape should not reduce top1 in aggregate", 24)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("aggregate should keep jump-neighbor routing inactive", 25)
    }
  }
  END {
    if (rows != 1) {
      die("expected one span-ambiguity aggregate row", 26)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span ambiguity smoke passed"
