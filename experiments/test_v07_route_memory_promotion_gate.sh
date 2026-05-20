#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v07_route_memory_promotion_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v07_route_memory_promotion_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v07_route_memory_promotion_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("adaptive_scale_safe chunk_local_safe chunk_local_best_scorer chunk_local_chunk_delta chunk_local_qacc_delta chunk_local_wrong_delta chunk_ready source_safe fallback_not_keyshape_only combined_ready abstain_action weak_hint_or_abstain default_promotion status routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h7 promotion summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (($idx["adaptive_scale_safe"] + 0) != 1) die("adaptive scale should be safe", 3)
    if (($idx["chunk_local_safe"] + 0) != 1 ||
        $idx["chunk_local_best_scorer"] == "") {
      die("chunk-local scorer gate should be safe and populated", 10)
    }
    if (($idx["chunk_local_chunk_delta"] + 0) < -0.000001 ||
        ($idx["chunk_local_qacc_delta"] + 0) < -0.020001 ||
        ($idx["chunk_local_wrong_delta"] + 0) > 0.000001) {
      die("chunk-local scorer should not leak unsafe deltas", 11)
    }
    if (($idx["source_safe"] + 0) != 1 ||
        ($idx["fallback_not_keyshape_only"] + 0) != 1) {
      die("source-credit side should be safe and not keyshape-only", 4)
    }
    if (($idx["chunk_ready"] + 0) != 0 ||
        ($idx["combined_ready"] + 0) != 0) {
      die("chunk/combined gate should not be ready", 5)
    }
    if ($idx["abstain_action"] != "abstain-or-weak-hint" ||
        ($idx["weak_hint_or_abstain"] + 0) != 1) {
      die("promotion gate should route to weak-hint/abstain", 6)
    }
    if (($idx["default_promotion"] + 0) != 0 ||
        $idx["status"] != "diagnostic-only") {
      die("route-memory default promotion must remain blocked", 7)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive", 8)
    }
  }
  END {
    if (rows != 1) die("expected one h7 promotion summary row", 9)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx) || !("reason" in idx)) {
      die("missing h7 promotion decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") {
      die("default promotion gate should be blocked", 21)
    }
  }
  END {
    if (rows < 5) die("expected h7 promotion decision rows", 22)
  }
' "$DECISION_CSV"

echo "v07 route-memory promotion gate smoke passed"
