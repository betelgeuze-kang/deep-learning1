#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_chunk_credit_fallback_retry_exercise.sh" --smoke

AGG_CSV="$RESULTS_DIR/v10_chunk_credit_fallback_retry_exercise_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("best_arm baseline_qacc best_qacc best_qacc_delta_vs_corrupt source_retry_used source_retry_success retry_raw_selected retry_keyshape_selected retry_noisy_selected noisy_selected fallback_retry_exercised fallback_not_keyshape_only fallback_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 fallback exercise aggregate column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 fallback exercise row has wrong column count", 3)
    if ($idx["best_arm"] !~ /retry$/) {
      die("h10 fallback exercise should choose a retry arm", 4)
    }
    if (($idx["best_qacc"] + 0) <= ($idx["baseline_qacc"] + 0) ||
        ($idx["best_qacc_delta_vs_corrupt"] + 0) <= 0.05) {
      die("h10 fallback exercise should improve over forced-corrupt baseline", 5)
    }
    if (($idx["source_retry_used"] + 0) <= 0.0 ||
        ($idx["source_retry_success"] + 0) <= 0.0 ||
        ($idx["fallback_retry_exercised"] + 0) != 1 ||
        ($idx["fallback_ready"] + 0) != 1) {
      die("h10 fallback exercise should actually use and recover through retry", 6)
    }
    if (($idx["fallback_not_keyshape_only"] + 0) != 1 ||
        ($idx["retry_raw_selected"] + 0) <= 0.0) {
      die("h10 fallback exercise should include non-keyshape raw retry evidence", 7)
    }
    if (($idx["retry_noisy_selected"] + 0) != 0.0 ||
        ($idx["noisy_selected"] + 0) != 0.0) {
      die("h10 fallback exercise should avoid noisy retry/source selection", 8)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 fallback exercise", 9)
    }
  }
  END {
    if (rows != 1) die("expected one h10 fallback exercise aggregate row", 10)
  }
' "$AGG_CSV"

echo "v10 chunk-credit fallback retry exercise smoke passed"
