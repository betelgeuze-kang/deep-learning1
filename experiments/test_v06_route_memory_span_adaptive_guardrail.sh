#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_adaptive_guardrail.sh" --smoke

DECISION_CSV="$RESULTS_DIR/v06_route_memory_span_adaptive_guardrail_smoke_decisions.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_adaptive_guardrail_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation policy loss_weight selected_scenario accepted_span_policy qacc_policy_scenario span_policy_scenario qacc_delta_vs_qacc_policy span_exact_delta_vs_qacc_policy utility", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing adaptive guardrail decision column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    policy = $idx["policy"]
    seen_policy[policy] = 1
    if (policy == "qacc-default") {
      if (($idx["accepted_span_policy"] + 0) != 0) {
        die("qacc-default should not accept span policy", 3)
      }
      if ($idx["selected_scenario"] != $idx["qacc_policy_scenario"]) {
        die("qacc-default should select byte-qacc policy", 4)
      }
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) != 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy"] + 0) != 0.0) {
        die("qacc-default should preserve byte-qacc metrics", 5)
      }
    }
    if (policy == "utility-w0p50" && ($idx["accepted_span_policy"] + 0) != 0) {
      utility_w0p50_accept++
      if (($idx["utility"] + 0) <= 0.0) {
        die("utility-w0p50 accepted with nonpositive utility", 6)
      }
    }
    if (policy == "utility-w0p75" && ($idx["accepted_span_policy"] + 0) != 0) {
      utility_w0p75_accept++
    }
    if (($idx["accepted_span_policy"] + 0) != 0) {
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) >= 0.0) {
        die("accepted span policy should trade off qacc", 7)
      }
      if (($idx["span_exact_delta_vs_qacc_policy"] + 0) <= 0.0) {
        die("accepted span policy should improve span exact-match", 8)
      }
    }
  }
  END {
    if (rows < 8) {
      die("expected adaptive guardrail decision rows", 9)
    }
    if (!("qacc-default" in seen_policy) ||
        !("utility-w0p50" in seen_policy) ||
        !("utility-w0p75" in seen_policy) ||
        !("utility-w1p00" in seen_policy)) {
      die("missing one or more adaptive policies", 10)
    }
    if (utility_w0p50_accept <= 0) {
      die("expected utility-w0p50 to accept a smoke split", 11)
    }
    if (utility_w0p75_accept != 0) {
      die("expected utility-w0p75 to reject high-loss smoke split", 12)
    }
  }
' "$DECISION_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation policy groups objective_split_rate span_accept_rate qacc_delta_vs_qacc_policy_mean span_exact_delta_vs_qacc_policy_mean utility_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing adaptive guardrail aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    policy = $idx["policy"]
    seen_policy[policy] = 1
    if (($idx["groups"] + 0) < 1) {
      die("expected at least one adaptive guardrail group", 21)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor route path should remain inactive", 22)
    }
    if (policy == "qacc-default") {
      if (($idx["span_accept_rate"] + 0) != 0.0 ||
          ($idx["qacc_delta_vs_qacc_policy_mean"] + 0) != 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy_mean"] + 0) != 0.0) {
        die("qacc-default aggregate should preserve byte-qacc policy", 23)
      }
    }
    if (policy == "utility-w0p50" && ($idx["span_accept_rate"] + 0) > 0.0) {
      utility_w0p50_accepting_rows++
      if (($idx["qacc_delta_vs_qacc_policy_mean"] + 0) >= 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy_mean"] + 0) <= 0.0) {
        die("utility-w0p50 acceptance should trade qacc for span exact-match", 24)
      }
    }
    if (policy == "utility-w0p75" && ($idx["span_accept_rate"] + 0) > 0.0) {
      utility_w0p75_accepting_rows++
    }
  }
  END {
    if (rows < 8) {
      die("expected adaptive guardrail aggregate rows", 25)
    }
    if (!("qacc-default" in seen_policy) ||
        !("utility-w0p50" in seen_policy) ||
        !("utility-w0p75" in seen_policy) ||
        !("utility-w1p00" in seen_policy)) {
      die("missing one or more aggregate adaptive policies", 26)
    }
    if (utility_w0p50_accepting_rows <= 0) {
      die("expected utility-w0p50 aggregate acceptance", 27)
    }
    if (utility_w0p75_accepting_rows != 0) {
      die("expected utility-w0p75 aggregate to reject smoke splits", 28)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span adaptive guardrail smoke passed"
