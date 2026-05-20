#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_span_first_guardrail.sh" --smoke

DECISION_CSV="$RESULTS_DIR/v06_route_memory_span_first_guardrail_smoke_decisions.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_span_first_guardrail_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("guardrail selected_scenario accepted_span_policy qacc_policy_scenario span_policy_scenario qacc_delta_vs_qacc_policy span_exact_delta_vs_qacc_policy", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span-first guardrail decision column: " required[i], 2)
      }
    }
    next
  }
  {
    rows++
    guardrail = $idx["guardrail"]
    seen[guardrail] = 1
    if (guardrail == "qacc-default") {
      if ($idx["accepted_span_policy"] + 0 != 0) {
        die("qacc-default should not accept span policy", 3)
      }
      if ($idx["selected_scenario"] != $idx["qacc_policy_scenario"]) {
        die("qacc-default should select the byte-qacc policy", 4)
      }
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) != 0 ||
          ($idx["span_exact_delta_vs_qacc_policy"] + 0) != 0) {
        die("qacc-default should have zero deltas", 5)
      }
    } else if (guardrail == "strict-g0p050-cap0p050") {
      strict_seen = 1
      if ($idx["accepted_span_policy"] + 0 != 1) {
        die("strict smoke guardrail should accept the span policy", 6)
      }
      if ($idx["selected_scenario"] != "local-energy-hybrid") {
        die("strict smoke guardrail should select local-energy-hybrid", 7)
      }
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) >= 0.0) {
        die("strict smoke guardrail should trade off qacc", 8)
      }
      if (($idx["span_exact_delta_vs_qacc_policy"] + 0) <= 0.0) {
        die("strict smoke guardrail should improve span exact-match", 9)
      }
    }
  }
  END {
    if (rows < 4) {
      die("expected all guardrail decision rows", 10)
    }
    if (!("qacc-default" in seen) ||
        !("strict-g0p050-cap0p050" in seen) ||
        !("balanced-g0p025-cap0p050" in seen) ||
        !("span-first-g0p025-cap0p075" in seen)) {
      die("missing one or more guardrail arms", 11)
    }
    if (strict_seen != 1) {
      die("missing strict guardrail smoke row", 12)
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
    required_count = split("guardrail groups span_accept_rate selected_hybrid_rate qacc_delta_vs_qacc_policy_mean span_exact_delta_vs_qacc_policy_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) {
        die("missing span-first guardrail aggregate column: " required[i], 20)
      }
    }
    next
  }
  {
    rows++
    guardrail = $idx["guardrail"]
    if (($idx["groups"] + 0) < 1) {
      die("expected at least one guardrail group", 21)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor route path should remain inactive", 22)
    }
    if (guardrail == "qacc-default") {
      qacc_default_seen = 1
      if (($idx["span_accept_rate"] + 0) != 0.0 ||
          ($idx["selected_hybrid_rate"] + 0) != 0.0) {
        die("qacc-default aggregate should not select span policy", 23)
      }
      if (($idx["qacc_delta_vs_qacc_policy_mean"] + 0) != 0.0 ||
          ($idx["span_exact_delta_vs_qacc_policy_mean"] + 0) != 0.0) {
        die("qacc-default aggregate should preserve qacc policy metrics", 24)
      }
    } else if (guardrail == "strict-g0p050-cap0p050") {
      strict_seen = 1
      if (($idx["span_accept_rate"] + 0) <= 0.0 ||
          ($idx["selected_hybrid_rate"] + 0) <= 0.0) {
        die("strict guardrail aggregate should accept a span-first policy", 25)
      }
      if (($idx["qacc_delta_vs_qacc_policy_mean"] + 0) >= 0.0) {
        die("strict guardrail aggregate should trade off qacc", 26)
      }
      if (($idx["span_exact_delta_vs_qacc_policy_mean"] + 0) <= 0.0) {
        die("strict guardrail aggregate should improve span exact-match", 27)
      }
    }
  }
  END {
    if (rows < 4) {
      die("expected all guardrail aggregate rows", 28)
    }
    if (qacc_default_seen != 1 || strict_seen != 1) {
      die("missing required aggregate guardrail rows", 29)
    }
  }
' "$AGG_CSV"

echo "v06 route-memory span-first guardrail smoke passed"
