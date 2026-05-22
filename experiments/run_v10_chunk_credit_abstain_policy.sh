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

PREFIX="v10_chunk_credit_abstain_policy"
CHUNK_PREFIX="v10_teacher_free_chunk_ranker"
JOINT_PREFIX="v10_chunk_credit_source_robustness"
SOURCE_PREFIX="v06_route_memory_wrong_candidate_robustness"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_chunk_credit_abstain_policy_smoke"
  CHUNK_PREFIX="v10_teacher_free_chunk_ranker_smoke"
  JOINT_PREFIX="v10_chunk_credit_source_robustness_smoke"
  SOURCE_PREFIX="v06_route_memory_wrong_candidate_robustness_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

CHUNK_AGG_CSV="$RESULTS_DIR/${CHUNK_PREFIX}_aggregate.csv"
JOINT_AGG_CSV="$RESULTS_DIR/${JOINT_PREFIX}_aggregate.csv"
SOURCE_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"
POLICY_CSV="$RESULTS_DIR/${PREFIX}_policy.csv"

if [[ ! -s "$CHUNK_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_teacher_free_chunk_ranker.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$JOINT_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v10_chunk_credit_source_robustness.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$SOURCE_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_wrong_candidate_robustness.sh" "${RUN_ARGS[@]}" >/dev/null
fi

awk -F, -v chunk_csv="$CHUNK_AGG_CSV" -v joint_csv="$JOINT_AGG_CSV" -v policy_csv="$POLICY_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  FILENAME == chunk_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) cidx[$i] = i
    required_count = split("chunk_credit_chunk_exact chunk_credit_coherent_wrong keyshape_chunk_gap chunk_credit_top1_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in cidx)) die("missing h10 chunk policy aggregate column: " required[i], 2)
    }
    next
  }
  FILENAME == chunk_csv {
    chunk_rows++
    chunk_exact = $cidx["chunk_credit_chunk_exact"] + 0
    chunk_wrong = $cidx["chunk_credit_coherent_wrong"] + 0
    chunk_keyshape_gap = $cidx["keyshape_chunk_gap"] + 0
    chunk_top1 = $cidx["chunk_credit_top1_mean"] + 0
    chunk_routing = $cidx["routing_trigger_rate_mean"] + 0
    chunk_jump = $cidx["active_jump_rate_mean"] + 0
    chunk_credit_ready = chunk_exact >= 0.95 &&
      chunk_wrong <= 0.05 &&
      chunk_keyshape_gap <= 0.05 &&
      chunk_top1 >= 0.99 &&
      chunk_routing == 0.0 &&
      chunk_jump == 0.0 ? 1 : 0
    next
  }
  FILENAME == joint_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) jidx[$i] = i
    required_count = split("best_joint_arm joint_chunk_source_ready chunk_ready source_safe fallback_not_keyshape_only fallback_retry_exercised noisy_used noisy_selected retry_noisy_selected retry_raw_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in jidx)) die("missing h10 chunk policy joint column: " required[i], 6)
    }
    next
  }
  FILENAME == joint_csv {
    joint_rows++
    joint_arm = $jidx["best_joint_arm"]
    joint_chunk_source_ready = $jidx["joint_chunk_source_ready"] + 0
    joint_chunk_ready = $jidx["chunk_ready"] + 0
    joint_source_safe = $jidx["source_safe"] + 0
    joint_fallback_not_keyshape_only = $jidx["fallback_not_keyshape_only"] + 0
    joint_fallback_retry_exercised = $jidx["fallback_retry_exercised"] + 0
    joint_noisy_used = $jidx["noisy_used"] + 0
    joint_noisy_selected = $jidx["noisy_selected"] + 0
    joint_retry_noisy_selected = $jidx["retry_noisy_selected"] + 0
    joint_retry_raw_selected = $jidx["retry_raw_selected"] + 0
    joint_routing = $jidx["routing_trigger_rate"] + 0
    joint_jump = $jidx["active_jump_rate"] + 0
    next
  }
  FILENAME != chunk_csv && FILENAME != joint_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("source_safe fallback_not_keyshape_only source_noisy_selected source_retry_noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) die("missing h10 chunk policy source column: " required[i], 3)
    }
    print "guardrail,guardrail_action,default_promotion,diagnostic_only,weak_hint_or_abstain,chunk_credit_ready,source_safe,fallback_not_keyshape_only,joint_chunk_source_ready,distillation_ready,combined_ready,noisy_selection_clean,joint_source_arm,joint_noisy_used,joint_fallback_retry_exercised,joint_retry_raw_selected,chunk_credit_chunk_exact,chunk_credit_coherent_wrong,keyshape_chunk_gap,chunk_credit_top1,source_noisy_selected,source_retry_noisy_selected,routing_trigger_rate,active_jump_rate" > policy_csv
    next
  }
  FILENAME != chunk_csv && FILENAME != joint_csv {
    source_rows++
    source_safe = $sidx["source_safe"] + 0
    fallback_not_keyshape_only = $sidx["fallback_not_keyshape_only"] + 0
    source_noisy_selected = $sidx["source_noisy_selected"] + 0
    source_retry_noisy_selected = $sidx["source_retry_noisy_selected"] + 0
    noisy_clean = source_noisy_selected == 0.0 &&
      source_retry_noisy_selected == 0.0 &&
      joint_noisy_selected == 0.0 &&
      joint_retry_noisy_selected == 0.0 ? 1 : 0
    distillation_ready = 0
    combined_ready = chunk_credit_ready &&
      source_safe &&
      fallback_not_keyshape_only &&
      noisy_clean &&
      joint_chunk_source_ready &&
      distillation_ready ? 1 : 0
    if (combined_ready) {
      action = "promotion-candidate"
      default_promotion = 1
      diagnostic_only = 0
      weak_hint_or_abstain = 0
    } else if (chunk_credit_ready && source_safe && noisy_clean && joint_chunk_source_ready) {
      action = "joint-ready-weak-hint-with-abstain"
      default_promotion = 0
      diagnostic_only = 1
      weak_hint_or_abstain = 1
    } else if (chunk_credit_ready && source_safe && noisy_clean) {
      action = "weak-hint-with-abstain"
      default_promotion = 0
      diagnostic_only = 1
      weak_hint_or_abstain = 1
    } else if (!chunk_credit_ready) {
      action = "chunk-credit-diagnostic-only"
      default_promotion = 0
      diagnostic_only = 1
      weak_hint_or_abstain = 0
    } else {
      action = "source-blocked"
      default_promotion = 0
      diagnostic_only = 1
      weak_hint_or_abstain = 0
    }
    printf "chunk-credit-source,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
      action,
      default_promotion,
      diagnostic_only,
      weak_hint_or_abstain,
      chunk_credit_ready,
      source_safe,
      fallback_not_keyshape_only,
      joint_chunk_source_ready,
      distillation_ready,
      combined_ready,
      noisy_clean,
      joint_arm,
      joint_noisy_used,
      joint_fallback_retry_exercised,
      joint_retry_raw_selected,
      chunk_exact,
      chunk_wrong,
      chunk_keyshape_gap,
      chunk_top1,
      source_noisy_selected,
      source_retry_noisy_selected,
      chunk_routing + joint_routing + ($sidx["routing_trigger_rate"] + 0),
      chunk_jump + joint_jump + ($sidx["active_jump_rate"] + 0) >> policy_csv
  }
  END {
    if (chunk_rows != 1) die("expected one h10 chunk aggregate row", 4)
    if (joint_rows != 1) die("expected one h10 joint aggregate row", 7)
    if (source_rows != 1) die("expected one h10 source summary row", 5)
    if (!joint_chunk_ready || !joint_source_safe ||
        !joint_fallback_not_keyshape_only || joint_noisy_used <= 0.0 ||
        joint_noisy_selected != 0.0 || joint_retry_noisy_selected != 0.0) {
      die("h10 joint source/chunk noisy gate is unsafe", 8)
    }
  }
' "$CHUNK_AGG_CSV" "$JOINT_AGG_CSV" "$SOURCE_SUMMARY_CSV"

echo "policy: $POLICY_CSV"
