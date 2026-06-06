#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_evidence_source_seed_live_fetch_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_evidence_source_seed_live_fetch_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_real_evidence_source_seed_live_fetch_gate_smoke_packet/run_001"

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
      if (!(field in idx)) die("missing v13-m summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-m summary row", 4)
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
      if ($idx["status"] != expected) die("v13-m decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-m decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_live_fetch_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "seed_contract_ready" "1" "v13-m default seed contract"
expect_summary_value "$SUMMARY_CSV" "seed_packet_hash_ready" "1" "v13-m default seed hash"
expect_summary_value "$SUMMARY_CSV" "seed_live_fetch_requested" "0" "v13-m default live fetch requested"
expect_summary_value "$SUMMARY_CSV" "live_fetch_seed_ready" "0" "v13-m default live fetch ready"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_source_seed_ready" "0" "v13-m default claim candidate"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-m default required rows"
expect_summary_value "$SUMMARY_CSV" "receipt_file_rows" "0" "v13-m default receipt files"
expect_summary_value "$SUMMARY_CSV" "receipt_json_shape_rows" "0" "v13-m default receipt shape"
expect_summary_value "$SUMMARY_CSV" "source_seed_live_fetch_receipt_ready" "0" "v13-m default receipt ready"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_source_live_fetch_ready" "0" "v13-m default source live candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-m default release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-source-seed-live-fetch-not-requested" "v13-m default action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-m default routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-m default jump"

expect_decision_status "$DECISION_CSV" "source-seed-contract" "pass"
expect_decision_status "$DECISION_CSV" "runtime-live-fetch-requested" "blocked"
expect_decision_status "$DECISION_CSV" "runtime-live-fetch-complete" "blocked"
expect_decision_status "$DECISION_CSV" "receipt-files" "blocked"
expect_decision_status "$DECISION_CSV" "receipt-json-provenance" "blocked"
expect_decision_status "$DECISION_CSV" "source-live-fetch-receipts" "blocked"
expect_decision_status "$DECISION_CSV" "claim-evidence-bound" "blocked"
expect_decision_status "$DECISION_CSV" "candidate-source-live-fetch" "blocked"
expect_decision_status "$DECISION_CSV" "v13-real-evidence-source-live-fetch" "blocked"

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
    if ($idx["receipt_files"] != "0") die("v13-m default should not invent receipt files", 20)
  }
  END {
    if (rows != 4) die("expected four v13-m source live fetch rows", 21)
  }
' "$PACKET_DIR/source_seed_live_fetch_rows.csv"

echo "v13 real evidence source seed live fetch gate smoke passed"
