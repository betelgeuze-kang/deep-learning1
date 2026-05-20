#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_adaptive_guardrail_scale.sh" --smoke

DECISION_CSV="$RESULTS_DIR/v06_route_memory_span_adaptive_guardrail_scale_smoke_decisions.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_adaptive_guardrail_scale_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation key_count seed policy selected_scenario accepted_span_policy sane_accept bad_accept qacc_policy_scenario span_policy_scenario qacc_delta_vs_qacc_policy span_exact_delta_vs_qacc_policy utility", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing adaptive guardrail scale decision column: " required[i], 2)
    }
    next
  }
  {
    rows++
    group = $idx["degradation"] ":" $idx["key_count"] ":" $idx["seed"]
    groups[group] = 1
    policy = $idx["policy"]
    seen_policy[policy] = 1
    if (policy == "qacc-default") {
      if (($idx["accepted_span_policy"] + 0) != 0) die("qacc-default must not accept span policy", 3)
      if ($idx["selected_scenario"] != $idx["qacc_policy_scenario"]) die("qacc-default must select qacc policy", 4)
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) != 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy"] + 0) != 0.0) {
        die("qacc-default must preserve qacc policy metrics", 5)
      }
    }
    if (($idx["accepted_span_policy"] + 0) != 0) {
      accepted++
      if (($idx["utility"] + 0) <= 0.0) die("accepted adaptive policy must have positive utility", 6)
      if (($idx["span_exact_delta_vs_qacc_policy"] + 0) <= 0.0) die("accepted adaptive policy must improve span exact", 7)
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) >= 0.0) die("accepted adaptive policy should trade off qacc", 8)
    }
    if (policy == "utility-w0p75" && ($idx["bad_accept"] + 0) != 0) {
      die("utility-w0p75 should not accept smoke splits with excessive qacc loss", 9)
    }
  }
  END {
    group_count = 0
    for (group in groups) group_count++
    if (rows < 8 || group_count < 2) die("expected multi-degradation adaptive guardrail scale rows", 10)
    if (!("qacc-default" in seen_policy) ||
        !("utility-w0p50" in seen_policy) ||
        !("utility-w0p75" in seen_policy) ||
        !("utility-w1p00" in seen_policy)) {
      die("missing adaptive guardrail scale policies", 11)
    }
    if (accepted <= 0) die("expected at least one span-policy acceptance in scale smoke", 12)
  }
' "$DECISION_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation policy groups objective_split_rate span_accept_rate sane_accept_rate bad_accept_rate qacc_delta_vs_qacc_policy_mean span_exact_delta_vs_qacc_policy_mean top1_recall_gap_mean promotion_candidate routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing adaptive guardrail scale aggregate column: " required[i], 20)
    }
    next
  }
  {
    rows++
    if (($idx["groups"] + 0) < 1) die("aggregate row must have groups", 21)
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive", 22)
    }
    if (($idx["top1_recall_gap_mean"] + 0) < -0.000001) die("top1/recall gap cannot be negative", 23)
    if ($idx["policy"] == "qacc-default") {
      if (($idx["span_accept_rate"] + 0) != 0.0 ||
          ($idx["qacc_delta_vs_qacc_policy_mean"] + 0) != 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy_mean"] + 0) != 0.0) {
        die("qacc-default aggregate must preserve qacc policy", 24)
      }
    }
    if ($idx["degradation"] == "all" && $idx["policy"] == "utility-w0p75") {
      saw_all_w0p75 = 1
      if (($idx["bad_accept_rate"] + 0) != 0.0) die("utility-w0p75 should have no bad scale acceptance", 26)
    }
  }
  END {
    if (rows < 8) die("expected adaptive guardrail scale aggregate rows", 27)
    if (!saw_all_w0p75) die("missing all/utility-w0p75 aggregate row", 28)
  }
' "$AGG_CSV"

echo "v06 route-memory span adaptive guardrail scale smoke passed"
