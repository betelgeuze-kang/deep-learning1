#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

FEATURE_LABELS_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_feature_labels.csv"
EXTERNAL_LABEL_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_external_labels.csv"
SOURCE_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_source.csv"
GOOD_EVAL_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_eval_good.csv"
BAD_EVAL_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_eval_bad.csv"
MALFORMED_EVAL_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_eval_malformed.csv"

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
      if (!(field in idx)) die("missing h10-s summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one h10-s summary row for " field, 4)
    }
  ' "$summary_csv"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_eval_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_source_verified_learned_chunk_scorer_eval_gate_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("source_verified_feature_labels_ready source_verified_learned_chunk_scorer_ready real_teacher_source_import_review_ready student_only_eval_rows student_only_eval_ready source_verified_learned_chunk_scorer_eval_ready default_promotion status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10-s default summary column: " required[i], 10)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10-s default row has wrong column count", 11)
    if (($idx["source_verified_feature_labels_ready"] + 0) != 0 ||
        ($idx["source_verified_learned_chunk_scorer_ready"] + 0) != 0 ||
        ($idx["real_teacher_source_import_review_ready"] + 0) != 0 ||
        ($idx["student_only_eval_rows"] + 0) != 0 ||
        ($idx["student_only_eval_ready"] + 0) != 0 ||
        ($idx["source_verified_learned_chunk_scorer_eval_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "source-verified-feature-labels-missing") {
      die("h10-s default should block before source-verified features and student-only eval", 12)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for default h10-s", 13)
    }
  }
  END {
    if (rows != 1) die("expected one h10-s default summary row", 14)
  }
' "$SUMMARY_CSV"

bash "$ROOT_DIR/experiments/test_v10_source_verified_learned_chunk_scorer_gate.sh" >/dev/null

{
  echo "eval_id,scorer_id,baseline_id,teacher_id,source_uri,provenance_hash,label_source,baseline_chunk_exact,student_only_chunk_exact,baseline_span_exact,student_only_span_exact,baseline_wrong_answer_rate,student_only_wrong_answer_rate,baseline_missing_abstain,student_only_missing_abstain,coherent_wrong_negative_rate,near_miss_negative_rate,missing_abstain_rate,correct_reward_rate,student_only_eval_ready,real_eval_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  echo "eval-001,linear-contrastive-chunk-v1-source-verified,local-energy-baseline,teacher-fixture-v1,https://teacher-source.invalid/source,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,provided-external-feature-csv,0.720000,0.840000,0.700000,0.780000,0.080000,0.040000,0.850000,0.920000,1.000000,1.000000,1.000000,1.000000,1,1,0,0,0"
} >"$GOOD_EVAL_CSV"

V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$FEATURE_LABELS_CSV" \
V10_TEACHER_EXTERNAL_LABEL_CSV="$EXTERNAL_LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV="$GOOD_EVAL_CSV" \
  "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh" --smoke

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("source_verified_feature_labels_ready source_verified_learned_chunk_scorer_ready student_only_eval_rows student_only_eval_ready baseline_chunk_exact student_only_chunk_exact chunk_exact_delta near_miss_negative_rate missing_abstain_rate metric_improvement_ready source_verified_learned_chunk_scorer_eval_ready default_promotion status reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10-s good-eval summary column: " required[i], 20)
    }
    next
  }
  {
    rows++
    if (($idx["source_verified_feature_labels_ready"] + 0) != 1 ||
        ($idx["source_verified_learned_chunk_scorer_ready"] + 0) != 0 ||
        ($idx["student_only_eval_rows"] + 0) != 1 ||
        ($idx["student_only_eval_ready"] + 0) != 1 ||
        ($idx["baseline_chunk_exact"] + 0) != 0.720000 ||
        ($idx["student_only_chunk_exact"] + 0) != 0.840000 ||
        ($idx["chunk_exact_delta"] + 0) <= 0.0 ||
        ($idx["near_miss_negative_rate"] + 0) != 1.0 ||
        ($idx["missing_abstain_rate"] + 0) != 1.0 ||
        ($idx["metric_improvement_ready"] + 0) != 1 ||
        ($idx["source_verified_learned_chunk_scorer_eval_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        $idx["status"] != "diagnostic-only" ||
        $idx["reason"] != "source-verified-learned-scorer-missing") {
      die("h10-s good student-only eval should pass metrics but remain blocked by real source-verified scorer", 21)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h10-s good eval", 22)
    }
  }
  END {
    if (rows != 1) die("expected one h10-s good-eval summary row", 23)
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
    if ($idx["gate"] == "source-verified-feature-labels" && $idx["status"] != "pass") {
      die("source-verified feature labels should pass for fixture", 30)
    }
    if ($idx["gate"] == "student-only-eval" && $idx["status"] != "pass") {
      die("student-only eval should pass for good supplied eval", 31)
    }
    if ($idx["gate"] == "metric-improvement" && $idx["status"] != "pass") {
      die("metric improvement should pass for good supplied eval", 32)
    }
    if ($idx["gate"] == "source-verified-learned-scorer-eval" && $idx["status"] != "blocked") {
      die("source-verified scorer eval should block before official source authority", 33)
    }
  }
  END {
    if (rows != 7) die("expected h10-s decision rows", 34)
  }
' "$DECISION_CSV"

{
  echo "eval_id,scorer_id,baseline_id,teacher_id,source_uri,provenance_hash,label_source,baseline_chunk_exact,student_only_chunk_exact,baseline_span_exact,student_only_span_exact,baseline_wrong_answer_rate,student_only_wrong_answer_rate,baseline_missing_abstain,student_only_missing_abstain,coherent_wrong_negative_rate,near_miss_negative_rate,missing_abstain_rate,correct_reward_rate,student_only_eval_ready,real_eval_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  echo "eval-001,linear-contrastive-chunk-v1-source-verified,local-energy-baseline,teacher-fixture-v1,https://teacher-source.invalid/source,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,provided-external-feature-csv,0.840000,0.800000,0.780000,0.760000,0.040000,0.060000,0.920000,0.900000,1.000000,0.500000,0.500000,1.000000,1,1,0,0,0"
} >"$BAD_EVAL_CSV"

V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$FEATURE_LABELS_CSV" \
V10_TEACHER_EXTERNAL_LABEL_CSV="$EXTERNAL_LABEL_CSV" \
V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV="$BAD_EVAL_CSV" \
  "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "student_only_eval_ready" "0" "bad h10-s eval should not be ready"
expect_summary_value "$SUMMARY_CSV" "metric_improvement_ready" "0" "bad h10-s eval should not pass improvement"
expect_summary_value "$SUMMARY_CSV" "source_verified_learned_chunk_scorer_eval_ready" "0" "bad h10-s eval should not unlock scorer eval"

{
  head -n 1 "$GOOD_EVAL_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$GOOD_EVAL_CSV")"
} >"$MALFORMED_EVAL_CSV"

if V10_LEARNED_CHUNK_QUALITY_SOURCE_VERIFIED_LABELS_CSV="$FEATURE_LABELS_CSV" \
   V10_TEACHER_EXTERNAL_LABEL_CSV="$EXTERNAL_LABEL_CSV" \
   V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV="$SOURCE_CSV" \
   V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV="$MALFORMED_EVAL_CSV" \
     "$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_eval_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h10-s should reject malformed student-only eval CSV row widths" >&2
  exit 40
fi

echo "v10 source-verified learned chunk scorer eval gate smoke passed"
