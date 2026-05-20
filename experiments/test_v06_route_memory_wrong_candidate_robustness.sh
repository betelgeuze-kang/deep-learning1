#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_wrong_candidate_robustness.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v06_route_memory_wrong_candidate_robustness_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v06_route_memory_wrong_candidate_robustness_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("chunk_ready source_arm source_qacc source_noisy_selected source_retry_raw_selected source_retry_keyshape_selected source_retry_noisy_selected source_safe fallback_not_keyshape_only combined_ready recommendation routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing wrong-candidate summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (($idx["source_safe"] + 0) != 1) die("expected safe source-credit retry candidate", 3)
    if (($idx["source_noisy_selected"] + 0) != 0.0 ||
        ($idx["source_retry_noisy_selected"] + 0) != 0.0) {
      die("noisy source/retry selection must stay zero", 4)
    }
    if (($idx["fallback_not_keyshape_only"] + 0) != 1) {
      die("source retry should not depend only on keyshape upper bound", 5)
    }
    if (($idx["chunk_ready"] + 0) != 0) {
      die("chunk-quality should remain diagnostic-only in smoke", 6)
    }
    if (($idx["combined_ready"] + 0) != 0 ||
        $idx["recommendation"] != "diagnostic-only") {
      die("combined wrong-candidate robustness should not promote yet", 7)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive", 8)
    }
  }
  END {
    if (rows != 1) die("expected one wrong-candidate summary row", 9)
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
      die("missing wrong-candidate decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "combined" && $idx["status"] != "diagnostic-only") {
      die("combined gate should remain diagnostic-only", 21)
    }
  }
  END {
    if (rows < 3) die("expected wrong-candidate decision gates", 22)
  }
' "$DECISION_CSV"

echo "v06 route-memory wrong-candidate robustness smoke passed"
