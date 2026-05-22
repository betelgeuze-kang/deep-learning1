#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_teacher_free_chunk_ranker.sh"

AGG_CSV="$RESULTS_DIR/v10_teacher_free_chunk_ranker_aggregate.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows groups chunk_credit_qacc keyshape_qacc chunk_credit_chunk_exact keyshape_chunk_exact chunk_credit_coherent_wrong best_non_keyshape_scorer best_qacc_delta_vs_local_energy best_chunk_delta_vs_local_energy best_wrong_delta_vs_local_energy keyshape_chunk_gap route_credit_gap_mean route_credit_top1_mean chunk_credit_gap_mean chunk_credit_top1_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v10 chunk ranker scale column: " required[i], 2)
    }
    next
  }
  function die(msg, code) {
    print msg > "/dev/stderr"
    exit code
  }
  {
    rows_seen++
    if (($idx["rows"] + 0) < 10) die("expected v10 scale matrix rows", 3)
    if (($idx["groups"] + 0) < 2) die("expected v10 scale matrix groups", 4)
    if ($idx["best_non_keyshape_scorer"] != "span-chunk-credit" &&
        $idx["best_non_keyshape_scorer"] != "span-local-energy-chunk-credit") {
      die("chunk-credit scorer should be best non-key-shape scale arm", 5)
    }
    if (($idx["chunk_credit_qacc"] + 0) + 0.000001 < ($idx["keyshape_qacc"] + 0) ||
        ($idx["chunk_credit_chunk_exact"] + 0) + 0.000001 < ($idx["keyshape_chunk_exact"] + 0)) {
      die("chunk-credit should match the key-shape upper-bound in scale smoke", 6)
    }
    if (($idx["chunk_credit_coherent_wrong"] + 0) != 0.0 ||
        ($idx["keyshape_chunk_gap"] + 0) != 0.0) {
      die("chunk-credit should close coherent-wrong/keyshape gap in scale smoke", 7)
    }
    if (($idx["best_qacc_delta_vs_local_energy"] + 0) <= 0.0 ||
        ($idx["best_chunk_delta_vs_local_energy"] + 0) <= 0.0 ||
        ($idx["best_wrong_delta_vs_local_energy"] + 0) >= 0.0) {
      die("chunk-credit scale arm should improve over local-energy", 8)
    }
    if (($idx["route_credit_gap_mean"] + 0) < 0.7 ||
        ($idx["chunk_credit_gap_mean"] + 0) < 0.7 ||
        ($idx["route_credit_top1_mean"] + 0) < 0.99 ||
        ($idx["chunk_credit_top1_mean"] + 0) < 0.99) {
      die("chunk-credit scale arm should maintain strong credit separation", 9)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v10 chunk ranker scale", 10)
    }
  }
  END {
    if (rows_seen != 1) die("expected one v10 scale aggregate row", 11)
  }
' "$AGG_CSV"

echo "v10 teacher-free chunk ranker scale passed"
