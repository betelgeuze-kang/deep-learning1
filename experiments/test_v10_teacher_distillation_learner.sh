#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_teacher_distillation_learner.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_teacher_distillation_learner_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_teacher_distillation_learner_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows train_rows eval_rows action_classes learned_rule_count reward_rules slash_rules weak_negative_rules abstain_rules training_schema_ready teacher_label_collection_ready teacher_external_labels_ready teacher_distillation_training_ready teacher_distillation_eval_ready default_promotion label_source learner_id training_mode action_accuracy exact_action_matches routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher distillation summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 teacher distillation summary row has wrong column count", 3)
    if (($idx["rows"] + 0) < 6 ||
        ($idx["train_rows"] + 0) != ($idx["rows"] + 0) ||
        ($idx["eval_rows"] + 0) != ($idx["rows"] + 0) ||
        ($idx["action_classes"] + 0) != 4 ||
        ($idx["learned_rule_count"] + 0) != 4 ||
        ($idx["reward_rules"] + 0) != 1 ||
        ($idx["slash_rules"] + 0) != 1 ||
        ($idx["weak_negative_rules"] + 0) != 1 ||
        ($idx["abstain_rules"] + 0) != 1) {
      die("h10 teacher distillation should learn all local action rules", 4)
    }
    if (($idx["training_schema_ready"] + 0) != 1 ||
        ($idx["teacher_label_collection_ready"] + 0) != 1 ||
        ($idx["teacher_external_labels_ready"] + 0) != 0 ||
        ($idx["teacher_distillation_training_ready"] + 0) != 1 ||
        ($idx["teacher_distillation_eval_ready"] + 0) != 1 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["label_source"] != "local-teacher-harness" ||
        $idx["learner_id"] != "distilled-rule-v1" ||
        $idx["training_mode"] != "local-fixture") {
      die("h10 teacher distillation should be locally trained/evaluated but not externally labeled/promoted", 5)
    }
    if (($idx["action_accuracy"] + 0) != 1.0 ||
        ($idx["exact_action_matches"] + 0) != ($idx["rows"] + 0)) {
      die("h10 teacher distillation should exactly fit the local collection fixture", 6)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 teacher distillation", 7)
    }
  }
  END {
    if (rows != 1) die("expected one h10 teacher distillation summary row", 8)
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
      die("missing h10 teacher distillation decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "schema" && $idx["status"] != "pass") die("schema gate should pass", 21)
    if ($idx["gate"] == "teacher-label-collection" && $idx["status"] != "pass") die("teacher label collection should pass", 22)
    if ($idx["gate"] == "action-fit" && $idx["status"] != "pass") die("local action fit should pass", 23)
    if ($idx["gate"] == "teacher-distillation-training" && $idx["status"] != "pass") die("teacher distillation training should pass", 24)
    if ($idx["gate"] == "external-label-ingestion" && $idx["status"] != "blocked") die("external label ingestion should remain blocked", 25)
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") die("default promotion should remain blocked", 26)
  }
  END {
    if (rows < 6) die("expected h10 teacher distillation decision rows", 27)
  }
' "$DECISION_CSV"

echo "v10 teacher distillation learner smoke passed"
