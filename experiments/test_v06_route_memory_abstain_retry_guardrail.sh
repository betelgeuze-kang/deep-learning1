#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_abstain_retry_guardrail.sh" --smoke

POLICY_CSV="$RESULTS_DIR/v06_route_memory_abstain_retry_guardrail_smoke_policy.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("guardrail guardrail_action default_promotion diagnostic_only weak_hint_or_abstain chunk_ready source_safe fallback_not_keyshape_only combined_ready noisy_selection_clean routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing abstain/retry policy column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["guardrail_action"] != "abstain-or-weak-hint") {
      die("expected weak-hint/abstain action while chunk-quality is not ready", 3)
    }
    if (($idx["default_promotion"] + 0) != 0 ||
        ($idx["diagnostic_only"] + 0) != 1 ||
        ($idx["weak_hint_or_abstain"] + 0) != 1) {
      die("abstain/retry guardrail should block default promotion", 4)
    }
    if (($idx["source_safe"] + 0) != 1 ||
        ($idx["noisy_selection_clean"] + 0) != 1) {
      die("source path should be safe and noisy-clean", 5)
    }
    if (($idx["chunk_ready"] + 0) != 0 ||
        ($idx["combined_ready"] + 0) != 0) {
      die("chunk/combined readiness should remain false", 6)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive", 7)
    }
  }
  END {
    if (rows != 1) die("expected one abstain/retry policy row", 8)
  }
' "$POLICY_CSV"

echo "v06 route-memory abstain/retry guardrail smoke passed"
