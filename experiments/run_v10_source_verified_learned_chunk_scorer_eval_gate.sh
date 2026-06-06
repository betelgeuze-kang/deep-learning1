#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

PREFIX="v10_source_verified_learned_chunk_scorer_eval_gate"
SCORER_PREFIX="v10_source_verified_learned_chunk_scorer_gate"
REAL_SOURCE_IMPORT_PREFIX="v10_real_teacher_source_import_review"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_source_verified_learned_chunk_scorer_eval_gate_smoke"
  SCORER_PREFIX="v10_source_verified_learned_chunk_scorer_gate_smoke"
  REAL_SOURCE_IMPORT_PREFIX="v10_real_teacher_source_import_review_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v10_source_verified_learned_chunk_scorer_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v10_real_teacher_source_import_review.sh" "${RUN_ARGS[@]}" >/dev/null

SCORER_SUMMARY_CSV="$RESULTS_DIR/${SCORER_PREFIX}_summary.csv"
REAL_SOURCE_IMPORT_SUMMARY_CSV="$RESULTS_DIR/${REAL_SOURCE_IMPORT_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EMPTY_EVAL_CSV="$RESULTS_DIR/${PREFIX}_eval.csv"

EVAL_CSV="$EMPTY_EVAL_CSV"
EVAL_SOURCE="pending"
if [[ -n "${V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV:-}" ]]; then
  EVAL_CSV="$V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV"
  EVAL_SOURCE="provided-csv"
  if [[ ! -s "$EVAL_CSV" ]]; then
    echo "V10_SOURCE_VERIFIED_LEARNED_CHUNK_SCORER_EVAL_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  {
    echo "eval_id,scorer_id,baseline_id,teacher_id,source_uri,provenance_hash,label_source,baseline_chunk_exact,student_only_chunk_exact,baseline_span_exact,student_only_span_exact,baseline_wrong_answer_rate,student_only_wrong_answer_rate,baseline_missing_abstain,student_only_missing_abstain,coherent_wrong_negative_rate,near_miss_negative_rate,missing_abstain_rate,correct_reward_rate,student_only_eval_ready,real_eval_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  } >"$EMPTY_EVAL_CSV"
fi

awk -F, \
  -v scorer_csv="$SCORER_SUMMARY_CSV" \
  -v real_source_import_csv="$REAL_SOURCE_IMPORT_SUMMARY_CSV" \
  -v eval_csv="$EVAL_CSV" \
  -v eval_source="$EVAL_SOURCE" \
  -v summary_csv="$SUMMARY_CSV" \
  -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function metric_pass() {
    return chunk_exact_delta > 0.0 &&
      span_exact_delta >= 0.0 &&
      wrong_answer_delta <= 0.0 &&
      missing_abstain_delta >= 0.0 &&
      coherent_wrong_negative_rate >= 0.999999 &&
      near_miss_negative_rate >= 0.999999 &&
      missing_abstain_rate >= 0.999999 &&
      correct_reward_rate >= 0.999999
  }
  FILENAME == scorer_csv && FNR == 1 {
    scorer_header_fields = NF
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("source_verified_feature_labels_ready source_verified_learned_chunk_scorer_ready learned_score_gap correct_reward_rate coherent_wrong_negative_rate real_teacher_source_verified reason routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) die("missing h10-s source-verified scorer column: " required[i], 2)
    }
    next
  }
  FILENAME == scorer_csv {
    if (NF != scorer_header_fields) die("h10-s source-verified scorer row has wrong column count", 3)
    scorer_rows++
    source_verified_feature_labels_ready = $sidx["source_verified_feature_labels_ready"] + 0
    source_verified_learned_chunk_scorer_ready = $sidx["source_verified_learned_chunk_scorer_ready"] + 0
    h10l_learned_score_gap = $sidx["learned_score_gap"] + 0
    h10l_correct_reward_rate = $sidx["correct_reward_rate"] + 0
    h10l_coherent_wrong_negative_rate = $sidx["coherent_wrong_negative_rate"] + 0
    h10l_real_teacher_source_verified = $sidx["real_teacher_source_verified"] + 0
    h10l_reason = $sidx["reason"]
    h10l_routing = $sidx["routing_trigger_rate"] + 0
    h10l_jump = $sidx["active_jump_rate"] + 0
    next
  }
  FILENAME == real_source_import_csv && FNR == 1 {
    real_source_import_header_fields = NF
    for (i = 1; i <= NF; i++) ridx[$i] = i
    required_count = split("real_teacher_source_import_review_ready real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in ridx)) die("missing h10-s real source import column: " required[i], 4)
    }
    next
  }
  FILENAME == real_source_import_csv {
    if (NF != real_source_import_header_fields) die("h10-s real source import row has wrong column count", 5)
    real_source_import_rows++
    real_teacher_source_import_review_ready = $ridx["real_teacher_source_import_review_ready"] + 0
    h10r_real_teacher_source_verified = $ridx["real_teacher_source_verified"] + 0
    h10r_action = $ridx["action"]
    h10r_routing = $ridx["routing_trigger_rate"] + 0
    h10r_jump = $ridx["active_jump_rate"] + 0
    next
  }
  FILENAME == eval_csv && FNR == 1 {
    eval_header_fields = NF
    for (i = 1; i <= NF; i++) eidx[$i] = i
    required_count = split("eval_id scorer_id baseline_id teacher_id source_uri provenance_hash label_source baseline_chunk_exact student_only_chunk_exact baseline_span_exact student_only_span_exact baseline_wrong_answer_rate student_only_wrong_answer_rate baseline_missing_abstain student_only_missing_abstain coherent_wrong_negative_rate near_miss_negative_rate missing_abstain_rate correct_reward_rate student_only_eval_ready real_eval_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in eidx)) die("missing h10-s student-only eval column: " required[i], 6)
    }
    next
  }
  FILENAME == eval_csv {
    if (NF != eval_header_fields) die("h10-s student-only eval row has wrong column count", 7)
    eval_rows++
    baseline_chunk_exact_sum += $eidx["baseline_chunk_exact"] + 0
    student_only_chunk_exact_sum += $eidx["student_only_chunk_exact"] + 0
    baseline_span_exact_sum += $eidx["baseline_span_exact"] + 0
    student_only_span_exact_sum += $eidx["student_only_span_exact"] + 0
    baseline_wrong_answer_rate_sum += $eidx["baseline_wrong_answer_rate"] + 0
    student_only_wrong_answer_rate_sum += $eidx["student_only_wrong_answer_rate"] + 0
    baseline_missing_abstain_sum += $eidx["baseline_missing_abstain"] + 0
    student_only_missing_abstain_sum += $eidx["student_only_missing_abstain"] + 0
    eval_coherent_wrong_negative_rate_sum += $eidx["coherent_wrong_negative_rate"] + 0
    eval_near_miss_negative_rate_sum += $eidx["near_miss_negative_rate"] + 0
    eval_missing_abstain_rate_sum += $eidx["missing_abstain_rate"] + 0
    eval_correct_reward_rate_sum += $eidx["correct_reward_rate"] + 0
    if (($eidx["student_only_eval_ready"] + 0) == 1) eval_ready_rows++
    if (($eidx["real_eval_declared"] + 0) == 1) real_eval_declared_rows++
    if (($eidx["fixture_or_synthetic_declared"] + 0) == 0) non_fixture_eval_rows++
    if ($eidx["source_uri"] != "" && $eidx["provenance_hash"] != "") source_bound_eval_rows++
    eval_routing += $eidx["routing_trigger_rate"] + 0
    eval_jump += $eidx["active_jump_rate"] + 0
    next
  }
  END {
    if (scorer_rows != 1) die("expected one h10-s source-verified scorer row", 8)
    if (real_source_import_rows != 1) die("expected one h10-s real source import row", 9)

    learned_score_gap = h10l_learned_score_gap
    correct_reward_rate = h10l_correct_reward_rate
    coherent_wrong_negative_rate = h10l_coherent_wrong_negative_rate
    near_miss_negative_rate = 0.0
    missing_abstain_rate = 0.0
    baseline_chunk_exact = 0.0
    student_only_chunk_exact = 0.0
    baseline_span_exact = 0.0
    student_only_span_exact = 0.0
    baseline_wrong_answer_rate = 0.0
    student_only_wrong_answer_rate = 0.0
    baseline_missing_abstain = 0.0
    student_only_missing_abstain = 0.0

    if (eval_rows > 0) {
      baseline_chunk_exact = baseline_chunk_exact_sum / eval_rows
      student_only_chunk_exact = student_only_chunk_exact_sum / eval_rows
      baseline_span_exact = baseline_span_exact_sum / eval_rows
      student_only_span_exact = student_only_span_exact_sum / eval_rows
      baseline_wrong_answer_rate = baseline_wrong_answer_rate_sum / eval_rows
      student_only_wrong_answer_rate = student_only_wrong_answer_rate_sum / eval_rows
      baseline_missing_abstain = baseline_missing_abstain_sum / eval_rows
      student_only_missing_abstain = student_only_missing_abstain_sum / eval_rows
      coherent_wrong_negative_rate = eval_coherent_wrong_negative_rate_sum / eval_rows
      near_miss_negative_rate = eval_near_miss_negative_rate_sum / eval_rows
      missing_abstain_rate = eval_missing_abstain_rate_sum / eval_rows
      correct_reward_rate = eval_correct_reward_rate_sum / eval_rows
    }

    chunk_exact_delta = student_only_chunk_exact - baseline_chunk_exact
    span_exact_delta = student_only_span_exact - baseline_span_exact
    wrong_answer_delta = student_only_wrong_answer_rate - baseline_wrong_answer_rate
    missing_abstain_delta = student_only_missing_abstain - baseline_missing_abstain

    metric_improvement_ready = 0
    if (eval_rows > 0 && metric_pass()) {
      metric_improvement_ready = 1
    }

    student_only_eval_ready = 0
    if (eval_rows > 0 &&
        eval_ready_rows == eval_rows &&
        real_eval_declared_rows == eval_rows &&
        non_fixture_eval_rows == eval_rows &&
        source_bound_eval_rows == eval_rows &&
        metric_improvement_ready &&
        eval_routing == 0.0 &&
        eval_jump == 0.0) {
      student_only_eval_ready = 1
    }

    real_teacher_source_verified = 0
    if (h10l_real_teacher_source_verified && h10r_real_teacher_source_verified) {
      real_teacher_source_verified = 1
    }

    total_routing = h10l_routing + h10r_routing + eval_routing
    total_jump = h10l_jump + h10r_jump + eval_jump

    source_verified_learned_chunk_scorer_eval_ready = 0
    if (source_verified_feature_labels_ready &&
        source_verified_learned_chunk_scorer_ready &&
        real_teacher_source_import_review_ready &&
        real_teacher_source_verified &&
        student_only_eval_ready &&
        total_routing == 0.0 &&
        total_jump == 0.0) {
      source_verified_learned_chunk_scorer_eval_ready = 1
    }

    default_promotion = 0
    status = source_verified_learned_chunk_scorer_eval_ready ? "source-verified-scorer-eval-candidate" : "diagnostic-only"
    reason = "all-gates-ready"
    if (!source_verified_feature_labels_ready) {
      reason = "source-verified-feature-labels-missing"
    } else if (!source_verified_learned_chunk_scorer_ready) {
      reason = "source-verified-learned-scorer-missing"
    } else if (!real_teacher_source_import_review_ready) {
      reason = "teacher-real-source-import-review-missing"
    } else if (!real_teacher_source_verified) {
      reason = "teacher-real-source-official-authority-missing"
    } else if (eval_rows <= 0) {
      reason = "student-only-eval-missing"
    } else if (eval_routing != 0.0 || eval_jump != 0.0) {
      reason = "jump-guardrail-active"
    } else if (real_eval_declared_rows != eval_rows || non_fixture_eval_rows != eval_rows) {
      reason = "student-only-eval-real-source-missing"
    } else if (source_bound_eval_rows != eval_rows) {
      reason = "student-only-eval-source-binding-missing"
    } else if (!metric_improvement_ready) {
      reason = "student-only-eval-not-improved"
    } else if (eval_ready_rows != eval_rows) {
      reason = "student-only-eval-not-ready"
    }

    print "source_verified_scorer_eval_scope,eval_source,h10l_reason,h10r_action,source_verified_feature_labels_ready,source_verified_learned_chunk_scorer_ready,real_teacher_source_import_review_ready,h10l_real_teacher_source_verified,h10r_real_teacher_source_verified,real_teacher_source_verified,student_only_eval_rows,student_only_eval_ready,learned_score_gap,correct_reward_rate,coherent_wrong_negative_rate,near_miss_negative_rate,missing_abstain_rate,baseline_chunk_exact,student_only_chunk_exact,chunk_exact_delta,baseline_span_exact,student_only_span_exact,span_exact_delta,baseline_wrong_answer_rate,student_only_wrong_answer_rate,wrong_answer_delta,baseline_missing_abstain,student_only_missing_abstain,missing_abstain_delta,eval_ready_rows,real_eval_declared_rows,non_fixture_eval_rows,source_bound_eval_rows,metric_improvement_ready,source_verified_learned_chunk_scorer_eval_ready,default_promotion,status,reason,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-h10s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%d,%d,%d,%s,%s,%.6f,%.6f\n",
      eval_source,
      h10l_reason,
      h10r_action,
      source_verified_feature_labels_ready,
      source_verified_learned_chunk_scorer_ready,
      real_teacher_source_import_review_ready,
      h10l_real_teacher_source_verified,
      h10r_real_teacher_source_verified,
      real_teacher_source_verified,
      eval_rows,
      student_only_eval_ready,
      learned_score_gap,
      correct_reward_rate,
      coherent_wrong_negative_rate,
      near_miss_negative_rate,
      missing_abstain_rate,
      baseline_chunk_exact,
      student_only_chunk_exact,
      chunk_exact_delta,
      baseline_span_exact,
      student_only_span_exact,
      span_exact_delta,
      baseline_wrong_answer_rate,
      student_only_wrong_answer_rate,
      wrong_answer_delta,
      baseline_missing_abstain,
      student_only_missing_abstain,
      missing_abstain_delta,
      eval_ready_rows,
      real_eval_declared_rows,
      non_fixture_eval_rows,
      source_bound_eval_rows,
      metric_improvement_ready,
      source_verified_learned_chunk_scorer_eval_ready,
      default_promotion,
      status,
      reason,
      total_routing,
      total_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "source-verified-feature-labels,%s,ready=%d\n",
      source_verified_feature_labels_ready ? "pass" : "blocked",
      source_verified_feature_labels_ready >> decision_csv
    printf "source-verified-learned-scorer,%s,ready=%d h10l_reason=%s\n",
      source_verified_learned_chunk_scorer_ready ? "pass" : "blocked",
      source_verified_learned_chunk_scorer_ready,
      h10l_reason >> decision_csv
    printf "real-teacher-source-import-review,%s,ready=%d action=%s\n",
      real_teacher_source_import_review_ready ? "pass" : "blocked",
      real_teacher_source_import_review_ready,
      h10r_action >> decision_csv
    printf "student-only-eval,%s,rows=%d ready_rows=%d real_rows=%d non_fixture_rows=%d\n",
      student_only_eval_ready ? "pass" : "blocked",
      eval_rows,
      eval_ready_rows,
      real_eval_declared_rows,
      non_fixture_eval_rows >> decision_csv
    printf "metric-improvement,%s,chunk_delta=%.6f span_delta=%.6f wrong_delta=%.6f missing_delta=%.6f near_miss_negative=%.6f\n",
      metric_improvement_ready ? "pass" : "blocked",
      chunk_exact_delta,
      span_exact_delta,
      wrong_answer_delta,
      missing_abstain_delta,
      near_miss_negative_rate >> decision_csv
    printf "source-verified-learned-scorer-eval,%s,ready=%d reason=%s\n",
      source_verified_learned_chunk_scorer_eval_ready ? "pass" : "blocked",
      source_verified_learned_chunk_scorer_eval_ready,
      reason >> decision_csv
    printf "jump-guardrail,%s,routing=%.6f active_jump=%.6f\n",
      total_routing == 0.0 && total_jump == 0.0 ? "pass" : "blocked",
      total_routing,
      total_jump >> decision_csv
  }
' "$SCORER_SUMMARY_CSV" "$REAL_SOURCE_IMPORT_SUMMARY_CSV" "$EVAL_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
