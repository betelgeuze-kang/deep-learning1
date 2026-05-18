#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_span_learned_source_smoke_summary.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_learned_source_smoke_aggregate.csv"

"$ROOT_DIR/experiments/run_v06_route_memory_span_learned_source.sh" --smoke

awk -F, '
  function die(message, code) {
    printf "%s\n", message > "/dev/stderr"
    exit code
  }
  function metric(name) { return $idx[name] + 0 }
  NR == 1 {
    required_count = split("scenario key_count value_len keep_prob aux_noise K_route score preset expected_query_count kv_record_count kv_query_count route_hint_query_count route_candidate_query_count route_candidate_recall_rate route_candidate_top1_rate route_bucket_load_mean route_collision qacc span_group_count span_mean_query_count span_exact_match_rate span_selected_key_consistency_rate span_selected_correct_key_rate route_decode route_unique raw_overlap routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span learned-source summary column: " required[i], 2)
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
      die("span learned-source smoke should expose all span offsets", 3)
    }
    if (metric("routing_trigger_rate") != 0 ||
        metric("active_jump_rate") != 0) {
      die("span learned-source must not activate jump-neighbor routing", 4)
    }
    qacc[scenario] = metric("qacc")
    recall[scenario] = metric("route_candidate_recall_rate")
    top1[scenario] = metric("route_candidate_top1_rate")
    span_exact[scenario] = metric("span_exact_match_rate")
    span_consistency[scenario] = metric("span_selected_key_consistency_rate")
    span_correct_key[scenario] = metric("span_selected_correct_key_rate")
    decode[scenario] = metric("route_decode")
    collision[scenario] = metric("route_collision")
    bucket_load[scenario] = metric("route_bucket_load_mean")
  }
  END {
    required_rows = split("clean-route-code-span weak-route-code-k4 weak-route-code-k16 weak-route-code-quality", names, " ")
    if (rows != required_rows) {
      die("expected four span learned-source rows, found " rows, 5)
    }
    for (i = 1; i <= required_rows; i++) {
      if (!seen[names[i]]) {
        die("missing span learned-source row: " names[i], 6)
      }
    }
    if (decode["clean-route-code-span"] < 0.99 ||
        recall["clean-route-code-span"] < 0.99 ||
        top1["clean-route-code-span"] < 0.99 ||
        span_exact["clean-route-code-span"] < 0.90 ||
        span_consistency["clean-route-code-span"] < 0.99 ||
        span_correct_key["clean-route-code-span"] < 0.99 ||
        qacc["clean-route-code-span"] < 0.90) {
      die("clean route-code span source should preserve identity and recall", 7)
    }
    if (decode["weak-route-code-k4"] >= decode["clean-route-code-span"] - 0.50) {
      die("weak route-code source should degrade route-code identity", 8)
    }
    if (collision["weak-route-code-k4"] <= collision["clean-route-code-span"] ||
        bucket_load["weak-route-code-k4"] <= bucket_load["clean-route-code-span"]) {
      die("weak route-code source should increase learned-source collisions", 9)
    }
    if (recall["weak-route-code-k4"] >= recall["clean-route-code-span"] &&
        top1["weak-route-code-k4"] >= top1["clean-route-code-span"]) {
      die("weak route-code source should expose recall or top1 degradation", 10)
    }
    if (recall["weak-route-code-k16"] < recall["weak-route-code-k4"]) {
      die("larger K_route should not reduce weak-source recall", 11)
    }
    if (span_exact["weak-route-code-k4"] >= span_exact["clean-route-code-span"]) {
      die("weak route-code source should reduce span exact-match rate", 12)
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
    required_count = split("rows clean_qacc weak_k4_qacc weak_k16_qacc weak_quality_qacc clean_span_exact weak_k4_span_exact weak_k16_span_exact weak_quality_span_exact clean_span_consistency weak_k4_span_consistency weak_k16_span_consistency weak_quality_span_consistency clean_recall weak_k4_recall weak_k16_recall weak_quality_recall clean_top1 weak_k4_top1 weak_k16_top1 weak_quality_top1 clean_decode weak_decode clean_collision weak_collision k16_recall_delta quality_qacc_delta routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= NF; i++) idx[$i] = i
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span learned-source aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    if (metric("rows") != 4) {
      die("aggregate should summarize four span learned-source rows", 21)
    }
    if (metric("clean_decode") < 0.99 || metric("clean_recall") < 0.99 ||
        metric("clean_span_exact") < 0.90 ||
        metric("clean_span_consistency") < 0.99) {
      die("aggregate clean route-code source should be strong", 22)
    }
    if (metric("weak_decode") >= metric("clean_decode") - 0.50) {
      die("aggregate weak branch should degrade route-code identity", 23)
    }
    if (metric("weak_collision") <= metric("clean_collision")) {
      die("aggregate weak branch should increase collisions", 24)
    }
    if (metric("k16_recall_delta") < 0) {
      die("aggregate K_route expansion should not lower recall", 25)
    }
    if (metric("weak_k4_span_exact") >= metric("clean_span_exact")) {
      die("aggregate weak branch should lower span exact-match", 26)
    }
    if (metric("routing_trigger_rate_mean") != 0 ||
        metric("active_jump_rate_mean") != 0) {
      die("aggregate should keep jump-neighbor routing inactive", 27)
    }
  }
  END {
    if (rows != 1) {
      die("expected one span learned-source aggregate row", 28)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span learned-source smoke passed"
