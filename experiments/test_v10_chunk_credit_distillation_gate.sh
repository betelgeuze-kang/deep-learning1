#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_chunk_credit_distillation_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_chunk_credit_distillation_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("best_joint_arm guardrail_action chunk_credit_ready joint_chunk_ready source_safe joint_source_safe noisy_clean fallback_not_keyshape_only fallback_retry_exercised joint_chunk_source_ready policy_distillation_ready combined_ready distillation_ready default_promotion diagnostic_only weak_hint_or_abstain status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 distillation summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 distillation row has wrong column count", 3)
    if ($idx["best_joint_arm"] !~ /^chunk-credit-/) {
      die("h10 distillation should consume chunk-credit joint evidence", 4)
    }
    if (($idx["chunk_credit_ready"] + 0) != 1 ||
        ($idx["joint_chunk_ready"] + 0) != 1 ||
        ($idx["source_safe"] + 0) != 1 ||
        ($idx["joint_source_safe"] + 0) != 1 ||
        ($idx["noisy_clean"] + 0) != 1) {
      die("h10 distillation should preserve chunk/source/noisy gates", 5)
    }
    if (($idx["fallback_retry_exercised"] + 0) != 0 ||
        ($idx["joint_chunk_source_ready"] + 0) != 0 ||
        ($idx["policy_distillation_ready"] + 0) != 0 ||
        ($idx["combined_ready"] + 0) != 0 ||
        ($idx["distillation_ready"] + 0) != 0) {
      die("h10 distillation must stay blocked until fallback/retry is exercised", 6)
    }
    if (($idx["default_promotion"] + 0) != 0 ||
        ($idx["diagnostic_only"] + 0) != 1 ||
        ($idx["weak_hint_or_abstain"] + 0) != 1 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "fallback-retry-unexercised") {
      die("h10 distillation should remain weak-hint diagnostic-only", 7)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 distillation", 8)
    }
  }
  END {
    if (rows != 1) die("expected one h10 distillation summary row", 9)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx) || !("reason" in idx)) {
      die("missing h10 distillation decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "fallback-retry" && $idx["status"] != "blocked") {
      die("fallback-retry gate should be blocked", 21)
    }
    if ($idx["gate"] == "distillation" && $idx["status"] != "blocked") {
      die("distillation gate should be blocked", 22)
    }
  }
  END {
    if (rows < 4) die("expected h10 distillation decision rows", 23)
  }
' "$DECISION_CSV"

echo "v10 chunk-credit distillation gate smoke passed"
