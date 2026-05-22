#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_teacher_free_chunk_ranker.sh" --smoke

AGG_CSV="$RESULTS_DIR/v10_teacher_free_chunk_ranker_smoke_aggregate.csv"

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows groups local_energy_qacc chunk_credit_qacc local_energy_chunk_credit_qacc local_energy_chunk_exact chunk_credit_chunk_exact local_energy_chunk_credit_chunk_exact local_energy_coherent_wrong chunk_credit_coherent_wrong local_energy_chunk_credit_coherent_wrong best_non_keyshape_scorer best_non_keyshape_chunk_exact best_qacc_delta_vs_local_energy best_chunk_delta_vs_local_energy best_wrong_delta_vs_local_energy route_credit_gap_mean route_credit_top1_mean chunk_credit_gap_mean chunk_credit_top1_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v10 chunk ranker aggregate column: " required[i], 2)
    }
    next
  }
  function die(msg, code) {
    print msg > "/dev/stderr"
    exit code
  }
  {
    rows_seen++
    if (($idx["rows"] + 0) < 5) die("expected all v10 chunk ranker arms", 3)
    if (($idx["groups"] + 0) < 1) die("expected v10 chunk ranker groups", 4)
    if ($idx["best_non_keyshape_scorer"] != "span-chunk-credit" &&
        $idx["best_non_keyshape_scorer"] != "span-local-energy-chunk-credit") {
      die("chunk-credit scorer should be best non-key-shape arm in smoke", 5)
    }
    if (($idx["best_qacc_delta_vs_local_energy"] + 0) <= 0.0 ||
        ($idx["best_chunk_delta_vs_local_energy"] + 0) <= 0.0 ||
        ($idx["best_wrong_delta_vs_local_energy"] + 0) >= 0.0) {
      die("chunk-credit scorer should improve qacc/chunk and reduce coherent wrong-key", 6)
    }
    if (($idx["route_credit_gap_mean"] + 0) <= 0.0 ||
        ($idx["chunk_credit_gap_mean"] + 0) <= 0.0) {
      die("teacher-free credit learner should separate correct and wrong candidates", 7)
    }
    if (($idx["route_credit_top1_mean"] + 0) < 0.99 ||
        ($idx["chunk_credit_top1_mean"] + 0) < 0.99) {
      die("teacher-free credit top1 should recover the correct chunk in smoke", 8)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v10 chunk ranker", 9)
    }
  }
  END {
    if (rows_seen != 1) die("expected one v10 chunk ranker aggregate row", 10)
  }
' "$AGG_CSV"

echo "v10 teacher-free chunk ranker smoke passed"
