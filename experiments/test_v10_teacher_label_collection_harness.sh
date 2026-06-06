#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_teacher_label_collection_harness.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_teacher_label_collection_harness_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_teacher_label_collection_harness_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows schema_valid coverage_ready grounding_ready missing_query_valid source_ready balance_ready noisy_case_covered fallback_case_covered correct_labels wrong_labels near_miss_labels missing_query_labels abstain_labels candidate_label_rows grounded_candidate_rows teacher_label_contract_ready teacher_label_collection_ready teacher_external_labels_ready distillation_training_ready default_promotion label_source teacher_id collection_mode contract_version routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 teacher label collection summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 teacher label collection row has wrong column count", 3)
    if (($idx["rows"] + 0) < 6 ||
        ($idx["schema_valid"] + 0) != 1 ||
        ($idx["coverage_ready"] + 0) != 1 ||
        ($idx["grounding_ready"] + 0) != 1 ||
        ($idx["missing_query_valid"] + 0) != 1 ||
        ($idx["source_ready"] + 0) != 1 ||
        ($idx["balance_ready"] + 0) != 1 ||
        ($idx["noisy_case_covered"] + 0) != 1 ||
        ($idx["fallback_case_covered"] + 0) != 1) {
      die("h10 teacher label collection should satisfy schema, coverage, source, noisy, and fallback gates", 4)
    }
    if (($idx["correct_labels"] + 0) < 2 ||
        ($idx["wrong_labels"] + 0) <= 0 ||
        ($idx["near_miss_labels"] + 0) <= 0 ||
        ($idx["missing_query_labels"] + 0) <= 0 ||
        ($idx["abstain_labels"] + 0) <= 0 ||
        ($idx["candidate_label_rows"] + 0) <= 0 ||
        ($idx["grounded_candidate_rows"] + 0) != ($idx["candidate_label_rows"] + 0)) {
      die("h10 teacher label collection should contain balanced grounded labels", 5)
    }
    if (($idx["teacher_label_contract_ready"] + 0) != 1 ||
        ($idx["teacher_label_collection_ready"] + 0) != 1 ||
        ($idx["teacher_external_labels_ready"] + 0) != 0 ||
        ($idx["distillation_training_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["label_source"] != "local-teacher-harness" ||
        $idx["teacher_id"] != "deterministic-span-v1" ||
        $idx["collection_mode"] != "offline-fixture") {
      die("h10 teacher label collection should be locally collected but not externally labeled/trained/promoted", 6)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10 teacher label collection", 7)
    }
  }
  END {
    if (rows != 1) die("expected one h10 teacher label collection summary row", 8)
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
      die("missing h10 teacher label collection decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "schema" && $idx["status"] != "pass") die("schema gate should pass", 21)
    if ($idx["gate"] == "coverage" && $idx["status"] != "pass") die("coverage gate should pass", 22)
    if ($idx["gate"] == "source" && $idx["status"] != "pass") die("source gate should pass", 23)
    if ($idx["gate"] == "case-coverage" && $idx["status"] != "pass") die("case coverage gate should pass", 24)
    if ($idx["gate"] == "teacher-label-collection" && $idx["status"] != "pass") die("teacher label collection should pass", 25)
    if ($idx["gate"] == "distillation-training" && $idx["status"] != "blocked") die("distillation training should remain blocked", 26)
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") die("default promotion should remain blocked", 27)
  }
  END {
    if (rows < 7) die("expected h10 teacher label collection decision rows", 28)
  }
' "$DECISION_CSV"

echo "v10 teacher-label collection harness smoke passed"
