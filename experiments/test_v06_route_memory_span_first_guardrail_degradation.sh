#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_first_guardrail_degradation.sh" --smoke

DECISION_CSV="$RESULTS_DIR/v06_route_memory_span_first_guardrail_degradation_smoke_decisions.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_first_guardrail_degradation_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation key_count seed guardrail selected_scenario accepted_span_policy qacc_policy_scenario span_policy_scenario qacc_delta_vs_qacc_policy span_exact_delta_vs_qacc_policy", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span guardrail degradation decision column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    degradation = $idx["degradation"]
    guardrail = $idx["guardrail"]
    seen_degradation[degradation] = 1
    seen_guardrail[guardrail] = 1

    if (guardrail == "qacc-default") {
      if (($idx["accepted_span_policy"] + 0) != 0) {
        die("qacc-default should not accept span policy: " degradation, 3)
      }
      if ($idx["selected_scenario"] != $idx["qacc_policy_scenario"]) {
        die("qacc-default should select byte-qacc policy: " degradation, 4)
      }
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) != 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy"] + 0) != 0.0) {
        die("qacc-default should preserve byte-qacc policy metrics: " degradation, 5)
      }
    }

    if (($idx["span_policy_scenario"] != $idx["qacc_policy_scenario"])) {
      split_count++
    }
    if (($idx["accepted_span_policy"] + 0) != 0) {
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) > 0.000001) {
        die("accepted span policy should not improve qacc over byte-qacc policy", 6)
      }
      if (($idx["span_exact_delta_vs_qacc_policy"] + 0) <= 0.0) {
        die("accepted span policy should improve span exact-match", 7)
      }
    }
  }
  END {
    if (rows < 8) {
      die("expected weak and harsher guardrail decision rows", 8)
    }
    if (!("weak" in seen_degradation) || !("harsher" in seen_degradation)) {
      die("expected weak and harsher degradation rows", 9)
    }
    if (!("qacc-default" in seen_guardrail) ||
        !("strict-g0p050-cap0p050" in seen_guardrail) ||
        !("balanced-g0p025-cap0p050" in seen_guardrail) ||
        !("span-first-g0p025-cap0p075" in seen_guardrail)) {
      die("missing one or more guardrail arms", 10)
    }
    if (split_count <= 0) {
      die("expected at least one objective split in smoke", 11)
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
    required_count = split("degradation guardrail groups span_accept_rate selected_hybrid_rate qacc_delta_vs_qacc_policy_mean span_exact_delta_vs_qacc_policy_mean objective_split_rate routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span guardrail degradation aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    degradation = $idx["degradation"]
    guardrail = $idx["guardrail"]
    seen_degradation[degradation] = 1
    seen_guardrail[guardrail] = 1
    if (($idx["groups"] + 0) < 1) {
      die("expected at least one guardrail degradation group", 21)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor route path should remain inactive", 22)
    }
    if (guardrail == "qacc-default") {
      if (($idx["span_accept_rate"] + 0) != 0.0 ||
          ($idx["selected_hybrid_rate"] + 0) != 0.0) {
        die("qacc-default aggregate should not select span policy: " degradation, 23)
      }
      if (($idx["qacc_delta_vs_qacc_policy_mean"] + 0) != 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy_mean"] + 0) != 0.0) {
        die("qacc-default aggregate should preserve byte-qacc policy metrics: " degradation, 24)
      }
    }
    if (($idx["objective_split_rate"] + 0) > 0.0) {
      split_aggregate_rows++
    }
    if (($idx["span_accept_rate"] + 0) > 0.0) {
      if (($idx["qacc_delta_vs_qacc_policy_mean"] + 0) > 0.000001) {
        die("accepting aggregate should not improve qacc over byte-qacc policy", 25)
      }
      if (($idx["span_exact_delta_vs_qacc_policy_mean"] + 0) <= 0.0) {
        die("accepting aggregate should improve span exact-match", 26)
      }
    }
  }
  END {
    if (rows < 8) {
      die("expected weak and harsher aggregate guardrail rows", 27)
    }
    if (!("weak" in seen_degradation) || !("harsher" in seen_degradation)) {
      die("expected weak and harsher aggregate degradation rows", 28)
    }
    if (!("qacc-default" in seen_guardrail) ||
        !("strict-g0p050-cap0p050" in seen_guardrail) ||
        !("balanced-g0p025-cap0p050" in seen_guardrail) ||
        !("span-first-g0p025-cap0p075" in seen_guardrail)) {
      die("missing one or more aggregate guardrail arms", 29)
    }
    if (split_aggregate_rows <= 0) {
      die("expected at least one aggregate objective split row", 30)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span-first guardrail degradation smoke passed"
