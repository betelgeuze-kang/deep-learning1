#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_chunk_local_energy_prefix.sh" --smoke

AGG_CSV="$RESULTS_DIR/v06_route_memory_chunk_local_energy_prefix_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows groups local_energy_chunk_exact local_energy_prefix_chunk_exact local_energy_worst_chunk_exact local_margin_chunk_exact local_margin_worst_chunk_exact best_non_keyshape_scorer best_non_keyshape_chunk_exact best_qacc_delta_vs_local_energy best_chunk_delta_vs_local_energy best_wrong_delta_vs_local_energy local_energy_prefix_qacc_delta_vs_local_energy local_energy_prefix_chunk_delta_vs_local_energy local_energy_prefix_wrong_delta_vs_local_energy keyshape_chunk_gap routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing chunk-local-scorer column: " required[i], 2)
    }
    next
  }
  {
    rows_seen++
    if (($idx["rows"] + 0) < 8) die("expected all chunk-local scorer arms", 3)
    if (($idx["groups"] + 0) < 1) die("expected chunk-local scorer groups", 4)
    if ($idx["best_non_keyshape_scorer"] == "") die("missing best local scorer", 5)
    if (($idx["best_chunk_delta_vs_local_energy"] + 0) < -0.000001) {
      die("best local scorer must not be below local-energy on chunk exact", 6)
    }
    if (($idx["best_qacc_delta_vs_local_energy"] + 0) < -0.020001) {
      die("best local scorer qacc loss is too large", 7)
    }
    if (($idx["best_wrong_delta_vs_local_energy"] + 0) > 0.000001) {
      die("best local scorer must not increase coherent wrong-key rate", 8)
    }
    if (($idx["keyshape_chunk_gap"] + 0) < -0.000001) {
      die("key-shape should remain an upper-bound chunk diagnostic", 9)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for chunk-local diagnostics", 10)
    }
  }
  END {
    if (rows_seen != 1) die("expected one chunk-local aggregate row", 11)
  }
' "$AGG_CSV"

echo "v06 route-memory chunk-local scorer diagnostics smoke passed"
