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

PREFIX="v10_learned_chunk_quality_scorer"
COLLECTION_PREFIX="v10_teacher_label_collection_harness"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_learned_chunk_quality_scorer_smoke"
  COLLECTION_PREFIX="v10_teacher_label_collection_harness_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi
if [[ -n "${V10_LEARNED_CHUNK_QUALITY_OUTPUT_PREFIX:-}" ]]; then
  PREFIX="$V10_LEARNED_CHUNK_QUALITY_OUTPUT_PREFIX"
fi

LABELS_CSV="${V10_LEARNED_CHUNK_QUALITY_LABELS_CSV:-$RESULTS_DIR/${COLLECTION_PREFIX}_labels.csv}"
WEIGHTS_CSV="$RESULTS_DIR/${PREFIX}_weights.csv"
SCORES_CSV="$RESULTS_DIR/${PREFIX}_scores.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ -z "${V10_LEARNED_CHUNK_QUALITY_LABELS_CSV:-}" && ! -s "$LABELS_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_teacher_label_collection_harness.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$LABELS_CSV" ]]; then
  echo "learned chunk quality labels CSV is not readable/non-empty: $LABELS_CSV" >&2
  exit 9
fi

awk -F, -v weights_csv="$WEIGHTS_CSV" -v scores_csv="$SCORES_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  function feature_value(name, row) {
    return feat[row, fmap[name]]
  }
  function score_row(row,   j, score) {
    score = bias
    for (j = 1; j <= feature_count; j++) {
      score += weight[j] * feat[row, j]
    }
    return score
  }
  BEGIN {
    feature_count = split("chunk_score chunk_gap span_overlap_norm chunk_top1 coherent_wrong_key noisy_source missing_query missing_candidate near_miss_norm", features, " ")
    for (i = 1; i <= feature_count; i++) fmap[features[i]] = i
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("label_id query_present candidate_present grounded_span_len chunk_score chunk_gap chunk_top1 noisy_source teacher_label expected_action span_overlap near_miss_distance coherent_wrong_key label_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h10 learned chunk scorer label column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h10 learned chunk scorer label row has wrong column count", 3)

    label_id[rows] = $idx["label_id"]
    teacher_label[rows] = $idx["teacher_label"]
    expected_action[rows] = $idx["expected_action"]
    row_label_source = $idx["label_source"]
    if (row_label_source == "") die("h10 learned chunk scorer label_source must be non-empty", 10)
    if (rows == 1) {
      label_source = row_label_source
    } else if (row_label_source != label_source) {
      die("h10 learned chunk scorer labels must use a single label_source", 11)
    }

    query_present = $idx["query_present"] + 0
    candidate_present = $idx["candidate_present"] + 0
    grounded_len = $idx["grounded_span_len"] + 0
    if (grounded_len <= 0) grounded_len = 1

    feat[rows, fmap["chunk_score"]] = $idx["chunk_score"] + 0
    feat[rows, fmap["chunk_gap"]] = $idx["chunk_gap"] + 0
    feat[rows, fmap["span_overlap_norm"]] = ($idx["span_overlap"] + 0) / grounded_len
    feat[rows, fmap["chunk_top1"]] = $idx["chunk_top1"] + 0
    feat[rows, fmap["coherent_wrong_key"]] = $idx["coherent_wrong_key"] + 0
    feat[rows, fmap["noisy_source"]] = $idx["noisy_source"] + 0
    feat[rows, fmap["missing_query"]] = 1 - query_present
    feat[rows, fmap["missing_candidate"]] = 1 - candidate_present
    feat[rows, fmap["near_miss_norm"]] = ($idx["near_miss_distance"] + 0) / grounded_len

    if (expected_action[rows] == "reward") {
      reward_rows++
      for (j = 1; j <= feature_count; j++) pos_sum[j] += feat[rows, j]
    } else {
      negative_rows++
      for (j = 1; j <= feature_count; j++) neg_sum[j] += feat[rows, j]
    }
    if (teacher_label[rows] == "wrong") wrong_rows++
    if (teacher_label[rows] == "near-miss") near_miss_rows++
    if (teacher_label[rows] == "missing-query") missing_rows++
    if (teacher_label[rows] == "abstain") abstain_rows++
    action_counts[expected_action[rows]]++
    if (feature_value("coherent_wrong_key", rows) == 1) coherent_wrong_rows++

    routing += $idx["routing_trigger_rate"] + 0
    jump += $idx["active_jump_rate"] + 0
  }
  END {
    if (rows < 6) die("expected at least six h10 learned chunk scorer rows", 4)
    if (reward_rows <= 0 || negative_rows <= 0) die("h10 learned chunk scorer needs reward and negative rows", 5)

    for (j = 1; j <= feature_count; j++) {
      pos_mean[j] = pos_sum[j] / reward_rows
      neg_mean[j] = neg_sum[j] / negative_rows
      weight[j] = pos_mean[j] - neg_mean[j]
      pos_projection += pos_mean[j] * weight[j]
      neg_projection += neg_mean[j] * weight[j]
    }
    bias = -0.5 * (pos_projection + neg_projection)

    print "feature,positive_mean,negative_mean,weight" > weights_csv
    for (j = 1; j <= feature_count; j++) {
      printf "%s,%.6f,%.6f,%.6f\n",
        features[j],
        pos_mean[j],
        neg_mean[j],
        weight[j] >> weights_csv
    }

    print "label_id,teacher_label,expected_action,label_source,learned_score,predicted_class,match,routing_trigger_rate,active_jump_rate" > scores_csv
    reward_score_min = 1.0e9
    negative_score_max = -1.0e9
    for (row = 1; row <= rows; row++) {
      learned_score = score_row(row)
      predicted_class = learned_score > 0.0 ? "reward" : "negative"
      expected_class = expected_action[row] == "reward" ? "reward" : "negative"
      class_match = predicted_class == expected_class ? 1 : 0
      exact_class_matches += class_match
      if (expected_action[row] == "reward") {
        reward_score_sum += learned_score
        if (learned_score < reward_score_min) reward_score_min = learned_score
        if (learned_score > 0.0) correct_reward_hits++
      } else {
        negative_score_sum += learned_score
        if (learned_score > negative_score_max) negative_score_max = learned_score
        if (learned_score < 0.0) negative_hits++
      }
      if (feature_value("coherent_wrong_key", row) == 1 && learned_score < 0.0) coherent_wrong_negative_hits++
      if (expected_action[row] == "slash" && learned_score < 0.0) slash_negative_hits++
      if (expected_action[row] == "abstain" && learned_score < 0.0) abstain_negative_hits++
      if (expected_action[row] == "weak-negative" && learned_score < 0.0) weak_negative_hits++
      printf "%s,%s,%s,%s,%.6f,%s,%d,0.000000,0.000000\n",
        label_id[row],
        teacher_label[row],
        expected_action[row],
        label_source,
        learned_score,
        predicted_class,
        class_match >> scores_csv
    }

    reward_score_mean = reward_score_sum / reward_rows
    negative_score_mean = negative_score_sum / negative_rows
    learned_score_gap = reward_score_min - negative_score_max
    correct_reward_rate = correct_reward_hits / reward_rows
    negative_action_rate = negative_hits / negative_rows
    coherent_wrong_negative_rate = coherent_wrong_rows > 0 ? coherent_wrong_negative_hits / coherent_wrong_rows : 0.0
    slash_negative_rate = action_counts["slash"] > 0 ? slash_negative_hits / action_counts["slash"] : 0.0
    abstain_negative_rate = action_counts["abstain"] > 0 ? abstain_negative_hits / action_counts["abstain"] : 0.0
    weak_negative_rate = action_counts["weak-negative"] > 0 ? weak_negative_hits / action_counts["weak-negative"] : 0.0

    direction_ready = 0
    if (weight[fmap["chunk_score"]] > 0.0 &&
        weight[fmap["chunk_gap"]] > 0.0 &&
        weight[fmap["span_overlap_norm"]] > 0.0 &&
        weight[fmap["chunk_top1"]] > 0.0 &&
        weight[fmap["coherent_wrong_key"]] < 0.0 &&
        weight[fmap["noisy_source"]] < 0.0 &&
        weight[fmap["missing_query"]] < 0.0 &&
        weight[fmap["missing_candidate"]] < 0.0) {
      direction_ready = 1
    }
    separation_ready = 0
    if (learned_score_gap > 0.50 &&
        correct_reward_rate == 1.0 &&
        negative_action_rate == 1.0 &&
        coherent_wrong_negative_rate == 1.0 &&
        slash_negative_rate == 1.0 &&
        abstain_negative_rate == 1.0 &&
        weak_negative_rate == 1.0) {
      separation_ready = 1
    }
    learned_chunk_scorer_ready = 0
    if (direction_ready && separation_ready && routing == 0.0 && jump == 0.0) {
      learned_chunk_scorer_ready = 1
    }
    external_label_source_ready = 0
    default_promotion = 0

    print "rows,train_rows,eval_rows,label_source,learner_id,training_mode,feature_count,reward_rows,negative_rows,wrong_rows,near_miss_rows,missing_query_rows,abstain_rows,coherent_wrong_rows,coherent_wrong_negative_rows,reward_score_mean,negative_score_mean,reward_score_min,negative_score_max,learned_score_gap,correct_reward_rate,negative_action_rate,coherent_wrong_negative_rate,slash_negative_rate,abstain_negative_rate,weak_negative_rate,direction_ready,separation_ready,learned_chunk_scorer_ready,external_label_source_ready,default_promotion,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%d,%d,%d,%s,linear-contrastive-chunk-v1,local-fixture,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%d,%.6f,%.6f\n",
      rows,
      rows,
      rows,
      label_source,
      feature_count,
      reward_rows,
      negative_rows,
      wrong_rows,
      near_miss_rows,
      missing_rows,
      abstain_rows,
      coherent_wrong_rows,
      coherent_wrong_negative_hits,
      reward_score_mean,
      negative_score_mean,
      reward_score_min,
      negative_score_max,
      learned_score_gap,
      correct_reward_rate,
      negative_action_rate,
      coherent_wrong_negative_rate,
      slash_negative_rate,
      abstain_negative_rate,
      weak_negative_rate,
      direction_ready,
      separation_ready,
      learned_chunk_scorer_ready,
      external_label_source_ready,
      default_promotion,
      routing,
      jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "feature-direction,%s,chunk_score=%.6f chunk_gap=%.6f overlap=%.6f coherent_wrong=%.6f noisy=%.6f missing=%.6f\n",
      direction_ready ? "pass" : "blocked",
      weight[fmap["chunk_score"]],
      weight[fmap["chunk_gap"]],
      weight[fmap["span_overlap_norm"]],
      weight[fmap["coherent_wrong_key"]],
      weight[fmap["noisy_source"]],
      weight[fmap["missing_query"]] >> decision_csv
    printf "reward-separation,%s,gap=%.6f reward_min=%.6f negative_max=%.6f\n",
      separation_ready ? "pass" : "blocked",
      learned_score_gap,
      reward_score_min,
      negative_score_max >> decision_csv
    printf "coherent-wrong-negative,%s,rate=%.6f rows=%d\n",
      coherent_wrong_negative_rate == 1.0 ? "pass" : "blocked",
      coherent_wrong_negative_rate,
      coherent_wrong_rows >> decision_csv
    printf "learned-chunk-scorer,%s,ready=%d learner=linear-contrastive-chunk-v1\n",
      learned_chunk_scorer_ready ? "pass" : "blocked",
      learned_chunk_scorer_ready >> decision_csv
    printf "external-label-source,%s,external_ready=%d\n",
      external_label_source_ready ? "pass" : "blocked",
      external_label_source_ready >> decision_csv
    printf "default-promotion,%s,default_promotion=%d\n",
      default_promotion ? "pass" : "blocked",
      default_promotion >> decision_csv
  }
' "$LABELS_CSV"

echo "weights: $WEIGHTS_CSV"
echo "scores: $SCORES_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
