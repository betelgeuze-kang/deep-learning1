#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_quality_diagnostics_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_quality_diagnostics_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v06_route_memory_span_quality_diagnostics.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("scenario expected_query_count route_hint_query_count route_candidate_query_count qacc span_exact span_selected_key_consistency span_selected_correct_key span_all_recall span_all_top1 span_offset_recall span_offset_top1 route_decode route_signature_collision routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span quality summary column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    scenario = $idx["scenario"]
    seen[scenario] = 1
    if (metric("expected_query_count") != 160 ||
        metric("route_hint_query_count") != 160 ||
        metric("route_candidate_query_count") != 160) {
      die("span quality smoke should expose all span offsets", 3)
    }
    if (metric("routing_trigger_rate") != 0 ||
        metric("active_jump_rate") != 0) {
      die("span quality diagnostics must not activate jump-neighbor routing", 4)
    }
    qacc[scenario] = metric("qacc")
    span_exact[scenario] = metric("span_exact")
    all_recall[scenario] = metric("span_all_recall")
    all_top1[scenario] = metric("span_all_top1")
    offset_recall[scenario] = metric("span_offset_recall")
    offset_top1[scenario] = metric("span_offset_top1")
    decode[scenario] = metric("route_decode")
    collision[scenario] = metric("route_signature_collision")
  }
  END {
    required_rows = split("clean-route-code-span weak-k4 weak-k16 weak-quality weak-keyshape", names, " ")
    if (rows != required_rows) {
      die("expected five span quality rows, found " rows, 5)
    }
    for (i = 1; i <= required_rows; i++) {
      if (!seen[names[i]]) {
        die("missing span quality row: " names[i], 6)
      }
    }
    if (decode["clean-route-code-span"] < 0.99 ||
        all_recall["clean-route-code-span"] < 0.99 ||
        all_top1["clean-route-code-span"] < 0.99 ||
        span_exact["clean-route-code-span"] < 0.90) {
      die("clean span source should preserve identity, candidate recall/top1, and exact-match", 7)
    }
    if (decode["weak-k4"] >= decode["clean-route-code-span"] - 0.50 ||
        collision["weak-k4"] <= collision["clean-route-code-span"]) {
      die("weak span source should degrade decode and increase collisions", 8)
    }
    if (all_recall["weak-k16"] < all_recall["weak-k4"] ||
        offset_recall["weak-k16"] < offset_recall["weak-k4"]) {
      die("larger K_route should not reduce span candidate recall", 9)
    }
    if (all_top1["weak-k16"] >= all_top1["clean-route-code-span"] ||
        span_exact["weak-k16"] >= span_exact["clean-route-code-span"]) {
      die("weak K16 should keep recall/top1 and exact-match separated", 10)
    }
    if (all_top1["weak-keyshape"] <= all_top1["weak-k16"] ||
        span_exact["weak-keyshape"] <= span_exact["weak-k16"]) {
      die("symbolic key-shape should expose the span-quality upper bound", 11)
    }
    if (span_exact["weak-quality"] > span_exact["weak-keyshape"]) {
      die("byte-level quality preset should not exceed symbolic key-shape upper bound", 12)
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
    required_count = split("rows clean_qacc weak_k4_qacc weak_k16_qacc weak_quality_qacc weak_keyshape_qacc clean_span_exact weak_k4_span_exact weak_k16_span_exact weak_quality_span_exact weak_keyshape_span_exact clean_all_recall weak_k4_all_recall weak_k16_all_recall weak_quality_all_recall weak_keyshape_all_recall clean_all_top1 weak_k4_all_top1 weak_k16_all_top1 weak_quality_all_top1 weak_keyshape_all_top1 quality_span_exact_delta keyshape_span_exact_delta routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span quality aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 5) {
      die("aggregate should summarize five span quality rows", 21)
    }
    if (metric("weak_k16_all_recall") < metric("weak_k4_all_recall")) {
      die("aggregate K_route expansion should not reduce all-span recall", 22)
    }
    if (metric("weak_k16_all_top1") >= metric("clean_all_top1")) {
      die("aggregate should show recall/top1 separation under weak source", 23)
    }
    if (metric("keyshape_span_exact_delta") <= 0) {
      die("aggregate key-shape upper-bound signal missing", 24)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("aggregate should keep jump-neighbor routing inactive", 25)
    }
  }
  END {
    if (rows != 1) {
      die("expected one span quality aggregate row", 26)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span quality diagnostics smoke passed"
