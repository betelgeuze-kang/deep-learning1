#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("benchmark_scope benchmark_families source_import_source attestor_identity_verified source_import_rows source_import_contract_ready source_import_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing v08 source import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if ($idx["benchmark_scope"] != "route-memory-v08m" ||
        ($idx["benchmark_families"] + 0) != 4 ||
        $idx["source_import_source"] != "pending-fixture" ||
        ($idx["source_import_rows"] + 0) != 0 ||
        ($idx["source_import_contract_ready"] + 0) != 0 ||
        ($idx["source_import_verified"] + 0) != 0 ||
        ($idx["real_external_benchmark_verified"] + 0) != 0) {
      die("default v08 source import gate should remain blocked", 3)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for default v08 source import gate", 4)
    }
  }
  END {
    if (rows != 1) die("expected one v08 source import summary row", 5)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    if ($idx["gate"] == "source-import-contract" && $idx["status"] != "blocked") die("source import contract should block by default", 20)
    if ($idx["gate"] == "source-import-verification" && $idx["status"] != "blocked") die("source import verification should block by default", 21)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("real external benchmark should block by default", 22)
  }
  END {
    if (rows != 11) die("expected v08 source import decision rows", 23)
  }
' "$DECISION_CSV"

echo "v08 external benchmark source import gate smoke passed"
