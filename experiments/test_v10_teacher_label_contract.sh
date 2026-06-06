#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_teacher_label_contract.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_teacher_label_contract_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_teacher_label_contract_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows label_classes correct_labels wrong_labels near_miss_labels missing_query_labels abstain_labels grounded_span_coverage missing_query_span_absent reward_actions slash_actions weak_negative_actions abstain_actions teacher_label_contract_ready teacher_label_collection_ready teacher_external_labels_ready distillation_training_ready default_promotion label_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher label contract summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 teacher label contract row has wrong column count", 3)
    if (($idx["rows"] + 0) < 5 ||
        ($idx["label_classes"] + 0) < 5 ||
        ($idx["correct_labels"] + 0) <= 0 ||
        ($idx["wrong_labels"] + 0) <= 0 ||
        ($idx["near_miss_labels"] + 0) <= 0 ||
        ($idx["missing_query_labels"] + 0) <= 0 ||
        ($idx["abstain_labels"] + 0) <= 0) {
      die("h10 teacher label contract should cover all required label classes", 4)
    }
    if (($idx["grounded_span_coverage"] + 0) != 1.0 ||
        ($idx["missing_query_span_absent"] + 0) != 1) {
      die("h10 teacher label contract should ground all candidate labels and keep missing queries spanless", 5)
    }
    if (($idx["reward_actions"] + 0) <= 0 ||
        ($idx["slash_actions"] + 0) <= 0 ||
        ($idx["weak_negative_actions"] + 0) <= 0 ||
        ($idx["abstain_actions"] + 0) <= 0) {
      die("h10 teacher label contract should cover reward/slash/weak-negative/abstain actions", 6)
    }
    if (($idx["teacher_label_contract_ready"] + 0) != 1 ||
        ($idx["teacher_label_collection_ready"] + 0) != 0 ||
        ($idx["teacher_external_labels_ready"] + 0) != 0 ||
        ($idx["distillation_training_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["label_source"] != "contract-oracle") {
      die("h10 teacher label contract should be schema-ready but not externally collected/trained/promoted", 7)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 teacher label contract", 8)
    }
  }
  END {
    if (rows != 1) die("expected one h10 teacher label contract summary row", 9)
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
      die("missing h10 teacher label contract decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "teacher-label-contract" && $idx["status"] != "pass") {
      die("teacher-label contract gate should pass", 21)
    }
    if ($idx["gate"] == "teacher-label-collection" && $idx["status"] != "blocked") {
      die("teacher-label collection should remain blocked", 22)
    }
    if ($idx["gate"] == "distillation-training" && $idx["status"] != "blocked") {
      die("distillation training should remain blocked", 23)
    }
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") {
      die("default promotion should remain blocked", 24)
    }
  }
  END {
    if (rows < 5) die("expected h10 teacher label contract decision rows", 25)
  }
' "$DECISION_CSV"

echo "v10 teacher label contract smoke passed"
