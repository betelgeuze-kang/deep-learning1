#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v10_learned_chunk_quality_scorer.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_learned_chunk_quality_scorer_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_learned_chunk_quality_scorer_smoke_decision.csv"
WEIGHTS_CSV="$RESULTS_DIR/v10_learned_chunk_quality_scorer_smoke_weights.csv"
COLLECTION_LABELS_CSV="$RESULTS_DIR/v10_teacher_label_collection_harness_smoke_labels.csv"
MIXED_LABELS_CSV="$RESULTS_DIR/v10_learned_chunk_quality_scorer_mixed_source_fixture.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("rows train_rows eval_rows label_source learner_id training_mode feature_count reward_rows negative_rows wrong_rows near_miss_rows missing_query_rows abstain_rows coherent_wrong_rows coherent_wrong_negative_rows reward_score_mean negative_score_mean reward_score_min negative_score_max learned_score_gap correct_reward_rate negative_action_rate coherent_wrong_negative_rate slash_negative_rate abstain_negative_rate weak_negative_rate direction_ready separation_ready learned_chunk_scorer_ready external_label_source_ready default_promotion routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing learned chunk scorer summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("learned chunk scorer summary row has wrong column count", 3)
    if (($idx["rows"] + 0) < 6 ||
        ($idx["train_rows"] + 0) != ($idx["rows"] + 0) ||
        ($idx["eval_rows"] + 0) != ($idx["rows"] + 0) ||
        $idx["label_source"] != "local-teacher-harness" ||
        $idx["learner_id"] != "linear-contrastive-chunk-v1" ||
        $idx["training_mode"] != "local-fixture" ||
        ($idx["feature_count"] + 0) < 8) {
      die("learned chunk scorer should train/eval from local teacher labels", 4)
    }
    if (($idx["reward_rows"] + 0) < 2 ||
        ($idx["negative_rows"] + 0) < 4 ||
        ($idx["wrong_rows"] + 0) < 1 ||
        ($idx["near_miss_rows"] + 0) < 1 ||
        ($idx["missing_query_rows"] + 0) < 1 ||
        ($idx["abstain_rows"] + 0) < 1 ||
        ($idx["coherent_wrong_rows"] + 0) < 1) {
      die("learned chunk scorer should cover reward/wrong/near-miss/missing/abstain/coherent-wrong rows", 5)
    }
    if (($idx["reward_score_min"] + 0) <= 0.0 ||
        ($idx["negative_score_max"] + 0) >= 0.0 ||
        ($idx["learned_score_gap"] + 0) <= 0.50 ||
        ($idx["correct_reward_rate"] + 0) != 1.0 ||
        ($idx["negative_action_rate"] + 0) != 1.0 ||
        ($idx["coherent_wrong_negative_rate"] + 0) != 1.0 ||
        ($idx["slash_negative_rate"] + 0) != 1.0 ||
        ($idx["abstain_negative_rate"] + 0) != 1.0 ||
        ($idx["weak_negative_rate"] + 0) != 1.0) {
      die("learned chunk scorer should separate reward from negative chunk actions", 6)
    }
    if (($idx["direction_ready"] + 0) != 1 ||
        ($idx["separation_ready"] + 0) != 1 ||
        ($idx["learned_chunk_scorer_ready"] + 0) != 1 ||
        ($idx["external_label_source_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0) {
      die("learned chunk scorer should be locally ready but not externally sourced/promoted", 7)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for learned chunk scorer", 8)
    }
  }
  END {
    if (rows != 1) die("expected one learned chunk scorer summary row", 9)
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
    weights[$idx["feature"]] = $idx["weight"] + 0
  }
  END {
    if (weights["chunk_score"] <= 0.0 ||
        weights["chunk_gap"] <= 0.0 ||
        weights["span_overlap_norm"] <= 0.0 ||
        weights["coherent_wrong_key"] >= 0.0 ||
        weights["noisy_source"] >= 0.0 ||
        weights["missing_query"] >= 0.0) {
      die("learned chunk scorer weights should reward correct chunk evidence and slash risk features", 20)
    }
  }
' "$WEIGHTS_CSV"

awk -F, '
  BEGIN { OFS = "," }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("label_source" in idx)) {
      print "missing label_source in mixed-source fixture input" > "/dev/stderr"
      exit 40
    }
    print
    next
  }
  NR == 2 {
    $(idx["label_source"]) = "local-teacher-harness-alt"
  }
  { print }
' "$COLLECTION_LABELS_CSV" > "$MIXED_LABELS_CSV"

if V10_LEARNED_CHUNK_QUALITY_LABELS_CSV="$MIXED_LABELS_CSV" "$ROOT_DIR/experiments/run_v10_learned_chunk_quality_scorer.sh" --smoke >/dev/null 2>/dev/null; then
  echo "learned chunk scorer should reject mixed label_source provenance" >&2
  exit 41
fi

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx) || !("reason" in idx)) {
      die("missing learned chunk scorer decision columns", 30)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "feature-direction" && $idx["status"] != "pass") die("feature direction should pass", 31)
    if ($idx["gate"] == "reward-separation" && $idx["status"] != "pass") die("reward separation should pass", 32)
    if ($idx["gate"] == "coherent-wrong-negative" && $idx["status"] != "pass") die("coherent wrong should be negative", 33)
    if ($idx["gate"] == "learned-chunk-scorer" && $idx["status"] != "pass") die("learned scorer should pass", 34)
    if ($idx["gate"] == "external-label-source" && $idx["status"] != "blocked") die("external source should remain blocked", 35)
    if ($idx["gate"] == "default-promotion" && $idx["status"] != "blocked") die("default promotion should remain blocked", 36)
  }
  END {
    if (rows < 6) die("expected learned chunk scorer decision rows", 37)
  }
' "$DECISION_CSV"

echo "v10 learned chunk quality scorer smoke passed"
