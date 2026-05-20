#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_chunk_quality_diagnostics.sh" --smoke

POLICY_CSV="$RESULTS_DIR/v06_route_memory_chunk_quality_diagnostics_smoke_policy.csv"
AGG_CSV="$RESULTS_DIR/v06_route_memory_chunk_quality_diagnostics_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation key_count seed policy selected_scenario qacc chunk_exact per_offset_consistency coherent_wrong_key top1_recall_gap qacc_delta_vs_qacc_policy chunk_exact_delta_vs_qacc_policy keyshape_chunk_exact keyshape_gap routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing chunk-quality policy column: " required[i], 2)
    }
    next
  }
  {
    rows++
    policy = $idx["policy"]
    seen_policy[policy] = 1
    if (($idx["top1_recall_gap"] + 0) < -0.000001) die("top1/recall gap must be nonnegative", 3)
    if (($idx["keyshape_gap"] + 0) < -0.000001) die("keyshape should remain an upper-bound chunk diagnostic", 4)
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for chunk diagnostics", 5)
    }
    if (policy == "qacc-default") {
      if (($idx["qacc_delta_vs_qacc_policy"] + 0) != 0.0 ||
          ($idx["chunk_exact_delta_vs_qacc_policy"] + 0) != 0.0) {
        die("qacc-default should preserve chunk/qacc policy metrics", 6)
      }
    }
  }
  END {
    if (rows < 4) die("expected chunk-quality policy rows", 7)
    if (!("qacc-default" in seen_policy) || !("utility-w0p75" in seen_policy)) {
      die("missing chunk-quality policy rows", 8)
    }
  }
' "$POLICY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("degradation policy groups span_policy_accept_rate chunk_exact_mean per_offset_consistency_mean coherent_wrong_key_mean top1_recall_gap_mean keyshape_gap_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing chunk-quality aggregate column: " required[i], 20)
    }
    next
  }
  {
    rows++
    if (($idx["groups"] + 0) < 1) die("chunk aggregate must contain groups", 21)
    if (($idx["top1_recall_gap_mean"] + 0) < -0.000001) die("aggregate top1/recall gap must be nonnegative", 22)
    if (($idx["keyshape_gap_mean"] + 0) < -0.000001) die("aggregate keyshape gap must be nonnegative", 23)
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive in chunk aggregate", 24)
    }
    if ($idx["degradation"] == "all" && $idx["policy"] == "utility-w0p75") {
      saw_all_w0p75 = 1
    }
  }
  END {
    if (rows < 4) die("expected chunk-quality aggregate rows", 25)
    if (!saw_all_w0p75) die("missing all/utility-w0p75 chunk aggregate", 26)
  }
' "$AGG_CSV"

echo "v06 route-memory chunk-quality diagnostics smoke passed"
