#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v06_route_memory_chunk_code_similarity.sh" --smoke

AGG_CSV="$RESULTS_DIR/v06_route_memory_chunk_code_similarity_smoke_aggregate.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows groups local_energy_chunk_exact route_code_chunk_exact local_energy_route_code_chunk_exact best_non_keyshape_scorer best_non_keyshape_chunk_exact best_qacc_delta_vs_local_energy best_chunk_delta_vs_local_energy best_wrong_delta_vs_local_energy keyshape_chunk_gap route_decode_mean route_signature_collision_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing chunk code-similarity column: " required[i], 2)
    }
    next
  }
  {
    rows_seen++
    if (($idx["rows"] + 0) < 5) die("expected all chunk code-similarity arms", 3)
    if (($idx["groups"] + 0) < 1) die("expected chunk code-similarity groups", 4)
    if ($idx["best_non_keyshape_scorer"] == "") die("missing best code-similarity scorer", 5)
    if (($idx["best_chunk_delta_vs_local_energy"] + 0) < -0.000001) {
      die("best code-similarity scorer must not be below local-energy on chunk exact", 6)
    }
    if (($idx["best_qacc_delta_vs_local_energy"] + 0) < -0.050001) {
      die("best code-similarity qacc loss is too large", 7)
    }
    if (($idx["best_wrong_delta_vs_local_energy"] + 0) > 0.000001) {
      die("best code-similarity scorer must not increase coherent wrong-key rate", 8)
    }
    if (($idx["keyshape_chunk_gap"] + 0) < -0.000001) {
      die("key-shape should remain an upper-bound chunk diagnostic", 9)
    }
    if (($idx["routing_trigger_rate_mean"] + 0) != 0.0 ||
        ($idx["active_jump_rate_mean"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for chunk code-similarity diagnostics", 10)
    }
  }
  END {
    if (rows_seen != 1) die("expected one chunk code-similarity aggregate row", 11)
  }
' "$AGG_CSV"

echo "v06 route-memory chunk code-similarity diagnostics smoke passed"
