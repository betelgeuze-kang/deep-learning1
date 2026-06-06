#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_external_benchmark_official_source_acquisition_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_external_benchmark_official_source_acquisition_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_external_benchmark_official_source_acquisition_gate_smoke_packet/run_001"

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v13-n summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-n summary row", 4)
    }
  ' "$summary_csv"
}

expect_decision_status() {
  local decision_csv="$1"
  local gate="$2"
  local expected="$3"

  awk -F, -v gate="$gate" -v expected="$expected" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    $idx["gate"] == gate {
      found = 1
      if ($idx["status"] != expected) die("v13-n decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-n decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_external_benchmark_official_source_acquisition_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "source_seed_contract_ready" "1" "v13-n default seed contract"
expect_summary_value "$SUMMARY_CSV" "source_live_packet_hash_ready" "1" "v13-n default source live packet hash"
expect_summary_value "$SUMMARY_CSV" "official_benchmark_seed_rows" "1" "v13-n default official benchmark seed"
expect_summary_value "$SUMMARY_CSV" "live_acquisition_requested" "0" "v13-n default live acquisition requested"
expect_summary_value "$SUMMARY_CSV" "required_source_rows" "3" "v13-n default required source rows"
expect_summary_value "$SUMMARY_CSV" "acquisition_receipt_rows" "0" "v13-n default acquisition receipt rows"
expect_summary_value "$SUMMARY_CSV" "acquisition_json_shape_rows" "0" "v13-n default acquisition shape"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_official_source_acquisition_ready" "0" "v13-n default source acquisition ready"
expect_summary_value "$SUMMARY_CSV" "candidate_external_benchmark_result_ready" "0" "v13-n default benchmark result"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-n default release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-external-benchmark-source-acquisition-not-requested" "v13-n default action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-n default routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-n default jump"

expect_decision_status "$DECISION_CSV" "source-seed-upstream" "pass"
expect_decision_status "$DECISION_CSV" "source-seed-live-fetch" "blocked"
expect_decision_status "$DECISION_CSV" "official-benchmark-seed" "pass"
expect_decision_status "$DECISION_CSV" "live-acquisition-requested" "blocked"
expect_decision_status "$DECISION_CSV" "acquisition-receipts" "blocked"
expect_decision_status "$DECISION_CSV" "official-source-acquisition" "blocked"
expect_decision_status "$DECISION_CSV" "candidate-external-benchmark-result" "blocked"
expect_decision_status "$DECISION_CSV" "real-release-package" "blocked"

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
    if ($idx["runner_owned_live_acquisition"] != "0") die("v13-n default should not invent live acquisition", 20)
    if ($idx["json_shape_ready"] != "0") die("v13-n default should not mark acquisition JSON ready", 21)
  }
  END {
    if (rows != 3) die("expected three v13-n source acquisition rows", 22)
  }
' "$PACKET_DIR/official_source_acquisition_rows.csv"

echo "v13 external benchmark official source acquisition gate smoke passed"
