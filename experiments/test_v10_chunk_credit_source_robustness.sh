#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_chunk_credit_source_robustness.sh" --smoke

AGG_CSV="$RESULTS_DIR/v10_chunk_credit_source_robustness_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("best_joint_arm best_joint_qacc best_joint_chunk_exact best_qacc_delta_vs_local_energy best_chunk_delta_vs_local_energy best_wrong_delta_vs_local_energy keyshape_chunk_gap top1_recall_gap chunk_ready source_safe fallback_not_keyshape_only fallback_retry_exercised joint_chunk_source_ready recommendation chunk_credit_top1 noisy_used noisy_selected retry_noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v10 joint robustness aggregate column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["best_joint_arm"] !~ /^chunk-credit-/) {
      die("v10 joint robustness should choose a chunk-credit arm", 3)
    }
    if (($idx["best_joint_qacc"] + 0) < 0.90 ||
        ($idx["best_joint_chunk_exact"] + 0) < 0.90) {
      die("v10 joint robustness should preserve strong qacc/chunk signal", 4)
    }
    if (($idx["best_qacc_delta_vs_local_energy"] + 0) < -0.000001 ||
        ($idx["best_chunk_delta_vs_local_energy"] + 0) < -0.000001 ||
        ($idx["best_wrong_delta_vs_local_energy"] + 0) > 0.000001) {
      die("v10 joint robustness should not regress against local-energy baseline", 5)
    }
    if (($idx["keyshape_chunk_gap"] + 0) > 0.050001 ||
        ($idx["top1_recall_gap"] + 0) > 0.050001 ||
        ($idx["chunk_credit_top1"] + 0) < 0.99) {
      die("v10 joint robustness should keep chunk top1 near keyshape", 6)
    }
    if (($idx["chunk_ready"] + 0) != 1 ||
        ($idx["source_safe"] + 0) != 1 ||
        ($idx["fallback_not_keyshape_only"] + 0) != 1 ||
        ($idx["fallback_retry_exercised"] + 0) != 0 ||
        ($idx["joint_chunk_source_ready"] + 0) != 0 ||
        $idx["recommendation"] != "noisy-clean-fallback-unexercised") {
      die("v10 joint robustness should keep fallback/retry unpromoted", 7)
    }
    if (($idx["noisy_used"] + 0) <= 0.0 ||
        ($idx["noisy_selected"] + 0) != 0.0 ||
        ($idx["retry_noisy_selected"] + 0) != 0.0) {
      die("v10 joint robustness should inject noisy candidates without selecting them", 8)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for v10 joint robustness", 9)
    }
  }
  END {
    if (rows != 1) die("expected one v10 joint robustness aggregate row", 10)
  }
' "$AGG_CSV"

echo "v10 chunk-credit source robustness smoke passed"
