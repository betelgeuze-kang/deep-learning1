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

PREFIX="v06_route_memory_wrong_candidate_robustness"
CHUNK_PREFIX="v06_route_memory_chunk_quality_diagnostics"
SOURCE_PREFIX="v05_route_source_credit_retry_tiebreak"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v06_route_memory_wrong_candidate_robustness_smoke"
  CHUNK_PREFIX="v06_route_memory_chunk_quality_diagnostics_smoke"
  SOURCE_PREFIX="v05_route_source_credit_retry_tiebreak_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

CHUNK_AGG_CSV="$RESULTS_DIR/${CHUNK_PREFIX}_aggregate.csv"
SOURCE_SUMMARY_CSV="$RESULTS_DIR/${SOURCE_PREFIX}_summary.csv"

if [[ ! -s "$CHUNK_AGG_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v06_route_memory_chunk_quality_diagnostics.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$SOURCE_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v05_route_source_credit_retry_tiebreak.sh" "${RUN_ARGS[@]}" >/dev/null
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function better_source(arm, qacc, noisy_selected, retry_noisy, retry_keyshape, retry_raw, best_arm, eps) {
    if (arm == "noisy-filter" || arm == "fixed-keyshape") return 0
    if (noisy_selected > eps || retry_noisy > eps) return 0
    if (best_arm == "") return 1
    if (retry_keyshape < best_retry_keyshape - eps) return 1
    if (retry_keyshape <= best_retry_keyshape + eps && retry_raw > best_retry_raw + eps) return 1
    if (retry_keyshape <= best_retry_keyshape + eps &&
        retry_raw >= best_retry_raw - eps &&
        qacc > best_qacc + eps) return 1
    return 0
  }
  NR == FNR {
    if (FNR == 1) {
      for (i = 1; i <= NF; i++) cidx[$i] = i
      required_count = split("degradation policy groups qacc_mean chunk_exact_mean coherent_wrong_key_mean top1_recall_gap_mean keyshape_gap_mean routing_trigger_rate_mean active_jump_rate_mean", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in cidx)) {
          printf "missing wrong-candidate chunk aggregate column: %s\n", required[i] > "/dev/stderr"
          exit 2
        }
      }
      next
    }
    if ($cidx["degradation"] == "all" && $cidx["policy"] == "utility-w0p75") {
      chunk_seen = 1
      chunk_groups = $cidx["groups"] + 0
      chunk_qacc = $cidx["qacc_mean"] + 0
      chunk_exact = $cidx["chunk_exact_mean"] + 0
      chunk_wrong = $cidx["coherent_wrong_key_mean"] + 0
      chunk_gap = $cidx["top1_recall_gap_mean"] + 0
      chunk_keyshape_gap = $cidx["keyshape_gap_mean"] + 0
      chunk_routing = $cidx["routing_trigger_rate_mean"] + 0
      chunk_jump = $cidx["active_jump_rate_mean"] + 0
    }
    next
  }
  FNR == 1 {
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("arm qacc fallback_recall fallback_qacc noisy_selected source_retry_used source_retry_success retry_raw_selected retry_keyshape_selected retry_noisy_selected routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) {
        printf "missing wrong-candidate source summary column: %s\n", required[i] > "/dev/stderr"
        exit 3
      }
    }
    next
  }
  {
    source_rows++
    arm = $sidx["arm"]
    qacc = $sidx["qacc"] + 0
    noisy_selected = $sidx["noisy_selected"] + 0
    retry_noisy = $sidx["retry_noisy_selected"] + 0
    retry_keyshape = $sidx["retry_keyshape_selected"] + 0
    retry_raw = $sidx["retry_raw_selected"] + 0
    if (better_source(arm, qacc, noisy_selected, retry_noisy, retry_keyshape,
        retry_raw, best_arm, 0.0000005)) {
      best_arm = arm
      best_qacc = qacc
      best_fallback_recall = $sidx["fallback_recall"] + 0
      best_fallback_qacc = $sidx["fallback_qacc"] + 0
      best_noisy_selected = noisy_selected
      best_source_retry_used = $sidx["source_retry_used"] + 0
      best_source_retry_success = $sidx["source_retry_success"] + 0
      best_retry_raw = retry_raw
      best_retry_keyshape = retry_keyshape
      best_retry_noisy = retry_noisy
      best_routing = $sidx["routing_trigger_rate"] + 0
      best_jump = $sidx["active_jump_rate"] + 0
    }
  }
  END {
    if (!chunk_seen) {
      printf "missing all/utility-w0p75 chunk aggregate\n" > "/dev/stderr"
      exit 4
    }
    if (source_rows < 1 || best_arm == "") {
      printf "missing safe source-credit retry candidate\n" > "/dev/stderr"
      exit 5
    }

    chunk_ready = chunk_wrong <= 0.25 &&
      chunk_gap <= 0.25 &&
      chunk_keyshape_gap <= 0.10 &&
      chunk_routing == 0.0 &&
      chunk_jump == 0.0 ? 1 : 0
    source_safe = best_qacc >= 0.90 &&
      best_noisy_selected == 0.0 &&
      best_retry_noisy == 0.0 &&
      best_routing == 0.0 &&
      best_jump == 0.0 ? 1 : 0
    fallback_not_keyshape_only = best_retry_keyshape < 0.50 || best_retry_raw > 0.0 ? 1 : 0
    combined_ready = chunk_ready && source_safe && fallback_not_keyshape_only ? 1 : 0
    recommendation = combined_ready ? "promotion-candidate" : "diagnostic-only"

    print "chunk_groups,chunk_qacc,chunk_exact,chunk_coherent_wrong_key,chunk_top1_recall_gap,chunk_keyshape_gap,chunk_ready,source_arm,source_qacc,source_fallback_recall,source_fallback_qacc,source_noisy_selected,source_retry_used,source_retry_success,source_retry_raw_selected,source_retry_keyshape_selected,source_retry_noisy_selected,source_safe,fallback_not_keyshape_only,combined_ready,recommendation,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "%d,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%s,%.6f,%.6f\n",
      chunk_groups,
      chunk_qacc,
      chunk_exact,
      chunk_wrong,
      chunk_gap,
      chunk_keyshape_gap,
      chunk_ready,
      best_arm,
      best_qacc,
      best_fallback_recall,
      best_fallback_qacc,
      best_noisy_selected,
      best_source_retry_used,
      best_source_retry_success,
      best_retry_raw,
      best_retry_keyshape,
      best_retry_noisy,
      source_safe,
      fallback_not_keyshape_only,
      combined_ready,
      recommendation,
      chunk_routing + best_routing,
      chunk_jump + best_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "chunk-quality,%s,coherent_wrong=%.6f top1_recall_gap=%.6f keyshape_gap=%.6f\n",
      chunk_ready ? "pass" : "diagnostic-only",
      chunk_wrong,
      chunk_gap,
      chunk_keyshape_gap >> decision_csv
    printf "source-credit,%s,arm=%s qacc=%.6f retry_noisy=%.6f\n",
      source_safe ? "pass" : "blocked",
      best_arm,
      best_qacc,
      best_retry_noisy >> decision_csv
    printf "combined,%s,recommendation=%s\n",
      combined_ready ? "pass" : "diagnostic-only",
      recommendation >> decision_csv
  }
' "$CHUNK_AGG_CSV" "$SOURCE_SUMMARY_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
